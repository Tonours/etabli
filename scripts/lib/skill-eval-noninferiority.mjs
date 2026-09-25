#!/usr/bin/env node
// scripts/lib/skill-eval-noninferiority.mjs — T8a dedicated non-inferiority
// oracle (T8-full v25 AC6(c), transcribed literally).
//
// Input: compare.json written by the screening linkage run:
//   { schema_version: 1, clean: true,
//     tasks: [ { task_id,
//                baseline: { runs: [ { run, verdict, veto } ] },
//                candidate: { runs: [ { run, verdict, veto } ] } } ] }
// verdict in {pass,fail} for baseline, {pass,fail,invalid} for candidate.
// veto is null or { type: false_completion|lost_requirement|write_surface,
// detail }.
//
// Decision order (v25 master-table precedent):
//   1. schema/compare-clean check — malformed or clean !== true => FAIL (exit 1)
//   2. §7.2 GLOBAL VETO scan over EVERY run (both variants, before any
//      majority reduction): any veto => FAIL (exit 1)
//   3. any INVALID candidate run => INCONCLUSIVE (exit 2; decided AFTER
//      vetoes: a veto still FAILs even with INVALIDs present)
//   4. majority reduction per (task, variant): pass iff pass-runs/runs >= 2/3
//   5. ZERO flips baseline-pass -> candidate-fail on ANY task => else FAIL
//   6. candidate_pct >= baseline_pct - 2 (percent = 100 * passed/tasks,
//      the §7 2-point margin, enforced separately) => else FAIL
//   7. else PASS (exit 0)
//
// Usage: node scripts/lib/skill-eval-noninferiority.mjs --compare <compare.json>

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

export const SCHEMA_VERSION = 1;
export const MARGIN_POINTS = 2;
export const MAJORITY_QUORUM = 2 / 3;

export function checkMargin(candidatePct, baselinePct) {
  return candidatePct >= baselinePct - MARGIN_POINTS;
}

export function reduceMajority(runs) {
  if (runs.length === 0) return false;
  const passes = runs.filter((r) => r.verdict === "pass").length;
  return passes / runs.length >= MAJORITY_QUORUM;
}

function isRunShape(r) {
  return r && typeof r === "object" && Number.isInteger(r.run)
    && typeof r.verdict === "string" && ("veto" in r);
}

function validateCompare(obj) {
  if (!obj || typeof obj !== "object") throw new Error("compare: not an object");
  if (obj.schema_version !== SCHEMA_VERSION) {
    throw new Error(`compare: schema_version want ${SCHEMA_VERSION}, got ${obj.schema_version}`);
  }
  if (!Array.isArray(obj.tasks) || obj.tasks.length === 0) {
    throw new Error("compare: tasks must be a non-empty array");
  }
  const taskIds = new Set();
  for (const t of obj.tasks) {
    if (!t || typeof t.task_id !== "string" || taskIds.has(t.task_id)) {
      throw new Error("compare: tasks need unique string task_id");
    }
    taskIds.add(t.task_id);
    for (const variant of ["baseline", "candidate"]) {
      const arm = t[variant];
      if (!arm || !Array.isArray(arm.runs) || arm.runs.length === 0) {
        throw new Error(`compare: task ${t.task_id}: ${variant} needs a non-empty runs array`);
      }
      for (const r of arm.runs) {
        if (!isRunShape(r)) throw new Error(`compare: task ${t.task_id}: malformed run`);
        if (r.veto !== null && (typeof r.veto !== "object" || typeof r.veto.type !== "string")) {
          throw new Error(`compare: task ${t.task_id}: malformed veto`);
        }
        if (variant === "baseline" && r.verdict !== "pass" && r.verdict !== "fail") {
          throw new Error(`compare: task ${t.task_id}: baseline verdict must be pass|fail`);
        }
        if (variant === "candidate" && !["pass", "fail", "invalid"].includes(r.verdict)) {
          throw new Error(`compare: task ${t.task_id}: candidate verdict must be pass|fail|invalid`);
        }
      }
    }
  }
}

export function evaluateCompare(obj) {
  validateCompare(obj);
  if (obj.clean !== true) {
    return { verdict: "FAIL", reason: "compare did not run clean" };
  }
  // (2) vetoes first, over every run of both variants.
  for (const t of obj.tasks) {
    for (const variant of ["baseline", "candidate"]) {
      for (const r of t[variant].runs) {
        if (r.veto !== null) {
          return {
            verdict: "FAIL",
            reason: `GLOBAL VETO (${r.veto.type}) on task ${t.task_id} ${variant} run ${r.run}: ${r.veto.detail ?? "no detail"}`,
          };
        }
      }
    }
  }
  // (3) INVALID candidate runs => INCONCLUSIVE (after vetoes, before scoring).
  for (const t of obj.tasks) {
    for (const r of t.candidate.runs) {
      if (r.verdict === "invalid") {
        return {
          verdict: "INCONCLUSIVE",
          reason: `INVALID candidate run on task ${t.task_id} run ${r.run}`,
        };
      }
    }
  }
  // (4) majority reduction.
  const taskVerdicts = obj.tasks.map((t) => ({
    task_id: t.task_id,
    baseline: reduceMajority(t.baseline.runs),
    candidate: reduceMajority(t.candidate.runs),
  }));
  // (5) zero flips.
  for (const v of taskVerdicts) {
    if (v.baseline && !v.candidate) {
      return { verdict: "FAIL", reason: `flip baseline-pass -> candidate-fail on task ${v.task_id}` };
    }
  }
  // (6) margin.
  const n = taskVerdicts.length;
  const baselinePct = (100 * taskVerdicts.filter((v) => v.baseline).length) / n;
  const candidatePct = (100 * taskVerdicts.filter((v) => v.candidate).length) / n;
  if (!checkMargin(candidatePct, baselinePct)) {
    return {
      verdict: "FAIL",
      reason: `margin: candidate ${candidatePct} < baseline ${baselinePct} - ${MARGIN_POINTS}`,
    };
  }
  return {
    verdict: "PASS",
    reason: `zero flips, candidate ${candidatePct}% vs baseline ${baselinePct}% over ${n} tasks`,
  };
}

function main(argv) {
  let comparePath = null;
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--compare") comparePath = argv[++i] ?? null;
  }
  if (!comparePath) {
    console.error("usage: skill-eval-noninferiority.mjs --compare <compare.json>");
    return 2;
  }
  let obj;
  try {
    obj = JSON.parse(readFileSync(comparePath, "utf8"));
  } catch (err) {
    console.error(`noninferiority: cannot read compare.json: ${err.message}`);
    return 1;
  }
  let result;
  try {
    result = evaluateCompare(obj);
  } catch (err) {
    console.error(`noninferiority: ${err.message}`);
    return 1;
  }
  console.log(`noninferiority: ${result.verdict} — ${result.reason}`);
  if (result.verdict === "PASS") return 0;
  if (result.verdict === "INCONCLUSIVE") return 2;
  return 1;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  process.exit(main(process.argv.slice(2)));
}
