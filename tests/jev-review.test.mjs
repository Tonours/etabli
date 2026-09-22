import test from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { reviewFindings, reviewObligations, groupFindings } from "../scripts/lib/jev-review.mjs";
import { evaluateClaimBatch } from "../scripts/lib/jev-claim-batch.mjs";
const evidence={path:"src/a.js",start:1,end:2,text:"if (!user) return;",excerpt_sha256:"e",file_sha256:"f"};
const pack={snapshot_sha256:"snapshot",complete:true,excerpts:[evidence]};
const finding=(id,severity="medium")=>({id,severity,line:1,path:"src/a.js",claim:"Null user is dereferenced",snapshot_sha256:"snapshot",evidence_ids:["e"]});
const provider=(values={},onCall=()=>{})=>async request=>{
 onCall(request);
 const answers=Object.fromEntries(Object.entries(request.questions).map(([id,q])=>{
  if(q.type==="noul") return [id,{type:"noul",noul:values[id]??0}];
  const choice=values[id]??Object.keys(q.criteria)[0];
  return [id,{type:"choice",choice,confidence:1,probabilities:Object.fromEntries(Object.keys(q.criteria).map(k=>[k,k===choice?1:0]))}];
 }));
 return {model:request.model,answers,usage:{input_tokens:12,output_tokens:3}};
};
test("empty and unbound findings avoid provider; retain escalation",async()=>{
 let calls=0;const options={pack,provider:provider({},()=>calls++),allowProviderEgress:true};
 assert.equal((await reviewFindings({...options,findings:[]})).receipts.length,0);
 const bad=await reviewFindings({...options,findings:[{...finding("a"),snapshot_sha256:"old"}]});
 assert.equal(bad.escalations.length,1);assert.equal(calls,0);
});
test("one batch binds each finding and preserves high severity escalation",async()=>{
 let calls=0;
 const r=await reviewFindings({pack,findings:[finding("a"),finding("b","high")],allowProviderEgress:true,provider:provider({status_0:"refuted",status_1:"style_only"},()=>calls++)});
 assert.equal(calls,1);assert.equal(r.receipts.length,1);assert.equal(r.findings[0].action,"recommend_dismiss");assert.equal(r.findings[1].action,"escalate");
 assert.equal(r.findings[0].request_id,r.findings[1].request_id);
});
test("safe reasoning escalation does not require a certain optional status",async()=>{
 const r=await reviewFindings({pack,findings:[finding("a")],allowProviderEgress:true,provider:provider({reasoning_0:1})});
 assert.equal(r.findings[0].action,"escalate");
});
test("provider failure and missing answer cannot dismiss a finding",async()=>{
 for(const p of [async()=>{throw new Error("private provider content");},async request=>({model:request.model,answers:{},usage:{input_tokens:1,output_tokens:1}})]) {
  const r=await reviewFindings({pack,findings:[finding("a")],allowProviderEgress:true,provider:p});
  assert.equal(r.findings[0].action,"escalate");assert.equal(r.receipts[0].error,"candidate_unavailable");
  assert.ok(!JSON.stringify(r).includes("private provider"));
 }
});
test("no egress without explicit permission",async()=>{
 let calls=0; const r=await reviewFindings({pack,findings:[finding("a")],provider:provider({},()=>calls++)});
 assert.equal(calls,0);assert.equal(r.findings[0].action,"escalate");
});

test("external IDs remain intact without becoming API question identifiers",async()=>{
 const ids=["Finding-42","A".repeat(80)];
 let calls=0;
 const result=await reviewFindings({pack,findings:ids.map(id=>finding(id)),allowProviderEgress:true,provider:provider({},()=>calls++)});
 assert.equal(calls,1);assert.deepEqual(result.findings.map(row=>row.id),ids);
 assert.ok(result.findings.every(row=>row.status==="grounded"));
 const obligations=await reviewObligations({pack,obligations:[{id:ids[0],text:"guard exists",source:"PLAN:2",evidence_ids:["e"]}],allowProviderEgress:true,provider:provider()});
 assert.equal(obligations.obligations[0].status,"satisfied");
});
test("pair annotations do not become transitive deduplication",async()=>{
 const r=await groupFindings({findings:[finding("a"),finding("b"),finding("c")],allowProviderEgress:true,provider:provider({pair_0_1:1,pair_1_2:1})});
 assert.equal(r.findings.length,3);assert.equal(r.groups.length,3);assert.deepEqual(r.groups[0].possible_duplicates,["b"]);
});
test("missing requirement evidence is never satisfied",async()=>{
 const r=await reviewObligations({pack,obligations:[{id:"a",text:"must pass",source:"PLAN.md:2",evidence_ids:["absent"]}],allowProviderEgress:true,provider:provider()});
 assert.equal(r.obligations[0].status,"insufficient");assert.equal(r.receipts.length,0);
});
test("v2 claims share exact evidence, resolve consumer root and omit absent conclusion",async()=>{
 const root=mkdtempSync(join(tmpdir(),"claims-v2-"));
 try {
  writeFileSync(join(root,"proof.txt"),"x".repeat(7000)+"\nexpected evidence\n");
  const claims=join(root,"claims.md"); writeFileSync(claims,"| Claim | Evidence | Status |\n| --- | --- | --- |\n| First claim | ./proof.txt:2 | verified |\n| Second claim | ./proof.txt:2 | verified |\n");
  let calls=0;
  const r=await evaluateClaimBatch({claimsFile:claims,claimIndices:[1,0],cwd:root,allowProviderEgress:true,provider:provider({},request=>{
   calls++;assert.equal(request.state.evidence.text,"expected evidence");assert.equal(Object.keys(request.questions).length,2);
  })});
  assert.equal(calls,1);assert.deepEqual(r.results.map(x=>x.index),[1,0]);assert.equal(r.results[0].materiality,"not_evaluated");assert.equal(r.results[0].outcome,"supported");
  assert.equal(r.receipts.length,1);
 } finally {rmSync(root,{recursive:true,force:true});}
});

test("claim materiality is a scalar and optional uncertainty preserves the relation",async()=>{
 const root=mkdtempSync(join(tmpdir(),"claim-materiality-"));
 try {
  writeFileSync(join(root,"proof.txt"),"The timeout is 1200 ms.\n");
  const claims=join(root,"claims.md");
  writeFileSync(claims,"| Claim | Evidence | Status |\n| --- | --- | --- |\n| The timeout is 1200 ms. | proof.txt:1 | verified |\n");
  for(const [probability,expected] of [[1,true],[0,false],[0.5,"uncertain"]]) {
   const result=await evaluateClaimBatch({claimsFile:claims,claimIndices:[0],cwd:root,
    conclusion:"The timeout satisfies a 2000 ms maximum.",allowProviderEgress:true,
    provider:provider({material_0:probability})});
   assert.equal(result.results[0].materiality,expected);
   assert.equal(result.results[0].outcome,"supported");
   assert.equal(result.results[0].action,"inspect_relation");
  }
 } finally {rmSync(root,{recursive:true,force:true});}
});

test("malformed nested candidate rows are input errors before provider egress",async()=>{
 const {candidateJudgment}=await import("../scripts/lib/jev-candidate-judgment.mjs");
 let calls=0;
 for(const malformed of [null,42,"invalid",[]]) {
  const states=[
   {version:"reviewer-finding-v2",state:{snapshot_sha256:"s",findings:[{id:"a",claim:"Claim",deciding_code:[malformed]}]}},
   {version:"review-spec-v1",state:{snapshot_sha256:"s",obligations:[{id:"a",text:"Requirement"}],evidence:[malformed]}},
   {version:"review-group-v1",state:{pairs:[{id:"pair",left:malformed,right:{id:"b",claim:"Claim"}}]}},
  ];
  for(const input of states) {
   const result=await candidateJudgment({...input,questions:{check:{type:"noul",instructions:"Check input"}},
    allowProviderEgress:true,provider:provider({},()=>calls++)});
   assert.equal(result.error,"invalid_candidate_state");
   assert.equal(result.receipt.attempts.length,0);
   assert.equal(result.receipt.usage,null);
   assert.equal(result.decisions,null);
  }
 }
 assert.equal(calls,0);
});

test("candidate input cannot override endpoint, credentials or profile thresholds",async()=>{
 let options;
 const result=await reviewFindings({pack,findings:[finding("a")],allowProviderEgress:true,
  profileId:"unknown-profile",transport:{endpoint:"https://untrusted.invalid",apiKey:"untrusted",fetchImpl:()=>{},timeoutMs:10},
  provider:async(request,receivedOptions)=>{options=receivedOptions;return provider({status_0:"refuted"})(request);}});
 assert.equal(result.findings[0].action,"recommend_dismiss");
 assert.equal(options.endpoint,undefined);assert.equal(options.apiKey,undefined);assert.equal(options.fetchImpl,undefined);
 assert.equal(options.timeoutMs,10);
});

test("review transport never forwards caller-controlled credentials or endpoint",async()=>{
 let options;
 await reviewFindings({pack,findings:[finding("a")],allowProviderEgress:true,
  transport:{endpoint:"https://untrusted.invalid",apiKey:"untrusted",fetchImpl:()=>{}},
  provider:async(request,receivedOptions)=>{options=receivedOptions;return provider()(request);}});
 assert.equal(options.endpoint,undefined);assert.equal(options.apiKey,undefined);assert.equal(options.fetchImpl,undefined);
});


test("candidate guards reject oversized singleton state, malformed shape and unprepared claims",async()=>{
 const {candidateJudgment}=await import("../scripts/lib/jev-candidate-judgment.mjs");
 let calls=0;
 for(const input of [
  {version:"reviewer-finding-v2",state:{snapshot_sha256:"s",findings:[{id:"a",claim:"x".repeat(8100),deciding_code:[]}]},questions:{check:{type:"noul",instructions:"check"}}},
  {version:"review-spec-v1",state:{obligations:"not an array",evidence:[],snapshot_sha256:"s"},questions:{check:{type:"noul",instructions:"check"}}},
  {version:"claim-evidence-v2",state:{evidence:{text:"raw"},claims:[{id:0,claim:"unchecked"}]},questions:{check:{type:"noul",instructions:"check"}}},
 ]) {
  const r=await candidateJudgment({...input,allowProviderEgress:true,provider:provider({},()=>calls++)});
  assert.ok(r.error);assert.equal(r.decisions,null);
 }
 assert.equal(calls,0);
});

test("prepared claim batch is bound to immutable structural evidence",async()=>{
 const {prepareClaimEvidenceBatchState,isPreparedClaimEvidenceState}=await import("../pi/extensions/lib/semantic-claim-evidence.mjs");
 assert.equal(typeof prepareClaimEvidenceBatchState,"function");
 const root=mkdtempSync(join(tmpdir(),"claim-bound-batch-"));
 try {
  writeFileSync(join(root,"proof.txt"),"proof");const claimsFile=join(root,"claims.md");
  writeFileSync(claimsFile,"| Claim | Evidence | Status |\n| --- | --- | --- |\n| Example | ./proof.txt | verified |\n");
  const {prepareClaimEvidenceStates}=await import("../pi/extensions/lib/semantic-claim-evidence.mjs");
  const items=prepareClaimEvidenceStates({claimsFile,claimIndices:[0],cwd:root,version:"v2"});
  const state=prepareClaimEvidenceBatchState(items);
  assert.equal(isPreparedClaimEvidenceState(state),true);
  state.claims[0].claim="mutated";assert.equal(isPreparedClaimEvidenceState(state),false);
  const {candidateJudgment}=await import("../scripts/lib/jev-candidate-judgment.mjs");
  let calls=0;const rejected=await candidateJudgment({version:"claim-evidence-v2",state,questions:{check:{type:"noul",instructions:"check"}},allowProviderEgress:true,provider:provider({},()=>calls++)});
  assert.equal(rejected.error,"unprepared_claim_batch");assert.equal(calls,0);
  assert.throws(()=>prepareClaimEvidenceBatchState([{index:0,state:{...items[0].state}}]),/prepared/);
 } finally {rmSync(root,{recursive:true,force:true});}
});


test("candidate state projection drops unrelated metadata before provider egress",async()=>{
 let received;
 const result=await reviewFindings({pack:{...pack,excerpts:[{...evidence,unrelated:"not for provider"}]},findings:[{...finding("a"),unrelated:"not for provider"}],allowProviderEgress:true,provider:provider({},request=>received=request)});
 assert.equal(result.findings[0].status,"grounded");
 assert.ok(!JSON.stringify(received.state).includes("not for provider"));
 assert.equal(result.receipts[0].candidate_policy.calibration,"not_verified");
 assert.equal(result.receipts[0].candidate_policy.max_state_chars,8000);
});

test("identical excerpt bytes in different files remain valid bound evidence",async()=>{
 let calls=0;
 const result=await reviewFindings({pack:{...pack,excerpts:[evidence,{...evidence,path:"src/b.js"}]},findings:[finding("a")],allowProviderEgress:true,provider:provider({},()=>calls++)});
 assert.equal(calls,1);assert.equal(result.findings[0].status,"grounded");
});


test("oversized finding does not prevent bounded neighbors from being evaluated",async()=>{
 const huge={...finding("huge"),claim:"x".repeat(33000)};
 let calls=0;
 const result=await reviewFindings({pack,findings:[huge,finding("small")],allowProviderEgress:true,provider:provider({},()=>calls++)});
 assert.equal(result.findings[0].action,"escalate");assert.equal(result.findings[1].status,"grounded");assert.equal(calls,1);
});
test("failed retry accounting reports unknown usage rather than a successful response",async()=>{
 const result=await reviewFindings({pack,findings:[finding("a")],allowProviderEgress:true,provider:async(request,options)=>{
  options.onAttempt({stage:"attempt_started"});options.onAttempt({stage:"attempt_started"});throw new Error("timeout");
 }});
 assert.equal(result.receipts[0].usage_coverage,"unknown");assert.equal(result.receipts[0].usage,null);
});
test("missing local v2 evidence is a normalized structural failure",async()=>{
 const {prepareClaimEvidenceState}=await import("../pi/extensions/lib/semantic-claim-evidence.mjs");
 const root=mkdtempSync(join(tmpdir(),"missing-claim-"));
 try {
  const claimsFile=join(root,"claims.md");writeFileSync(claimsFile,"| Claim | Evidence | Status |\n| --- | --- | --- |\n| Example | ./missing.txt:1 | verified |\n");
  assert.throws(()=>prepareClaimEvidenceState({claimsFile,claimIndex:0,cwd:root,version:"v2"}),/^Error: claim structural check failed$/);
 } finally {rmSync(root,{recursive:true,force:true});}
});

test("ranked evidence exposes scalar decisions with explicit uncertainty status",async()=>{
 const {rankReviewEvidence}=await import('../scripts/lib/jev-review.mjs');
 const result=await rankReviewEvidence({candidates:[{id:'guard',...evidence}],purpose:'Is the null guard present?',allowProviderEgress:true,provider:async request=>({model:request.model,answers:{relevance_0:{type:'score',score:3,confidence:1,probabilities:{'0':0,'1':0,'2':0,'3':1},legend:request.questions.relevance_0.criteria[3]},contradiction_0:{type:'noul',noul:0}},usage:{input_tokens:10,output_tokens:4}})});
 assert.equal(result.candidates[0].relevance,3);assert.equal(result.candidates[0].relevance_status,'accepted');
 assert.equal(result.candidates[0].contradiction,false);assert.equal(result.candidates[0].contradiction_status,'accepted');
});
