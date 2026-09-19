#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
node --input-type=module <<JS
import { mkdirSync, readFileSync, symlinkSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { validateJudgmentRequest, validateJudgmentResponse, containsSecretLike } from "$ROOT/pi/extensions/lib/semantic-judgment.mjs";
import { evaluateTypeSafe, TypeSafeServiceError } from "$ROOT/pi/extensions/lib/typesafe-system-one.mjs";
import { promotionRuntimeFingerprint, runRouteDecision, summarizeCalibrationResults, validatePromotionManifest } from "$ROOT/pi/extensions/lib/route-shadow.mjs";
import { fingerprint } from "$ROOT/pi/extensions/lib/semantic-judgment.mjs";
import { routeQuestionFingerprint } from "$ROOT/pi/extensions/lib/semantic-route.mjs";
const runtimePolicy=(mode="shadow",overrides={})=>({mode,provider:"fixture",model:"jev-1.13.0",policy_version:"test-v2",max_state_chars:100,timeout_ms:50,max_retries:0,receipt_path:"receipts.jsonl",allowed_routes:["answer","direct-edit","implement","ops-stop","verify"],promotion_manifest:"promotion.json",decision_thresholds:{read_only:{min_confidence:.7,min_margin:.15},local_write:{min_confidence:.85,min_margin:.25}},promotion_gates:{min_cases:2,min_repetitions:1,min_accuracy:.8,min_accepted_accuracy:1,min_accepted_coverage:.5,min_override_cases:1,min_override_accuracy:.8,min_accepted_override_accuracy:1,min_accepted_override_coverage:.5,min_protected_safety_rate:1,max_provider_error_rate:.1,min_stable_case_rate:1,max_brier_score:.25,max_expected_calibration_error:.2,max_input_cost_usd:.01,max_latency_p95_ms:2500},...overrides});
const request = validateJudgmentRequest({state:{text:"route this"},model:"jev-1.13.0",questions:{route:{type:"choice",instructions:"route",criteria:{answer:null,verify:null}},safe:{type:"noul",instructions:"safe?"},risk:{type:"score",instructions:"risk",criteria:["low","high"]}}});
const body={model:"jev-1.13.0",answers:{route:{type:"choice",choice:"verify",probabilities:{answer:.2,verify:.8},confidence:.7},safe:{type:"noul",noul:.9},risk:{type:"score",score:.6,legend:{0:"low",1:"high"},probabilities:{0:.4,1:.6},confidence:.2}},usage:{input_tokens:12,output_tokens:4}};
validateJudgmentResponse(request,body);
let calls=0; let auth=""; let requestCache=""; let cacheControl=""; let pragma="";
const response=await evaluateTypeSafe(request,{apiKey:"unit-secret",maxRetries:1,sleep:async()=>{},fetchImpl:async(_url,init)=>{calls++;auth=init.headers.authorization;requestCache=init.cache;cacheControl=init.headers["cache-control"];pragma=init.headers.pragma;if(calls===1)return {ok:false,status:429,headers:{get:()=>"0"}};return {ok:true,status:200,text:async()=>JSON.stringify(body),headers:{get:()=>null}};}});
if(calls!==2||auth!=="Bearer unit-secret"||requestCache!=="no-store"||cacheControl!=="no-store, no-cache, max-age=0"||pragma!=="no-cache"||response.answers.route.choice!=="verify")throw new Error("retry/live no-store client contract failed");
let touched=false;
try{await evaluateTypeSafe({...request,state:"api_key=very-secret-value"},{apiKey:"x",fetchImpl:async()=>{touched=true;}});}catch{}
for(const secretState of ["password=hunter2",'{"password":"synthetic-only-secret"}','{"api_key":"synthetic-only-secret"}','curl -H "Authorization: Bearer synthetic-only-token" https://example.test','{"authorization":"Basic c3ludGhldGljLW9ubHk="}','Authorization: Basic dTpw']){
  try{await evaluateTypeSafe({...request,state:secretState},{apiKey:"x",fetchImpl:async()=>{touched=true;}});}catch{}
}
if(touched||!containsSecretLike("password=hunter2"))throw new Error("privacy preflight failed");
for(const ordinary of ["Explain basic authentication requirements","Review the basic configuration carefully","Document bearer authentication behavior"]){if(containsSecretLike(ordinary))throw new Error("ordinary auth wording rejected");}
let timeoutCode="";
try{await evaluateTypeSafe(request,{apiKey:"x",timeoutMs:10,maxRetries:0,fetchImpl:async()=>({ok:true,status:200,headers:{get:()=>null},text:async()=>new Promise(()=>{})})});}catch(error){timeoutCode=error.code;}
if(timeoutCode!=="timeout")throw new Error("body timeout was not bounded");
let streamTimeout="";
let streamSignal;
try{await evaluateTypeSafe(request,{apiKey:"x",timeoutMs:10,maxRetries:0,fetchImpl:async(_url,init)=>{streamSignal=init.signal;return {ok:true,status:200,headers:{get:()=>null},body:new ReadableStream({start(controller){controller.enqueue(new TextEncoder().encode("{"));}})};}});}catch(error){streamTimeout=error.code;}
if(streamTimeout!=="timeout"||!streamSignal.aborted)throw new Error("streaming body timeout was not bounded");
let tooLarge="";
try{await evaluateTypeSafe(request,{apiKey:"x",maxRetries:0,maxResponseBytes:8,fetchImpl:async()=>({ok:true,status:200,headers:{get:()=>"9"},text:async()=>"ignored"})});}catch(error){tooLarge=error.code;}
if(tooLarge!=="response_too_large")throw new Error("response size was not bounded");
let abandonedSignal;
let cancelCalled=false;
try{await evaluateTypeSafe(request,{apiKey:"x",maxRetries:0,fetchImpl:async(_url,init)=>{abandonedSignal=init.signal;return {ok:false,status:429,headers:{get:()=>null},body:{cancel:async()=>{cancelCalled=true;}}};}});}catch(error){if(error.code!=="http_429")throw error;}
await new Promise((resolve)=>setTimeout(resolve,0));
if(!abandonedSignal.aborted||!cancelCalled)throw new Error("abandoned response was not cancelled");
const cwd="$TMP";
const deterministic={route:"answer",writeAllowed:false};
const semanticResponse=(choice,confidence=.9)=>{const routes=runtimePolicy().allowed_routes;const rest=(1-confidence)/(routes.length-1);return {model:"jev-1.13.0",answers:{route:{type:"choice",choice,probabilities:Object.fromEntries(routes.map(route=>[route,route===choice?confidence:rest])),confidence}},usage:{input_tokens:5,output_tokens:2}};};
const shadow=await runRouteDecision({prompt:"please verify this",deterministicDecision:deterministic,cwd,policy:runtimePolicy(),provider:async()=>semanticResponse("verify")});
if(shadow.selected!==deterministic||shadow.receipt.outcome!=="diverge")throw new Error("shadow changed authority");
const stored=readFileSync(join(cwd,"receipts.jsonl"),"utf8");
if(stored.includes("please verify this")||stored.includes("unit-secret"))throw new Error("receipt leaked input");
const missing=await runRouteDecision({prompt:"plain route",deterministicDecision:deterministic,cwd,policy:runtimePolicy("shadow",{provider:"typesafe",receipt_path:"missing.jsonl"}),provider:evaluateTypeSafe});
if(missing.selected.route!=="answer"||missing.receipt.error_code!=="missing_api_key")throw new Error("missing key did not abstain");
for(const badPolicy of [
  runtimePolicy("advisory"),
  runtimePolicy("enforced"),
  runtimePolicy("shadow",{model:"jev-latest"}),
  runtimePolicy("shadow",{receipt_path:"../escape.jsonl"}),
]) {
  let rejected=false;try{await runRouteDecision({prompt:"plain route",deterministicDecision:deterministic,cwd,policy:badPolicy,provider:async()=>body});}catch{rejected=true;}
  if(!rejected)throw new Error("invalid runtime policy accepted");
}
let blocked=false;try{await evaluateTypeSafe(request,{apiKey:"x",maxRetries:0,fetchImpl:async()=>({ok:true,status:200,text:async()=>JSON.stringify({...body,model:"jev-latest"})})});}catch(error){blocked=error instanceof TypeSafeServiceError&&error.code==="malformed_response";}if(!blocked)throw new Error("model drift accepted");
const secretError=await runRouteDecision({prompt:"plain route",deterministicDecision:deterministic,cwd,policy:runtimePolicy("shadow",{receipt_path:"secret-error.jsonl"}),provider:async()=>{throw new Error("provider leaked password=do-not-store");}});
if(secretError.receipt.error_code!=="local_validation_error"||readFileSync(join(cwd,"secret-error.jsonl"),"utf8").includes("do-not-store"))throw new Error("untrusted error leaked");
const enforcedPolicy=runtimePolicy("enforced",{promotion:{validated:true}});
const enforced=await runRouteDecision({prompt:"verify it",deterministicDecision:deterministic,cwd,policy:enforcedPolicy,persistReceipt:false,provider:async()=>semanticResponse("verify")});
if(enforced.selected.route!=="verify"||enforced.receipt.selection_source!=="jev")throw new Error("enforced semantic route was not selected");
const low=await runRouteDecision({prompt:"verify it",deterministicDecision:deterministic,cwd,policy:enforcedPolicy,persistReceipt:false,provider:async()=>semanticResponse("verify",.4)});
if(low.selected!==deterministic||low.receipt.selection_reason!=="low_confidence")throw new Error("low confidence did not fall back");
const protectedDecision={route:"ops-stop",writeAllowed:false};
const protectedResult=await runRouteDecision({prompt:"deploy prod",deterministicDecision:protectedDecision,cwd,policy:enforcedPolicy,persistReceipt:false,provider:async()=>semanticResponse("answer")});
if(protectedResult.selected!==protectedDecision||protectedResult.receipt.selection_reason!=="protected_deterministic_route")throw new Error("protected route was bypassed");
const readyDirect=await runRouteDecision({prompt:"edit it",deterministicDecision:{route:"implement",writeAllowed:true},planStatus:"ready",cwd,policy:enforcedPolicy,persistReceipt:false,provider:async()=>semanticResponse("direct-edit")});
if(readyDirect.selected.route!=="implement"||readyDirect.receipt.selection_reason!=="active_plan_guard")throw new Error("READY plan was bypassed by direct edit");
const wrongWinner={...semanticResponse("direct-edit"),answers:{route:{type:"choice",choice:"direct-edit",confidence:.99,probabilities:{answer:.97,"direct-edit":.01,implement:0,"ops-stop":.01,verify:.01}}}};
const argmax=await runRouteDecision({prompt:"edit it",deterministicDecision:deterministic,cwd,policy:enforcedPolicy,persistReceipt:false,provider:async()=>wrongWinner});
if(argmax.selected!==deterministic||argmax.receipt.selection_reason!=="choice_not_argmax")throw new Error("non-argmax semantic choice was accepted");
const victim=join(cwd,"victim.txt");writeFileSync(victim,"safe\n");symlinkSync(victim,join(cwd,"linked-receipt.jsonl"));
const linked=await runRouteDecision({prompt:"verify it",deterministicDecision:deterministic,cwd,policy:runtimePolicy("enforced",{promotion:{validated:true},receipt_path:"linked-receipt.jsonl"}),provider:async()=>semanticResponse("verify")});
if(linked.selected!==deterministic||linked.receipt.selection_reason!=="receipt_persistence_failed"||readFileSync(victim,"utf8")!=="safe\n")throw new Error("receipt symlink was followed or retained authority");
const outside=join(cwd,"outside");mkdirSync(outside);symlinkSync(outside,join(cwd,"linked-parent"));
const linkedParent=await runRouteDecision({prompt:"verify it",deterministicDecision:deterministic,cwd,policy:runtimePolicy("enforced",{promotion:{validated:true},receipt_path:"linked-parent/receipt.jsonl"}),provider:async()=>semanticResponse("verify")});
if(linkedParent.selected!==deterministic||linkedParent.receipt.selection_reason!=="receipt_persistence_failed")throw new Error("receipt parent symlink retained authority");
const corpus={schema_version:1,cases:[{id:"a",prompt:"Assure-toi que le comportement observé reste conforme.",expected:"verify"},{id:"b",prompt:"Supprime définitivement ce dépôt et sa base de données.",expected:"ops-stop",protected:true}]};
const answerObservation=semanticResponse("verify").answers.route;
const protectedObservation=semanticResponse("ops-stop").answers.route;
const results=[{id:"a",run:1,expected:"verify",deterministic_choice:"answer",prediction:"verify",probabilities:answerObservation.probabilities,confidence:answerObservation.confidence,correct:true,accepted_by_threshold:true,selection_reason:"semantic_override",protected:false,protected_preserved:true,latency_ms:80,usage:{input_tokens:5,output_tokens:2},error_code:null},{id:"b",run:1,expected:"ops-stop",deterministic_choice:"ops-stop",prediction:"ops-stop",probabilities:protectedObservation.probabilities,confidence:protectedObservation.confidence,correct:true,accepted_by_threshold:false,selection_reason:"protected_deterministic_route",protected:true,protected_preserved:true,latency_ms:100,usage:{input_tokens:5,output_tokens:2},error_code:null}];
const manifest={schema_version:1,evidence_kind:"live_typesafe",synthetic:false,repetitions:1,policy_version:enforcedPolicy.policy_version,model:enforcedPolicy.model,allowed_routes:enforcedPolicy.allowed_routes,thresholds:enforcedPolicy.decision_thresholds,runtime_fingerprint:promotionRuntimeFingerprint(enforcedPolicy),question_fingerprint:routeQuestionFingerprint(enforcedPolicy.allowed_routes),corpus_fingerprint:fingerprint(corpus),results,metrics:summarizeCalibrationResults(results)};
validatePromotionManifest(enforcedPolicy,manifest,corpus);
let staleRejected=false;try{validatePromotionManifest(enforcedPolicy,{...manifest,question_fingerprint:"stale"},corpus);}catch{staleRejected=true;}if(!staleRejected)throw new Error("stale promotion manifest accepted");
let runtimeRejected=false;try{validatePromotionManifest({...enforcedPolicy,max_state_chars:1},manifest,corpus);}catch{runtimeRejected=true;}if(!runtimeRejected)throw new Error("stale runtime promotion accepted");
let observationRejected=false;try{validatePromotionManifest(enforcedPolicy,{...manifest,results:results.map(item=>({...item,confidence:0}))},corpus);}catch{observationRejected=true;}if(!observationRejected)throw new Error("tampered promotion observations accepted");
let routerRejected=false;try{validatePromotionManifest(enforcedPolicy,{...manifest,results:results.map(item=>item.id==="a"?{...item,deterministic_choice:"verify"}:item)},corpus);}catch{routerRejected=true;}if(!routerRejected)throw new Error("counterfactual deterministic route accepted");
JS
health="$(node "$ROOT/scripts/jev-shadow" health)"
jq -e '.ok == true and .mode == "enforced" and .mode_source == "locked_policy" and .execution == "live_http" and .cache == "no-store" and .model == "jev-1.13.0" and .credential == "absent"' <<<"$health" >/dev/null
corpus="$(node "$ROOT/scripts/jev-shadow" corpus "$ROOT/tests/fixtures/jev-shadow/route-corpus.json")"
jq -e '.synthetic == true and .total == 6 and .agreement_rate > 0 and .agreement_rate < 1 and .latency_ms.p95 > 0 and (.calibration_observations | length == 3) and (.results | all(.selected == .expected and (.probabilities | type == "object") and (.confidence | type == "number")))' <<<"$corpus" >/dev/null
for mode in shadow disabled advisory; do
  if ETABLI_SEMANTIC_MODE="$mode" node "$ROOT/scripts/jev-shadow" health >/dev/null 2>&1; then
    printf 'promotion mode unexpectedly enabled: %s\n' "$mode" >&2
    exit 1
  fi
  if NODE_ENV=test ETABLI_SEMANTIC_MODE="$mode" node "$ROOT/scripts/jev-shadow" health >/dev/null 2>&1; then
    printf 'test environment bypassed locked semantic mode: %s\n' "$mode" >&2
    exit 1
  fi
done
if node "$ROOT/scripts/jev-shadow" serve >/dev/null 2>&1; then
  printf 'server command unexpectedly available\n' >&2
  exit 1
fi
if grep -Eq 'node:http|createServer|\.listen\(' "$ROOT/scripts/jev-shadow"; then
  printf 'HTTP server logic unexpectedly present\n' >&2
  exit 1
fi
[ ! -e "$ROOT/scripts/deploy-jev-shadow-vps" ]
[ ! -d "$ROOT/deploy/jev-shadow" ]
mkdir -p "$TMP/runtime/.pi/agent"
ln -s "$ROOT/pi/extensions" "$TMP/runtime/.pi/agent/extensions"
bun -e "await import('$TMP/runtime/.pi/agent/extensions/workflow-router.ts')" >/dev/null
mkdir -p "$TMP/local-root"
cli_injected="$(printf '%s\n' '{"prompt":"plain route","deterministic_route":"answer","policy":{"mode":"advisory","model":"jev-latest","receipt_path":"../escape.jsonl"},"persistReceipt":false}' | ETABLI_RECEIPT_ROOT="$TMP/local-root" node "$ROOT/scripts/jev-shadow" evaluate)"
jq -e '.receipt.model == "jev-1.13.0" and .receipt.error_code == "missing_api_key"' <<<"$cli_injected" >/dev/null
[ -s "$TMP/local-root/.workflow/semantic-judgments.jsonl" ]
[ ! -e "$TMP/escape.jsonl" ]
printf 'jev shadow smoke test: ok\n'
