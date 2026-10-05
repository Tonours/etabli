import test from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync, symlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { planMutationGuardDecision } from "../workflow/runtime/workflow-router-core.mjs";
import { planContract, evaluatePlanReview, planReviewPermission } from "../scripts/lib/plan-review-binding.mjs";
import { parseChecks, evaluateReadyPlan } from "../scripts/lib/plan-check-freeze.mjs";
const plan = readFileSync(new URL("./fixtures/execution-quality/ready-plan.md", import.meta.url), "utf8");
const entry = (event,detail) => ({schema_version:2,ts:"2026-10-02T10:00:00Z",run:"fixture",event,detail});
export function fixture(rows) {
 const root=mkdtempSync(join(tmpdir(),"plan-binding-"));
 mkdirSync(join(root,".workflow/fixture"),{recursive:true});
 writeFileSync(join(root,"PLAN.md"),plan);
 writeFileSync(join(root,".workflow/active-run.json"),JSON.stringify({schema_version:1,run:"fixture"}));
 writeFileSync(join(root,".workflow/fixture/events.jsonl"),rows.map(JSON.stringify).join("\n")+"\n");
 return root;
}
test("ready_without_review: both adapters reject newly bound READY",()=>{
 assert.equal(evaluateReadyPlan(plan).ok,true);
 const root=fixture([entry("plan_created",{path:"PLAN.md",status:"READY",plan_contract_sha256:"0".repeat(64)})]);
 try {
  for(const tool_name of ["Write","write"]) {
   const result=planMutationGuardDecision({cwd:root,tool_name,tool_input:{file_path:"app.mjs",content:"changed"}});
   assert.equal(result?.hookSpecificOutput?.permissionDecision,"deny");
  }
 } finally {rmSync(root,{recursive:true,force:true});}
});

const provenance={requested:{family:"fixture",model:"fixture",provider:"fixture"},effective:{family:"fixture",model:"fixture",provider:"fixture"},runner:"fixture",run_id:"fixture"};
const binding=()=>entry("plan_created",{path:"PLAN.md",status:"READY",plan_contract_sha256:planContract(plan).contract_sha256});
const approval=(verdict="READY",hash=planContract(plan).contract_sha256)=>entry("adversary_completed",{mode:"plan",verdict,plan_contract_sha256:hash,accepted_findings:[],rejected_findings:[],model_provenance:provenance});
for(const [id,replacement] of [
 ["decision_change",["Keep caller behavior stable.","Change caller behavior."]],
 ["scope_change",["app.mjs and its tests","app.mjs, auth.mjs and their tests"]],
 ["check_change",["syntax passes","syntax and runtime pass"]],
 ["approach_change",["Enumerate valid and invalid boundaries","Ignore invalid boundaries"]],
 ["workflow_contract_change",["focused checks and reviewed closure pass","syntax alone passes"]],
 ["product_required_change",["Required: no","Required: yes"]],
]) test(id,()=>assert.notEqual(planContract(plan.replace(...replacement)).contract_sha256,planContract(plan).contract_sha256));
test("progress_only: only owned result fields and task completion are ignored",()=>{
 const next=plan.replace("Status: READY","Status: CHALLENGED").replace("Last revised: 2026-10-02","Last revised: 2026-10-03").replace("Archive: pending until implemented and validated","Archive: docs/plan/fixture.md").replace("[ ] AC1","[x] AC1").replace("last run: pending","last run: passed with fixture");
 assert.equal(planContract(next).contract_sha256,planContract(plan).contract_sha256);
 assert.notEqual(planContract(plan.replace("AC1: Preserve","AC1: Change")).contract_sha256,planContract(plan).contract_sha256);
});
test("owned check progress preserves binding for the resolver heading aliases",()=>{
 for(const title of ["Checks","Validation Plan","Checks (release)","Validation Plan: release"]) {
  const before=plan.replace("## Checks",`## ${title}`),hash=planContract(before).contract_sha256;
  const after=before.replace("last run: pending","last run: passed");
  assert.equal(evaluateReadyPlan(before).ok,true,title);
  assert.equal(evaluateReadyPlan(after).ok,true,title);
  assert.deepEqual(parseChecks(after),parseChecks(before),title);
  const rows=[entry("plan_created",{path:"PLAN.md",status:"READY",plan_contract_sha256:hash}),approval("READY",hash)];
  assert.equal(planContract(after).contract_sha256,hash,title);
  assert.equal(evaluatePlanReview(rows,after).ok,true,title);
  assert.notEqual(planContract(before.replace("syntax passes","different output")).contract_sha256,hash,title);
  const nested=before.replace("  - last run: pending","  - last run: pending\n    - Retain this decision.");
  assert.notEqual(planContract(nested).contract_sha256,planContract(nested.replace("last run: pending","last run: passed")).contract_sha256,title);
 }
 for(const title of ["ChecksLog","Validation Plans","Notes / Handoff","Product Verification"]) {
  const before=plan.replace("## Checks",`## ${title}`);
  assert.notEqual(planContract(before).contract_sha256,planContract(before.replace("last run: pending","last run: passed")).contract_sha256,title);
 }
});
for(const section of ["Review Changes","Notes / Handoff","Unknown decisions"]) test(`unknown_section_change: ${section}`,()=>{
 const before=plan+`\n## ${section}\n- Keep authentication.\n`;
 assert.notEqual(planContract(before).contract_sha256,planContract(before.replace("Keep authentication.","Remove authentication.")).contract_sha256);
});
test("markdown_code_example: fenced headings and task markers remain material",()=>{
 const before=plan+"\n## Examples\n```md\n## Meta\n- Status: READY\n- [ ] Keep this literal.\n```\n";
 assert.notEqual(planContract(before).contract_sha256,planContract(before.replace("[ ] Keep this literal.","[x] Keep this literal.")).contract_sha256);
 assert.notEqual(planContract(before).contract_sha256,planContract(before.replace("Status: READY\n- [ ] Keep","Status: DRAFT\n- [ ] Keep")).contract_sha256);
 const linked=plan.replace("Keep caller behavior stable.","Keep [caller](https://example.invalid/a).");
 assert.notEqual(planContract(linked).contract_sha256,planContract(linked.replace("invalid/a","invalid/b")).contract_sha256);
});
test("matching_plan_verdict and challenged_after_ready: use latest verdict",()=>{
 assert.equal(evaluatePlanReview([binding(),approval()],plan).ok,true);
 assert.equal(evaluatePlanReview([binding(),approval(),approval("CHALLENGED")],plan).ok,false);
 assert.equal(evaluatePlanReview([binding(),approval("READY","0".repeat(64))],plan).reason,"stale_plan_review");
 const bad=approval();bad.detail.accepted_findings=[{finding:"open blocker",blocking:true}];
 assert.equal(evaluatePlanReview([binding(),bad],plan).ok,false);
 assert.equal(evaluatePlanReview([entry("plan_created",{path:"PLAN.md",status:"READY",plan_contract_sha256:null})],plan).ok,false);
});
test("legacy_unbound and invalid_active_state are distinct",()=>{
 const root=fixture([entry("plan_created",{path:"PLAN.md",status:"READY"})]);
 try {
  assert.equal(planReviewPermission(root,plan).mode,"legacy-unbound");
  writeFileSync(join(root,".workflow/active-run.json"),"bad");
  assert.equal(planReviewPermission(root,plan).ok,false);
  rmSync(join(root,".workflow/active-run.json"));rmSync(join(root,".workflow/fixture"),{recursive:true});
  assert.equal(planReviewPermission(root,plan).mode,"legacy-no-ledger");
 } finally {rmSync(root,{recursive:true,force:true});}
});
test("matching_plan_verdict: actual guard permits approved current contract",()=>{
 const root=fixture([binding(),approval()]);
 try {
  assert.equal(planMutationGuardDecision({cwd:root,tool_name:"Write",tool_input:{file_path:"app.mjs",content:"changed"}}),null);
  writeFileSync(join(root,"PLAN.md"),plan.replace("Keep caller behavior stable.","Change caller behavior."));
  assert.equal(planMutationGuardDecision({cwd:root,tool_name:"Write",tool_input:{file_path:"app.mjs",content:"changed"}})?.hookSpecificOutput?.permissionDecision,"deny");
 } finally {rmSync(root,{recursive:true,force:true});}
});
test("review_bootstrap and review_bootstrap_escape: confined artifacts and fixed argv",()=>{
 const root=fixture([binding()]);
 const run=".workflow/fixture", hunter=new URL("../scripts/pi-review-hunter",import.meta.url).pathname;
 try {
  const write=path=>planMutationGuardDecision({cwd:root,tool_name:"Write",tool_input:{file_path:path,content:"prompt"}});
  assert.equal(write(`${run}/prompt.md`),null);
  assert.equal(write(`${run}/events.jsonl`)?.hookSpecificOutput?.permissionDecision,"deny");
  writeFileSync(join(root,run,"prompt.md"),"read only");writeFileSync(join(root,run,"plan.patch"),plan);
  const command=`${hunter} --prompt-file ${run}/prompt.md --patch ${run}/plan.patch --capture-dir ${run}/r1 --pass-id plan-r1 --role adversary-plan`;
  const bash=command=>planMutationGuardDecision({cwd:root,tool_name:"Bash",tool_input:{command}});
  assert.equal(bash(command),null);assert.equal(bash(`rtk proxy ${command}`),null);
  assert.equal(bash(command.replace(`${run}/plan.patch`,"PLAN.md")),null);
  const check=new URL("../scripts/plan-review-check",import.meta.url).pathname;
  assert.equal(bash(`${check} --hash PLAN.md`),null);
  assert.equal(bash(`rtk proxy node ${check} --hash PLAN.md`),null);
  assert.equal(bash(`bash ${check} --hash PLAN.md`)?.hookSpecificOutput?.permissionDecision,"deny");
  assert.equal(bash(`node ${command}`)?.hookSpecificOutput?.permissionDecision,"deny");
  for(const invalid of [command+"; touch outside",command.replace("adversary-plan","logic"),command.replace(`${run}/r1`,"../outside"),command+" --sources-file other.json"]) assert.equal(bash(invalid)?.hookSpecificOutput?.permissionDecision,"deny");
  writeFileSync(join(root,run,"file"),"regular");
  assert.equal(write(`${run}/file/prompt.md`)?.hookSpecificOutput?.permissionDecision,"deny");
  symlinkSync(root,join(root,run,"link"));assert.equal(write(`${run}/link/prompt.md`)?.hookSpecificOutput?.permissionDecision,"deny");
 } finally {rmSync(root,{recursive:true,force:true});}
});

test("bookkeeping descendants and continuations remain material",()=>{
 for(const next of [
  plan.replace("last run: pending","last run: pending\n      - command: node extra-check.mjs\n        - expected: extra behavior passes"),
  plan.replace("Last revised: 2026-10-02","Last revised: 2026-10-02\n  Deployment is authorized now."),
 ]) {
  assert.notEqual(planContract(next).contract_sha256,planContract(plan).contract_sha256);
  assert.equal(evaluatePlanReview([binding(),approval()],next).reason,"stale_plan_review");
 }
 assert.notDeepEqual(parseChecks(plan.replace("last run: pending","last run: pending\n      - command: node extra-check.mjs\n        - expected: extra behavior passes")),parseChecks(plan));
});

test("symlinked root plan does not provide READY authority",()=>{
 const root=fixture([binding(),approval()]);
 try {
  rmSync(join(root,"PLAN.md"));writeFileSync(join(root,"linked.md"),plan);symlinkSync("linked.md",join(root,"PLAN.md"));
  assert.equal(planMutationGuardDecision({cwd:root,tool_name:"Write",tool_input:{file_path:"app.mjs",content:"changed"}})?.hookSpecificOutput?.permissionDecision,"deny");
 } finally {rmSync(root,{recursive:true,force:true});}
});

test("command source escapes in Checks and Steps remain material",()=>{
 for(const [before,after] of [
  [plan.replace("node --check app.mjs", "printf %s \\*"),plan.replace("node --check app.mjs", "printf %s *")],
  [plan.replace("1. Correct the module and verify its callers.", "1. Run node fix.mjs --files \\*"),plan.replace("1. Correct the module and verify its callers.", "1. Run node fix.mjs --files *")],
  [plan+"\n[domain]: /allowed \"boundaries\"\n",plan+"\n[domain]: /other \"boundaries\"\n"],
 ]) {
  assert.notEqual(planContract(before).contract_sha256,planContract(after).contract_sha256);
  assert.equal(evaluatePlanReview([binding(),approval("READY",planContract(before).contract_sha256)],after).reason,"stale_plan_review");
 }
});
test("first last-run result has no contract effect",()=>{
 const before=plan.replace("  - expected: syntax passes\n  - last run: pending\n","");
 const after=before.replace("- command: node --check app.mjs","- command: node --check app.mjs\n  - last run: syntax passed");
 assert.equal(planContract(before).contract_sha256,planContract(after).contract_sha256);
 assert.equal(evaluatePlanReview([binding(),approval("READY",planContract(before).contract_sha256)],after).ok,true);
});
test("bootstrap rejects expansions and retains quoted literal paths",()=>{
 const root=fixture([binding()]),run=".workflow/fixture",hunter=new URL("../scripts/pi-review-hunter",import.meta.url).pathname;
 try {
  writeFileSync(join(root,run,"prompt.md"),"read only");symlinkSync(root,join(root,run,"1"));
  const command=`${hunter} --prompt-file ${run}/prompt.md --patch PLAN.md --capture-dir ${run}/DEST/capture --pass-id plan-r1 --role adversary-plan`;
  const bash=cmd=>planMutationGuardDecision({cwd:root,tool_name:"Bash",tool_input:{command:cmd}});
  for(const destination of ["{1..1}","*","?","[1]","~","$(pwd)"])
   assert.equal(bash(command.replace("DEST",destination))?.hookSpecificOutput?.permissionDecision,"deny",destination);
  mkdirSync(join(root,run,"{literal}"));
  assert.equal(bash(command.replace(`${run}/DEST/capture`,`'${run}/{literal}/capture'`)),null);
 } finally {rmSync(root,{recursive:true,force:true});}
});
test("invalid UTF-8 plan cannot provide READY authority",()=>{
 const root=fixture([binding(),approval()]);
 try {
  writeFileSync(join(root,"PLAN.md"),Buffer.concat([Buffer.from(plan),Buffer.from([0xff])]));
  assert.equal(planMutationGuardDecision({cwd:root,tool_name:"Write",tool_input:{file_path:"app.mjs",content:"changed"}})?.hookSpecificOutput?.permissionDecision,"deny");
 } finally {rmSync(root,{recursive:true,force:true});}
});
