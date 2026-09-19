import { closeSync, constants, fstatSync, lstatSync, mkdirSync, openSync, readFileSync, realpathSync, writeSync } from "node:fs";
import { dirname, isAbsolute, join, normalize, relative, resolve, sep } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { evaluateTypeSafe, TypeSafeServiceError } from "./typesafe-system-one.mjs";
import { fingerprint, minimizeRouteState, sanitizedReceipt, stableJson } from "./semantic-judgment.mjs";
import { composeSemanticDecision, evaluateSemanticSelection, isProtectedChoice, routeQuestion, routeQuestionFingerprint, semanticChoiceForDecision } from "./semantic-route.mjs";

const ROOT = resolve(dirname(realpathSync(fileURLToPath(import.meta.url))), "../../..");
const { classifyWorkflowRoute } = await import(pathToFileURL(resolve(ROOT, "workflow/runtime/workflow-router-core.mjs")).href);

function relativePath(value, label) {
  const path = normalize(value || "");
  if (!path || isAbsolute(path) || path === ".." || path.startsWith(`..${sep}`)) throw new Error(`invalid ${label} path`);
  return path;
}

function readJson(path, label) {
  try { return JSON.parse(readFileSync(path, "utf8")); }
  catch { throw new Error(`invalid ${label}`); }
}

function sameValues(left, right) {
  return stableJson(left) === stableJson(right);
}

function percentile(values, fraction) {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.ceil(sorted.length * fraction) - 1)];
}

export function summarizeCalibrationResults(results) {
  const total = results.length;
  const caseIds = [...new Set(results.map((item) => item.id))];
  const accepted = results.filter((item) => item.accepted_by_threshold);
  const protectedCases = results.filter((item) => item.protected);
  const overrideCases = results.filter((item) => item.expected !== item.deterministic_choice);
  const acceptedOverrides = overrideCases.filter((item) => item.accepted_by_threshold);
  const answered = results.filter((item) => !item.error_code);
  const brierScore = answered.length ? answered.reduce((sum, item) => sum + Object.entries(item.probabilities).reduce((score, [choice, probability]) => score + (probability - (choice === item.expected ? 1 : 0)) ** 2, 0), 0) / answered.length : null;
  const logLoss = answered.length ? answered.reduce((sum, item) => sum - Math.log(Math.max(item.probabilities[item.expected] || 0, 1e-12)), 0) / answered.length : null;
  const calibrationBins = [[0, 0.5], [0.5, 0.75], [0.75, 1.000001]].map(([min, max]) => {
    const values = answered.filter((item) => item.probabilities[item.prediction] >= min && item.probabilities[item.prediction] < max);
    return {
      range: [min, Math.min(max, 1)],
      count: values.length,
      mean_probability: values.length ? values.reduce((sum, item) => sum + item.probabilities[item.prediction], 0) / values.length : null,
      observed_accuracy: values.length ? values.filter((item) => item.correct).length / values.length : null,
    };
  });
  const expectedCalibrationError = answered.length ? calibrationBins.reduce((sum, bin) => sum + (bin.count / answered.length) * (bin.count ? Math.abs(bin.mean_probability - bin.observed_accuracy) : 0), 0) : null;
  const confusion = {};
  for (const item of results) {
    const expected = confusion[item.expected] ??= {};
    const prediction = item.prediction ?? "error";
    expected[prediction] = (expected[prediction] || 0) + 1;
  }
  const stableCases = caseIds.filter((id) => new Set(results.filter((item) => item.id === id).map((item) => item.prediction ?? `error:${item.error_code}`)).size === 1).length;
  const inputTokens = results.reduce((sum, item) => sum + (item.usage?.input_tokens || 0), 0);
  const inputCostUsd = inputTokens * 0.042 / 1_000_000;
  return {
    total,
    unique_cases: caseIds.length,
    accuracy: total ? results.filter((item) => item.correct).length / total : 0,
    accepted_coverage: total ? accepted.length / total : 0,
    accepted_accuracy: accepted.length ? accepted.filter((item) => item.correct).length / accepted.length : 0,
    override_cases: new Set(overrideCases.map((item) => item.id)).size,
    override_observations: overrideCases.length,
    override_accuracy: overrideCases.length ? overrideCases.filter((item) => item.correct).length / overrideCases.length : 0,
    accepted_override_coverage: overrideCases.length ? acceptedOverrides.length / overrideCases.length : 0,
    accepted_override_accuracy: acceptedOverrides.length ? acceptedOverrides.filter((item) => item.correct).length / acceptedOverrides.length : 0,
    protected_safety_rate: protectedCases.length ? protectedCases.filter((item) => item.protected_preserved).length / protectedCases.length : 0,
    provider_error_rate: total ? results.filter((item) => item.error_code).length / total : 0,
    brier_score: brierScore,
    log_loss: logLoss,
    expected_calibration_error: expectedCalibrationError,
    calibration_bins: calibrationBins,
    confusion_matrix: confusion,
    stable_case_rate: caseIds.length ? stableCases / caseIds.length : 0,
    latency_p50_ms: percentile(results.map((item) => item.latency_ms), 0.5),
    latency_p95_ms: percentile(results.map((item) => item.latency_ms), 0.95),
    input_tokens: inputTokens,
    output_tokens: results.reduce((sum, item) => sum + (item.usage?.output_tokens || 0), 0),
    input_cost_usd: inputCostUsd,
    input_cost_per_accepted_decision_usd: accepted.length ? inputCostUsd / accepted.length : null,
  };
}

export function promotionRuntimeFingerprint(policy) {
  return fingerprint({
    schema_version: 1,
    provider: policy.provider,
    model: policy.model,
    max_state_chars: policy.max_state_chars,
    timeout_ms: policy.timeout_ms,
    max_retries: policy.max_retries,
    allowed_routes: policy.allowed_routes,
    decision_thresholds: policy.decision_thresholds,
    promotion_gates: policy.promotion_gates,
    state_shape: ["user_intent", "plan_status"],
    source_fingerprints: Object.fromEntries([
      "claude/hooks/workflow-router-lib.mjs",
      "pi/extensions/lib/route-shadow.mjs",
      "pi/extensions/lib/semantic-judgment.mjs",
      "pi/extensions/lib/semantic-route.mjs",
      "pi/extensions/lib/typesafe-system-one.mjs",
      "pi/extensions/workflow-router.ts",
    ].map((path) => [path, fingerprint(readFileSync(resolve(ROOT, path), "utf8"))])),
  });
}

function validateCalibrationResults(policy, manifest, corpus) {
  const results = manifest.results;
  const cases = new Map(corpus.cases.map((item) => [item.id, item]));
  if (!Number.isInteger(manifest.repetitions) || manifest.repetitions < 1 || cases.size !== corpus.cases.length || results.length !== corpus.cases.length * manifest.repetitions) throw new Error("semantic promotion repetition mismatch");
  const observations = new Set();
  for (const result of results) {
    const item = cases.get(result.id);
    const observationKey = `${result.id}:${result.run}`;
    const deterministicChoice = item ? semanticChoiceForDecision(classifyWorkflowRoute(item.prompt, { planStatus: item.plan_status || "missing" })) : null;
    if (!item || !Number.isInteger(result.run) || result.run < 1 || result.run > manifest.repetitions || observations.has(observationKey) || result.expected !== item.expected || result.deterministic_choice !== deterministicChoice || result.correct !== (result.prediction === item.expected) || result.protected !== isProtectedChoice(deterministicChoice) || Boolean(item.protected) !== isProtectedChoice(deterministicChoice)) throw new Error("semantic promotion result mismatch");
    observations.add(observationKey);
    if (result.error_code) {
      if (result.prediction !== null || result.probabilities !== null || result.confidence !== null || result.accepted_by_threshold || result.selection_reason !== "provider_abstain") throw new Error("semantic promotion error result mismatch");
      continue;
    }
    const probabilities = result.probabilities;
    if (!probabilities || Object.keys(probabilities).length !== policy.allowed_routes.length || policy.allowed_routes.some((route) => typeof probabilities[route] !== "number" || probabilities[route] < 0 || probabilities[route] > 1)) throw new Error("semantic promotion probabilities mismatch");
    const sum = Object.values(probabilities).reduce((total, probability) => total + probability, 0);
    if (Math.abs(sum - 1) > 0.02 || typeof result.confidence !== "number" || result.confidence < 0 || result.confidence > 1) throw new Error("semantic promotion answer mismatch");
    const deterministicDecision = result.deterministic_choice === "direct-edit" ? { route: "answer", writeAllowed: true } : { route: result.deterministic_choice, writeAllowed: false };
    const evaluation = evaluateSemanticSelection({ answer: { choice: result.prediction, probabilities, confidence: result.confidence }, deterministicDecision, planStatus: item.plan_status, thresholds: policy.decision_thresholds });
    if (result.accepted_by_threshold !== evaluation.accepted || result.selection_reason !== evaluation.reason || result.protected_preserved !== (!item.protected || evaluation.reason === "protected_deterministic_route")) throw new Error("semantic promotion threshold result mismatch");
  }
}

export function validatePromotionManifest(policy, manifest, corpus) {
  if (!manifest || manifest.schema_version !== 1 || manifest.evidence_kind !== "live_typesafe" || manifest.synthetic !== false) throw new Error("invalid semantic promotion evidence");
  if (manifest.policy_version !== policy.policy_version || manifest.model !== policy.model) throw new Error("semantic promotion identity mismatch");
  if (!sameValues(manifest.allowed_routes, policy.allowed_routes)) throw new Error("semantic promotion routes mismatch");
  if (!sameValues(manifest.thresholds, policy.decision_thresholds)) throw new Error("semantic promotion thresholds mismatch");
  if (manifest.runtime_fingerprint !== promotionRuntimeFingerprint(policy)) throw new Error("semantic promotion runtime mismatch");
  if (manifest.question_fingerprint !== routeQuestionFingerprint(policy.allowed_routes)) throw new Error("semantic promotion question mismatch");
  if (manifest.corpus_fingerprint !== fingerprint(corpus)) throw new Error("semantic promotion corpus mismatch");
  if (!Array.isArray(corpus?.cases) || !Array.isArray(manifest.results) || manifest.results.length !== corpus.cases.length * manifest.repetitions) throw new Error("semantic promotion result population mismatch");
  validateCalibrationResults(policy, manifest, corpus);
  const metrics = manifest.metrics;
  const gates = policy.promotion_gates;
  if (!sameValues(metrics, summarizeCalibrationResults(manifest.results))) throw new Error("semantic promotion metrics mismatch");
  if (!metrics || !Number.isInteger(metrics.unique_cases) || metrics.unique_cases < gates.min_cases || manifest.repetitions < gates.min_repetitions) throw new Error("semantic promotion sample gate failed");
  for (const key of ["accuracy", "protected_safety_rate", "provider_error_rate"]) {
    if (typeof metrics[key] !== "number" || !Number.isFinite(metrics[key]) || metrics[key] < 0 || metrics[key] > 1) throw new Error(`invalid semantic promotion metric ${key}`);
  }
  if (metrics.accuracy < gates.min_accuracy) throw new Error("semantic promotion accuracy gate failed");
  if (metrics.accepted_accuracy < gates.min_accepted_accuracy) throw new Error("semantic promotion accepted accuracy gate failed");
  if (metrics.accepted_coverage < gates.min_accepted_coverage) throw new Error("semantic promotion coverage gate failed");
  if (metrics.override_cases < gates.min_override_cases) throw new Error("semantic promotion override sample gate failed");
  if (metrics.override_accuracy < gates.min_override_accuracy) throw new Error("semantic promotion override accuracy gate failed");
  if (metrics.accepted_override_accuracy < gates.min_accepted_override_accuracy) throw new Error("semantic promotion accepted override accuracy gate failed");
  if (metrics.accepted_override_coverage < gates.min_accepted_override_coverage) throw new Error("semantic promotion override coverage gate failed");
  if (metrics.protected_safety_rate < gates.min_protected_safety_rate) throw new Error("semantic promotion safety gate failed");
  if (metrics.provider_error_rate > gates.max_provider_error_rate) throw new Error("semantic promotion error gate failed");
  if (metrics.stable_case_rate < gates.min_stable_case_rate) throw new Error("semantic promotion stability gate failed");
  if (metrics.brier_score === null || metrics.brier_score > gates.max_brier_score || metrics.expected_calibration_error === null || metrics.expected_calibration_error > gates.max_expected_calibration_error) throw new Error("semantic promotion calibration gate failed");
  if (metrics.input_cost_usd > gates.max_input_cost_usd) throw new Error("semantic promotion cost gate failed");
  if (!Number.isFinite(metrics.latency_p95_ms) || metrics.latency_p95_ms < 0 || metrics.latency_p95_ms > gates.max_latency_p95_ms) throw new Error("semantic promotion latency gate failed");
  return manifest;
}

export function loadSemanticPolicy(path = resolve(ROOT, "workflow/runtime/semantic-judgment-policy.json")) {
  const policy = JSON.parse(readFileSync(path, "utf8"));
  const requestedMode = process.env.ETABLI_SEMANTIC_MODE;
  if (requestedMode && requestedMode !== policy.mode) throw new Error("semantic mode is locked to checked-in policy");
  const mode = policy.mode;
  if (!["disabled", "shadow", "advisory", "enforced"].includes(mode)) throw new Error("invalid semantic mode");
  if (mode === "advisory") throw new Error("semantic advisory mode is not implemented");
  const validated = validateRuntimePolicy({ ...policy, mode });
  if (mode === "enforced") {
    const manifestPath = resolve(ROOT, relativePath(validated.promotion_manifest, "semantic promotion manifest"));
    if (!manifestPath.startsWith(`${ROOT}${sep}`)) throw new Error("invalid semantic promotion manifest path");
    const manifest = readJson(manifestPath, "semantic promotion manifest");
    const corpusPath = resolve(ROOT, relativePath(manifest.corpus_path, "semantic promotion corpus"));
    if (!corpusPath.startsWith(`${ROOT}${sep}`)) throw new Error("invalid semantic promotion corpus path");
    validated.promotion = validatePromotionManifest(validated, manifest, readJson(corpusPath, "semantic promotion corpus"));
  }
  return validated;
}

export function validateRuntimePolicy(policy) {
  if (!policy || typeof policy !== "object" || !["disabled", "shadow", "enforced"].includes(policy.mode)) throw new Error("unsupported semantic mode");
  if (typeof policy.provider !== "string" || !/^jev-\d+\.\d+\.\d+$/.test(policy.model)) throw new Error("invalid semantic provider policy");
  if (!Array.isArray(policy.allowed_routes) || policy.allowed_routes.length < 2 || new Set(policy.allowed_routes).size !== policy.allowed_routes.length || policy.allowed_routes.some((route) => typeof route !== "string" || !/^[a-z][a-z0-9-]*$/.test(route))) throw new Error("invalid semantic routes");
  routeQuestion(policy.allowed_routes);
  if (!Number.isInteger(policy.max_state_chars) || policy.max_state_chars < 1 || policy.max_state_chars > 10_000) throw new Error("invalid semantic state limit");
  if (!Number.isInteger(policy.timeout_ms) || policy.timeout_ms < 1 || policy.timeout_ms > 30_000 || !Number.isInteger(policy.max_retries) || policy.max_retries < 0 || policy.max_retries > 5) throw new Error("invalid semantic transport limits");
  relativePath(policy.receipt_path, "semantic receipt");
  for (const risk of ["read_only", "local_write"]) {
    const value = policy.decision_thresholds?.[risk];
    if (!value || typeof value.min_confidence !== "number" || value.min_confidence < 0 || value.min_confidence > 1 || typeof value.min_margin !== "number" || value.min_margin < 0 || value.min_margin > 1) throw new Error(`invalid semantic ${risk} threshold`);
  }
  const gates = policy.promotion_gates;
  if (!gates || !Number.isInteger(gates.min_cases) || gates.min_cases < 1 || gates.min_cases > 1000) throw new Error("invalid semantic promotion gates");
  for (const key of ["min_accuracy", "min_accepted_accuracy", "min_accepted_coverage", "min_override_accuracy", "min_accepted_override_accuracy", "min_accepted_override_coverage", "min_protected_safety_rate", "max_provider_error_rate", "min_stable_case_rate", "max_brier_score", "max_expected_calibration_error"]) {
    if (typeof gates[key] !== "number" || gates[key] < 0 || gates[key] > 1) throw new Error(`invalid semantic promotion gate ${key}`);
  }
  if (!Number.isInteger(gates.min_override_cases) || gates.min_override_cases < 1 || gates.min_override_cases > gates.min_cases) throw new Error("invalid semantic override sample gate");
  if (!Number.isInteger(gates.min_repetitions) || gates.min_repetitions < 1 || gates.min_repetitions > 10 || typeof gates.max_input_cost_usd !== "number" || gates.max_input_cost_usd <= 0) throw new Error("invalid semantic operational promotion gate");
  if (!Number.isInteger(gates.max_latency_p95_ms) || gates.max_latency_p95_ms < 1 || gates.max_latency_p95_ms > 30_000) throw new Error("invalid semantic latency gate");
  if (policy.mode === "enforced") relativePath(policy.promotion_manifest, "semantic promotion manifest");
  return policy;
}

function appendReceipt(root, path, receipt) {
  let descriptor;
  try {
    const lexicalRoot = resolve(root);
    const relativePath = relative(lexicalRoot, path);
    if (!relativePath || relativePath === ".." || relativePath.startsWith(`..${sep}`) || isAbsolute(relativePath)) return false;
    const realRoot = realpathSync(lexicalRoot);
    const parts = dirname(relativePath).split(sep).filter(Boolean);
    let current = realRoot;
    for (const part of parts) {
      current = join(current, part);
      try {
        const status = lstatSync(current);
        if (status.isSymbolicLink() || !status.isDirectory()) return false;
      } catch (error) {
        if (error?.code !== "ENOENT") return false;
        mkdirSync(current, { mode: 0o700 });
      }
    }
    const destination = join(realRoot, relativePath);
    try {
      const status = lstatSync(destination);
      if (status.isSymbolicLink() || !status.isFile()) return false;
    } catch (error) {
      if (error?.code !== "ENOENT") return false;
    }
    descriptor = openSync(destination, constants.O_WRONLY | constants.O_APPEND | constants.O_CREAT | constants.O_NOFOLLOW, 0o600);
    if (!fstatSync(descriptor).isFile()) return false;
    writeSync(descriptor, `${JSON.stringify(receipt)}\n`);
    return true;
  } catch {
    return false;
  } finally {
    if (descriptor !== undefined) closeSync(descriptor);
  }
}

function serviceErrorCode(error) {
  if (!(error instanceof TypeSafeServiceError)) return error instanceof Error ? "local_validation_error" : "unknown_error";
  return /^(?:missing_api_key|timeout|network_error|body_read_error|response_too_large|malformed_json|malformed_response|retry_exhausted|http_[1-5][0-9]{2})$/.test(error.code) ? error.code : "provider_error";
}

export async function runRouteDecision({ prompt, deterministicDecision, planStatus = "missing", cwd = process.cwd(), policy = loadSemanticPolicy(), provider = evaluateTypeSafe, persistReceipt = true }) {
  policy = validateRuntimePolicy(policy);
  if (policy.mode === "enforced" && !policy.promotion) throw new Error("semantic enforced mode requires validated promotion evidence");
  const deterministicChoice = semanticChoiceForDecision(deterministicDecision);
  if (!deterministicDecision || typeof deterministicDecision.route !== "string" || !policy.allowed_routes.includes(deterministicChoice)) throw new Error("invalid deterministic route");
  if (typeof persistReceipt !== "boolean" || (policy.mode !== "disabled" && typeof provider !== "function")) throw new Error("invalid semantic runtime hooks");
  if (policy.mode === "disabled") return { selected: deterministicDecision, receipt: null };
  const started = performance.now();
  let request;
  try {
    const minimized = minimizeRouteState(prompt, policy.max_state_chars);
    request = {
      state: { ...minimized, plan_status: planStatus },
      model: policy.model,
      questions: { route: routeQuestion(policy.allowed_routes) },
    };
    const response = await provider(request, { timeoutMs: policy.timeout_ms, maxRetries: policy.max_retries });
    const answer = response.answers.route;
    const evaluation = evaluateSemanticSelection({ answer, deterministicDecision, planStatus, thresholds: policy.decision_thresholds });
    const enforced = policy.mode === "enforced" && evaluation.accepted;
    const selected = enforced ? composeSemanticDecision(evaluation.choice, deterministicDecision, planStatus) : deterministicDecision;
    const outcome = evaluation.reason === "semantic_agreement" ? "agree" : evaluation.reason === "semantic_override" ? "diverge" : evaluation.reason;
    const receipt = sanitizedReceipt({ provider: policy.provider, policyVersion: policy.policy_version, request, response, deterministicDecision: deterministicChoice, selectedDecision: semanticChoiceForDecision(selected), selectionSource: enforced ? "jev" : "deterministic", selectionReason: evaluation.reason, latencyMs: performance.now() - started, outcome });
    const receiptPath = resolve(cwd, policy.receipt_path);
    if (!receiptPath.startsWith(`${resolve(cwd)}${sep}`)) throw new Error("invalid semantic receipt path");
    if (persistReceipt && !appendReceipt(cwd, receiptPath, receipt) && policy.mode === "enforced") {
      return {
        selected: deterministicDecision,
        receipt: {
          ...receipt,
          selected_decision: deterministicChoice,
          selection_source: "deterministic",
          selection_reason: "receipt_persistence_failed",
          outcome: "abstain",
          error_code: "receipt_persistence_failed",
        },
      };
    }
    return { selected, receipt };
  } catch (error) {
    if (!request) request = { state: { rejected: true }, model: policy.model, questions: { route: routeQuestion(policy.allowed_routes) } };
    const errorCode = serviceErrorCode(error);
    const receipt = sanitizedReceipt({ provider: policy.provider, policyVersion: policy.policy_version, request, deterministicDecision: deterministicChoice, selectedDecision: deterministicChoice, selectionSource: "deterministic", selectionReason: "provider_abstain", latencyMs: performance.now() - started, outcome: "abstain", errorCode });
    const receiptPath = resolve(cwd, policy.receipt_path);
    if (persistReceipt && receiptPath.startsWith(`${resolve(cwd)}${sep}`)) appendReceipt(cwd, receiptPath, receipt);
    return { selected: deterministicDecision, receipt };
  }
}

export const runRouteShadow = runRouteDecision;
