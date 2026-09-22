import test from "node:test";
import assert from "node:assert/strict";
import { evaluateTypeSafe } from "../pi/extensions/lib/typesafe-system-one.mjs";
const request={model:"jev-1.13.0",state:{text:"fixture"},questions:{safe:{type:"noul",instructions:"Safe?"}}};
test("total deadline includes backoff and does not start a late retry",async()=>{
 let calls=0;
 await assert.rejects(evaluateTypeSafe(request,{apiKey:"fixture",timeoutMs:1000,totalTimeoutMs:15,maxRetries:1,
  fetchImpl:async()=>{calls++;return {ok:false,status:429,headers:{get:()=>"5"}};}}),error=>error.code==="total_timeout");
 assert.equal(calls,1);
});
test("abort interrupts provider wait and propagates to fetch",async()=>{
 const abort=new AbortController(); let signal;
 const pending=evaluateTypeSafe(request,{apiKey:"fixture",timeoutMs:1000,signal:abort.signal,fetchImpl:async(_u,init)=>{signal=init.signal;return new Promise(()=>{});}});
 abort.abort();await assert.rejects(pending,e=>e.code==="aborted");assert.equal(signal.aborted,true);
});

test("attempt observer separates retry waiting without copying provider content",async()=>{
 const stages=[];let calls=0;
 await evaluateTypeSafe(request,{apiKey:"fixture",maxRetries:1,sleep:async()=>{},onAttempt:e=>stages.push(e),fetchImpl:async()=>{
  calls++;return calls===1?{ok:false,status:429,headers:{get:()=>"0"}}:new Response(JSON.stringify({model:request.model,answers:{safe:{type:"noul",noul:1}},usage:{input_tokens:1,output_tokens:1}}));
 }});
 assert.equal(stages.filter(e=>e.stage==="attempt_started").length,2);assert.ok(stages.some(e=>e.stage==="backoff"));assert.ok(!JSON.stringify(stages).includes("fixture"));
});
