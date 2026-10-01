import { afterEach, beforeEach, test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { preflight, prospectiveClose } from "../scripts/lib/workflow-run-check.mjs";
import { hookScriptNames, loadFragment } from "../scripts/lib/claude-hooks-fragment.mjs";

const repo = resolve(new URL("..", import.meta.url).pathname);
let root;
beforeEach(() => { root = mkdtempSync(join(tmpdir(), "workflow-run-check-")); });
afterEach(() => { rmSync(root, { recursive: true, force: true }); });
function write(path, text) { mkdirSync(join(path, ".."), { recursive: true }); writeFileSync(path, text); }
function prerequisites() {
	for (const name of ["pi/node_modules/@earendil-works/pi-coding-agent/package.json", "pi/node_modules/typescript/package.json", `pi/node_modules/@typescript/typescript-${process.platform}-${process.arch}/lib/tsc`, "pi/extensions/node_modules/@earendil-works/pi-coding-agent/package.json", "pi/extensions/node_modules/typebox/package.json"]) write(join(root, name), '{"main":"index.js"}');
	for (const name of ["pi/node_modules/@earendil-works/pi-coding-agent/index.js", "pi/extensions/node_modules/@earendil-works/pi-coding-agent/index.js", "pi/extensions/node_modules/typebox/index.js"]) write(join(root, name), "export {};\n");
}
function events() {
	const provenance = { requested: { family: "anthropic", model: "opus", provider: "anthropic" }, effective: { family: "anthropic", model: "claude-opus-5-5", provider: "firstParty" }, runner: "fixture", run_id: "fixture" };
	const adversary = (mode, verdict) => ["adversary_completed", { mode, verdict, accepted_findings: [], rejected_findings: [], model_provenance: provenance }];
	return [
		["route_decided", { route: "plan-implement", reason: "fixture" }], ["plan_created", { path: "PLAN.md", status: "READY" }],
		adversary("plan", "READY"), ["file_changed", { path: "app.mjs", change: "fixture" }], ["validation_run", { command: "node fixture.mjs", exit: 0 }],
		["simplification_completed", { status: "clean", evidence: "fixture" }], ["quality_completed", { status: "pass", evidence: "fixture" }],
		adversary("code_diff", "GO"), ["review_completed", { status: "GO", evidence: "fixture", review_round: "T1", round_outcome: "clean" }],
		adversary("code_diff", "GO"), ["review_completed", { status: "GO", evidence: "fixture", review_round: "F1", round_outcome: "clean" }],
	].map(([event, detail]) => ({ schema_version: 2, ts: "2026-09-01T00:00:00Z", run: "run", event, detail }));
}
function ledger(entries = events()) { const path = join(root, ".workflow/run/events.jsonl"); write(path, entries.map((e) => JSON.stringify(e)).join("\n") + "\n"); return path; }

test("preflight catches missing dependencies without creating or installing them", () => {
	const result = preflight(root);
	assert.equal(result.ready, false);
	assert.equal(result.live_hooks, "not-requested");
	assert.ok(result.checks.some((row) => row.status === "missing" && row.remediation));
	assert.deepEqual(readdirSync(root), []);
	prerequisites();
	assert.equal(preflight(root).ready, true);
});

test("optional hooks readiness checks the requested DIR/.claude and preserves its bytes", () => {
	prerequisites();
	const settings = join(root, ".claude/settings.json"); write(settings, "{}");
	const before = readFileSync(settings);
	assert.equal(preflight(root, root).ready, false);
	assert.deepEqual(readFileSync(settings), before);
	const fragment = loadFragment(repo);
	write(settings, JSON.stringify(fragment));
	for (const name of hookScriptNames(fragment)) write(join(root, ".claude/hooks", name), "// fixture");
	assert.equal(preflight(root, root).ready, true);
});

test("extension package lookup accepts native parent fallback instead of requiring one managed directory", () => {
	prerequisites();
	rmSync(join(root, "pi/extensions/node_modules/@earendil-works"), { recursive: true });
	assert.equal(preflight(root).ready, true);
});

test("prospective close validates the real completion profile while leaving ledger, pointer, plan and archive untouched", () => {
	const path = ledger();
	const pointer = join(root, ".workflow/active-run.json"); write(pointer, JSON.stringify({ schema_version: 1, run: "run" }));
	const plan = join(root, "PLAN.md"); write(plan, "# Existing plan\n");
	const archive = join(root, "docs/plan/existing.md"); write(archive, "existing archive\n");
	const files = [path, pointer, plan, archive]; const before = files.map((file) => readFileSync(file));
	const result = prospectiveClose(join(root, ".workflow"), "run");
	assert.equal(result.ready, true);
	assert.equal(result.archive_checked, false);
	assert.equal(result.scope, "prospective-event-chain");
	files.forEach((file, i) => assert.deepEqual(readFileSync(file), before[i]));
	assert.deepEqual(readdirSync(join(root, "docs/plan")), ["existing.md"]);
	assert.deepEqual(readdirSync(join(root, ".workflow")), ["active-run.json", "run"]);
});

test("late archive-as-code-change and latest failed validation both block prospective closure", () => {
	for (const extra of [
		{ event: "file_changed", detail: { path: "docs/plan/new.md", change: "wrong event for archive" } },
		{ event: "validation_failed", detail: { command: "node fixture.mjs", exit: 1, failure: "latest attempt failed" } },
	]) {
		const entries = events(); entries.push({ ...entries[0], ...extra });
		const path = ledger(entries); const before = readFileSync(path);
		const result = prospectiveClose(join(root, ".workflow"), "run");
		assert.equal(result.ready, false);
		assert.ok(result.remediation.includes("workflow-event"));
		assert.deepEqual(readFileSync(path), before);
	}
});

test("terminal, malformed, missing and invalid-slug runs cannot be closed prospectively", () => {
	assert.equal(prospectiveClose(join(root, ".workflow"), "run").ready, false);
	assert.equal(prospectiveClose(join(root, ".workflow"), "../run").ready, false);
	const entries = events(); entries.push({ ...entries[0], event: "blocked", detail: { reason: "review_requested", needed_input: "review" } });
	ledger(entries);
	assert.equal(prospectiveClose(join(root, ".workflow"), "run").ready, false);
	write(join(root, ".workflow/run/events.jsonl"), "invalid JSON\n");
	assert.equal(prospectiveClose(join(root, ".workflow"), "run").ready, false);
});

test("CLI exposes JSON and rejects mixed-mode or missing option values", () => {
	prerequisites();
	const cli = join(repo, "scripts/workflow-run-check");
	const result = JSON.parse(execFileSync(cli, ["preflight", "--root", root, "--json"], { encoding: "utf8" }));
	assert.equal(result.ready, true);
	for (const args of [["preflight", "--root"], ["close", "--root", root, "run"], ["preflight", "--dir", root]]) assert.equal(spawnSync(cli, args).status, 2);
});

test("CLI reached through a symlink reports readiness and prerequisite failures", () => {
	const alias = join(root, "etabli");
	symlinkSync(repo, alias, "dir");
	const cli = join(alias, "scripts/workflow-run-check");
	const missing = spawnSync(cli, ["preflight", "--root", root, "--json"], { encoding: "utf8" });
	assert.equal(missing.status, 1);
	assert.equal(JSON.parse(missing.stdout).ready, false);
	prerequisites();
	const ready = spawnSync(cli, ["preflight", "--root", root, "--json"], { encoding: "utf8" });
	assert.equal(ready.status, 0);
	assert.equal(JSON.parse(ready.stdout).ready, true);
});
