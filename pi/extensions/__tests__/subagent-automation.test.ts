/// <reference path="./bun-test.d.ts" />
/// <reference path="../lib/node-runtime.d.ts" />
import { describe, expect, test } from "bun:test";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  buildAutomationInstruction,
  createWorkflowAutomationState,
  detectWorkflowInput,
  hasPlanFile,
  readPlanStatus,
  readWorkflowAutomationSettings,
  shouldSpawnWorker,
} from "../lib/subagent-automation.ts";

describe("detectWorkflowInput", () => {
  test("detects /skill:plan-loop with task text", () => {
    expect(detectWorkflowInput("/skill:plan-loop tighten subagent automation")).toEqual({
      workflow: "plan-loop",
      task: "tighten subagent automation",
    });
  });

  test("detects /plan-implement without task text", () => {
    expect(detectWorkflowInput("/plan-implement")).toEqual({
      workflow: "plan-implement",
      task: "",
    });
  });

  test("ignores unrelated input", () => {
    expect(detectWorkflowInput("hello")).toBeNull();
  });
});

describe("readWorkflowAutomationSettings", () => {
  test("uses defaults when settings are missing", () => {
    const settings = readWorkflowAutomationSettings(join(tmpdir(), "missing-subagent-automation.json"));
    expect(settings["plan-loop"].autoReviewer).toBe(true);
    expect(settings["plan-implement"].autoWorkerOnReady).toBe(true);
  });

  test("reads explicit automation flags", () => {
    const dir = mkdtempSync(join(tmpdir(), "subagent-automation-"));
    const file = join(dir, "settings.json");
    writeFileSync(
      file,
      JSON.stringify({
        subagentAutomation: {
          planLoop: { enabled: false, autoScout: false, autoReviewer: true },
          planImplement: { autoWorkerOnReady: false },
        },
      }),
      "utf-8",
    );

    const settings = readWorkflowAutomationSettings(file);
    expect(settings["plan-loop"]).toEqual({
      enabled: false,
      autoScout: false,
      autoReviewer: true,
      autoWorkerOnReady: false,
    });
    expect(settings["plan-implement"].autoWorkerOnReady).toBe(false);
  });
});

describe("readPlanStatus", () => {
  test("extracts READY from PLAN.md", () => {
    const dir = mkdtempSync(join(tmpdir(), "subagent-plan-"));
    writeFileSync(join(dir, "PLAN.md"), "# Title\n- Status: READY\n", "utf-8");
    expect(hasPlanFile(dir)).toBe(true);
    expect(readPlanStatus(dir)).toBe("READY");
  });
});

describe("shouldSpawnWorker", () => {
  test("waits for reviewer assimilation before worker", () => {
    const automation = createWorkflowAutomationState("plan-implement", "ship it", 1);
    automation.reviewerId = 2;
    automation.reviewerDone = true;
    automation.reviewerReadyAfterAgentEndCount = 3;

    expect(
      shouldSpawnWorker({
        automation,
        config: { enabled: true, autoScout: true, autoReviewer: true, autoWorkerOnReady: true },
        agentEndCount: 2,
        planStatus: "READY",
      }),
    ).toBe(false);
  });

  test("spawns worker once plan is READY after reviewer", () => {
    const automation = createWorkflowAutomationState("plan-implement", "ship it", 1);
    automation.reviewerId = 2;
    automation.reviewerDone = true;
    automation.reviewerReadyAfterAgentEndCount = 3;

    expect(
      shouldSpawnWorker({
        automation,
        config: { enabled: true, autoScout: true, autoReviewer: true, autoWorkerOnReady: true },
        agentEndCount: 3,
        planStatus: "READY",
      }),
    ).toBe(true);
  });
});

describe("buildAutomationInstruction", () => {
  test("mentions reviewer and worker for plan-implement", () => {
    const text = buildAutomationInstruction("plan-implement");
    expect(text).toContain("reviewer");
    expect(text).toContain("worker");
  });
});
