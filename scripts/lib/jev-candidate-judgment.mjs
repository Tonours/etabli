import { randomUUID } from "node:crypto";
import { performance } from "node:perf_hooks";
import { fingerprint, stableJson, validateJudgmentRequest, validateJudgmentResponse } from "../../pi/extensions/lib/semantic-judgment.mjs";
import { containsSensitiveProfileData, interpretProfileResponse, loadSemanticProfilePolicy } from "../../pi/extensions/lib/semantic-profiles.mjs";
import { isPreparedClaimEvidenceState } from "../../pi/extensions/lib/semantic-claim-evidence.mjs";
import { evaluateTypeSafe } from "../../pi/extensions/lib/typesafe-system-one.mjs";

const candidateShapes = {
  "reviewer-finding-v2": {profile:"reviewer-finding",fields:{snapshot_sha256:"string",findings:"array"},rows:"findings"},
  "review-spec-v1": {profile:"reviewer-finding",fields:{snapshot_sha256:"string",obligations:"array",evidence:"array"},rows:"obligations"},
  "review-group-v1": {profile:"reviewer-finding",fields:{pairs:"array"},rows:"pairs"},
  "review-evidence-v1": {profile:"reviewer-finding",fields:{purpose:"string",candidates:"array"},rows:"candidates"},
  "claim-evidence-v2": {profile:"claim-evidence",fields:{evidence:"object",claims:"array"},rows:"claims"},
};
const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
const pick = (value, keys) => {
  if (!object(value)) throw new Error("invalid_candidate_state");
  return Object.fromEntries(keys.filter(key=>Object.hasOwn(value,key)).map(key=>[key,value[key]]));
};
const evidenceFields=["id","path","start","end","text","file_sha256","excerpt_sha256"];
const findingFields=["id","claim","severity","path","line","snapshot_sha256","evidence_ids","trigger","consequence","correction"];
function projectCandidateState(version,state,shape) {
  if(!object(state))throw new Error("invalid_candidate_state");
  for(const [key,type] of Object.entries(shape.fields)) {
    const value=state[key];
    if(type==="string"?typeof value!=="string"||!value.trim():type==="array"?!Array.isArray(value):!object(value))
      throw new Error("invalid_candidate_state");
  }
  const rows=state[shape.rows];
  if(!rows.length||rows.some(row=>!object(row)))throw new Error("invalid_candidate_state");
  const projected=pick(state,Object.keys(shape.fields));
  if(version==="claim-evidence-v2") {
    if(!isPreparedClaimEvidenceState(state))throw new Error("unprepared_claim_batch");
    if(state.conclusion!==undefined)projected.conclusion=state.conclusion;
  } else if(version==="reviewer-finding-v2") {
    projected.findings=rows.map(row=>{
      if(typeof row.claim!=="string"||!row.claim.trim()||!Array.isArray(row.deciding_code))throw new Error("invalid_candidate_state");
      return {...pick(row,findingFields),deciding_code:row.deciding_code.map(item=>pick(item,evidenceFields))};
    });
  } else if(version==="review-spec-v1") {
    projected.obligations=rows.map(row=>pick(row,["id","text","source","evidence_ids"]));
    projected.evidence=state.evidence.map(row=>pick(row,evidenceFields));
  } else if(version==="review-group-v1") {
    projected.pairs=rows.map(row=>({id:row.id,left:pick(row.left,findingFields),right:pick(row.right,findingFields)}));
  } else projected.candidates=rows.map(row=>pick(row,evidenceFields));
  return projected;
}

// Candidate-only typed judgments. No policy mutation, implicit egress or verdict authority.
export async function candidateJudgment({ version, state, questions, provider = evaluateTypeSafe, allowProviderEgress = false, transport = {} }) {
  const policy = loadSemanticProfilePolicy(), requestId = randomUUID(), started = performance.now();
  let response = null, decisions = null, error = null;
  const attempts = [];
  const shape=candidateShapes[version];
  const profile=shape?{...policy.profiles[shape.profile],questions}:null;
  let maxStateChars=null;
  try {
    if(!profile)throw new Error("unknown_candidate_version");
    if (containsSensitiveProfileData({ state, questions })) throw new Error("sensitive_candidate_input");
    const projectedState=projectCandidateState(version,state,shape);
    maxStateChars=Math.min(96_000,profile.max_state_chars * state[shape.rows].length);
    if(stableJson(state).length>maxStateChars || Buffer.byteLength(stableJson(state))>96_000)throw new Error("candidate_state_too_large");
    if(stableJson(questions).length>32_000)throw new Error("candidate_questions_too_large");
    const request = validateJudgmentRequest({ model: policy.model, state:projectedState, questions });
    if (!allowProviderEgress) throw new Error("provider_egress_not_allowed");
    const received = await provider(request, {
      timeoutMs: policy.timeout_ms, maxRetries: policy.max_retries,
      totalTimeoutMs: transport.totalTimeoutMs ?? policy.timeout_ms * (policy.max_retries + 1) + 5000 * policy.max_retries,
      ...(transport.timeoutMs === undefined ? {} : {timeoutMs: transport.timeoutMs}),
      ...(transport.maxRetries === undefined ? {} : {maxRetries: transport.maxRetries}),
      onAttempt: (event) => attempts.push(event),
    });
    if (!received?.answers || Object.keys(received.answers).sort().join(",") !== Object.keys(questions).sort().join(",")) throw new Error("candidate_answer_binding_mismatch");
    response = validateJudgmentResponse(request, received);
    decisions = interpretProfileResponse(profile, response);
  } catch (failure) {
    const known = new Set(["provider_egress_not_allowed", "sensitive_candidate_input", "candidate_state_too_large", "candidate_questions_too_large", "invalid_candidate_state", "unprepared_claim_batch", "unknown_candidate_version", "missing_api_key", "timeout", "total_timeout", "aborted"]);
    const code = failure?.code ?? failure?.message;
    error = known.has(code) ? code : "candidate_unavailable";
  }
  return { decisions, error, receipt: { schema_version: 1, request_id: requestId, candidate_version: version,
    authority: "advisory", candidate_policy:{version,max_state_chars:maxStateChars,threshold_source:shape?.profile??null,calibration:"not_verified"}, execution: provider === evaluateTypeSafe ? "live_http" : "injected_provider", model: policy.model, state_sha256: fingerprint(state), questions_sha256: fingerprint(questions),
    latency_ms: Math.round(performance.now()-started), attempts, usage_coverage: !response ? "unknown" : attempts.filter(e=>e.stage==="attempt_started").length > 1 ? "successful_response_only" : "response_measured", usage: response?.usage ?? null, error } };
}
