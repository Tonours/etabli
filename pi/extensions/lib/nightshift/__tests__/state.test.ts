import { describe, expect, test, beforeEach } from "bun:test";
import { mkdtempSync, existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { readState, writeState, updateTaskState } from "../state.ts";
import type { NightshiftState } from "../types.ts";

let stateDir: string;
let stateFile: string;

beforeEach(() => {
  stateDir = mkdtempSync(join(tmpdir(), "nightshift-state-test-"));
  stateFile = join(stateDir, "state.json");
});

describe("readState", () => {
  test("returns empty state when file does not exist", () => {
    const state = readState(stateFile);
    expect(state).toEqual({ version: 1, tasks: {} });
  });

  test("reads valid state file", () => {
    const expected: NightshiftState = {
      version: 1,
      tasks: {
        "my-task": { status: "done", branch: "night/my-task" },
      },
    };
    Bun.write(stateFile, JSON.stringify(expected, null, 2));

    const state = readState(stateFile);
    expect(state).toEqual(expected);
  });

  test("throws on invalid JSON", () => {
    Bun.write(stateFile, "not json at all{{{");
    expect(() => readState(stateFile)).toThrow();
  });
});

describe("writeState", () => {
  test("writes state atomically (file exists after write)", () => {
    const state: NightshiftState = {
      version: 1,
      tasks: { "t1": { status: "running" } },
    };
    writeState(stateFile, state);

    expect(existsSync(stateFile)).toBe(true);
    const raw = readFileSync(stateFile, "utf-8");
    const parsed = JSON.parse(raw);
    expect(parsed.tasks.t1.status).toBe("running");
  });

  test("overwrites existing state", () => {
    writeState(stateFile, { version: 1, tasks: { a: { status: "done" } } });
    writeState(stateFile, { version: 1, tasks: { b: { status: "failed" } } });

    const state = readState(stateFile);
    expect(state.tasks.b?.status).toBe("failed");
    expect(state.tasks.a).toBeUndefined();
  });
});

describe("updateTaskState", () => {
  test("creates task entry if none exists", () => {
    writeState(stateFile, { version: 1, tasks: {} });
    updateTaskState(stateFile, "new-task", "status", "running");

    const state = readState(stateFile);
    expect(state.tasks["new-task"]?.status).toBe("running");
  });

  test("updates existing task field", () => {
    writeState(stateFile, {
      version: 1,
      tasks: { "my-task": { status: "running", branch: "night/my-task" } },
    });

    updateTaskState(stateFile, "my-task", "status", "done");

    const state = readState(stateFile);
    expect(state.tasks["my-task"]?.status).toBe("done");
    expect(state.tasks["my-task"]?.branch).toBe("night/my-task");
  });

  test("creates state file if it does not exist", () => {
    updateTaskState(stateFile, "fresh-task", "status", "todo");

    expect(existsSync(stateFile)).toBe(true);
    const state = readState(stateFile);
    expect(state.tasks["fresh-task"]?.status).toBe("todo");
  });
});
