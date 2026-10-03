import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { isAbsolute, join, resolve, sep } from "node:path";
import { assertionProtocol } from "./project-verification-plan.mjs";

export { assertionProtocol };

function pointerParts(pointer) {
  assert.ok(
    typeof pointer === "string" && (pointer === "" || pointer.startsWith("/")),
    "Invalid RFC6901 JSON pointer",
  );
  if (pointer === "") return [];
  return pointer
    .slice(1)
    .split("/")
    .map((part) => {
      assert.ok(!/~(?:[^01]|$)/.test(part), "Invalid RFC6901 escape");
      return part.replace(/~1/g, "/").replace(/~0/g, "~");
    });
}

export function jsonPointer(value, pointer) {
  for (const part of pointerParts(pointer)) {
    assert.ok(
      value !== null && typeof value === "object" && Object.hasOwn(value, part),
      `Missing observation at JSON pointer ${pointer}`,
    );
    if (Array.isArray(value))
      assert.ok(
        /^(0|[1-9][0-9]*)$/.test(part),
        `Invalid array index at JSON pointer ${pointer}`,
      );
    value = value[part];
  }
  return value;
}

function assertionList(assertions) {
  assert.ok(
    Array.isArray(assertions) && assertions.length,
    "Observation requires nonempty frozen assertions",
  );
  for (const assertion of assertions) {
    assert.ok(
      assertion && typeof assertion === "object",
      "Invalid observation assertion",
    );
    assert.deepEqual(
      Object.keys(assertion).sort(),
      ["expected", "pointer"],
      "Assertions accept pointer and expected fields only",
    );
    pointerParts(assertion.pointer);
  }
}

export function assertJsonExpectations(
  value,
  assertions,
  label = "Observation",
) {
  assertionList(assertions);
  for (const { pointer, expected } of assertions) {
    assert.deepEqual(
      jsonPointer(value, pointer),
      expected,
      `${label} differs from frozen expectation at ${pointer}`,
    );
  }
  return true;
}

function commandSpec(command, label) {
  assert.ok(
    command &&
      Array.isArray(command.argv) &&
      command.argv.length &&
      command.argv.every((arg) => typeof arg === "string") &&
      command.argv[0].length,
    `${label} requires shell-less argv`,
  );
  assert.ok(
    Number.isSafeInteger(command.timeout_ms) && command.timeout_ms > 0,
    `${label} requires a positive timeout_ms`,
  );
}

export function validateRecipeAssertions(recipe) {
  assert.equal(recipe.schema_version, 1, "Unsupported verification recipe");
  assert.ok(
    typeof recipe.name === "string" && recipe.name.trim(),
    "Recipe needs a name",
  );
  for (const phase of ["launch", "doctor", "cleanup"])
    commandSpec(recipe[phase], phase);
  assert.ok(
    Array.isArray(recipe.scenarios) && recipe.scenarios.length,
    "Recipe needs executable scenarios",
  );
  const ids = new Set();
  for (const scenario of recipe.scenarios) {
    assert.ok(
      typeof scenario.id === "string" &&
        scenario.id.length &&
        !ids.has(scenario.id),
      "Recipe needs unique scenario IDs",
    );
    ids.add(scenario.id);
    assert.ok(
      Array.isArray(scenario.criterion_ids) &&
        scenario.criterion_ids.length &&
        new Set(scenario.criterion_ids).size ===
          scenario.criterion_ids.length &&
        scenario.criterion_ids.every((id) => /^AC-[A-Za-z0-9-]+$/.test(id)),
      "Recipe needs explicit unique criterion mappings",
    );
    commandSpec(scenario.action, `${scenario.id} action`);
    commandSpec(scenario.result, `${scenario.id} result`);
    assertionList(scenario.result.assertions);
    if (scenario.persistence) {
      commandSpec(scenario.persistence, `${scenario.id} persistence`);
      assertionList(scenario.persistence.assertions);
    }
  }
  if (recipe.service) {
    commandSpec(recipe.service, "service");
    commandSpec(recipe.service.readiness, "service readiness");
  }
  if (recipe.engine) {
    commandSpec(recipe.engine, "engine");
    for (const field of ["provider", "model"])
      assert.ok(
        typeof recipe.engine[field] === "string" && recipe.engine[field].trim(),
        `Engine needs requested ${field}`,
      );
    assert.ok(
      Array.isArray(recipe.engine.required_env) &&
        recipe.engine.required_env.every(
          (name) =>
            typeof name === "string" &&
            /^[A-Za-z_][A-Za-z0-9_]*$/.test(name) &&
            !name.startsWith("ETABLI_"),
        ),
      "Engine needs credential environment names only",
    );
  }
  return recipe;
}

export function assertCommandReceipt(
  receipt,
  command,
  binding,
  { allowOwnedShutdown = false } = {},
) {
  commandSpec(command, "Observed command");
  assert.equal(
    receipt.protocol,
    assertionProtocol,
    "Missing process observation protocol",
  );
  for (const [field, expected] of Object.entries(binding))
    assert.equal(
      receipt[field],
      expected,
      `Process ${field} differs from its owned execution`,
    );
  assert.deepEqual(
    receipt.argv,
    command.argv,
    "Process argv differs from the frozen recipe",
  );
  assert.equal(
    receipt.timeout_ms,
    command.timeout_ms,
    "Process timeout differs from the frozen recipe",
  );
  assert.ok(
    Number.isSafeInteger(receipt.pid) && receipt.pid > 0,
    "Process receipt needs an observed PID",
  );
  for (const field of ["started_at", "ended_at"])
    assert.ok(
      typeof receipt[field] === "string" &&
        /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$/.test(
          receipt[field],
        ) &&
        Number.isFinite(Date.parse(receipt[field])),
      `Process needs an observed ${field}`,
    );
  assert.ok(
    Date.parse(receipt.ended_at) >= Date.parse(receipt.started_at),
    "Process observation ends before it starts",
  );
  if (Object.hasOwn(receipt, "completion_forced"))
    assert.equal(receipt.completion_forced, false, "Process completion was forced rather than observed");
  assert.equal(
    receipt.timed_out,
    false,
    "Process timed out or timeout observation is missing",
  );
  assert.ok(
    typeof receipt.stdout_sha256 === "string" &&
      /^[a-f0-9]{64}$/.test(receipt.stdout_sha256),
    "Process needs captured stdout identity",
  );
  if (allowOwnedShutdown) {
    assert.equal(
      receipt.owned_shutdown,
      true,
      "Service shutdown was not owned",
    );
    assert.equal(
      receipt.ready_observed,
      true,
      "Service readiness was not observed",
    );
    assert.equal(
      receipt.unexpected_exit,
      false,
      "Service exited before its intended cleanup",
    );
    assert.ok(
      (receipt.exit_code === 0 && receipt.signal === null) ||
        (receipt.exit_code === null &&
          ["SIGTERM", "SIGKILL"].includes(receipt.signal)),
      "Service did not reach an observed owned shutdown",
    );
  } else {
    assert.equal(receipt.exit_code, 0, "Observed command failed");
    assert.equal(receipt.signal, null, "Observed command was interrupted");
  }
  return receipt;
}

export function verifyRecipeEvidence({
  pack,
  contract,
  manifest,
  artifacts,
  executionReceipt,
  phaseReceipts,
  environment,
}) {
  assert.equal(
    pack.recipe.protocol,
    assertionProtocol,
    "Unsupported recipe assertion protocol",
  );
  const sourceRecipe = manifest.files.find(
    (file) => file.path === pack.recipe.path,
  );
  assert.ok(
    sourceRecipe,
    "Verification recipe must belong to the complete source inventory",
  );
  assert.equal(
    sourceRecipe.sha256,
    pack.recipe.sha256,
    "Recipe differs from the captured source",
  );
  function artifact(id, kind) {
    const item = artifacts.get(id);
    assert.equal(item?.kind, kind, `Missing ${kind} recipe evidence: ${id}`);
    return item;
  }
  const retained = artifact(pack.recipe.artifact, "recipe");
  assert.equal(
    retained.sha256,
    pack.recipe.sha256,
    "Retained recipe differs from the source recipe",
  );
  const recipe = validateRecipeAssertions(
    JSON.parse(readFileSync(retained.fullPath, "utf8")),
  );
  for (const value of [environment, executionReceipt]) {
    assert.equal(
      value.protocol,
      assertionProtocol,
      "Missing owned runner protocol",
    );
    assert.equal(
      value.run_id,
      pack.run_id,
      "Recipe execution belongs to another run",
    );
    assert.equal(
      value.recipe_sha256,
      pack.recipe.sha256,
      "Recipe execution belongs to another recipe",
    );
  }
  assert.ok(
    typeof environment.run_root === "string" &&
      isAbsolute(environment.run_root) &&
      resolve(environment.run_root) === environment.run_root &&
      environment.run_root.startsWith(
        join(contract.subjectRoot, ".workflow") + sep,
      ),
    "Runner must own a project-local workflow run root",
  );
  assert.equal(
    environment.snapshot_root,
    join(environment.run_root, "subject"),
    "Snapshot must belong to this owned run",
  );
  assert.equal(
    executionReceipt.run_root,
    environment.run_root,
    "Execution run root differs from environment",
  );
  assert.equal(
    executionReceipt.snapshot_root,
    environment.snapshot_root,
    "Execution snapshot differs from environment",
  );
  const binding = {
    run_id: pack.run_id,
    source_sha256: pack.target.subject_sha256,
    environment_sha256: pack.target.environment_sha256,
    recipe_sha256: pack.recipe.sha256,
    cwd: environment.snapshot_root,
  };
  const record = (id, kind = "execution_receipt") =>
    JSON.parse(readFileSync(artifact(id, kind).fullPath, "utf8"));
  for (const [phase, receipts] of Object.entries(phaseReceipts)) {
    for (const receipt of receipts) {
      const role = phase === "isolation" ? receipt.role : phase;
      assert.ok(
        phase !== "isolation" || ["launch", "doctor"].includes(role),
        "Isolation must bind an observed launch or doctor process",
      );
      assertCommandReceipt(receipt, recipe[role], { ...binding, role });
      if (phase === "isolation") {
        assert.equal(
          receipt.isolation?.cwd_verified,
          true,
          "Snapshot cwd isolation was not observed",
        );
        assert.equal(
          receipt.isolation?.runtime_root,
          join(environment.run_root, "runtime"),
          "Runtime isolation differs from its owned run",
        );
      }
      if (phase === "cleanup") {
        assert.equal(
          receipt.owned_cleanup?.processes_reaped,
          true,
          "Cleanup did not observe owned process reaping",
        );
        assert.equal(
          receipt.owned_cleanup?.runtime_removed,
          true,
          "Cleanup did not observe owned runtime removal",
        );
      }
    }
  }
  if (recipe.service) {
    const service = executionReceipt.service;
    assert.ok(service, "Missing owned service process observations");
    const serviceReceipt = assertCommandReceipt(
      record(service.receipt_artifact),
      recipe.service,
      { ...binding, role: "service" },
      { allowOwnedShutdown: true },
    );
    assertCommandReceipt(
      record(service.readiness_artifact),
      recipe.service.readiness,
      { ...binding, role: "readiness" },
    );
    for (const cleanup of phaseReceipts.cleanup)
      assert.ok(
        cleanup.owned_cleanup?.groups?.some(
          (group) => group.pid === serviceReceipt.pid && group.reaped === true,
        ),
        "Cleanup did not reap the owned service group",
      );
  }
  if (recipe.engine) {
    assert.equal(
      typeof executionReceipt.engine_requested,
      "boolean",
      "Engine activation must be explicit",
    );
    if (executionReceipt.engine_requested)
      assertCommandReceipt(
        record(executionReceipt.engine_receipt_artifact),
        recipe.engine,
        { ...binding, role: "engine" },
      );
    else
      assert.ok(
        !executionReceipt.engine_receipt_artifact,
        "Unrequested engine cannot claim an observed invocation",
      );
  } else
    assert.ok(
      !executionReceipt.engine_requested &&
        !executionReceipt.engine_receipt_artifact,
      "Engine invocation has no configured source recipe",
    );
  const declared = new Map(
    recipe.scenarios.map((scenario) => [scenario.id, scenario]),
  );
  assert.deepEqual(
    [...declared.keys()].sort(),
    pack.scenarios.map((scenario) => scenario.id).sort(),
    "Executed scenarios differ from the frozen recipe",
  );
  for (const scenario of pack.scenarios) {
    const expected = declared.get(scenario.id);
    assert.deepEqual(
      scenario.criterion_ids,
      expected.criterion_ids,
      "Scenario criterion mapping differs from the source recipe",
    );
    const action = scenario.action_evidence.filter(
      (id) => artifacts.get(id)?.kind === "action",
    );
    assert.ok(action.length, "Missing observed action command");
    for (const id of action)
      assertCommandReceipt(record(id, "action"), expected.action, {
        ...binding,
        role: "action",
        scenario_id: scenario.id,
      });
    const needsPersistence =
      scenario.side_effect_expected ||
      expected.criterion_ids.some((id) =>
        contract.criteria
          .find((criterion) => criterion.id === id)
          ?.proof.includes("side_effect"),
      );
    if (needsPersistence)
      assert.ok(
        expected.persistence,
        "Required persistence has no frozen recipe assertions",
      );
    if (expected.persistence)
      assert.equal(
        scenario.side_effect_expected,
        true,
        "Recipe persistence must be declared by its scenario",
      );
    assert.ok(
      scenario.observations?.result,
      "Missing independently checkable result observation",
    );
    for (const [role, kind, proof] of [
      ["result", "outcome", scenario.result_evidence],
      ["persistence", "side_effect", scenario.side_effect_evidence],
    ]) {
      if (role === "persistence" && !expected.persistence) {
        assert.ok(
          !scenario.observations?.persistence,
          "Persistence observation has no frozen recipe oracle",
        );
        continue;
      }
      const observed = scenario.observations?.[role];
      assert.ok(observed, `Missing ${role} observation`);
      assert.ok(
        proof.includes(observed.artifact),
        `${role} observation is not the scenario's retained proof`,
      );
      assert.deepEqual(
        observed.assertions,
        expected[role].assertions,
        `${role} assertions differ from the frozen recipe`,
      );
      const item = artifact(observed.artifact, kind);
      const receipt = assertCommandReceipt(
        record(observed.receipt_artifact),
        expected[role],
        { ...binding, role, scenario_id: scenario.id },
      );
      assert.equal(
        receipt.stdout_sha256,
        item.sha256,
        `${role} JSON differs from observed command stdout`,
      );
      assertJsonExpectations(
        JSON.parse(readFileSync(item.fullPath, "utf8")),
        expected[role].assertions,
        `${scenario.id} ${role}`,
      );
    }
  }
  return recipe;
}
