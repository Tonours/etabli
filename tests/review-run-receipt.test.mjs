import test from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, readFileSync, mkdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { aggregateReviewRuns, reviewRunReceipt, sha256 } from "../scripts/lib/review-run-receipt.mjs";
const events = (responseId = "provider-1") => [{ type: "message_end", message: { role: "assistant", responseId, model: "fixture", provider: "fixture", stopReason: "stop", content: [{ type: "text", text: "Axis: Logic\nNo findings" }], usage: { input: 10, output: 3, cacheRead: 7, cacheWrite: 0, totalTokens: 20 } } }];
const make = (passId, parentId = null) => ({child_inventory:{status:"complete",evidence:"fixture dispatch inventory"},...reviewRunReceipt({ passId, parentId, role: "logic", patchSha256: sha256("patch"), events: events(passId), exitCode: 0, elapsedMs: 10 })});
const expected = (records) => records.map(({ pass_id, parent_id, role, patch_sha256 }) => ({ pass_id, parent_id, role, patch_sha256 }));
test("chain requires every dispatched child and binds its patch", () => {
 const rows = [make("a"), make("b", "a")], manifest = expected(rows);
 assert.equal(aggregateReviewRuns(manifest, rows).total_tokens, 40);
 assert.equal(aggregateReviewRuns(manifest, rows.slice(0,1)).total_tokens, null);
 assert.equal(aggregateReviewRuns(manifest, [{ ...rows[0], patch_sha256: sha256("changed") }, rows[1]]).measured, false);
 assert.equal(aggregateReviewRuns(manifest, [...rows, rows[0]]).measured, false);
 rows[1].receipts = rows[0].receipts;
 assert.equal(aggregateReviewRuns(manifest, rows).measured, false);
});
test("failed provider retains known usage but never certifies review completion", () => {
 const r = make("a"); r.terminal = "failed";
 const result = aggregateReviewRuns(expected([r]), [r]);
 assert.equal(result.known_tokens,20); assert.equal(result.measured,false);
});
test("capture runs isolated Pi argv and keeps native receipt separate from final text", () => {
 const root=mkdtempSync(join(tmpdir(),"review-capture-")); mkdirSync(join(root,"bin"));
 writeFileSync(join(root,"prompt"),"hunt"); writeFileSync(join(root,"patch"),"patch");
 writeFileSync(join(root,"bin/pi"), `#!/usr/bin/env node
 const fs=require("node:fs"),args=process.argv.slice(2);
 fs.writeFileSync(${JSON.stringify(join(root,"patch"))},"changed after capture");
 fs.writeFileSync(${JSON.stringify(join(root,"prompt"))},"changed after capture");
 const patch=args.find(value=>value.startsWith("@")).slice(1);
 const prompt=args[args.indexOf("--append-system-prompt")+1];
 if(fs.readFileSync(patch,"utf8")!=="patch" || fs.readFileSync(prompt,"utf8")!=="hunt")process.exit(9);
 process.stdout.write(${JSON.stringify(JSON.stringify(events()[0])+"\n")});
 `, {mode:0o700});
 const out=join(root,"run");
 const result=spawnSync("bash",[resolve("scripts/pi-review-hunter"),"--prompt-file",join(root,"prompt"),"--patch",join(root,"patch"),"--capture-dir",out,"--pass-id","test","--role","logic"],{encoding:"utf8",env:{...process.env,PATH:`${join(root,"bin")}:${process.env.PATH}`}});
 assert.equal(result.status,0,result.stderr); assert.match(result.stdout,/Axis: Logic/);
 const receipt=JSON.parse(readFileSync(join(out,"receipt.json"))); assert.equal(receipt.usage.total_tokens,20); assert.equal(receipt.prompt_inventory_scope,"supplied_inputs_only");
 assert.equal(receipt.effective_system_prompt,"unknown");
 assert.match(receipt.capture_id,/^[a-f0-9]{64}$/);assert.match(receipt.input_context_sha256,/^[a-f0-9]{64}$/);
 assert.equal(receipt.context_sha256,undefined);
 assert.equal(receipt.patch_sha256,sha256("patch"));
 assert.equal(readFileSync(join(out,"input.patch"),"utf8"),"patch");
});

test("prompt observer inventories assembled blocks without raw prompts or headers", async () => {
 const {promptInventory}=await import("../scripts/lib/review-prompt-observer.mjs");
 const r=promptInventory({type:"before_provider_request",payload:{system:"private instructions",messages:[{role:"user",content:"private code"}],tools:[{name:"read"}],headers:{authorization:"private"}}});
 assert.deepEqual(r.blocks.map(b=>b.kind),["system","messages","tools"]);
 assert.ok(!JSON.stringify(r).includes("private"));assert.equal(r.token_estimate,null);
});

test("chain reconciles a parent's unknown child coverage only with dispatched child receipts",()=>{
 const native=events("parent-response");
 native[0].message.content.unshift({type:"toolCall",id:"dispatch",name:"bash",arguments:{command:"scripts/pi-review-hunter --patch patch --prompt-file prompt"}});
 const parent=reviewRunReceipt({passId:"parent",role:"parent",patchSha256:sha256("patch"),events:native,exitCode:0,elapsedMs:20});
 const child=make("child","parent");
 const inventory=expected([parent,child]);inventory[1].dispatch_id="dispatch";
 assert.equal(parent.measured,false);
 parent.child_inventory={status:"complete",evidence:"fixture native dispatch inventory"};
 assert.equal(aggregateReviewRuns(inventory,[parent,child]).total_tokens,40);
 assert.equal(aggregateReviewRuns(expected([parent,child]),[parent]).total_tokens,null);
 parent.observed_child_dispatches.push({dispatch_id:"second-dispatch"});
 assert.equal(aggregateReviewRuns(inventory,[parent,child]).measured,false);
});

test("parent silence is unknown until an authoritative dispatch inventory or isolated capability is supplied",async()=>{
 const {piEventCoverage}=await import("../scripts/lib/harness-token-usage.mjs");
 assert.equal(piEventCoverage(events()).child.status,"unknown");
 assert.equal(piEventCoverage(events(),{childScope:"isolated_read_grep"}).child.status,"not_triggered");
});

test("exact source inventory binds role, line ranges and explicit obligations to assembled payload",async()=>{
 const {reviewPromptSources}=await import("../scripts/lib/review-prompt-sources.mjs");
 const {promptInventory}=await import("../scripts/lib/review-prompt-observer.mjs");
 const root=mkdtempSync(join(tmpdir(),"review-source-"));
 writeFileSync(join(root,"PLAN.md"),"# Scope\n- [ ] A1. Preserve auth guard\nOther text\n");
 const origins=reviewPromptSources(root,[{kind:"plan",path:"PLAN.md",start:2,end:2}]);
 const metadata=promptInventory({type:"before_provider_request",payload:{messages:[{content:origins[0].text}]}},{origins,role:"spec"});
 assert.equal(metadata.role,"spec");assert.equal(metadata.source_coverage,"declared_sources_observed");
 assert.equal(metadata.sources[0].start,2);assert.equal(metadata.sources[0].obligations[0].line,2);
 assert.ok(!JSON.stringify(metadata).includes("Preserve auth"));
 assert.equal(promptInventory({type:"before_provider_request",payload:{messages:[{content:"changed"}]}},{origins}).source_coverage,"unknown");
});

test("timing separates observed request intervals, preparation and unknown provider internals",async()=>{
 const {reviewTiming}=await import("../scripts/lib/review-timing.mjs");
 const inventory=[{stage:"before_agent_start",observed_at_ms:10},
  {stage:"before_provider_request",observed_at_ms:15,call_index:1,blocks:[{bytes:20}]},
  {stage:"assistant_message_end",observed_at_ms:35,call_index:1}];
 const timing=reviewTiming(inventory,{preparationMs:3,totalMs:50});
 assert.equal(timing.calls[0].request_to_message_end_ms,20);
 assert.equal(timing.agent_start_to_first_request_ms,5);assert.equal(timing.model_compute_ms,null);
 assert.equal(reviewTiming(inventory.slice(0,2)).coverage,"unknown");
});

test("empty dispatch lists do not certify unknown parent child coverage",()=>{
 const parent=reviewRunReceipt({passId:"parent",role:"parent",patchSha256:sha256("patch"),events:events("parent-response"),exitCode:0,elapsedMs:20});
 assert.equal(aggregateReviewRuns(expected([parent]),[parent]).measured,false);
 parent.child_inventory={status:"complete",evidence:"native dispatch ledger includes zero admitted children"};
 assert.equal(aggregateReviewRuns(expected([parent]),[parent]).measured,true);
});

test("direct capture binds alternate path spellings before the child starts",()=>{
 const root=mkdtempSync(join(tmpdir(),"review-capture-path-"));mkdirSync(join(root,"bin"));
 writeFileSync(join(root,"prompt"),"hunt");writeFileSync(join(root,"patch"),"patch");
 writeFileSync(join(root,"bin/pi"),`#!/usr/bin/env node
 const fs=require('node:fs'),args=process.argv.slice(2);
 fs.writeFileSync('patch','mutated');fs.writeFileSync('prompt','mutated');
 const patch=args.find(arg=>arg.startsWith('@')).slice(1),prompt=args[args.indexOf('--append-system-prompt')+1];
 if(fs.readFileSync(patch,'utf8')!=='patch'||fs.readFileSync(prompt,'utf8')!=='hunt')process.exit(9);
 process.stdout.write(${JSON.stringify(JSON.stringify(events()[0])+"\n")});
 `,{mode:0o700});
 const result=spawnSync(process.execPath,[resolve("scripts/review-hunter-capture"),"--directory",join(root,"run"),"--patch",join(root,"patch"),"--prompt",join(root,"prompt"),"--timeout","10","--pass-id","paths","--role","logic","--","--no-extensions","--no-session","--no-context-files","--no-skills","--tools","read,grep","--append-system-prompt","./prompt","@./patch"],{cwd:root,encoding:"utf8",env:{...process.env,PATH:`${join(root,"bin")}:${process.env.PATH}`}});
 assert.equal(result.status,0,result.stderr);
 const receipt=JSON.parse(readFileSync(join(root,"run/receipt.json")));assert.equal(receipt.isolated_context,true);
});


test("stats-only dispatches require explicit complete one-to-one inventory bindings",()=>{
 const native=[...events("parent-stats"),{type:"agent_end",subagent_stats:{spawned:1}}];
 const parent=reviewRunReceipt({passId:"parent",role:"parent",patchSha256:sha256("patch"),events:native,exitCode:0,elapsedMs:20});
 const child=make("child","parent"),inventory=expected([parent,child]);
 parent.child_inventory={status:"complete",evidence:"native scheduler ledger",stats_bindings:{"stats-1-0":"child"}};
 assert.equal(aggregateReviewRuns(inventory,[parent,child]).total_tokens,40);
 parent.child_inventory.stats_bindings={};assert.equal(aggregateReviewRuns(inventory,[parent,child]).measured,false);
 parent.child_inventory.stats_bindings={"stats-1-0":"absent"};assert.equal(aggregateReviewRuns(inventory,[parent,child]).measured,false);
});

test("prompt inventory preserves completed metadata and flags a truncated tail",async()=>{
 const {parsePromptInventory}=await import("../scripts/lib/review-prompt-observer.mjs");
 assert.deepEqual(parsePromptInventory('{"stage":"before_provider_request"}\n{"stage":'),{rows:[{stage:"before_provider_request"}],complete:false});
 assert.equal(parsePromptInventory('bad\n{"stage":"before_provider_request"}\n').complete,false);
});
