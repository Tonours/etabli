import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
	WORKFLOW_ROUTER_EXTENSION_VERSION,
} from "./lib/workflow-router-runtime.ts";
import { eventCwd, resolveWorkflowRouteContext } from "./lib/workflow-route-context.ts";
import { planCommitGuardDecision, planMutationGuardDecision } from "../../workflow/runtime/workflow-router-core.mjs";
import {
	appendLedgerEvent,
	inferBashFailureFromToolResult,
	isBashToolName,
	pickPrimaryActiveLedger,
	recordBashValidationFailure,
} from "./lib/ledger-auto-emit.ts";
import {
	explicitCwd,
	resolveContractPointer,
	routeDecidedExists,
	type ContractPointer,
} from "./lib/route-contract.ts";

const CUSTOM_MESSAGE_TYPE = "etabli.workflow-router";

type RoutablePi = ExtensionAPI & {
	appendEntry?: (customType: string, data?: unknown) => void;
	registerEntryRenderer?: (customType: string, renderer: unknown) => void;
};

function routedSystemPrompt(
	systemPrompt: string | undefined,
	decision: Record<string, unknown>,
	pointer: ContractPointer | null,
): string {
	const contract: Record<string, unknown> = {
		route: decision.route,
		writeAllowed: decision.writeAllowed,
		command: decision.command,
		skill: decision.skill,
		artifact: decision.artifact,
		stopCondition: decision.stopCondition,
		requiredEvidence: decision.requiredEvidence,
	};
	let mustRead = "";
	if (pointer) {
		contract.contract = { path: pointer.path, sha256: pointer.sha256, provenance: pointer.provenance };
		mustRead = ` Read ${pointer.path} (sha256 ${pointer.sha256.slice(0, 12)}) before acting on this route.`;
	}
	return `${systemPrompt || ""}\n\n<etabli-route-contract>\n${JSON.stringify(contract)}\nFollow this code-owned route contract for the current turn.${mustRead} It does not override permission, safety, READY, mutation, validation, or external-action gates.\n</etabli-route-contract>`;
}

// Best-effort issuance record: never throws, never blocks the turn. A ledger
// error must not break the agent run; the emission is evidence, not a gate.
function maybeEmitRouteDecided(
	cwd: string | null,
	decision: Record<string, unknown>,
	pointer: ContractPointer | null,
): void {
	if (!cwd) return;
	let ledger: { path: string; run: string } | null;
	try {
		ledger = pickPrimaryActiveLedger(cwd);
	} catch {
		return;
	}
	if (!ledger) return;
	const route = decision.route;
	if (typeof route !== "string") return;
	const sha = pointer?.sha256 ?? null;
	let exists = false;
	try {
		exists = routeDecidedExists(ledger.path, route, sha);
	} catch {
		return;
	}
	if (exists) return;
	try {
		appendLedgerEvent(ledger.path, "route_decided", {
			route,
			reason: `workflow-router selected ${route}`,
			...(pointer ? { contract_path: pointer.path, contract_sha256: pointer.sha256, provenance: pointer.provenance } : {}),
		}, ledger.run);
	} catch {
		return;
	}
}

export default function (pi: ExtensionAPI) {
	const routablePi = pi as RoutablePi;
	// Latest decided route awaiting ledger issuance. before_agent_start fires
	// before the run's ledger exists on first turn; agent_end retries then, so
	// single-prompt runs still record their route (dedup keeps it idempotent).
	let pendingRoute: { cwd: string; decision: Record<string, unknown>; pointer: ContractPointer | null } | null = null;

	pi.on("before_agent_start", (event, ctx) => {
		const trimmedPrompt = event.prompt.trim();
		if (trimmedPrompt === "" || trimmedPrompt.startsWith("/")) return undefined;

		const { decision } = resolveWorkflowRouteContext(event.prompt, eventCwd(event, ctx));

		routablePi.appendEntry?.(CUSTOM_MESSAGE_TYPE, {
			version: WORKFLOW_ROUTER_EXTENSION_VERSION,
			decision,
		});
		const pointer = typeof decision.skill === "string" ? resolveContractPointer(decision.skill) : null;
		const cwd = explicitCwd(event, ctx);
		maybeEmitRouteDecided(cwd, decision, pointer);
		pendingRoute = cwd ? { cwd, decision, pointer } : null;
		return pointer ? { systemPrompt: routedSystemPrompt(event.systemPrompt, decision, pointer) } : undefined;
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
				}
			} catch {
				// Never break the tool_result pipeline on ledger I/O.
			}
		}
		// Mid-turn catch-up: the run's ledger can appear (and even turn
		// terminal) between before_agent_start and agent_end. Re-attempt
		// issuance while a route is pending; dedup keeps it idempotent and
		// the picker skips terminal ledgers. agent_end retries one last time.
		if (pendingRoute) {
			try {
				maybeEmitRouteDecided(pendingRoute.cwd, pendingRoute.decision, pendingRoute.pointer);
			} catch {
				// Best effort: never break the tool_result pipeline on ledger I/O.
			}
		}
		return undefined;
	});

	pi.on("agent_end", () => {
		// Catch-up issuance for routes decided before their ledger existed.
		const pending = pendingRoute;
		pendingRoute = null;
		if (pending) {
			try {
				maybeEmitRouteDecided(pending.cwd, pending.decision, pending.pointer);
			} catch {
				// Best effort: never break the agent_end pipeline on ledger I/O.
			}
		}
	});
}
