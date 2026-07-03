import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { existsSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import {
  appendTaskLoopGuidance,
  decideAutoContinue,
  detectTaskRuntimeCapabilityIssue,
  parseTaskToolResult,
  shouldInjectTaskLoop,
  TASK_TILL_DONE_CONTINUE_PROMPT,
  TASK_TILL_DONE_COMPLETION_EVIDENCE_PROMPT,
  TASK_TILL_DONE_EXTENSION_VERSION,
  TASK_TILL_DONE_VALIDATION_PROMPT,
  TASK_TOOL_NAMES,
  type TaskListSummary,
  type TaskRuntimeCapabilityIssue,
  type ImplementationRuntimeEvidence,
} from "./lib/tasks-till-done-runtime.ts";
import { classifyWorkflowRoute, type WorkflowRoute } from "./lib/workflow-router-runtime.ts";

const CUSTOM_MESSAGE_TYPE = "etabli.tasks-till-done";
const MAX_AUTO_CONTINUES = 12;
const MAX_STALLED_REPEATS = 2;

type SendablePi = ExtensionAPI & {
  sendMessage?: <T = unknown>(
    message: {
      customType: string;
      content: string;
      display: boolean;
      details?: T;
    },
    options?: { triggerTurn?: boolean },
  ) => void;
};

function textFromContent(content: Array<{ type: string; text?: string }>): string {
  return content
    .filter((item): item is { type: "text"; text: string } => item.type === "text" && typeof item.text === "string")
    .map((item) => item.text)
    .join("\n");
}

function hasImplementedPlanArchive(cwd: string, startedAtMs: number): boolean {
  try {
    return readdirSync(join(cwd, "docs", "plan")).some((name) => {
      if (!name.endsWith(".md") || name === "README.md") return false;
      return statSync(join(cwd, "docs", "plan", name)).mtimeMs >= startedAtMs - 1000;
    });
  } catch {
    return false;
  }
}

function getImplementationRuntimeEvidence(cwd: string, startedAtMs: number): ImplementationRuntimeEvidence {
  return {
    hasImplementedPlanArchive: hasImplementedPlanArchive(cwd, startedAtMs),
    rootPlanDeleted: !existsSync(join(cwd, "PLAN.md")),
  };
}

export default function (pi: ExtensionAPI) {
  const sendablePi = pi as SendablePi;
  let active = false;
  let taskToolUsedThisRun = false;
  let lastSummary: TaskListSummary | undefined;
  let lastSignature = "";
  let stalledCount = 0;
  let autoContinueCount = 0;
  let workflowRoute: WorkflowRoute = "answer";
  let validationRequired = false;
  let implementationCompletionRequired = false;
  let currentCwd = ".";
  let taskLoopStartedAtMs = 0;
  let runtimeCapabilityIssue: TaskRuntimeCapabilityIssue | undefined;

  pi.on("before_agent_start", (event) => {
    taskToolUsedThisRun = false;
    const isExtensionContinuation = event.prompt.includes(TASK_TILL_DONE_CONTINUE_PROMPT.slice(0, 24));

    if (!isExtensionContinuation) {
      autoContinueCount = 0;
      stalledCount = 0;
      lastSummary = undefined;
      lastSignature = "";
      workflowRoute = classifyWorkflowRoute(event.prompt).route;
      const eventCwd = (event as { cwd?: unknown }).cwd;
      currentCwd = typeof eventCwd === "string" && eventCwd.trim() !== ""
        ? eventCwd
        : process.cwd?.() ?? ".";
      taskLoopStartedAtMs = Date.now();
      validationRequired = workflowRoute === "implement" || workflowRoute === "plan-implement";
      implementationCompletionRequired = workflowRoute === "implement" || workflowRoute === "plan-implement";
      runtimeCapabilityIssue = undefined;
    }

    if (!shouldInjectTaskLoop(event.prompt, pi.getActiveTools())) return undefined;

    active = true;
    return {
      systemPrompt: appendTaskLoopGuidance(event.systemPrompt),
    };
  });

  pi.on("tool_result", (event) => {
    if (!TASK_TOOL_NAMES.has(event.toolName)) return undefined;

    active = true;
    taskToolUsedThisRun = true;

    const text = textFromContent(event.content);
    runtimeCapabilityIssue = detectTaskRuntimeCapabilityIssue(event.toolName, text) ?? runtimeCapabilityIssue;

    if (event.toolName !== "TaskList") return undefined;

    const summary = parseTaskToolResult({
      details: (event as { details?: unknown }).details,
      text,
    });
    if (!summary) return undefined;

    if (summary.signature === lastSignature) {
      stalledCount += 1;
    } else {
      stalledCount = 0;
      lastSignature = summary.signature;
    }

    lastSummary = summary;
    return undefined;
  });

  pi.on("agent_end", () => {
    const implementationRuntimeEvidence = implementationCompletionRequired
      ? getImplementationRuntimeEvidence(currentCwd, taskLoopStartedAtMs)
      : undefined;
    const decision = decideAutoContinue({
      active,
      taskToolUsed: taskToolUsedThisRun,
      summary: lastSummary,
      autoContinueCount,
      maxAutoContinues: MAX_AUTO_CONTINUES,
      stalledCount,
      maxStalledRepeats: MAX_STALLED_REPEATS,
      validationRequired,
      implementationCompletionRequired,
      implementationRuntimeEvidence,
      runtimeCapabilityIssue,
    });

    taskToolUsedThisRun = false;

    if (!decision.continue) {
      if (decision.reason === "complete" || decision.reason === "blocked" || decision.reason === "limit" || decision.reason === "stalled" || decision.reason === "runtime_capability_blocked") {
        if (decision.reason === "blocked" || decision.reason === "limit" || decision.reason === "stalled" || decision.reason === "runtime_capability_blocked") {
          sendablePi.sendMessage?.(
            {
              customType: CUSTOM_MESSAGE_TYPE,
              content: `Task loop stopped: ${decision.reason}`,
              display: true,
              details: { reason: decision.reason, workflowRoute, summary: lastSummary, runtimeCapabilityIssue, implementationRuntimeEvidence },
            },
            { triggerTurn: false },
          );
        }
        active = false;
      }
      return undefined;
    }

    autoContinueCount += 1;
    sendablePi.appendEntry(CUSTOM_MESSAGE_TYPE, {
      version: TASK_TILL_DONE_EXTENSION_VERSION,
      reason: decision.reason,
      autoContinueCount,
      workflowRoute,
      summary: lastSummary,
      implementationRuntimeEvidence,
    });
    sendablePi.sendMessage?.(
      {
        customType: CUSTOM_MESSAGE_TYPE,
        content: `Task loop continue (${decision.reason})`,
        display: false,
        details: { reason: decision.reason, autoContinueCount, workflowRoute, implementationRuntimeEvidence },
      },
      { triggerTurn: false },
    );
    const followUpPrompt = decision.reason === "completion_evidence_required"
      ? TASK_TILL_DONE_COMPLETION_EVIDENCE_PROMPT
      : decision.reason === "validation_required"
        ? TASK_TILL_DONE_VALIDATION_PROMPT
        : TASK_TILL_DONE_CONTINUE_PROMPT;

    pi.sendUserMessage(followUpPrompt, { deliverAs: "followUp" });
    return undefined;
  });
}
