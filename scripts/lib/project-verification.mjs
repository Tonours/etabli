import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { readFileSync, realpathSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { parseChecks, parsePlanStatus } from "./plan-check-freeze.mjs";
import { productCriteria, productVerificationDeclaration } from "./project-verification-plan.mjs";
import { confinedFile, sha256, verifySourceManifest } from "./project-verification-source.mjs";
import { assertionProtocol, verifyRecipeEvidence } from "./project-verification-assertions.mjs";

const require = createRequire(new URL("../../pi/package.json", import.meta.url));
let schemaValidator;
function validatorModule() {
  try { return require.resolve("typebox/compile"); }
  catch (error) {
    if (error.code !== "MODULE_NOT_FOUND") throw error;
    return createRequire(join(homedir(), ".pi/agent/npm/package.json")).resolve("typebox/compile");
  }
}

export const productContractIdentity = contract => sha256(JSON.stringify({ pack: contract.pack, subjectRoot: contract.subjectRoot, criteria_sha256: contract.criteria_sha256, ...(contract.assertion_protocol ? { assertion_protocol: contract.assertion_protocol } : {}) }));

export function frozenProductContract(plan, planPath) {
  const declaration = productVerificationDeclaration(plan, { normalizedChecks: parseChecks(plan) });
  if (!declaration.required) return declaration;
  assert.equal(parsePlanStatus(plan), "ready", "Product verification requires the actual READY plan");
  const checks = parseChecks(plan).filter(value => value.startsWith("acceptance-criteria:")).sort();
  return {
    required: true,
    pack: resolve(dirname(planPath), declaration.pack),
    subjectRoot: realpathSync(resolve(dirname(planPath), declaration.subjectRoot)),
    criteria_sha256: sha256(JSON.stringify(checks)),
    criteria: productCriteria(checks),
    ...(declaration.assertion_protocol ? { assertion_protocol: declaration.assertion_protocol } : {}),
  };
}

// This guard is synchronous so callers can use it immediately before writes/unlink.
export function assertProductIdentity(contract, expectedPackHash, { allowRefChange = false } = {}) {
  if (!contract.required) return;
  const bytes = readFileSync(contract.pack);
  assert.equal(sha256(bytes), expectedPackHash, "Evidence pack changed during identity recheck");
  const pack = JSON.parse(bytes);
  const base = dirname(contract.pack);
  let source;
  for (const artifact of pack.artifacts) {
    const path = confinedFile(base, artifact.path);
    const retained = readFileSync(path);
    assert.equal(sha256(retained), artifact.sha256, `Evidence content changed: ${artifact.id}`);
    if (artifact.kind === "source" && artifact.path === pack.target.subject_path) source = JSON.parse(retained);
  }
  assert.ok(source, "Missing preserved source inventory during identity recheck");
  verifySourceManifest(source, contract.subjectRoot, { allowRefChange });
}

export async function checkProductContract(contract, packPath = contract.pack, { allowRefChange = false } = {}) {
  if (!contract.required) return { required: false, status: "not_applicable" };
  assert.equal(resolve(packPath), contract.pack, "Evidence pack differs from the plan's declared path");
  if (!schemaValidator) {
    const { Compile } = await import(pathToFileURL(validatorModule()));
    schemaValidator = Compile(JSON.parse(readFileSync(new URL("../../workflow/evidence-pack.schema.json", import.meta.url), "utf8")));
  }
  const packBytes = readFileSync(packPath);
  const pack = JSON.parse(packBytes);
  const packHash = sha256(packBytes);
  assert.ok(schemaValidator.Check(pack), "Evidence pack does not match the shared schema");
  assert.ok(["product", "ui"].includes(pack.mode), "Product criteria require product/UI evidence");
  if (pack.scenarios.some(scenario => scenario.observations)) assert.ok(pack.recipe, "Recorded assertions require a source-bound recipe");
  if (contract.assertion_protocol) assert.equal(pack.recipe?.protocol, contract.assertion_protocol, "Auto product plans require the source-bound recipe assertion protocol");
  assert.equal(pack.criteria_sha256, contract.criteria_sha256, "Frozen criteria changed since evidence capture");
  const base = dirname(packPath);
  const artifacts = new Map();
  for (const artifact of pack.artifacts) {
    assert.ok(!artifacts.has(artifact.id), `Duplicate artifact ID: ${artifact.id}`);
    const path = confinedFile(base, artifact.path);
    assert.equal(sha256(readFileSync(path)), artifact.sha256, `Evidence content changed: ${artifact.id}`);
    artifacts.set(artifact.id, { ...artifact, fullPath: path });
  }
  function evidence(ids, role, kind) {
    assert.ok(Array.isArray(ids) && ids.length, `Missing ${role} evidence`);
    for (const id of ids) assert.ok(artifacts.has(id), `Unknown ${role} artifact: ${id}`);
    if (kind) assert.ok(ids.some(id => artifacts.get(id).kind === kind), `${role} proof needs a ${kind} artifact`);
  }
  const source = [...artifacts.values()].find(a => a.kind === "source" && a.path === pack.target.subject_path);
  assert.ok(source, "The target must name the preserved source inventory artifact");
  assert.equal(source.sha256, pack.target.subject_sha256, "Source artifact hash differs from target identity");
  const manifest = JSON.parse(readFileSync(source.fullPath, "utf8"));
  const observed = verifySourceManifest(manifest, contract.subjectRoot, { allowRefChange });
  assert.equal(pack.target.ref, observed.ref, "Target ref differs from captured source");
  const environmentArtifact = [...artifacts.values()].find(a => a.id !== source.id && a.kind === "source" && a.sha256 === pack.target.environment_sha256 && a.sha256 !== source.sha256);
  assert.ok(environmentArtifact, "Environment fingerprint must name a distinct retained artifact");
  assert.equal(pack.execution.status, "parent_observed", "Pack integrity alone is not observed execution");
  const receiptArtifact = artifacts.get(pack.execution.receipt_artifact);
  assert.equal(receiptArtifact?.kind, "execution_receipt", "Missing execution receipt artifact");
  const receipt = JSON.parse(readFileSync(receiptArtifact.fullPath, "utf8"));
  if (receipt.protocol === assertionProtocol || receipt.recipe_sha256) assert.ok(pack.recipe, "Runner execution requires its retained source-bound recipe");
  assert.equal(receipt.run_id, pack.run_id, "Execution receipt belongs to another run");
  assert.equal(receipt.source_sha256, source.sha256, "Execution receipt belongs to another source snapshot");
  assert.equal(receipt.environment_sha256, pack.target.environment_sha256, "Execution environment identity differs");
  assert.equal(receipt.exit_code, 0, "Execution receipt reports failure");
  const phaseReceipts = {};
  for (const step of ["launch", "doctor", "isolation", "cleanup"]) {
    assert.equal(pack.execution[step].status, "passed", `Execution ${step} is not passed`);
    const kind = step === "cleanup" ? "cleanup" : "execution_receipt";
    evidence(pack.execution[step].evidence, step, kind);
    const observations = pack.execution[step].evidence.filter(id => artifacts.get(id).kind === kind);
    phaseReceipts[step] = [];
    for (const id of observations) {
      const phase = JSON.parse(readFileSync(artifacts.get(id).fullPath, "utf8"));
      assert.ok(Array.isArray(phase.phases) && phase.phases.includes(step), `${step} receipt does not observe this phase`);
      assert.equal(phase.status, "passed", `${step} receipt does not report a passing observation`);
      assert.equal(phase.run_id, pack.run_id, `${step} receipt belongs to another run`);
      assert.equal(phase.source_sha256, source.sha256, `${step} receipt belongs to another source`);
      phaseReceipts[step].push(phase);
    }
  }
  const expected = new Map(contract.criteria.map(c => [c.id, c]));
  const covered = new Set();
  const scenarioIds = new Set();
  for (const scenario of pack.scenarios) {
    assert.ok(!scenarioIds.has(scenario.id), `Duplicate scenario ID: ${scenario.id}`);
    scenarioIds.add(scenario.id);
    assert.equal(scenario.status, "pass", `Scenario ${scenario.id} is failed, blocked or inconclusive`);
    assert.ok(scenario.criterion_ids?.length, `Scenario ${scenario.id} has no criterion mapping`);
    evidence(scenario.action_evidence, "action", "action");
    evidence(scenario.result_evidence, "result", "outcome");
    if (scenario.side_effect_expected) evidence(scenario.side_effect_evidence, "side_effect", "side_effect");
    for (const id of scenario.criterion_ids) {
      assert.ok(expected.has(id), `Unknown product criterion: ${id}`);
      if (expected.get(id).proof.includes("side_effect")) {
        assert.equal(scenario.side_effect_expected, true, `${id} requires a persistence/side-effect check`);
        evidence(scenario.side_effect_evidence, "side_effect");
        assert.ok(scenario.side_effect_evidence.some(key => artifacts.get(key)?.kind === "side_effect"), "Persistence proof needs a side_effect artifact");
      }
      covered.add(id);
    }
  }
  for (const id of expected.keys()) assert.ok(covered.has(id), `Missing passing proof for ${id}`);
  if (pack.mode === "ui") {
    const ui = pack.ui;
    for (const check of ["keyboard", "focus", "accessibility", "console", "network"]) {
      assert.equal(ui.checks[check].status, "passed", `UI ${check} is not passed`);
      evidence(ui.checks[check].evidence, `UI ${check}`);
    }
    for (const [check, inScope] of [["responsive", ui.responsive_in_scope], ["reduced_motion", ui.motion_in_scope], ["reference", ui.reference_in_scope]]) {
      assert.equal(ui.checks[check].status, inScope ? "passed" : "not_applicable", `UI ${check} does not match its declared scope`);
      if (inScope) evidence(ui.checks[check].evidence, `UI ${check}`);
      else assert.ok(ui.checks[check].reason?.trim(), `UI ${check} needs a not-applicable reason`);
    }
    assert.ok(ui.viewports.length, "UI proof requires an observed viewport");
    for (const viewport of ui.viewports) evidence(viewport.evidence, `UI viewport ${viewport.label}`);
    if (ui.responsive_in_scope) assert.ok(new Set(ui.viewports.map(viewport => `${viewport.width}x${viewport.height}`)).size >= 2, "UI responsive proof requires at least two observed sizes");
  }
  if (pack.recipe) {
    assert.equal(pack.recipe.protocol, assertionProtocol, "Unsupported recipe assertion protocol");
    verifyRecipeEvidence({ pack, contract, manifest, artifacts, executionReceipt: receipt, phaseReceipts, environment: JSON.parse(readFileSync(environmentArtifact.fullPath, "utf8")) });
  }
  assert.equal(sha256(readFileSync(packPath)), packHash, "Evidence pack changed during validation");
  assertProductIdentity(contract, packHash, { allowRefChange });
  return { required: true, status: "passed", run_id: pack.run_id, criteria: [...covered], source_sha256: source.sha256, pack_sha256: packHash };
}

export async function checkProductPlan(planPath, packPath) {
  const contract = frozenProductContract(readFileSync(planPath, "utf8"), resolve(planPath));
  return checkProductContract(contract, packPath);
}

export async function writeProductCompletion(planPath, archivePath) {
  const plan = readFileSync(planPath, "utf8");
  const contract = frozenProductContract(plan, resolve(planPath));
  const archive = contract.required ? readFileSync(archivePath) : undefined;
  const verification = await checkProductContract(contract);
  assert.equal(readFileSync(planPath, "utf8"), plan, "Plan changed during product verification");
  if (!contract.required) return verification;
  assert.ok(readFileSync(archivePath).equals(archive), "Archive changed during product verification");
  assert.equal(sha256(readFileSync(contract.pack)), verification.pack_sha256, "Evidence pack changed during product verification");
  assertProductIdentity(contract, verification.pack_sha256);
  const record = { schema_version: 1, contract, verification, source_plan: plan, source_plan_path: resolve(planPath), source_plan_sha256: sha256(plan), archive: resolve(archivePath), archive_sha256: sha256(archive) };
  const path = contract.pack + ".completion.json";
  writeFileSync(path, JSON.stringify(record, null, 2) + "\n", { mode: 0o600 });
  return { ...verification, pack: contract.pack, receipt: path };
}

export async function checkProductCompletion(path, archivePath, expectedContractIdentity) {
  const receiptBytes = readFileSync(path);
  const record = JSON.parse(receiptBytes);
  assert.equal(record.schema_version, 1, "Unsupported product completion receipt");
  assert.equal(record.contract.required, true, "Product completion receipt cannot disable its contract");
  assert.equal(sha256(record.source_plan), record.source_plan_sha256, "Preserved plan bytes differ from the archived plan identity");
  assert.deepEqual(record.contract, frozenProductContract(record.source_plan, record.source_plan_path), "Completion contract differs from the preserved frozen plan");
  if (expectedContractIdentity !== undefined) assert.equal(productContractIdentity(record.contract), expectedContractIdentity, "Completion receipt belongs to another ledger plan contract");
  assert.equal(realpathSync(record.archive), realpathSync(archivePath), "Completion receipt belongs to another archive");
  const archive = readFileSync(archivePath, "utf8");
  assert.equal(sha256(archive), record.archive_sha256, "Implemented archive changed after product verification");
  assert.ok(archive.split(/\r?\n/).some(line => line.trimEnd() === `- Source plan SHA-256: \`${record.source_plan_sha256}\``), "Archive does not bind the verified source plan");
  assert.equal(sha256(readFileSync(record.contract.pack)), record.verification.pack_sha256, "Evidence pack changed after cleanup");
  const verification = await checkProductContract(record.contract, record.contract.pack, { allowRefChange: true });
  assert.equal(verification.pack_sha256, record.verification.pack_sha256, "Evidence pack changed during completion verification");
  assert.equal(sha256(readFileSync(record.contract.pack)), record.verification.pack_sha256, "Evidence pack changed during completion verification");
  assert.equal(sha256(readFileSync(archivePath)), record.archive_sha256, "Archive changed during completion verification");
  assert.ok(readFileSync(path).equals(receiptBytes), "Receipt changed during completion verification");
  assertProductIdentity(record.contract, verification.pack_sha256, { allowRefChange: true });
  return verification;
}
