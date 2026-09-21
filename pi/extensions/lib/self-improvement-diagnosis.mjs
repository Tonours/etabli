const PROFILE_ID = "self-improvement-diagnosis";
const COUNTER_FIELDS = ["tool_calls", "tool_errors", "validation_failures", "review_rework", "plan_rework", "compactions", "retries"];
const PATTERNS = new Set(["no_material_friction", "execution_reliability", "verification_gap", "review_feedback_loop", "planning_feedback_loop", "context_saturation", "mixed_or_ambiguous"]);
const TARGETS = new Set(["no_change", "tool_contract", "validation_strategy", "review_contract", "planning_contract", "context_design", "needs_investigation"]);
const ACTIONABILITY = new Set(["no_op", "investigate", "candidate"]);
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

function coherentDiagnosis(pattern, target, actionability) {
  const isNoChange = pattern === "no_material_friction" || target === "no_change" || actionability === "no_op";
  return !isNoChange || (pattern === "no_material_friction" && target === "no_change" && actionability === "no_op");
}

export function reduceSelfImprovementDiagnosis(result) {
  if (!result || result.profile !== PROFILE_ID || result.authority !== "diagnostic" || result.outcome !== "accepted") return noDiagnosis(result, result?.error_code || result?.outcome || "diagnosis_unavailable");
  const pattern = acceptedValue(result.decisions, "pattern", PATTERNS);
  const target = acceptedValue(result.decisions, "target", TARGETS);
  const actionability = acceptedValue(result.decisions, "actionability", ACTIONABILITY);
  if (!pattern || !target || !actionability || !result.receipt) return noDiagnosis(result, "diagnosis_incomplete");
  if (!coherentDiagnosis(pattern, target, actionability)) return noDiagnosis(result, "diagnosis_incoherent");
  return {
    schema_version: 1,
    profile_id: PROFILE_ID,
    authority: "diagnostic",
    status: "diagnosed",
    diagnosis: { pattern, target, actionability },
    provenance: provenance(result.receipt),
  };
}

export function rejectedSelfImprovementDiagnosis(error) {
  return noDiagnosis(null, String(error?.message || "diagnosis_observation_invalid").replace(/[^a-z0-9_-]+/gi, "_").toLowerCase());
}
