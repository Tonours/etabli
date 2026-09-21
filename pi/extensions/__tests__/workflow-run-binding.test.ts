import { expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import workflowRunBinding from "../workflow-run-binding.ts";

test("binds one active ledger to the Pi session without persisting identifiers", () => {
	const handlers = new Map<string, (event: unknown, context: unknown) => unknown>();
	const entries: Array<Record<string, unknown>> = [{
		type: "custom",
		customType: "etabli.workflow-run-binding",
		data: { schema_version: 1, algorithm: "sha256", fingerprint: "a".repeat(64) },
	}];
	const pi = {
		on(name: string, handler: (event: unknown, context: unknown) => unknown) {
			handlers.set(name, handler);
		},
		appendEntry(customType: string, data: Record<string, unknown>) {
			entries.push({ type: "custom", customType, data });
		},
	};
	workflowRunBinding(pi as unknown as Parameters<typeof workflowRunBinding>[0]);
	const cwd = mkdtempSync(join(tmpdir(), "etabli-pi-binding-"));
	try {
		mkdirSync(join(cwd, ".workflow", "private-run-slug"), { recursive: true });
		writeFileSync(join(cwd, ".workflow", "private-run-slug", "events.jsonl"), `${JSON.stringify({
			schema_version: 2,
			ts: "2026-09-20T10:00:00Z",
			event: "route_decided",
			run: "private-run-slug",
			detail: { route: "plan-implement", reason: "fixture" },
		})}\n`);
		writeFileSync(join(cwd, ".workflow", "active-run.json"), JSON.stringify({ schema_version: 1, run: "private-run-slug" }));
		const context = {
			cwd,
			sessionManager: {
				getSessionId: () => "private-session-id",
				getEntries: () => entries,
			},
		};

		handlers.get("tool_result")?.({}, context);
		handlers.get("agent_settled")?.({}, context);

		expect(entries).toHaveLength(2);
		expect(entries[1]).toMatchObject({
			type: "custom",
			customType: "etabli.workflow-run-binding",
			data: {
				schema_version: 1,
				algorithm: "sha256",
				fingerprint: expect.stringMatching(/^[0-9a-f]{64}$/),
			},
		});
		const serialized = JSON.stringify(entries[1]);
		expect(serialized).not.toContain("private-session-id");
		expect(serialized).not.toContain("private-run-slug");
	} finally {
		rmSync(cwd, { recursive: true, force: true });
	}
});
