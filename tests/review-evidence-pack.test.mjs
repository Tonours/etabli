import test from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, symlinkSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { execFileSync } from "node:child_process";
import { createReviewEvidencePack, readEvidence, reviewRoleInput, invalidatedEvidence } from "../scripts/lib/review-evidence-pack.mjs";

test("large file supports exact bounded line evidence, not silent truncation", () => {
 const root=mkdtempSync(join(tmpdir(),"pack-"));
 try { writeFileSync(join(root,"large"),"x".repeat(7000)+"\nimportant\n");
  assert.throws(()=>readEvidence(root,"large"),/narrower/);
  const row=readEvidence(root,"large",{start:2,end:2}); assert.equal(row.text,"important"); assert.equal(row.start,2);
  assert.throws(()=>readEvidence(root,"large",{start:99}),/range/);
  symlinkSync("large",join(root,"link")); assert.throws(()=>readEvidence(root,"link"));
 } finally { rmSync(root,{recursive:true,force:true}); }
});
test("cumulative snapshot includes staged, unstaged and new files and invalidates a fix", () => {
 const root=mkdtempSync(join(tmpdir(),"pack-")); const git=(...a)=>execFileSync("git",a,{cwd:root,stdio:"ignore"});
 try { git("init"); git("config","user.name","Fixture"); git("config","user.email","fixture@example.invalid");
  writeFileSync(join(root,"a"),"old\n"); git("add","a"); git("commit","-m","fixture");
  writeFileSync(join(root,"a"),"staged\n"); git("add","a"); writeFileSync(join(root,"a"),"unstaged\n"); writeFileSync(join(root,"new"),"new\n");
  const p=createReviewEvidencePack({root,criteria:["intent"]}); assert.match(p.patch,/unstaged/); assert.equal(p.files.length,2);
  assert.equal(p.files.find(f=>f.path==="new").content,"new\n"); assert.equal(reviewRoleInput(p,"logic").criteria,undefined);
  writeFileSync(join(root,"a"),"fixed\n"); const q=createReviewEvidencePack({root}); assert.deepEqual(invalidatedEvidence(p,q),["a"]);
 } finally {rmSync(root,{recursive:true,force:true});}
});

test("unchanged dependency excerpts are invalidated when their source changes",()=>{
 const previous={files:[],excerpts:[{path:"guard.js",file_sha256:"old"}]};
 const current={files:[],excerpts:[{path:"guard.js",file_sha256:"new"}]};
 assert.deepEqual(invalidatedEvidence(previous,current),["guard.js"]);
});

test("end-only selection bounds both text and its declared range",()=>{
 const root=mkdtempSync(join(tmpdir(),"pack-"));
 try {
  writeFileSync(join(root,"source"),"included\nexcluded\n");
  const row=readEvidence(root,"source",{end:1});
  assert.equal(row.text,"included");
  assert.equal(row.start,1);assert.equal(row.end,1);
  assert.equal(row.excerpt_sha256,readEvidence(root,"source",{start:1,end:1}).excerpt_sha256);
 } finally {rmSync(root,{recursive:true,force:true});}
});
