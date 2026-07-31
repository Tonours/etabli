import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  appendWorkflowRouterGuidance,
  classifyWorkflowRoute,
  shouldInjectWorkflowRouter,
  WORKFLOW_ROUTER_EXTENSION_VERSION,
  type PlanStatus,
  type WorkflowMultiExecution,
} from "./lib/workflow-router-runtime.ts";
import { resolveDynamicKnowledgeContext } from "../../workflow/runtime/obvault-topic-resolver.mjs";
import { planMutationGuardDecision } from "../../workflow/runtime/workflow-router-core.mjs";
import {
  inferBashFailureFromToolResult,
  isBashToolName,
  recordBashValidationFailure,
} from "./lib/ledger-auto-emit.ts";

const CUSTOM_MESSAGE_TYPE = "etabli.workflow-router";

type RoutablePi = ExtensionAPI & {
  appendEntry?: (customType: string, data?: unknown) => void;
};

const ETABLI_PORTFOLIO_ROLES = new Set([
  "etabli-scout",
  "etabli-analyst",
  "etabli-challenger",
  "etabli-fallback",
  "etabli-judge",
]);
const ETABLI_PORTFOLIO_MODELS = new Set([
  "zai/glm-5.2",
  "zai/glm-5.1",
  "zai/glm-5-turbo",
  "xai/grok-4.5",
  "kimi-coding/k3",
]);

type PortfolioCallState = {
  decision: WorkflowMultiExecution | null;
  firstPassRoles: Set<string>;
  resumedRoles: Set<string>;
  resumedAgentIds: Set<string>;
  pendingInitialRoles: Map<string, string>;
  pendingResumes: Map<string, { agentId: string; role: string }>;
  agentRoles: Map<string, string>;
  completedAgentIds: Set<string>;
  failedFirstPassRoles: Set<string>;
  completedResumedRoles: Set<string>;
  fallbackCalls: number;
  adjudicationCalls: number;
};

function newPortfolioCallState(): PortfolioCallState {
  return {
    decision: null,
    firstPassRoles: new Set(),
    resumedRoles: new Set(),
    resumedAgentIds: new Set(),
    pendingInitialRoles: new Map(),
    pendingResumes: new Map(),
    agentRoles: new Map(),
    completedAgentIds: new Set(),
    failedFirstPassRoles: new Set(),
    completedResumedRoles: new Set(),
    fallbackCalls: 0,
    adjudicationCalls: 0,
  };
}

function blockPortfolioCall(reason: string) {
  return { block: true, reason: "Etabli adaptive council budget: " + reason };
}

function guardPortfolioCall(state: PortfolioCallState, toolCallId: string, input: Record<string, unknown>) {
  const role = typeof input.subagent_type === "string" ? input.subagent_type : "";
  if (!ETABLI_PORTFOLIO_ROLES.has(role)) return undefined;

  const decision = state.decision;
  if (!decision || decision.strategy === "single") {
    return blockPortfolioCall("no portfolio sidecar is admitted for the active route");
  }

  const resumed = typeof input.resume === "string" && input.resume.trim() !== "";
  if (role === "etabli-judge") {
    if (resumed) return blockPortfolioCall("the Sol adjudicator cannot be resumed");
    if (decision.budget.maxAdjudications === 0 || state.adjudicationCalls >= decision.budget.maxAdjudications) {
      return blockPortfolioCall("the adjudication call cap is exhausted");
    }
    if (state.completedResumedRoles.size < decision.budget.maxFirstPassAgents) {
      return blockPortfolioCall("Sol requires the bounded rebuttal round to finish first");
    }
    state.adjudicationCalls += 1;
    return undefined;
  }

  if (resumed) {
    const agentId = (input.resume as string).trim();
    if (decision.budget.maxResumesPerPrimary === 0) {
      return blockPortfolioCall("the selected strategy does not allow rebuttal resumes");
    }
    if (!state.firstPassRoles.has(role)) {
      return blockPortfolioCall("a role must complete an admitted first pass before resume");
    }
    if (state.resumedRoles.has(role)) {
      return blockPortfolioCall("each admitted participant may be resumed only once");
    }
    if (state.agentRoles.get(agentId) !== role) {
      return blockPortfolioCall("the resumed agent id is not bound to the requested admitted role");
    }
    if (!state.completedAgentIds.has(agentId)) {
      return blockPortfolioCall("the admitted first pass must finish before its agent id can be resumed");
    }
    if (state.resumedAgentIds.has(agentId)) {
      return blockPortfolioCall("each admitted agent id may be resumed only once");
    }
    if (state.resumedRoles.size >= decision.budget.maxFirstPassAgents) {
      return blockPortfolioCall("the total rebuttal resume cap is exhausted");
    }
    state.resumedRoles.add(role);
    state.resumedAgentIds.add(agentId);
    if (toolCallId !== "") state.pendingResumes.set(toolCallId, { agentId, role });
    return undefined;
  }

  if (role === "etabli-fallback") {
    if (state.fallbackCalls >= decision.budget.maxFallbackAgents) {
      return blockPortfolioCall("the Kimi fallback replacement cap is exhausted");
    }
    if (state.failedFirstPassRoles.size <= state.fallbackCalls) {
      return blockPortfolioCall("Kimi is a replacement and requires an observed failed primary first pass");
    }
    state.fallbackCalls += 1;
    state.firstPassRoles.add(role);
    if (toolCallId !== "") state.pendingInitialRoles.set(toolCallId, role);
    return undefined;
  }

  if (!decision.roles.includes(role)) {
    return blockPortfolioCall("role " + role + " is not selected by the active " + decision.strategy + " strategy");
  }
  if (state.firstPassRoles.has(role) || state.firstPassRoles.size - state.fallbackCalls >= decision.budget.maxFirstPassAgents) {
    return blockPortfolioCall("the selected first-pass call cap is exhausted");
  }
  state.firstPassRoles.add(role);
  if (toolCallId !== "") state.pendingInitialRoles.set(toolCallId, role);
  return undefined;
}

function recordPortfolioAgentResult(
  state: PortfolioCallState,
  toolCallId: string,
  details: unknown,
  isError: boolean,
) {
  const pendingResume = state.pendingResumes.get(toolCallId);
  if (pendingResume) {
    state.pendingResumes.delete(toolCallId);
    if (isError || typeof details !== "object" || details === null) return;
    const result = details as { agentId?: unknown; subagentType?: unknown; status?: unknown };
    if (
      result.agentId === pendingResume.agentId
      && result.subagentType === pendingResume.role
      && (result.status === "completed" || result.status === "steered")
    ) {
      state.completedResumedRoles.add(pendingResume.role);
    }
    return;
  }

  const expectedRole = state.pendingInitialRoles.get(toolCallId);
  if (!expectedRole) return;
  state.pendingInitialRoles.delete(toolCallId);
  if (isError || typeof details !== "object" || details === null) {
    if (expectedRole !== "etabli-fallback") state.failedFirstPassRoles.add(expectedRole);
    return;
  }

  const result = details as { agentId?: unknown; subagentType?: unknown; status?: unknown };
  if (
    typeof result.agentId === "string"
    && result.agentId.trim() !== ""
    && result.subagentType === expectedRole
  ) {
    const agentId = result.agentId.trim();
    state.agentRoles.set(agentId, expectedRole);
    if (result.status === "completed" || result.status === "steered") {
      state.completedAgentIds.add(agentId);
    } else if (
      expectedRole !== "etabli-fallback"
      && (result.status === "error" || result.status === "stopped" || result.status === "aborted")
    ) {
      state.failedFirstPassRoles.add(expectedRole);
    }
  }
}

function textFromToolResult(content: unknown): string {
  if (!Array.isArray(content)) return "";
  return content
    .filter((item): item is { type: "text"; text: string } => (
      typeof item === "object"
      && item !== null
      && (item as { type?: unknown }).type === "text"
      && typeof (item as { text?: unknown }).text === "string"
    ))
    .map((item) => item.text)
    .join("\n");
}

function recordPortfolioRetrieval(
  state: PortfolioCallState,
  input: Record<string, unknown>,
  content: unknown,
  isError: boolean,
) {
  if (isError || typeof input.agent_id !== "string") return;
  const agentId = input.agent_id.trim();
  const role = state.agentRoles.get(agentId);
  if (!role) return;
  const status = textFromToolResult(content).match(/\bStatus:\s*([a-z-]+)/i)?.[1]?.toLowerCase();
  if (!status || status === "running" || status === "queued" || status === "background") return;
  if (status === "error" || status === "stopped" || status === "aborted") {
    state.completedAgentIds.delete(agentId);
    if (role !== "etabli-fallback") state.failedFirstPassRoles.add(role);
    return;
  }
  state.completedAgentIds.add(agentId);
}

function portfolioTaskRole(input: Record<string, unknown>): string {
  if (typeof input.agentType === "string") return input.agentType;
  if (typeof input.metadata !== "object" || input.metadata === null) return "";
  const metadata = input.metadata as Record<string, unknown>;
  return typeof metadata.agentType === "string" ? metadata.agentType : "";
}

function guardPortfolioTaskCall(toolName: string, input: Record<string, unknown>) {
  if ((toolName === "TaskCreate" || toolName === "TaskUpdate") && ETABLI_PORTFOLIO_ROLES.has(portfolioTaskRole(input))) {
    return blockPortfolioCall("portfolio roles must use the guarded Agent surface, not Task RPC");
  }
  if (toolName === "TaskExecute" && typeof input.model === "string" && ETABLI_PORTFOLIO_MODELS.has(input.model)) {
    return blockPortfolioCall("portfolio model overrides are not admitted through Task RPC");
  }
  return undefined;
}

function readPlanStatus(cwd: string): PlanStatus {
  try {
    const content = readFileSync(resolve(cwd, "PLAN.md"), "utf-8");
    const match = content.match(/^\s*-\s*Status:\s*(DRAFT|CHALLENGED|READY)\s*$/im);
    return match ? (match[1].toLowerCase() as PlanStatus) : "unknown";
  } catch {
    return "missing";
  }
}

function eventCwd(event: unknown): string {
  if (typeof event === "object" && event !== null && "cwd" in event) {
    const cwd = (event as { cwd?: unknown }).cwd;
    if (typeof cwd === "string" && cwd.trim() !== "") return cwd;
  }
  if (typeof process.cwd === "function") return process.cwd();
  return ".";
}

function promptPlanStatusFallback(prompt: string): PlanStatus {
  if (/\bdraft\b|brouillon/i.test(prompt)) return "draft";
  if (/\bchallenged\b|bloqu[eé]|challenge/i.test(prompt)) return "challenged";
  return "unknown";
}

export default function (pi: ExtensionAPI) {
  const routablePi = pi as RoutablePi;
  let portfolioCallState = newPortfolioCallState();

  pi.on("before_agent_start", (event) => {
    if (!shouldInjectWorkflowRouter(event.prompt)) return undefined;
    portfolioCallState = newPortfolioCallState();

    const planStatus = readPlanStatus(eventCwd(event));
    const routeContext = {
      planStatus: planStatus === "missing" ? promptPlanStatusFallback(event.prompt) : planStatus,
      hasTaskTools: pi.getActiveTools().some((toolName) => toolName.startsWith("Task")),
      hasAgentTools: ["Agent", "get_subagent_result"].every((toolName) => pi.getActiveTools().includes(toolName)),
    };
    let decision = classifyWorkflowRoute(event.prompt, routeContext);
    if (!decision.knowledgeContext) {
      decision = classifyWorkflowRoute(event.prompt, {
        ...routeContext,
        dynamicKnowledgeContext: resolveDynamicKnowledgeContext(event.prompt) ?? undefined,
      });
    }
    portfolioCallState.decision = decision.multiExecution;

    routablePi.appendEntry?.(CUSTOM_MESSAGE_TYPE, {
      version: WORKFLOW_ROUTER_EXTENSION_VERSION,
      decision,
    });

    if (decision.route === "answer" && !decision.knowledgeContext) return undefined;

    return {
      systemPrompt: appendWorkflowRouterGuidance(event.systemPrompt, decision),
    };
  });

  pi.on("tool_call", (event) => {
    if (event.toolName === "Agent") {
      return guardPortfolioCall(portfolioCallState, event.toolCallId, event.input);
    }
    const portfolioBlock = guardPortfolioTaskCall(event.toolName, event.input);
    if (portfolioBlock) return portfolioBlock;

    // READY mutation + check-freeze parity with Claude plan-ready-guard
    // (shared planMutationGuardDecision; no divergent classifier).
    const mutationGuard = planMutationGuardDecision({
      cwd: eventCwd(event),
      tool_name: event.toolName,
      tool_input: event.input || {},
    }) as { hookSpecificOutput?: { permissionDecision?: string; permissionDecisionReason?: string } } | null;
    if (mutationGuard?.hookSpecificOutput?.permissionDecision === "deny") {
      return {
        block: true,
        reason:
          mutationGuard.hookSpecificOutput.permissionDecisionReason ||
          "PLAN.md guard: mutating tools are blocked",
      };
    }
    return undefined;
  });

  pi.on("tool_result", (event) => {
    if (event.toolName === "Agent") {
      recordPortfolioAgentResult(
        portfolioCallState,
        event.toolCallId,
        (event as { details?: unknown }).details,
        event.isError,
      );
    } else if (event.toolName === "get_subagent_result") {
      recordPortfolioRetrieval(portfolioCallState, event.input, event.content, event.isError);
    } else if (isBashToolName(event.toolName)) {
      // Ledger-scoped auto-emit: only when an active non-terminal ledger exists.
      try {
        const inferred = inferBashFailureFromToolResult(event.content, Boolean(event.isError));
        if (inferred.failed && typeof inferred.exit === "number") {
          const command = String(
            (event.input as { command?: string; cmd?: string } | undefined)?.command ||
              (event.input as { command?: string; cmd?: string } | undefined)?.cmd ||
              "bash",
          );
          recordBashValidationFailure(eventCwd(event), {
            command,
            exit: inferred.exit,
            failure: inferred.failure || `exit ${inferred.exit}`,
          });
        }
      } catch {
        // Never break the tool_result pipeline on ledger I/O.
      }
    }
    return undefined;
  });

  pi.on("agent_end", () => {
    portfolioCallState = newPortfolioCallState();
  });
}
