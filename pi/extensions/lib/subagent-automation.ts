/// <reference path="./node-runtime.d.ts" />
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

export type WorkflowKind = "plan-loop" | "plan-implement";

export type WorkflowAutomationConfig = {
  enabled: boolean;
  autoScout: boolean;
  autoReviewer: boolean;
  autoWorkerOnReady: boolean;
};

export type WorkflowAutomationSettings = Record<WorkflowKind, WorkflowAutomationConfig>;

export type WorkflowAutomationState = {
  runId: number;
  workflow: WorkflowKind;
  task: string;
  reviewerReadyAfterAgentEndCount: number;
  reviewerDone: boolean;
  scoutId?: number;
  reviewerId?: number;
  workerId?: number;
};

type RawWorkflowAutomationConfig = Partial<Record<keyof WorkflowAutomationConfig, unknown>>;

type RawSettings = {
  subagentAutomation?: Partial<Record<"planLoop" | "planImplement", RawWorkflowAutomationConfig>>;
};

const DEFAULT_SETTINGS: WorkflowAutomationSettings = {
  "plan-loop": {
    enabled: true,
    autoScout: true,
    autoReviewer: true,
    autoWorkerOnReady: false,
  },
  "plan-implement": {
    enabled: true,
    autoScout: true,
    autoReviewer: true,
    autoWorkerOnReady: true,
  },
};

function asBoolean(value: unknown, fallback: boolean): boolean {
  return typeof value === "boolean" ? value : fallback;
}

function readRawSettings(settingsPath: string): RawSettings | undefined {
  try {
    return JSON.parse(readFileSync(settingsPath, "utf-8")) as RawSettings;
  } catch {
    return undefined;
  }
}

export function readWorkflowAutomationSettings(settingsPath: string): WorkflowAutomationSettings {
  const raw = readRawSettings(settingsPath)?.subagentAutomation;
  const planLoop = raw?.planLoop ?? {};
  const planImplement = raw?.planImplement ?? {};

  return {
    "plan-loop": {
      enabled: asBoolean(planLoop.enabled, DEFAULT_SETTINGS["plan-loop"].enabled),
      autoScout: asBoolean(planLoop.autoScout, DEFAULT_SETTINGS["plan-loop"].autoScout),
      autoReviewer: asBoolean(planLoop.autoReviewer, DEFAULT_SETTINGS["plan-loop"].autoReviewer),
      autoWorkerOnReady: asBoolean(planLoop.autoWorkerOnReady, DEFAULT_SETTINGS["plan-loop"].autoWorkerOnReady),
    },
    "plan-implement": {
      enabled: asBoolean(planImplement.enabled, DEFAULT_SETTINGS["plan-implement"].enabled),
      autoScout: asBoolean(planImplement.autoScout, DEFAULT_SETTINGS["plan-implement"].autoScout),
      autoReviewer: asBoolean(planImplement.autoReviewer, DEFAULT_SETTINGS["plan-implement"].autoReviewer),
      autoWorkerOnReady: asBoolean(
        planImplement.autoWorkerOnReady,
        DEFAULT_SETTINGS["plan-implement"].autoWorkerOnReady,
      ),
    },
  };
}

export function detectWorkflowInput(text: string): { workflow: WorkflowKind; task: string } | null {
  const match = text.match(/^\/(?:skill:)?(plan-loop|plan-implement)\b([\s\S]*)$/);
  if (!match) return null;

  const workflow = match[1] as WorkflowKind;
  const task = match[2]?.trim() ?? "";
  return { workflow, task };
}

export function createWorkflowAutomationState(workflow: WorkflowKind, task: string, runId: number): WorkflowAutomationState {
  return {
    runId,
    workflow,
    task,
    reviewerReadyAfterAgentEndCount: Number.POSITIVE_INFINITY,
    reviewerDone: false,
  };
}

export function hasPlanFile(cwd: string): boolean {
  return existsSync(join(cwd, "PLAN.md"));
}

export function extractPlanStatus(content: string): string | null {
  const match = content.match(/^- Status:\s*(.+)$/m);
  return match?.[1]?.trim() ?? null;
}

export function readPlanStatus(cwd: string): string | null {
  const path = join(cwd, "PLAN.md");
  if (!existsSync(path)) return null;
  return extractPlanStatus(readFileSync(path, "utf-8"));
}

export function shouldSpawnWorker(options: {
  automation: WorkflowAutomationState;
  config: WorkflowAutomationConfig;
  agentEndCount: number;
  planStatus: string | null;
}): boolean {
  return (
    options.automation.workflow === "plan-implement"
    && options.config.enabled
    && options.config.autoWorkerOnReady
    && !options.automation.workerId
    && options.planStatus === "READY"
    && (!options.automation.reviewerId || (
      options.automation.reviewerDone
      && options.agentEndCount >= options.automation.reviewerReadyAfterAgentEndCount
    ))
  );
}

export function buildAutomationInstruction(workflow: WorkflowKind): string {
  const lines = workflow === "plan-loop"
    ? [
        "[Subagent automation active]",
        "- A scout subagent is gathering codebase context in parallel.",
        "- A reviewer subagent will review PLAN.md after its first draft exists.",
        "- Keep the main session focused on authoring/updating PLAN.md.",
        "- When reviewer findings arrive, fold them into PLAN.md before finalizing the reviewed plan.",
      ]
    : [
        "[Subagent automation active]",
        "- A scout subagent is gathering codebase context in parallel.",
        "- A reviewer subagent will review PLAN.md after its first draft exists.",
        "- Keep the main session focused on planning/review until PLAN.md is truly READY after reviewer feedback.",
        "- Do NOT implement code directly in the main session once PLAN.md reaches READY.",
        "- The worker subagent will implement from the READY plan; the main session should supervise, replan if needed, and summarize.",
      ];

  return lines.join("\n");
}
