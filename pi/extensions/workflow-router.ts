import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
	WORKFLOW_ROUTER_EXTENSION_VERSION,
} from "./lib/workflow-router-runtime.ts";
import { eventCwd, resolveWorkflowRouteContext } from "./lib/workflow-route-context.ts";
import { planCommitGuardDecision, planMutationGuardDecision } from "../../workflow/runtime/workflow-router-core.mjs";
import {
	inferBashFailureFromToolResult,
	isBashToolName,
	isLikelyValidationCommand,
	recordBashValidationFailure,
	recordBashValidationReceipt,
} from "./lib/ledger-auto-emit.ts";
import { maybeEmitOutcomeMetric } from "./lib/outcome-metric-emit.ts";
import { loadSemanticPolicy, runRouteDecision } from "./lib/route-shadow.mjs";
import { accumulateAssistantUsage } from "../../scripts/lib/usage-accounting.mjs";

const CUSTOM_MESSAGE_TYPE = "etabli.workflow-router";

type RoutablePi = ExtensionAPI & {
	appendEntry?: (customType: string, data?: unknown) => void;
	registerEntryRenderer?: (customType: string, renderer: unknown) => void;
};

type WorkflowRouterHooks = {
	loadSemanticPolicy?: typeof loadSemanticPolicy;
};

function routedSystemPrompt(systemPrompt: string | undefined, decision: Record<string, unknown>): string {
	const contract = {
		route: decision.route,
		writeAllowed: decision.writeAllowed,
		command: decision.command,
		skill: decision.skill,
		artifact: decision.artifact,
		stopCondition: decision.stopCondition,
		requiredEvidence: decision.requiredEvidence,
	};
	return `${systemPrompt || ""}\n\n<etabli-route-contract>\n${JSON.stringify(contract)}\nFollow this code-owned route contract for the current turn. It does not override permission, safety, READY, mutation, validation, or external-action gates.\n</etabli-route-contract>`;
}

export default function (pi: ExtensionAPI, hooks: WorkflowRouterHooks = {}) {
	const routablePi = pi as RoutablePi;
	const semanticPolicyLoader = hooks.loadSemanticPolicy ?? loadSemanticPolicy;

	pi.on("before_agent_start", (event, ctx) => {
		const trimmedPrompt = event.prompt.trim();
		if (trimmedPrompt === "" || trimmedPrompt.startsWith("/")) return undefined;

		const { decision, routeContext } = resolveWorkflowRouteContext(event.prompt, eventCwd(event, ctx));

		let semanticPolicy;
		try {
			semanticPolicy = semanticPolicyLoader();
		} catch {
			routablePi.appendEntry?.(CUSTOM_MESSAGE_TYPE, {
				version: WORKFLOW_ROUTER_EXTENSION_VERSION,
				decision,
				semantic: { mode: "fallback", reason: "invalid_policy" },
			});
			return {
				systemPrompt: routedSystemPrompt(event.systemPrompt, decision),
			};
		}

		if (semanticPolicy.mode !== "enforced") {
			routablePi.appendEntry?.(CUSTOM_MESSAGE_TYPE, {
				version: WORKFLOW_ROUTER_EXTENSION_VERSION,
				decision,
			});
			if (semanticPolicy.mode === "shadow") {
				void runRouteDecision({
					prompt: event.prompt,
					deterministicDecision: decision,
					planStatus: routeContext.planStatus,
					cwd: eventCwd(event, ctx),
					policy: semanticPolicy,
				}).then(({ receipt }) => {
					if (!receipt) return;
					routablePi.appendEntry?.(`${CUSTOM_MESSAGE_TYPE}.shadow`, {
						version: WORKFLOW_ROUTER_EXTENSION_VERSION,
						receipt,
					});
				}).catch(() => undefined);
			}
			return semanticPolicy.mode === "disabled" ? undefined : {
				systemPrompt: routedSystemPrompt(event.systemPrompt, decision),
			};
		}

		return runRouteDecision({
			prompt: event.prompt,
			deterministicDecision: decision,
			planStatus: routeContext.planStatus,
			cwd: eventCwd(event, ctx),
			policy: semanticPolicy,
		}).then(({ selected, receipt }) => {
			routablePi.appendEntry?.(CUSTOM_MESSAGE_TYPE, {
				version: WORKFLOW_ROUTER_EXTENSION_VERSION,
				decision: selected,
				semantic: receipt ? {
					mode: "enforced",
					source: receipt.selection_source,
					reason: receipt.selection_reason,
					confidence: receipt.shadow_answer?.confidence ?? null,
				} : { mode: "enforced", source: "deterministic", reason: "no_receipt" },
			});
			if (receipt) {
				routablePi.appendEntry?.(`${CUSTOM_MESSAGE_TYPE}.decision`, {
					version: WORKFLOW_ROUTER_EXTENSION_VERSION,
					receipt,
				});
			}
			return {
				systemPrompt: routedSystemPrompt(event.systemPrompt, selected),
			};
		}).catch(() => {
			routablePi.appendEntry?.(CUSTOM_MESSAGE_TYPE, {
				version: WORKFLOW_ROUTER_EXTENSION_VERSION,
				decision,
				semantic: { mode: "fallback", reason: "runtime_error" },
			});
			return {
				systemPrompt: routedSystemPrompt(event.systemPrompt, decision),
			};
		});
	});

	pi.on("tool_call", (event, ctx) => {
		if (event.toolName === "Agent") return undefined;

		// READY mutation + check-freeze parity with Claude plan-ready-guard
		// (shared planMutationGuardDecision; no divergent classifier). Commit
		// guard parity: session PLAN.md must not be staged or committed.
		const guardEvent = {
			cwd: eventCwd(event, ctx),
			tool_name: event.toolName,
			tool_input: event.input || {},
		};
		const denied =
			planMutationGuardDecision(guardEvent) ||
			planCommitGuardDecision(guardEvent);
		if (denied?.hookSpecificOutput?.permissionDecision === "deny") {
			return {
				block: true,
				reason:
					denied.hookSpecificOutput.permissionDecisionReason ||
					"PLAN.md guard: mutating tools are blocked",
			};
		}
		return undefined;
	});

	pi.on("tool_result", (event, ctx) => {
		if (isBashToolName(event.toolName)) {
			// Ledger-scoped auto-emit: only when an active non-terminal ledger exists.
			try {
				const command = String(
					(event.input as { command?: string; cmd?: string } | undefined)?.command ||
						(event.input as { command?: string; cmd?: string } | undefined)?.cmd ||
						"bash",
				);
				const inferred = inferBashFailureFromToolResult(
					event.content,
					Boolean(event.isError),
				);
				if (inferred.failed && typeof inferred.exit === "number") {
					recordBashValidationFailure(eventCwd(event, ctx), {
						command,
						exit: inferred.exit,
						failure: inferred.failure || `exit ${inferred.exit}`,
					});
				} else if (isLikelyValidationCommand(command)) {
					// Bind observed successful validations to the active ledger as a
					// non-cryptographic runtime receipt (command hash + exit 0).
					recordBashValidationReceipt(eventCwd(event, ctx), { command });
				}
			} catch {
				// Never break the tool_result pipeline on ledger I/O.
			}
		}
		return undefined;
	});

	let parentUsageAcc: {
		input_tokens: number;
		output_tokens: number;
		total_tokens: number;
	} | null = null;

	pi.on("agent_end", (event) => {
		const messages = (event as { messages?: unknown }).messages;
		if (Array.isArray(messages)) {
			parentUsageAcc = accumulateAssistantUsage(parentUsageAcc, messages);
		}
	});

	// Prefer settled so retries/compactions do not double-count a still-running session.
	pi.on("agent_settled", async (_event, ctx) => {
		try {
			const cwd =
				typeof ctx?.cwd === "string" && ctx.cwd.trim() !== ""
					? ctx.cwd
					: process.cwd();
			const model = ctx?.model as { provider?: string; id?: string } | undefined;
			const runtime =
				model?.provider && model?.id ? `${model.provider}/${model.id}` : "pi";
			await maybeEmitOutcomeMetric(cwd, {
				parentUsage: parentUsageAcc,
				runtime,
				success_kind: "run_terminal",
			});
		} catch {
			// Never break the agent lifecycle on ledger I/O.
		} finally {
			parentUsageAcc = null;
		}
	});
}
