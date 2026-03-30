/// <reference path="./bun-test.d.ts" />
import { describe, expect, test } from "bun:test";
import { canSpawnRole, type MinimalSubagentState } from "../lib/subagent-orchestration.ts";

describe("canSpawnRole", () => {
  test("allows scout and reviewer even when a worker is running", () => {
    const states: MinimalSubagentState[] = [{ status: "running", role: "worker" }];
    expect(canSpawnRole(states, "scout")).toBeNull();
    expect(canSpawnRole(states, "reviewer")).toBeNull();
  });

  test("blocks a second worker by default", () => {
    const states: MinimalSubagentState[] = [{ status: "running", role: "worker" }];
    expect(canSpawnRole(states, "worker")).toContain("allowParallelWorkers=true");
  });

  test("allows a worker when no running worker exists", () => {
    const states: MinimalSubagentState[] = [{ status: "done", role: "worker" }];
    expect(canSpawnRole(states, "worker")).toBeNull();
  });

  test("allows an explicit parallel worker override", () => {
    const states: MinimalSubagentState[] = [{ status: "running", role: "worker" }];
    expect(canSpawnRole(states, "worker", true)).toBeNull();
  });
});
