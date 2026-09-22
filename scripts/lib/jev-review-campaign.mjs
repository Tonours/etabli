import { fingerprint } from "../../pi/extensions/lib/semantic-judgment.mjs";
import { aggregateTelemetry, pairedTokenInterval } from "./jev-review-metrics.mjs";
import { aggregateReviewRuns } from "./review-run-receipt.mjs";

const arms=["A","B","C"];
export function requiredReviewPasses(tier) {
  return {parent:1,logic:1,spec:1,"adversary-code":tier==="high-risk"?1:2};
}
const family = model => /(?:^|\/)(gpt-|codex)/.test(model) ? "openai"
  : /(?:^|\/)claude-/.test(model) ? "anthropic" : /(?:^|\/)grok-/.test(model) ? "xai"
  : /^zai\/glm-/.test(model) ? "zai" : null;
export function buildReviewCampaignPlan({ cases, repetitions=3, tier="standard", budget=null, authorFamily=null }) {
  if(authorFamily!==null&&!["openai","anthropic","xai","zai","moonshot","alibaba","deepseek"].includes(authorFamily))throw new Error("invalid canonical author family");
  if(!Array.isArray(cases)||cases.length!==12||new Set(cases.map(c=>c.id)).size!==12||cases.some(c=>!c.id||!c.patch_sha256||!["critical","clean","drift"].includes(c.kind))) throw new Error("review pilot requires 12 distinct pinned cases");
  if(cases.filter(c=>c.kind==="critical").length<6||cases.filter(c=>c.kind==="clean").length<3||cases.filter(c=>c.kind==="drift").length<3||repetitions!==3||!["standard","high-risk"].includes(tier))throw new Error("invalid frozen review population");
  const cells=[];
  for(let repetition=1;repetition<=repetitions;repetition++) for(const [index,c] of cases.entries()) {
    const offset=(index+repetition-1)%3;
    for(let i=0;i<3;i++)cells.push({case_id:c.id,patch_sha256:c.patch_sha256,repetition,arm:arms[(offset+i)%3]});
  }
  const contract={schema_version:1,kind:"review-pilot-v1",cases,repetitions,tier,author_family:authorFamily,
    required_passes:requiredReviewPasses(tier),parent_duties:["coordination","quality","lead"],
    arms:{A:"current_required_passes",B:"same_passes_deterministic_packs",C:"same_passes_packs_and_jev"},
    cells,canary_cases:["review-go-clean-diff","review-spec-drift"],canary_runs:2,
    authorization:"not_authorized",budget,substitution:"disabled",second_adversary:tier==="high-risk"?"cross_family_required":"same_family_double_sample"};
  return {...contract,manifest_sha256:fingerprint(contract),review_cells:108,
    max_launches:budget?.max_launches??null,launch_estimate_status:"runner_pass_inventory_required",
    provider_calls:"unknown_until_runner_inventory",holdout_policy:"sealed_labels_outside_agent_context"};
}

export function compareReviewCampaign({manifest,rows,canaries}) {
  const issues=[];
  const rebuilt=buildReviewCampaignPlan({cases:manifest.cases,repetitions:manifest.repetitions,tier:manifest.tier,budget:manifest.budget,authorFamily:manifest.author_family});
  if(fingerprint(rebuilt)!==fingerprint(manifest))throw new Error("campaign manifest drift");
  if(manifest.kind!=="review-pilot-v1"||manifest.review_cells!==108)throw new Error("invalid review campaign manifest");
  if(!Array.isArray(canaries)||canaries.length!==2||!manifest.canary_cases.every(id=>canaries.some(c=>c.id===id&&c.success===true&&c.execution==="live"&&c.complete_usage===true)))issues.push("functional_live_canaries_missing");
  const keys=new Set(),configs=new Set(),roleConfigs=new Set(),providerReceipts=new Set(),captures=new Set();
  for(const row of rows) {
    const key=`${row.case_id}/${row.repetition}/${row.arm}`;
    if(keys.has(key))issues.push("duplicate_cell");keys.add(key);
    const expected=manifest.cells.find(c=>`${c.case_id}/${c.repetition}/${c.arm}`===key);
    if(!expected||expected.patch_sha256!==row.patch_sha256||row.manifest_sha256!==manifest.manifest_sha256)issues.push("cell_identity_mismatch");
    if(row.measured!==true||row.coverage_complete!==true||row.execution!=="live"||!Number.isSafeInteger(row.total_llm_tokens)||row.total_llm_tokens<=0||!Number.isFinite(row.elapsed_ms)||row.elapsed_ms<=0)issues.push("incomplete_usage_or_execution");
    if(typeof row.success!=="boolean"||!Array.isArray(row.expected_defects)||!Array.isArray(row.found_defects)||typeof row.false_go!=="boolean"||typeof row.false_block!=="boolean")issues.push("incomplete_quality_oracle");
    if(!row.runtime_sha256||!row.effective_model||!row.effort||!row.evaluator_sha256)issues.push("missing_execution_provenance");
    if(row.telemetry?.timing_coverage!=="request_intervals_observed" || !Number.isFinite(row.telemetry?.preparation_ms)
      || row.telemetry.preparation_ms<0)issues.push("incomplete_phase_timing");
    if(!Number.isSafeInteger(row.telemetry?.jev_tokens)||row.telemetry.jev_tokens<0)issues.push("incomplete_jev_usage");
    const roles=row.telemetry?.roles;
    if(!Array.isArray(roles)||!roles.length||roles.some(role=>!Number.isSafeInteger(role.total_tokens)||role.total_tokens<=0)||
      roles.reduce((sum,role)=>sum+role.total_tokens,0)!==row.total_llm_tokens)issues.push("role_usage_mismatch");
    const passes=row.passes??[];
    if(!Array.isArray(row.expected_passes)||!row.expected_passes.length||!passes.length)issues.push("native_pass_inventory_missing");
    else {
      const chain=aggregateReviewRuns(row.expected_passes,passes);
      if(!chain.measured||chain.total_tokens!==row.total_llm_tokens||
        passes.some(pass=>pass.patch_sha256!==row.patch_sha256))issues.push("incomplete_native_pass_chain");
      for(const [role,count] of Object.entries(manifest.required_passes))
        if(passes.filter(pass=>pass.role===role).length<count)issues.push("required_review_pass_missing");
      const independent=passes.filter(pass=>["logic","spec","adversary-code"].includes(pass.role));
      if(independent.some(pass=>pass.isolated_context!==true||!/^[a-f0-9]{64}$/.test(pass.capture_id??"")||!/^[a-f0-9]{64}$/.test(pass.input_context_sha256??""))||
        new Set(independent.map(pass=>pass.capture_id)).size!==independent.length)issues.push("review_context_independence_unproven");
      for(const pass of passes) {
        if(pass.capture_id) {
          if(captures.has(pass.capture_id))issues.push("replayed_review_capture");
          captures.add(pass.capture_id);
        }
        for(const receipt of pass.receipts??[])if(receipt.identity?.startsWith("pi:provider:")) {
          if(providerReceipts.has(receipt.identity))issues.push("replayed_provider_receipt");
          providerReceipts.add(receipt.identity);
        }
      }
      if(manifest.tier==="high-risk" && (!manifest.author_family ||
        passes.filter(pass=>pass.role==="adversary-code").some(pass=>!pass.models?.length||
          pass.models.some(model=>!family(model)||family(model)===manifest.author_family))))issues.push("cross_family_adversary_unproven");
      roleConfigs.add(JSON.stringify([...new Set(passes.map(pass=>JSON.stringify([pass.role,...pass.models])))].sort()));
    }
    const caseKind=manifest.cases.find(c=>c.id===row.case_id)?.kind;
    if(caseKind==="critical" && !row.expected_defects?.length || caseKind==="clean" && row.expected_defects?.length)issues.push("oracle_contradicts_case_kind");
    if(row.expected_defects && new Set(row.expected_defects).size!==row.expected_defects.length || row.found_defects && new Set(row.found_defects).size!==row.found_defects.length)issues.push("duplicate_defect_identity");
    const oraclePeer=rows.find(r=>r.case_id===row.case_id && r!==row);
    if(oraclePeer && fingerprint(row.expected_defects)!==fingerprint(oraclePeer.expected_defects))issues.push("oracle_drift_between_arms");
    configs.add(JSON.stringify([row.runtime_sha256,row.effective_model,row.effort,row.evaluator_sha256]));
  }
  if(rows.length!==manifest.cells.length||manifest.cells.some(c=>!keys.has(`${c.case_id}/${c.repetition}/${c.arm}`)))issues.push("incomplete_population");
  if(configs.size!==1 || roleConfigs.size!==1)issues.push("non_comparable_runtime");
  const median=values=>{const sorted=[...values].sort((a,b)=>a-b);return sorted.length%2?sorted[(sorted.length-1)/2]:(sorted[sorted.length/2-1]+sorted[sorted.length/2])/2;};
  const aggregate=Object.fromEntries(arms.map(arm=>{
    const cells=rows.filter(r=>r.arm===arm);
    const totals=cells.every(r=>Number.isSafeInteger(r.total_llm_tokens))?cells.reduce((n,r)=>n+r.total_llm_tokens,0):null;
    const successes=cells.filter(r=>r.success===true).length;
    const expected=cells.reduce((n,r)=>n+(r.expected_defects?.length??0),0);
    const truePositive=cells.reduce((n,r)=>n+(r.found_defects??[]).filter(id=>r.expected_defects?.includes(id)).length,0);
    const found=cells.reduce((n,r)=>n+(r.found_defects?.length??0),0);
    return [arm,{attempts:cells.length,successes,total_tokens:totals,tokens_per_success:successes&&totals!==null?totals/successes:null,
      median_ms:cells.length?median(cells.map(r=>r.elapsed_ms)):null,p95_ms:cells.length?[...cells.map(r=>r.elapsed_ms)].sort((a,b)=>a-b)[Math.ceil(cells.length*.95)-1]:null,
      recall:expected?truePositive/expected:null,precision:found?truePositive/found:null,
      false_go:cells.filter(r=>r.false_go===true).length,false_block:cells.filter(r=>r.false_block===true).length,
      telemetry:aggregateTelemetry(cells),
      by_repetition:[1,2,3].map(repetition=>({repetition,...aggregateTelemetry(cells.filter(row=>row.repetition===repetition))}))}];
  }));
  if(issues.length)return {verdict:"inconclusive",promotion:false,issues:[...new Set(issues)],aggregate};
  const {A,B,C}=aggregate;
  const quality=A.successes>0&&B.successes>0&&C.successes>0&&C.successes>=A.successes&&C.successes>=B.successes&&C.false_go===0&&C.recall>=A.recall&&C.recall>=B.recall&&C.precision>=A.precision&&C.precision>=B.precision&&
    rows.filter(r=>r.arm==="C").every(r=>r.expected_defects.every(id=>r.found_defects.includes(id)));
  const combinedEfficiency=C.telemetry.combined_tokens<=A.telemetry.combined_tokens && C.telemetry.combined_tokens<=B.telemetry.combined_tokens;
  const efficiency=combinedEfficiency&&C.total_tokens<=A.total_tokens*.7&&C.total_tokens<=B.total_tokens*.9&&C.median_ms<=A.median_ms*.8&&C.p95_ms<=A.p95_ms*1.05;
  const intervals={C_over_A:pairedTokenInterval(rows,"A"),C_over_B:pairedTokenInterval(rows,"B")};
  const conclusive=intervals.C_over_A?.upper<=.7&&intervals.C_over_B?.upper<=.9;
  return {verdict:quality&&efficiency?(conclusive?"pilot_thresholds_met":"inconclusive"):"rejected",promotion:false,aggregate,quality,efficiency,combined_efficiency:combinedEfficiency,intervals,
    uncertainty:"small pilot; independent quality review required before promotion",second_adversary:manifest.second_adversary};
}

export function capsuleExperimentPlan() {
  return {schema_version:1,kind:"capsule-three-arm-v1",arms:{A:"deterministic_route_without_capsule",B:"deterministic_route_fixed_capsule",C:"same_capsule_conditioned_by_jev"},
    repetitions:3,tasks:9,final_cells:81,canary_cells:3,max_launches:84,injection:"system_prompt_only",authorization:"not_authorized",protected_routes:"unchanged",plan_implement:"excluded",promotion:false};
}

export async function prepareCapsuleExperimentArm({ arm, prompt, systemPrompt, route, writeAllowed=false, evaluate, allowProviderEgress=false }) {
  if(!arms.includes(arm))throw new Error("invalid capsule arm");
  const {renderDeterministicCapsule}=await import("../../pi/extensions/lib/jev-route-capsule.mjs");
  const mapped=route==="plan-loop"?"planning":route==="implement"||route==="answer"&&writeAllowed?"implementation":["review","pr-review","sec-pr"].includes(route)?"review":null;
  const expected=mapped?renderDeterministicCapsule(mapped):null;
  let capsule=null,receipt=null;
  if(arm==="B")capsule=expected;
  if(arm==="C"&&expected) {
    if(!allowProviderEgress||typeof evaluate!=="function")throw new Error("capsule C requires explicit authorized evaluator");
    receipt=await evaluate(prompt);
    if(receipt.status==="accepted"&&receipt.route===mapped&&receipt.capsule===expected)capsule=expected;
  }
  return {arm,prompt,systemPrompt:capsule?`${systemPrompt}\n\n<etabli-jev-route-capsule>\n${capsule}\n</etabli-jev-route-capsule>`:systemPrompt,receipt,promotion:false};
}
