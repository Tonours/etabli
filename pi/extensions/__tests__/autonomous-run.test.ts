import { describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { isAutonomousRun } from "../lib/autonomous-run.ts";

describe("isAutonomousRun", () => {
	test("false without .workflow active pointer", () => {
		const cwd = mkdtempSync(join(tmpdir(), "etabli-auto-"));
		try {
			expect(isAutonomousRun(cwd)).toBe(false);
		} finally {
			rmSync(cwd, { recursive: true, force: true });
		}
	});

	test("true when pointer names a ledger that exists", () => {
		const cwd = mkdtempSync(join(tmpdir(), "etabli-auto-"));
		try {
			const run = "fluid-run";
			mkdirSync(join(cwd, ".workflow", run), { recursive: true });
			writeFileSync(
				join(cwd, ".workflow", "active-run.json"),
				JSON.stringify({ schema_version: 1, run }) + "\n",
			);
			writeFileSync(join(cwd, ".workflow", run, "events.jsonl"), "{}\n");
			expect(isAutonomousRun(cwd)).toBe(true);
		} finally {
			rmSync(cwd, { recursive: true, force: true });
		}
	});

	test("false for path traversal pointer", () => {
		const cwd = mkdtempSync(join(tmpdir(), "etabli-auto-"));
		try {
			mkdirSync(join(cwd, ".workflow"), { recursive: true });
			writeFileSync(
				join(cwd, ".workflow", "active-run.json"),
				JSON.stringify({ schema_version: 1, run: "../escape" }) + "\n",
			);
			expect(isAutonomousRun(cwd)).toBe(false);
		} finally {
			rmSync(cwd, { recursive: true, force: true });
		}
	});
});

