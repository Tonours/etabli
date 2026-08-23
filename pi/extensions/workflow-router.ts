import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import {
	classifyWorkflowRoute,
	WORKFLOW_ROUTER_EXTENSION_VERSION,
	type PlanStatus,
} from "./lib/workflow-router-runtime.ts";
import { resolveDynamicKnowledgeContext } from "../../workflow/runtime/obvault-topic-resolver.mjs";
import { planMutationGuardDecision } from "../../workflow/runtime/workflow-router-core.mjs";
import {
	inferBashFailureFromToolResult,
	isBashToolName,
	isLikelyValidationCommand,
	recordBashValidationFailure,
	recordBashValidationReceipt,
} from "./lib/ledger-auto-emit.ts";
import { maybeEmitOutcomeMetric } from "./lib/outcome-metric-emit.ts";

const CUSTOM_MESSAGE_TYPE = "etabli.workflow-router";

type RoutablePi = ExtensionAPI & {
	appendEntry?: (customType: string, data?: unknown) => void;
	registerEntryRenderer?: (customType: string, renderer: unknown) => void;
};

function readPlanStatus(cwd: string): PlanStatus {
	try {
		const content = readFileSync(resolve(cwd, "PLAN.md"), "utf-8");
		const match = content.match(
			/^\s*-\s*Status:\s*(DRAFT|CHALLENGED|READY)\s*$/im,
		);
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
	// Map prompt wording to a plan status ONLY when the status word is tied
	// to the plan itself; "fix the bug in the email draft" must not resume a
	// plan cycle.
	if (planStatusWord(prompt, /\bdraft\b|brouillon/i)) return "draft";
	if (
		planStatusWord(
			prompt,
			/\bchallenged\b|challeng[eé]e?s?\b|bloqu[eé]e?s?\b|\bblocked\b/i,
		)
	)
		return "challenged";
	// "unknown" and "missing" both mean "no recognized planning lock": the
	// core router treats them equivalently (ordinary coding edits directly).
	return "unknown";
}

function planStatusWord(prompt: string, statusPattern: RegExp): boolean {
	// Co-occurrence approximation of "status word tied to the plan": a plan
	// NOUN (or PLAN.md) and the status word anywhere in the same prompt.
	// Excludes the English verb ("plan to ...") and compound tokens
	// ("plan-implement") so ordinary wording does not resume a plan cycle.
	// Deliberately loose on distance — proximity parsing would be brittle
	// for one line of routing.
	const planNoun = /\bplan\b(?![\w-])(?!\s+to\b)|(?:^|[^\w-])plan\.md\b/i;
	return planNoun.test(prompt) && statusPattern.test(prompt);
}

export default function (pi: ExtensionAPI) {
	const routablePi = pi as RoutablePi;

	pi.on("before_agent_start", (event) => {
		try {
			if (
				requiresMaxThinking(classifyWorkflowRoute(event.prompt).route) &&
				typeof pi.setThinkingLevel === "function" &&
				!/^Continue the Task Loop\./.test(event.prompt.trim())
			) {
				pi.setThinkingLevel("xhigh");
			}
		} catch {
			// Thinking-level hint is best-effort: a routing error here must not
			// block the turn.
		}

		const trimmedPrompt = event.prompt.trim();
		if (trimmedPrompt === "" || trimmedPrompt.startsWith("/")) return undefined;

		const planStatus = readPlanStatus(eventCwd(event));
		const routeContext = {
			planStatus:
				planStatus === "missing"
					? promptPlanStatusFallback(event.prompt)
					: planStatus,
			hasTaskTools: pi
				.getActiveTools()
				.some((toolName) => toolName.startsWith("Task")),
			hasAgentTools: ["Agent", "get_subagent_result"].every((toolName) =>
				pi.getActiveTools().includes(toolName),
			),
		};
		let decision = classifyWorkflowRoute(event.prompt, routeContext);
		if (!decision.knowledgeContext) {
			decision = classifyWorkflowRoute(event.prompt, {
				...routeContext,
				dynamicKnowledgeContext:
					resolveDynamicKnowledgeContext(event.prompt) ?? undefined,
			});
		}

		routablePi.appendEntry?.(CUSTOM_MESSAGE_TYPE, {
			version: WORKFLOW_ROUTER_EXTENSION_VERSION,
			decision,
		});

		return undefined;
	});

	pi.on("tool_call", (event) => {
		if (event.toolName === "Agent") return undefined;

		// READY mutation + check-freeze parity with Claude plan-ready-guard
		// (shared planMutationGuardDecision; no divergent classifier).
		const mutationGuard = planMutationGuardDecision({
			cwd: eventCwd(event),
			tool_name: event.toolName,
			tool_input: event.input || {},
		}) as {
			hookSpecificOutput?: {
				permissionDecision?: string;
				permissionDecisionReason?: string;
			};
		} | null;
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
					recordBashValidationFailure(eventCwd(event), {
						command,
						exit: inferred.exit,
						failure: inferred.failure || `exit ${inferred.exit}`,
					});
				} else if (isLikelyValidationCommand(command)) {
					// Bind observed successful validations to the active ledger as a
					// non-cryptographic runtime receipt (command hash + exit 0).
					recordBashValidationReceipt(eventCwd(event), { command });
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
			let input = 0;
			let output = 0;
			let total = 0;
			let found = false;
			for (const msg of messages) {
				if (!msg || typeof msg !== "object") continue;
				const role = (msg as { role?: unknown }).role;
				const usage = (msg as { usage?: unknown }).usage;
				if (role !== "assistant" || !usage || typeof usage !== "object") continue;
				const u = usage as Record<string, unknown>;
				const i = Number(u.input);
				const o = Number(u.output);
				const t = Number(u.totalTokens ?? u.total_tokens ?? i + o);
				if (
					!Number.isInteger(i) ||
					i < 0 ||
					!Number.isInteger(o) ||
					o < 0 ||
					!Number.isInteger(t) ||
					t < 0
				) {
					continue;
				}
				input += i;
				output += o;
				total += t;
				found = true;
			}
			if (found) {
				parentUsageAcc = parentUsageAcc
					? {
							input_tokens: parentUsageAcc.input_tokens + input,
							output_tokens: parentUsageAcc.output_tokens + output,
							total_tokens: parentUsageAcc.total_tokens + total,
						}
					: { input_tokens: input, output_tokens: output, total_tokens: total };
			}
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

const MAX_THINKING_ROUTES = new Set([
	"adversary",
	"sec-pr",
	"bug-check",
	"pr-review",
]);

function requiresMaxThinking(route: string): boolean {
	return MAX_THINKING_ROUTES.has(route);
}
