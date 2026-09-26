import { describe, beforeAll, afterAll, expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
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

			const injectedImplement = (results[0] as { systemPrompt: string }).systemPrompt;
			expect(injectedImplement).toContain("<etabli-route-contract>");
			expect(injectedImplement).toContain('"route":"implement"');
			expect(injectedImplement).toContain("implement/SKILL.md");
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

			const injectedPlan = (results[0] as { systemPrompt: string }).systemPrompt;
			expect(injectedPlan).toContain("<etabli-route-contract>");
			expect(injectedPlan).toContain('"route":"plan-implement"');
			expect(injectedPlan).toContain("plan-implement/SKILL.md");
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

	test("tool_call commit guard blocks staging a session PLAN.md", () => {
		const runtime = setupExtension();
		const cwd = mkdtempSync(join(tmpdir(), "etabli-pi-commit-guard-"));
		try {
			const commit = runtime.emit("tool_call", {
				toolName: "bash",
				toolCallId: "b-commit",
				cwd,
				input: { command: "git add PLAN.md" },
			})[0];
			expect(commit).toMatchObject({
				block: true,
				reason: expect.stringMatching(/session artifact/i),
			});

			const unrelated = runtime.emit("tool_call", {
				toolName: "bash",
				toolCallId: "b-status",
				cwd,
				input: { command: "git status --short" },
			})[0];
			expect(unrelated).toBeUndefined();
		} finally {
			rmSync(cwd, { recursive: true, force: true });
		}
	});

	test("tool_call commit guard resolves the session cwd from the handler context", () => {
		const runtime = setupExtension();
		const cwd = mkdtempSync(join(tmpdir(), "etabli-pi-commit-ctx-"));
		try {
			execFileSync("git", ["-C", cwd, "init", "-q"]);
			writeFileSync(join(cwd, "PLAN.md"), validReadyPlanText());
			execFileSync("git", ["-C", cwd, "add", "PLAN.md"]);

			// Production shape: no cwd on the event, session cwd on the context.
			const commit = runtime.emit(
				"tool_call",
				{
					toolName: "bash",
					toolCallId: "b-staged",
					input: { command: "git commit -m wip" },
				},
				{ cwd },
			)[0];
			expect(commit).toMatchObject({
				block: true,
				reason: expect.stringMatching(/staged/i),
			});
		} finally {
			rmSync(cwd, { recursive: true, force: true });
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

	test("tool_call READY guard blocks write/edit/mutating bash under DRAFT and CHALLENGED", () => {
		const runtime = setupExtension();
		const cwd = mkdtempSync(join(tmpdir(), "etabli-pi-ready-guard-"));
		try {
			writeFileSync(
				join(cwd, "PLAN.md"),
				["# PLAN.md", "", "## Meta", "- Status: DRAFT", ""].join("\n"),
			);
			const draftWrite = runtime.emit("tool_call", {
				toolName: "write",
				toolCallId: "w1",
				cwd,
				input: { path: join(cwd, "src/x.ts"), content: "export {}" },
			})[0];
			expect(draftWrite).toMatchObject({
				block: true,
				reason: expect.stringMatching(/DRAFT/i),
			});

			const draftPlanEdit = runtime.emit("tool_call", {
				toolName: "edit",
				toolCallId: "e1",
				cwd,
				input: {
					path: join(cwd, "PLAN.md"),
					old_string: "DRAFT",
					new_string: "READY",
				},
			})[0];
			expect(draftPlanEdit).toBeUndefined();

			const relativeDraftPlanEdit = runtime.emit("tool_call", {
				toolName: "edit",
				toolCallId: "e-relative",
				cwd,
				input: {
					path: "PLAN.md",
					old_string: "DRAFT",
					new_string: "READY",
				},
			})[0];
			expect(relativeDraftPlanEdit).toBeUndefined();

			const draftBash = runtime.emit("tool_call", {
				toolName: "bash",
				toolCallId: "b1",
				cwd,
				input: { command: "rm -rf src" },
			})[0];
			expect(draftBash).toMatchObject({
				block: true,
				reason: expect.stringMatching(/DRAFT|mutating/i),
			});

			writeFileSync(
				join(cwd, "PLAN.md"),
				["# PLAN.md", "", "## Meta", "- Status: CHALLENGED", ""].join("\n"),
			);
			const challengedWrite = runtime.emit("tool_call", {
				toolName: "Write",
				toolCallId: "w2",
				cwd,
				input: { file_path: join(cwd, "src/y.ts"), content: "y" },
			})[0];
			expect(challengedWrite).toMatchObject({
				block: true,
				reason: expect.stringMatching(/CHALLENGED/i),
			});

			writeFileSync(join(cwd, "PLAN.md"), validReadyPlanText());
			const readyWrite = runtime.emit("tool_call", {
				toolName: "write",
				toolCallId: "w3",
				cwd,
				input: { path: join(cwd, "src/z.ts"), content: "z" },
			})[0];
			expect(readyWrite).toBeUndefined();

			writeFileSync(join(cwd, "PLAN.md"), "# PLAN.md\n## Meta\n- Status: READY\n");
			const incompleteReady = runtime.emit("tool_call", {
				toolName: "write", toolCallId: "w4", cwd,
				input: { path: join(cwd, "src/z.ts"), content: "z" },
			})[0];
			expect(incompleteReady).toMatchObject({ block: true, reason: expect.stringMatching(/READY but incomplete/i) });

			writeFileSync(join(cwd, "PLAN.md"), "# PLAN.md\n## Meta\n- Status: DRAFT — needs review\n");
			const malformedStatus = runtime.emit("tool_call", {
				toolName: "write", toolCallId: "w5", cwd,
				input: { path: join(cwd, "src/z.ts"), content: "z" },
			})[0];
			expect(malformedStatus).toMatchObject({ block: true, reason: expect.stringMatching(/UNKNOWN/i) });
		} finally {
			rmSync(cwd, { recursive: true, force: true });
		}
	});

	test("tool_call check-freeze denies READY plan weaken and allows strengthen or CHALLENGED demote", () => {
		const runtime = setupExtension();
		const cwd = mkdtempSync(join(tmpdir(), "etabli-pi-check-freeze-"));
		try {
			const readyBaseline = [
				"# PLAN.md",
				"",
				"## Meta",
				"- Status: READY",
				"",
				"## Checks",
				"- command: bash tests/a.sh",
				"- command: bash tests/b.sh",
				"",
			].join("\n");
			writeFileSync(join(cwd, "PLAN.md"), readyBaseline);

			const weaken = runtime.emit("tool_call", {
				toolName: "write",
				toolCallId: "cf1",
				cwd,
				input: {
					path: join(cwd, "PLAN.md"),
					content: [
						"# PLAN.md",
						"",
						"## Meta",
						"- Status: READY",
						"",
						"## Checks",
						"- command: bash tests/a.sh",
						"",
					].join("\n"),
				},
			})[0];
			expect(weaken).toMatchObject({
				block: true,
				reason: expect.stringMatching(/check-freeze/i),
			});

			const strengthen = runtime.emit("tool_call", {
				toolName: "write",
				toolCallId: "cf2",
				cwd,
				input: {
					path: join(cwd, "PLAN.md"),
					content: [
						"# PLAN.md",
						"",
						"## Meta",
						"- Status: READY",
						"",
						"## Checks",
						"- command: bash tests/a.sh",
						"- command: bash tests/b.sh",
						"- command: bash tests/c.sh",
						"",
					].join("\n"),
				},
			})[0];
			expect(strengthen).toBeUndefined();

			const piSchemaNeutralEdit = runtime.emit("tool_call", {
				toolName: "edit",
				toolCallId: "cf-pi-neutral",
				cwd,
				input: {
					path: join(cwd, "PLAN.md"),
					edits: [{ oldText: "# PLAN.md\n", newText: "# PLAN updated\n" }],
				},
			})[0];
			expect(piSchemaNeutralEdit).toBeUndefined();

			const piSchemaWeaken = runtime.emit("tool_call", {
				toolName: "edit",
				toolCallId: "cf-pi-weaken",
				cwd,
				input: {
					path: join(cwd, "PLAN.md"),
					edits: [{ oldText: "- command: bash tests/b.sh\n", newText: "" }],
				},
			})[0];
			expect(piSchemaWeaken).toMatchObject({
				block: true,
				reason: expect.stringMatching(/check-freeze/i),
			});

			const demoted = runtime.emit("tool_call", {
				toolName: "write",
				toolCallId: "cf3",
				cwd,
				input: {
					path: join(cwd, "PLAN.md"),
					content: [
						"# PLAN.md",
						"",
						"## Meta",
						"- Status: CHALLENGED",
						"",
						"## Checks",
						"- command: bash tests/a.sh",
						"",
						"## Decision Log",
						"- check-freeze demote: removed b after scope cut",
						"",
					].join("\n"),
				},
			})[0];
			expect(demoted).toBeUndefined();

			const bashPlan = runtime.emit("tool_call", {
				toolName: "bash",
				toolCallId: "cf4",
				cwd,
				input: { command: "sed -i '' 's/b.sh/gone/' PLAN.md" },
			})[0];
			expect(bashPlan).toMatchObject({
				block: true,
				reason: expect.stringMatching(/check-freeze|PLAN\.md/i),
			});

			const badEdit = runtime.emit("tool_call", {
				toolName: "edit",
				toolCallId: "cf5",
				cwd,
				input: {
					path: join(cwd, "PLAN.md"),
					old_string: "this-string-is-not-in-the-file",
					new_string: "noop",
				},
			})[0];
			expect(badEdit).toMatchObject({
				block: true,
				reason: expect.stringMatching(/check-freeze|reconstruct/i),
			});
		} finally {
			rmSync(cwd, { recursive: true, force: true });
		}
	});

	test("tool_result successful Bash appends no runtime receipt (retired type)", () => {
		const runtime = setupExtension();
		const cwd = mkdtempSync(join(tmpdir(), "etabli-pi-receipt-"));
		try {
			writeFileSync(join(cwd, "PLAN.md"), validReadyPlanText());
			mkdirSync(join(cwd, ".workflow", "rcpt-run"), { recursive: true });
			writeFileSync(
				join(cwd, ".workflow", "rcpt-run", "events.jsonl"),
				`${JSON.stringify({
					schema_version: 2,
					ts: "2026-08-01T00:00:00Z",
					run: "rcpt-run",
					event: "route_decided",
					detail: { route: "implement" },
				})}\n`,
			);
			writeFileSync(
				join(cwd, ".workflow", "active-run.json"),
				JSON.stringify({ schema_version: 1, run: "rcpt-run" }),
			);

			runtime.emit("tool_result", {
				toolName: "bash",
				toolCallId: "rcpt1",
				cwd,
				input: { command: "bash tests/a.sh" },
				content: [{ type: "text", text: "exit code: 0" }],
				isError: false,
			});

			const ledger = readFileSync(
				join(cwd, ".workflow", "rcpt-run", "events.jsonl"),
				"utf8",
			);
			const receipts = ledger
				.split("\n")
				.filter((line: string) => line.trim())
				.map(
					(line: string) =>
						JSON.parse(line) as {
							event: string;
							detail: Record<string, unknown>;
						},
				)
				.filter((event) => event.event === "runtime_receipt");
			expect(receipts.length).toBe(0);
			expect(ledger).not.toContain("bash tests/a.sh");

			runtime.emit("tool_result", {
				toolName: "bash",
				toolCallId: "read1",
				cwd,
				input: { command: "ls -la" },
				content: [{ type: "text", text: "exit code: 0" }],
				isError: false,
			});
			const afterRead = readFileSync(
				join(cwd, ".workflow", "rcpt-run", "events.jsonl"),
				"utf8",
			);
			expect(
				afterRead.split("\n").filter((line) => line.includes('"runtime_receipt"')),
			).toHaveLength(0);
		} finally {
			rmSync(cwd, { recursive: true, force: true });
		}
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

	test("blocks mutating write/bash while PLAN is DRAFT (READY guard parity)", () => {
		const runtime = setupExtension(["Write", "Bash", "Agent"]);
		const cwd = mkdtempSync(join(tmpdir(), "etabli-draft-guard-"));
		try {
			writeFileSync(
				join(cwd, "PLAN.md"),
				["# PLAN.md", "", "## Meta", "- Status: DRAFT", ""].join("\n"),
			);
			const writeBlock = runtime.emit("tool_call", {
				toolName: "Write",
				toolCallId: "1",
				cwd,
				input: { file_path: join(cwd, "src/x.ts"), content: "x" },
			});
			expect(writeBlock[0]).toMatchObject({ block: true });
			for (const [index, command] of [
				"rm -rf ./out",
				"node -e \"require('node:fs').writeFileSync('x', 'x')\"",
				"python3 -c \"from pathlib import Path; Path('x').write_text('x')\"",
				"git apply patch.diff",
				"install source target",
			].entries()) {
				const bashBlock = runtime.emit("tool_call", {
					toolName: "Bash",
					toolCallId: `bash-${index}`,
					cwd,
					input: { command },
				});
				expect(bashBlock[0]).toMatchObject({ block: true });
			}
			const quotedReadOnlySearch = runtime.emit("tool_call", {
				toolName: "Bash",
				toolCallId: "read-only-search",
				cwd,
				input: { command: "rg -n 'rm|mv' docs | head -n 1" },
			});
			expect(quotedReadOnlySearch[0]).toBeUndefined();
		} finally {
			rmSync(cwd, { recursive: true, force: true });
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

	describe("route contract pointer and issuance", () => {
		function setupLedgerCwd() {
			const cwd = mkdtempSync(join(tmpdir(), "etabli-emit-"));
			mkdirSync(join(cwd, ".workflow", "emit"), { recursive: true });
			// The picker only attaches to valid ledgers: seed one canonical line.
			writeFileSync(
				join(cwd, ".workflow", "emit", "events.jsonl"),
				'{"schema_version":2,"ts":"2026-01-01T00:00:00Z","event":"plan_created","run":"emit","detail":{"path":"PLAN.md","status":"DRAFT"}}\n',
			);
			writeFileSync(join(cwd, ".workflow", "active-run.json"), '{"schema_version":1,"run":"emit"}');
			return cwd;
		}

		function ledgerLines(cwd: string): Array<Record<string, unknown>> {
			const text = readFileSync(join(cwd, ".workflow", "emit", "events.jsonl"), "utf8");
			return text.split("\n").filter((l) => l.trim() !== "").map((l) => JSON.parse(l) as Record<string, unknown>);
		}

		test("emits route_decided with contract fields once per route", () => {
			const runtime = setupExtension();
			const cwd = setupLedgerCwd();
			try {
				runtime.emit("before_agent_start", {
					prompt: "Implémente le PLAN.md ready",
					systemPrompt: "Base prompt",
					cwd,
				});
				let lines = ledgerLines(cwd).filter((l) => l.event === "route_decided");
				expect(lines).toHaveLength(1);
				expect(lines[0]).toMatchObject({
					event: "route_decided",
					run: "emit",
					detail: { route: "plan-implement" },
				});
				const detail = lines[0].detail as Record<string, unknown>;
				expect(typeof detail.contract_path).toBe("string");
				expect(String(detail.contract_path).endsWith("plan-implement/SKILL.md")).toBe(true);
				expect(typeof detail.contract_sha256).toBe("string");
				expect(typeof detail.provenance).toBe("string");
				expect(["deployed-pi", "deployed-agents", "repo"]).toContain(detail.provenance as string);
				// Same route again: deduped, no second line.
				runtime.emit("before_agent_start", {
					prompt: "Implémente le PLAN.md ready encore",
					systemPrompt: "Base prompt",
					cwd,
				});
				lines = ledgerLines(cwd).filter((l) => l.event === "route_decided");
				expect(lines).toHaveLength(1);
			} finally {
				rmSync(cwd, { recursive: true, force: true });
			}
		});

		test("emits once per distinct route across A-B-A turns", () => {
			const runtime = setupExtension();
			const cwd = setupLedgerCwd();
			try {
				runtime.emit("before_agent_start", {
					prompt: "Implémente le PLAN.md ready",
					systemPrompt: "Base prompt",
					cwd,
				});
				writeFileSync(join(cwd, "PLAN.md"), validReadyPlanText());
				runtime.emit("before_agent_start", {
					prompt: "Implémente le PLAN.md ready",
					systemPrompt: "Base prompt",
					cwd,
				});
				let lines = ledgerLines(cwd).filter((l) => l.event === "route_decided");
				expect(lines.map((l) => (l.detail as Record<string, unknown>).route)).toEqual([
					"plan-implement",
					"implement",
				]);
				// Back to plan-implement: no third line.
				rmSync(join(cwd, "PLAN.md"), { force: true });
				runtime.emit("before_agent_start", {
					prompt: "Implémente le PLAN.md ready",
					systemPrompt: "Base prompt",
					cwd,
				});
				lines = ledgerLines(cwd).filter((l) => l.event === "route_decided");
				expect(lines).toHaveLength(2);
			} finally {
				rmSync(cwd, { recursive: true, force: true });
			}
		});

		test("emits contract-less route_decided for answer routes", () => {
			const runtime = setupExtension();
			const cwd = setupLedgerCwd();
			try {
				const results = runtime.emit("before_agent_start", {
					prompt: "Bonjour, comment vas-tu ?",
					systemPrompt: "Base prompt",
					cwd,
				});
				expect(results).toEqual([undefined]);
				const lines = ledgerLines(cwd).filter((l) => l.event === "route_decided");
				expect(lines).toHaveLength(1);
				expect(lines[0]).toMatchObject({ event: "route_decided", detail: { route: "answer" } });
				expect("contract_path" in (lines[0].detail as Record<string, unknown>)).toBe(false);
			} finally {
				rmSync(cwd, { recursive: true, force: true });
			}
		});

		test("skips emission without an active ledger and without cwd", () => {
			const runtime = setupExtension();
			const cwd = mkdtempSync(join(tmpdir(), "etabli-noledger-"));
			try {
				runtime.emit("before_agent_start", {
					prompt: "Implémente le PLAN.md ready",
					systemPrompt: "Base prompt",
					cwd,
				});
				expect(() => readFileSync(join(cwd, ".workflow", "emit", "events.jsonl"), "utf8")).toThrow();
				runtime.emit("before_agent_start", {
					prompt: "Implémente le PLAN.md ready",
					systemPrompt: "Base prompt",
				});
			} finally {
				rmSync(cwd, { recursive: true, force: true });
			}
		});

		test("emits at agent_end when the ledger appears mid-turn", () => {
			const runtime = setupExtension();
			const cwd = mkdtempSync(join(tmpdir(), "etabli-catchup-"));
			try {
				runtime.emit("before_agent_start", {
					prompt: "Implémente le PLAN.md ready",
					systemPrompt: "Base prompt",
					cwd,
				});
				// Ledger created mid-turn: seed one canonical line + pointer.
				mkdirSync(join(cwd, ".workflow", "emit"), { recursive: true });
				writeFileSync(
					join(cwd, ".workflow", "emit", "events.jsonl"),
					'{"schema_version":2,"ts":"2026-01-01T00:00:00Z","event":"plan_created","run":"emit","detail":{"path":"PLAN.md","status":"DRAFT"}}\n',
				);
				writeFileSync(join(cwd, ".workflow", "active-run.json"), '{"schema_version":1,"run":"emit"}');
				// Mid-turn tool result: catch-up emits before agent_end.
				runtime.emit("tool_result", { toolName: "read" });
				const lines = ledgerLines(cwd).filter((l) => l.event === "route_decided");
				expect(lines).toHaveLength(1);
				expect(lines[0]).toMatchObject({ event: "route_decided", run: "emit", detail: { route: "plan-implement" } });
				// agent_end after mid-turn catch-up: idempotent, no duplicate.
				runtime.emit("agent_end", { messages: [] });
				expect(ledgerLines(cwd).filter((l) => l.event === "route_decided")).toHaveLength(1);
				// Second agent_end without a new decision: no duplicate.
				runtime.emit("agent_end", { messages: [] });
				expect(ledgerLines(cwd).filter((l) => l.event === "route_decided")).toHaveLength(1);
			} finally {
				rmSync(cwd, { recursive: true, force: true });
			}
		});
	});
});
