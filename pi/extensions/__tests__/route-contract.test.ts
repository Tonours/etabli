import { describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { explicitCwd, routeDecidedExists } from "../lib/route-contract.ts";

describe("route-contract explicit cwd", () => {
	test("prefers ctx, then event, then null (no process.cwd fallback)", () => {
		expect(explicitCwd({ cwd: "/e" }, { cwd: "/c" })).toBe("/c");
		expect(explicitCwd({ cwd: "/e" })).toBe("/e");
		expect(explicitCwd({})).toBeNull();
		expect(explicitCwd({}, { cwd: "  " })).toBeNull();
	});
});

describe("route-contract dedupe scan", () => {
	function writeLedger(lines: string[]): string {
		const dir = mkdtempSync(join(tmpdir(), "etabli-ledger-"));
		const file = join(dir, "events.jsonl");
		writeFileSync(file, `${lines.join("\n")}\n`);
		return file;
	}

	test("matches a route once per run, legacy contract fields included, and ignores garbage", () => {
		const file = writeLedger([
			'{"event":"route_decided","detail":{"route":"plan-implement","reason":"r","contract_sha256":"aaa"}}',
			'not json',
			'{"event":"route_decided","detail":{"route":"implement","reason":"r"}}',
		]);
		try {
			expect(routeDecidedExists(file, "plan-implement")).toBe(true);
			expect(routeDecidedExists(file, "implement")).toBe(true);
			expect(routeDecidedExists(file, "review")).toBe(false);
			expect(routeDecidedExists(join(tmpdir(), "etabli-missing-ledger.jsonl"), "plan-implement")).toBe(false);
		} finally {
			rmSync(join(file, ".."), { recursive: true, force: true });
		}
	});
});
