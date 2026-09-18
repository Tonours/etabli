import { createHash } from "node:crypto";

export const QUESTION_TYPES = new Set(["choice", "noul", "score"]);

export function stableJson(value) {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(",")}]`;
  if (value && typeof value === "object") return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stableJson(value[key])}`).join(",")}}`;
  return JSON.stringify(value);
}

export function fingerprint(value) {
  return createHash("sha256").update(stableJson(value)).digest("hex");
}

export function containsSecretLike(value) {
  const text = typeof value === "string" ? value : stableJson(value);
  return /(?:-----BEGIN [A-Z ]+PRIVATE KEY-----|["']?(?:api[_-]?key|access[_-]?token|client[_-]?secret|password)["']?\s*[:=]\s*["']?[^\s,"'}]+|["']?(?:proxy-)?authorization["']?\s*[:=]\s*["']?(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+|\b(?:sk|ghp|github_pat|xox[baprs])[-_][A-Za-z0-9_-]{12,})/i.test(text);
}

export function minimizeRouteState(prompt, maxChars = 1200) {
  const normalized = String(prompt).replace(/\s+/g, " ").trim();
  if (!normalized) throw new Error("empty state");
  if (containsSecretLike(normalized)) throw new Error("secret-like state rejected");
  return { user_intent: normalized.slice(0, maxChars) };
}

function finiteProbability(value) {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 && value <= 1;
}

function validateDistribution(value, expectedKeys = null) {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("invalid probabilities");
  const entries = Object.entries(value);
  if (entries.length === 0 || entries.some(([, probability]) => !finiteProbability(probability))) throw new Error("invalid probabilities");
  if (expectedKeys && (entries.length !== expectedKeys.length || expectedKeys.some((key) => !(key in value)))) throw new Error("probability keys mismatch");
  const sum = entries.reduce((total, [, probability]) => total + probability, 0);
  if (Math.abs(sum - 1) > 0.02) throw new Error("probabilities do not sum to one");
  return Object.fromEntries(entries);
}

export function validateJudgmentRequest(request) {
  if (!request || typeof request !== "object" || Array.isArray(request)) throw new Error("invalid request");
  if (!(typeof request.state === "string" || Array.isArray(request.state) || (request.state && typeof request.state === "object"))) throw new Error("invalid state");
  if (containsSecretLike(request.state) || containsSecretLike(request.questions)) throw new Error("secret-like request rejected");
  if (typeof request.model !== "string" || !/^jev-\d+\.\d+\.\d+$/.test(request.model)) throw new Error("model must be a pinned Jev version");
  if (!request.questions || typeof request.questions !== "object" || Array.isArray(request.questions) || Object.keys(request.questions).length === 0) throw new Error("questions required");
  for (const [id, question] of Object.entries(request.questions)) {
    if (!/^[a-z][a-z0-9_]{0,63}$/.test(id) || !question || typeof question !== "object" || !QUESTION_TYPES.has(question.type) || !question.instructions) throw new Error(`invalid question ${id}`);
    if (question.type === "choice" && (!question.criteria || Array.isArray(question.criteria) || Object.keys(question.criteria).length < 2)) throw new Error(`invalid choice ${id}`);
    if (question.type === "score" && (!Array.isArray(question.criteria) || question.criteria.length < 2 || question.criteria.length > 10)) throw new Error(`invalid score ${id}`);
  }
  return request;
}

export function validateJudgmentResponse(request, response) {
  if (!response || typeof response !== "object" || Array.isArray(response) || response.model !== request.model) throw new Error("unexpected response model");
  if (!response.answers || typeof response.answers !== "object" || Array.isArray(response.answers)) throw new Error("invalid answers");
  const answers = {};
  for (const [id, question] of Object.entries(request.questions)) {
    const answer = response.answers[id];
    if (!answer || answer.type !== question.type) throw new Error(`answer type mismatch ${id}`);
    if (question.type === "noul") {
      if (!finiteProbability(answer.noul)) throw new Error(`invalid noul ${id}`);
      answers[id] = { type: "noul", noul: answer.noul };
    } else if (question.type === "choice") {
      const options = Object.keys(question.criteria);
      if (!options.includes(answer.choice) || !finiteProbability(answer.confidence)) throw new Error(`invalid choice ${id}`);
      answers[id] = { type: "choice", choice: answer.choice, probabilities: validateDistribution(answer.probabilities, options), confidence: answer.confidence };
    } else {
      if (typeof answer.score !== "number" || answer.score < 0 || answer.score > question.criteria.length - 1 || !finiteProbability(answer.confidence)) throw new Error(`invalid score ${id}`);
      answers[id] = { type: "score", score: answer.score, probabilities: validateDistribution(answer.probabilities, question.criteria.map((_, index) => String(index))), confidence: answer.confidence, legend: answer.legend };
    }
  }
  const usage = response.usage;
  if (!usage || !Number.isInteger(usage.input_tokens) || usage.input_tokens < 0 || !Number.isInteger(usage.output_tokens) || usage.output_tokens < 0) throw new Error("invalid usage");
  return { model: response.model, answers, usage: { input_tokens: usage.input_tokens, output_tokens: usage.output_tokens } };
}

export function sanitizedReceipt({ provider, policyVersion, request, response = null, deterministicDecision, selectedDecision = deterministicDecision, selectionSource = "deterministic", selectionReason = null, latencyMs, outcome, errorCode = null }) {
  return {
    schema_version: 2,
    ts: new Date().toISOString(),
    provider,
    model: request.model,
    policy_version: policyVersion,
    state_fingerprint: fingerprint(request.state),
    question_fingerprint: fingerprint(request.questions),
    deterministic_decision: deterministicDecision,
    selected_decision: selectedDecision,
    selection_source: selectionSource,
    selection_reason: selectionReason,
    shadow_answer: response?.answers?.route ?? null,
    latency_ms: Math.max(0, Math.round(latencyMs)),
    usage: response?.usage ?? null,
    outcome,
    error_code: errorCode,
  };
}
