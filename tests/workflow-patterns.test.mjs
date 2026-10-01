import { afterEach, beforeEach, test } from "node:test";
import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { archiveInitiative } from "../scripts/lib/workflow-patterns.mjs";
import { buildReport, renderReport } from "../scripts/lib/ship-metrics-report.mjs";
import { buildPortfolio, renderPortfolio } from "../scripts/lib/workflow-stats.mjs";

let root;
beforeEach(() => { root = mkdtempSync(join(tmpdir(), "etabli-patterns-")); });
afterEach(() => { rmSync(root, { recursive: true, force: true }); });

function write(path, content) {
	mkdirSync(join(path, ".."), { recursive: true });
	writeFileSync(path, content);
}

function ledger(project, slug, events) {
	write(join(project, ".workflow", slug, "events.jsonl"), events.map((event) => JSON.stringify({ ts: "2026-09-29T10:00:00Z", run: slug, ...event })).join("\n") + "\n");
}

function archive(project, name, initiative, body, extra = "") {
	write(join(project, "docs", "plan", `${name}.md`), `# Implemented: fixture\n\n## Metadata\n- Status: IMPLEMENTED\n- Archived: 2026-09-29\n- Workflow initiative: ${initiative}\n${extra}\n## Context\n${body}\n`);
}

function report(project = root, extra = {}) {
	return buildReport({ dir: join(project, ".workflow"), since: "2026-09-01", until: "2026-10-01", ...extra });
}

test("known legacy reasons and ledger/archive duplicates count distinct initiatives", () => {
	ledger(root, "run-a", [
		{ event: "blocked", detail: { reason: "review budget exhausted: F1 returned 3 findings and no D round is left" } },
		{ event: "blocked", detail: { reason: "review budget spent: user stopped" } },
	]);
	ledger(root, "run-b", [{ event: "blocked", detail: { reason: "no D round is left for the FD review" } }]);
	archive(root, "20260929-a", "`run-a` (completed at F1)", "- Context: review budget exhausted twice.\n- Context: review budget spent.");
	const patterns = report().patterns.rows;
	assert.equal(patterns.length, 1);
	assert.equal(patterns[0].id, "blocked/review-budget-exhausted");
	assert.equal(patterns[0].initiative_count, 2);
	assert.equal(patterns[0].observation_count, 5);
	assert.ok(patterns[0].evidence.every((e) => e.path && e.line > 0));
});

test("validation recurrence is check-specific, unknown reasons do not merge", () => {
	for (const slug of ["a", "b", "c"]) ledger(root, slug, [
		{ event: "validation_failed", detail: { command: "bash tests/a.sh", failure: "private failure text" } },
		{ event: "validation_failed", detail: { command: "bash tests/b.sh" } },
	]);
	ledger(root, "d", [{ event: "blocked", detail: { reason: "one unknown problem" } }, { event: "blocked", detail: { reason: "another unknown problem" } }]);
	const patterns = report().patterns.rows;
	assert.equal(patterns.filter((p) => p.id.startsWith("validation/")).length, 2);
	assert.equal(patterns.filter((p) => p.id.startsWith("blocked/unclassified/")).length, 2);
	assert.ok(patterns[0].recommendation.includes("mechanical check"));
	assert.ok(!JSON.stringify(patterns).includes("private failure text"));
});

test("successes, negative findings, draft archives and code fences are excluded", () => {
	ledger(root, "a", [{ event: "completed", detail: { summary: "review budget exhausted fixed" } },
		{ event: "adversary_completed", detail: { accepted_findings: ["No findings."] } }]);
	archive(root, "negative", "a", "- Context: no validation failure.\n- Context: without scope drift.\n- Context: accepted findings fixed.\n```md\n- Context: review budget exhausted.\n```\n\n## Outcome\n- Context: router miss.\n\n## Validation Evidence\n- Context: validation failed.");
	write(join(root, "docs/plan/draft.md"), "# PLAN.md\n## Metadata\n- Status: DRAFT\n## Context\n- Context: review budget spent.");
	assert.deepEqual(report().patterns.rows, []);
});

test("archive identity grammar reflects real metadata without broadcasting multi-run findings", () => {
	const cases = [
		["`escaped-tier` (completed at F1)", "escaped-tier"],
		["`lean-harness`, closed as documented `blocked`. Every slice is done.", "lean-harness"],
		["`rule-dedupe`, closed as documented `blocked` at F1.", "rule-dedupe"],
		["`lean-harness-followup` (follows `lean-harness`, whose ledger stays `blocked`)", "lean-harness-followup"],
		["contract-coherence, contract-coherence-2", null],
		["`lean-context-t4`, `lean-context-t4-review` (both blocked)", null],
		["`review-rounds-check` (blocked at F1), `review-rounds-check-r2` (clean)", null],
		["`etabli-audit-t9` (blocked after F1), `etabli-audit-t9-review` (completed)", null],
		["none", null],
	];
	for (const [field, expected] of cases) assert.equal(archiveInitiative(field), expected, field);
	archive(root, "ambiguous", cases[4][0], "- Context: review budget spent.");
	archive(root, "override", "owner", "- Context: review budget spent. [initiative:other]\n- Context: review budget exhausted.");
	ledger(root, "other", [{ event: "blocked", detail: { reason: "review budget spent" } }]);
	const out = report().patterns;
	assert.equal(out.sources.archives, "partial");
	assert.equal(out.rows[0].initiative_count, 2);
	assert.deepEqual(out.rows[0].initiatives.map((x) => x.slug).sort(), ["other", "owner"]);
	assert.ok(out.diagnostics.some((x) => x.reason.includes("unresolved initiative")));
});

test("metadata status is section-scoped; qualifications work; missing/duplicate status is partial", () => {
	archive(root, "body-status", "a", "Status: **verified**\n- Context: review budget spent.");
	archive(root, "qualified", "b", "- Context: router miss.");
	const qualified = join(root, "docs/plan/qualified.md");
	write(qualified, readFileSync(qualified, "utf8").replace("Status: IMPLEMENTED", "Status: IMPLEMENTED (AC4 UNCLAIMED)"));
	archive(root, "duplicate", "c", "- Context: validation failed.", "- Status: IMPLEMENTED");
	archive(root, "missing", "d", "- Context: validation failed.");
	const missing = join(root, "docs/plan/missing.md");
	write(missing, readFileSync(missing, "utf8").replace("- Status: IMPLEMENTED\n", ""));
	const out = report().patterns;
	assert.equal(out.sources.archives, "partial");
	assert.equal(out.rows.length, 2);
	assert.equal(out.diagnostics.filter((x) => x.reason.includes("status")).length, 2);
});

test("explicit pattern annotations link archive and ledger findings with precise evidence", () => {
	ledger(root, "a", [{ event: "blocked", detail: { reason: "ci_wait" } }]);
	archive(root, "a", "a", "- Waiting for the runner. [pattern:blocked/ci_wait]");
	const row = report().patterns.rows[0];
	assert.equal(row.initiative_count, 1);
	assert.equal(row.observation_count, 2);
	assert.ok(row.evidence.some((e) => e.timestamp_basis === "archive_recorded"));
});

test("archives overlap a partial-day window by recording date; event offsets compare by instant", () => {
	archive(root, "a", "a", "- Context: review budget spent.");
	ledger(root, "b", [{ ts: "2026-09-29T11:00:00+02:00", event: "blocked", detail: { reason: "ci_wait" } }]);
	const out = report(root, { since: "2026-09-29T09:00:00Z", until: "2026-09-29T09:30:00Z" });
	assert.equal(out.patterns.rows.length, 2);
	assert.equal(out.primaries.blocked_by_reason.ci_wait, 1);
	assert.deepEqual(report(root, { since: "2026-09-30", until: "2026-09-30" }).patterns.rows, []);
});

test("all guards stay unattributed, including new records claiming an initiative", () => {
	write(join(root, ".workflow/guard-journal/today.jsonl"), JSON.stringify({ ts: "2026-10-01T10:00:00Z", guard: "no-comments", pattern: "code-comment-added", run: "claimed", origin: "live" }) + "\n");
	const out = report().patterns;
	assert.deepEqual(out.rows, []);
	assert.equal(out.unattributed_guards[0].initiative_count, null);
	assert.equal(out.unattributed_guards[0].provenance, "unknown");
	assert.equal(out.unattributed_guards[0].observation_count, 1);
});

test("missing and malformed sources are named; reporting leaves input bytes and directories unchanged", () => {
	assert.equal(report().patterns.sources.ledgers, "missing");
	assert.ok(!readdirSync(root).includes(".workflow"));
	const path = join(root, ".workflow/a/events.jsonl");
	write(path, "{broken\n{}\n");
	const before = readFileSync(path);
	const out = report();
	assert.equal(out.patterns.sources.ledgers, "partial");
	assert.deepEqual(out.patterns.rows, []);
	assert.deepEqual(readFileSync(path), before);
	assert.ok(renderReport(out).includes("unmeasured"));
	assert.ok(renderReport(out).includes("outcome:"));
});

test("multi-project reporting preserves per-project coverage and same-slug independence", () => {
	const a = join(root, "a"), b = join(root, "b"), empty = join(root, "empty");
	mkdirSync(empty);
	for (const project of [a, b]) ledger(project, "same-run", [{ event: "blocked", detail: { reason: "review budget spent" } }]);
	const inventory = join(root, "roots.json");
	write(inventory, JSON.stringify([a, b, empty]));
	const out = buildPortfolio({ projectsFile: inventory, since: "2026-09-01", until: "2026-10-01" });
	assert.equal(out.patterns[0].initiative_count, 2);
	assert.equal(out.projects[2].sources.event_ledgers, "missing");
	assert.ok(renderPortfolio(out).includes("Projects: 3"));
});

test("inventory aliases, malformed entries and mixed Herdr usage fail with remediation", () => {
	const inventory = join(root, "roots.json");
	const alias = join(root, "alias");
	symlinkSync(root, alias);
	write(inventory, JSON.stringify([root, alias]));
	assert.throws(() => buildPortfolio({ projectsFile: inventory }), /Duplicate canonical/);
	for (const content of ["{", "[]", '["relative"]', JSON.stringify([inventory])]) {
		write(inventory, content);
		assert.throws(() => buildPortfolio({ projectsFile: inventory }));
	}
	assert.throws(() => buildPortfolio({ projectsFile: inventory, herdrHistory: "x" }), /single-project/);
});

test("invalid and reversed reporting windows fail", () => {
	assert.throws(() => report(root, { since: "nonsense" }), /Invalid reporting window/);
	assert.throws(() => report(root, { since: "2026-09-31" }), /Invalid reporting window/);
	assert.throws(() => report(root, { until: "2026-02-30" }), /Invalid reporting window/);
	assert.throws(() => report(root, { since: "2026-10-02", until: "2026-10-01" }), /Invalid reporting window/);
});

test("date-only until includes the final millisecond", () => {
	ledger(root, "a", [{ ts: "2026-09-29T23:59:59.999Z", event: "blocked", detail: { reason: "ci_wait" } }]);
	assert.equal(report(root, { since: "2026-09-29", until: "2026-09-29" }).patterns.rows[0].initiative_count, 1);
});

test("blocked validation reasons preserve identity instead of implying a shared failing check", () => {
	for (const slug of ["a", "b", "c"]) ledger(root, slug, [{ event: "blocked", detail: { reason: `validation failed: bash tests/${slug}.sh` } }]);
	const rows = report().patterns.rows;
	assert.equal(rows.length, 3);
	assert.ok(rows.every((row) => row.initiative_count === 1 && row.id.startsWith("blocked/unclassified/")));
});

test("text reports missing guards as unmeasured and partial observations as incomplete", () => {
	assert.match(renderReport(report()), /Guard observations: unmeasured/);
	write(join(root, ".workflow/guard-journal/x.jsonl"), "{}\n");
	assert.match(renderReport(report()), /Guard observations: 0 observed \(partial; total unmeasured\)/);
});

test("negative versions of every recognized phrase remain absent in archives and findings", () => {
	const phrases = ["routing miss", "router miss", "wrong route", "misroute", "review budget spent", "review budget exhausted", "validation failed", "test failure", "smoke failed", "scope drift", "plan drift", "D budget was spent"];
	for (const negation of ["no", "without", "not a", "never a", "zero"]) {
		const descriptions = phrases.map((phrase) => `${negation} ${phrase}`);
		archive(root, negation.replace(/ /g, "-"), "a", descriptions.map((text) => `- Context: ${text}.`).join("\n"));
		ledger(root, negation.replace(/ /g, "-"), [{ event: "adversary_completed", detail: { accepted_findings: descriptions } }]);
	}
	assert.deepEqual(report().patterns.rows, []);
});

test("readable text retains registry, Herdr and structured event counters", () => {
	const path = join(root, "herdr.jsonl");
	write(path, [1, 2].map((seq) => JSON.stringify({ ts: `2026-09-29T10:0${seq}:00Z`, host: "h", pane_id: "p", state_change_seq: seq })).join("\n"));
	ledger(root, "a", [{ event: "human_checkpoint", detail: { consent_class: "permission_request" } }, { event: "ship_completed", detail: { ci_state: "green" } }]);
	const text = renderReport(report(root, { herdrHistory: path }));
	assert.match(text, /known_seconds: 60/);
	assert.match(text, /panes: 1/);
	assert.match(text, /permission_request: 1/);
	assert.match(text, /green: 1/);
	assert.match(text, /escaped_later_total: unmeasured/);
});

test("not only introduces an affirmed failure; mixed positive and negative lines stay conservative", () => {
	archive(root, "affirmed", "a", "- Issue: Not only validation failed, routing miss also occurred.");
	ledger(root, "a", [{ event: "adversary_completed", detail: { accepted_findings: ["Not only validation failed, routing miss also occurred."] } }]);
	archive(root, "mixed", "b", "- Issue: validation failed; no routing miss.");
	const rows = report().patterns.rows;
	assert.equal(rows.length, 1);
	assert.equal(rows[0].id, "failure/validation");
	assert.equal(rows[0].observation_count, 2);
	assert.equal(rows[0].initiative_count, 1);
});

test("case-sensitive commands stay distinct and malformed issue details degrade coverage", () => {
	ledger(root, "a", [
		{ event: "validation_failed", detail: { command: "bash tests/A.sh" } },
		{ event: "validation_failed", detail: { command: "bash tests/a.sh" } },
		{ event: "validation_failed", detail: {} },
	]);
	const out = report().patterns;
	assert.equal(out.rows.length, 2);
	assert.equal(out.sources.ledgers, "partial");
});

function lineage(project, families) {
	write(join(project, "docs/workflow-run-lineage.json"), JSON.stringify({ schema_version: 1, families }));
}

function blocked(ts = "2026-09-29T10:00:00Z") {
	return { schema_version: 2, ts, event: "blocked", detail: { reason: "review budget spent", needed_input: "review" } };
}

function completed(ts = "2026-09-30T10:00:00Z") {
	return { schema_version: 2, ts, event: "completed", detail: { summary: "recorded workflow closure" } };
}

test("explicit family groups preserve raw counts and resolve historical blocks through a recorded successor", () => {
	for (const slug of ["a", "b", "c"]) ledger(root, slug, [blocked()]);
	ledger(root, "done", [completed()]);
	lineage(root, [{ id: "work", runs: ["a", "b", "c", "done"], resolutions: ["a", "b", "c"].map((slug) => ({ blocked: slug, completed: "done" })) }]);
	const row = report().patterns.rows[0];
	assert.equal(row.initiative_count, 3);
	assert.equal(row.observation_count, 3);
	assert.equal(row.family_count, 1);
	assert.equal(row.unmapped_run_count, 0);
	assert.equal(row.recorded_resolved_run_count, 3);
	assert.equal(row.resolutions[0].completed, "done");
	assert.equal(row.resolutions[0].evidence.line, 1);
	assert.ok(!row.recommendation.includes("candidate mechanical check"));
	assert.match(renderReport(report()), /1 work groups \/ 3 runs/);
});

test("recorded completion uses until, not since, and never an older or future successor", () => {
	ledger(root, "a", [blocked("2026-09-10T10:00:00Z")]);
	ledger(root, "done", [completed("2026-09-20T10:00:00Z")]);
	lineage(root, [{ id: "work", runs: ["a", "done"], resolutions: [{ blocked: "a", completed: "done" }] }]);
	assert.equal(report(root, { until: "2026-09-15" }).patterns.rows[0].recorded_resolved_run_count, 0);
	assert.equal(report(root, { until: "2026-09-20" }).patterns.rows[0].recorded_resolved_run_count, 1);
	ledger(root, "done", [completed("2026-09-01T10:00:00Z")]);
	assert.equal(report().patterns.rows[0].recorded_resolved_run_count, 0);
});

test("missing, legacy, malformed and non-final successor evidence never resolves a blockage", () => {
	ledger(root, "a", [blocked()]);
	lineage(root, [{ id: "work", runs: ["a", "done"], resolutions: [{ blocked: "a", completed: "done" }] }]);
	const cases = [null, [{ ...completed(), schema_version: 1 }], [completed(), { event: "validation_run", detail: { command: "true", exit: 0 }, ts: "2026-10-01T10:00:00Z" }], [{ ...completed(), detail: {} }], [blocked()]];
	for (const events of cases) {
		if (events) ledger(root, "done", events);
		const out = report().patterns;
		assert.equal(out.rows[0].recorded_resolved_run_count, 0);
		assert.equal(out.rows[0].family_count, 1);
		assert.ok(out.diagnostics.some((d) => d.reason.includes("successor")));
	}
});

test("invalid registry identities and contradictory links fall back to unmapped runs", () => {
	ledger(root, "a", [blocked()]);
	const invalid = [
		[{ id: "work", runs: ["a", "a"], resolutions: [] }],
		[{ id: "../work", runs: ["a"], resolutions: [] }],
		[{ id: "work", runs: ["a"], resolutions: [{ blocked: "a", completed: "a" }] }],
		[{ id: "work", runs: ["a"], resolutions: [{ blocked: "a", completed: "other" }] }],
		[{ id: "work", runs: ["a", "b", "c"], resolutions: [{ blocked: "a", completed: "b" }, { blocked: "a", completed: "c" }] }],
		[{ id: "work", runs: ["a"], resolutions: [], typo: "ignored?" }],
	];
	for (const families of invalid) {
		lineage(root, families);
		const out = report().patterns;
		assert.equal(out.sources.lineage, "partial");
		assert.equal(out.rows[0].unmapped_run_count, 1);
		assert.equal(out.rows[0].recorded_resolved_run_count, 0);
	}
});

test("unmapped run namespace cannot collide with a mapped family and portfolio groups remain project-scoped", () => {
	const a = join(root, "one"), b = join(root, "two");
	for (const project of [a, b]) {
		ledger(project, "a", [blocked()]);
		ledger(project, "work", [blocked()]);
		lineage(project, [{ id: "work", runs: ["a"], resolutions: [] }]);
	}
	const inventory = join(root, "projects.json"); write(inventory, JSON.stringify([a, b]));
	const row = buildPortfolio({ projectsFile: inventory, since: "2026-09-01", until: "2026-10-01" }).patterns[0];
	assert.equal(row.initiative_count, 4);
	assert.equal(row.family_count, 4);
	assert.equal(row.unmapped_run_count, 2);
	assert.match(row.recommendation, /independence/);
});

test("planning findings are labelled and all lineage reporting stays read-only", () => {
	ledger(root, "a", [{ event: "adversary_completed", detail: { mode: "plan", accepted_findings: ["missing a prerequisite"] } }]);
	lineage(root, [{ id: "work", runs: ["a"], resolutions: [] }]);
	const files = [join(root, ".workflow/a/events.jsonl"), join(root, "docs/workflow-run-lineage.json")];
	const before = files.map((file) => readFileSync(file));
	const row = report().patterns.rows[0];
	assert.equal(row.phase_counts.planning, 1);
	assert.match(renderReport(report()), /planning: 1/);
	files.forEach((file, index) => assert.deepEqual(readFileSync(file), before[index]));
});
