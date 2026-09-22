import test from "node:test";
import assert from "node:assert/strict";
import { buildReviewCampaignPlan, compareReviewCampaign, capsuleExperimentPlan } from "../scripts/lib/jev-review-campaign.mjs";
import { reviewRunReceipt, sha256 } from "../scripts/lib/review-run-receipt.mjs";
const cases=Array.from({length:12},(_,i)=>({id:`case-${i}`,patch_sha256:String(i).padStart(64,"0"),kind:i<6?"critical":i<9?"clean":"drift"}));
const manifest=buildReviewCampaignPlan({cases});
const rows=manifest.cells.map(c=>({...c,manifest_sha256:manifest.manifest_sha256,measured:true,coverage_complete:true,execution:"live",total_llm_tokens:{A:1000,B:800,C:500}[c.arm],elapsed_ms:c.arm==="C"?500:1000,success:true,expected_defects:cases.find(x=>x.id===c.case_id).kind==="clean"?[]:["bug"],found_defects:cases.find(x=>x.id===c.case_id).kind==="clean"?[]:["bug"],false_go:false,false_block:false,runtime_sha256:"runtime",effective_model:"openai/gpt-fixture",effort:"fixed",evaluator_sha256:"oracle"}));
const canaries=manifest.canary_cases.map(id=>({id,success:true,execution:"live",complete_usage:true}));
for(const row of rows) row.telemetry={schema_version:1,timing_coverage:"request_intervals_observed",preparation_ms:2,
 roles:[{role:"logic",pass_id:row.case_id,llm_calls:1,tool_calls:0,total_tokens:row.total_llm_tokens}],
 jev_tokens:row.arm==="C"?20:0,jev_wait_ms:row.arm==="C"?10:0,jev_backoff_ms:0,
 usage:{input_tokens:row.total_llm_tokens-10,output_tokens:10,cached_input_tokens:0,cache_write_input_tokens:0,reasoning_output_tokens:null,cost_usd:null}};
for(const row of rows) {
 const roles=["parent","logic","spec","adversary-code","adversary-code"];
 const root=`${row.case_id}-${row.repetition}-${row.arm}`;
 row.passes=roles.map((role,index)=>{
  const passId=root+"-"+index,total=row.total_llm_tokens/roles.length;
  const pass=reviewRunReceipt({passId,parentId:index?root+"-0":null,role,patchSha256:row.patch_sha256,exitCode:0,elapsedMs:row.elapsed_ms,
   events:[{type:"message_end",message:{role:"assistant",responseId:passId,provider:"openai",model:"gpt-fixture",stopReason:"stop",content:[{type:"text",text:"fixture review"}],usage:{input:total-1,output:1,cacheRead:0,cacheWrite:0,totalTokens:total}}}]});
  return {...pass,child_inventory:{status:"complete",evidence:"fixture dispatch ledger"},isolated_context:true,capture_id:sha256(passId),input_context_sha256:sha256("fixture inputs")};
 });
 row.expected_passes=row.passes.map(({pass_id,parent_id,role,patch_sha256})=>({pass_id,parent_id,role,patch_sha256}));
 row.telemetry.roles=row.passes.map(pass=>({pass_id:pass.pass_id,role:pass.role,total_tokens:pass.receipts[0].total_tokens,llm_calls:1,tool_calls:0}));
}
test("three-arm plan freezes population and does not authorize inference",()=>{
 assert.equal(manifest.cells.length,108);assert.equal(manifest.authorization,"not_authorized");assert.equal(manifest.provider_calls,"unknown_until_runner_inventory");assert.equal(capsuleExperimentPlan().max_launches,84);
});
test("comparator checks complete functional chain before savings",()=>{
 assert.equal(compareReviewCampaign({manifest,rows,canaries:[]}).verdict,"inconclusive");
 assert.equal(compareReviewCampaign({manifest,rows:rows.slice(1),canaries}).verdict,"inconclusive");
 const broken=structuredClone(rows);broken[0].coverage_complete=false;
 assert.equal(compareReviewCampaign({manifest,rows:broken,canaries}).verdict,"inconclusive");
 const good=compareReviewCampaign({manifest,rows,canaries});assert.equal(good.verdict,"pilot_thresholds_met");assert.equal(good.promotion,false);
});
test("missing critical defect rejects cheaper candidate and duplicates are invalid",()=>{
 const broken=structuredClone(rows);const c=broken.find(r=>r.arm==="C");c.found_defects=[];
 assert.equal(compareReviewCampaign({manifest,rows:broken,canaries}).verdict,"rejected");
 assert.equal(compareReviewCampaign({manifest,rows:[...rows,rows[0]],canaries}).verdict,"inconclusive");
});

test("changed manifest or labels cannot manufacture a comparable population",()=>{
 const altered=structuredClone(manifest);altered.cells[0].arm="D";
 assert.throws(()=>compareReviewCampaign({manifest:altered,rows,canaries}),/drift/);
 const relabeled=structuredClone(rows);relabeled.find(r=>r.arm==="C").expected_defects=[];
 assert.equal(compareReviewCampaign({manifest,rows:relabeled,canaries}).verdict,"inconclusive");
});

test("every frozen manifest field is checked, including canary requirements",()=>{
 for (const change of [
  {canary_cases:[]}, {canary_runs:0}, {authorization:"authorized"},
  {substitution:"enabled"}, {max_launches:999}, {holdout_policy:"unsealed"},
 ]) {
  assert.throws(()=>compareReviewCampaign({manifest:{...manifest,...change},rows,canaries:[{},{}]}),/manifest drift/);
 }
});

test("phase gaps stay inconclusive and patch intervals do not count repetitions as independent",()=>{
 const missing=structuredClone(rows);delete missing[0].telemetry;
 assert.equal(compareReviewCampaign({manifest,rows:missing,canaries}).verdict,"inconclusive");
 const result=compareReviewCampaign({manifest,rows,canaries});
 assert.equal(result.intervals.C_over_B.patches,12);
 assert.equal(result.aggregate.C.telemetry.jev_tokens,720);
 assert.equal(result.aggregate.C.telemetry.combined_tokens,18720);
 assert.equal(result.aggregate.C.by_repetition.length,3);
 assert.equal(result.aggregate.C.telemetry.combined_cost_usd,null);
});

test("cheaper campaigns cannot omit a mandatory pass or reuse an independent context",()=>{
 for(const role of ["parent","logic","spec","adversary-code"]) {
  const altered=structuredClone(rows);
  altered[0].passes=altered[0].passes.filter(pass=>pass.role!==role);
  const result=compareReviewCampaign({manifest,rows:altered,canaries});
  assert.equal(result.verdict,"inconclusive");
  assert.ok(result.issues.includes("required_review_pass_missing"));
 }
 const reused=structuredClone(rows);
 reused[0].passes[2].capture_id=reused[0].passes[1].capture_id;
 assert.ok(compareReviewCampaign({manifest,rows:reused,canaries}).issues.includes("review_context_independence_unproven"));
 const high=buildReviewCampaignPlan({cases,tier:"high-risk",authorFamily:"openai"});
 const sameFamily=structuredClone(rows).map(row=>({...row,manifest_sha256:high.manifest_sha256}));
 assert.ok(compareReviewCampaign({manifest:high,rows:sameFamily,canaries}).issues.includes("cross_family_adversary_unproven"));
});

test("native provider receipts cannot be replayed as fresh repetitions",()=>{
 const replay=structuredClone(rows);
 const first=replay.find(row=>row.case_id==="case-0"&&row.arm==="C"&&row.repetition===1);
 const second=replay.find(row=>row.case_id==="case-0"&&row.arm==="C"&&row.repetition===2);
 second.passes=structuredClone(first.passes);
 second.expected_passes=structuredClone(first.expected_passes);
 second.telemetry.roles=structuredClone(first.telemetry.roles);
 const result=compareReviewCampaign({manifest,rows:replay,canaries});
 assert.equal(result.verdict,"inconclusive");
 assert.ok(result.issues.includes("replayed_provider_receipt"));
});

test("unrecognized author families cannot bypass high-risk independence",()=>{
 for(const authorFamily of ["OpenAI","unrecognized",""])
  assert.throws(()=>buildReviewCampaignPlan({cases,tier:"high-risk",authorFamily}),/author family/);
});

test("capsule control uses identical system bytes and never changes user intent",async()=>{
 const {prepareCapsuleExperimentArm}=await import("../scripts/lib/jev-review-campaign.mjs");
 const {renderDeterministicCapsule}=await import("../pi/extensions/lib/jev-route-capsule.mjs");
 const input={prompt:"review this",systemPrompt:"base contract",route:"review"};
 const a=await prepareCapsuleExperimentArm({...input,arm:"A"});
 const b=await prepareCapsuleExperimentArm({...input,arm:"B"});
 let calls=0;
 const c=await prepareCapsuleExperimentArm({...input,arm:"C",allowProviderEgress:true,evaluate:async()=>{calls++;return {status:"accepted",route:"review",capsule:renderDeterministicCapsule("review")};}});
 assert.equal(c.systemPrompt,b.systemPrompt);assert.equal(c.prompt,a.prompt);assert.equal(calls,1);
 for(const route of ["plan-implement","ops-stop","ci-fix"])assert.equal((await prepareCapsuleExperimentArm({...input,route,arm:"C"})).systemPrompt,input.systemPrompt);
});

test("unknown Jev usage cannot yield a successful efficiency verdict",()=>{
 const altered=structuredClone(rows);altered.find(row=>row.arm==="C").telemetry.jev_tokens=null;
 const result=compareReviewCampaign({manifest,rows:altered,canaries});
 assert.equal(result.verdict,"inconclusive");assert.ok(result.issues.includes("incomplete_jev_usage"));
});


test("identical inputs in distinct isolated captures are valid independent repetitions",()=>{
 const identical=structuredClone(rows);
 for(const row of identical)for(const pass of row.passes)pass.input_context_sha256=sha256("same input");
 assert.equal(compareReviewCampaign({manifest,rows:identical,canaries}).verdict,"pilot_thresholds_met");
});

test("Jev token transfer cannot hide a larger combined token total",()=>{
 const expensive=structuredClone(rows);
 for(const row of expensive)if(row.arm==="C")row.telemetry.jev_tokens=1000;
 const result=compareReviewCampaign({manifest,rows:expensive,canaries});
 assert.equal(result.verdict,"rejected");assert.equal(result.combined_efficiency,false);
});


test("high-risk labels and direct Z.ai family match the enforced inventory",()=>{
 const high=buildReviewCampaignPlan({cases,tier:"high-risk",authorFamily:"openai"});
 assert.equal(high.second_adversary,"cross_family_required");
 const direct=structuredClone(rows).map(row=>({...row,manifest_sha256:high.manifest_sha256}));
 for(const row of direct)for(const pass of row.passes)if(pass.role==="adversary-code")pass.models=["zai/glm-5.3"];
 assert.ok(!compareReviewCampaign({manifest:high,rows:direct,canaries}).issues?.includes("cross_family_adversary_unproven"));
});
