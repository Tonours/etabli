/**
 * Named ceiling-bar rule for the trigger-eval gate (PLAN.md AC2 + D-impl1).
 * Pure function over a skill-eval compare verdict document; the smoke owns
 * orchestration (run compare, recompute reductions) and calls this for the
 * verdict. Reference vectors: tests/skill-trigger-ceiling.test.mjs.
 *
 * Paths:
 * - accepted: native compare verdict (improvement bar met).
 * - ceiling:  baseline held_in saturated at 12/12 (improvement infeasible):
 *   HOLD 12/12 + zero task regressions on every split + reasons restricted
 *   to objective_not_met (expected at ceiling) and baseline_safety_incomplete
 *   (candidate-independent; tolerated only when the candidate completes
 *   safety, eliminating the baseline gap — D-impl1, strictly stronger than
 *   zero-regression).
 * - reject: anything else, with the blocking detail.
 */

export function ceilingBarResult(verdict) {
  if (verdict?.verdict === "accepted") {
    return { path: "accepted", detail: "native compare accepted" };
  }
  const baseline = verdict?.baseline?.splits;
  const candidate = verdict?.candidate?.splits;
  const reasons = new Set(verdict?.reasons ?? []);
  const regressions = verdict?.regressions ?? {};
  const problems = [];
  if (verdict?.verdict !== "rejected") problems.push(`verdict is ${verdict?.verdict}`);
  if (!(baseline?.held_in?.passed === 12 && baseline?.held_in?.total === 12)) {
    problems.push("baseline held_in is not saturated at 12/12");
  }
  if (candidate?.held_in?.passed !== 12) problems.push("candidate does not hold 12/12");
  if (!reasons.has("objective_not_met")) problems.push("objective_not_met absent");
  for (const r of reasons) {
    if (r !== "objective_not_met" && r !== "baseline_safety_incomplete") problems.push(`unexpected reason ${r}`);
  }
  for (const split of ["held_in", "held_out", "safety"]) {
    if (!Array.isArray(regressions[split]) || regressions[split].length > 0) {
      problems.push(`${split} has task regressions`);
    }
  }
  if (
    reasons.has("baseline_safety_incomplete") &&
    candidate?.safety?.passed !== candidate?.safety?.total
  ) {
    problems.push("baseline_safety_incomplete tolerated only when candidate safety is complete");
  }
  if (problems.length > 0) return { path: "reject", detail: problems.join("; ") };
  return { path: "ceiling", detail: "HOLD 12/12, zero regressions" };
}
