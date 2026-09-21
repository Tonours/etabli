import { createHash } from "node:crypto";
import { containsSecretLike, minimizeRouteState } from "./semantic-judgment.mjs";
import { evaluateTypeSafe } from "./typesafe-system-one.mjs";

const MODEL = "jev-1.13.0";
const POLICY_VERSION = "jev-route-capsule-v3";
const MAX_PROMPT_CHARS = 1200;
const MIN_CONFIDENCE = 0.7;

export const JEV_ROUTE_CAPSULE_METADATA = Object.freeze({
  schema_version: 1,
  model: MODEL,
  policy_version: POLICY_VERSION,
  max_prompt_chars: MAX_PROMPT_CHARS,
  min_confidence: MIN_CONFIDENCE,
  max_retries: 0,
  source_fingerprints: Object.freeze({
    "workflow/spec.md": "58a6007c23c0b267f79755a1d0732a7e38cc8f14a1f265eca8233c345cfcce85",
    "workflow/skills/implementation-loop.md": "6075140415cdb42ad87577a3f623724f274d78b6e659c8c825479c9654b0eeb6",
    "workflow/review-rubric.md": "612241cdcd72ecfc7cf208ca5a18763d2e8b2308693cba220233a623762716c4",
  }),
});

const CAPSULES = Object.freeze({
	plan_implementation: [
		"ETABLI_ROUTE_CAPSULE plan_implementation v1",
		"Run one governed lifecycle: inspect only the sources needed to create or update the single root PLAN.md, challenge it, and keep observed facts separate from assumptions.",
		"Do not implement while PLAN.md is DRAFT or CHALLENGED; implementation begins only after the actual root plan is READY and every deterministic permission and mutation gate allows it.",
		"After implementation, run the named checks, simplification, quality, cumulative review, adversary, archive, and root-plan cleanup required by the workflow contract.",
		"Jev supplies semantic guidance only; code retains authority over routing, READY state, permissions, protected actions, mutation, rollback, and completion.",
	].join("\n"),
  planning: [
    "ETABLI_ROUTE_CAPSULE planning v1",
    "Treat PLAN.md as the single planning artifact and inspect only the product sources needed to make it executable.",
    "Keep observed facts separate from assumptions; bind acceptance criteria to named checks, rollback, budgets, and stop conditions.",
    "Do not implement until the plan is READY, and do not reread routing or skill-selection documents already compiled into this capsule.",
  ].join("\n"),
  implementation: [
    "ETABLI_ROUTE_CAPSULE implementation v1",
    "Read the READY PLAN.md and the requested product files, then implement every accepted criterion in the smallest coherent diff.",
    "Preserve unrelated work, keep permission and safety gates deterministic, and validate the exact changed behavior before reporting completion.",
    "Do not reread routing or skill-selection documents already compiled into this capsule.",
  ].join("\n"),
  review: [
    "ETABLI_ROUTE_CAPSULE review v1",
    "Remain read-only. Inspect PLAN.md when present, the current diff, and the changed source and tests.",
    "Report only actionable correctness, regression, safety, or contract findings with exact evidence; hard-stop when isolation is unavailable.",
    "Do not reread routing or skill-selection documents already compiled into this capsule.",
  ].join("\n"),
});

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

export const JEV_ROUTE_CAPSULE_FINGERPRINTS = Object.freeze(
  Object.fromEntries(Object.entries(CAPSULES).map(([route, capsule]) => [route, sha256(capsule)])),
);

function requestFor(prompt) {
  return {
    model: MODEL,
    state: minimizeRouteState(prompt, MAX_PROMPT_CHARS),
    questions: {
      route: {
        type: "choice",
        instructions: "Select the single generic Etabli workflow route required by the user request. Distinguish a governed plan-and-implement lifecycle from plan-only work and implementation from an already READY plan. Choose other when none clearly applies.",
        criteria: {
		  plan_implementation: "Plan or challenge a change, wait for the actual root PLAN.md to become READY, then implement, validate, review, archive, and remove the root plan in one governed workflow.",
          planning: "Create or challenge a PLAN.md without implementation.",
          implementation: "Change code or configuration from an implementation-ready request or READY plan.",
          review: "Inspect an existing diff or change set without modifying it.",
          other: "Any answer, diagnosis, protected action, private inline benchmark, or ambiguous request outside those three routes.",
        },
      },
    },
  };
}

function abstention(reason, startedAt, response = null, calls = 1) {
  return Object.freeze({
    schema_version: 1,
    status: "abstained",
    reason,
    model: MODEL,
    route: null,
    confidence: response?.answers?.route?.confidence ?? null,
    capsule: null,
    capsule_fingerprint: null,
    source_fingerprints: JEV_ROUTE_CAPSULE_METADATA.source_fingerprints,
    usage: response?.usage ?? null,
    latency_ms: Date.now() - startedAt,
    calls,
    retries: 0,
  });
}

export async function preflightAndRenderRouteCapsule(prompt) {
  const startedAt = Date.now();
  const boundedPrompt = String(prompt ?? "");
  if (!boundedPrompt.trim()) return abstention("empty_prompt", startedAt, null, 0);
  if (containsSecretLike(boundedPrompt)) return abstention("secret_like_prompt", startedAt, null, 0);
  try {
    const response = await evaluateTypeSafe(requestFor(boundedPrompt), {
      maxRetries: 0,
      timeoutMs: 5000,
      maxResponseBytes: 64 * 1024,
    });
    const answer = response.answers.route;
    if (answer.choice === "other") return abstention("route_other", startedAt, response);
    if (!(answer.choice in CAPSULES)) return abstention("unknown_route", startedAt, response);
    if (answer.confidence < MIN_CONFIDENCE) return abstention("low_confidence", startedAt, response);
    const capsule = CAPSULES[answer.choice];
    return Object.freeze({
      schema_version: 1,
      status: "accepted",
      reason: null,
      model: MODEL,
      route: answer.choice,
      confidence: answer.confidence,
      capsule,
      capsule_fingerprint: JEV_ROUTE_CAPSULE_FINGERPRINTS[answer.choice],
      source_fingerprints: JEV_ROUTE_CAPSULE_METADATA.source_fingerprints,
      usage: response.usage,
      latency_ms: Date.now() - startedAt,
      calls: 1,
      retries: 0,
    });
  } catch (error) {
    return Object.freeze({
      ...abstention("provider_error", startedAt),
      status: "error",
      error_code: typeof error?.code === "string" ? error.code : "unknown_error",
    });
  }
}
