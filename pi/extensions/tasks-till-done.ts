import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  appendTaskLoopGuidance,
  decideAutoContinue,
  parseTaskListOutput,
  shouldInjectTaskLoop,
  TASK_TILL_DONE_CONTINUE_PROMPT,
  TASK_TILL_DONE_EXTENSION_VERSION,
  TASK_TILL_DONE_VALIDATION_PROMPT,
  TASK_TOOL_NAMES,
  type TaskListSummary,
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

  pi.on("before_agent_start", (event) => {
    taskToolUsedThisRun = false;
    const isExtensionContinuation = event.prompt.includes(TASK_TILL_DONE_CONTINUE_PROMPT.slice(0, 24));

    if (!isExtensionContinuation) {
      autoContinueCount = 0;
      stalledCount = 0;
      lastSummary = undefined;
      lastSignature = "";
      workflowRoute = classifyWorkflowRoute(event.prompt).route;
      validationRequired = workflowRoute === "implement" || workflowRoute === "plan-implement";
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

    if (event.toolName !== "TaskList") return undefined;

    const summary = parseTaskListOutput(textFromContent(event.content));
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
    const decision = decideAutoContinue({
      active,
      taskToolUsed: taskToolUsedThisRun,
      summary: lastSummary,
      autoContinueCount,
      maxAutoContinues: MAX_AUTO_CONTINUES,
      stalledCount,
      maxStalledRepeats: MAX_STALLED_REPEATS,
      validationRequired,
    });

    taskToolUsedThisRun = false;

    if (!decision.continue) {
      if (decision.reason === "complete" || decision.reason === "blocked" || decision.reason === "limit" || decision.reason === "stalled") {
        if (decision.reason === "blocked" || decision.reason === "limit" || decision.reason === "stalled") {
          sendablePi.sendMessage?.(
            {
              customType: CUSTOM_MESSAGE_TYPE,
              content: `Task loop stopped: ${decision.reason}`,
              display: true,
              details: { reason: decision.reason, workflowRoute, summary: lastSummary },
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
    });
    sendablePi.sendMessage?.(
      {
        customType: CUSTOM_MESSAGE_TYPE,
        content: `Task loop continue (${decision.reason})`,
        display: false,
        details: { reason: decision.reason, autoContinueCount, workflowRoute },
      },
      { triggerTurn: false },
    );
    pi.sendUserMessage(
      decision.reason === "validation_required" ? TASK_TILL_DONE_VALIDATION_PROMPT : TASK_TILL_DONE_CONTINUE_PROMPT,
      { deliverAs: "followUp" },
    );
    return undefined;
  });
}
