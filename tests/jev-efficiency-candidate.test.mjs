import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, rmSync } from "node:fs";
import { resolve } from "node:path";
import test from "node:test";
import { JEV_ROUTE_CAPSULE_METADATA, preflightAndRenderRouteCapsule } from "../pi/extensions/lib/jev-route-capsule.mjs";
import { snapshotRuntimeArtifact } from "../scripts/lib/jev-efficiency-campaign.mjs";
import { hashManifestBytes } from "../scripts/lib/evaluator-bundle.mjs";
import {
  appendRouteCapsule,
  assertPiRetryProfile,
  assertPiRuntimeVersion,
  candidateChildEnvironment,
  consumeValidatedEscalation,
  decideEscalatedCampaign,
  executeLiveCandidate,
  normalizeCandidatePreflight,
  prepareCandidatePrompt,
} from "../scripts/lib/jev-efficiency-candidate.mjs";

const SHA = "a".repeat(64);
const POPULATION_FIXTURE = "tests/fixtures/jev-efficiency/population.json";
const PRIVATE_TEST_ROOT = resolve(".workflow/jev-autonomous-efficiency/private");
mkdirSync(PRIVATE_TEST_ROOT, { recursive: true });

function syntheticBaseline({ manifest, manifestSha, population, populationFingerprint }) {
  return {
    schema_version: 1,
    arm: "baseline",
    campaign_id: manifest.manifest_id,
    manifest_sha256: manifestSha,
    evaluator_bundle_sha256: manifest.evaluator.bundle.sha256,
    artifact_fingerprint: "e".repeat(64),
    population_fingerprint: populationFingerprint,
    runtime: { runner: "pi", provider: "openai-codex", model: "gpt-6-astra", effort: "medium", runtime_fingerprint: "f".repeat(64), candidate_enabled: false },
    repetitions: [1, 2, 3].map((repetition) => ({
      repetition,
      tasks: population.tasks.map((task) => ({
        task_id: task.id,
        protected: task.protected,
        passed: true,
        latency_ms: 1,
        traditional_llm: { measured: true, provenance: "provider_receipt", input_tokens: 90, output_tokens: 10, cached_input_tokens: 0, cache_write_input_tokens: 0, total_tokens: 100, cost_usd: null, cost_status: "unavailable" },
        jev: { calls: 0, input_tokens: 0, output_tokens: 0, total_tokens: 0, cost_usd: 0, cost_status: "not_incurred", latency_ms: 0, abstentions: 0, escalations: 0, retries: 0 },
      })),
    })),
  };
}

function response({ choice = "planning", confidence = 0.95, inputTokens = 9, outputTokens = 3 } = {}) {
  const probabilities = { plan_implementation: 0.025, planning: 0.9, implementation: 0.025, review: 0.025, other: 0.025 };
  probabilities.planning = choice === "planning" ? confidence : (1 - confidence) / 4;
  for (const key of Object.keys(probabilities)) {
    if (key !== "planning") probabilities[key] = key === choice ? confidence : (1 - confidence) / 4;
  }
  return new Response(JSON.stringify({
    model: "jev-1.13.0",
    answers: { route: { type: "choice", choice, probabilities, confidence } },
    usage: { input_tokens: inputTokens, output_tokens: outputTokens },
  }), { status: 200, headers: { "content-type": "application/json" } });
}

async function withTypeSafeFixture(fetchImpl, run) {
  const priorKey = process.env.TYPESAFE_API_KEY;
  const priorFetch = globalThis.fetch;
  process.env.TYPESAFE_API_KEY = "fixture-typesafe-key";
  globalThis.fetch = fetchImpl;
  try {
    return await run();
  } finally {
    globalThis.fetch = priorFetch;
    if (priorKey === undefined) delete process.env.TYPESAFE_API_KEY;
    else process.env.TYPESAFE_API_KEY = priorKey;
  }
}

test("accepted Jev route causally renders one fixed capsule with zero retry", { concurrency: false }, async () => {
  let calls = 0;
  const result = await withTypeSafeFixture(async (_url, options) => {
    calls += 1;
    const request = JSON.parse(options.body);
    assert.equal(request.model, "jev-1.13.0");
    assert.deepEqual(Object.keys(request.state), ["user_intent"]);
    return response();
  }, () => preflightAndRenderRouteCapsule("Plan the next bounded implementation."));
  assert.equal(calls, 1);
  assert.equal(result.status, "accepted");
  assert.equal(result.route, "planning");
  assert.equal(result.retries, 0);
  assert.match(result.capsule, /^ETABLI_ROUTE_CAPSULE planning v1/);
  assert.equal(normalizeCandidatePreflight(result).comparable, true);
});

test("provider failure performs one attempt and becomes non-comparable fallback", { concurrency: false }, async () => {
  let calls = 0;
  const result = await withTypeSafeFixture(async () => {
    calls += 1;
    throw new Error("offline fixture");
  }, () => preflightAndRenderRouteCapsule("Implement the READY plan."));
  assert.equal(calls, 1);
  assert.equal(result.status, "error");
  assert.equal(result.retries, 0);
  const normalized = normalizeCandidatePreflight(result);
  assert.equal(normalized.fallback, true);
  assert.equal(normalized.comparable, false);
  assert.equal(normalized.non_comparable_reason, "non_comparable_missing_jev_usage");
  assert.equal(appendRouteCapsule("unchanged prompt", result), "unchanged prompt");
});

test("low-confidence or other route falls back without appending a capsule", { concurrency: false }, async () => {
  for (const fixture of [
    { choice: "planning", confidence: 0.5 },
    { choice: "other", confidence: 0.95 },
  ]) {
    const result = await withTypeSafeFixture(async () => response(fixture), () => preflightAndRenderRouteCapsule("Explain the current state."));
    assert.equal(result.status, "abstained");
    assert.equal(normalizeCandidatePreflight(result).fallback, true);
    assert.equal(appendRouteCapsule("exact baseline", result), "exact baseline");
  }
});

test("local empty or secret-like rejection reports zero provider calls", async () => {
  for (const prompt of ["", "api_key=not-a-real-credential-value"]) {
    const result = await preflightAndRenderRouteCapsule(prompt);
    const normalized = normalizeCandidatePreflight(result);
    assert.equal(result.status, "abstained");
    assert.equal(result.calls, 0);
    assert.equal(normalized.comparable, false);
  }
});

test("protected and private-inline cells bypass the artifact and strip the child credential", async () => {
  for (const input of [
    { category: "review", protectedRoute: true, privateInline: false },
    { category: "planning", protectedRoute: false, privateInline: true },
    { category: "answer", protectedRoute: false, privateInline: false },
  ]) {
    const prepared = await prepareCandidatePrompt({ artifactPath: "/does/not/exist", prompt: "baseline bytes", ...input });
    assert.equal(prepared.bypassed, true);
    assert.equal(prepared.prompt, "baseline bytes");
    assert.equal(prepared.jev.calls, 0);
  }
  assert.deepEqual(candidateChildEnvironment({ PATH: "/bin", TYPESAFE_API_KEY: "parent-only" }), { PATH: "/bin", PI_SKIP_VERSION_CHECK: "1" });
});

test("candidate execution rejects Pi runtime drift before provider work", () => {
  const state = { execution_runtime: { pi_version: "0.86.1" } };
  assert.equal(assertPiRuntimeVersion(state, "0.86.1"), "0.86.1");
  assert.throws(() => assertPiRuntimeVersion(state, "0.85.1"), /Pi runtime drift/);
});

test("candidate execution rejects a retry-enabled Pi profile before provider work", () => {
  const state = { execution_runtime: { retry_profile: "dedicated_zero_retry_agent_dir" } };
  assert.equal(assertPiRetryProfile(state, "dedicated_zero_retry_agent_dir"), "dedicated_zero_retry_agent_dir");
  assert.throws(() => assertPiRetryProfile(state, "unsafe_or_unbounded"), /Pi retry profile drift/);
});

test("capsule source fingerprints bind current public workflow sources", () => {
  for (const [path, expected] of Object.entries(JEV_ROUTE_CAPSULE_METADATA.source_fingerprints)) {
    const actual = createHash("sha256").update(readFileSync(path)).digest("hex");
    assert.equal(actual, expected, path);
  }
});

test("escalation coordinator preserves the typed Jev abstention and validates every binding", () => {
  const state = {
    observation_fingerprint: SHA,
    proposal_fingerprint: "b".repeat(64),
    diagnosis: { producer: "jev", valid: true, abstained: true, receipt_fingerprint: "c".repeat(64) },
  };
  const receipt = {
    schema_version: 1,
    producer: "traditional_llm",
    status: "completed",
    observation_fingerprint: SHA,
    diagnosis_receipt_fingerprint: "c".repeat(64),
    proposal_fingerprint: "b".repeat(64),
    model_receipt_fingerprint: "d".repeat(64),
    retry_events: 0,
  };
  const result = consumeValidatedEscalation({ state, receipt });
  assert.equal(result.decision, "deduplicate");
  assert.equal(result.diagnosis.producer, "jev");
  assert.equal(result.diagnosis.abstained, true);
  assert.equal(result.escalation.status, "consumed");
  assert.equal(result.escalation.producer, "traditional_llm");
  assert.equal(result.escalation.valid, true);
  assert.deepEqual(result.escalation.bindings, {
    observation_fingerprint: SHA,
    diagnosis_receipt_fingerprint: "c".repeat(64),
    proposal_fingerprint: "b".repeat(64),
  });
  assert.throws(() => consumeValidatedEscalation({ state, receipt: { ...receipt, proposal_fingerprint: SHA } }), /binding mismatch/);
});

test("escalated controller continues without mutating the immutable Jev abstention", () => {
  const manifest = JSON.parse(readFileSync("workflow/self-improvement/jev-efficiency-manifest.json", "utf8"));
  const state = {
    offline_hypotheses: 4,
    live_candidates: 1,
    private_population_fingerprint: SHA,
    offline_validation: "passed",
    baseline_runtime_artifact: { status: "frozen", candidate_enabled: false, fingerprint: SHA },
    provider_checkpoint: "authorized",
    candidate_runtime_enabled: false,
    baseline: { status: "accepted", candidate_enabled: false, result_fingerprint: SHA },
    observation_fingerprint: SHA,
    diagnosis: { producer: "jev", valid: true, abstained: true, receipt_fingerprint: "b".repeat(64) },
    deduplication: { status: "unique", evidence_fingerprint: SHA },
    proposal_fingerprint: "f".repeat(64),
    plan_status: "READY",
    plan_fingerprint: SHA,
    adversary_verdict: "GO",
    adversary_fingerprint: SHA,
    implementation_status: "verified",
    implementation_fingerprint: SHA,
  };
  const receipt = {
    schema_version: 1,
    producer: "traditional_llm",
    status: "completed",
    observation_fingerprint: SHA,
    diagnosis_receipt_fingerprint: "b".repeat(64),
    proposal_fingerprint: "f".repeat(64),
    model_receipt_fingerprint: "d".repeat(64),
    retry_events: 0,
  };
  state.escalation = consumeValidatedEscalation({ state, receipt }).escalation;
  const result = decideEscalatedCampaign(manifest, state, receipt);
  assert.equal(result.decision, "evaluate_candidate");
  assert.equal(result.escalation_status, "consumed");
  assert.equal(result.diagnosis_abstained, true);
  assert.equal(state.diagnosis.abstained, true);
  assert.throws(() => decideEscalatedCampaign(manifest, {
    ...state,
    escalation: { ...state.escalation, receipt_fingerprint: "9".repeat(64) },
  }, receipt), /receipt_fingerprint mismatch/);
  assert.throws(() => decideEscalatedCampaign(manifest, state, { ...receipt, proposal_fingerprint: SHA }), /binding mismatch/);
});

test("candidate orchestrator keeps the frozen evaluator and produces a 21-cell simulated result", async () => {
  const manifestBytes = readFileSync("workflow/self-improvement/jev-efficiency-manifest.json");
  const populationBytes = readFileSync(POPULATION_FIXTURE);
  const manifest = JSON.parse(manifestBytes);
  const population = JSON.parse(populationBytes);
  const manifestSha = hashManifestBytes(manifestBytes);
  const populationFingerprint = hashManifestBytes(populationBytes);
  const baseline = syntheticBaseline({ manifest, manifestSha, population, populationFingerprint });
  const baselineBytes = Buffer.from(`${JSON.stringify(baseline, null, 2)}\n`);
  const artifact = resolve(`.workflow/jev-autonomous-efficiency/private/simulated-candidate-artifact-${process.pid}-${Date.now()}`);
  const output = resolve(`.workflow/jev-autonomous-efficiency/private/simulated-candidate-run-${process.pid}-${Date.now()}`);
  let calls = 0;
  try {
    const snapshot = snapshotRuntimeArtifact({ manifest, manifestSha: hashManifestBytes(manifestBytes), candidateEnabled: true, outputPath: artifact });
    const state = {
      provider_checkpoint: "authorized",
      plan_status: "READY",
      adversary_verdict: "GO",
      candidate_runtime_enabled: false,
      private_population_fingerprint: populationFingerprint,
      execution_runtime: { pi_version: "0.86.1", retry_profile: "dedicated_zero_retry_agent_dir" },
      baseline: {
        status: "accepted",
        candidate_enabled: false,
        result_fingerprint: hashManifestBytes(baselineBytes),
      },
      candidate_runtime_artifact: { status: "frozen", candidate_enabled: true, fingerprint: snapshot.artifact_fingerprint },
    };
    const result = await executeLiveCandidate({
      manifest,
      manifestSha,
      population,
      populationFingerprint,
      state,
      config: { schema_version: 1, arm: "candidate", runner: "pi", provider: "openai-codex", model: "gpt-6-astra", effort: "medium", repetitions: 3, timeout_seconds: 600, max_cost_usd: 0, billing_mode: "subscription", candidate_enabled: true, retry_policy: "none" },
      baseline,
      artifactPath: artifact,
      outputPath: output,
      env: { ETABLI_JEV_EFFICIENCY_LIVE: "1" },
      runtimeVersion: () => "0.86.1",
      runtimeRetryProfile: () => "dedicated_zero_retry_agent_dir",
      cellExecutor: async ({ task }) => {
        calls += 1;
        const eligible = ["planning", "implementation", "review"].includes(task.category) && !task.protected && task.source.kind !== "private_inline";
        return {
          task_id: task.id,
          protected: task.protected,
          passed: true,
          latency_ms: 1,
          traditional_llm: { measured: true, provenance: "provider_receipt", input_tokens: 90, output_tokens: 10, cached_input_tokens: 0, cache_write_input_tokens: 0, total_tokens: 100, cost_usd: null, cost_status: "unavailable" },
          jev: eligible
            ? { calls: 1, input_tokens: 5, output_tokens: 1, total_tokens: 6, cost_usd: null, cost_status: "unavailable", latency_ms: 1, abstentions: 0, escalations: 0, retries: 0 }
            : { calls: 0, input_tokens: 0, output_tokens: 0, total_tokens: 0, cost_usd: 0, cost_status: "not_incurred", latency_ms: 0, abstentions: 0, escalations: 0, retries: 0 },
        };
      },
    });
    assert.equal(calls, 21);
    assert.equal(result.runtime.runtime_fingerprint, baseline.runtime.runtime_fingerprint);
    assert.equal(result.runtime.candidate_enabled, true);
    assert.equal(result.repetitions.flatMap((row) => row.tasks).reduce((sum, task) => sum + task.jev.calls, 0), 9);
    assert.equal(existsSync(`${output}/candidate.json`), true);
  } finally {
    rmSync(output, { recursive: true, force: true });
    rmSync(artifact, { recursive: true, force: true });
  }
});
