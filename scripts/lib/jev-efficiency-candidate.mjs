import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { existsSync, lstatSync, mkdirSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
import { basename, dirname, relative, resolve, sep } from "node:path";
import { containsSecretLike } from "../../pi/extensions/lib/semantic-judgment.mjs";
import { normalizeEvents } from "./harness-token-usage.mjs";
import { fingerprintArtifact } from "./skill-eval.mjs";
import { fingerprintEvaluatorBundle, fingerprintEvaluatorFile } from "./evaluator-bundle.mjs";
import { decideCampaign, validateCampaignManifest, validatePrivatePopulation } from "./jev-efficiency-campaign.mjs";

const SHA256 = /^[a-f0-9]{64}$/;
const ELIGIBLE_CATEGORIES = new Set(["planning", "implementation", "review"]);
const MAX_CAPSULE_BYTES = 4096;

function fail(message) {
  throw new Error(message);
}

function fingerprint(value) {
  return createHash("sha256").update(value).digest("hex");
}

function isCount(value) {
  return Number.isInteger(value) && value >= 0;
}

export function candidateChildEnvironment(env) {
  const child = { ...env, PI_SKIP_VERSION_CHECK: "1" };
  delete child.TYPESAFE_API_KEY;
  return child;
}

function observePiVersion(env) {
  const completed = spawnSync("pi", ["--version"], { env, encoding: "utf8" });
  if (completed.status !== 0) fail(`unable to verify Pi runtime version: ${completed.stderr || completed.stdout}`);
  return completed.stdout.trim();
}

function observePiRetryProfile(env) {
  const agentDirectory = env.PI_CODING_AGENT_DIR;
  if (typeof agentDirectory !== "string" || agentDirectory.length === 0) fail("PI_CODING_AGENT_DIR is required for a live candidate");
  let settings;
  try { settings = JSON.parse(readFileSync(resolve(agentDirectory, "settings.json"), "utf8")); }
  catch (error) { fail(`unable to verify Pi retry profile: ${error.message}`); }
  return settings.retry?.enabled === false
    && settings.retry?.maxRetries === 0
    && settings.retry?.provider?.maxRetries === 0
    && settings.cacheWarming === "off"
    ? "dedicated_zero_retry_agent_dir"
    : "unsafe_or_unbounded";
}

export function assertPiRuntimeVersion(state, observedVersion) {
  const expectedVersion = state?.execution_runtime?.pi_version;
  if (typeof expectedVersion !== "string" || expectedVersion.length === 0) fail("campaign Pi runtime version is missing");
  if (observedVersion !== expectedVersion) fail(`Pi runtime drift: expected ${expectedVersion}, observed ${observedVersion || "unavailable"}`);
  return observedVersion;
}

export function assertPiRetryProfile(state, observedProfile) {
  const expectedProfile = state?.execution_runtime?.retry_profile;
  if (expectedProfile !== "dedicated_zero_retry_agent_dir") fail("campaign Pi retry profile is missing or unsupported");
  if (observedProfile !== expectedProfile) fail(`Pi retry profile drift: expected ${expectedProfile}, observed ${observedProfile}`);
  return observedProfile;
}

export function candidateEligibility({ category, protectedRoute, privateInline }) {
  return protectedRoute !== true && privateInline !== true && ELIGIBLE_CATEGORIES.has(category);
}

function validateSourceFingerprints(value) {
  if (!value || typeof value !== "object" || Array.isArray(value) || Object.keys(value).length === 0) fail("candidate source fingerprints are missing");
  for (const [path, digest] of Object.entries(value)) {
    if (!path.startsWith("workflow/") || !SHA256.test(digest)) fail("candidate source fingerprint is invalid");
  }
  return Object.freeze({ ...value });
}

export function normalizeCandidatePreflight(result) {
  if (!result || typeof result !== "object" || result.schema_version !== 1) fail("candidate preflight schema mismatch");
  const localAbstention = result.status === "abstained" && ["empty_prompt", "secret_like_prompt"].includes(result.reason);
  if (result.model !== "jev-1.13.0" || result.calls !== (localAbstention ? 0 : 1) || result.retries !== 0 || !isCount(result.latency_ms)) fail("candidate preflight provenance mismatch");
  const sourceFingerprints = validateSourceFingerprints(result.source_fingerprints);
  if (result.status === "accepted") {
    if (!["planning", "implementation", "review"].includes(result.route)) fail("candidate route is invalid");
    if (typeof result.confidence !== "number" || result.confidence < 0.7 || result.confidence > 1) fail("candidate confidence is invalid");
    if (typeof result.capsule !== "string" || Buffer.byteLength(result.capsule, "utf8") === 0 || Buffer.byteLength(result.capsule, "utf8") > MAX_CAPSULE_BYTES) fail("candidate capsule size is invalid");
    if (containsSecretLike(result.capsule) || !SHA256.test(result.capsule_fingerprint) || fingerprint(result.capsule) !== result.capsule_fingerprint) fail("candidate capsule integrity failed");
    if (!result.usage || !isCount(result.usage.input_tokens) || !isCount(result.usage.output_tokens)) fail("accepted Jev usage is unavailable");
    return Object.freeze({ ...result, source_fingerprints: sourceFingerprints, comparable: true, fallback: false });
  }
  if (!["abstained", "error"].includes(result.status) || result.capsule !== null || result.capsule_fingerprint !== null) fail("candidate fallback result is invalid");
  const usageAvailable = result.usage !== null && isCount(result.usage?.input_tokens) && isCount(result.usage?.output_tokens);
  return Object.freeze({
    ...result,
    source_fingerprints: sourceFingerprints,
    comparable: usageAvailable,
    non_comparable_reason: usageAvailable ? null : "non_comparable_missing_jev_usage",
    fallback: true,
  });
}

export function appendRouteCapsule(prompt, preflight) {
  const normalized = normalizeCandidatePreflight(preflight);
  if (normalized.fallback) return String(prompt);
  return `${String(prompt).trimEnd()}\n\n${normalized.capsule}\n`;
}

export async function loadCandidateArtifact(artifactPath) {
  const modulePath = resolve(artifactPath, "pi/extensions/lib/jev-route-capsule.mjs");
  const candidate = await import(`${pathToFileURL(modulePath).href}?artifact=${encodeURIComponent(fingerprint(modulePath))}`);
  if (typeof candidate.preflightAndRenderRouteCapsule !== "function" || !candidate.JEV_ROUTE_CAPSULE_METADATA?.source_fingerprints) fail("candidate artifact interface is missing");
  return Object.freeze({
    preflightAndRenderRouteCapsule: candidate.preflightAndRenderRouteCapsule,
    source_fingerprints: Object.freeze({ ...candidate.JEV_ROUTE_CAPSULE_METADATA.source_fingerprints }),
  });
}

export async function prepareCandidatePrompt({ artifactPath, prompt, category, protectedRoute = false, privateInline = false }) {
  if (!candidateEligibility({ category, protectedRoute, privateInline })) {
    return Object.freeze({
      prompt: String(prompt),
      bypassed: true,
      comparable: true,
      preflight: null,
      jev: { calls: 0, input_tokens: 0, output_tokens: 0, total_tokens: 0, latency_ms: 0, abstentions: 0, escalations: 0, retries: 0 },
    });
  }
  const artifact = await loadCandidateArtifact(artifactPath);
  const preflight = normalizeCandidatePreflight(await artifact.preflightAndRenderRouteCapsule(String(prompt)));
  if (JSON.stringify(preflight.source_fingerprints) !== JSON.stringify(artifact.source_fingerprints)) fail("candidate artifact source declaration drift");
  const usage = preflight.usage;
  return Object.freeze({
    prompt: appendRouteCapsule(prompt, preflight),
    bypassed: false,
    comparable: preflight.comparable,
    non_comparable_reason: preflight.non_comparable_reason ?? null,
    preflight,
    jev: {
      calls: preflight.calls,
      input_tokens: usage?.input_tokens ?? null,
      output_tokens: usage?.output_tokens ?? null,
      total_tokens: usage ? usage.input_tokens + usage.output_tokens : null,
      latency_ms: preflight.latency_ms,
      abstentions: preflight.status === "abstained" ? 1 : 0,
      escalations: preflight.fallback ? 1 : 0,
      retries: 0,
    },
  });
}

function validateCandidateConfig(config) {
  const allowed = new Set(["schema_version", "arm", "runner", "provider", "model", "effort", "repetitions", "timeout_seconds", "max_cost_usd", "billing_mode", "candidate_enabled", "retry_policy"]);
  for (const key of Object.keys(config ?? {})) if (!allowed.has(key)) fail(`candidate config contains unsupported field: ${key}`);
  if (config?.schema_version !== 1 || config.arm !== "candidate" || config.runner !== "pi" || config.candidate_enabled !== true) fail("candidate config must select schema 1, candidate arm, pi, and candidate_enabled true");
  if (!["off", "minimal", "low", "medium", "high", "xhigh", "max"].includes(config.effort) || !config.provider || !config.model) fail("candidate model configuration is invalid");
  if (config.model.includes("/") && !config.model.startsWith(`${config.provider}/`)) fail("candidate model provider prefix contradicts provider");
  if (config.repetitions !== 3 || !Number.isSafeInteger(config.timeout_seconds) || config.timeout_seconds < 1 || config.timeout_seconds > 3600) fail("candidate repetition or timeout contract is invalid");
  if (config.retry_policy !== "none") fail("candidate retry policy must be none");
  if (!["metered", "subscription"].includes(config.billing_mode) || typeof config.max_cost_usd !== "number" || config.max_cost_usd < 0) fail("candidate billing contract is invalid");
  if (config.billing_mode === "subscription" && config.max_cost_usd !== 0) fail("subscription candidate requires zero incremental-cost cap");
  return config;
}

function validateCandidateArtifact({ manifest, manifestSha, artifactPath }) {
  const metadata = JSON.parse(readFileSync(resolve(artifactPath, "runtime-state.json"), "utf8"));
  if (metadata.schema_version !== 1 || metadata.manifest_id !== manifest.manifest_id || metadata.manifest_sha256 !== manifestSha || metadata.candidate_enabled !== true) fail("candidate artifact state drift");
  if (JSON.stringify(metadata.source_paths) !== JSON.stringify(manifest.runtime_artifact.paths) || JSON.stringify(metadata.excluded_paths) !== JSON.stringify(manifest.runtime_artifact.excludes)) fail("candidate artifact inventory drift");
  return fingerprintArtifact(resolve(artifactPath));
}

function privateOutputPath(root, outputPath) {
  const privateRoot = resolve(root, ".workflow/jev-autonomous-efficiency/private");
  const stat = lstatSync(privateRoot);
  if (!stat.isDirectory() || stat.isSymbolicLink() || realpathSync(privateRoot) !== privateRoot) fail("private campaign directory must be a real directory");
  const output = resolve(outputPath);
  const rel = relative(privateRoot, output);
  if (!rel || rel === ".." || rel.startsWith(`..${sep}`) || rel.startsWith(sep) || dirname(output) !== privateRoot || existsSync(output)) fail("candidate output must be a new direct private child");
  return output;
}

function parseJsonLines(value) {
  return value.split(/\r?\n/).filter((line) => line.trim()).map((line, index) => {
    try { return JSON.parse(line); } catch (error) { fail(`Pi JSON output line ${index + 1} is invalid: ${error.message}`); }
  });
}

function piCoverage(events) {
  const serialized = JSON.stringify(events);
  const seen = {
    assistant: events.some((event) => event.type === "message_end" && event.message?.role === "assistant"),
    child: events.some((event) => event.parent_tool_use_id || event.subagent_stats?.spawned > 0),
    model_tool: events.some((event) => event.type === "message_end" && event.message?.role === "toolResult" && event.message?.usage),
    compaction: /compaction|branch_summary/.test(serialized),
    retry: events.some((event) => /retry/.test(event.type ?? "")),
  };
  return Object.fromEntries(Object.entries(seen).map(([name, triggered]) => [name, { status: triggered ? "complete" : "not_triggered", evidence: triggered ? `native_event_scan:${name}` : `native_event_scan:no_${name}` }]));
}

function exactObjectMatch(actual, required) {
  return Object.entries(required).every(([key, value]) => value && typeof value === "object" && !Array.isArray(value) ? actual?.[key] && exactObjectMatch(actual[key], value) : actual?.[key] === value);
}

function gradeInline(task, finalText) {
  if (task.grader.kind === "deterministic_text_contract") {
    const normalized = finalText.toLowerCase();
    return task.grader.required_concepts.every((concept) => normalized.includes(concept.toLowerCase()));
  }
  try {
    const cleaned = finalText.trim().replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "");
    return exactObjectMatch(JSON.parse(cleaned), task.grader.required);
  } catch { return false; }
}

function prepareHarnessCell(root, task, worktree) {
  const harnessTask = basename(task.source.path);
  const script = 'set -euo pipefail; HARNESS_ROOT="$1"; source "$1/scripts/lib/etabli-harness-eval.sh"; harness_prepare_worktree "$2" "$3"';
  const prepared = spawnSync("bash", ["-c", script, "jev-candidate-prepare", root, harnessTask, worktree], { encoding: "utf8" });
  if (prepared.status !== 0) fail(`failed to prepare harness task ${harnessTask}: ${prepared.stderr || prepared.stdout}`);
  return harnessTask;
}

function gradeHarnessCell(root, taskId, worktree, transcript, runnerExit) {
  const graded = spawnSync(resolve(root, "scripts/etabli-harness-eval"), ["grade", "--task", taskId, "--worktree", worktree, "--transcript", transcript, "--runner", "pi", "--runner-exit", String(runnerExit)], { encoding: "utf8" });
  if (graded.status !== 0) fail(`harness grader failed for ${taskId}: ${graded.stderr || graded.stdout}`);
  return JSON.parse(graded.stdout).pass === true;
}

function validateCandidateCellResult(task, result) {
  if (result?.task_id !== task.id || result.protected !== task.protected || typeof result.passed !== "boolean" || !isCount(result.latency_ms)) fail(`candidate cell ${task.id} grade contract is invalid`);
  const traditional = result.traditional_llm;
  if (traditional?.measured !== true || traditional.provenance !== "provider_receipt") fail(`candidate cell ${task.id} provider receipt is missing`);
  for (const key of ["input_tokens", "output_tokens", "cached_input_tokens", "cache_write_input_tokens", "total_tokens"]) if (!isCount(traditional[key])) fail(`candidate cell ${task.id} traditional usage is invalid`);
  if (traditional.total_tokens !== traditional.input_tokens + traditional.output_tokens || traditional.total_tokens === 0) fail(`candidate cell ${task.id} traditional total is invalid`);
  const jev = result.jev;
  for (const key of ["calls", "input_tokens", "output_tokens", "total_tokens", "latency_ms", "abstentions", "escalations", "retries"]) if (!isCount(jev?.[key])) fail(`candidate cell ${task.id} Jev usage is invalid`);
  if (jev.total_tokens !== jev.input_tokens + jev.output_tokens || jev.retries !== 0) fail(`candidate cell ${task.id} Jev total or retry is invalid`);
  const eligible = candidateEligibility({ category: task.category, protectedRoute: task.protected, privateInline: task.source.kind === "private_inline" });
  if (jev.calls !== (eligible ? 1 : 0)) fail(`candidate cell ${task.id} Jev call count violates eligibility`);
  if (task.protected && !result.passed) fail(`candidate cell ${task.id} protected route failed`);
  return result;
}

async function runCandidateCell({ root, task, repetition, config, artifactPath, output, env }) {
  const cellId = `candidate-r${repetition}-${task.id}`;
  const cellDirectory = resolve(output, cellId);
  const worktree = resolve(cellDirectory, "worktree");
  mkdirSync(cellDirectory);
  const harnessTask = task.source.kind === "existing_harness_task" ? prepareHarnessCell(root, task, worktree) : (mkdirSync(worktree), null);
  const baselinePrompt = task.source.kind === "private_inline" ? task.source.prompt : readFileSync(resolve(root, task.source.path, "prompt.md"), "utf8");
  const prepared = await prepareCandidatePrompt({ artifactPath, prompt: baselinePrompt, category: task.category, protectedRoute: task.protected, privateInline: task.source.kind === "private_inline" });
  writeFileSync(resolve(cellDirectory, "jev-preflight.json"), `${JSON.stringify(prepared.preflight, null, 2)}\n`);
  const argv = ["--provider", config.provider, "--model", config.model, "--thinking", config.effort, "--mode", "json", "--print", "--no-session", "--approve", "--", prepared.prompt];
  const started = Date.now();
  const completed = spawnSync("pi", argv, { cwd: worktree, env: candidateChildEnvironment(env), encoding: "utf8", timeout: config.timeout_seconds * 1000, maxBuffer: 32 * 1024 * 1024 });
  const latency = Date.now() - started;
  writeFileSync(resolve(cellDirectory, "events.jsonl"), completed.stdout ?? "");
  writeFileSync(resolve(cellDirectory, "stderr.txt"), completed.stderr ?? "");
  const events = parseJsonLines(completed.stdout ?? "");
  const coverage = piCoverage(events);
  if (coverage.retry.status !== "not_triggered") fail(`${cellId} observed a provider retry`);
  const normalized = normalizeEvents("pi", events, { exitCode: completed.status ?? 1, coverage });
  writeFileSync(resolve(cellDirectory, "normalized.json"), `${JSON.stringify(normalized, null, 2)}\n`);
  if (!normalized.measured) fail(`${cellId} has incomplete provider evidence: ${normalized.measurement_errors.join("; ")}`);
  const expectedModel = config.model.includes("/") ? config.model : `${config.provider}/${config.model}`;
  if (!normalized.models.includes(expectedModel)) fail(`${cellId} effective model does not match ${expectedModel}`);
  const transcript = resolve(cellDirectory, "transcript.txt");
  writeFileSync(transcript, normalized.final_text);
  const passed = harnessTask ? gradeHarnessCell(root, harnessTask, worktree, transcript, completed.status ?? 1) : gradeInline(task, normalized.final_text);
  const result = {
    task_id: task.id,
    protected: task.protected,
    passed,
    latency_ms: latency + prepared.jev.latency_ms,
    traditional_llm: {
      measured: true,
      provenance: "provider_receipt",
      input_tokens: normalized.usage.input_tokens,
      output_tokens: normalized.usage.output_tokens,
      cached_input_tokens: normalized.usage.cached_input_tokens,
      cache_write_input_tokens: normalized.usage.cache_write_input_tokens,
      total_tokens: normalized.usage.total_tokens,
      cost_usd: normalized.usage.cost_usd,
      cost_status: normalized.usage.cost_usd === null ? "unavailable" : "measured",
    },
    jev: prepared.jev.calls === 0
      ? { ...prepared.jev, cost_usd: 0, cost_status: "not_incurred" }
      : { ...prepared.jev, cost_usd: null, cost_status: "unavailable" },
  };
  writeFileSync(resolve(cellDirectory, "cell-result.json"), `${JSON.stringify(result, null, 2)}\n`);
  if (!prepared.comparable) {
    writeFileSync(resolve(output, "non-comparable.json"), `${JSON.stringify({ schema_version: 1, status: prepared.non_comparable_reason, cell_id: cellId, result }, null, 2)}\n`);
    fail(`${cellId} is non-comparable because Jev usage is unavailable`);
  }
  if (task.protected && !passed) fail(`${cellId} protected route failed`);
  return result;
}

export async function executeLiveCandidate({ manifest, manifestSha, population, populationFingerprint, state, config, baseline, artifactPath, outputPath, root = ".", env = process.env, cellExecutor = runCandidateCell, runtimeVersion = observePiVersion, runtimeRetryProfile = observePiRetryProfile }) {
  validateCampaignManifest(manifest);
  validatePrivatePopulation(manifest, manifestSha, population, root);
  validateCandidateConfig(config);
  if (fingerprintEvaluatorBundle(root, manifest.evaluator.bundle.paths) !== manifest.evaluator.bundle.sha256 || fingerprintEvaluatorFile(root, manifest.evaluator.path) !== manifest.evaluator.sha256) fail("frozen evaluator bundle drift");
  if (state.provider_checkpoint !== "authorized" || state.plan_status !== "READY" || state.adversary_verdict !== "GO" || state.candidate_runtime_enabled !== false) fail("candidate READY/authorization gate is closed");
  if (state.private_population_fingerprint !== populationFingerprint || state.baseline?.result_fingerprint !== fingerprint(JSON.stringify(baseline, null, 2) + "\n")) fail("candidate baseline or population binding drift");
  if (env.ETABLI_JEV_EFFICIENCY_LIVE !== "1") fail("ETABLI_JEV_EFFICIENCY_LIVE=1 is required");
  assertPiRuntimeVersion(state, runtimeVersion(candidateChildEnvironment(env)));
  assertPiRetryProfile(state, runtimeRetryProfile(candidateChildEnvironment(env)));
  const artifactFingerprint = validateCandidateArtifact({ manifest, manifestSha, artifactPath });
  if (state.candidate_runtime_artifact?.fingerprint !== artifactFingerprint) fail("campaign state candidate artifact drift");
  const output = privateOutputPath(root, outputPath);
  mkdirSync(output);
  const repetitions = [];
  let observedCost = 0;
  for (let repetition = 1; repetition <= config.repetitions; repetition += 1) {
    const tasks = [];
    for (const task of population.tasks) {
      const result = validateCandidateCellResult(task, await cellExecutor({ root: resolve(root), task, repetition, config, artifactPath, output, env }));
      if (config.billing_mode === "metered" && result.traditional_llm.cost_status !== "measured") fail("metered candidate cost telemetry is unavailable");
      if (config.billing_mode === "metered") observedCost += result.traditional_llm.cost_usd;
      if (config.billing_mode === "metered" && observedCost > config.max_cost_usd) fail("candidate exceeded max_cost_usd");
      tasks.push(result);
    }
    repetitions.push({ repetition, tasks });
  }
  const result = {
    schema_version: 1,
    arm: "candidate",
    campaign_id: manifest.manifest_id,
    manifest_sha256: manifestSha,
    evaluator_bundle_sha256: manifest.evaluator.bundle.sha256,
    artifact_fingerprint: artifactFingerprint,
    population_fingerprint: populationFingerprint,
    runtime: { ...baseline.runtime, candidate_enabled: true },
    repetitions,
  };
  writeFileSync(resolve(output, "candidate.json"), `${JSON.stringify(result, null, 2)}\n`);
  return result;
}

export function consumeValidatedEscalation({ state, receipt, receiptFingerprint = fingerprint(JSON.stringify(receipt)) }) {
  if (state?.diagnosis?.producer !== "jev" || state.diagnosis.valid !== true || state.diagnosis.abstained !== true || !SHA256.test(state.diagnosis.receipt_fingerprint ?? "")) fail("typed Jev abstention is required");
  if (!receipt || receipt.schema_version !== 1 || receipt.producer !== "traditional_llm" || receipt.status !== "completed") fail("completed escalation receipt is required");
  const bindings = {
    observation_fingerprint: state.observation_fingerprint,
    diagnosis_receipt_fingerprint: state.diagnosis.receipt_fingerprint,
    proposal_fingerprint: state.proposal_fingerprint,
  };
  for (const [key, expected] of Object.entries(bindings)) {
    if (!SHA256.test(expected ?? "") || receipt[key] !== expected) fail(`escalation ${key} binding mismatch`);
  }
  if (!SHA256.test(receipt.model_receipt_fingerprint ?? "") || receipt.retry_events !== 0 || !SHA256.test(receiptFingerprint)) fail("escalation provenance is invalid");
  const coordinatorFingerprint = fingerprint(JSON.stringify({
    schema_version: 1,
    receipt_fingerprint: receiptFingerprint,
    model_receipt_fingerprint: receipt.model_receipt_fingerprint,
    bindings,
  }));
  return Object.freeze({
    decision: "deduplicate",
    diagnosis: Object.freeze({ ...state.diagnosis }),
    escalation: Object.freeze({
      producer: "traditional_llm",
      valid: true,
      status: "consumed",
      receipt_fingerprint: receiptFingerprint,
      model_receipt_fingerprint: receipt.model_receipt_fingerprint,
      coordinator_fingerprint: coordinatorFingerprint,
      bindings: Object.freeze({ ...bindings }),
    }),
  });
}

export function decideEscalatedCampaign(manifest, state, receipt, receiptFingerprint = fingerprint(JSON.stringify(receipt))) {
  if (state?.diagnosis?.abstained !== true) return decideCampaign(manifest, state);
  if (state?.escalation?.status !== "consumed") return decideCampaign(manifest, state);
  if (!receipt || typeof receipt !== "object") fail("consumed escalation receipt is required");
  const validated = consumeValidatedEscalation({ state, receipt, receiptFingerprint });
  for (const key of ["producer", "valid", "status", "receipt_fingerprint", "model_receipt_fingerprint", "coordinator_fingerprint"]) {
    if (state.escalation[key] !== validated.escalation[key]) fail(`consumed escalation ${key} mismatch`);
  }
  for (const key of ["observation_fingerprint", "diagnosis_receipt_fingerprint", "proposal_fingerprint"]) {
    if (state.escalation.bindings?.[key] !== validated.escalation.bindings[key]) fail(`consumed escalation ${key} binding mismatch`);
  }
  const continuation = decideCampaign(manifest, {
    ...state,
    diagnosis: { ...state.diagnosis, abstained: false },
  });
  return Object.freeze({
    ...continuation,
    escalation_status: "consumed",
    diagnosis_abstained: true,
  });
}
