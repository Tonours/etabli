import { describe, expect, test, beforeEach } from "bun:test";
import { mkdtempSync, readFileSync, existsSync } from "node:fs";
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
  formatStartResponse,
  formatFinalizeResponse,
  detectStepFromInput,
  type ShipHistoryEntry,
  type ShipStatePaths,
  type ShipCurrentRun,
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

  test("returns empty string for empty input", () => {
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
    expect(createRepoKey("/path/a")).not.toBe(createRepoKey("/path/b"));
  });

  test("key includes normalized repo name", () => {
    expect(createRepoKey("/projects/My App")).toMatch(/^my-app-/);
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

// -- getSessionKey --
describe("getSessionKey", () => {
  test("uses PI_SHIP_SESSION when set", () => {
    expect(getSessionKey({ PI_SHIP_SESSION: "my-session" })).toBe("my-session");
  });

  test("falls back to TMUX_PANE", () => {
    expect(getSessionKey({ TMUX_PANE: "%3" })).toBe("3");
  });

  test("falls back to TTY", () => {
    expect(getSessionKey({ TTY: "/dev/ttys003" })).toMatch(/ttys003/);
  });

  test("falls back to pid-based key when no env set", () => {
    expect(getSessionKey({})).toMatch(/^pid-\d+$/);
  });

  test("never returns 'default'", () => {
    expect(getSessionKey({})).not.toBe("default");
  });
});

// -- detectStepFromInput --
describe("detectStepFromInput", () => {
  test("detects /skill:plan", () => {
    expect(detectStepFromInput("/skill:plan some task")).toBe("plan");
  });

  test("detects /skill:plan-review", () => {
    expect(detectStepFromInput("/skill:plan-review")).toBe("plan-review");
  });

  test("detects /skill:verify", () => {
    expect(detectStepFromInput("/skill:verify")).toBe("verify");
  });

  test("detects /skill:review", () => {
    expect(detectStepFromInput("/skill:review")).toBe("review");
  });

  test("does not confuse plan with plan-review", () => {
    expect(detectStepFromInput("/skill:plan-review")).toBe("plan-review");
    expect(detectStepFromInput("/skill:plan do stuff")).toBe("plan");
  });

  test("returns undefined for non-skill input", () => {
    expect(detectStepFromInput("hello world")).toBeUndefined();
    expect(detectStepFromInput("/ship start")).toBeUndefined();
  });

  test("handles leading whitespace", () => {
    expect(detectStepFromInput("  /skill:verify")).toBe("verify");
  });
});

// -- summarizeLast7Days --
describe("summarizeLast7Days", () => {
  const now = new Date();
  const recent = now.toISOString();
  const old = new Date(now.getTime() - 8 * 24 * 60 * 60 * 1000).toISOString();

  function entry(overrides: Partial<ShipHistoryEntry>): ShipHistoryEntry {
    return {
      runId: "r1", status: "go", task: "test-task", startedAt: recent,
      repoPath: "/path", repoName: "repo", sessionKey: "session-a",
      ...overrides,
    };
  }

  test("filters entries by sessionKey", () => {
    const entries = [
      entry({ status: "go", sessionKey: "session-a" }),
      entry({ status: "block", sessionKey: "session-b" }),
      entry({ status: "go", sessionKey: "session-a" }),
    ];
    const summary = summarizeLast7Days(entries, "session-a");
    expect(summary).toContain("go=2");
    expect(summary).not.toContain("block=1");
  });

  test("excludes entries older than 7 days", () => {
    const entries = [entry({ startedAt: old }), entry({ startedAt: recent })];
    expect(summarizeLast7Days(entries, "session-a")).toContain("go=1");
  });

  test("shows 'No GO/BLOCK decision' when none recorded", () => {
    expect(summarizeLast7Days([entry({ status: "started" })], "session-a")).toContain("No GO/BLOCK decision");
  });
});

// -- formatStartResponse --
describe("formatStartResponse", () => {
  function makeRun(overrides?: Partial<ShipCurrentRun>): ShipCurrentRun {
    return {
      runId: "123", task: "add feature", startedAt: "2025-01-01T00:00:00Z",
      auto: false, repoPath: "/path", repoName: "repo", sessionKey: "s1", completedSteps: [],
      ...overrides,
    };
  }

  test("includes task and repo info", () => {
    const out = formatStartResponse(makeRun(), false);
    expect(out).toContain("add feature");
    expect(out).toContain("repo");
  });

  test("shows queue message when auto", () => {
    const out = formatStartResponse(makeRun(), true);
    expect(out).toContain("Queued /skill:plan");
  });

  test("no queue message when not auto", () => {
    const out = formatStartResponse(makeRun(), false);
    expect(out).not.toContain("Queued");
  });
});

// -- formatFinalizeResponse --
describe("formatFinalizeResponse", () => {
  function makeRun(overrides?: Partial<ShipCurrentRun>): ShipCurrentRun {
    return {
      runId: "456", task: "fix bug", startedAt: "2025-01-01T00:00:00Z",
      auto: false, repoPath: "/path", repoName: "repo", sessionKey: "s1", completedSteps: [],
      ...overrides,
    };
  }

  test("shows completed and pending steps", () => {
    const out = formatFinalizeResponse(makeRun({ completedSteps: ["plan", "verify"] }), false);
    expect(out).toContain("plan, verify");
    expect(out).toContain("plan-review, implement, review");
  });

  test("shows queue message when runChecks and steps pending", () => {
    const out = formatFinalizeResponse(makeRun(), true);
    expect(out).toContain("Queued /skill:verify and /skill:review");
  });

  test("does not queue already completed steps", () => {
    const out = formatFinalizeResponse(makeRun({ completedSteps: ["verify"] }), true);
    expect(out).not.toContain("/skill:verify");
    expect(out).toContain("/skill:review");
  });
});

// -- pruneHistory --
describe("pruneHistory", () => {
  let historyFile: string;

  beforeEach(() => {
    const dir = mkdtempSync(join(tmpdir(), "ship-prune-test-"));
    historyFile = join(dir, "history.jsonl");
  });

  function makePaths(): ShipStatePaths {
    return { dir: tmpdir(), currentFile: "", historyFile, sessionKey: "test" };
  }

  function entry(i: number): ShipHistoryEntry {
    return {
      runId: `r${i}`, status: "go", task: `task-${i}`, startedAt: new Date().toISOString(),
      repoPath: "/path", repoName: "repo", sessionKey: "test",
    };
  }

  test("keeps all entries when under max", () => {
    const paths = makePaths();
    appendHistory(paths, entry(1));
    appendHistory(paths, entry(2));
    pruneHistory(paths, 10);
    expect(readHistory(paths)).toHaveLength(2);
  });

  test("trims to max entries keeping latest", () => {
    const paths = makePaths();
    for (let i = 0; i < 10; i++) appendHistory(paths, entry(i));
    pruneHistory(paths, 3);
    const entries = readHistory(paths);
    expect(entries).toHaveLength(3);
    expect(entries[0].runId).toBe("r7");
    expect(entries[2].runId).toBe("r9");
  });

  test("atomic write (file exists after prune)", () => {
    const paths = makePaths();
    for (let i = 0; i < 5; i++) appendHistory(paths, entry(i));
    pruneHistory(paths, 2);
    expect(existsSync(historyFile)).toBe(true);
    expect(readFileSync(historyFile, "utf-8").trim().split("\n")).toHaveLength(2);
  });

  test("no-op on non-existent file", () => {
    expect(() => pruneHistory(makePaths(), 10)).not.toThrow();
  });
});
