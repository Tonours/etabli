import assert from "node:assert/strict";
import { existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { bindPlanImplementPolicy, buildCandidatePiArguments, buildPlanImplementDryRun, comparePlanImplementRuns, fingerprintTrackedTree, gradePlanImplementCell, validatePlanImplementManifest, validatePrivateCampaignOutputDirectory } from "../scripts/lib/jev-plan-implement-campaign.mjs";
import { fingerprintEvaluatorBundle, fingerprintEvaluatorFile, hashManifestBytes } from "../scripts/lib/evaluator-bundle.mjs";

const manifestBytes = readFileSync("workflow/self-improvement/jev-plan-implement-manifest.json");
const manifest = JSON.parse(manifestBytes);
const manifestSha = hashManifestBytes(manifestBytes);
const config = JSON.parse(readFileSync("workflow/self-improvement/jev-plan-implement-live-config.json", "utf8"));
const SHA = "a".repeat(64);

function usage(tokens) {
  return { measured: true, provenance: "provider_receipt", input_tokens: tokens - 10, output_tokens: 10, cached_input_tokens: 0, cache_write_input_tokens: 0, total_tokens: tokens, cost_usd: null, cost_status: "unavailable" };
}

function jev(arm) {
  return arm === "candidate"
    ? { calls: 1, input_tokens: 5, output_tokens: 1, total_tokens: 6, latency_ms: 2, abstentions: 0, escalations: 0, retries: 0, cost_usd: null, cost_status: "unavailable" }
    : { calls: 0, input_tokens: 0, output_tokens: 0, total_tokens: 0, latency_ms: 0, abstentions: 0, escalations: 0, retries: 0, cost_usd: 0, cost_status: "not_incurred" };
}

function run(arm, tokens) {
  return {
    schema_version: 1,
    arm,
    campaign_id: manifest.manifest_id,
    manifest_sha256: manifestSha,
    evaluator_bundle_sha256: manifest.evaluator.bundle.sha256,
    artifact_fingerprint: SHA,
    population_fingerprint: "b".repeat(64),
    runtime: { runner: "pi", provider: "openai-codex", model: "gpt-6-astra", effort: "medium", runtime_fingerprint: "c".repeat(64), candidate_enabled: arm === "candidate" },
    repetitions: [1, 2, 3].map((repetition) => ({ repetition, tasks: manifest.tasks.map((task) => ({ task_id: task.id, protected: task.protected, passed: true, latency_ms: 10, traditional_llm: usage(tokens), jev: jev(arm) })) })),
  };
}

test("route-specific manifest is frozen, bound and enumerates exactly 18/9 calls", () => {
  validatePlanImplementManifest(manifest);
  assert.equal(fingerprintEvaluatorFile(".", manifest.evaluator.path), manifest.evaluator.sha256);
  assert.equal(fingerprintEvaluatorBundle(".", manifest.evaluator.bundle.paths), manifest.evaluator.bundle.sha256);
  const plan = buildPlanImplementDryRun({ manifest, config });
  assert.equal(plan.cells.length, 18);
  assert.equal(plan.traditional_llm_calls, 18);
  assert.equal(plan.jev_calls, 9);
  assert.deepEqual(new Set(manifest.tasks.map((task) => task.split)), new Set(["held_in", "held_out", "safety"]));
});

test("accepts only stable 3/3 savings and reports Jev separately", () => {
  const result = comparePlanImplementRuns({ manifest, manifestSha, baseline: run("baseline", 100), candidate: run("candidate", 60) });
  assert.equal(result.verdict, "accepted");
  assert.deepEqual(result.repetitions.map((row) => row.savings_percent), [40, 40, 40]);
  assert.equal(result.traditional_llm.baseline.calls, 9);
  assert.equal(result.jev.candidate.calls, 9);
  assert.equal(result.jev.candidate.cost_status, "unavailable");
});

test("rejects one weak repetition, unstable quality and safety regression", () => {
  const candidate = run("candidate", 60);
  candidate.repetitions[1].tasks[0].traditional_llm = usage(200);
  candidate.repetitions[2].tasks[1].passed = false;
  const result = comparePlanImplementRuns({ manifest, manifestSha, baseline: run("baseline", 100), candidate });
  assert.equal(result.verdict, "rejected");
  assert.ok(result.reasons.includes("target_not_met:rep2"));
  assert.ok(result.reasons.includes("candidate_quality_vector_unstable"));
  assert.ok(result.reasons.includes("candidate_quality_failure:ready-implementation:rep3"));
  assert.ok(result.reasons.includes("quality_regression:ready-implementation:rep3"));
  const unsafe = run("candidate", 60);
  unsafe.repetitions[0].tasks[2].passed = false;
  assert.throws(() => comparePlanImplementRuns({ manifest, manifestSha, baseline: run("baseline", 100), candidate: unsafe }), /safety task failed/);
});

test("rollback removes only plan-implement and preserves measured routes", () => {
  const policy = { eligible_routes: ["planning", "implementation", "review", "plan-implement"], protected_routes: ["answer"] };
  const rejected = bindPlanImplementPolicy(policy, { status: "comparable", verdict: "rejected" });
  assert.deepEqual(rejected.eligible_routes, ["planning", "implementation", "review"]);
  assert.deepEqual(rejected.protected_routes, ["answer"]);
  const accepted = bindPlanImplementPolicy(rejected, { status: "comparable", verdict: "accepted" });
  assert.deepEqual(accepted.eligible_routes, ["planning", "implementation", "review", "plan-implement"]);
});

test("candidate capsule is appended to the system prompt after route selection", () => {
  const prompt = "Planifie puis implémente ce changement";
  const capsule = "Plan or challenge, then implement after READY.";
  const argv = buildCandidatePiArguments({ config, prompt, capsule });
  assert.equal(argv.at(-1), prompt);
  assert.equal(argv[argv.indexOf("--append-system-prompt") + 1], `<etabli-jev-route-capsule>\n${capsule}\n</etabli-jev-route-capsule>`);
  assert.equal(argv.filter((value) => value === prompt).length, 1);
});

test("exact grader binds tracked worktree and complete terminal ledger", () => {
  const task = manifest.tasks[0];
  const root = mkdtempSync(join(tmpdir(), "jev-plan-implement-grade-"));
  try {
    writeFileSync(join(root, "app.txt"), "mode=new\n");
    mkdirSync(join(root, "docs/plan"), { recursive: true });
    writeFileSync(join(root, "docs/plan/natural-plan-build.md"), "archived\n");
    mkdirSync(join(root, ".workflow/natural-plan-build"), { recursive: true });
    const rows = task.grader.required_events.map((event, index) => ({ schema_version: 2, ts: `2026-09-21T00:00:0${index}.000Z`, run: task.id, event, detail: {} }));
    writeFileSync(join(root, ".workflow/natural-plan-build/events.jsonl"), `${rows.map(JSON.stringify).join("\n")}\n`);
    assert.equal(fingerprintTrackedTree(root, task.grader.tracked_paths), task.grader.expected_tree_sha256);
    assert.equal(gradePlanImplementCell({ task, worktree: root, runnerExit: 0 }).passed, true);
    writeFileSync(join(root, "app.txt"), "mode=almost\n");
    assert.deepEqual(gradePlanImplementCell({ task, worktree: root, runnerExit: 0 }).reasons, ["exact_worktree_mismatch"]);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("campaign output rejects a symlinked workflow parent before creating outside directories", () => {
  const root = mkdtempSync(join(tmpdir(), "jev-plan-implement-output-"));
  const outside = mkdtempSync(join(tmpdir(), "jev-plan-implement-outside-"));
  try {
    symlinkSync(outside, join(root, ".workflow"));
    assert.throws(() => validatePrivateCampaignOutputDirectory(root, join(root, ".workflow/jev-plan-implement/private/run")), /campaign output root symlink rejected/);
    assert.equal(existsSync(join(outside, "jev-plan-implement")), false);
  } finally {
    rmSync(root, { recursive: true, force: true });
    rmSync(outside, { recursive: true, force: true });
  }
});

test("historical v1 evaluator binding remains unchanged", () => {
  const previous = JSON.parse(readFileSync("workflow/self-improvement/jev-efficiency-manifest.json", "utf8"));
  assert.equal(fingerprintEvaluatorFile(".", previous.evaluator.path), previous.evaluator.sha256);
  assert.equal(fingerprintEvaluatorBundle(".", previous.evaluator.bundle.paths), previous.evaluator.bundle.sha256);
});
