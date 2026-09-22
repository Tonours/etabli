import { fingerprint } from "../../pi/extensions/lib/semantic-judgment.mjs";
import { prepareSelfImprovementDiagnosisRequest } from "../../pi/extensions/lib/semantic-profiles.mjs";

export function validateCandidateCorpus(corpus) {
 if(corpus.schema_version!==1||corpus.kind!=="synthetic_sanitized"||corpus.collection!=="not_collected"||!Array.isArray(corpus.cases)||new Set(corpus.cases.map(c=>c.id)).size!==corpus.cases.length)throw new Error("invalid candidate corpus");
 if(corpus.candidate_version==="claim-evidence-v2") {
  const development=corpus.cases.filter(c=>c.split==="development"),holdout=corpus.cases.filter(c=>c.split==="held_out");
  if(development.length!==20||holdout.length!==30||development.some(c=>holdout.some(h=>h.family===c.family)))throw new Error("invalid or leaking corpus split");
  if(corpus.cases.some(c=>!c.claim||!c.evidence||!["en","fr"].includes(c.language)||!["supported","contradicted","insufficient","irrelevant"].includes(c.expected_relation)))throw new Error("invalid claim case");
 } else if(corpus.candidate_version==="diagnosis-corpus-v1") {
  for(const c of corpus.cases) {
   let failed=false;
   try {prepareSelfImprovementDiagnosisRequest(diagnosisObservation(c));}catch {failed=true;}
   if(failed!==Boolean(c.expected_error))throw new Error(`diagnosis preflight mismatch: ${c.id}`);
  }
 } else throw new Error("unknown candidate corpus");
 return {ok:true,candidate_version:corpus.candidate_version,cases:corpus.cases.length,corpus_sha256:fingerprint(corpus),live_quality:"not_verified",promotion:false};
}
export function diagnosisObservation(c) {
 return {schema_version:1,capability:"prototype_offline",adapter:"pi",adapter_version:"prototype-offline-1",binding:"explicit_unverified",observation_id:"11111111-1111-4111-8111-111111111111",completeness:c.completeness,lifecycle:{terminal:true,outcome:c.terminal},reason_codes:[],signals:c.signals};
}
