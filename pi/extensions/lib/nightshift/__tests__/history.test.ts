import { describe, expect, test, beforeEach } from "bun:test";
import { mkdtempSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { appendHistory, readHistory, pruneHistory } from "../history.ts";
import type { NightshiftHistoryEntry } from "../types.ts";

let historyFile: string;

function makeEntry(overrides: Partial<NightshiftHistoryEntry> = {}): NightshiftHistoryEntry {
  return {
    runId: "run-1",
    taskId: "task-1",
    status: "done",
    verify: "ok",
    engine: "codex",
    branch: "night/task-1",
    repoDir: "/projects/app",
    worktree: "/worktrees/app-task-1",
    startedAt: "2024-01-01T12:00:00Z",
    endedAt: "2024-01-01T12:10:00Z",
    error: "",
    logFile: "/logs/task-1.log",
    verifyOnly: false,
    ...overrides,
  };
}

beforeEach(() => {
  const dir = mkdtempSync(join(tmpdir(), "nightshift-history-test-"));
  historyFile = join(dir, "history.jsonl");
});

describe("appendHistory", () => {
  test("creates file and appends entry", () => {
    const entry = makeEntry();
    appendHistory(historyFile, entry);

    const raw = readFileSync(historyFile, "utf-8");
    const lines = raw.trim().split("\n");
    expect(lines).toHaveLength(1);
    expect(JSON.parse(lines[0]).taskId).toBe("task-1");
  });

  test("appends multiple entries", () => {
    appendHistory(historyFile, makeEntry({ taskId: "t1" }));
    appendHistory(historyFile, makeEntry({ taskId: "t2" }));
    appendHistory(historyFile, makeEntry({ taskId: "t3" }));

    const raw = readFileSync(historyFile, "utf-8");
    const lines = raw.trim().split("\n");
    expect(lines).toHaveLength(3);
  });
});

describe("readHistory", () => {
  test("returns empty array when file does not exist", () => {
    expect(readHistory(historyFile)).toEqual([]);
  });

  test("reads entries correctly", () => {
    appendHistory(historyFile, makeEntry({ taskId: "a" }));
    appendHistory(historyFile, makeEntry({ taskId: "b" }));

    const entries = readHistory(historyFile);
    expect(entries).toHaveLength(2);
    expect(entries[0].taskId).toBe("a");
    expect(entries[1].taskId).toBe("b");
  });

  test("skips malformed lines", () => {
    Bun.write(historyFile, '{"taskId":"good"}\nnot-json\n{"taskId":"also-good"}\n');

    const entries = readHistory(historyFile);
    expect(entries).toHaveLength(2);
    expect(entries[0].taskId).toBe("good");
    expect(entries[1].taskId).toBe("also-good");
  });
});

describe("pruneHistory", () => {
  test("keeps all entries when under max", () => {
    appendHistory(historyFile, makeEntry({ taskId: "t1" }));
    appendHistory(historyFile, makeEntry({ taskId: "t2" }));

    pruneHistory(historyFile, 10);

    const entries = readHistory(historyFile);
    expect(entries).toHaveLength(2);
  });

  test("trims to max entries keeping latest", () => {
    for (let i = 0; i < 10; i++) {
      appendHistory(historyFile, makeEntry({ taskId: `t${i}` }));
    }

    pruneHistory(historyFile, 3);

    const entries = readHistory(historyFile);
    expect(entries).toHaveLength(3);
    expect(entries[0].taskId).toBe("t7");
    expect(entries[1].taskId).toBe("t8");
    expect(entries[2].taskId).toBe("t9");
  });

  test("no-op on non-existent file", () => {
    expect(() => pruneHistory(historyFile, 10)).not.toThrow();
  });
});
