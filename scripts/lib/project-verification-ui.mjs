import assert from "node:assert/strict";

const mandatory = ["keyboard", "focus", "accessibility", "console", "network"];
const scoped = {
  responsive: "responsive_in_scope",
  reduced_motion: "motion_in_scope",
  reference: "reference_in_scope",
};

export function validateUiDeclaration(recipe) {
  const mode = Object.hasOwn(recipe, "mode") ? recipe.mode : "product";
  assert.ok(["product", "ui"].includes(mode), "Recipe mode must be product or ui");
  if (mode !== "ui") {
    assert.ok(!Object.hasOwn(recipe, "ui"), "UI observations require explicit recipe mode ui");
    return;
  }
  const ui = recipe.ui;
  assert.ok(ui && typeof ui === "object" && !Array.isArray(ui), "UI recipe needs ui scope and observation commands");
  assert.deepEqual(
    Object.keys(ui).sort(),
    ["motion_in_scope", "not_applicable_reasons", "observation", "reference_in_scope", "responsive_in_scope"],
    "UI recipe needs explicit scopes, not_applicable_reasons and observation",
  );
  const reasons = ui.not_applicable_reasons;
  assert.ok(reasons && typeof reasons === "object" && !Array.isArray(reasons), "UI recipe needs not_applicable_reasons");
  for (const key of Object.keys(reasons)) {
    assert.ok(Object.hasOwn(scoped, key), `Unknown UI not-applicable check: ${key}`);
    assert.ok(typeof reasons[key] === "string" && reasons[key].trim(), `UI ${key} needs a not-applicable reason`);
  }
  for (const [check, scope] of Object.entries(scoped)) {
    assert.equal(typeof ui[scope], "boolean", `Declare UI ${scope} explicitly`);
    if (!ui[scope])
      assert.ok(typeof reasons[check] === "string" && reasons[check].trim(), `UI ${check} needs a not-applicable reason`);
  }
}

export function pendingUiEvidence(ui) {
  const checks = {};
  for (const check of [...mandatory, ...Object.keys(scoped)])
    checks[check] = Object.hasOwn(scoped, check) && !ui[scoped[check]]
      ? { status: "not_applicable", evidence: [], reason: ui.not_applicable_reasons[check] }
      : { status: "blocked", evidence: [], reason: "UI observation did not complete" };
  return {
    responsive_in_scope: ui.responsive_in_scope,
    motion_in_scope: ui.motion_in_scope,
    reference_in_scope: ui.reference_in_scope,
    viewports: [],
    checks,
  };
}

export function observedUiEvidence(ui, observation, artifactId) {
  const evidence = pendingUiEvidence(ui);
  for (const check of [...mandatory, ...Object.keys(scoped)]) {
    if (evidence.checks[check].status === "not_applicable") continue;
    assert.equal(observation?.checks?.[check], true, `UI ${check} needs a true observed check`);
    evidence.checks[check] = { status: "passed", evidence: [artifactId] };
  }
  assert.ok(Array.isArray(observation.viewports) && observation.viewports.length, "UI observation needs actual viewports");
  evidence.viewports = observation.viewports.map(({ label, width, height }) => {
    assert.ok(typeof label === "string" && label.trim(), "UI viewport needs a label");
    assert.ok(Number.isSafeInteger(width) && width > 0 && Number.isSafeInteger(height) && height > 0, "UI viewport needs positive observed dimensions");
    return { label, width, height, evidence: [artifactId] };
  });
  if (ui.responsive_in_scope)
    assert.ok(new Set(evidence.viewports.map(({ width, height }) => `${width}x${height}`)).size >= 2, "UI responsive proof requires at least two observed sizes");
  return evidence;
}
