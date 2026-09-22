import { closeSync, constants, fstatSync, lstatSync, mkdirSync, openSync, readFileSync, realpathSync, writeSync } from "node:fs";
import { dirname, isAbsolute, join, normalize, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { containsSecretLike, fingerprint, stableJson, validateJudgmentRequest, validateJudgmentResponse } from "./semantic-judgment.mjs";
import { evaluateTypeSafe } from "./typesafe-system-one.mjs";
import { isPreparedClaimEvidenceState } from "./semantic-claim-evidence.mjs";
import { prepareSelfImprovementDiagnosisState, reduceSelfImprovementDiagnosis, rejectedSelfImprovementDiagnosis } from "./self-improvement-diagnosis.mjs";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
export const DEFAULT_PROFILE_POLICY_PATH = join(ROOT, "workflow/runtime/semantic-profile-policy.json");
const AUTHORITIES = new Set(["shadow", "advisory", "diagnostic"]);
const EGRESS_CLASSES = new Set(["public_or_sanitized", "private_opt_in", "metadata_only"]);
const UNCERTAINTY_KEYS = new Set(["choice_min_confidence", "choice_min_margin", "noul_false_max", "noul_true_min", "score_min_confidence"]);
const STATE_FIELD_TYPES = new Set(["nonempty_string", "true", "false", "self_improvement_candidate", "self_improvement_evidence", "self_improvement_episode", "self_improvement_signals"]);
const SENSITIVE_KEYS = new Set(["token", "accesstoken", "refreshtoken", "idtoken", "apikey", "secret", "clientsecret", "password", "passwd", "cookie", "cookies", "authorization", "credential", "credentials", "privatekey", "accesskey", "awsaccesskeyid", "awssecretaccesskey", "sessioncookie"]);
const SAFE_TOKEN_METADATA_KEYS = new Set(["inputtokens", "outputtokens", "totaltokens", "maxtokens", "tokencount", "tokenbudget"]);
const SELF_IMPROVEMENT_CANDIDATE = /^action=(no_op|recommendation);category=(no_issue|validation_failure|tool_failure|review_rework|plan_rework|context_pressure|incomplete_evidence);target=(none|skill|rule|testing|tooling|context)$/;
const SELF_IMPROVEMENT_EVIDENCE = /^runs=([1-9][0-9]{0,3});complete=(true|false);terminal=(completed|blocked);verifier=(true|false)$/;
const SELF_IMPROVEMENT_EPISODE = /^schema=1;completeness=complete;terminal=(completed|blocked);verifier=(true|false)$/;
const SELF_IMPROVEMENT_SIGNALS = /^tool_calls=(?:null|(?:0|[1-9][0-9]{0,4}));tool_errors=(?:null|(?:0|[1-9][0-9]{0,4}));validation_failures=(?:null|(?:0|[1-9][0-9]{0,4}));review_rework=(?:null|(?:0|[1-9][0-9]{0,4}));plan_rework=(?:null|(?:0|[1-9][0-9]{0,4}));compactions=(?:null|(?:0|[1-9][0-9]{0,4}));retries=(?:null|(?:0|[1-9][0-9]{0,4}))$/;
const COMPLETE_SELF_IMPROVEMENT_CANDIDATES = new Set([
  "action=no_op;category=no_issue;target=none",
  "action=recommendation;category=validation_failure;target=testing",
  "action=recommendation;category=tool_failure;target=tooling",
  "action=recommendation;category=review_rework;target=rule",
  "action=recommendation;category=plan_rework;target=skill",
  "action=recommendation;category=context_pressure;target=context",
]);
const PARTIAL_SELF_IMPROVEMENT_CANDIDATE = "action=no_op;category=incomplete_evidence;target=none";
const SELF_IMPROVEMENT_STATE_SCHEMA = {
  candidate: "self_improvement_candidate",
  evidence: "self_improvement_evidence",
};
const SELF_IMPROVEMENT_PROFILE_ENVELOPE = {
  authority: "shadow",
  egress_class: "private_opt_in",
  deterministic_owner: "workflow/skills/self-improvement-loop.md",
};
const SELF_IMPROVEMENT_DIAGNOSIS_STATE_SCHEMA = {
  episode: "self_improvement_episode",
  signals: "self_improvement_signals",
};
const SELF_IMPROVEMENT_DIAGNOSIS_ENVELOPE = {
  authority: "diagnostic",
  egress_class: "private_opt_in",
  deterministic_owner: "workflow/trace-self-improvement.md",
  calibration_status: "pending_corpus",
  contract_fingerprint: "2d459c4a2e79e3ad75ee24b08f15115de3dd0b5ec169f8ae0eee7ae432bf0066",
  max_state_chars: 2048,
};

function diagnosisContract(profile) {
  const { purpose: _purpose, contract_fingerprint: _fingerprint, ...contract } = profile;
  return contract;
}

function plainObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function assertProbability(value, label) {
  if (typeof value !== "number" || value < 0 || value > 1) throw new Error(`invalid ${label}`);
}

export function containsSensitiveProfileData(value) {
  if (containsSecretLike(value)) return true;
  const visit = (candidate) => {
    if (typeof candidate === "string") return /(?:\b(?:token|secret|cookie|authorization|aws_access_key_id|aws_secret_access_key)\b\s*[:=]\s*\S+|\bAKIA[0-9A-Z]{16}\b|\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b|[a-z][a-z0-9+.-]*:\/\/[^\s/:@]+:[^\s/@]+@)/i.test(candidate);
    if (Array.isArray(candidate)) return candidate.some(visit);
    if (!plainObject(candidate)) return false;
    return Object.entries(candidate).some(([key, nested]) => {
      const normalizedKey = key.replace(/[^a-z0-9]/gi, "").toLowerCase();
      const sensitiveKey = SENSITIVE_KEYS.has(normalizedKey) || !SAFE_TOKEN_METADATA_KEYS.has(normalizedKey) && /(?:token|secret|password|passwd|cookie|credential|authorization|apikey|accesskey|privatekey)$/.test(normalizedKey);
      return sensitiveKey && nested !== "" && nested !== null && nested !== undefined || visit(nested);
    });
  };
  return visit(value);
}

function validateStateSchema(profile, state, id) {
  if (!plainObject(profile.state_schema) || Object.keys(profile.state_schema).length === 0) throw new Error(`state schema required ${id}`);
  for (const [field, type] of Object.entries(profile.state_schema)) {
    if (!/^[a-z][a-z0-9_]{0,63}$/.test(field) || !STATE_FIELD_TYPES.has(type)) throw new Error(`invalid state schema ${id}.${field}`);
    const value = state[field];
    if (type === "nonempty_string" && (typeof value !== "string" || !value.trim())) throw new Error(`invalid state field ${id}.${field}`);
    if (type === "true" && value !== true) throw new Error(`invalid state field ${id}.${field}`);
    if (type === "false" && value !== false) throw new Error(`invalid state field ${id}.${field}`);
    if (type === "self_improvement_candidate" && (typeof value !== "string" || !SELF_IMPROVEMENT_CANDIDATE.test(value))) throw new Error(`invalid state field ${id}.${field}`);
    if (type === "self_improvement_episode" && (typeof value !== "string" || !SELF_IMPROVEMENT_EPISODE.test(value))) throw new Error(`invalid state field ${id}.${field}`);
    if (type === "self_improvement_signals") {
      const bounded = typeof value === "string" && SELF_IMPROVEMENT_SIGNALS.test(value) && value.split(";").every((entry) => {
        const count = entry.slice(entry.indexOf("=") + 1);
        return count === "null" || Number(count) <= 20_000;
      });
      if (!bounded) throw new Error(`invalid state field ${id}.${field}`);
    }
    if (type === "self_improvement_evidence") {
      const match = typeof value === "string" && value.match(SELF_IMPROVEMENT_EVIDENCE);
      if (!match || Number(match[1]) > 1000) throw new Error(`invalid state field ${id}.${field}`);
    }
  }
  if (profile.state_schema.candidate === "self_improvement_candidate" && profile.state_schema.evidence === "self_improvement_evidence") {
    if (Object.keys(state).sort().join(",") !== "candidate,evidence") throw new Error(`invalid state field ${id}.candidate`);
    const candidate = state.candidate.match(SELF_IMPROVEMENT_CANDIDATE);
    const evidence = state.evidence.match(SELF_IMPROVEMENT_EVIDENCE);
    const canonicalCandidate = candidate[0];
    const complete = evidence[2] === "true";
    if (complete ? !COMPLETE_SELF_IMPROVEMENT_CANDIDATES.has(canonicalCandidate) : canonicalCandidate !== PARTIAL_SELF_IMPROVEMENT_CANDIDATE) throw new Error(`invalid state field ${id}.candidate`);
  }
  if (profile.state_schema.episode === "self_improvement_episode" && profile.state_schema.signals === "self_improvement_signals" && Object.keys(state).sort().join(",") !== "episode,signals") throw new Error(`invalid state field ${id}.episode`);
}

export function validateProfilePolicy(policy) {
  if (!plainObject(policy) || policy.schema_version !== 1 || typeof policy.policy_version !== "string" || !/^semantic-profile-catalog-\d+\.\d+\.\d+$/.test(policy.catalog_version || "")) throw new Error("invalid profile policy");
  if (policy.provider !== "typesafe-system-one" || !/^jev-\d+\.\d+\.\d+$/.test(policy.model)) throw new Error("invalid profile provider or model");
  if (!Number.isInteger(policy.timeout_ms) || policy.timeout_ms < 1 || policy.timeout_ms > 30000 || !Number.isInteger(policy.max_retries) || policy.max_retries < 0 || policy.max_retries > 5) throw new Error("invalid profile transport limits");
  const receiptPath = normalize(policy.receipt_path || "");
  if (!receiptPath || isAbsolute(receiptPath) || receiptPath === ".." || receiptPath.startsWith(`..${sep}`)) throw new Error("invalid profile receipt path");
  if (!plainObject(policy.profiles) || Object.keys(policy.profiles).length !== 13) throw new Error("profile policy must contain exactly 13 profiles");
  for (const [id, profile] of Object.entries(policy.profiles)) {
    if (!/^[a-z][a-z0-9-]{1,63}$/.test(id) || !plainObject(profile)) throw new Error(`invalid profile ${id}`);
    if (!profile.purpose || !AUTHORITIES.has(profile.authority) || !EGRESS_CLASSES.has(profile.egress_class) || !profile.deterministic_owner) throw new Error(`invalid profile metadata ${id}`);
    if (profile.authority === "diagnostic" && id !== "self-improvement-diagnosis") throw new Error(`invalid profile metadata ${id}`);
    if (id === "self-improvement-candidate") {
      if (stableJson(profile.state_schema) !== stableJson(SELF_IMPROVEMENT_STATE_SCHEMA)) throw new Error(`invalid state schema ${id}`);
      for (const [field, value] of Object.entries(SELF_IMPROVEMENT_PROFILE_ENVELOPE)) {
        if (profile[field] !== value) throw new Error(`invalid profile metadata ${id}`);
      }
    }
    if (id === "self-improvement-diagnosis") {
      if (stableJson(profile.state_schema) !== stableJson(SELF_IMPROVEMENT_DIAGNOSIS_STATE_SCHEMA)) throw new Error(`invalid state schema ${id}`);
      for (const [field, value] of Object.entries(SELF_IMPROVEMENT_DIAGNOSIS_ENVELOPE)) {
        if (profile[field] !== value) throw new Error(`invalid profile metadata ${id}`);
      }
      if (fingerprint(diagnosisContract(profile)) !== profile.contract_fingerprint) throw new Error(`invalid profile contract ${id}`);
    } else if (profile.calibration_status !== undefined) throw new Error(`invalid calibration status ${id}`);
    if (!Number.isInteger(profile.max_state_chars) || profile.max_state_chars < 256 || profile.max_state_chars > 10000) throw new Error(`invalid max state ${id}`);
    validateStateSchema(profile, Object.fromEntries(Object.entries(profile.state_schema || {}).map(([field, type]) => {
      if (type === "nonempty_string") return [field, "fixture"];
      if (type === "self_improvement_candidate") return [field, "action=no_op;category=no_issue;target=none"];
      if (type === "self_improvement_evidence") return [field, "runs=1;complete=true;terminal=completed;verifier=true"];
      if (type === "self_improvement_episode") return [field, "schema=1;completeness=complete;terminal=completed;verifier=true"];
      if (type === "self_improvement_signals") return [field, "tool_calls=0;tool_errors=0;validation_failures=0;review_rework=0;plan_rework=0;compactions=0;retries=null"];
      return [field, type === "true"];
    })), id);
    if (!plainObject(profile.questions) || (!profile.builder && Object.keys(profile.questions).length === 0) || (profile.builder && profile.builder !== "skill-suggestion-v1")) throw new Error(`questions required ${id}`);
    const request = { model: policy.model, state: { validation: true }, questions: profile.builder ? { placeholder: { type: "noul", instructions: "Validation placeholder." } } : profile.questions };
    validateJudgmentRequest(request);
    const uncertainty = profile.uncertainty;
    if (!plainObject(uncertainty)) throw new Error(`uncertainty required ${id}`);
    for (const [key, value] of Object.entries(uncertainty)) {
      if (!UNCERTAINTY_KEYS.has(key)) throw new Error(`unknown uncertainty key ${id}.${key}`);
      assertProbability(value, `${id}.${key}`);
    }
    if (uncertainty.noul_false_max !== undefined && uncertainty.noul_true_min !== undefined && uncertainty.noul_false_max >= uncertainty.noul_true_min) throw new Error(`invalid noul uncertainty ${id}`);
    const questionTypes = new Set(profile.builder ? ["choice", "noul"] : Object.values(profile.questions).map((question) => question.type));
    if (questionTypes.has("choice") && (uncertainty.choice_min_confidence === undefined || uncertainty.choice_min_margin === undefined)) throw new Error(`choice uncertainty required ${id}`);
    if (questionTypes.has("noul") && (uncertainty.noul_false_max === undefined || uncertainty.noul_true_min === undefined)) throw new Error(`noul uncertainty required ${id}`);
    if (questionTypes.has("score") && uncertainty.score_min_confidence === undefined) throw new Error(`score uncertainty required ${id}`);
  }
  return policy;
}

export function loadSemanticProfilePolicy(path = process.env.ETABLI_SEMANTIC_PROFILE_POLICY || DEFAULT_PROFILE_POLICY_PATH) {
  return validateProfilePolicy(JSON.parse(readFileSync(resolve(path), "utf8")));
}

export function profileSummary(policy = loadSemanticProfilePolicy()) {
  return Object.entries(policy.profiles).map(([id, profile]) => ({ id, purpose: profile.purpose, authority: profile.authority, egress_class: profile.egress_class, max_state_chars: profile.max_state_chars, deterministic_owner: profile.deterministic_owner, dynamic: Boolean(profile.builder) }));
}

/**
 * @param {string} profileId
 * @param {Record<string, unknown>} state
 * @param {{policy?: any, questions?: Record<string, unknown>}} [options]
 */
export function prepareProfileRequest(profileId, state, options = {}) {
  const { policy: candidatePolicy = loadSemanticProfilePolicy(), questions } = options;
  const policy = validateProfilePolicy(candidatePolicy);
  const profile = policy.profiles[profileId];
  if (!profile) throw new Error(`unknown profile: ${profileId}`);
  if (!plainObject(state)) throw new Error("profile state must be an object");
  const serialized = stableJson(state);
  if (serialized.length > profile.max_state_chars) throw new Error("profile state too large");
  if (containsSensitiveProfileData(state)) throw new Error("secret-like state rejected");
  validateStateSchema(profile, state, profileId);
  if (profileId === "claim-evidence" && !isPreparedClaimEvidenceState(state)) throw new Error("claim state must come from structural checker");
  const projectedState = Object.fromEntries(Object.keys(profile.state_schema).map((field) => [field, state[field]]));
  const resolvedQuestions = questions ?? profile.questions;
  if (profile.builder && !questions) throw new Error(`dynamic questions required: ${profileId}`);
  if (stableJson(resolvedQuestions).length > 32000) throw new Error("profile questions too large");
  return validateJudgmentRequest({ model: policy.model, state: projectedState, questions: resolvedQuestions });
}

function interpretChoice(answer, uncertainty) {
  const ranked = Object.entries(answer.probabilities).sort((a, b) => b[1] - a[1]);
  const top = ranked[0]?.[1] ?? 0;
  const margin = top - (ranked[1]?.[1] ?? 0);
  const accepted = answer.choice === ranked[0]?.[0] && answer.confidence >= (uncertainty.choice_min_confidence ?? 0.75) && margin >= (uncertainty.choice_min_margin ?? 0.15);
  return { value: accepted ? answer.choice : null, raw_value: answer.choice, confidence: answer.confidence, margin, status: accepted ? "accepted" : "uncertain" };
}

function interpretNoul(answer, uncertainty) {
  const falseMax = uncertainty.noul_false_max ?? 0.2;
  const trueMin = uncertainty.noul_true_min ?? 0.8;
  const value = answer.noul <= falseMax ? false : answer.noul >= trueMin ? true : null;
  return { value, probability: answer.noul, status: value === null ? "uncertain" : "accepted" };
}

function interpretScore(answer, uncertainty, criteria) {
  const accepted = answer.confidence >= (uncertainty.score_min_confidence ?? 0.75);
  const index = Math.max(0, Math.min(criteria.length - 1, Math.round(answer.score)));
  return { value: accepted ? answer.score : null, raw_value: answer.score, confidence: answer.confidence, legend: criteria[index], status: accepted ? "accepted" : "uncertain" };
}

export function interpretProfileResponse(profile, response) {
  const decisions = {};
  for (const [id, answer] of Object.entries(response.answers)) {
    decisions[id] = answer.type === "choice" ? interpretChoice(answer, profile.uncertainty) : answer.type === "noul" ? interpretNoul(answer, profile.uncertainty) : interpretScore(answer, profile.uncertainty, profile.questions[id].criteria);
  }
  return decisions;
}

function receiptFor({ profileId, policy, profile, request, response, decisions, latencyMs, outcome, errorCode }) {
  return {
    schema_version: 1,
    ts: new Date().toISOString(),
    profile_id: profileId,
    provider: policy.provider,
    model: policy.model,
    policy_version: policy.policy_version,
    catalog_version: policy.catalog_version,
    authority: profile.authority,
    egress_class: profile.egress_class,
    state_fingerprint: fingerprint(request.state),
    question_fingerprint: fingerprint(request.questions),
    decisions: decisions ?? null,
    latency_ms: Math.max(0, Math.round(latencyMs)),
    usage: response?.usage ?? null,
    outcome,
    error_code: errorCode ?? null
  };
}

export function appendProfileReceipt(cwd, policy, receipt) {
  const lexicalRoot = resolve(cwd);
  const configured = normalize(policy.receipt_path || "");
  if (!configured || isAbsolute(configured) || configured === ".." || configured.startsWith(`..${sep}`)) throw new Error("invalid receipt path");
  const relativeTarget = relative(lexicalRoot, resolve(lexicalRoot, configured));
  if (!relativeTarget || relativeTarget === ".." || relativeTarget.startsWith(`..${sep}`) || isAbsolute(relativeTarget)) throw new Error("receipt path escapes root");
  const realRoot = realpathSync(lexicalRoot);
  let current = realRoot;
  for (const part of dirname(relativeTarget).split(sep).filter(Boolean)) {
    current = join(current, part);
    try {
      const status = lstatSync(current);
      if (status.isSymbolicLink() || !status.isDirectory()) throw new Error("unsafe receipt directory");
    } catch (error) {
      if (error?.code !== "ENOENT") throw error;
      mkdirSync(current, { mode: 0o700 });
    }
  }
  const target = join(realRoot, relativeTarget);
  try {
    const status = lstatSync(target);
    if (status.isSymbolicLink() || !status.isFile()) throw new Error("unsafe receipt target");
  } catch (error) {
    if (error?.code !== "ENOENT") throw error;
  }
  const fd = openSync(target, constants.O_WRONLY | constants.O_APPEND | constants.O_CREAT | constants.O_NOFOLLOW, 0o600);
  try {
    if (!fstatSync(fd).isFile()) throw new Error("unsafe receipt descriptor");
    writeSync(fd, `${JSON.stringify(receipt)}\n`);
  } finally { closeSync(fd); }
}

/**
 * @param {{profileId: string, state: Record<string, unknown>, questions?: Record<string, unknown>, policy?: any, provider?: Function, allowProviderEgress?: boolean, persistReceipt?: boolean, cwd?: string}} options
 * @returns {Promise<any>}
 */
async function evaluateSemanticProfileInternal({ profileId, state, questions = undefined, policy = loadSemanticProfilePolicy(), provider = evaluateTypeSafe, allowProviderEgress = false, persistReceipt = true, cwd = process.cwd(), allowDiagnostic = false }) {
  const policySnapshot = validateProfilePolicy(structuredClone(policy));
  const profile = policySnapshot.profiles[profileId];
  if (!profile) throw new Error(`unknown profile: ${profileId}`);
  if (profile.authority === "diagnostic" && !allowDiagnostic) throw new Error(`diagnostic profile requires dedicated evaluator: ${profileId}`);
  const started = Date.now();
  let request;
  let response = null;
  let decisions = null;
  let outcome = "abstain";
  let errorCode = null;
  try {
    request = prepareProfileRequest(profileId, state, { policy: policySnapshot, questions });
    if (allowProviderEgress !== true) throw new Error("provider egress not allowed");
    response = validateJudgmentResponse(request, await provider(request, { timeoutMs: policySnapshot.timeout_ms, maxRetries: policySnapshot.max_retries }));
    decisions = interpretProfileResponse(profile, response);
    outcome = Object.values(decisions).some((decision) => decision.status === "uncertain") ? "uncertain" : "accepted";
  } catch (error) {
    errorCode = String(error?.code || error?.message || "evaluation_error").replace(/[^a-z0-9_-]+/gi, "_").toLowerCase().slice(0, 80);
    if (!request) request = { model: policySnapshot.model, state: { rejected: true }, questions: profile?.questions ?? {} };
  }
  const receipt = receiptFor({ profileId, policy: policySnapshot, profile, request, response, decisions, latencyMs: Date.now() - started, outcome, errorCode });
  if (persistReceipt) appendProfileReceipt(cwd, policySnapshot, receipt);
  return { profile: profileId, authority: profile.authority, answers: response?.answers ?? null, decisions, outcome, error_code: errorCode, receipt };
}

export async function evaluateSemanticProfile(options) {
  return evaluateSemanticProfileInternal(options);
}

export function prepareSelfImprovementDiagnosisRequest(observation, policy = loadSemanticProfilePolicy()) {
  return prepareProfileRequest("self-improvement-diagnosis", prepareSelfImprovementDiagnosisState(observation), { policy });
}

export async function evaluateSelfImprovementDiagnosis({ observation, policy = loadSemanticProfilePolicy(), provider = evaluateTypeSafe, allowProviderEgress = false, persistReceipt = true, cwd = process.cwd() }) {
  let state;
  try {
    state = prepareSelfImprovementDiagnosisState(observation);
  } catch (error) {
    return rejectedSelfImprovementDiagnosis(error);
  }
  const policySnapshot = validateProfilePolicy(structuredClone(policy));
  const result = await evaluateSemanticProfileInternal({ profileId: "self-improvement-diagnosis", state, policy: policySnapshot, provider, allowProviderEgress, persistReceipt: false, cwd, allowDiagnostic: true });
  const diagnosis = reduceSelfImprovementDiagnosis(result, { terminal: observation.lifecycle.outcome, verifier: observation.signals.verifier });
  if (diagnosis.status === "abstain" && result.receipt.outcome === "accepted") {
    result.receipt = { ...result.receipt, outcome: "abstain", error_code: diagnosis.reason };
  }
  if (persistReceipt) appendProfileReceipt(cwd, policySnapshot, result.receipt);
  return diagnosis;
}
