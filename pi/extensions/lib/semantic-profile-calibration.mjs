import { closeSync, constants, fstatSync, lstatSync, mkdirSync, mkdtempSync, openSync, readFileSync, renameSync, rmSync, writeFileSync, writeSync } from "node:fs";
import { dirname, join, relative, resolve, sep } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import { evaluateSemanticProfile, loadSemanticProfilePolicy } from "./semantic-profiles.mjs";
import { loadSkillSuggestionCatalog, suggestSkill } from "./semantic-skill-suggestion.mjs";
import { prepareClaimEvidenceState } from "./semantic-claim-evidence.mjs";
import { evaluateTypeSafe } from "./typesafe-system-one.mjs";
import { fingerprint, stableJson } from "./semantic-judgment.mjs";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
export const CORPUS_DIR = join(ROOT, "tests/fixtures/jev-profiles");
export const REPORT_DIR = join(ROOT, "workflow/runtime/jev-profile-calibration");
const SOURCE_PATHS = [
  "scripts/jev-profile-calibrate",
  "pi/extensions/lib/semantic-profile-calibration.mjs",
  "pi/extensions/lib/semantic-profiles.mjs",
  "pi/extensions/lib/semantic-skill-suggestion.mjs",
  "pi/extensions/lib/semantic-claim-evidence.mjs",
  "pi/extensions/lib/semantic-judgment.mjs",
  "pi/extensions/lib/typesafe-system-one.mjs",
];
const PRICE_PER_MTOK = 0.042;
const REQUEST_RESERVATION = 64_000;
const BINS = [[0, 0.5], [0.5, 0.75], [0.75, 1.000001]];

function plainObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function readRegularJson(path) {
  let fd;
  try {
    fd = openSync(resolve(path), constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
    const stat = fstatSync(fd);
    if (!stat.isFile() || stat.size > 1_048_576) throw new Error("invalid calibration file");
    return JSON.parse(readFileSync(fd, "utf8"));
  } finally { if (fd !== undefined) closeSync(fd); }
}

function percentile(values, fraction) {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.ceil(sorted.length * fraction) - 1)];
}

function mean(values) {
  return values.length ? values.reduce((sum, value) => sum + value, 0) / values.length : 0;
}

/** @param {number | [number, number]} value */
function exactExpectedRange(value, levels) {
  const range = Number.isInteger(value) ? [value, value] : value;
  if (!Array.isArray(range) || range.length !== 2 || !range.every(Number.isInteger) || range[0] < 0 || range[1] < range[0] || range[1] >= levels || range[1] - range[0] > 1) throw new Error("invalid score expectation");
  return range;
}

function assertExpected(question, expected) {
  if (question.type === "choice" && !Object.hasOwn(question.criteria, expected)) throw new Error("choice expectation outside criteria");
  if (question.type === "noul" && typeof expected !== "boolean") throw new Error("noul expectation must be boolean");
  if (question.type === "score") exactExpectedRange(expected, question.criteria.length);
}

function validateChoiceFloors(question, cases, id) {
  const options = Object.keys(question.criteria);
  const counts = Object.fromEntries(options.map((option) => [option, cases.filter((item) => item.expected[id] === option).length]));
  if (options.length <= 6 && options.some((option) => counts[option] < 2)) throw new Error(`choice floor failed ${id}`);
  if (options.length === 7 && (options.some((option) => counts[option] < 1) || Object.values(counts).filter((count) => count >= 2).length < 5)) throw new Error(`choice floor failed ${id}`);
}

function validateStaticFloors(profile, cases) {
  for (const [id, question] of Object.entries(profile.questions)) {
    if (question.type === "noul") {
      const values = cases.map((item) => item.expected[id]);
      if (values.filter(Boolean).length < 4 || values.filter((value) => value === false).length < 4) throw new Error(`noul floor failed ${id}`);
    } else if (question.type === "choice") validateChoiceFloors(question, cases, id);
    else {
      for (let level = 0; level < question.criteria.length; level += 1) {
        if (cases.filter((item) => Number.isInteger(item.expected[id]) && item.expected[id] === level).length < 2) throw new Error(`score floor failed ${id}.${level}`);
      }
    }
  }
}

function validateSkillFloors(cases) {
  const positives = cases.filter((item) => typeof item.expected_selected === "string");
  const noMatch = cases.filter((item) => item.expected_selected === null);
  if (new Set(positives.map((item) => item.expected_selected)).size < 6 || noMatch.length < 3) throw new Error("skill suggestion floor failed");
}

export function validateCalibrationCorpus(corpus, policy = loadSemanticProfilePolicy()) {
  if (!plainObject(corpus) || corpus.schema_version !== 1 || !policy.profiles[corpus.profile_id] || !Array.isArray(corpus.cases)) throw new Error("invalid calibration corpus");
  const profile = policy.profiles[corpus.profile_id];
  const semantic = corpus.cases.filter((item) => item.kind === "semantic");
  const preflight = corpus.cases.filter((item) => item.kind === "preflight_reject");
  if (semantic.length !== 12 || semantic.filter((item) => item.safety === true).length < 2) throw new Error("corpus requires exactly 12 semantic cases and two safety cases");
  if (new Set(corpus.cases.map((item) => item.id)).size !== corpus.cases.length || corpus.cases.some((item) => !/^[a-z0-9][a-z0-9-]{2,63}$/.test(item.id || "") || !item.justification)) throw new Error("invalid calibration case metadata");
  for (const item of semantic) {
    if (corpus.profile_id === "skill-suggestion") {
      if (typeof item.prompt !== "string" || !item.prompt.trim() || !(typeof item.expected_selected === "string" || item.expected_selected === null)) throw new Error("invalid skill calibration case");
    } else {
      if (!plainObject(item.state) || !plainObject(item.expected)) throw new Error("invalid semantic calibration case");
      for (const [id, question] of Object.entries(profile.questions)) assertExpected(question, item.expected[id]);
      if (Object.keys(item.expected).length !== Object.keys(profile.questions).length) throw new Error("semantic expectation shape mismatch");
    }
  }
  for (const item of preflight) if (!item.expected_error || !plainObject(item.state)) throw new Error("invalid preflight calibration case");
  if (corpus.profile_id === "skill-suggestion") validateSkillFloors(semantic); else validateStaticFloors(profile, semantic);
  return { corpus, profile, semantic, preflight };
}

export function loadCalibrationCorpus(profileId, policy = loadSemanticProfilePolicy()) {
  return validateCalibrationCorpus(readRegularJson(join(CORPUS_DIR, `${profileId}.json`)), policy);
}

function averageProbabilityMaps(values) {
  const keys = Object.keys(values[0] || {});
  return Object.fromEntries(keys.map((key) => [key, mean(values.map((value) => value[key]))]));
}

function calibrationBins(cases) {
  return BINS.map(([min, max]) => {
    const values = cases.filter((item) => item.calibration_confidence >= min && item.calibration_confidence < max);
    return { range: [min, Math.min(max, 1)], count: values.length, mean_probability: values.length ? mean(values.map((item) => item.calibration_confidence)) : null, observed_accuracy: values.length ? mean(values.map((item) => item.correct ? 1 : 0)) : null };
  });
}

function finishMetrics(cases, extra = {}) {
  const accepted = cases.filter((item) => item.accepted);
  const bins = calibrationBins(cases);
  return {
    cases: cases.length,
    accuracy: mean(cases.map((item) => item.correct ? 1 : 0)),
    accepted_accuracy: accepted.length ? mean(accepted.map((item) => item.correct ? 1 : 0)) : 0,
    accepted_coverage: cases.length ? accepted.length / cases.length : 0,
    stability: mean(cases.map((item) => item.stable ? 1 : 0)),
    expected_calibration_error: cases.length ? bins.reduce((sum, bin) => sum + (bin.count / cases.length) * (bin.count ? Math.abs(bin.mean_probability - bin.observed_accuracy) : 0), 0) : null,
    calibration_bins: bins,
    ...extra,
  };
}

function choiceMetrics(question, expectedByCase, observations, uncertainty) {
  const cases = [...expectedByCase].map(([caseId, expected]) => {
    const answers = observations.filter((item) => item.id === caseId && !item.error_code).map((item) => item.answers[question]);
    const probabilities = averageProbabilityMaps(answers.map((answer) => answer.probabilities));
    const ranked = Object.entries(probabilities).sort((a, b) => b[1] - a[1]);
    const prediction = ranked[0]?.[0] ?? null;
    const confidence = mean(answers.map((answer) => answer.confidence));
    const accepted = answers.length === 3 && answers.every((answer) => {
      const answerRanked = Object.entries(answer.probabilities).sort((a, b) => b[1] - a[1]);
      return answer.choice === answerRanked[0]?.[0] && answer.confidence >= uncertainty.choice_min_confidence && (answerRanked[0]?.[1] ?? 0) - (answerRanked[1]?.[1] ?? 0) >= uncertainty.choice_min_margin;
    });
    return { correct: prediction === expected, accepted, stable: answers.length === 3 && new Set(answers.map((answer) => answer.choice)).size === 1, calibration_confidence: ranked[0]?.[1] ?? 0, brier: Object.entries(probabilities).reduce((sum, [option, probability]) => sum + (probability - (option === expected ? 1 : 0)) ** 2, 0) };
  });
  return finishMetrics(cases, { brier_score: mean(cases.map((item) => item.brier)) });
}

function noulMetrics(question, expectedByCase, observations, uncertainty) {
  const cases = [...expectedByCase].map(([caseId, expected]) => {
    const answers = observations.filter((item) => item.id === caseId && !item.error_code).map((item) => item.answers[question]);
    const probability = mean(answers.map((answer) => answer.noul));
    const prediction = probability >= 0.5;
    return { correct: prediction === expected, accepted: answers.length === 3 && answers.every((answer) => answer.noul <= uncertainty.noul_false_max || answer.noul >= uncertainty.noul_true_min), stable: answers.length === 3 && new Set(answers.map((answer) => answer.noul >= 0.5)).size === 1, calibration_confidence: Math.max(probability, 1 - probability), brier: (probability - (expected ? 1 : 0)) ** 2 };
  });
  return finishMetrics(cases, { brier_score: mean(cases.map((item) => item.brier)) });
}

/**
 * @returns {{ cases: number, accuracy: number, accepted_accuracy: number, accepted_coverage: number, stability: number, expected_calibration_error: number | null, calibration_bins: Array<object>, mean_absolute_error: number, ranked_probability_score: number }}
 */
function scoreMetrics(question, expectedByCase, observations, uncertainty, criteria) {
  const levels = criteria.length;
  const cases = [...expectedByCase].map(([caseId, expected]) => {
    const answers = observations.filter((item) => item.id === caseId && !item.error_code).map((item) => item.answers[question]);
    const probabilities = averageProbabilityMaps(answers.map((answer) => answer.probabilities));
    const score = mean(answers.map((answer) => answer.score));
    const confidence = mean(answers.map((answer) => answer.confidence));
    const range = exactExpectedRange(expected, levels);
    const target = Array.from({ length: levels }, (_, index) => index >= range[0] && index <= range[1] ? 1 / (range[1] - range[0] + 1) : 0);
    const predicted = Array.from({ length: levels }, (_, index) => probabilities[String(index)] ?? probabilities[criteria[index]] ?? 0);
    let pc = 0; let qc = 0; let rps = 0;
    for (let index = 0; index < levels - 1; index += 1) { pc += predicted[index]; qc += target[index]; rps += (pc - qc) ** 2; }
    const predictedLevel = Math.max(0, Math.min(levels - 1, Math.round(score)));
    const correct = predictedLevel >= range[0] && predictedLevel <= range[1];
    return { correct, accepted: answers.length === 3 && answers.every((answer) => answer.confidence >= uncertainty.score_min_confidence), stable: answers.length === 3 && new Set(answers.map((answer) => Math.round(answer.score))).size === 1, calibration_confidence: Math.max(...predicted), mae: score < range[0] ? range[0] - score : score > range[1] ? score - range[1] : 0, rps: rps / (levels - 1) };
  });
  return finishMetrics(cases, { mean_absolute_error: mean(cases.map((item) => item.mae)), ranked_probability_score: mean(cases.map((item) => item.rps)) });
}

function metricPass(type, metrics) {
  const base = metrics.accuracy >= 0.8 && metrics.accepted_accuracy >= 0.9 && metrics.accepted_coverage >= 0.5 && metrics.stability >= 0.9;
  if (type === "choice") return base && metrics.expected_calibration_error <= 0.2 && metrics.brier_score <= 0.35;
  if (type === "noul") return base && metrics.expected_calibration_error <= 0.2 && metrics.brier_score <= 0.2;
  return base && metrics.mean_absolute_error <= 0.5 && metrics.ranked_probability_score <= 0.2;
}

function summarizeStatic(profile, semantic, observations) {
  const metrics = {};
  for (const [id, question] of Object.entries(profile.questions)) {
    const expected = new Map(semantic.map((item) => [item.id, item.expected[id]]));
    metrics[id] = question.type === "choice" ? choiceMetrics(id, expected, observations, profile.uncertainty) : question.type === "noul" ? noulMetrics(id, expected, observations, profile.uncertainty) : scoreMetrics(id, expected, observations, profile.uncertainty, question.criteria);
    metrics[id].passed = metricPass(question.type, metrics[id]);
  }
  return metrics;
}

function summarizeSkill(semantic, observations) {
  const positives = semantic.filter((item) => item.expected_selected !== null);
  const noMatch = semantic.filter((item) => item.expected_selected === null);
  const caseRows = semantic.map((item) => {
    const rows = observations.filter((row) => row.id === item.id);
    const correctRows = rows.filter((row) => item.expected_selected === null ? row.selected === null && row.outcome === "no_match" : row.selected === item.expected_selected);
    const acceptedOutcome = item.expected_selected === null ? "no_match" : "accepted";
    return { item, rows, correct: correctRows.length === 3, accepted: rows.length === 3 && rows.every((row) => row.outcome === acceptedOutcome && !row.error_code), stable: rows.length === 3 && new Set(rows.map((row) => row.selected)).size === 1 };
  });
  const positiveRows = caseRows.filter(({ item }) => item.expected_selected !== null);
  const shortlistRecall = mean(positiveRows.map(({ item, rows }) => rows.length === 3 && rows.every((row) => row.shortlist.includes(item.expected_selected)) ? 1 : 0));
  const noMatchAccuracy = mean(caseRows.filter(({ item }) => item.expected_selected === null).map(({ correct }) => correct ? 1 : 0));
  const accepted = caseRows.filter((row) => row.accepted);
  return { expected_skill_cases: positives.length, no_match_cases: noMatch.length, shortlist_recall: shortlistRecall, accuracy: mean(caseRows.map((row) => row.correct ? 1 : 0)), accepted_accuracy: accepted.length ? mean(accepted.map((row) => row.correct ? 1 : 0)) : 0, accepted_coverage: accepted.length / caseRows.length, stability: mean(caseRows.map((row) => row.stable ? 1 : 0)), no_match_accuracy: noMatchAccuracy, passed: shortlistRecall === 1 && noMatchAccuracy === 1 && mean(caseRows.map((row) => row.correct ? 1 : 0)) >= 0.8 && (accepted.length ? mean(accepted.map((row) => row.correct ? 1 : 0)) : 0) >= 0.9 && accepted.length / caseRows.length >= 0.5 && mean(caseRows.map((row) => row.stable ? 1 : 0)) >= 0.9 };
}

function summarizeSkillProfile(profile, semantic, observations) {
  const stageOne = observations.map((row) => ({ id: row.id, error_code: row.error_code, answers: row.stages?.[0]?.answers || {} }));
  const candidateExpected = new Map(semantic.map((item) => [item.id, item.expected_selected || "none"]));
  const needsSkillExpected = new Map(semantic.map((item) => [item.id, item.expected_selected !== null]));
  const candidate = choiceMetrics("candidate", candidateExpected, stageOne, profile.uncertainty);
  const needsSkill = noulMetrics("needs_skill", needsSkillExpected, stageOne, profile.uncertainty);
  candidate.passed = metricPass("choice", candidate);
  needsSkill.passed = metricPass("noul", needsSkill);
  return { candidate, needs_skill: needsSkill, final: summarizeSkill(semantic, observations) };
}

function safetyPass(profileId, profile, semantic, observations) {
  return semantic.filter((item) => item.safety).every((item) => observations.filter((row) => row.id === item.id).every((row) => {
    if (row.error_code || row.outcome !== "accepted") return false;
    if (profileId === "skill-suggestion") return row.selected === item.expected_selected;
    return Object.entries(item.expected).every(([id, expected]) => {
      const decision = row.decisions[id];
      if (decision?.status !== "accepted") return false;
      if (profile.questions[id].type !== "score") return decision.value === expected;
      const predictedLevel = Math.round(decision.value);
      const range = Number.isInteger(expected) ? [expected, expected] : expected;
      return predictedLevel >= range[0] && predictedLevel <= range[1];
    });
  }));
}

function sourceFingerprints() {
  return Object.fromEntries(SOURCE_PATHS.map((path) => [path, fingerprint(readFileSync(join(ROOT, path), "utf8"))]));
}

function observationTotals(observations) {
  const inputTokens = observations.reduce((sum, item) => sum + (item.usage?.input_tokens || item.stages?.reduce((nested, stage) => nested + (stage.usage?.input_tokens || 0), 0) || 0), 0);
  const outputTokens = observations.reduce((sum, item) => sum + (item.usage?.output_tokens || item.stages?.reduce((nested, stage) => nested + (stage.usage?.output_tokens || 0), 0) || 0), 0);
  const errors = observations.filter((item) => item.error_code).length;
  return {
    provider_errors: errors,
    provider_error_rate: observations.length ? errors / observations.length : 0,
    attempts: observations.reduce((sum, item) => sum + (item.stages?.length || 1), 0),
    input_tokens: inputTokens,
    output_tokens: outputTokens,
    input_cost_usd: inputTokens * PRICE_PER_MTOK / 1_000_000,
    latency_mean_ms: mean(observations.map((item) => item.latency_ms)),
    latency_p95_ms: percentile(observations.map((item) => item.latency_ms), 0.95),
  };
}

function hasCompleteObservationGrid(semantic, observations) {
  const expected = new Set(semantic.flatMap((item) => [1, 2, 3].map((run) => `${item.id}:${run}`)));
  const actual = observations.map((item) => `${item.id}:${item.run}`);
  return actual.length === expected.size && new Set(actual).size === expected.size && actual.every((key) => expected.has(key));
}

export function calibrationIdentity(profileId, corpus, policy = loadSemanticProfilePolicy()) {
  const extra = profileId === "skill-suggestion" ? { catalog: loadSkillSuggestionCatalog() } : profileId === "claim-evidence" ? { checker: fingerprint(readFileSync(join(ROOT, "scripts/claim-evidence-check"), "utf8")) } : {};
  return { profile_id: profileId, policy_version: policy.policy_version, model: policy.model, policy_fingerprint: fingerprint(policy.profiles[profileId]), corpus_fingerprint: fingerprint(corpus), source_fingerprints: sourceFingerprints(), extra_fingerprint: fingerprint(extra) };
}

function validateCollectionIdentity(identity, profileId, corpus, policy) {
  const current = calibrationIdentity(profileId, corpus, policy);
  for (const key of ["profile_id", "policy_version", "model", "policy_fingerprint", "corpus_fingerprint", "extra_fingerprint"]) if (identity?.[key] !== current[key]) throw new Error(`calibration collection identity mismatch ${profileId}`);
  if (!plainObject(identity.source_fingerprints) || !Object.keys(identity.source_fingerprints).length) throw new Error(`calibration collection source identity missing ${profileId}`);
  return identity;
}

export function createBudget({ maxAttempts = 600, maxInputTokens = 1_500_000, maxSeconds = 1500, startedAt = Date.now(), initial = {}, transport = evaluateTypeSafe } = {}) {
  const budget = {
    attempts: initial.attempts || 0,
    input_tokens: initial.input_tokens || 0,
    output_tokens: initial.output_tokens || 0,
    maxAttempts,
    maxInputTokens,
    started_at: initial.started_at || startedAt,
    deadline: initial.deadline || startedAt + maxSeconds * 1000,
    onReservation() {},
    async provider(request, options = {}) {
      const remainingMs = budget.deadline - Date.now();
      if (budget.attempts + 1 > maxAttempts) throw Object.assign(new Error("calibration_attempt_budget"), { code: "calibration_attempt_budget" });
      if (budget.input_tokens + REQUEST_RESERVATION > maxInputTokens) throw Object.assign(new Error("calibration_token_budget"), { code: "calibration_token_budget" });
      if (remainingMs <= 0) throw Object.assign(new Error("calibration_deadline"), { code: "calibration_deadline" });
      budget.attempts += 1;
      budget.input_tokens += REQUEST_RESERVATION;
      budget.onReservation();
      const response = await transport(request, { ...options, maxRetries: 0, timeoutMs: Math.max(1, Math.min(options.timeoutMs || remainingMs, remainingMs)) });
      if (!Number.isInteger(response.usage?.input_tokens) || response.usage.input_tokens < 0 || !Number.isInteger(response.usage?.output_tokens) || response.usage.output_tokens < 0) throw Object.assign(new Error("calibration_usage_missing"), { code: "calibration_usage_missing" });
      budget.input_tokens += response.usage.input_tokens - REQUEST_RESERVATION;
      budget.output_tokens += response.usage.output_tokens;
      if (response.usage.input_tokens > REQUEST_RESERVATION || budget.input_tokens > maxInputTokens) throw Object.assign(new Error("calibration_reported_usage_exceeded_reservation"), { code: "calibration_reported_usage_exceeded_reservation" });
      return response;
    },
  };
  return budget;
}

function claimState(item) {
  const root = mkdtempSync(join(tmpdir(), "etabli-calibration-claim-"));
  const evidence = join(root, "evidence.txt");
  const claims = join(root, "claims.md");
  writeFileSync(evidence, item.state.evidence || "evidence", { mode: 0o600 });
  const pointer = item.state.missing_pointer ? join(root, "missing.txt") : evidence;
  writeFileSync(claims, `| Claim | Evidence | Status |\n| --- | --- | --- |\n| ${item.state.claim || "Claim"} | ${pointer} | verified |\n`, { mode: 0o600 });
  try { return prepareClaimEvidenceState({ claimsFile: claims, claimIndex: 0, cwd: root }); }
  finally { rmSync(root, { recursive: true, force: true }); }
}

async function evaluateCase(profileId, item, policy, provider) {
  if (profileId === "skill-suggestion") {
    const result = await suggestSkill({ prompt: item.prompt, policy, provider, allowProviderEgress: true, persistReceipt: false });
    return { selected: result.selected, shortlist: result.shortlist, outcome: result.outcome, error_code: result.stages.find((stage) => stage.error_code)?.error_code || null, stages: result.stages.map((stage) => ({ answers: stage.answers, decisions: stage.decisions, outcome: stage.outcome, usage: stage.receipt?.usage || null, latency_ms: stage.receipt?.latency_ms || 0, model: stage.receipt?.model || null, question_fingerprint: stage.receipt?.question_fingerprint || null, state_fingerprint: stage.receipt?.state_fingerprint || null })) };
  }
  const state = profileId === "claim-evidence" ? claimState(item) : item.state;
  const result = await evaluateSemanticProfile({ profileId, state, policy, provider, allowProviderEgress: true, persistReceipt: false });
  return { answers: result.answers, decisions: result.decisions, outcome: result.outcome, error_code: result.error_code, latency_ms: result.receipt.latency_ms, usage: result.receipt.usage, model: result.receipt.model, question_fingerprint: result.receipt.question_fingerprint, state_fingerprint: result.receipt.state_fingerprint };
}

function atomicJson(path, value) {
  const target = resolve(path);
  const parent = dirname(target);
  const relativeParent = relative(ROOT, parent);
  if (relativeParent === ".." || relativeParent.startsWith(`..${sep}`)) throw new Error("calibration output escapes repository");
  let current = ROOT;
  for (const part of relativeParent.split(sep).filter(Boolean)) {
    current = join(current, part);
    try {
      const stat = lstatSync(current);
      if (stat.isSymbolicLink() || !stat.isDirectory()) throw new Error("unsafe calibration output directory");
    } catch (error) {
      if (error?.code !== "ENOENT") throw error;
      mkdirSync(current, { mode: 0o700 });
    }
  }
  try {
    const stat = lstatSync(target);
    if (stat.isSymbolicLink() || !stat.isFile()) throw new Error("unsafe calibration output file");
  } catch (error) {
    if (error?.code !== "ENOENT") throw error;
  }
  const temp = `${target}.tmp-${process.pid}`;
  let fd;
  try { fd = openSync(temp, constants.O_WRONLY | constants.O_CREAT | constants.O_EXCL | constants.O_NOFOLLOW, 0o600); writeSync(fd, `${JSON.stringify(value, null, 2)}\n`); }
  finally { if (fd !== undefined) closeSync(fd); }
  renameSync(temp, target);
}

export function writeCalibrationManifest(path, manifest) {
  atomicJson(path, manifest);
}

export function checkpointMatchesCampaign(checkpoint, campaignId) {
  return plainObject(checkpoint) && typeof campaignId === "string" && campaignId.length > 0 && checkpoint.campaign_id === campaignId;
}

export function calibrationCampaignDescriptor(campaign) {
  if (!plainObject(campaign) || typeof campaign.campaign_id !== "string" || !campaign.campaign_id || !Array.isArray(campaign.profile_ids) || !plainObject(campaign.limits) || !Number.isInteger(campaign.started_at) || !Number.isInteger(campaign.deadline)) throw new Error("invalid calibration campaign");
  const contract = { profile_ids: campaign.profile_ids, repetitions: campaign.repetitions, limits: campaign.limits, started_at: campaign.started_at, deadline: campaign.deadline };
  return { campaign_id: campaign.campaign_id, campaign_contract_fingerprint: fingerprint(contract) };
}

export async function runProfileCalibration({ profileId, repetitions = 3, budget, checkpointPath, campaign, resume = false, policy = loadSemanticProfilePolicy() }) {
  if (repetitions !== 3) throw new Error("calibration requires exactly three repetitions");
  const campaignDescriptor = calibrationCampaignDescriptor(campaign);
  const campaignId = campaignDescriptor.campaign_id;
  const { corpus, profile, semantic, preflight } = loadCalibrationCorpus(profileId, policy);
  const identity = calibrationIdentity(profileId, corpus, policy);
  let observations = [];
  let interrupted = null;
  if (resume && checkpointPath) {
    try { const saved = readRegularJson(checkpointPath); if (checkpointMatchesCampaign(saved, campaignId)) { if (stableJson(saved.identity) !== stableJson(identity)) throw new Error("calibration checkpoint fingerprint mismatch"); observations = saved.observations || []; interrupted = saved.pending || null; } }
    catch (error) { if (error?.code !== "ENOENT") throw error; }
  }
  if (interrupted && semantic.some((item) => item.id === interrupted.id) && [1, 2, 3].includes(interrupted.run) && !observations.some((item) => item.id === interrupted.id && item.run === interrupted.run)) {
    const source = semantic.find((item) => item.id === interrupted.id);
    observations.push({ id: interrupted.id, run: interrupted.run, safety: source?.safety === true, latency_ms: 0, error_code: "interrupted_after_reservation", ...(profileId === "skill-suggestion" ? { selected: null, shortlist: [], outcome: "abstain", stages: [] } : { answers: {}, decisions: {}, outcome: "abstain", model: null, question_fingerprint: null, state_fingerprint: null }) });
  }
  const persist = (pending = null) => {
    if (checkpointPath) atomicJson(checkpointPath, { schema_version: 1, campaign_id: campaignId, identity, budget: { attempts: budget.attempts, input_tokens: budget.input_tokens, output_tokens: budget.output_tokens, started_at: budget.started_at, deadline: budget.deadline }, pending, observations });
  };
  budget.onReservation = () => {};
  const seen = new Set(observations.map((item) => `${item.id}:${item.run}`));
  const preflightResults = [];
  for (const item of preflight) {
    const attempts = budget.attempts;
    let errorCode = null;
    try { const result = await evaluateCase(profileId, item, policy, budget.provider); errorCode = result.error_code; } catch (error) { errorCode = String(error?.message || error); }
    if (budget.attempts !== attempts || !String(errorCode).includes(item.expected_error)) throw new Error(`preflight failed ${item.id}`);
    preflightResults.push({ id: item.id, error_code: errorCode, provider_attempts: 0, passed: true });
  }
  for (let run = 1; run <= repetitions; run += 1) for (const item of semantic) {
    if (seen.has(`${item.id}:${run}`)) continue;
    const started = Date.now();
    budget.onReservation = () => persist({ id: item.id, run });
    const result = await evaluateCase(profileId, item, policy, budget.provider);
    const row = { id: item.id, run, safety: item.safety === true, latency_ms: Date.now() - started, ...result };
    observations.push(row);
    persist();
  }
  const metrics = profileId === "skill-suggestion" ? summarizeSkillProfile(profile, semantic, observations) : summarizeStatic(profile, semantic, observations);
  const safetyPassed = safetyPass(profileId, profile, semantic, observations);
  const errors = observations.filter((item) => item.error_code).length;
  const complete = hasCompleteObservationGrid(semantic, observations);
  const passed = Object.values(metrics).every((item) => item.passed) && safetyPassed;
  const verdict = !complete || errors ? "inconclusive" : passed ? "passes_current_thresholds" : "needs_tuning";
  return { schema_version: 1, evidence_kind: "live_typesafe_profile_calibration", generated_at: new Date().toISOString(), provider_observations_live: true, corpus_kind: "synthetic_sanitized", synthetic: true, collection_provenance: "complete", collection_identity: identity, recompute_identity: identity, ...campaignDescriptor, repetitions, thresholds: profile.uncertainty, verdict, complete, safety_passed: safetyPassed, metrics, preflight_results: preflightResults, operational: { ...observationTotals(observations), campaign_attempts: budget.attempts, campaign_input_tokens: budget.input_tokens, campaign_input_cost_usd: budget.input_tokens * PRICE_PER_MTOK / 1_000_000 }, observations };
}

export function writeCalibrationReport(profileId, report, reportDir = REPORT_DIR) {
  atomicJson(join(reportDir, `${profileId}.json`), report);
}

export function writeCalibrationSummary(reports, campaign, reportDir = REPORT_DIR) {
  if (!reports.length || typeof campaign?.campaign_id !== "string" || reports.some((report) => report.campaign_id !== campaign.campaign_id || report.campaign_contract_fingerprint !== reports[0].campaign_contract_fingerprint)) throw new Error("calibration summary campaign mismatch");
  atomicJson(join(reportDir, "summary.json"), {
    schema_version: 1,
    evidence_kind: "live_typesafe_profile_calibration_summary",
    generated_at: new Date().toISOString(),
    bundle_promotion_verdict: null,
    note: "Profiles are evaluated independently; this summary does not promote authority or thresholds.",
    campaign_id: reports[0].campaign_id,
    campaign_contract_fingerprint: reports[0].campaign_contract_fingerprint,
    campaign,
    profiles: reports.map((report) => ({ profile_id: report.collection_identity.profile_id, verdict: report.verdict, safety_passed: report.safety_passed, metrics_fingerprint: fingerprint(report.metrics), report_fingerprint: fingerprint(report) })),
  });
}

export function recomputeCalibrationReport(profileId, reportDir = REPORT_DIR, policy = loadSemanticProfilePolicy(), campaign, allowLegacyMigration = false, legacyCollectionIdentity = null) {
  const path = join(reportDir, `${profileId}.json`);
  const report = readRegularJson(path);
  const { corpus, profile, semantic } = loadCalibrationCorpus(profileId, policy);
  const campaignDescriptor = calibrationCampaignDescriptor(campaign);
  if (!allowLegacyMigration && (report.campaign_id !== campaignDescriptor.campaign_id || report.campaign_contract_fingerprint !== campaignDescriptor.campaign_contract_fingerprint)) throw new Error(`calibration report campaign mismatch ${profileId}`);
  const collectionIdentity = validateCollectionIdentity(allowLegacyMigration ? legacyCollectionIdentity : report.collection_identity, profileId, corpus, policy);
  if (!Array.isArray(report.observations) || !hasCompleteObservationGrid(semantic, report.observations)) throw new Error(`incomplete calibration observations ${profileId}`);
  const metrics = profileId === "skill-suggestion" ? summarizeSkillProfile(profile, semantic, report.observations) : summarizeStatic(profile, semantic, report.observations);
  const safetyPassed = safetyPass(profileId, profile, semantic, report.observations);
  const errors = report.observations.filter((item) => item.error_code).length;
  const passed = Object.values(metrics).every((item) => item.passed) && safetyPassed;
  const operational = { ...report.operational, ...observationTotals(report.observations) };
  const { identity: _legacyIdentity, ...reportWithoutLegacyIdentity } = report;
  const updated = { ...reportWithoutLegacyIdentity, recomputed_at: new Date().toISOString(), provider_observations_live: true, corpus_kind: "synthetic_sanitized", synthetic: true, collection_provenance: allowLegacyMigration ? "legacy_cli_fingerprint_unavailable" : report.collection_provenance, collection_identity: collectionIdentity, recompute_identity: calibrationIdentity(profileId, corpus, policy), ...campaignDescriptor, metrics, safety_passed: safetyPassed, operational, verdict: errors ? "inconclusive" : passed ? "passes_current_thresholds" : "needs_tuning" };
  writeCalibrationReport(profileId, updated, reportDir);
  return updated;
}

export function verifyCalibrationReport(profileId, reportDir = REPORT_DIR, policy = loadSemanticProfilePolicy(), campaign) {
  const report = readRegularJson(join(reportDir, `${profileId}.json`));
  const { corpus, profile, semantic, preflight } = loadCalibrationCorpus(profileId, policy);
  const campaignDescriptor = calibrationCampaignDescriptor(campaign);
  if (report.campaign_id !== campaignDescriptor.campaign_id || report.campaign_contract_fingerprint !== campaignDescriptor.campaign_contract_fingerprint) throw new Error(`calibration report campaign mismatch ${profileId}`);
  validateCollectionIdentity(report.collection_identity, profileId, corpus, policy);
  if (stableJson(report.recompute_identity) !== stableJson(calibrationIdentity(profileId, corpus, policy))) throw new Error(`calibration recompute fingerprint mismatch ${profileId}`);
  if (!["complete", "legacy_cli_fingerprint_unavailable"].includes(report.collection_provenance)) throw new Error(`calibration collection provenance missing ${profileId}`);
  if (report.provider_observations_live !== true || report.corpus_kind !== "synthetic_sanitized" || report.synthetic !== true || report.repetitions !== 3 || report.complete !== true || !hasCompleteObservationGrid(semantic, report.observations) || !["passes_current_thresholds", "needs_tuning", "inconclusive"].includes(report.verdict)) throw new Error(`invalid calibration report ${profileId}`);
  if (report.observations.some((item) => item.model && item.model !== policy.model || item.stages?.some((stage) => stage.model !== policy.model || !stage.question_fingerprint || !stage.state_fingerprint) || !item.error_code && !item.stages && (!item.question_fingerprint || !item.state_fingerprint))) throw new Error(`calibration observation identity mismatch ${profileId}`);
  const metrics = profileId === "skill-suggestion" ? summarizeSkillProfile(profile, semantic, report.observations) : summarizeStatic(profile, semantic, report.observations);
  if (stableJson(metrics) !== stableJson(report.metrics)) throw new Error(`calibration metrics mismatch ${profileId}`);
  const expectedSafety = safetyPass(profileId, profile, semantic, report.observations);
  const providerErrors = report.observations.filter((item) => item.error_code).length;
  const expectedVerdict = providerErrors ? "inconclusive" : Object.values(metrics).every((item) => item.passed) && expectedSafety ? "passes_current_thresholds" : "needs_tuning";
  if (report.safety_passed !== expectedSafety || report.verdict !== expectedVerdict) throw new Error(`calibration verdict mismatch ${profileId}`);
  const preflightById = new Map(preflight.map((item) => [item.id, item]));
  if ((report.preflight_results || []).length !== preflight.length || (report.preflight_results || []).some((item) => item.provider_attempts !== 0 || item.passed !== true || !String(item.error_code).includes(preflightById.get(item.id)?.expected_error || "__missing__"))) throw new Error(`calibration preflight mismatch ${profileId}`);
  const expectedOperational = observationTotals(report.observations);
  if (Object.entries(expectedOperational).some(([key, value]) => report.operational?.[key] !== value)) throw new Error(`calibration operational mismatch ${profileId}`);
  return report;
}

export const calibrationMetricsForTesting = { choiceMetrics, noulMetrics, scoreMetrics, summarizeSkill };

export function calibrationProfileIds(policy = loadSemanticProfilePolicy()) {
  return Object.keys(policy.profiles);
}
