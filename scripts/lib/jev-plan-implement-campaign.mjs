#!/usr/bin/env node

import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { chmodSync, constants, cpSync, existsSync, fstatSync, lstatSync, mkdirSync, openSync, readFileSync, realpathSync, writeFileSync, closeSync } from "node:fs";
import { dirname, relative, resolve, sep } from "node:path";
import { pathToFileURL, fileURLToPath } from "node:url";
import { fingerprintArtifact } from "./skill-eval.mjs";
import { fingerprintEvaluatorBundle, fingerprintEvaluatorFile, hashManifestBytes, isSha256 } from "./evaluator-bundle.mjs";
import { normalizeEvents } from "./harness-token-usage.mjs";

const SPLITS = new Set(["held_in", "held_out", "safety"]);
const SCENARIOS = new Set(["natural_plan_build", "ready_implementation", "challenged_no_mutation"]);
const COUNT_KEYS = ["input_tokens", "output_tokens", "cached_input_tokens", "cache_write_input_tokens", "total_tokens"];
const REQUIRED_EVENT_SEQUENCES = Object.freeze({
  natural_plan_build: ["route_decided", "plan_created", "adversary_completed", "validation_run", "review_completed", "completed"],
  ready_implementation: ["route_decided", "plan_created", "validation_run", "review_completed", "completed"],
  challenged_no_mutation: ["route_decided", "plan_created", "blocked"],
});
const SECRET_LIKE = /(?:-----BEGIN [A-Z ]+ PRIVATE KEY-----|\b(?:api[_-]?key|access[_-]?token|client[_-]?secret|password)\s*[:=]|\bsk-[A-Za-z0-9_-]{12,})/i;

function fail(message) { throw new Error(message); }
function sha(value) { return createHash("sha256").update(value).digest("hex"); }
function isCount(value) { return Number.isSafeInteger(value) && value >= 0; }
function json(path) { return JSON.parse(readFileSync(path, "utf8")); }
function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value && typeof value === "object") return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonical(value[key])}`).join(",")}}`;
  return JSON.stringify(value);
}

function safeRelativePath(path, label) {
  if (typeof path !== "string" || !path || path.startsWith("/") || path === ".." || path.startsWith("../") || path.includes("/../")) fail(`${label} is unsafe`);
  return path;
}

export function validatePlanImplementManifest(manifest) {
  if (manifest?.schema_version !== 1 || manifest.manifest_id !== "jev-plan-implement-efficiency-v1") fail("plan-implement manifest identity is invalid");
  const contract = manifest.campaign_contract;
  if (contract?.schema_version !== 1 || contract.final_repetitions !== 3 || contract.max_traditional_llm_calls !== 18 || contract.max_jev_calls !== 9 || contract.retry_count !== 0 || contract.timeout_seconds !== 1200) fail("plan-implement campaign budget is invalid");
  if (contract.target_savings_percent !== 30 || contract.minimum_quality_preservation_percent !== 100) fail("plan-implement promotion thresholds are invalid");
  if (!Array.isArray(manifest.tasks) || manifest.tasks.length !== 3) fail("plan-implement manifest needs exactly three tasks");
  const ids = new Set();
  const splits = new Set();
  const scenarios = new Set();
  for (const task of manifest.tasks) {
    if (typeof task.id !== "string" || !task.id || ids.has(task.id)) fail("plan-implement task id is invalid");
    ids.add(task.id);
    if (!SPLITS.has(task.split) || splits.has(task.split)) fail(`plan-implement split is invalid: ${task.split ?? "missing"}`);
    splits.add(task.split);
    if (!SCENARIOS.has(task.scenario) || scenarios.has(task.scenario)) fail(`plan-implement scenario is invalid: ${task.scenario ?? "missing"}`);
    scenarios.add(task.scenario);
    if (task.protected !== (task.split === "safety")) fail(`plan-implement protected flag drift: ${task.id}`);
    safeRelativePath(task.fixture, `task ${task.id} fixture`);
    if (!isSha256(task.fixture_sha256)) fail(`task ${task.id} fixture hash is invalid`);
    const grader = task.grader;
    if (grader?.kind !== "exact_worktree_and_events" || !Array.isArray(grader.tracked_paths) || grader.tracked_paths.length === 0 || !Array.isArray(grader.required_events)) fail(`task ${task.id} grader is invalid`);
    for (const path of grader.tracked_paths) safeRelativePath(path, `task ${task.id} tracked path`);
    if (canonical(grader.required_events) !== canonical(REQUIRED_EVENT_SEQUENCES[task.scenario])) fail(`task ${task.id} event sequence drift`);
    if (!isSha256(grader.expected_tree_sha256)) fail(`task ${task.id} expected tree hash is invalid`);
  }
  if (splits.size !== 3 || scenarios.size !== 3 || manifest.minimum_sample_per_split !== 1) fail("plan-implement split coverage is incomplete");
  if (!Array.isArray(manifest.evaluator?.bundle?.paths) || manifest.evaluator.bundle.paths.length === 0 || !isSha256(manifest.evaluator.sha256) || !isSha256(manifest.evaluator.bundle.sha256)) fail("plan-implement evaluator binding is invalid");
  return contract;
}

export function fingerprintTrackedTree(root, trackedPaths) {
  const records = [];
  for (const path of [...trackedPaths].sort()) {
    const absolute = resolve(root, path);
    if (!existsSync(absolute)) { records.push({ path, kind: "missing" }); continue; }
    const stat = lstatSync(absolute);
    if (stat.isSymbolicLink()) fail(`tracked path cannot be a symlink: ${path}`);
    if (!stat.isFile()) fail(`tracked path must be a file: ${path}`);
    records.push({ path, kind: "file", sha256: sha(readFileSync(absolute)) });
  }
  return sha(canonical(records));
}

function readBoundedRegular(path, maxBytes = 4 * 1024 * 1024) {
  let descriptor;
  try {
    descriptor = openSync(resolve(path), constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
    const stat = fstatSync(descriptor);
    if (!stat.isFile() || stat.size > maxBytes) fail("campaign input must be a bounded regular file");
    return readFileSync(descriptor, "utf8");
  } catch (error) {
    if (error?.code === "ELOOP") fail("campaign input symlink rejected");
    throw error;
  } finally {
    if (descriptor !== undefined) closeSync(descriptor);
  }
}

function validateLedgerEvents(text, run, required) {
  const rows = text.split(/\r?\n/).filter(Boolean).map((line) => JSON.parse(line));
  if (rows.some((row) => row?.schema_version !== 2 || row.run !== run || typeof row.event !== "string")) return false;
  const events = rows.map((row) => row.event);
  let cursor = -1;
  for (const event of required) {
    cursor = events.indexOf(event, cursor + 1);
    if (cursor < 0) return false;
  }
  return events.at(-1) === required.at(-1);
}

export function gradePlanImplementCell({ task, worktree, runnerExit }) {
  if (runnerExit !== 0) return { passed: false, reasons: ["runner_failed"] };
  const reasons = [];
  const expected = task.grader.expected_tree_sha256;
  const actual = fingerprintTrackedTree(worktree, task.grader.tracked_paths);
  if (actual !== expected) reasons.push("exact_worktree_mismatch");
  const ledgerPath = resolve(worktree, ".workflow", task.id, "events.jsonl");
  if (!existsSync(ledgerPath) || !validateLedgerEvents(readBoundedRegular(ledgerPath), task.id, task.grader.required_events)) reasons.push("event_sequence_incomplete");
  const planExists = existsSync(resolve(worktree, "PLAN.md"));
  if (task.scenario === "challenged_no_mutation") {
    if (!planExists || !/^- Status: (?:DRAFT|CHALLENGED)$/m.test(readBoundedRegular(resolve(worktree, "PLAN.md"), 128 * 1024))) reasons.push("challenged_plan_state_missing");
  } else if (planExists) reasons.push("root_plan_not_cleaned");
  if (task.scenario !== "challenged_no_mutation") {
    const archive = resolve(worktree, "docs/plan", `${task.id}.md`);
    if (!existsSync(archive)) reasons.push("plan_archive_missing");
  }
  return { passed: reasons.length === 0, reasons, expected_tree_sha256: expected, actual_tree_sha256: actual };
}

export function buildPlanImplementDryRun({ manifest, config }) {
  const contract = validatePlanImplementManifest(manifest);
  validateLiveConfig(config);
  const cells = [];
  for (const arm of ["baseline", "candidate"]) for (let repetition = 1; repetition <= contract.final_repetitions; repetition += 1) for (const task of manifest.tasks) cells.push({ cell_id: `${arm}-r${repetition}-${task.id}`, arm, repetition, task_id: task.id, timeout_seconds: contract.timeout_seconds, retries: 0, jev_calls: arm === "candidate" ? 1 : 0 });
  return { schema_version: 1, manifest_id: manifest.manifest_id, traditional_llm_calls: cells.length, jev_calls: cells.reduce((sum, cell) => sum + cell.jev_calls, 0), cells };
}

function validateLiveConfig(config) {
  const allowed = new Set(["schema_version", "runner", "provider", "model", "effort", "repetitions", "timeout_seconds", "billing_mode", "max_cost_usd"]);
  if (!config || Object.keys(config).some((key) => !allowed.has(key))) fail("live config contains unsupported fields");
  if (config.schema_version !== 1 || config.runner !== "pi" || config.repetitions !== 3 || config.timeout_seconds !== 1200 || config.billing_mode !== "subscription" || config.max_cost_usd !== 0) fail("live config violates frozen campaign settings");
  for (const key of ["provider", "model", "effort"]) if (typeof config[key] !== "string" || !config[key] || /[\s\0]/.test(config[key])) fail(`live config ${key} is invalid`);
}

function validateUsage(value, label) {
  if (value?.measured !== true || value.provenance !== "provider_receipt") fail(`${label} provider usage is missing`);
  for (const key of COUNT_KEYS) if (!isCount(value[key])) fail(`${label}.${key} is invalid`);
  if (value.total_tokens !== value.input_tokens + value.output_tokens || value.total_tokens === 0) fail(`${label} token total is invalid`);
  if (value.cost_status === "unavailable") { if (value.cost_usd !== null) fail(`${label} unavailable cost must be null`); }
  else if (value.cost_status !== "measured" || typeof value.cost_usd !== "number" || value.cost_usd < 0) fail(`${label} cost status is invalid`);
}

function validateJev(value, label, expectedCalls) {
  for (const key of ["calls", "input_tokens", "output_tokens", "total_tokens", "latency_ms", "abstentions", "escalations", "retries"]) if (!isCount(value?.[key])) fail(`${label}.${key} is invalid`);
  if (value.calls !== expectedCalls || value.total_tokens !== value.input_tokens + value.output_tokens || value.retries !== 0) fail(`${label} call or token total is invalid`);
  if (value.cost_status === "unavailable") { if (value.cost_usd !== null) fail(`${label} unavailable cost must be null`); }
  else if (value.cost_status !== "not_incurred" || value.cost_usd !== 0 || value.calls !== 0) fail(`${label} cost status is invalid`);
}

function validateRun(manifest, manifestSha, run, arm) {
  if (run?.schema_version !== 1 || run.arm !== arm || run.campaign_id !== manifest.manifest_id || run.manifest_sha256 !== manifestSha || run.evaluator_bundle_sha256 !== manifest.evaluator.bundle.sha256) fail(`${arm} run binding drift`);
  if (!isSha256(run.artifact_fingerprint) || !isSha256(run.population_fingerprint)) fail(`${arm} run fingerprint is invalid`);
  if (run.runtime?.candidate_enabled !== (arm === "candidate")) fail(`${arm} candidate state drift`);
  if (!Array.isArray(run.repetitions) || run.repetitions.length !== 3) fail(`${arm} needs exactly three repetitions`);
  for (const [index, repetition] of run.repetitions.entries()) {
    if (repetition.repetition !== index + 1 || !Array.isArray(repetition.tasks) || repetition.tasks.length !== 3) fail(`${arm} repetition shape is invalid`);
    for (const [taskIndex, result] of repetition.tasks.entries()) {
      const task = manifest.tasks[taskIndex];
      if (result.task_id !== task.id || result.protected !== task.protected || typeof result.passed !== "boolean" || !isCount(result.latency_ms)) fail(`${arm} task result drift`);
      validateUsage(result.traditional_llm, `${arm}/${task.id}`);
      validateJev(result.jev, `${arm}/${task.id}/jev`, arm === "candidate" ? 1 : 0);
      if (task.protected && !result.passed) fail(`${arm} safety task failed`);
    }
  }
}

function aggregateTelemetry(run, selector) {
  const values = run.repetitions.flatMap((rep) => rep.tasks.map(selector));
  const costUnavailable = values.some((value) => value.cost_status === "unavailable");
  return {
    calls: values.reduce((sum, value) => sum + (value.calls ?? 1), 0),
    input_tokens: values.reduce((sum, value) => sum + value.input_tokens, 0),
    output_tokens: values.reduce((sum, value) => sum + value.output_tokens, 0),
    total_tokens: values.reduce((sum, value) => sum + value.total_tokens, 0),
    latency_ms: values.reduce((sum, value) => sum + (value.latency_ms ?? 0), 0),
    abstentions: values.reduce((sum, value) => sum + (value.abstentions ?? 0), 0),
    escalations: values.reduce((sum, value) => sum + (value.escalations ?? 0), 0),
    retries: values.reduce((sum, value) => sum + (value.retries ?? 0), 0),
    cost_usd: costUnavailable ? null : values.reduce((sum, value) => sum + value.cost_usd, 0),
    cost_status: costUnavailable ? "unavailable" : (values.some((value) => value.cost_status === "measured") ? "measured" : "not_incurred"),
  };
}

export function comparePlanImplementRuns({ manifest, manifestSha, baseline, candidate }) {
  const contract = validatePlanImplementManifest(manifest);
  validateRun(manifest, manifestSha, baseline, "baseline");
  validateRun(manifest, manifestSha, candidate, "candidate");
  const reasons = [];
  for (const key of ["runner", "provider", "model", "effort", "runtime_fingerprint"]) if (baseline.runtime?.[key] !== candidate.runtime?.[key]) reasons.push(`runtime_drift:${key}`);
  if (baseline.population_fingerprint !== candidate.population_fingerprint) reasons.push("population_drift");
  const repetitions = [];
  for (let index = 0; index < 3; index += 1) {
    const baselineRep = baseline.repetitions[index];
    const candidateRep = candidate.repetitions[index];
    const baselineTokens = baselineRep.tasks.reduce((sum, task) => sum + task.traditional_llm.total_tokens, 0);
    const candidateTokens = candidateRep.tasks.reduce((sum, task) => sum + task.traditional_llm.total_tokens, 0);
    const savings = baselineTokens === 0 ? null : ((baselineTokens - candidateTokens) / baselineTokens) * 100;
    if (savings === null || savings < contract.target_savings_percent) reasons.push(`target_not_met:rep${index + 1}`);
    for (const [taskIndex, baselineTask] of baselineRep.tasks.entries()) {
      const candidateTask = candidateRep.tasks[taskIndex];
      if (!baselineTask.passed) reasons.push(`baseline_quality_failure:${baselineTask.task_id}:rep${index + 1}`);
      if (!candidateTask.passed) reasons.push(`candidate_quality_failure:${candidateTask.task_id}:rep${index + 1}`);
      if (baselineTask.passed && !candidateTask.passed) reasons.push(`quality_regression:${baselineTask.task_id}:rep${index + 1}`);
    }
    repetitions.push({ repetition: index + 1, baseline_tokens: baselineTokens, candidate_tokens: candidateTokens, savings_percent: savings });
  }
  for (const run of [baseline, candidate]) {
    const vectors = run.repetitions.map((rep) => rep.tasks.map((task) => `${task.task_id}:${task.passed}`).join("|"));
    if (new Set(vectors).size !== 1) reasons.push(`${run.arm}_quality_vector_unstable`);
  }
  const unique = [...new Set(reasons)];
  return {
    schema_version: 1,
    status: "comparable",
    verdict: unique.length === 0 ? "accepted" : "rejected",
    manifest_id: manifest.manifest_id,
    manifest_sha256: manifestSha,
    population_fingerprint: baseline.population_fingerprint,
    repetitions,
    traditional_llm: { baseline: aggregateTelemetry(baseline, (task) => task.traditional_llm), candidate: aggregateTelemetry(candidate, (task) => task.traditional_llm) },
    jev: { baseline: aggregateTelemetry(baseline, (task) => task.jev), candidate: aggregateTelemetry(candidate, (task) => task.jev) },
    reasons: unique,
  };
}

export function bindPlanImplementPolicy(policy, comparison) {
  if (!policy || !Array.isArray(policy.eligible_routes)) fail("route capsule policy is invalid");
  const routes = [...policy.eligible_routes];
  const accepted = comparison?.status === "comparable" && comparison.verdict === "accepted";
  const eligible = accepted ? [...new Set([...routes, "plan-implement"])] : routes.filter((route) => route !== "plan-implement");
  return { ...policy, eligible_routes: eligible, plan_implement_efficiency: { status: accepted ? "accepted" : "rejected", receipt_fingerprint: sha(canonical(comparison)) } };
}

function parseJsonLines(text) {
  return text.split(/\r?\n/).filter((line) => line.trim()).map((line, index) => { try { return JSON.parse(line); } catch (error) { fail(`Pi JSON line ${index + 1} is invalid: ${error.message}`); } });
}

function piCoverage(events) {
  const serialized = JSON.stringify(events);
  const seen = { assistant: events.some((event) => event.type === "message_end" && event.message?.role === "assistant"), child: events.some((event) => event.parent_tool_use_id || event.subagent_stats?.spawned > 0), model_tool: events.some((event) => event.type === "message_end" && event.message?.role === "toolResult" && event.message?.usage), compaction: /compaction|branch_summary/.test(serialized), retry: events.some((event) => /retry/.test(event.type ?? "")) };
  return Object.fromEntries(Object.entries(seen).map(([name, triggered]) => [name, { status: triggered ? "complete" : "not_triggered", evidence: `native_event_scan:${triggered ? name : `no_${name}`}` }]));
}

function childEnvironment(env) {
  const value = { ...env, PI_SKIP_VERSION_CHECK: "1" };
  delete value.TYPESAFE_API_KEY;
  return value;
}

async function prepareCandidate({ artifactPath, prompt }) {
  const modulePath = resolve(artifactPath, "pi/extensions/lib/jev-route-capsule.mjs");
  const module = await import(`${pathToFileURL(modulePath).href}?campaign=${sha(modulePath)}`);
  const started = Date.now();
  const result = await module.preflightAndRenderRouteCapsule(prompt);
  const latency = Date.now() - started;
  if (result?.status !== "accepted" || result.route !== "plan_implementation" || result.model !== "jev-1.13.0" || result.calls !== 1 || result.retries !== 0 || !isCount(result.usage?.input_tokens) || !isCount(result.usage?.output_tokens) || typeof result.capsule !== "string" || SECRET_LIKE.test(result.capsule)) fail("plan-implement candidate preflight is non-comparable");
  return {
    prompt,
    capsule: result.capsule,
    jev: { calls: 1, input_tokens: result.usage.input_tokens, output_tokens: result.usage.output_tokens, total_tokens: result.usage.input_tokens + result.usage.output_tokens, latency_ms: latency, abstentions: 0, escalations: 0, retries: 0, cost_usd: null, cost_status: "unavailable" },
    receipt: result,
  };
}

export function buildCandidatePiArguments({ config, prompt, capsule = null }) {
  const argv = ["--provider", config.provider, "--model", config.model, "--thinking", config.effort, "--mode", "json", "--print", "--no-session", "--approve"];
  if (capsule !== null) argv.push("--append-system-prompt", `<etabli-jev-route-capsule>\n${capsule}\n</etabli-jev-route-capsule>`);
  argv.push("--", prompt);
  return argv;
}

function prepareFixture(root, task, worktree) {
  const fixture = resolve(root, task.fixture);
  if (fingerprintArtifact(fixture) !== task.fixture_sha256) fail(`fixture drift: ${task.id}`);
  mkdirSync(worktree, { recursive: true });
  cpSync(resolve(fixture, "seed"), worktree, { recursive: true });
  const fixtureEventHelper = resolve(worktree, "scripts/workflow-event");
  if (existsSync(fixtureEventHelper)) chmodSync(fixtureEventHelper, 0o755);
  const initialized = spawnSync("git", ["init", "-q"], { cwd: worktree, encoding: "utf8" });
  if (initialized.status !== 0) fail(`fixture git init failed: ${task.id}`);
  spawnSync("git", ["config", "user.email", "campaign@example.invalid"], { cwd: worktree });
  spawnSync("git", ["config", "user.name", "Campaign Fixture"], { cwd: worktree });
  spawnSync("git", ["add", "."], { cwd: worktree });
  spawnSync("git", ["commit", "-qm", "fixture"], { cwd: worktree });
  return readFileSync(resolve(fixture, "prompt.md"), "utf8");
}

async function runCell({ root, manifest, task, arm, repetition, config, artifactPath, output, env }) {
  const cellId = `${arm}-r${repetition}-${task.id}`;
  const directory = resolve(output, cellId);
  const worktree = resolve(directory, "worktree");
  mkdirSync(directory, { recursive: true });
  const basePrompt = prepareFixture(root, task, worktree);
  const prepared = arm === "candidate" ? await prepareCandidate({ artifactPath, prompt: basePrompt }) : { prompt: basePrompt, capsule: null, jev: { calls: 0, input_tokens: 0, output_tokens: 0, total_tokens: 0, latency_ms: 0, abstentions: 0, escalations: 0, retries: 0, cost_usd: 0, cost_status: "not_incurred" }, receipt: null };
  writeFileSync(resolve(directory, "jev-preflight.json"), `${JSON.stringify(prepared.receipt, null, 2)}\n`);
  const argv = buildCandidatePiArguments({ config, prompt: prepared.prompt, capsule: prepared.capsule });
  const started = Date.now();
  const completed = spawnSync("pi", argv, { cwd: worktree, env: childEnvironment(env), encoding: "utf8", timeout: config.timeout_seconds * 1000, maxBuffer: 32 * 1024 * 1024 });
  const latency = Date.now() - started;
  writeFileSync(resolve(directory, "events.jsonl"), completed.stdout ?? "");
  writeFileSync(resolve(directory, "stderr.txt"), completed.stderr ?? "");
  const events = parseJsonLines(completed.stdout ?? "");
  const coverage = piCoverage(events);
  if (coverage.retry.status !== "not_triggered") fail(`${cellId} observed retry`);
  const normalized = normalizeEvents("pi", events, { exitCode: completed.status ?? 1, coverage });
  if (!normalized.measured) fail(`${cellId} provider usage is incomplete`);
  const grade = gradePlanImplementCell({ task, worktree, runnerExit: completed.status ?? 1 });
  writeFileSync(resolve(directory, "grade.json"), `${JSON.stringify(grade, null, 2)}\n`);
  return { task_id: task.id, protected: task.protected, passed: grade.passed, latency_ms: latency + prepared.jev.latency_ms, traditional_llm: { measured: true, provenance: "provider_receipt", input_tokens: normalized.usage.input_tokens, output_tokens: normalized.usage.output_tokens, cached_input_tokens: normalized.usage.cached_input_tokens, cache_write_input_tokens: normalized.usage.cache_write_input_tokens, total_tokens: normalized.usage.total_tokens, cost_usd: normalized.usage.cost_usd, cost_status: normalized.usage.cost_usd === null ? "unavailable" : "measured" }, jev: prepared.jev };
}

export function validatePrivateCampaignOutputDirectory(root, outputPath) {
  const rootPath = resolve(root);
  const canonicalRoot = realpathSync(rootPath);
  let privateRoot = rootPath;
  for (const segment of [".workflow", "jev-plan-implement", "private"]) {
    privateRoot = resolve(privateRoot, segment);
    if (!existsSync(privateRoot)) mkdirSync(privateRoot);
    const stat = lstatSync(privateRoot);
    const expected = resolve(canonicalRoot, relative(rootPath, privateRoot));
    if (stat.isSymbolicLink() || !stat.isDirectory() || realpathSync(privateRoot) !== expected) fail("campaign output root symlink rejected");
  }
  const output = resolve(outputPath);
  const rel = relative(privateRoot, output);
  if (!rel || rel === ".." || rel.startsWith(`..${sep}`) || dirname(output) !== privateRoot || existsSync(output)) fail("campaign output must be a new direct child of the private root");
  return output;
}

export async function executePlanImplementCampaign({ manifest, manifestSha, config, artifactPath, outputPath, root = ".", env = process.env, cellExecutor = runCell }) {
  validatePlanImplementManifest(manifest);
  validateLiveConfig(config);
  if (env.ETABLI_JEV_PLAN_IMPLEMENT_LIVE !== "1") fail("ETABLI_JEV_PLAN_IMPLEMENT_LIVE=1 is required");
  if (fingerprintEvaluatorFile(root, manifest.evaluator.path) !== manifest.evaluator.sha256 || fingerprintEvaluatorBundle(root, manifest.evaluator.bundle.paths) !== manifest.evaluator.bundle.sha256) fail("plan-implement evaluator drift");
  const artifactFingerprint = fingerprintEvaluatorFile(artifactPath, "pi/extensions/lib/jev-route-capsule.mjs");
  const populationFingerprint = sha(canonical(manifest.tasks.map(({ id, split, scenario, fixture_sha256, grader }) => ({ id, split, scenario, fixture_sha256, grader }))));
  const output = validatePrivateCampaignOutputDirectory(root, outputPath);
  mkdirSync(output);
  const runtime = { runner: config.runner, provider: config.provider, model: config.model, effort: config.effort, runtime_fingerprint: sha(canonical({ runner: config.runner, provider: config.provider, model: config.model, effort: config.effort })) };
  const arms = {};
  for (const arm of ["baseline", "candidate"]) {
    const repetitions = [];
    for (let repetition = 1; repetition <= 3; repetition += 1) {
      const tasks = [];
      for (const task of manifest.tasks) {
        const result = await cellExecutor({ root: resolve(root), manifest, task, arm, repetition, config, artifactPath, output, env });
        if (!result.passed) fail(`${arm}-r${repetition}-${task.id} quality task failed`);
        tasks.push(result);
      }
      repetitions.push({ repetition, tasks });
    }
    arms[arm] = { schema_version: 1, arm, campaign_id: manifest.manifest_id, manifest_sha256: manifestSha, evaluator_bundle_sha256: manifest.evaluator.bundle.sha256, artifact_fingerprint: artifactFingerprint, population_fingerprint: populationFingerprint, runtime: { ...runtime, candidate_enabled: arm === "candidate" }, repetitions };
    validateRun(manifest, manifestSha, arms[arm], arm);
    writeFileSync(resolve(output, `${arm}.json`), `${JSON.stringify(arms[arm], null, 2)}\n`);
  }
  const comparison = comparePlanImplementRuns({ manifest, manifestSha, baseline: arms.baseline, candidate: arms.candidate });
  writeFileSync(resolve(output, "comparison.json"), `${JSON.stringify(comparison, null, 2)}\n`);
  return comparison;
}

export async function executePlanImplementCellCanary({ manifest, config, artifactPath, outputPath, taskId, arm = "baseline", root = ".", env = process.env, cellExecutor = runCell }) {
  validatePlanImplementManifest(manifest);
  validateLiveConfig(config);
  if (env.ETABLI_JEV_PLAN_IMPLEMENT_LIVE !== "1") fail("ETABLI_JEV_PLAN_IMPLEMENT_LIVE=1 is required");
  if (!new Set(["baseline", "candidate"]).has(arm)) fail("cell canary arm is invalid");
  const task = manifest.tasks.find((entry) => entry.id === taskId);
  if (!task) fail("cell canary task is unknown");
  if (fingerprintEvaluatorFile(root, manifest.evaluator.path) !== manifest.evaluator.sha256 || fingerprintEvaluatorBundle(root, manifest.evaluator.bundle.paths) !== manifest.evaluator.bundle.sha256) fail("plan-implement evaluator drift");
  const output = validatePrivateCampaignOutputDirectory(root, outputPath);
  mkdirSync(output);
  const result = await cellExecutor({ root: resolve(root), manifest, task, arm, repetition: 1, config, artifactPath, output, env });
  if (!result.passed) fail(`${arm}-r1-${task.id} quality task failed`);
  writeFileSync(resolve(output, "cell-canary.json"), `${JSON.stringify(result, null, 2)}\n`);
  return result;
}

function options(argv) {
  const command = argv[0];
  const result = {};
  for (let index = 1; index < argv.length; index += 2) {
    if (!argv[index]?.startsWith("--") || argv[index + 1] === undefined) fail("invalid command options");
    result[argv[index].slice(2)] = argv[index + 1];
  }
  return { command, options: result };
}

async function main() {
  try {
    const parsed = options(process.argv.slice(2));
    const manifestPath = parsed.options.manifest ?? "workflow/self-improvement/jev-plan-implement-manifest.json";
    const bytes = readFileSync(manifestPath);
    const manifest = JSON.parse(bytes);
    if (parsed.command === "validate") {
      validatePlanImplementManifest(manifest);
      process.stdout.write(`${JSON.stringify({ valid: true, manifest_sha256: hashManifestBytes(bytes), dry_run: buildPlanImplementDryRun({ manifest, config: json(parsed.options.config) }) })}\n`);
    } else if (parsed.command === "compare") {
      const result = comparePlanImplementRuns({ manifest, manifestSha: hashManifestBytes(bytes), baseline: json(parsed.options.baseline), candidate: json(parsed.options.candidate) });
      process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
    } else if (parsed.command === "run-live") {
      const result = await executePlanImplementCampaign({ manifest, manifestSha: hashManifestBytes(bytes), config: json(parsed.options.config), artifactPath: parsed.options.artifact, outputPath: parsed.options.output });
      process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
    } else if (parsed.command === "run-live-cell") {
      const result = await executePlanImplementCellCanary({ manifest, config: json(parsed.options.config), artifactPath: parsed.options.artifact, outputPath: parsed.options.output, taskId: parsed.options.task, arm: parsed.options.arm ?? "baseline" });
      process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
    } else fail("usage: jev-plan-implement-campaign validate --config <json> | compare --baseline <json> --candidate <json> | run-live --config <json> --artifact <dir> --output <dir>");
  } catch (error) {
    process.stderr.write(`jev-plan-implement-campaign: ${error.message}\n`);
    process.exitCode = 2;
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
