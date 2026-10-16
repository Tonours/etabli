import { describe, beforeAll, afterAll, expect, test } from "bun:test";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import workflowRouter from "../workflow-router.ts";

type Handler = (
	event: Record<string, unknown>,
	ctx?: Record<string, unknown>,
) => unknown;

// Minimal `obvault route` stub (same JSON contract as
// tests/fixtures/obvault-meta/obvault) as a /bin/sh script: each spawn costs
// ~5ms instead of a ~45ms node startup.
const ROUTE_STUB = `#!/bin/sh
set -eu
if [ "\${1:-}" != "route" ] || [ "\${2:-}" != "--json" ]; then
  exit 1
fi
prompt="\${3-}"
if case "$prompt" in (*[Ff][Ii][Nn][Oo][Pp][Ss]*) true;; (*) false;; esac && [ -f "\${OBVAULT_ROOT:-/nonexistent}/kb/finops-cost-controls.md" ]; then
  printf '%s\\n' '{"abstained":false,"topics":["finops"],"query":"finops aws billing controls cloud cost","matched_notes":[{"path":"kb/finops-cost-controls.md"}]}'
else
  printf '%s\\n' '{"abstained":true,"topics":[],"query":"","matched_notes":[]}'
fi
`;

function writeRouteStub(root: string) {
	mkdirSync(join(root, "_meta"), { recursive: true });
	writeFileSync(join(root, "_meta", "obvault"), ROUTE_STUB, { mode: 0o755 });
	chmodSync(join(root, "_meta", "obvault"), 0o755);
}

function validReadyPlanText() {
	return [
		"# PLAN.md", "", "## Meta", "- Status: READY",
		"## Goal", "- Exercise the guard.",
		"## Workflow Contract", "- Route: implement", "- Role: implementer",
		"- Stop condition: fixture passes", "- Required evidence: smoke output",
		"## Acceptance Criteria", "- Guard follows the READY contract.",
		"## Scope", "- In: guard fixture", "- Out: product code",
		"## Facts And Assumptions", "- Observed: temporary fixture", "- Assumptions: none",
		"## Requirement Trace", "- Request -> fixture state -> no material gap -> guard output",
		"## Steps", "1. Exercise the guard.",
		"## Checks", "- command: bash tests/a.sh",
		"## Risks", "- None.", "## Open Questions", "- None", "",
	].join("\n");
}

function setupExtension(
	activeTools = ["TaskCreate", "TaskList", "Agent", "get_subagent_result"],
	initialThinkingLevel?: string,
) {
	const handlers = new Map<string, Handler[]>();
	const entries: unknown[] = [];
	const renderers = new Map<string, unknown>();
	let thinkingLevel = initialThinkingLevel;
	const thinkingChanges: string[] = [];

	const pi = {
		on(eventName: string, handler: Handler) {
			handlers.set(eventName, [...(handlers.get(eventName) ?? []), handler]);
		},
		getActiveTools() {
			return activeTools;
		},
		appendEntry(_customType: string, data?: unknown) {
			entries.push(data);
		},
		registerEntryRenderer(customType: string, renderer: unknown) {
			renderers.set(customType, renderer);
		},
		getThinkingLevel() {
			return thinkingLevel;
		},
		setThinkingLevel(level: string) {
			thinkingChanges.push(level);
			thinkingLevel = level;
		},
	};

	workflowRouter(pi as unknown as Parameters<typeof workflowRouter>[0]);

	return {
		entries,
		renderers,
		thinkingChanges,
		get thinkingLevel() {
			return thinkingLevel;
		},
		emit(
			eventName: string,
			event: Record<string, unknown>,
			ctx?: Record<string, unknown>,
		) {
			return (handlers.get(eventName) ?? []).map((handler) => handler(event, ctx));
		},
		async emitAsync(
			eventName: string,
			event: Record<string, unknown>,
			ctx?: Record<string, unknown>,
		) {
			return Promise.all(
				(handlers.get(eventName) ?? []).map((handler) => handler(event, ctx)),
			);
		},
	};
}

describe("workflow router extension", () => {
	// Hermeticity: default-root discovery would find the developer's real
	// ~/work/obvault vault and spawn its node-based `_meta/obvault route`
	// binary once per before_agent_start emit (~100ms each), making the suite
	// both slow and environment-dependent. Point OBVAULT_ROOT at an opted-out
	// path (exclusive semantics, see obvault-topic-resolver tests) so routing
	// behaves exactly as on a machine without a vault. The dedicated dynamic
	// test below overrides this with its own fixture root.
	const previousObvaultRoot = process.env.OBVAULT_ROOT;
	beforeAll(() => {
		process.env.OBVAULT_ROOT = "/nonexistent-obvault-for-tests";
	});
	afterAll(() => {
		if (previousObvaultRoot === undefined) delete process.env.OBVAULT_ROOT;
		else process.env.OBVAULT_ROOT = previousObvaultRoot;
	});

	test("uses actual PLAN.md status before routing to implement", () => {
		const runtime = setupExtension();
		const cwd = mkdtempSync(join(tmpdir(), "etabli-ready-plan-"));

		try {
			writeFileSync(
				join(cwd, "PLAN.md"),
				validReadyPlanText(),
			);

			const results = runtime.emit("before_agent_start", {
				prompt: "Implémente le PLAN.md ready",
				systemPrompt: "Base prompt",
				cwd,
			});

			expect(results).toEqual([undefined]);
			expect(runtime.entries[0]).toMatchObject({
				decision: { route: "implement" },
			});
		} finally {
			rmSync(cwd, { recursive: true, force: true });
		}
	});

	test("does not resume a plan cycle from a non-plan draft mention", () => {
		const runtime = setupExtension();
		const cwd = mkdtempSync(join(tmpdir(), "etabli-draft-word-"));

		try {
			const results = runtime.emit("before_agent_start", {
				prompt: "Corrige le bug du brouillon d'email dans le composeur",
				systemPrompt: "Base prompt",
				cwd,
			});

			expect(runtime.entries[0]).toMatchObject({
				decision: {
					route: "answer",
					writeAllowed: true,
				},
			});
			expect(results[0]).toBeUndefined();
		} finally {
			rmSync(cwd, { recursive: true, force: true });
		}
	});

	test("resumes the plan cycle only when the draft word is tied to the plan", () => {
		const runtime = setupExtension();
		const cwd = mkdtempSync(join(tmpdir(), "etabli-draft-plan-"));

		try {
			runtime.emit("before_agent_start", {
				prompt: "Le plan est encore en brouillon, améliore-le puis corrige le bug",
				systemPrompt: "Base prompt",
				cwd,
			});

			expect(runtime.entries[0]).toMatchObject({
				decision: { route: "plan-implement" },
			});
		} finally {
			rmSync(cwd, { recursive: true, force: true });
		}
	});

	test("english plan-verb and compound tokens do not resume a plan cycle", () => {
		const runtime = setupExtension();
		const cwd = mkdtempSync(join(tmpdir(), "etabli-plan-verb-"));

		try {
			runtime.emit("before_agent_start", {
				prompt: "We plan to fix the email draft in the composer",
				systemPrompt: "Base prompt",
				cwd,
			});
			expect(runtime.entries[0]).toMatchObject({
				decision: { route: "answer", writeAllowed: true },
			});

			runtime.emit("before_agent_start", {
				prompt: "Fix the draft comment in plan-implement.md docs",
				systemPrompt: "Base prompt",
				cwd,
			});
			// Mentioning the plan-implement token routes via the classifier's
			// autonomous pattern (intended: naming the command invokes it) — the
			// fallback must NOT be the reason (no "active plan cycle" resume).
			expect(runtime.entries[1]).toMatchObject({
				decision: { route: "plan-implement" },
			});
			expect(
				String(
					(runtime.entries[1] as { decision?: { reason?: string } }).decision
						?.reason,
				),
			).not.toMatch(/active plan cycle/);
		} finally {
			rmSync(cwd, { recursive: true, force: true });
		}
	});

	test("plural plan-blocked wording still resumes the plan cycle", () => {
		const runtime = setupExtension();
		const cwd = mkdtempSync(join(tmpdir(), "etabli-bloques-plan-"));

		try {
			runtime.emit("before_agent_start", {
				prompt: "Les étapes du plan sont bloquées, corrige-les",
				systemPrompt: "Base prompt",
				cwd,
			});

			expect(runtime.entries[0]).toMatchObject({
				decision: { route: "plan-implement" },
			});
		} finally {
			rmSync(cwd, { recursive: true, force: true });
		}
	});

	test("does not route prompt-only READY wording directly to implement", () => {
		const runtime = setupExtension();
		const cwd = mkdtempSync(join(tmpdir(), "etabli-missing-plan-"));

		try {
			const results = runtime.emit("before_agent_start", {
				prompt: "Implémente le PLAN.md ready",
				systemPrompt: "Base prompt",
				cwd,
			});

			expect(results).toEqual([undefined]);
			expect(runtime.entries[0]).toMatchObject({
				decision: { route: "plan-implement" },
			});
		} finally {
			rmSync(cwd, { recursive: true, force: true });
		}
	});

	test("does not route read-only READY plan prompts to implementation even with READY PLAN.md", () => {
		const runtime = setupExtension();
		const cwd = mkdtempSync(join(tmpdir(), "etabli-read-ready-plan-"));

		try {
			writeFileSync(join(cwd, "PLAN.md"), validReadyPlanText());

			const results = runtime.emit("before_agent_start", {
				prompt: "Résume le PLAN.md ready",
				systemPrompt: "Base prompt",
				cwd,
			});

			expect(results).toEqual([undefined]);
			expect(runtime.entries[0]).toMatchObject({
				decision: { route: "answer", writeAllowed: false },
			});
		} finally {
			rmSync(cwd, { recursive: true, force: true });
		}
	});

	test("skips explicit slash commands", () => {
		const runtime = setupExtension();

		const results = runtime.emit("before_agent_start", {
			prompt: "/skill:implement",
			systemPrompt: "Base prompt",
		});

		expect(results).toEqual([undefined]);
		expect(runtime.entries).toEqual([]);
	});

	test("resolves Obvault knowledge context for a topic-aware answer", () => {
		const runtime = setupExtension();
		const results = runtime.emit("before_agent_start", {
			prompt: "Donne-moi des idées de SaaS",
			systemPrompt: "Base prompt",
		});

		expect(results[0]).toBeUndefined();
		expect(runtime.entries[0]).toMatchObject({
			version: "0.7.0",
			decision: {
				route: "answer",
				knowledgeContext: { topics: ["saas"] },
				multiExecution: {
					mode: "single",
					strategy: "single",
					writer: "parent-only",
					reason: "multi-model portfolio removed",
				},
			},
		});
	});

	test("preserves selected thinking across heavy routes and subsequent turns", () => {
		for (const level of ["off", "low", "medium", "high", "xhigh"]) {
			const runtime = setupExtension(undefined, level);
			for (const prompt of [
				"Analyse ce bug depuis le ticket Linear",
				"Peux tu me donner un résumé ?",
				"audit sécurité de la PR 42",
				"Continue the Task Loop. Analyse ce bug depuis le ticket Linear",
				"/adversary",
				"/pr-review",
			]) {
				runtime.emit("before_agent_start", { prompt, systemPrompt: "Base prompt" });
				expect(runtime.thinkingLevel).toBe(level);
			}
			expect(runtime.thinkingChanges).toEqual([]);
		}
	});

	test("leaves the user thinking level untouched on other routes", () => {
		for (const prompt of [
			"Peux tu me donner un résumé ?",
			"Implémente le plan READY",
		]) {
			const runtime = setupExtension();
			runtime.emit("before_agent_start", { prompt, systemPrompt: "Base prompt" });
			expect(runtime.thinkingLevel).toBeUndefined();
		}
	});

	test("never overrides thinking on task-loop auto-continues", () => {
		const runtime = setupExtension();
		runtime.emit("before_agent_start", {
			prompt: "Continue the Task Loop. Analyse ce bug depuis le ticket Linear",
			systemPrompt: "Base prompt",
		});
		expect(runtime.thinkingLevel).toBeUndefined();
	});

	test("keeps unrelated answers free of router injection", () => {
		const runtime = setupExtension();
		const results = runtime.emit("before_agent_start", {
			prompt: "Bonjour, comment vas-tu ?",
			systemPrompt: "Base prompt",
		});

		expect(results).toEqual([undefined]);
		expect(runtime.entries[0]).toMatchObject({ decision: { route: "answer" } });
	});

	test("does not throw when the optional entry surface is absent", () => {
		const handlers = new Map<string, Handler[]>();
		const pi = {
			on(eventName: string, handler: Handler) {
				handlers.set(eventName, [...(handlers.get(eventName) ?? []), handler]);
			},
			getActiveTools() {
				return ["Agent"];
			},
		};
		workflowRouter(pi as unknown as Parameters<typeof workflowRouter>[0]);

		expect(() =>
			(handlers.get("before_agent_start") ?? []).map((handler) =>
				handler({
					prompt: "Donne-moi des idées de SaaS",
					systemPrompt: "Base prompt",
				}),
			),
		).not.toThrow();
	});

	test("injects a newly discovered Obvault metadata topic", () => {
		const runtime = setupExtension();
		const root = mkdtempSync(join(tmpdir(), "etabli-pi-dynamic-vault-"));
		const previousRoot = process.env.OBVAULT_ROOT;

		try {
			mkdirSync(join(root, "kb"));
			mkdirSync(join(root, "ref"));
			writeFileSync(join(root, "AGENTS.md"), "# Test vault\n");
			writeFileSync(
				join(root, "kb/_index.md"),
				"# Index\n\n- [[finops-cost-controls]]\n",
			);
			writeFileSync(
				join(root, "kb/finops-cost-controls.md"),
				`---
type: synthesis
status: verified
summary: "Cloud cost controls."
sources:
  - "repo:billing.md"
created: 2026-07-10
updated: 2026-07-10
tags:
  - finops
---
# FinOps Cost Controls
`,
			);
			writeRouteStub(root);
			process.env.OBVAULT_ROOT = root;

			const results = runtime.emit("before_agent_start", {
				prompt: "Donne-moi des idées FinOps",
				systemPrompt: "Base prompt",
			});

			expect(results[0]).toBeUndefined();
			expect(runtime.entries[0]).toMatchObject({
				decision: {
					route: "answer",
					knowledgeContext: {
						source: "obvault-metadata",
						topics: ["finops"],
						matchedNotes: ["kb/finops-cost-controls.md"],
					},
				},
			});
		} finally {
			if (previousRoot === undefined) delete process.env.OBVAULT_ROOT;
			else process.env.OBVAULT_ROOT = previousRoot;
			rmSync(root, { recursive: true, force: true });
		}
	});

	test("allows write while PLAN is READY", () => {
		const runtime = setupExtension(["Write", "Bash"]);
		const cwd = mkdtempSync(join(tmpdir(), "etabli-ready-guard-"));
		try {
			writeFileSync(join(cwd, "PLAN.md"), validReadyPlanText());
			const writeAllow = runtime.emit("tool_call", {
				toolName: "Write",
				toolCallId: "1",
				cwd,
				input: { file_path: join(cwd, "src/x.ts"), content: "x" },
			});
			expect(writeAllow[0]).toBeUndefined();
		} finally {
			rmSync(cwd, { recursive: true, force: true });
		}
	});

});

