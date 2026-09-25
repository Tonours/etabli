import { currentEvaluatorFixtureBytes, currentPopulationFixtureBytes } from "./helpers/jev-efficiency-fixture.mjs";
import assert from "node:assert/strict";
import { cpSync, existsSync, mkdirSync, mkdtempSync, realpathSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";
import { baselineChildEnvironment, buildLiveDryRunPlan, compareCampaignDocuments, decideCampaign, executeLiveBaseline, rankOfflineHypotheses, snapshotRuntimeArtifact, validatePrivatePopulation } from "../scripts/lib/jev-efficiency-campaign.mjs";
import { hashManifestBytes } from "../scripts/lib/evaluator-bundle.mjs";
import { fingerprintEvaluatorBundle, fingerprintEvaluatorFile } from "../scripts/lib/evaluator-bundle.mjs";

const SHA = "a".repeat(64);
const FILE_SHA = "b".repeat(64);
const POPULATION_FIXTURE = "tests/fixtures/jev-efficiency/population.json";
const PRIVATE_TEST_ROOT = resolve(".workflow/jev-autonomous-efficiency/private");
const baselinePhaseState = (populationFingerprint, overrides = {}) => ({
	private_population_fingerprint: populationFingerprint,
	offline_validation: "passed",
	baseline_runtime_artifact: { status: "frozen", candidate_enabled: false, fingerprint: SHA },
	provider_checkpoint: "required",
	candidate_runtime_enabled: false,
	live_candidates: 0,
	...overrides,
});
mkdirSync(PRIVATE_TEST_ROOT, { recursive: true });
const manifest = {
	schema_version: 2,
	strict: true,
	manifest_id: "jev-efficiency-v1",
	visibility: "frozen_public",
	objective: { kind: "efficiency", metric: "total_tokens", direction: "decrease", minimum_delta: 1, measurement_population: "jev-efficiency-private-v1" },
	evaluator: { sha256: FILE_SHA, path: "scripts/jev-efficiency-campaign", bundle: { root: ".", paths: ["scripts/jev-efficiency-campaign"], sha256: SHA } },
	campaign_contract: { schema_version: 1, final_repetitions: 3, target_savings_percent: 30, stretch_savings_percent: 50, max_offline_hypotheses: 4, max_live_candidates: 2, execution_population: "private_ignored", public_manifest_is_sealed: false },
	runtime_artifact: { paths: ["fixture"], excludes: [] },
	tasks: [
		["answer", "held_in", false], ["planning", "held_in", false], ["implementation", "held_out", false],
		["review", "held_out", false], ["failure_diagnosis", "held_in", false],
		["self_improvement", "held_out", false], ["protected_route", "safety", true],
	].map(([category, split, protectedRoute]) => ({ id: `${category}-case`, category, split, protected: protectedRoute })),
};

const taskRow = (task, tokens, passed = true) => ({
	task_id: task.id,
	protected: task.protected,
	passed,
	latency_ms: 10,
	traditional_llm: { measured: true, provenance: "provider_receipt", input_tokens: tokens - 10, output_tokens: 10, cached_input_tokens: 2, cache_write_input_tokens: 1, total_tokens: tokens, cost_usd: 0.01, cost_status: "measured" },
	jev: { calls: 1, input_tokens: 5, output_tokens: 1, total_tokens: 6, cost_usd: 0.001, cost_status: "measured", latency_ms: 2, abstentions: 0, escalations: 0, retries: 0 },
});

const run = (arm, tokens) => ({
	schema_version: 1,
	arm,
	campaign_id: manifest.manifest_id,
	manifest_sha256: SHA,
	evaluator_bundle_sha256: SHA,
	artifact_fingerprint: arm === "baseline" ? "c".repeat(64) : "d".repeat(64),
	population_fingerprint: "e".repeat(64),
	runtime: { runner: "pi", provider: "fixture", model: "fixture-1", effort: "high", runtime_fingerprint: "f".repeat(64), candidate_enabled: arm === "candidate" },
	repetitions: [1, 2, 3].map((repetition) => ({ repetition, tasks: manifest.tasks.map((task) => taskRow(task, tokens)) })),
});

const compare = (baseline = run("baseline", 100), candidate = run("candidate", 60)) =>
	compareCampaignDocuments({ manifest, manifestSha: SHA, evaluatorBundleSha: SHA, evaluatorFileSha: FILE_SHA, baseline, candidate });

test("accepts stable provider-backed 3/3 savings and reports Jev separately", () => {
	const result = compare();
	assert.equal(result.verdict, "accepted");
	assert.deepEqual(result.repetitions.map((row) => row.savings_percent), [40, 40, 40]);
	assert.equal(result.stretch_met, false);
	assert.equal(result.jev.candidate.calls, 21);
});

test("historical evaluator stays frozen and is stale after candidate accounting changes", () => {
	const frozen = JSON.parse(readFileSync(new URL("../workflow/self-improvement/jev-efficiency-manifest.json", import.meta.url), "utf8"));
	assert.equal(fingerprintEvaluatorFile(".", frozen.evaluator.path), frozen.evaluator.sha256);
	assert.notEqual(fingerprintEvaluatorBundle(".", frozen.evaluator.bundle.paths), frozen.evaluator.bundle.sha256);
});

test("rejects one repetition below the target", () => {
	const candidate = run("candidate", 60);
	candidate.repetitions[1].tasks[0].traditional_llm.input_tokens = 200;
	candidate.repetitions[1].tasks[0].traditional_llm.total_tokens = 210;
	const result = compare(run("baseline", 100), candidate);
	assert.equal(result.verdict, "rejected");
	assert.ok(result.reasons.includes("target_not_met:rep2"));
});

test("fails closed on malformed provider telemetry, retries, drift and protected regressions", () => {
	for (const mutate of [
		(value) => { value.repetitions[0].tasks[0].traditional_llm.cost_usd = null; value.repetitions[0].tasks[0].traditional_llm.cost_status = "measured"; },
		(value) => { value.repetitions[0].tasks[0].jev.retries = 1; },
		(value) => { value.population_fingerprint = "9".repeat(64); },
		(value) => { value.repetitions[0].tasks.at(-1).passed = false; },
	]) {
		const candidate = run("candidate", 60);
		mutate(candidate);
		assert.throws(() => compare(run("baseline", 100), candidate));
	}
});

test("keeps unavailable provider cost explicit without inventing zero", () => {
	const baseline = run("baseline", 100);
	const candidate = run("candidate", 60);
	for (const value of [baseline, candidate]) {
		value.repetitions[0].tasks[0].traditional_llm.cost_usd = null;
		value.repetitions[0].tasks[0].traditional_llm.cost_status = "unavailable";
		value.repetitions[0].tasks[0].jev.cost_usd = null;
		value.repetitions[0].tasks[0].jev.cost_status = "unavailable";
	}
	const result = compare(baseline, candidate);
	assert.equal(result.verdict, "accepted");
	assert.deepEqual(result.traditional_llm.baseline, { cost_usd: null, cost_status: "unavailable" });
	assert.equal(result.jev.candidate.cost_status, "unavailable");
});

test("rejects unstable quality vectors and paired regressions", () => {
	const candidate = run("candidate", 60);
	candidate.repetitions[1].tasks[0].passed = false;
	const result = compare(run("baseline", 100), candidate);
	assert.equal(result.verdict, "rejected");
	assert.ok(result.reasons.includes("candidate_quality_vector_unstable"));
	assert.ok(result.reasons.includes("quality_regression:answer-case:rep2"));
});

test("controller keeps provider, READY, mutation and rollback authority outside Jev", () => {
	assert.equal(decideCampaign(manifest, {}).decision, "await_private_population");
	const base = { private_population_fingerprint: SHA, offline_validation: "passed", baseline_runtime_artifact: { status: "frozen", candidate_enabled: false, fingerprint: SHA } };
	assert.equal(decideCampaign(manifest, { private_population_fingerprint: SHA, offline_validation: "passed" }).decision, "snapshot_baseline_artifact");
	assert.equal(decideCampaign(manifest, base).decision, "await_checkpoint");
	assert.equal(decideCampaign(manifest, { ...base, provider_checkpoint: "authorized" }).decision, "run_baseline");
	assert.equal(decideCampaign(manifest, { ...base, provider_checkpoint: "authorized", candidate_runtime_enabled: true }).reason, "candidate_enabled_before_baseline");
	const progressed = { ...base, provider_checkpoint: "authorized", baseline: { status: "accepted", candidate_enabled: false, result_fingerprint: SHA }, observation_fingerprint: SHA };
	assert.equal(decideCampaign(manifest, progressed).decision, "diagnose_with_jev");
	assert.equal(decideCampaign(manifest, { ...progressed, diagnosis: { producer: "jev", valid: true, abstained: true, receipt_fingerprint: SHA } }).decision, "escalate_to_llm");
	const evaluated = { ...progressed, diagnosis: { producer: "jev", valid: true, abstained: false, receipt_fingerprint: SHA }, deduplication: { status: "unique", evidence_fingerprint: SHA }, proposal_fingerprint: SHA, plan_status: "READY", plan_fingerprint: SHA, adversary_verdict: "GO", adversary_fingerprint: SHA, implementation_status: "verified", implementation_fingerprint: SHA, comparison: { verdict: "rejected", receipt_fingerprint: SHA } };
	assert.equal(decideCampaign(manifest, evaluated).decision, "rollback_required");
	assert.equal(decideCampaign(manifest, { ...evaluated, comparison: { verdict: "accepted", receipt_fingerprint: SHA }, final_validation: { verdict: "accepted", repetitions: 3, receipt_fingerprint: SHA, target_savings_percent: 30, protected_preservation_percent: 100, quality_vectors_stable: true } }).decision, "completion_ready");
	assert.equal(decideCampaign(manifest, { ...evaluated, comparison: { verdict: "accepted", receipt_fingerprint: SHA }, final_validation: { verdict: "accepted", repetitions: 3, receipt_fingerprint: SHA, target_savings_percent: 29, protected_preservation_percent: 100, quality_vectors_stable: true } }).decision, "rollback_required");
});

const offlineResult = (task, overrides = {}) => ({
	task_id: task.id,
	provider_mode: "synthetic_fixture",
	candidate_runtime_enabled: false,
	attempts: 1,
	jev_status: "accepted",
	fallback: "none",
	quality_passed: true,
	protected_preserved: true,
	...overrides,
});

test("offline runner ranks at most four synthetic hypotheses without a savings claim", () => {
	const input = {
		schema_version: 1,
		manifest_id: manifest.manifest_id,
		population_fingerprint: SHA,
		hypotheses: [
			{ id: "h-context", seam: "context_selection", results: manifest.tasks.map((task) => offlineResult(task)) },
			{ id: "h-triage", seam: "failure_triage", results: manifest.tasks.map((task, index) => offlineResult(task, index === 0 ? { jev_status: "abstained", fallback: "traditional_llm" } : {})) },
		],
	};
	const result = rankOfflineHypotheses(manifest, input);
	assert.equal(result.status, "offline_only_no_runtime_savings_claim");
	assert.equal(result.ranking[0].id, "h-context");
	assert.equal(result.next, "freeze_private_population_then_request_provider_checkpoint");
});

test("offline runner rejects retry, runtime activation and a fifth hypothesis", () => {
	const valid = { id: "h", seam: "no_op", results: manifest.tasks.map((task) => offlineResult(task)) };
	for (const mutate of [
		(input) => { input.hypotheses[0].results[0].attempts = 2; },
		(input) => { input.hypotheses[0].results[0].candidate_runtime_enabled = true; },
		(input) => { input.hypotheses = [0, 1, 2, 3, 4].map((index) => ({ ...structuredClone(valid), id: `h-${index}` })); },
	]) {
		const input = { schema_version: 1, manifest_id: manifest.manifest_id, population_fingerprint: SHA, hypotheses: [structuredClone(valid)] };
		mutate(input);
		assert.throws(() => rankOfflineHypotheses(manifest, input));
	}
});

test("offline runner retains unsafe fallback as an ineligible negative result", () => {
	const hypothesis = { id: "h", seam: "no_op", results: manifest.tasks.map((task) => offlineResult(task)) };
	hypothesis.results[0].jev_status = "malformed";
	hypothesis.results[0].fallback = "none";
	const result = rankOfflineHypotheses(manifest, { schema_version: 1, manifest_id: manifest.manifest_id, population_fingerprint: SHA, hypotheses: [hypothesis] });
	assert.equal(result.ranking[0].eligible, false);
	assert.equal(result.next, "reject_all_offline_hypotheses");
	assert.ok(result.ranking[0].reasons.includes("missing_fallback:answer-case"));
});

test("CLI runs the synthetic offline path without provider egress", () => {
	const frozen = JSON.parse(readFileSync("workflow/self-improvement/jev-efficiency-manifest.json", "utf8"));
	const directory = mkdtempSync(join(tmpdir(), "jev-efficiency-"));
	try {
		const inputPath = join(directory, "offline.json");
		writeFileSync(inputPath, JSON.stringify({
			schema_version: 1,
			manifest_id: frozen.manifest_id,
			population_fingerprint: SHA,
			hypotheses: [{ id: "synthetic-context", seam: "context_selection", results: frozen.tasks.map((task) => offlineResult(task)) }],
		}));
		const completed = spawnSync("scripts/jev-efficiency-campaign", ["rank-offline", "--manifest", "workflow/self-improvement/jev-efficiency-manifest.json", "--input", inputPath], { encoding: "utf8" });
		assert.equal(completed.status, 0, completed.stderr || completed.stdout);
		assert.equal(JSON.parse(completed.stdout).status, "offline_only_no_runtime_savings_claim");
	} finally {
		rmSync(directory, { recursive: true, force: true });
	}
});

test("private population validator binds categories, manifest and existing harness artifacts", () => {
	const frozen = JSON.parse(readFileSync("workflow/self-improvement/jev-efficiency-manifest.json", "utf8"));
	const bytes = readFileSync(POPULATION_FIXTURE);
	const population = JSON.parse(bytes);
	const result = validatePrivatePopulation(frozen, population.manifest_sha256, population);
	assert.equal(result.task_count, 7);
	assert.deepEqual(result.splits, { held_in: 3, held_out: 3, safety: 1 });
	assert.equal(result.sealed_held_out, false);
	const drifted = structuredClone(population);
	drifted.tasks[0].source.prompt = "api_key=should-not-enter-a-private-corpus";
	assert.throws(() => validatePrivatePopulation(frozen, population.manifest_sha256, drifted), /secret-like/);
});

test("live baseline dry-run enumerates 21 candidate-off cells without provider egress", () => {
	const manifestBytes = currentEvaluatorFixtureBytes();
	const frozen = JSON.parse(manifestBytes);
	const populationBytes = currentPopulationFixtureBytes(manifestBytes);
	const population = JSON.parse(populationBytes);
	const populationFingerprint = hashManifestBytes(populationBytes);
	const state = baselinePhaseState(populationFingerprint, { provider_checkpoint: "required" });
	const result = buildLiveDryRunPlan({
		manifest: frozen,
		manifestSha: hashManifestBytes(manifestBytes),
		population,
		populationFingerprint,
		state,
		config: { schema_version: 1, arm: "baseline", runner: "pi", provider: "fixture", model: "fixture-1", effort: "high", repetitions: 3, timeout_seconds: 600, max_cost_usd: 1, billing_mode: "metered", candidate_enabled: false, retry_policy: "none" },
	});
	assert.equal(result.mode, "dry_run_no_provider_egress");
	assert.equal(result.status, "awaiting_provider_authorization");
	assert.equal(result.executable, false);
	assert.equal(result.call_budget.cells, 21);
	assert.ok(result.cells.every((cell) => cell.argv_prefix.includes("json") && !JSON.stringify(cell).includes("api_key")));
	const directory = mkdtempSync(join(tmpdir(), "jev-live-dry-run-"));
	try {
		const configPath = join(directory, "config.json");
		const statePath = join(directory, "state.json");
		writeFileSync(configPath, JSON.stringify({ schema_version: 1, arm: "baseline", runner: "pi", provider: "fixture", model: "fixture-1", effort: "high", repetitions: 3, timeout_seconds: 600, max_cost_usd: 1, billing_mode: "metered", candidate_enabled: false, retry_policy: "none" }));
		writeFileSync(statePath, JSON.stringify(state));
		writeFileSync(join(directory,"manifest.json"),manifestBytes);
    writeFileSync(join(directory,"population.json"),populationBytes);
    const completed = spawnSync("scripts/jev-efficiency-campaign", ["dry-run-live", "--manifest", join(directory,"manifest.json"), "--population", join(directory,"population.json"), "--state", statePath, "--config", configPath], { encoding: "utf8" });
		assert.equal(completed.status, 0, completed.stderr || completed.stdout);
		assert.equal(JSON.parse(completed.stdout).call_budget.cells, 21);
	} finally {
		rmSync(directory, { recursive: true, force: true });
	}
});

test("live baseline dry-run rejects credentials, retries and candidate activation", () => {
	const manifestBytes = currentEvaluatorFixtureBytes();
	const frozen = JSON.parse(manifestBytes);
	const populationBytes = currentPopulationFixtureBytes(manifestBytes);
	const population = JSON.parse(populationBytes);
	const base = { schema_version: 1, arm: "baseline", runner: "pi", provider: "fixture", model: "fixture-1", effort: "high", repetitions: 3, timeout_seconds: 600, max_cost_usd: 1, billing_mode: "metered", candidate_enabled: false, retry_policy: "none" };
	const state = baselinePhaseState(hashManifestBytes(populationBytes));
	for (const config of [
		{ ...base, api_key: "forbidden" },
		{ ...base, retry_policy: "default" },
		{ ...base, candidate_enabled: true },
		{ ...base, provider: "provider-a", model: "provider-b/model" },
		{ ...base, max_cost_usd: -1 },
		{ ...base, billing_mode: "subscription" },
	]) {
		assert.throws(() => buildLiveDryRunPlan({ manifest: frozen, manifestSha: hashManifestBytes(manifestBytes), population, populationFingerprint: hashManifestBytes(populationBytes), state, config }));
	}
});

test("live baseline dry-run accepts an explicit zero incremental-cost cap", () => {
	const manifestBytes = currentEvaluatorFixtureBytes();
	const populationBytes = currentPopulationFixtureBytes(manifestBytes);
	const result = buildLiveDryRunPlan({
		manifest: JSON.parse(manifestBytes),
		manifestSha: hashManifestBytes(manifestBytes),
		population: JSON.parse(populationBytes),
		populationFingerprint: hashManifestBytes(populationBytes),
		state: baselinePhaseState(hashManifestBytes(populationBytes)),
		config: { schema_version: 1, arm: "baseline", runner: "pi", provider: "subscription", model: "included-model", effort: "high", repetitions: 3, timeout_seconds: 600, max_cost_usd: 0, billing_mode: "subscription", candidate_enabled: false, retry_policy: "none" },
	});
	assert.equal(result.runtime.max_cost_usd, 0);
});

test("live baseline execution requires both authorization and explicit process opt-in", () => {
	const manifestBytes = currentEvaluatorFixtureBytes();
	const populationBytes = currentPopulationFixtureBytes(manifestBytes);
	const frozen = JSON.parse(manifestBytes);
	const population = JSON.parse(populationBytes);
	const state = baselinePhaseState(hashManifestBytes(populationBytes));
	const config = { schema_version: 1, arm: "baseline", runner: "pi", provider: "subscription", model: "included-model", effort: "high", repetitions: 3, timeout_seconds: 600, max_cost_usd: 0, billing_mode: "subscription", candidate_enabled: false, retry_policy: "none" };
	const common = { manifest: frozen, manifestSha: hashManifestBytes(manifestBytes), population, populationFingerprint: hashManifestBytes(populationBytes), state: { ...state, provider_checkpoint: "required" }, config, artifactPath: ".", outputPath: ".workflow/jev-autonomous-efficiency/private/should-not-exist" };
	assert.throws(() => executeLiveBaseline({ ...common, env: { ETABLI_JEV_EFFICIENCY_LIVE: "1" } }), /checkpoint is not authorized/);
	assert.throws(() => executeLiveBaseline({ ...common, state: { ...state, provider_checkpoint: "authorized" }, env: {} }), /ETABLI_JEV_EFFICIENCY_LIVE=1/);
});

test("live baseline child environment strips Jev credentials", () => {
	assert.deepEqual(baselineChildEnvironment({ PATH: "/bin", TYPESAFE_API_KEY: "must-not-reach-baseline" }), {
		PATH: "/bin",
		PI_SKIP_VERSION_CHECK: "1",
	});
});

test("authorized live baseline orchestration writes 21 normalized simulated cells without calling a provider", () => {
	const manifestBytes = currentEvaluatorFixtureBytes();
	const populationBytes = currentPopulationFixtureBytes(manifestBytes);
	const historicalRoot = realpathSync(mkdtempSync(join(tmpdir(), "etabli-jev-historical-")));
	const historicalManifest = JSON.parse(manifestBytes);
	for (const path of historicalManifest.runtime_artifact.paths) {
		const source = path === "herdr/skills/herdr" ? resolve("tests/fixtures/jev-efficiency-herdr") : resolve(path);
		mkdirSync(dirname(join(historicalRoot, path)), { recursive: true });
		cpSync(source, join(historicalRoot, path), { recursive: true });
	}
	for (const path of new Set([historicalManifest.evaluator.path, ...historicalManifest.evaluator.bundle.paths])) {
		mkdirSync(dirname(join(historicalRoot, path)), { recursive: true });
		cpSync(resolve(path), join(historicalRoot, path));
	}
	for (const task of JSON.parse(populationBytes).tasks) {
		if (task.source.kind !== "existing_harness_task") continue;
		mkdirSync(dirname(join(historicalRoot, task.source.path)), { recursive: true });
		cpSync(resolve(task.source.path), join(historicalRoot, task.source.path), { recursive: true });
	}
	mkdirSync(join(historicalRoot, ".workflow/jev-autonomous-efficiency/private"), { recursive: true });
	const artifact = join(historicalRoot, `.workflow/jev-autonomous-efficiency/private/simulated-artifact-${process.pid}`);
	const output = join(historicalRoot, `.workflow/jev-autonomous-efficiency/private/simulated-live-${process.pid}`);
	let calls = 0;
	try {
		const snapshot = snapshotRuntimeArtifact({ manifest: historicalManifest, manifestSha: hashManifestBytes(manifestBytes), candidateEnabled: false, outputPath: artifact, root: historicalRoot });
		assert.equal(snapshot.candidate_enabled, false);
		assert.equal(existsSync(join(artifact, "pi/skills/herdr")), false);
		assert.equal(existsSync(join(artifact, "herdr/skills/herdr/SKILL.md")), true);
		const execution = {
			manifest: JSON.parse(manifestBytes),
			manifestSha: hashManifestBytes(manifestBytes),
			population: JSON.parse(populationBytes),
			populationFingerprint: hashManifestBytes(populationBytes),
			state: {
				...baselinePhaseState(hashManifestBytes(populationBytes)),
				provider_checkpoint: "authorized",
				baseline_runtime_artifact: { status: "frozen", candidate_enabled: false, fingerprint: snapshot.artifact_fingerprint },
			},
			config: { schema_version: 1, arm: "baseline", runner: "pi", provider: "subscription", model: "included-model", effort: "high", repetitions: 3, timeout_seconds: 600, max_cost_usd: 0, billing_mode: "subscription", candidate_enabled: false, retry_policy: "none" },
			artifactPath: artifact,
			outputPath: output,
			root: historicalRoot,
			env: { ETABLI_JEV_EFFICIENCY_LIVE: "1" },
			cellExecutor: ({ task }) => {
				calls += 1;
				return {
					task_id: task.id,
					protected: task.protected,
					passed: true,
					latency_ms: 1,
					traditional_llm: { measured: true, provenance: "provider_receipt", input_tokens: 90, output_tokens: 10, cached_input_tokens: 0, cache_write_input_tokens: 0, total_tokens: 100, cost_usd: 0.5, cost_status: "measured" },
					jev: { calls: 0, input_tokens: 0, output_tokens: 0, total_tokens: 0, cost_usd: 0, cost_status: "not_incurred", latency_ms: 0, abstentions: 0, escalations: 0, retries: 0 },
				};
			},
		};
		const result = executeLiveBaseline(execution);
		assert.equal(calls, 21);
		assert.equal(result.repetitions.length, 3);
		assert.equal(result.runtime.candidate_enabled, false);
		assert.equal(existsSync(join(output, "baseline.json")), true);
		const identityPath=join(output, "execution-identity.json");
		assert.equal(existsSync(identityPath),true);
		const originalIdentity=readFileSync(identityPath,"utf8");
		const identity=JSON.parse(originalIdentity);identity.manifest_sha256="stale";
		writeFileSync(identityPath,JSON.stringify(identity));
		assert.throws(()=>executeLiveBaseline({...execution,outputPath:output+"-resume",resumeOutputPath:output}),/resume execution identity/);
		assert.equal(calls,21);
		writeFileSync(identityPath,originalIdentity);
		const firstCell=buildLiveDryRunPlan(execution).cells[0];
		const cellDirectory=join(output,firstCell.cell_id);mkdirSync(cellDirectory);
		const events=[{type:"message_end",message:{role:"assistant",provider:"subscription",model:"included-model",
			responseId:"old-response",stopReason:"stop",content:[{type:"text",text:"old final"}],
			usage:{input:90,output:10,cacheRead:0,cacheWrite:0,totalTokens:100}}}];
		writeFileSync(join(cellDirectory,"events.jsonl"),events.map(event=>JSON.stringify(event)).join("\n"));
		writeFileSync(join(cellDirectory,"normalized.json"),JSON.stringify({measured:true,transport_success:true,measurement_errors:[],models:["subscription/included-model"],final_text:"old final",usage:{total_tokens:100}}));
		writeFileSync(join(cellDirectory,"transcript.txt"),"old final");
		assert.throws(()=>executeLiveBaseline({...execution,outputPath:output+"-resume",resumeOutputPath:output}),/resume normalization drift/);
		assert.equal(calls,21);
		let incompleteCalls=0;
		const partial=executeLiveBaseline({...execution,outputPath:output+"-partial",cellExecutor:({task})=>{
			incompleteCalls++;return {...taskRow(task,100),traditional_llm:{measured:false,provenance:"provider_receipt",total_tokens:null,
			known_usage:{total_tokens:100},measurement_errors:["Call-class coverage unproven: child"]},
			jev:{calls:0,input_tokens:0,output_tokens:0,total_tokens:0,cost_usd:0,cost_status:"not_incurred",latency_ms:0,abstentions:0,escalations:0,retries:0}};
		}});
		assert.equal(incompleteCalls,1);assert.equal(partial.status,"non_comparable");
		assert.equal(partial.repetitions[0].tasks[0].traditional_llm.known_usage.total_tokens,100);
		assert.equal(existsSync(join(output+"-partial","baseline.json")),true);
	} finally {
		rmSync(historicalRoot, { recursive: true, force: true });
	}
});


test("non-comparable campaign results retain unknown totals without an efficiency verdict",()=>{
 const baseline=run("baseline",100);baseline.status="non_comparable";
 baseline.repetitions[0].tasks[0].traditional_llm={measured:false,total_tokens:null,known_usage:{total_tokens:100},measurement_errors:["Call-class coverage unproven: child"]};
 const result=compare(baseline,run("candidate",60));
 assert.equal(result.status,"non_comparable");assert.equal(result.verdict,"inconclusive");
 assert.equal(result.repetitions.length,0);
});


test("real baseline collector preserves incomplete receipts and resume without relaunch",async()=>{
 const {runPiBaselineCell,loadCompletedBaselineCell}=await import("../scripts/lib/jev-efficiency-campaign.mjs");
 const output=realpathSync(mkdtempSync(join(tmpdir(),"incomplete-baseline-")));
 const events=[{type:"session",timestamp:new Date().toISOString()},{type:"message_end",message:{role:"assistant",provider:"fixture",model:"model",responseId:"incomplete-native",stopReason:"stop",content:[{type:"text",text:"done"}],usage:{input:90,output:10,cacheRead:0,cacheWrite:0,totalTokens:100}}}];
 const child=join(output,"child.cjs");writeFileSync(child,`process.stdout.write(${JSON.stringify(events.map(e=>JSON.stringify(e)).join("\n"))});`);
 const task={id:"answer",protected:false,source:{kind:"private_inline",prompt:"say done"},grader:{kind:"deterministic_text_contract",required_concepts:["done"]}};
 const cell={cell_id:"cell",argv_prefix:[process.execPath,child]},config={timeout_seconds:10,provider:"fixture",model:"model"};
 try {
  const result=runPiBaselineCell({root:resolve("."),task,cell,config,output,env:process.env});
  assert.equal(result.passed,true);assert.equal(result.traditional_llm.measured,false);
  assert.equal(result.traditional_llm.total_tokens,null);assert.equal(result.traditional_llm.known_usage.total_tokens,100);
  assert.equal(JSON.parse(readFileSync(join(output,"cell/cell-result.json"))).traditional_llm.total_tokens,null);
  const resumed=loadCompletedBaselineCell({root:resolve("."),task,cell,config,resumeOutput:output});
  assert.equal(resumed.traditional_llm.known_usage.total_tokens,100);assert.equal(resumed.traditional_llm.measured,false);
 } finally {rmSync(output,{recursive:true,force:true});}
});

test("real baseline collector retains failed terminal receipts on resume without relaunch",async()=>{
 const {runPiBaselineCell,loadCompletedBaselineCell}=await import("../scripts/lib/jev-efficiency-campaign.mjs");
 const output=realpathSync(mkdtempSync(join(tmpdir(),"incomplete-baseline-")));
 const events=[{type:"session",timestamp:new Date().toISOString()},{type:"message_end",message:{role:"assistant",provider:"fixture",model:"model",responseId:"incomplete-native",stopReason:"stop",content:[{type:"text",text:"done"}],usage:{input:90,output:10,cacheRead:0,cacheWrite:0,totalTokens:100}}}];
 const child=join(output,"child.cjs");writeFileSync(child,`process.stdout.write(${JSON.stringify(events.map(e=>JSON.stringify(e)).join("\n"))});process.exitCode=7;`);
 const task={id:"answer",protected:false,source:{kind:"private_inline",prompt:"say done"},grader:{kind:"deterministic_text_contract",required_concepts:["done"]}};
 const cell={cell_id:"cell",argv_prefix:[process.execPath,child]},config={timeout_seconds:10,provider:"fixture",model:"model"};
 try {
  const result=runPiBaselineCell({root:resolve("."),task,cell,config,output,env:process.env});
  assert.equal(result.passed,false);assert.equal(result.traditional_llm.measured,false);
  assert.equal(result.traditional_llm.total_tokens,null);assert.equal(result.traditional_llm.known_usage.total_tokens,100);
  assert.equal(JSON.parse(readFileSync(join(output,"cell/cell-result.json"))).traditional_llm.total_tokens,null);
  const resumed=loadCompletedBaselineCell({root:resolve("."),task,cell,config,resumeOutput:output});
  assert.equal(resumed.traditional_llm.known_usage.total_tokens,100);assert.equal(resumed.traditional_llm.measured,false);
 } finally {rmSync(output,{recursive:true,force:true});}
});
