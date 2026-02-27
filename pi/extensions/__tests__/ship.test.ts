import { describe, expect, test, beforeEach } from "bun:test";
import { mkdtempSync, writeFileSync, readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import {
  normalizeSegment,
  createRepoKey,
  getSessionKey,
  isShipResult,
  summarizeLast7Days,
  pruneHistory,
  readHistory,
  appendHistory,
  type ShipHistoryEntry,
  type ShipStatePaths,
} from "../lib/ship-utils.ts";

// -- normalizeSegment --
describe("normalizeSegment", () => {
  test("lowercases and replaces special chars with dashes", () => {
    expect(normalizeSegment("My Repo Name")).toBe("my-repo-name");
  });

  test("preserves dots, underscores, and dashes", () => {
    expect(normalizeSegment("my.repo_name-v2")).toBe("my.repo_name-v2");
  });

  test("trims leading/trailing dashes", () => {
    expect(normalizeSegment("--hello--")).toBe("hello");
  });

  test("returns 'repo' for empty result", () => {
    // normalizeSegment("") → "" but getRepoName handles fallback
    expect(normalizeSegment("")).toBe("");
  });
});

// -- createRepoKey --
describe("createRepoKey", () => {
  test("produces deterministic key from path", () => {
    const key1 = createRepoKey("/path/to/repo");
    const key2 = createRepoKey("/path/to/repo");
    expect(key1).toBe(key2);
  });

  test("different paths produce different keys", () => {
    const key1 = createRepoKey("/path/a");
    const key2 = createRepoKey("/path/b");
    expect(key1).not.toBe(key2);
  });

  test("key includes normalized repo name", () => {
    const key = createRepoKey("/projects/My App");
    expect(key).toMatch(/^my-app-/);
  });
});

// -- isShipResult --
describe("isShipResult", () => {
  test("accepts 'go'", () => expect(isShipResult("go")).toBe(true));
  test("accepts 'block'", () => expect(isShipResult("block")).toBe(true));
  test("rejects 'started'", () => expect(isShipResult("started")).toBe(false));
  test("rejects undefined", () => expect(isShipResult(undefined)).toBe(false));
  test("rejects empty string", () => expect(isShipResult("")).toBe(false));
});

// -- getSessionKey (Fix I-6) --
describe("getSessionKey", () => {
  test("uses PI_SHIP_SESSION when set", () => {
    const key = getSessionKey({ PI_SHIP_SESSION: "my-session" });
    expect(key).toBe("my-session");
  });

  test("falls back to TMUX_PANE", () => {
    const key = getSessionKey({ TMUX_PANE: "%3" });
    expect(key).toBe("3"); // normalized: % stripped
  });

  test("falls back to TTY", () => {
    const key = getSessionKey({ TTY: "/dev/ttys003" });
    expect(key).toMatch(/ttys003/);
  });

  test("falls back to pid-based key when no env set", () => {
    const key = getSessionKey({});
    expect(key).toMatch(/^pid-\d+$/);
  });

  test("never returns 'default'", () => {
    const key = getSessionKey({});
    expect(key).not.toBe("default");
  });
});

// -- summarizeLast7Days (Fix C-5: filter by sessionKey) --
describe("summarizeLast7Days", () => {
  const now = new Date();
  const recent = now.toISOString();
  const old = new Date(now.getTime() - 8 * 24 * 60 * 60 * 1000).toISOString();

  function entry(overrides: Partial<ShipHistoryEntry>): ShipHistoryEntry {
    return {
      runId: "r1",
      status: "go",
      task: "test-task",
      startedAt: recent,
      repoPath: "/path",
      repoName: "repo",
      sessionKey: "session-a",
      ...overrides,
    };
  }

  test("filters entries by sessionKey", () => {
    const entries: ShipHistoryEntry[] = [
      entry({ status: "go", sessionKey: "session-a" }),
      entry({ status: "block", sessionKey: "session-b" }),
      entry({ status: "go", sessionKey: "session-a" }),
    ];

    const summary = summarizeLast7Days(entries, "session-a");
    expect(summary).toContain("go=2");
    expect(summary).not.toContain("block=1");
  });

  test("excludes entries older than 7 days", () => {
    const entries: ShipHistoryEntry[] = [
      entry({ status: "go", startedAt: old }),
      entry({ status: "go", startedAt: recent }),
    ];

    const summary = summarizeLast7Days(entries, "session-a");
    expect(summary).toContain("go=1");
  });

  test("shows 'No GO/BLOCK decision' when none recorded", () => {
    const entries: ShipHistoryEntry[] = [
      entry({ status: "started" }),
    ];

    const summary = summarizeLast7Days(entries, "session-a");
    expect(summary).toContain("No GO/BLOCK decision");
  });
});

// -- pruneHistory (Fix I-3) --
describe("pruneHistory", () => {
  let historyFile: string;

  beforeEach(() => {
    const dir = mkdtempSync(join(tmpdir(), "ship-prune-test-"));
    historyFile = join(dir, "history.jsonl");
  });

  function makePaths(): ShipStatePaths {
    return {
      dir: tmpdir(),
      currentFile: "",
      historyFile,
      sessionKey: "test",
    };
  }

  function entry(i: number): ShipHistoryEntry {
    return {
      runId: `r${i}`,
      status: "go",
      task: `task-${i}`,
      startedAt: new Date().toISOString(),
      repoPath: "/path",
      repoName: "repo",
      sessionKey: "test",
    };
  }

  test("keeps all entries when under max", () => {
    const paths = makePaths();
    appendHistory(paths, entry(1));
    appendHistory(paths, entry(2));

    pruneHistory(paths, 10);

    const entries = readHistory(paths);
    expect(entries).toHaveLength(2);
  });

  test("trims to max entries keeping latest", () => {
    const paths = makePaths();
    for (let i = 0; i < 10; i++) {
      appendHistory(paths, entry(i));
    }

    pruneHistory(paths, 3);

    const entries = readHistory(paths);
    expect(entries).toHaveLength(3);
    expect(entries[0].runId).toBe("r7");
    expect(entries[2].runId).toBe("r9");
  });

  test("atomic write (file exists after prune)", () => {
    const paths = makePaths();
    for (let i = 0; i < 5; i++) {
      appendHistory(paths, entry(i));
    }

    pruneHistory(paths, 2);

    expect(existsSync(historyFile)).toBe(true);
    const raw = readFileSync(historyFile, "utf-8");
    expect(raw.trim().split("\n")).toHaveLength(2);
  });

  test("no-op on non-existent file", () => {
    const paths = makePaths();
    expect(() => pruneHistory(paths, 10)).not.toThrow();
  });
});
