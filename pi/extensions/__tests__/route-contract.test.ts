import { describe, expect, test } from "bun:test";
import { createHash } from "node:crypto";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
	explicitCwd,
	resolveContractPointer,
	routeDecidedExists,
} from "../lib/route-contract.ts";

function writeSkill(root: string, skill: string, body = "body"): string {
	const dir = join(root, skill);
	mkdirSync(dir, { recursive: true });
	const file = join(dir, "SKILL.md");
	writeFileSync(file, `---\nname: ${skill}\n---\n${body}\n`);
	return file;
}

describe("route-contract pointer resolution", () => {
	test("prefers deployed-pi over deployed-agents over repo", () => {
		const home = mkdtempSync(join(tmpdir(), "etabli-home-"));
		const repo = mkdtempSync(join(tmpdir(), "etabli-repo-"));
		try {
			const piSkills = join(home, ".pi/agent/skills");
			const agentsSkills = join(home, ".agents/skills");
			const repoSkills = join(repo, "pi/skills");
			mkdirSync(piSkills, { recursive: true });
			mkdirSync(agentsSkills, { recursive: true });
			mkdirSync(repoSkills, { recursive: true });
			writeSkill(repoSkills, "plan-implement", "repo");
			writeSkill(agentsSkills, "plan-implement", "agents");
			writeSkill(piSkills, "plan-implement", "pi");
			const pointer = resolveContractPointer("plan-implement", { homeDir: home, repoRoot: repo });
			expect(pointer?.provenance).toBe("deployed-pi");
			expect(pointer?.path).toBe(join(piSkills, "plan-implement", "SKILL.md"));
			expect(pointer?.sha256).toBe(
				createHash("sha256").update(readFileSync(pointer?.path as string)).digest("hex"),
			);
		} finally {
			rmSync(home, { recursive: true, force: true });
			rmSync(repo, { recursive: true, force: true });
		}
	});

	test("falls back through agents to repo", () => {
		const home = mkdtempSync(join(tmpdir(), "etabli-home-"));
		const repo = mkdtempSync(join(tmpdir(), "etabli-repo-"));
		try {
			const agentsSkills = join(home, ".agents/skills");
			const repoSkills = join(repo, "pi/skills");
			mkdirSync(agentsSkills, { recursive: true });
			mkdirSync(repoSkills, { recursive: true });
			writeSkill(repoSkills, "review", "repo");
			const repoOnly = resolveContractPointer("review", { homeDir: home, repoRoot: repo });
			expect(repoOnly?.provenance).toBe("repo");
			writeSkill(agentsSkills, "review", "agents");
			const agents = resolveContractPointer("review", { homeDir: home, repoRoot: repo });
			expect(agents?.provenance).toBe("deployed-agents");
		} finally {
			rmSync(home, { recursive: true, force: true });
			rmSync(repo, { recursive: true, force: true });
		}
	});

	test("returns null when absent and rejects traversal names", () => {
		const home = mkdtempSync(join(tmpdir(), "etabli-home-"));
		const repo = mkdtempSync(join(tmpdir(), "etabli-repo-"));
		try {
			expect(resolveContractPointer("nope", { homeDir: home, repoRoot: repo })).toBeNull();
			expect(resolveContractPointer("../x", { homeDir: home, repoRoot: repo })).toBeNull();
			expect(resolveContractPointer("a/b", { homeDir: home, repoRoot: repo })).toBeNull();
			expect(resolveContractPointer("", { homeDir: home, repoRoot: repo })).toBeNull();
		} finally {
			rmSync(home, { recursive: true, force: true });
			rmSync(repo, { recursive: true, force: true });
		}
	});

	test("resolves the real plan-implement skill from the module location", () => {
		const pointer = resolveContractPointer("plan-implement", { homeDir: join(tmpdir(), "etabli-nohome") });
		expect(pointer?.provenance).toBe("repo");
		expect(pointer?.path.endsWith("pi/skills/plan-implement/SKILL.md")).toBe(true);
	});
});

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

	test("matches route+sha, ignores other routes, shamatches, and garbage", () => {
		const file = writeLedger([
			'{"event":"route_decided","detail":{"route":"plan-implement","reason":"r","contract_sha256":"aaa"}}',
			'not json',
			'{"event":"route_decided","detail":{"route":"implement","reason":"r"}}',
		]);
		try {
			expect(routeDecidedExists(file, "plan-implement", "aaa")).toBe(true);
			expect(routeDecidedExists(file, "plan-implement", "bbb")).toBe(false);
			expect(routeDecidedExists(file, "implement", null)).toBe(true);
			expect(routeDecidedExists(file, "review", null)).toBe(false);
			expect(routeDecidedExists(join(tmpdir(), "etabli-missing-ledger.jsonl"), "plan-implement", "aaa")).toBe(false);
		} finally {
			rmSync(join(file, ".."), { recursive: true, force: true });
		}
	});
});
