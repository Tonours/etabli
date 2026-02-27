import { describe, expect, test } from "bun:test";
import { resolveConfig } from "../config.ts";

describe("resolveConfig", () => {
  test("returns default paths when no env provided", () => {
    const home = "/Users/test";
    const config = resolveConfig({ HOME: home });

    expect(config.projectRoot).toBe(`${home}/projects`);
    expect(config.worktreeRoot).toBe(`${home}/projects/worktrees`);
    expect(config.stateDir).toBe(`${home}/.local/state/nightshift`);
    expect(config.tasksFile).toBe(`${home}/.local/state/nightshift/tasks.md`);
    expect(config.stateFile).toBe(`${home}/.local/state/nightshift/state.json`);
    expect(config.historyFile).toBe(`${home}/.local/state/nightshift/history.jsonl`);
    expect(config.logDir).toBe(`${home}/.local/state/nightshift/logs`);
    expect(config.lastReportFile).toBe(`${home}/.local/state/nightshift/last-run-report.md`);
    expect(config.lastReportJsonFile).toBe(`${home}/.local/state/nightshift/last-run-report.json`);
  });

  test("respects PI_PROJECT_ROOT override", () => {
    const config = resolveConfig({
      HOME: "/Users/test",
      PI_PROJECT_ROOT: "/custom/projects",
    });

    expect(config.projectRoot).toBe("/custom/projects");
    expect(config.worktreeRoot).toBe("/custom/projects/worktrees");
  });

  test("respects PI_WORKTREE_ROOT override independently", () => {
    const config = resolveConfig({
      HOME: "/Users/test",
      PI_PROJECT_ROOT: "/custom/projects",
      PI_WORKTREE_ROOT: "/custom/worktrees",
    });

    expect(config.projectRoot).toBe("/custom/projects");
    expect(config.worktreeRoot).toBe("/custom/worktrees");
  });

  test("respects NIGHTSHIFT_STATE_DIR override", () => {
    const config = resolveConfig({
      HOME: "/Users/test",
      NIGHTSHIFT_STATE_DIR: "/tmp/nightshift-state",
    });

    expect(config.stateDir).toBe("/tmp/nightshift-state");
    expect(config.tasksFile).toBe("/tmp/nightshift-state/tasks.md");
    expect(config.stateFile).toBe("/tmp/nightshift-state/state.json");
    expect(config.historyFile).toBe("/tmp/nightshift-state/history.jsonl");
    expect(config.logDir).toBe("/tmp/nightshift-state/logs");
    expect(config.lastReportFile).toBe("/tmp/nightshift-state/last-run-report.md");
    expect(config.lastReportJsonFile).toBe("/tmp/nightshift-state/last-run-report.json");
  });

  test("all overrides together", () => {
    const config = resolveConfig({
      HOME: "/Users/test",
      PI_PROJECT_ROOT: "/a",
      PI_WORKTREE_ROOT: "/b",
      NIGHTSHIFT_STATE_DIR: "/c",
    });

    expect(config.projectRoot).toBe("/a");
    expect(config.worktreeRoot).toBe("/b");
    expect(config.stateDir).toBe("/c");
    expect(config.tasksFile).toBe("/c/tasks.md");
  });
});
