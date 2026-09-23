const PROFILE_ID = "self-improvement-diagnosis";
const COUNTER_FIELDS = ["tool_calls", "tool_errors", "validation_failures", "review_rework", "plan_rework", "compactions", "retries"];
const PATTERN_TARGETS = Object.freeze({
  no_material_friction: "no_change",
  execution_reliability: "tool_contract",
  verification_gap: "validation_strategy",
  review_feedback_loop: "review_contract",
  planning_feedback_loop: "planning_contract",
  context_saturation: "context_design",
  mixed_or_ambiguous: "needs_investigation",
});
const PATTERNS = new Set(Object.keys(PATTERN_TARGETS));
const OBSERVATION_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function plainObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function counter(value, nullable = false) {
  if (value === null && nullable) return "null";
  if (!Number.isInteger(value) || value < 0 || value > 20_000) throw new Error("diagnosis observation counter invalid");
  return String(value);
}

export function prepareSelfImprovementDiagnosisState(observation) {
  if (!plainObject(observation) || observation.schema_version !== 1 || observation.capability !== "prototype_offline") throw new Error("diagnosis observation unsupported");
  if (!["pi", "claude"].includes(observation.adapter) || observation.adapter_version !== "prototype-offline-1" || !["explicit_unverified", "native_correlated"].includes(observation.binding) || observation.adapter === "claude" && observation.binding !== "explicit_unverified" || !OBSERVATION_ID.test(observation.observation_id || "")) throw new Error("diagnosis observation identity invalid");
  if (observation.completeness !== "complete" || !plainObject(observation.lifecycle) || observation.lifecycle.terminal !== true || !["completed", "blocked"].includes(observation.lifecycle.outcome)) throw new Error("diagnosis observation ineligible");
  if (!Array.isArray(observation.reason_codes) || observation.reason_codes.length !== 0 || !plainObject(observation.signals) || observation.signals.unsupported_rows !== 0 || typeof observation.signals.verifier !== "boolean") throw new Error("diagnosis observation signals invalid");
  const values = COUNTER_FIELDS.map((field) => {
    const nullable = field === "retries" || (field === "compactions" && observation.adapter === "claude");
    if (field === "retries" && observation.signals[field] !== null) throw new Error("diagnosis observation counter invalid");
    if (field === "compactions" && observation.adapter === "claude" && observation.signals[field] !== null) throw new Error("diagnosis observation counter invalid");
    return `${field}=${counter(observation.signals[field], nullable)}`;
  });
  if (observation.signals.tool_errors > observation.signals.tool_calls) throw new Error("diagnosis observation counter invalid");
  return {
    episode: `schema=1;completeness=complete;terminal=${observation.lifecycle.outcome};verifier=${observation.signals.verifier}`,
    signals: values.join(";"),
  };
}

function acceptedValue(decisions, field, allowlist) {
  const decision = decisions?.[field];
  return decision?.status === "accepted" && allowlist.has(decision.value) ? decision.value : null;
}

function provenance(receipt) {
  if (!receipt) return null;
  return {
    provider: receipt.provider,
    model: receipt.model,
    policy_version: receipt.policy_version,
    catalog_version: receipt.catalog_version,
    state_fingerprint: receipt.state_fingerprint,
    question_fingerprint: receipt.question_fingerprint,
  };
}

function noDiagnosis(result, reason) {
  return {
    schema_version: 1,
    profile_id: PROFILE_ID,
    authority: "diagnostic",
    status: "abstain",
    diagnosis: null,
    provenance: provenance(result?.receipt),
    reason,
  };
}

function derivedFollowUp(pattern, episode) {
  const settledClean = pattern === "no_material_friction" && episode?.terminal === "completed" && episode?.verifier === true;
  if (settledClean) return { target: "no_change", actionability: "no_op" };
  if (pattern === "no_material_friction") return { target: "needs_investigation", actionability: "investigate" };
  return { target: PATTERN_TARGETS[pattern], actionability: "investigate" };
}

export function reduceSelfImprovementDiagnosis(result, episode) {
  if (!result || result.profile !== PROFILE_ID || result.authority !== "diagnostic" || result.outcome !== "accepted") return noDiagnosis(result, result?.error_code || result?.outcome || "diagnosis_unavailable");
  const pattern = acceptedValue(result.decisions, "pattern", PATTERNS);
  if (!pattern || !result.receipt) return noDiagnosis(result, "diagnosis_incomplete");
  return {
    schema_version: 1,
    profile_id: PROFILE_ID,
    authority: "diagnostic",
    status: "diagnosed",
    diagnosis: { pattern, ...derivedFollowUp(pattern, episode) },
    provenance: provenance(result.receipt),
  };
}

export function rejectedSelfImprovementDiagnosis(error) {
  return noDiagnosis(null, String(error?.message || "diagnosis_observation_invalid").replace(/[^a-z0-9_-]+/gi, "_").toLowerCase());
}
