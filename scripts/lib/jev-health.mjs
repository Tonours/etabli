import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { loadSemanticPolicy } from "../../pi/extensions/lib/route-shadow.mjs";
import { loadSemanticProfilePolicy, profileSummary } from "../../pi/extensions/lib/semantic-profiles.mjs";
import { calibrationProfileIds, REPORT_DIR, verifyCalibrationReport } from "../../pi/extensions/lib/semantic-profile-calibration.mjs";

export function jevHealth({ credentialPresent = Boolean(process.env.TYPESAFE_API_KEY), noRetry = false } = {}) {
  const profile=loadSemanticProfilePolicy(), legacy=loadSemanticPolicy();
  const campaign=JSON.parse(readFileSync(resolve(REPORT_DIR,"campaign.json"),"utf8"));
  const calibrations=calibrationProfileIds(profile).map((id)=>{
    try {const report=verifyCalibrationReport(id,REPORT_DIR,profile,campaign);return {id,status:"verified_historical",verdict:report.verdict};}
    catch {return {id,status:"stale_or_invalid",verdict:"unknown"};}
  });
  return {ok:true,policy_version:profile.policy_version,provider:profile.provider,model:profile.model,
    profiles:Object.keys(profile.profiles).length,credential:credentialPresent?"present":"absent",live_by_default:false,
    max_retries:noRetry?0:profile.max_retries,legacy:{mode:legacy.mode},
    capsules:{status:"removed",effective_mode:"deterministic_fallback"},
    profile_inventory:profileSummary(profile),calibrations,execution_coverage:"unknown",
    candidates:{review:"opt_in_advisory",claim_evidence_v2:"opt_in_advisory",diagnosis:"pending_corpus",promotion:"not_authorized"}};
}

export function summarizeJevObservations(events) {
  const types=new Set(["etabli.workflow-router", "etabli.jev-route-capsule", "etabli.semantic-profile"]);
  const counts={};let observations=0;
  for(const event of events) {
    if(event.type!=="custom" || !types.has(event.customType)) continue;
    const status=event.data?.status??event.data?.outcome;
    if(!["accepted","abstained","uncertain","abstain","bypassed","route_mismatch"].includes(status))continue;
    counts[status]=(counts[status]??0)+1;observations++;
  }
  return {observations,counts,coverage:observations?"observed_only":"unknown"};
}
