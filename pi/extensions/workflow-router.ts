import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
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
	registerUserPrompt,
} from "./lib/ledger-auto-emit.ts";
import { explicitCwd, routeDecidedExists } from "./lib/route-contract.ts";

const CUSTOM_MESSAGE_TYPE = "etabli.workflow-router";

type RoutablePi = ExtensionAPI & {
	appendEntry?: (customType: string, data?: unknown) => void;
	registerEntryRenderer?: (customType: string, renderer: unknown) => void;
};

function maybeEmitRouteDecided(cwd: string | null, decision: Record<string, unknown>): void {
	if (!cwd) return;
	let ledger: { path: string; run: string } | null;
	try {
		ledger = pickPrimaryActiveLedger(cwd);
	} catch {
		return;
	}
	if (!ledger) return;
	const route = decision.route;
	if (typeof route !== "string" || routeDecidedExists(ledger.path, route)) return;
	try {
		appendLedgerEvent(ledger.path, "route_decided", { route, reason: `workflow-router selected ${route}` }, ledger.run);
	} catch {
		return;
	}
}

export default function (pi: ExtensionAPI) {
	const routablePi = pi as RoutablePi;
	// Latest decided route awaiting ledger issuance. before_agent_start fires
	// before the run's ledger exists on first turn; agent_end retries then, so
	// single-prompt runs still record their route (dedup keeps it idempotent).
	let pendingRoute: { cwd: string; decision: Record<string, unknown> } | null = null;

	pi.on("input", (event, ctx) => {
		if (event.source !== "interactive") return undefined;
		let sessionId: string | null = null;
		try {
			sessionId =
				ctx?.sessionManager?.getSessionId?.() ||
				process.env.PI_SESSION_ID ||
				null;
		} catch {
			sessionId = process.env.PI_SESSION_ID || null;
		}
		if (!sessionId) return undefined;
		const cwd = eventCwd(event, ctx);
		try {
			registerUserPrompt(cwd, sessionId, "pi", event.text, (ledgerPath, run, detail) => {
				const eventCli = join(cwd, "scripts", "workflow-event");
				if (!existsSync(eventCli)) return false;
				const dir = dirname(dirname(ledgerPath));
				const result = spawnSync(
					eventCli,
					["--dir", dir, "append", run, "correction", JSON.stringify(detail)],
					{ cwd, encoding: "utf8", timeout: 4000 },
				);
				return result.status === 0;
			});
		} catch {
			return undefined;
		}
		return undefined;
	});

	pi.on("before_agent_start", (event, ctx) => {
		const trimmedPrompt = event.prompt.trim();
		if (trimmedPrompt === "" || trimmedPrompt.startsWith("/")) return undefined;

		const { decision } = resolveWorkflowRouteContext(event.prompt, eventCwd(event, ctx));

		routablePi.appendEntry?.(CUSTOM_MESSAGE_TYPE, {
			version: WORKFLOW_ROUTER_EXTENSION_VERSION,
			decision,
		});
		const cwd = explicitCwd(event, ctx);
		maybeEmitRouteDecided(cwd, decision);
		pendingRoute = cwd ? { cwd, decision } : null;
		return undefined;
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
				maybeEmitRouteDecided(pendingRoute.cwd, pendingRoute.decision);
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
				maybeEmitRouteDecided(pending.cwd, pending.decision);
			} catch {
				// Best effort: never break the agent_end pipeline on ledger I/O.
			}
		}
	});
}
