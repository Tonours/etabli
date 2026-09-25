// tests/token-noninferiority.test.mjs — T8a AC3(b) frozen oracle vectors.
// Run: bun test tests/token-noninferiority.test.mjs
import { describe, expect, test } from "bun:test";
import {
  checkMargin, evaluateCompare, reduceMajority,
} from "../scripts/lib/skill-eval-noninferiority.mjs";

function run(run, verdict, veto = null) {
  return { run, verdict, veto };
}

function task(task_id, baselineVerdicts, candidateVerdicts, vetoes = {}) {
  const arm = (verdicts, variant) => ({
    runs: verdicts.map((verdict, i) => {
      const key = `${variant}:${i + 1}`;
      return run(i + 1, verdict, vetoes[key] ?? null);
    }),
  });
  return { task_id, baseline: arm(baselineVerdicts, "baseline"), candidate: arm(candidateVerdicts, "candidate") };
}

function compare(tasks, clean = true) {
  return { schema_version: 1, clean, tasks };
}

function twelveAllPass() {
  return compare(Array.from({ length: 12 }, (_, i) => task(
    `s${i + 1}`, ["pass", "pass", "pass"], ["pass", "pass", "pass"],
  )));
}

describe("majority reduction", () => {
  test("2-of-3 passes", () => {
    expect(reduceMajority([run(1, "pass"), run(2, "pass"), run(3, "fail")])).toBe(true);
  });
  test("1-of-3 fails", () => {
    expect(reduceMajority([run(1, "pass"), run(2, "fail"), run(3, "fail")])).toBe(false);
  });
  test("single run passes iff pass", () => {
    expect(reduceMajority([run(1, "pass")])).toBe(true);
    expect(reduceMajority([run(1, "fail")])).toBe(false);
  });
});

describe("margin helper", () => {
  test("exact 2-point edge holds", () => {
    expect(checkMargin(98, 100)).toBe(true);
  });
  test("below the edge fails", () => {
    expect(checkMargin(97.99, 100)).toBe(false);
  });
  test("improvement holds", () => {
    expect(checkMargin(100, 50)).toBe(true);
  });
});

describe("frozen verdict vectors", () => {
  test("12-task all-pass => PASS", () => {
    const r = evaluateCompare(twelveAllPass());
    expect(r.verdict).toBe("PASS");
  });

  test("1-in-3 veto (1 faulty + 2 clean) => FAIL before majority", () => {
    const tasks = Array.from({ length: 12 }, (_, i) => task(
      `s${i + 1}`, ["pass", "pass", "pass"], ["pass", "pass", "pass"],
    ));
    tasks[4] = task("s5", ["pass", "pass", "pass"], ["pass", "pass", "pass"], {
      "candidate:2": { type: "lost_requirement", detail: "F1 dropped on run 2" },
    });
    const r = evaluateCompare(compare(tasks));
    expect(r.verdict).toBe("FAIL");
    expect(r.reason).toContain("VETO");
  });

  test("lone No-findings on a planted defect => FAIL veto", () => {
    const tasks = Array.from({ length: 12 }, (_, i) => task(
      `s${i + 1}`, ["pass", "pass", "pass"], ["pass", "pass", "pass"],
    ));
    tasks[9] = task("s10", ["pass", "pass", "pass"], ["pass", "pass", "pass"], {
      "baseline:1": { type: "false_completion", detail: "No findings. on pp-null-deref" },
    });
    const r = evaluateCompare(compare(tasks));
    expect(r.verdict).toBe("FAIL");
    expect(r.reason).toContain("VETO");
  });

  test("write-surface veto => FAIL", () => {
    const tasks = Array.from({ length: 12 }, (_, i) => task(
      `s${i + 1}`, ["pass", "pass", "pass"], ["pass", "pass", "pass"],
    ));
    tasks[0] = task("s1", ["pass", "pass", "pass"], ["pass", "pass", "pass"], {
      "candidate:1": { type: "write_surface", detail: "plan-loop task wrote a file" },
    });
    expect(evaluateCompare(compare(tasks)).verdict).toBe("FAIL");
  });

  test("baseline-pass -> candidate-fail flip => FAIL", () => {
    const tasks = Array.from({ length: 12 }, (_, i) => task(
      `s${i + 1}`, ["pass", "pass", "pass"], ["pass", "pass", "pass"],
    ));
    tasks[2] = task("s3", ["pass", "pass", "pass"], ["fail", "fail", "fail"]);
    const r = evaluateCompare(compare(tasks));
    expect(r.verdict).toBe("FAIL");
    expect(r.reason).toContain("flip");
  });

  test("candidate improvement without flips => PASS", () => {
    const tasks = Array.from({ length: 12 }, (_, i) => task(
      `s${i + 1}`, ["fail", "fail", "fail"], ["pass", "pass", "pass"],
    ));
    expect(evaluateCompare(compare(tasks)).verdict).toBe("PASS");
  });

  test("all-fail both variants => PASS (no flips, margin 0 >= -2)", () => {
    const tasks = Array.from({ length: 12 }, (_, i) => task(
      `s${i + 1}`, ["fail", "fail", "fail"], ["fail", "fail", "fail"],
    ));
    expect(evaluateCompare(compare(tasks)).verdict).toBe("PASS");
  });

  test("INVALID candidate run => INCONCLUSIVE", () => {
    const tasks = Array.from({ length: 12 }, (_, i) => task(
      `s${i + 1}`, ["pass", "pass", "pass"], ["pass", "pass", "pass"],
    ));
    tasks[8] = task("s9", ["pass", "pass", "pass"], ["pass", "invalid", "pass"]);
    const r = evaluateCompare(compare(tasks));
    expect(r.verdict).toBe("INCONCLUSIVE");
  });

  test("veto + INVALID => FAIL (vetoes decided before INVALID)", () => {
    const tasks = Array.from({ length: 12 }, (_, i) => task(
      `s${i + 1}`, ["pass", "pass", "pass"], ["pass", "pass", "pass"],
    ));
    tasks[8] = task("s9", ["pass", "pass", "pass"], ["pass", "invalid", "pass"], {
      "candidate:3": { type: "false_completion", detail: "uncited checklist" },
    });
    const r = evaluateCompare(compare(tasks));
    expect(r.verdict).toBe("FAIL");
    expect(r.reason).toContain("VETO");
  });

  test("unclean compare => FAIL", () => {
    expect(evaluateCompare(twelveAllPass()).verdict).toBe("PASS");
    expect(evaluateCompare(compare(twelveAllPass().tasks, false)).verdict).toBe("FAIL");
  });

  test("linkage shape (2 tasks x 1 run, all pass) => PASS", () => {
    const c = compare([
      task("s1", ["pass"], ["pass"]),
      task("s5", ["pass"], ["pass"]),
    ]);
    expect(evaluateCompare(c).verdict).toBe("PASS");
  });
});

describe("tampered compare.json", () => {
  test("wrong schema_version throws", () => {
    expect(() => evaluateCompare({ schema_version: 2, clean: true, tasks: [] })).toThrow();
  });
  test("empty tasks throws", () => {
    expect(() => evaluateCompare({ schema_version: 1, clean: true, tasks: [] })).toThrow();
  });
  test("baseline invalid verdict throws", () => {
    expect(() => evaluateCompare(compare([task("s1", ["invalid"], ["pass"])]))).toThrow();
  });
  test("duplicate task ids throw", () => {
    expect(() => evaluateCompare(compare([
      task("s1", ["pass"], ["pass"]),
      task("s1", ["pass"], ["pass"]),
    ]))).toThrow();
  });
});
