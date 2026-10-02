import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { chmodSync, existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { test } from "node:test";
import { checkProductCompletion, productContractIdentity, checkProductPlan, frozenProductContract, writeProductCompletion } from "../scripts/lib/project-verification.mjs";
import { inventoryCommand, sha256, sourceInventory, workflowSourceExclusions } from "../scripts/lib/project-verification-source.mjs";
import { evaluateCheckFreeze, parseChecks } from "../scripts/lib/plan-check-freeze.mjs";

const repository = resolve(import.meta.dirname, "..");
function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), "etabli-product-gate-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const git = args => execFileSync("git", args, { cwd: root, stdio: "pipe" });
  git(["init", "-q"]);
  writeFileSync(join(root, ".gitignore"), "PLAN.md\n.workflow/\n");
  writeFileSync(join(root, "app.txt"), "real subject\n");
  git(["add", "."]);
  git(["-c", "user.name=QA fixture", "-c", "user.email=qa@localhost", "commit", "-qm", "test: subject fixture"]);
  const planPath = join(root, "PLAN.md");
  const plan = `# PLAN.md\n\n## Meta\n- Status: READY\n\n## Acceptance Criteria\n- [ ] AC-01 [product]: Visible mutation is persisted. Proof: action,result,side_effect.\n- [ ] AC-02 [process]: Focused checks pass.\n\n## Product Verification\n- Required: yes\n- Evidence pack: .workflow/run/pack.json\n- Subject root: ${root}\n`;
  writeFileSync(planPath, plan);
  const base = join(root, ".workflow/run");
  mkdirSync(join(base, "artifacts"), { recursive: true });
  const manifest = { schema_version: 1, root, git_head: git(["rev-parse", "HEAD"]).toString().trim(), inventory_command: inventoryCommand, exclusions: workflowSourceExclusions, files: sourceInventory(root).map(path => ({ path, sha256: sha256(readFileSync(join(root, path))), mode: lstatSync(join(root, path)).mode & 0o777 })) };
  const artifacts = [];
  function artifact(id, kind, content) {
    const path = `artifacts/${id}.json`;
    writeFileSync(join(base, path), JSON.stringify(content));
    const item = { id, kind, path, sha256: sha256(readFileSync(join(base, path))), captured_at: new Date().toISOString() };
    artifacts.push(item);
    return item;
  }
  const source = artifact("source", "source", manifest);
  const environment = artifact("environment", "source", { node: process.version });
  artifact("execution", "execution_receipt", { run_id: "test-run", source_sha256: source.sha256, environment_sha256: environment.sha256, exit_code: 0 });
  artifact("action", "action", { action: "write value through the user entry point" });
  artifact("outcome", "outcome", { value: "expected" });
  artifact("sql", "side_effect", { persisted: "expected" });
  for (const step of ["launch", "doctor", "isolation", "cleanup"]) artifact(step, step === "cleanup" ? "cleanup" : "execution_receipt", { status: "passed", phases: [step], run_id: "test-run", source_sha256: source.sha256 });
  const passed = step => ({ status: "passed", evidence: [step] });
  const contract = frozenProductContract(plan, planPath);
  const pack = { schema_version: 1, run_id: "test-run", mode: "product", criteria_sha256: contract.criteria_sha256,
    target: { name: "subject", ref: manifest.git_head, subject_path: source.path, subject_sha256: source.sha256, environment_sha256: environment.sha256 }, artifacts,
    execution: { status: "parent_observed", receipt_artifact: "execution", launch: passed("launch"), doctor: passed("doctor"), isolation: passed("isolation"), cleanup: passed("cleanup") },
    scenarios: [{ id: "mutation", criterion_ids: ["AC-01"], outcome: "Expected value persisted", status: "pass", action_evidence: ["action"], result_evidence: ["outcome"], side_effect_expected: true, side_effect_evidence: ["sql"] }] };
  function save() { writeFileSync(contract.pack, JSON.stringify(pack)); }
  save();
  return { root, planPath, plan, base, pack, contract, save, git };
}

test("the deployed checker validates a product pack using its declared runtime", async t => {
  const f = fixture(t);
  const deployed = mkdtempSync(join(tmpdir(), "etabli-deployed-product-"));
  t.after(() => rmSync(deployed, { recursive: true, force: true }));
  execFileSync(join(repository, "scripts/deploy-workflow"), [deployed], { stdio: "pipe" });
  mkdirSync(join(deployed, "pi"), { recursive: true });
  symlinkSync(join(repository, "pi/node_modules"), join(deployed, "pi/node_modules"));
  const result = spawnSync(process.execPath, [join(deployed, "scripts/project-verification-check"), f.planPath], { encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(JSON.parse(result.stdout).status, "passed");
});

test("passing product proof joins criteria, actual source inventory and retained evidence", async t => {
  const f = fixture(t);
  assert.deepEqual((await checkProductPlan(f.planPath)).criteria, ["AC-01"]);
});

for (const [name, mutate] of [
  ["missing criterion", f => { f.pack.scenarios[0].criterion_ids = []; }],
  ["unknown criterion", f => { f.pack.scenarios[0].criterion_ids = ["AC-99"]; }],
  ["failed scenario", f => { f.pack.scenarios[0].status = "fail"; }],
  ["blocked scenario", f => { f.pack.scenarios[0].status = "blocked"; }],
  ["missing result proof", f => { f.pack.scenarios[0].result_evidence = []; }],
  ["source substituted for action", f => { f.pack.scenarios[0].action_evidence = ["source"]; }],
  ["source substituted for result", f => { f.pack.scenarios[0].result_evidence = ["source"]; }],
  ["global receipt substituted for cleanup", f => { f.pack.execution.cleanup.evidence = ["execution"]; }],
  ["global receipt substituted for launch", f => { f.pack.execution.launch.evidence = ["execution"]; }],
  ["launch substituted for doctor", f => { f.pack.execution.doctor.evidence = ["launch"]; }],
  ["doctor substituted for isolation", f => { f.pack.execution.isolation.evidence = ["doctor"]; }],
  ["missing persistence proof", f => { f.pack.scenarios[0].side_effect_evidence = []; }],
  ["unknown artifact", f => { f.pack.scenarios[0].action_evidence = ["missing"]; }],
  ["stale criterion identity", f => { f.pack.criteria_sha256 = "0".repeat(64); }],
  ["integrity-only execution", f => { f.pack.execution.status = "integrity_only"; }],
  ["cleanup not completed", f => { f.pack.execution.cleanup.status = "blocked"; }],
  ["duplicate scenario ID", f => { f.pack.scenarios.push(structuredClone(f.pack.scenarios[0])); }],
  ["duplicate artifact ID", f => { f.pack.artifacts.push(structuredClone(f.pack.artifacts[0])); }],
  ["artifact path escape", f => { f.pack.artifacts[0].path = "../../app.txt"; }],
  ["unexpected schema property", f => { f.pack.claimedSuccess = true; }],
]) {
  test(`gate rejects ${name}`, async t => {
    const f = fixture(t); mutate(f); f.save();
    await assert.rejects(checkProductPlan(f.planPath));
  });
}

for (const [name, mutate] of [
  ["changed source", f => writeFileSync(join(f.root, "app.txt"), "different\n")],
  ["added source", f => writeFileSync(join(f.root, "new.txt"), "new source\n")],
  ["deleted source", f => rmSync(join(f.root, "app.txt"))],
  ["changed mode", f => chmodSync(join(f.root, "app.txt"), 0o755)],
  ["changed evidence", f => writeFileSync(join(f.base, "artifacts/outcome.json"), "{}")],
]) {
  test(`gate rejects ${name}`, async t => {
    const f = fixture(t); mutate(f);
    await assert.rejects(checkProductPlan(f.planPath));
  });
}

test("checkbox updates preserve criterion identity; classification changes do not", t => {
  const f = fixture(t);
  assert.equal(frozenProductContract(f.plan.replace("[ ]", "[x]"), f.planPath).criteria_sha256, f.contract.criteria_sha256);
  assert.notEqual(frozenProductContract(f.plan.replace("[process]", "[judgment]"), f.planPath).criteria_sha256, f.contract.criteria_sha256);
});

test("nested acceptance details stay frozen without becoming duplicate criterion IDs", t => {
  const f = fixture(t);
  const nested = f.plan.replace("Proof: action,result,side_effect.", "Proof: action,result,side_effect.\n  - Covers reload and persisted state.");
  const contract = frozenProductContract(nested, f.planPath);
  assert.deepEqual(contract.criteria.map(c => c.id), ["AC-01"]);
  assert.notEqual(contract.criteria_sha256, f.contract.criteria_sha256);
});

test("completion survives a new commit only when the full source inventory is unchanged", async t => {
  const f = fixture(t);
  mkdirSync(join(f.root, "docs/plan"), { recursive: true });
  const archive = join(f.root, "docs/plan/fixture.md");
  writeFileSync(archive, `# Implemented: gate fixture\n- Source plan: \`PLAN.md\`\n- Status: IMPLEMENTED\n- Source plan SHA-256: \`${sha256(f.plan)}\`\n`);
  await writeProductCompletion(f.planPath, archive);
  f.git(["-c", "user.name=QA fixture", "-c", "user.email=qa@localhost", "commit", "--allow-empty", "-qm", "test: metadata only"]);
  await checkProductCompletion(f.contract.pack + ".completion.json", archive);
  await assert.rejects(checkProductPlan(f.planPath), /Git ref changed/);
  writeFileSync(join(f.root, "app.txt"), "unverified code\n");
  await assert.rejects(checkProductCompletion(f.contract.pack + ".completion.json", archive), /Source content changed/);
});

test("legacy process-only plan remains independent of a product pack", async t => {
  const f = fixture(t); writeFileSync(f.planPath, "# PLAN.md\n- Status: READY\n");
  assert.deepEqual(await checkProductPlan(f.planPath), { required: false, status: "not_applicable" });
});

test("actual archive helper retains the plan when product proof fails", t => {
  const f = fixture(t); f.pack.scenarios[0].status = "fail"; f.save();
  mkdirSync(join(f.root, "docs/plan"), { recursive: true });
  const archive = `# Implemented: gate fixture\n- Source plan: \`PLAN.md\`\n- Status: IMPLEMENTED\n- Source plan SHA-256: \`${sha256(f.plan)}\`\n`;
  writeFileSync(join(f.root, "docs/plan/fixture.md"), archive);
  const result = spawnSync(join(repository, "scripts/plan-cleanup"), ["--archive", "docs/plan/fixture.md"], { cwd: f.root, encoding: "utf8" });
  assert.notEqual(result.status, 0);
  assert.ok(existsSync(f.planPath));
  assert.match(result.stderr, /product verification blocked/);
});

test("archive records a bound product receipt and detects later artifact drift", async t => {
  const f = fixture(t);
  mkdirSync(join(f.root, "docs/plan"), { recursive: true });
  const path = join(f.root, "docs/plan/fixture.md");
  writeFileSync(path, `# Implemented: gate fixture\n- Source plan: \`PLAN.md\`\n- Status: IMPLEMENTED\n- Source plan SHA-256: \`${sha256(f.plan)}\`\n`);
  const result = spawnSync(join(repository, "scripts/plan-cleanup"), ["--archive", "docs/plan/fixture.md"], { cwd: f.root, encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(existsSync(f.planPath), false);
  await checkProductCompletion(f.contract.pack + ".completion.json", path);
  writeFileSync(join(f.root, "app.txt"), "new patch\n");
  await assert.rejects(checkProductCompletion(f.contract.pack + ".completion.json", path));
});

test("archive event refuses missing product evidence before ledger append", t => {
  const f = fixture(t); rmSync(f.contract.pack);
  const result = spawnSync(join(repository, "scripts/workflow-event"), ["--dir", join(f.root, ".workflow/ledger"), "append", "test-run", "archive_written", '{"path":"docs/plan/fixture.md"}'], { cwd: f.root, encoding: "utf8", env: { ...process.env, WORKFLOW_EVENT_PROJECT_ROOT: f.root } });
  assert.notEqual(result.status, 0);
  assert.equal(existsSync(join(f.root, ".workflow/ledger/test-run/events.jsonl")), false);
});

for (const failure of ["missing subject", "invalid declaration"]) {
for (const [event, detail] of [
  ["blocked", { reason: "plan_gate", needed_input: "Restore the product subject or declaration" }],
  ["validation_failed", { command: "product QA", exit: 1, failure: "Subject unavailable" }],
  ["handoff", { branch: "main", sha: "fixture", done: [], pending: ["restore subject"], next_action: "Restore subject", do_not_redo: [] }],
  ["human_checkpoint", { category: "runtime", decision: "restore required", target: "product subject" }],
]) {
  test(`${event} remains writable with ${failure}`, t => {
    const f = fixture(t);
    const subject = join(f.root, "subject");
    mkdirSync(subject);
    const plan = f.plan.replace(`Subject root: ${f.root}`, `Subject root: ${subject}`);
    writeFileSync(f.planPath, plan);
    const command = (event, detail) => spawnSync(join(repository, "scripts/workflow-event"), ["--dir", join(f.root, ".workflow/ledger"), "append", "test-run", event, JSON.stringify(detail)], { cwd: f.root, encoding: "utf8", env: { ...process.env, WORKFLOW_EVENT_PROJECT_ROOT: f.root } });
    const created = command("plan_created", { path: "PLAN.md", status: "READY" });
    assert.equal(created.status, 0, created.stderr);
    const ledger = join(f.root, ".workflow/ledger/test-run/events.jsonl");
    const frozen = JSON.parse(readFileSync(ledger, "utf8")).detail;
    if (failure === "missing subject") rmSync(subject, { recursive: true });
    else writeFileSync(f.planPath, plan.replace("Required: yes", "Required: invalid"));
    const completed = command("completed", { summary: "Unavailable proof cannot complete" });
    assert.notEqual(completed.status, 0);
    const recorded = command(event, detail);
    assert.equal(recorded.status, 0, recorded.stderr);
    const events = readFileSync(ledger, "utf8").trim().split("\n").map(JSON.parse);
    assert.deepEqual(events[0].detail, frozen);
    assert.equal(events.at(-1).event, event);
    const checked = spawnSync(join(repository, "scripts/workflow-event"), ["--dir", join(f.root, ".workflow/ledger"), "validate", "test-run", ...(event === "blocked" ? ["--profile", "blocked-terminal"] : [])], { cwd: f.root, encoding: "utf8", env: { ...process.env, WORKFLOW_EVENT_PROJECT_ROOT: f.root } });
    assert.equal(checked.status, 0, checked.stderr);
  });
}
}

test("READY check-freeze prevents removing product applicability", t => {
  const f = fixture(t);
  const result = evaluateCheckFreeze({ previousChecks: parseChecks(f.plan), currentText: f.plan.replace("Required: yes", "Required: no") });
  assert.equal(result.ok, false);
  assert.ok(result.removed.some(value => value.includes("product-verification")));
});

test("actual completed event remembers required proof after root plan removal", t => {
  const f = fixture(t);
  const command = (...args) => spawnSync(join(repository, "scripts/workflow-event"), ["--dir", join(f.root, ".workflow/ledger"), "append", "test-run", ...args], { cwd: f.root, encoding: "utf8", env: { ...process.env, WORKFLOW_EVENT_PROJECT_ROOT: f.root } });
  assert.equal(command("plan_created", '{"path":"PLAN.md","status":"READY"}').status, 0);
  const ledger = join(f.root, ".workflow/ledger/test-run/events.jsonl");
  assert.equal(JSON.parse(readFileSync(ledger, "utf8")).detail.product_verification_required, true);
  rmSync(f.planPath);
  assert.equal(command("archive_written", '{"path":"docs/plan/fixture.md"}').status, 0);
  const before = readFileSync(ledger, "utf8");
  const result = command("completed", '{"summary":"Attempted bypass"}');
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /required product completion receipt is missing/);
  assert.equal(readFileSync(ledger, "utf8"), before);
});

for (const mutation of ["different archive path", "later archive without receipt", "different plan contract", "terminal contract override"]) {
  test(`completion rejects ${mutation} instead of reusing an old receipt`, async t => {
    const f = fixture(t);
    mkdirSync(join(f.root, "docs/plan"), { recursive: true });
    const archive = join(f.root, "docs/plan/fixture.md");
    writeFileSync(archive, `# Implemented: gate fixture\n- Source plan: \`PLAN.md\`\n- Status: IMPLEMENTED\n- Source plan SHA-256: \`${sha256(f.plan)}\`\n`);
    await writeProductCompletion(f.planPath, archive);
    if (["different plan contract", "terminal contract override"].includes(mutation)) writeFileSync(f.planPath, f.plan.replace("Visible mutation is persisted", "Another required mutation is persisted"));
    const command = (event, detail) => spawnSync(join(repository, "scripts/workflow-event"), ["--dir", join(f.root, ".workflow/ledger"), "append", "test-run", event, JSON.stringify(detail)], { cwd: f.root, encoding: "utf8", env: { ...process.env, WORKFLOW_EVENT_PROJECT_ROOT: f.root } });
    assert.equal(command("plan_created", { path: "PLAN.md", status: "READY" }).status, 0);
    rmSync(f.planPath);
    const detail = { path: mutation === "different archive path" ? "docs/plan/other.md" : "docs/plan/fixture.md", product_verification_required: true, product_verification_receipt: f.contract.pack + ".completion.json", product_archive_path: archive };
    assert.equal(command("archive_written", detail).status, 0);
    if (mutation === "later archive without receipt") assert.equal(command("archive_written", { path: "docs/plan/other.md" }).status, 0);
    const ledger = join(f.root, ".workflow/ledger/test-run/events.jsonl");
    const before = readFileSync(ledger, "utf8");
    const completed = command("completed", { summary: "Attempted foreign or stale archive", ...(mutation === "terminal contract override" ? {product_verification_contract_sha256: productContractIdentity(f.contract)} : {}) });
    assert.notEqual(completed.status, 0, "The old internally valid receipt must not close this ledger");
    assert.equal(readFileSync(ledger, "utf8"), before);
  });
}

test("the latest archive with this ledger's frozen contract can complete", async t => {
  const f = fixture(t);
  const command = (event, detail) => spawnSync(join(repository, "scripts/workflow-event"), ["--dir", join(f.root, ".workflow/ledger"), "append", "test-run", event, JSON.stringify(detail)], { cwd: f.root, encoding: "utf8", env: { ...process.env, WORKFLOW_EVENT_PROJECT_ROOT: f.root } });
  assert.equal(command("plan_created", { path: "PLAN.md", status: "READY" }).status, 0);
  mkdirSync(join(f.root, "docs/plan"), { recursive: true });
  const archive = join(f.root, "docs/plan/fixture.md");
  writeFileSync(archive, `# Implemented: gate fixture\n- Source plan: \`PLAN.md\`\n- Status: IMPLEMENTED\n- Source plan SHA-256: \`${sha256(f.plan)}\`\n`);
  assert.equal(command("archive_written", { path: "docs/plan/fixture.md" }).status, 0);
  await writeProductCompletion(f.planPath, archive);
  rmSync(f.planPath);
  const completed = command("completed", { summary: "Bound source and plan verified" });
  assert.equal(completed.status, 0, completed.stderr);
});

test("completion does not write a receipt for a plan changed during validation", async t => {
  const f = fixture(t);
  const archive = join(f.base, "archive.md");
  writeFileSync(archive, `# Implemented: fixture\n- Source plan SHA-256: \`${sha256(f.plan)}\`\n`);
  const pending = writeProductCompletion(f.planPath, archive);
  const newer = f.plan + "\nNew work must remain pending.\n";
  writeFileSync(f.planPath, newer);
  await assert.rejects(pending, /Plan changed during product verification/);
  assert.equal(readFileSync(f.planPath, "utf8"), newer);
  assert.equal(existsSync(f.contract.pack + ".completion.json"), false);
});

test("completion does not write a receipt for an archive changed during validation", async t => {
  const f = fixture(t);
  const archive = join(f.base, "archive.md");
  writeFileSync(archive, `# Implemented: fixture\n- Source plan SHA-256: \`${sha256(f.plan)}\`\n`);
  const pending = writeProductCompletion(f.planPath, archive);
  writeFileSync(archive, "Replaced archive must not complete the old plan.\n");
  await assert.rejects(pending, /Archive changed during product verification/);
  assert.equal(existsSync(f.contract.pack + ".completion.json"), false);
});

test("completion does not write a receipt for a pack replaced during validation", async t => {
  const f = fixture(t);
  const archive = join(f.base, "archive.md");
  writeFileSync(archive, `# Implemented: fixture\n- Source plan SHA-256: \`${sha256(f.plan)}\`\n`);
  await checkProductPlan(f.planPath);
  const pending = writeProductCompletion(f.planPath, archive);
  f.pack.scenarios[0].status = "fail"; f.save();
  await assert.rejects(pending, /Evidence pack changed during product verification/);
  assert.equal(existsSync(f.contract.pack + ".completion.json"), false);
});

for (const mutation of ["pack", "archive", "receipt"]) {
  test(`completion rechecks ${mutation} after asynchronous validation`, async t => {
    const f = fixture(t);
    const archive = join(f.base, "archive.md");
    writeFileSync(archive, `# Implemented: fixture\n- Source plan SHA-256: \`${sha256(f.plan)}\`\n`);
    await writeProductCompletion(f.planPath, archive);
    const receipt = f.contract.pack + ".completion.json";
    const pending = checkProductCompletion(receipt, archive);
    if (mutation === "pack") { f.pack.scenarios[0].status = "fail"; f.save(); }
    else if (mutation === "archive") writeFileSync(archive, "Another archive\n");
    else writeFileSync(receipt, readFileSync(receipt, "utf8") + "\n");
    await assert.rejects(pending, /changed during completion verification/);
  });
}

test("checker hashes the exact pack bytes it evaluates", t => {
  const f = fixture(t);
  const expected = sha256(readFileSync(f.contract.pack));
  const failed = structuredClone(f.pack); failed.scenarios[0].status = "fail";
  const preload = join(f.base, "replace-pack.mjs");
  writeFileSync(preload, `import fs from "node:fs"; import { syncBuiltinESMExports } from "node:module";
const original = fs.readFileSync; let reads = 0;
fs.readFileSync = function(path, ...args) {
  if (String(path).endsWith("/pack.json") && ++reads === 2) fs.writeFileSync(path, ${JSON.stringify(JSON.stringify(failed))});
  return original.call(this, path, ...args);
}; syncBuiltinESMExports();\n`);
  const result = spawnSync(process.execPath, ["--import", preload, join(repository, "scripts/project-verification-check"), f.planPath], { cwd: f.root, encoding: "utf8" });
  if (result.status === 0) assert.equal(JSON.parse(result.stdout).pack_sha256, expected);
  else assert.match(result.stderr, /Evidence pack changed during validation/);
});

for (const boundary of ["during verification", "before deletion"]) {
test(`actual cleanup retains a plan edited ${boundary}`, t => {
  const f = fixture(t);
  mkdirSync(join(f.root, "docs/plan"), { recursive: true });
  const archive = join(f.root, "docs/plan/fixture.md");
  writeFileSync(archive, `# Implemented: fixture\n- Source plan: \`PLAN.md\`\n- Status: IMPLEMENTED\n- Source plan SHA-256: \`${sha256(f.plan)}\`\n`);
  const preload = join(f.base, "edit-during-validation.mjs");
  // Queue a real filesystem edit at the next async boundary, without a timing sleep.
  writeFileSync(preload, `import fs from "node:fs"; import { syncBuiltinESMExports } from "node:module";
const original = fs.readFileSync; let reads = 0;
fs.readFileSync = function (path, ...args) {
  const bytes = original.call(this, path, ...args);
  if (String(path).endsWith("/PLAN.md") && ++reads === ${boundary === "during verification" ? 1 : 3}) {
    queueMicrotask(() => fs.writeFileSync(${JSON.stringify(f.planPath)}, ${JSON.stringify(f.plan + "\nNew work must remain pending.\n")}));
  }
  return bytes;
}; syncBuiltinESMExports();\n`);
  const result = spawnSync(process.execPath, ["--import", preload, join(repository, "scripts/plan-cleanup"), "--archive", "docs/plan/fixture.md"], { cwd: f.root, encoding: "utf8" });
  assert.notEqual(result.status, 0, result.stderr);
  assert.match(result.stderr, boundary === "during verification" ? /Plan changed during product verification/ : /plan or archive changed during cleanup/);
  assert.match(readFileSync(f.planPath, "utf8"), /New work must remain pending/);
});
}

test("a nonzero execution receipt cannot pass even with passing scenarios", async t => {
  const f = fixture(t);
  const artifact = f.pack.artifacts.find(a => a.id === "execution");
  const path = join(f.base, artifact.path);
  const receipt = JSON.parse(readFileSync(path)); receipt.exit_code = 1;
  writeFileSync(path, JSON.stringify(receipt)); artifact.sha256 = sha256(readFileSync(path)); f.save();
  await assert.rejects(checkProductPlan(f.planPath), /Execution receipt reports failure/);
});

test("artifact symlinks escaping the retained evidence root are refused", async t => {
  const f = fixture(t);
  const path = join(f.base, "artifacts/outcome.json");
  rmSync(path); symlinkSync(join(f.root, "app.txt"), path);
  await assert.rejects(checkProductPlan(f.planPath), /escapes its root/);
});

test("product applicability added after plan creation is remembered on later events", t => {
  const f = fixture(t);
  const args = ["--dir", join(f.root, ".workflow/ledger"), "append", "test-run"];
  const command = (...more) => spawnSync(join(repository, "scripts/workflow-event"), [...args, ...more], { cwd: f.root, encoding: "utf8", env: { ...process.env, WORKFLOW_EVENT_PROJECT_ROOT: f.root } });
  writeFileSync(f.planPath, "# PLAN.md\n- Status: DRAFT\n");
  assert.equal(command("plan_created", '{"path":"PLAN.md","status":"DRAFT"}').status, 0);
  writeFileSync(f.planPath, f.plan);
  assert.equal(command("validation_run", '{"command":"product proof","exit":0}').status, 0);
  rmSync(f.planPath);
  const result = command("completed", '{"summary":"No archive receipt"}');
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /required product completion receipt is missing/);
});

test("completion itself cannot promote product applicability without a receipt", t => {
  const f = fixture(t);
  const command = (...more) => spawnSync(join(repository, "scripts/workflow-event"), ["--dir", join(f.root, ".workflow/ledger"), "append", "test-run", ...more], { cwd: f.root, encoding: "utf8", env: { ...process.env, WORKFLOW_EVENT_PROJECT_ROOT: f.root } });
  writeFileSync(f.planPath, "# PLAN.md\n- Status: DRAFT\n\n## Product Verification\n- Required: no\n");
  assert.equal(command("plan_created", '{"path":"PLAN.md","status":"DRAFT"}').status, 0);
  const ledger = join(f.root, ".workflow/ledger/test-run/events.jsonl");
  const before = readFileSync(ledger, "utf8");
  writeFileSync(f.planPath, f.plan);
  const result = command("completed", '{"summary":"Direct terminal promotion"}');
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /required product completion receipt is missing/);
  assert.equal(readFileSync(ledger, "utf8"), before);
});

test("non-plan CI ledger does not inherit the caller's unrelated product plan", t => {
  const f = fixture(t);
  const command = (...more) => spawnSync(join(repository, "scripts/workflow-event"), ["--dir", join(f.root, ".workflow/ci"), "append", "ci-fix", ...more], { cwd: f.root, encoding: "utf8", env: { ...process.env, WORKFLOW_EVENT_PROJECT_ROOT: f.root } });
  assert.equal(command("validation_run", '{"command":"CI checks","exit":0}').status, 0);
  const result = command("completed", '{"summary":"CI checks passed, no plan lifecycle"}');
  assert.equal(result.status, 0, result.stderr);
});

test("draft plan can remember required product verification before paths are filled", t => {
  const f = fixture(t);
  writeFileSync(f.planPath, "# PLAN.md\n- Status: DRAFT\n\n## Product Verification\n- Required: yes\n");
  const result = spawnSync(join(repository, "scripts/workflow-event"), ["--dir", join(f.root, ".workflow/ledger"), "append", "test-run", "plan_created", '{"path":"PLAN.md","status":"DRAFT"}'], { cwd: f.root, encoding: "utf8", env: { ...process.env, WORKFLOW_EVENT_PROJECT_ROOT: f.root } });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(JSON.parse(readFileSync(join(f.root, ".workflow/ledger/test-run/events.jsonl"), "utf8")).detail.product_verification_required, true);
});

test("source manifest cannot substitute for the environment fingerprint", async t => {
  const f = fixture(t);
  f.pack.target.environment_sha256 = f.pack.target.subject_sha256; f.save();
  await assert.rejects(checkProductPlan(f.planPath), /distinct retained artifact/);
});

test("completion contract cannot be edited independently of the preserved plan", async t => {
  const f = fixture(t);
  mkdirSync(join(f.root, "docs/plan"), { recursive: true });
  const archive = join(f.root, "docs/plan/fixture.md");
  writeFileSync(archive, `# Implemented: gate fixture\n- Source plan: \`PLAN.md\`\n- Status: IMPLEMENTED\n- Source plan SHA-256: \`${sha256(f.plan)}\`\n`);
  const result = spawnSync(join(repository, "scripts/plan-cleanup"), ["--archive", "docs/plan/fixture.md"], { cwd: f.root, encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  const path = f.contract.pack + ".completion.json";
  const record = JSON.parse(readFileSync(path)); record.contract.criteria[0].proof = ["action", "result"];
  writeFileSync(path, JSON.stringify(record));
  await assert.rejects(checkProductCompletion(path, archive), /differs from the preserved frozen plan/);
});

test("all declared product criteria need coverage even when another scenario passes", async t => {
  const f = fixture(t);
  const changed = f.plan.replace("AC-02 [process]: Focused checks pass.", "AC-02 [product]: Another user outcome. Proof: action,result.");
  writeFileSync(f.planPath, changed);
  f.pack.criteria_sha256 = frozenProductContract(changed, f.planPath).criteria_sha256; f.save();
  await assert.rejects(checkProductPlan(f.planPath), /Missing passing proof for AC-02/);
});

test("archive hash metadata accepted by cleanup remains accepted by completion", async t => {
 const f=fixture(t);mkdirSync(join(f.root,"docs/plan"),{recursive:true});
 const archive=join(f.root,"docs/plan/fixture.md");
 writeFileSync(archive,`# Implemented: fixture\n- Source plan: \`PLAN.md\`\n- Status: IMPLEMENTED\n- Source plan SHA-256: \`${sha256(f.plan)}\`  \n`);
 const result=spawnSync(join(repository,"scripts/plan-cleanup"),["--archive","docs/plan/fixture.md"],{cwd:f.root,encoding:"utf8"});
 assert.equal(result.status,0,result.stderr);assert.equal(existsSync(f.planPath),false);
 await checkProductCompletion(f.contract.pack+".completion.json",archive);
});
