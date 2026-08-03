import { describe, expect, test } from "bun:test";
import {
	mkdirSync,
	mkdtempSync,
	readFileSync,
	rmSync,
	symlinkSync,
	writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import workflowRouter from "../workflow-router.ts";

type Handler = (
	event: Record<string, unknown>,
	ctx?: Record<string, unknown>,
) => unknown;

function setupExtension(
	activeTools = ["TaskCreate", "TaskList", "Agent", "get_subagent_result"],
) {
	const handlers = new Map<string, Handler[]>();
	const entries: unknown[] = [];
	const renderers = new Map<string, unknown>();
	let thinkingLevel: string | undefined;

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
			thinkingLevel = level;
		},
	};

	workflowRouter(pi as unknown as Parameters<typeof workflowRouter>[0]);

	return {
		entries,
		renderers,
		get thinkingLevel() {
			return thinkingLevel;
		},
		emit(eventName: string, event: Record<string, unknown>, ctx?: Record<string, unknown>) {
			return (handlers.get(eventName) ?? []).map((handler) =>
				handler(event, ctx),
			);
		},
	};
}

describe("workflow router extension", () => {
	test("uses actual PLAN.md status before routing to implement", () => {
		const runtime = setupExtension();
		const cwd = mkdtempSync(join(tmpdir(), "etabli-ready-plan-"));

		try {
			writeFileSync(
				join(cwd, "PLAN.md"),
				["# PLAN.md", "", "## Meta", "- Status: READY", ""].join("\n"),
			);

			const results = runtime.emit("before_agent_start", {
				prompt: "Implémente le PLAN.md ready",
				systemPrompt: "Base prompt",
				cwd,
			});

			expect(results[0]).toEqual({
				systemPrompt: expect.stringContaining("Route: implement"),
			});
			expect(runtime.entries[0]).toMatchObject({
				decision: { route: "implement" },
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

			expect(results[0]).toEqual({
				systemPrompt: expect.stringContaining("Route: plan-implement"),
			});
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
			writeFileSync(
				join(cwd, "PLAN.md"),
				["# PLAN.md", "", "## Meta", "- Status: READY", ""].join("\n"),
			);

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

	test("injects Obvault guidance for a topic-aware answer", () => {
		const runtime = setupExtension();
		const results = runtime.emit("before_agent_start", {
			prompt: "Donne-moi des idées de SaaS",
			systemPrompt: "Base prompt",
		});

		expect(results[0]).toEqual({
			systemPrompt: expect.stringContaining("Knowledge topics: saas"),
		});
		expect(runtime.entries[0]).toMatchObject({
			version: "0.6.0",
			decision: { route: "answer", knowledgeContext: { topics: ["saas"] } },
		});
	});

	test("raises thinking to xhigh on heavy-reasoning routes", () => {
		for (const prompt of [
			"Analyse ce bug depuis le ticket Linear",
			"audit sécurité de la PR 42",
		]) {
			const runtime = setupExtension();
			runtime.emit("before_agent_start", { prompt, systemPrompt: "Base prompt" });
			expect(runtime.thinkingLevel).toBe("xhigh");
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

			writeFileSync(
				join(cwd, "PLAN.md"),
				["# PLAN.md", "", "## Meta", "- Status: READY", ""].join("\n"),
			);
			const readyWrite = runtime.emit("tool_call", {
				toolName: "write",
				toolCallId: "w3",
				cwd,
				input: { path: join(cwd, "src/z.ts"), content: "z" },
			})[0];
			expect(readyWrite).toBeUndefined();
		} finally {
			rmSync(cwd, { recursive: true, force: true });
		}
	});

	test("tool_call no_progress denies code Write under active ledger and allows PLAN / workflow-event escape", () => {
		const runtime = setupExtension();
		const cwd = mkdtempSync(join(tmpdir(), "etabli-pi-no-progress-"));
		try {
			writeFileSync(
				join(cwd, "PLAN.md"),
				[
					"# PLAN.md",
					"",
					"## Meta",
					"- Status: READY",
					"",
					"## Checks",
					"- command: bash tests/a.sh",
					"",
				].join("\n"),
			);
			mkdirSync(join(cwd, ".workflow", "run-a"), { recursive: true });
			writeFileSync(
				join(cwd, ".workflow", "run-a", "events.jsonl"),
				`${JSON.stringify({
					schema_version: 2,
					ts: "2026-08-01T00:00:00Z",
					run: "run-a",
					event: "no_progress",
					detail: {
						check_or_hypothesis: "stuck",
						command: "bash tests/a.sh",
						attempts: 2,
						eliminated: ["stuck"],
					},
				})}\n`,
			);

			const codeWrite = runtime.emit("tool_call", {
				toolName: "write",
				toolCallId: "np1",
				cwd,
				input: { path: join(cwd, "src/x.ts"), content: "x" },
			})[0];
			expect(codeWrite).toMatchObject({
				block: true,
				reason: expect.stringMatching(/no_progress/i),
			});

			const planWrite = runtime.emit("tool_call", {
				toolName: "write",
				toolCallId: "np2",
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
						"- check-freeze demote: no_progress stop",
						"",
					].join("\n"),
				},
			})[0];
			expect(planWrite).toBeUndefined();

			const eventCli = runtime.emit("tool_call", {
				toolName: "bash",
				toolCallId: "np3",
				cwd,
				input: { command: "scripts/workflow-event append --event blocked" },
			})[0];
			expect(eventCli).toBeUndefined();
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

	test("tool_result successful Bash emits a non-cryptographic runtime receipt to the active ledger", () => {
		const runtime = setupExtension();
		const cwd = mkdtempSync(join(tmpdir(), "etabli-pi-receipt-"));
		try {
			writeFileSync(
				join(cwd, "PLAN.md"),
				["# PLAN.md", "", "## Meta", "- Status: READY", ""].join("\n"),
			);
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
			expect(receipts.length).toBe(1);
			expect(receipts[0].detail).toMatchObject({
				kind: "validation",
				exit: 0,
				observed_by: "parent-process",
				cryptographic: false,
			});
			// Raw command text must not leak into the persisted receipt.
			expect(ledger).not.toContain("bash tests/a.sh");
			expect(receipts[0].detail.subject_sha256).toMatch(/^[a-f0-9]{64}$/);

			// Ordinary successful shell reads are not validation receipts.
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
				afterRead
					.split("\n")
					.filter((line) => line.includes('"runtime_receipt"')),
			).toHaveLength(1);

			// A repeated identical success does not double-emit.
			runtime.emit("tool_result", {
				toolName: "bash",
				toolCallId: "rcpt2",
				cwd,
				input: { command: "bash tests/a.sh" },
				content: [{ type: "text", text: "exit code: 0" }],
				isError: false,
			});
			const afterSecond = readFileSync(
				join(cwd, ".workflow", "rcpt-run", "events.jsonl"),
				"utf8",
			);
			const secondReceipts = afterSecond
				.split("\n")
				.filter(
					(line: string) => line.trim() && line.includes('"runtime_receipt"'),
				);
			expect(secondReceipts.length).toBe(1);
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
			symlinkSync(
				join(import.meta.dir, "../../../tests/fixtures/obvault-meta"),
				join(root, "_meta"),
				"dir",
			);
			process.env.OBVAULT_ROOT = root;

			const results = runtime.emit("before_agent_start", {
				prompt: "Donne-moi des idées FinOps",
				systemPrompt: "Base prompt",
			});

			expect(results[0]).toEqual({
				systemPrompt: expect.stringContaining("Knowledge topics: finops"),
			});
			expect(results[0]).toEqual({
				systemPrompt: expect.stringContaining(
					"Knowledge notes: kb/finops-cost-controls.md",
				),
			});
			expect(runtime.entries[0]).toMatchObject({
				decision: {
					route: "answer",
					knowledgeContext: { source: "obvault-metadata" },
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
			writeFileSync(
				join(cwd, "PLAN.md"),
				["# PLAN.md", "", "## Meta", "- Status: READY", ""].join("\n"),
			);
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
