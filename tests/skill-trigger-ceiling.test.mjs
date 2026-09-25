// Reference vectors for the ceiling-bar rule (independent of the smoke).
// Run from tests/skill-trigger-eval-smoke.sh.
import test from "node:test";
import assert from "node:assert/strict";
import { ceilingBarResult } from "../scripts/lib/skill-eval-ceiling.mjs";

function verdictDoc(overrides = {}) {
  const base = {
    verdict: "rejected",
    reasons: ["objective_not_met", "baseline_safety_incomplete"],
    baseline: { splits: { held_in: { passed: 12, total: 12 }, safety: { passed: 3, total: 4 } } },
    candidate: { splits: { held_in: { passed: 12, total: 12 }, safety: { passed: 4, total: 4 } } },
    regressions: { held_in: [], held_out: [], safety: [] },
  };
  return { ...base, ...overrides };
}

test("accepted verdict takes the accepted path", () => {
  assert.equal(ceilingBarResult({ verdict: "accepted" }).path, "accepted");
});

test("ceiling holds with the waiver branch", () => {
  const r = ceilingBarResult(verdictDoc());
  assert.equal(r.path, "ceiling");
});

test("task regression rejects", () => {
  const v = verdictDoc();
  v.regressions = { held_in: [], held_out: [], safety: [{ task_id: "s-none-deploy" }] };
  assert.equal(ceilingBarResult(v).path, "reject");
});

test("extra reason rejects", () => {
  const v = verdictDoc();
  v.reasons = [...v.reasons, "safety_regression"];
  assert.equal(ceilingBarResult(v).path, "reject");
});

test("incomplete candidate safety voids the waiver", () => {
  const v = verdictDoc();
  v.candidate.splits.safety.passed = 3;
  assert.equal(ceilingBarResult(v).path, "reject");
});

test("held_in drop rejects", () => {
  const v = verdictDoc();
  v.candidate.splits.held_in.passed = 11;
  assert.equal(ceilingBarResult(v).path, "reject");
});

test("unsaturated baseline rejects the ceiling path", () => {
  const v = verdictDoc();
  v.baseline.splits.held_in.passed = 11;
  assert.equal(ceilingBarResult(v).path, "reject");
});
