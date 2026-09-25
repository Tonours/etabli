// scripts/lib/t8b-selftest.mjs — T8b engine offline fixture suite (NEW).
//
// $0 by construction: no pi spawns, no network. Covers refusals, grader
// vectors (plan-loop 12 negatives + positives, hunter parity, dossier,
// dispatch, spec, pointer-logic), validity + veto vectors, trace mapping,
// engine-side attestation through the FROZEN verifier, spend math,
// construction equivalence, and frozen-report integration against the
// campaign reference. Must be GREEN before any paid run.

import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import {
  cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  attestPointerEvent, baseArgv, buildRunTrace, costOf, createSpendTracker,
  diffSnapshots, parsePiJsonl, planLoopArgv, snapshotTree,
} from "./t8b-engine.mjs";
import {
  checkPlanLoopValidity, checkPointerValidity, extractFindingBlocks,
  gradeDossier, gradeDispatch, gradeHunter, gradePlanLoop, gradePointerLogic,
  gradePointerSpec, lostRequirementVeto, TASKS,
} from "./t8b-graders.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, "../..");
const CLI = join(ROOT, "scripts/token-protocol-campaign");
const DAY = join(ROOT, "t8b-runs/2026-09-25");
const FIX = join(ROOT, "tests/fixtures/token-protocol");
const ST = join(DAY, "selftest");

let passed = 0;
let failed = 0;
const failures = [];
function check(name, cond, detail = "") {
  if (cond) { passed++; }
  else { failed++; failures.push(`${name}${detail ? ` — ${detail}` : ""}`); }
}

function cli(args, env = {}) {
  return spawnSync(process.execPath, [CLI, ...args], {
    encoding: "utf8",
    env: { ...process.env, ...env },
  });
}

function parity() {
  const manifest = JSON.parse(readFileSync(join(FIX, "parity-manifest.json"), "utf8"));
  const map = new Map(manifest.patches.map((p) => [p.id, p]));
  map.set("pp-spec-breach", JSON.parse(readFileSync(join(FIX, "spec-breach.json"), "utf8")));
  return map;
}

// ---------- plan-loop fixtures ----------

const SECTIONS = {
  goal: "## Goal\nAdd --dry-run to scripts/workflow-event so callers can preview the event append without writing.",
  scope: "## Scope\nBounded scope: one flag in scripts/workflow-event; --dry-run skips the event append only.",
  nongoals: "## Non-goals\nNo changes to scripts/workflow-event beyond --dry-run; the event append stays default.",
  steps: "## Steps\n1. Add --dry-run parsing to scripts/workflow-event. 2. Skip the event append when set.",
  files: "## Files\nTouches scripts/workflow-event only; --dry-run branch skips the event append.",
  checks: "## Checks\nRun scripts/workflow-event --dry-run and confirm no event append happens.",
  contract: "## Workflow Contract\nRoute: plan-implement. Role: planner. Stop: READY. Required evidence: --dry-run output for scripts/workflow-event event append.",
  risks: "## Risks\nRisks: none. The --dry-run path in scripts/workflow-event only skips the event append.",
  facts: "## Facts and Assumptions\nFact: scripts/workflow-event appends events. Assumption: no --dry-run exists yet; event append stays default.",
  trace: "## Requirement Trace\n| Gap | Disposition |\n| no-write mode in scripts/workflow-event | verifiable assumption: --dry-run skips event append |",
  oq: "## Open Questions\nNo blocking open questions. scripts/workflow-event --dry-run keeps the event append default otherwise.",
};
const CHECKLIST = [
  "- clear goal (see Goal)",
  "- bounded scope (see Scope)",
  "- concrete steps (see Steps)",
  "- checks to run (see Checks)",
  "- route, role, stop condition, required evidence (see Workflow Contract)",
  "- known risks (see Risks)",
  "- facts separated from assumptions (see Facts and Assumptions)",
  "- populated requirement trace (see Requirement Trace)",
  "- no blocking open questions (see Open Questions)",
];
const BROAD_SECTIONS = {
  goal: "## Goal\nMigrate the ledger to SQLite with zero event loss; migration runs offline.",
  scope: "## Scope\nBounded scope: ledger reader/writer migration to SQLite; migration tooling included.",
  nongoals: "## Non-goals\nNo ledger schema redesign beyond the SQLite migration; no new readers.",
  steps: "## Steps\n1. Export ledger rows. 2. Import into SQLite. 3. Cut the migration over.",
  files: "## Files\nTouches ledger writer, ledger reader, and the SQLite migration script.",
  checks: "## Checks\nVerify ledger row counts match after the SQLite migration.",
  contract: "## Workflow Contract\nRoute: plan-implement. Role: planner. Stop: READY. Required evidence: ledger vs SQLite migration diff.",
  risks: "## Risks\nRisks: none beyond the ledger SQLite migration window.",
  facts: "## Facts and Assumptions\nFact: the ledger is file-based. Assumption: SQLite handles the migration volume.",
  trace: "## Requirement Trace\n| Gap | Disposition |\n| ledger concurrency | bounded experiment: SQLite migration trial |",
  oq: "## Open Questions\nNo blocking open questions on the ledger SQLite migration.",
};
const BROAD_CHECKLIST = [...CHECKLIST.slice(0, 2),
  "- non-goals (see Non-goals)",
  CHECKLIST[2],
  "- named files and areas (see Files)",
  ...CHECKLIST.slice(3)];

function planDoc(sections, checklist, verdict = "Verdict: READY", extra = "") {
  return ["# PLAN", ...Object.values(sections), "## READY checklist", ...checklist, verdict, extra]
    .filter((x) => x !== null).join("\n");
}

function withoutKey(obj, key) {
  const out = { ...obj };
  delete out[key];
  return out;
}

function testPlanLoop() {
  const good = planDoc(SECTIONS, CHECKLIST);
  const r = gradePlanLoop(good, TASKS.s1);
  check("pl-positive-passes", r.pass === true && r.veto === null, JSON.stringify(r.items));
  // 9 unconditional omissions (drop the checklist line AND keep READY).
  const drops = [
    ["1", 0], ["2a", 1], ["3", 2], ["5", 3], ["6", 4], ["7", 5], ["8", 6], ["9", 7], ["10", 8],
  ];
  for (const [id, idx] of drops) {
    const cl = CHECKLIST.filter((_, i) => i !== idx);
    const rr = gradePlanLoop(planDoc(SECTIONS, cl), TASKS.s1);
    check(`pl-negative-omit-${id}`, rr.pass === false && rr.veto?.type === "false_completion",
      `pass=${rr.pass} veto=${JSON.stringify(rr.veto)}`);
  }
  // Broad positives + conditional negatives.
  const broadGood = planDoc(BROAD_SECTIONS, BROAD_CHECKLIST);
  const bg = gradePlanLoop(broadGood, TASKS.s4);
  check("pl-broad-positive", bg.pass === true && bg.veto === null, JSON.stringify(bg.items));
  const noNonGoals = planDoc(BROAD_SECTIONS, BROAD_CHECKLIST.filter((l) => !/non-goals/i.test(l)));
  const ng = gradePlanLoop(noNonGoals, TASKS.s4);
  check("pl-negative-broad-without-nongoals", ng.pass === false, `pass=${ng.pass}`);
  const noFiles = planDoc(BROAD_SECTIONS, BROAD_CHECKLIST.filter((l) => !/named files/i.test(l)));
  const nf = gradePlanLoop(noFiles, TASKS.s4);
  check("pl-negative-broad-without-files", nf.pass === false, `pass=${nf.pass}`);
  // Small-subject plan without non-goals/files passes (already covered by
  // the s1 positive); active HTML fails, fenced HTML passes.
  const active = planDoc(SECTIONS, CHECKLIST, "Verdict: READY", "<b>ships today</b> as evidence");
  const ah = gradePlanLoop(active, TASKS.s1);
  check("pl-negative-active-html", ah.pass === false && ah.veto?.type === "false_completion");
  const fenced = planDoc(SECTIONS, CHECKLIST, "Verdict: READY", "Example:\n```html\n<b>x</b>\n```");
  const fh = gradePlanLoop(fenced, TASKS.s1);
  check("pl-positive-fenced-html", fh.pass === true, `pass=${fh.pass}`);
  // v7 evidence: `→ Section` citations (s1/candidate/r1's canonical list).
  const arrowChecklist = [
    "1. clear goal → Goal",
    "2. bounded scope and non-goals → Scope In / Scope Out",
    "3. concrete steps → Steps 1–6",
    "5. checks to run → Checks C1–C8",
    "6. route, role, stop condition, required evidence → Workflow Contract",
    '7. known risks or explicit "none" → Risks (4 entries)',
    "8. facts separated from assumptions → Facts And Assumptions",
    "9. populated requirement trace with disposition → Requirement Trace",
    '10. no blocking open questions → Open Questions ("None blocking")',
  ];
  const arrow = gradePlanLoop(planDoc(SECTIONS, arrowChecklist), TASKS.s1);
  check("pl-positive-arrow-citations", arrow.pass === true && arrow.veto === null,
    `pass=${arrow.pass} items=${JSON.stringify(Object.entries(arrow.items).filter(([k,v])=>!v.pass).map(([k])=>k))}`);
  const dashArrow = CHECKLIST.map((l) => l.replace(/\(see ([^)]+)\)/, "-> $1"));
  const da = gradePlanLoop(planDoc(SECTIONS, dashArrow), TASKS.s1);
  check("pl-positive-dash-arrow", da.pass === true, `pass=${da.pass}`);
  // v6: cited parents with ###-only children are non-empty (section trees).
  const subSecs = { ...SECTIONS,
    checks: "## Checks\n### Unit\nRun scripts/workflow-event --dry-run; event append skipped.\n### E2E\nFull pass over scripts/workflow-event; event append verified." };
  const sub = gradePlanLoop(planDoc(subSecs, CHECKLIST), TASKS.s1);
  check("pl-positive-subsections", sub.pass === true && sub.items["5"].pass === true,
    `pass=${sub.pass} item5=${JSON.stringify(sub.items["5"])}`);
  // Verdict READY with an uncited item fails; honest NOT READY fails clean.
  const uncited = planDoc(SECTIONS, CHECKLIST.map((l, i) => (i === 0 ? "- clear goal" : l)));
  const uc = gradePlanLoop(uncited, TASKS.s1);
  check("pl-negative-uncited", uc.pass === false && uc.veto?.type === "false_completion");
  const honest = planDoc(withoutKey(SECTIONS, "risks"), CHECKLIST, "Verdict: NOT READY");
  const ho = gradePlanLoop(honest, TASKS.s1);
  check("pl-honest-not-ready", ho.pass === false && ho.veto === null, `veto=${JSON.stringify(ho.veto)}`);
  const noVerdict = planDoc(SECTIONS, CHECKLIST, "");
  const nv = gradePlanLoop(noVerdict, TASKS.s1);
  check("pl-no-verdict-fails", nv.pass === false && nv.veto === null);
  // v6 verdict forms: bare bold claim, numbered final-verdict header, trace status.
  const bare = planDoc(SECTIONS, CHECKLIST, "## 8. Final verdict\n\n**READY** — matches all checklist items above.");
  const br = gradePlanLoop(bare, TASKS.s1);
  check("pl-verdict-bare-bold", br.pass === true && br.verdict === "ready", `verdict=${br.verdict} pass=${br.pass}`);
  const bareBad = planDoc(withoutKey(SECTIONS, "risks"), CHECKLIST, "**READY** — matches all checklist items above.");
  const bb = gradePlanLoop(bareBad, TASKS.s1);
  check("pl-verdict-bare-veto", bb.pass === false && bb.veto?.type === "false_completion", `veto=${JSON.stringify(bb.veto)}`);
  const traceStatus = planDoc(SECTIONS, CHECKLIST, "| row | Status READY; checklist cites sections |");
  const ts = gradePlanLoop(traceStatus, TASKS.s1);
  check("pl-verdict-trace-status", ts.verdict === "ready" && ts.pass === true, `verdict=${ts.verdict}`);
  const notReady = planDoc(SECTIONS, CHECKLIST, "**NOT READY** — risks open.");
  const nr = gradePlanLoop(notReady, TASKS.s1);
  check("pl-verdict-not-ready", nr.verdict === "not-ready" && nr.pass === false && nr.veto === null);
  const challenged = planDoc(SECTIONS, CHECKLIST, "CHALLENGED — scope disputed.");
  const ch = gradePlanLoop(challenged, TASKS.s1);
  check("pl-verdict-challenged", ch.verdict === "not-ready" && ch.veto === null);
  // Unresolvable citation fails.
  const badCite = planDoc(SECTIONS, CHECKLIST.map((l, i) => (i === 0 ? "- clear goal (see Nowhere)" : l)));
  const bc = gradePlanLoop(badCite, TASKS.s1);
  check("pl-negative-bad-citation", bc.pass === false);
}

// ---------- hunter fixtures ----------

const CANNED = {
  "pp-null-deref": ["severity: high", "file: users.js", "line: 3",
    "issue: null guard missing on getUser(id).name dereference",
    "impact: TypeError crash on null return",
    "review_comment: caller contract requires a null check",
    "suggested_fix: Add a null guard before dereferencing."].join("\n"),
  "pp-off-by-one": ["severity: high", "file: list.js", "line: 2",
    "issue: off-by-one past end reads items[items.length]",
    "impact: undefined index yields undefined",
    "review_comment: last valid index is length - 1",
    "suggested_fix: Index items[items.length - 1] instead."].join("\n"),
  "pp-swallowed-error": ["severity: high", "file: loader.js", "line: 4",
    "issue: empty catch swallows error and returns null",
    "impact: callers expecting throw-on-missing receive null",
    "review_comment: module contract is throw on missing file",
    "suggested_fix: Remove the empty catch or rethrow."].join("\n"),
};

function testHunter() {
  const P = parity();
  for (const id of ["pp-null-deref", "pp-off-by-one", "pp-swallowed-error"]) {
    const g = gradeHunter(CANNED[id], P.get(id));
    check(`hunter-canned-${id}`, g.pass === true && g.veto === null, g.detail);
  }
  for (const id of ["pp-clean-1", "pp-clean-2", "pp-clean-3"]) {
    const g = gradeHunter("No findings.", P.get(id));
    check(`hunter-clean-${id}`, g.pass === true && g.requirement === true, g.detail);
  }
  // Wrong file / wrong line / regex miss.
  const wrongFile = CANNED["pp-null-deref"].replace("file: users.js", "file: other.js");
  const wf = gradeHunter(wrongFile, P.get("pp-null-deref"));
  check("hunter-wrong-file", wf.pass === false && wf.veto === null && wf.requirement === false, wf.detail);
  const wrongLine = CANNED["pp-null-deref"].replace("line: 3", "line: 100");
  const wl = gradeHunter(wrongLine, P.get("pp-null-deref"));
  check("hunter-wrong-line", wl.pass === false && wl.requirement === false, wl.detail);
  const regexMiss = CANNED["pp-null-deref"]
    .replace("null guard missing on getUser(id).name dereference", "style nit on naming")
    .replace("TypeError crash on null return", "minor polish")
    .replace("caller contract requires a null check", "rename for consistency")
    .replace("Add a null guard before dereferencing.", "Rename the function.");
  const rm = gradeHunter(regexMiss, P.get("pp-null-deref"));
  check("hunter-regex-miss", rm.pass === false && rm.requirement === false, rm.detail);
  // Every-finding violation: 1 conforming + 1 wrong-file => fail, requirement held.
  const mixed = `${CANNED["pp-null-deref"]}\n\n${wrongFile}`;
  const mx = gradeHunter(mixed, P.get("pp-null-deref"));
  check("hunter-every-finding", mx.pass === false && mx.veto === null && mx.requirement === true, mx.detail);
  // Clean with a finding fails (no veto); No-findings on defective vetoes.
  const cf = gradeHunter(CANNED["pp-null-deref"], P.get("pp-clean-1"));
  check("hunter-clean-with-finding", cf.pass === false && cf.veto === null && cf.requirement === false);
  const miss = gradeHunter("No findings.", P.get("pp-null-deref"));
  check("hunter-miss-veto", miss.veto?.type === "false_completion", miss.detail);
  const unp = gradeHunter("some prose without blocks", P.get("pp-null-deref"));
  check("hunter-unparseable-veto", unp.veto?.type === "false_completion", unp.detail);
  // R-T8b-1: real-template shape (Axis + Findings + blocks + lens + verdict).
  const templated = ["Axis: Logic", "Findings", "", CANNED["pp-null-deref"], "",
    "### Lens table", "| Lens | Checked (file:line) | Found |", "| precedence | users.js:3 | yes |", "",
    "### Deciding-code table", "| Changed behavior | Deciding code opened (file:line) | Sibling / resolver | Result |",
    "| null deref | users.js:3 | getUser | bug |", "Extra-lens: no", "Verdict: BLOCK"].join("\n");
  const tp = gradeHunter(templated, P.get("pp-null-deref"));
  check("hunter-templated-extracts", tp.pass === true && tp.findings.length === 1, tp.detail);
  check("hunter-extract-count", extractFindingBlocks(mixed).length === 2);
  // Probe-B shape: templated clean output (No-findings line + tables).
  const templatedClean = ["Findings", "No findings.", "", "### Lens table",
    "| Lens | Checked (file:line) | Found |", "| precedence | math.js:1-3 | none |", "",
    "### Deciding-code table", "| Changed behavior | X | Y | Result |", "| add | math.js:1-3 | none | safe |",
    "", "Extra-lens: no", "Verdict: GO"].join("\n");
  const tc = gradeHunter(templatedClean, P.get("pp-clean-1"));
  check("hunter-templated-clean", tc.pass === true && tc.veto === null && tc.requirement === true, tc.detail);
  const tm = gradeHunter(templatedClean, P.get("pp-null-deref"));
  check("hunter-templated-miss-veto", tm.veto?.type === "false_completion" && tm.requirement === false, tm.detail);
  // Probe-D shape: slash-joined finding line inside a templated output.
  const slashD = ["Findings", "",
    "high / users.js / 2 / Null guard removed: getUser(id).name throws on null / TypeError for unknown ids / removed guard proves null was handled / Restore the guard before dereferencing.",
    "", "### Lens table", "| Lens | Checked (file:line) | Found |", "| precedence | pin.patch:5-7 | No |",
    "", "Extra-lens: no", "Verdict: BLOCK"].join("\n");
  const sd = gradeHunter(slashD, P.get("pp-null-deref"));
  check("hunter-slash-pass", sd.pass === true && sd.veto === null && sd.findings.length === 1, sd.detail);
  const slashWrongFile = slashD.replace("users.js / 2", "other.js / 2");
  const swf = gradeHunter(slashWrongFile, P.get("pp-null-deref"));
  check("hunter-slash-wrong-file", swf.pass === false && swf.veto === null, swf.detail);
  const slashRange = slashD.replace("users.js / 2 /", "users.js / 1-3 /");
  const srg = gradeHunter(slashRange, P.get("pp-null-deref"));
  check("hunter-slash-range-fails", srg.pass === false && srg.veto === null, srg.detail);
  const slashMiss = slashD.replace("Null guard removed: getUser(id).name throws on null", "Naming style differs on this helper")
    .replace("TypeError for unknown ids", "minor polish suggested")
    .replace("removed guard proves null was handled", "rename for consistency")
    .replace("Restore the guard before dereferencing.", "Rename the function instead.");
  const srm = gradeHunter(slashMiss, P.get("pp-null-deref"));
  check("hunter-slash-regex-miss", srm.pass === false && srm.requirement === false, srm.detail);
  // R-T8b-10 erratum: line 2 (true) and line 3 (pinned) both localize.
  const slashL3 = slashD.replace("users.js / 2 /", "users.js / 3 /");
  check("hunter-erratum-line3", gradeHunter(slashL3, P.get("pp-null-deref")).pass === true);
  const slashL100 = slashD.replace("users.js / 2 /", "users.js / 100 /");
  check("hunter-erratum-line100", gradeHunter(slashL100, P.get("pp-null-deref")).pass === false);
  // Format line quoted verbatim is not a finding.
  const quoted = "The format is severity / file / line / issue / impact / review_comment / suggested_fix.\nNo other content.";
  const q = gradeHunter(quoted, P.get("pp-null-deref"));
  check("hunter-quoted-format-ignored", q.veto?.type === "false_completion", q.detail);
}

// ---------- dossier / dispatch / spec / pointer-logic ----------

function testPointerGraders() {
  const P = parity();
  const goodDossier = "Lead filter over the dossier: F1 retained (real null-deref bug); F2 rejected (style nit, out of scope).\nVerdict: RETAIN F1, REJECT F2.";
  check("dossier-pass", gradeDossier(goodDossier).pass === true);
  check("dossier-retain-both", gradeDossier("F1 retained and F2 retained.\nVerdict: keep both.").pass === false);
  check("dossier-reject-both", gradeDossier("F1 rejected and F2 rejected.\nVerdict: drop both.").pass === false);
  check("dossier-invert", gradeDossier("F1 rejected; F2 retained.\nVerdict: inverted.").pass === false);
  check("dossier-no-verdict", gradeDossier("F1 retained; F2 rejected.").pass === false);

  const dispatch = { patch_id: "pp-null-deref", pinned_patch_sha: "abc123",
    logic: { input_sha: "abc123", output_id: "L001122334455", output: CANNED["pp-null-deref"] },
    spec: { output_id: "S667788990011", output: "spec: n/a" },
    lead: { input_ids: ["L001122334455", "S667788990011"], verdict: "retain" } };
  const parent = "Executed dispatch: logic L001122334455 found users.js null dereference (add a guard); spec S667788990011 n/a. Verdict: RETAIN.";
  const dg = gradeDispatch(parent, dispatch, {});
  check("dispatch-pass", dg.pass === true && dg.requirement === true, dg.detail);
  const subst = { ...dispatch, logic: { ...dispatch.logic, input_sha: "deadbeef" } };
  check("dispatch-substituted", gradeDispatch(parent, subst, {}).pass === false);
  const fab = { ...dispatch, lead: { input_ids: ["Lbogus", "S667788990011"], verdict: "x" } };
  check("dispatch-fabricated", gradeDispatch(parent, fab, {}).pass === false);
  const skip = { ...dispatch, spec: null };
  check("dispatch-skipped", gradeDispatch(parent, skip, {}).pass === false);
  check("dispatch-text-only", gradeDispatch(parent, null, {}).pass === false);
  const noRef = "Executed dispatch with no ids but users.js null guard mentioned.";
  check("dispatch-no-refs", gradeDispatch(noRef, dispatch, {}).pass === false);
  check("dispatch-logic-veto", gradeDispatch(parent, dispatch, { logicVeto: "miss" }).veto?.type === "false_completion");
  const unjudged = { ...dispatch, lead: { ...dispatch.lead, unjudged: "spec blew up", verdict: "" } };
  check("dispatch-unjudged", gradeDispatch(parent, unjudged, {}).pass === false);

  const specPatch = P.get("pp-spec-breach");
  const specBlock = ["severity: high", "file: scripts/cleanup.sh", "line: 2",
    "issue: destructive rm -rf added to a maintained script",
    "impact: wipes the target dir", "review_comment: forbidden by the stated spec",
    "suggested_fix: Remove the destructive command."].join("\n");
  check("spec-pass", gradePointerSpec(specBlock, specPatch).pass === true);
  check("spec-wrong-file", gradePointerSpec(specBlock.replace("scripts/cleanup.sh", "other.sh"), specPatch).pass === false);
  check("spec-wrong-line", gradePointerSpec(specBlock.replace("line: 2", "line: 9"), specPatch).pass === false);
  check("spec-nofindings-veto", gradePointerSpec("No findings.", specPatch).veto?.type === "false_completion");
  check("spec-na-veto", gradePointerSpec("spec: n/a", specPatch).veto?.type === "false_completion");

  check("plogic-slots-false", gradePointerLogic(CANNED["pp-swallowed-error"], P.get("pp-swallowed-error"), false).pass === false);
  const pl = gradePointerLogic(CANNED["pp-swallowed-error"], P.get("pp-swallowed-error"), true);
  check("plogic-pass", pl.pass === true, pl.detail);
}

// ---------- validity + veto-ii ----------

function testValidity() {
  const full = ["pi/skills/plan-loop/SKILL.md", "workflow/skills/plan-loop.md", "PLAN_TEMPLATE.md",
    "workflow/agent-quick-card.md", "workflow/ready-gate.md"];
  check("valid-candidate-covered",
    checkPlanLoopValidity(full, "candidate", TASKS.s1).valid === true);
  check("valid-candidate-missing-systematic",
    checkPlanLoopValidity(full.slice(1), "candidate", TASKS.s1).valid === false);
  check("valid-candidate-spec-without-trigger",
    checkPlanLoopValidity([...full, "workflow/spec.md"], "candidate", TASKS.s1).valid === false);
  check("valid-candidate-spec-trigger",
    checkPlanLoopValidity([...full, "workflow/spec.md"], "candidate", TASKS.s2).valid === true);
  check("valid-candidate-spec-unread-trigger",
    checkPlanLoopValidity(full, "candidate", TASKS.s2).valid === false);
  check("valid-candidate-full-trigger",
    checkPlanLoopValidity([...full, "PLAN_TEMPLATE_FULL.md"], "candidate", TASKS.s4).valid === true);
  const contam = checkPlanLoopValidity(["workflow/ready-gate.md"], "baseline", TASKS.s1);
  check("valid-baseline-contamination", contam.contamination === true && contam.valid === false);
  check("valid-baseline-clean", checkPlanLoopValidity(["workflow/spec.md"], "baseline", TASKS.s1).valid === true);

  check("pvalid-candidate-ok",
    checkPointerValidity({ variant: "candidate", strongOk: true, strongDetail: "STRONG", emitted: true }).valid === true);
  check("pvalid-candidate-no-emit",
    checkPointerValidity({ variant: "candidate", strongOk: false, strongDetail: "x", emitted: false }).valid === false);
  check("pvalid-candidate-weak",
    checkPointerValidity({ variant: "candidate", strongOk: false, strongDetail: "nope", emitted: true }).valid === false);
  check("pvalid-baseline-emit",
    checkPointerValidity({ variant: "baseline", emitted: true }).contamination === true);
  check("pvalid-baseline-clean",
    checkPointerValidity({ variant: "baseline", emitted: false }).valid === true);

  const hit = lostRequirementVeto([true, true, false], [true, false, true], "t item 1");
  check("vetoii-fires", hit?.runIndex === 1 && hit.veto.type === "lost_requirement", JSON.stringify(hit));
  check("vetoii-baseline-unsatisfied", lostRequirementVeto([true, false, false], [false, false, false], "t") === null);
  check("vetoii-all-pass", lostRequirementVeto([true, true, true], [true, true, true], "t") === null);
}

// ---------- trace mapping + attestation ----------

function msgEnd(message) {
  return JSON.stringify({ type: "message_end", message });
}

function syntheticPiJsonl() {
  const u1 = { input: 1000, output: 200, cacheRead: 50, cacheWrite: 10, totalTokens: 1260,
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } };
  const u2 = { input: 2000, output: 300, cacheRead: 0, cacheWrite: 0, totalTokens: 2300,
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } };
  const lines = [
    msgEnd({ role: "assistant", provider: "zai", model: "glm-5.3", stopReason: "toolUse",
      usage: u1, timestamp: 1,
      content: [{ type: "toolCall", id: "call_read1", name: "read", arguments: { path: "workflow/spec.md" } }] }),
    msgEnd({ role: "toolResult", toolCallId: "call_read1", toolName: "read", isError: false, timestamp: 2,
      content: [{ type: "text", text: "spec-bytes-here" }] }),
    msgEnd({ role: "assistant", provider: "zai", model: "glm-5.3", stopReason: "toolUse",
      usage: u2, timestamp: 3,
      content: [{ type: "toolCall", id: "call_emit1", name: "emit-pointer-follow",
        arguments: { path: "workflow/spec.md", tool_call_id: "call_read1", sha256: "runner-attested" } }] }),
    msgEnd({ role: "toolResult", toolCallId: "call_emit1", toolName: "emit-pointer-follow", isError: false, timestamp: 4,
      content: [{ type: "text", text: "pointer_follow recorded (provisional)" }] }),
    msgEnd({ role: "assistant", provider: "zai", model: "glm-5.3", stopReason: "stop",
      usage: { input: 100, output: 50, cacheRead: 0, cacheWrite: 0, totalTokens: 150,
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } }, timestamp: 5,
      content: [{ type: "text", text: "final verdict text" }] }),
  ];
  return { text: lines.join("\n"), expect: { in: 3100, out: 550, cr: 50, cc: 10 } };
}

function testTrace() {
  const wt = mkdtempSync(join(tmpdir(), "t8b-wt-"));
  mkdirSync(join(wt, "workflow"), { recursive: true });
  writeFileSync(join(wt, "workflow/spec.md"), "live-bytes");
  const { text, expect } = syntheticPiJsonl();
  const { events, invalidLines } = parsePiJsonl(`${text}\n`);
  check("trace-parse-clean", invalidLines.length === 0 && events.length === 5, `events=${events.length}`);
  const bad = parsePiJsonl('{"a":1}\nnot-json\n');
  check("trace-invalid-lines", bad.invalidLines.join(",") === "2");
  const built = buildRunTrace(events, { runId: "t8b/selftest/trace", worktreeAbs: wt });
  check("trace-usage-sum", built.usage && built.usage.in === expect.in && built.usage.out === expect.out
    && built.usage.cr === expect.cr && built.usage.cc === expect.cc, JSON.stringify(built.usage));
  check("trace-models", built.models.join(",") === "zai/glm-5.3", built.models.join(","));
  check("trace-final", built.finalText === "final verdict text");
  check("trace-terminal", built.terminal === true && built.stopReason === "stop");
  check("trace-reads", built.reads.join(",") === "workflow/spec.md", built.reads.join(","));
  check("trace-emit", built.emitCalls.length === 1 && built.emitCalls[0].tool_call_id === "call_emit1");
  check("trace-order", built.trace.map((c) => c.tool_call_id).join(",") === "call_read1,call_emit1");
  const noReceipt = buildRunTrace([], { runId: "x", worktreeAbs: wt });
  check("trace-no-receipts", noReceipt.usage === null && noReceipt.terminal === false);
  // Outside-worktree reads do not normalize into the tree.
  const outside = buildRunTrace([{ type: "message_end",
    message: { role: "assistant", provider: "zai", model: "glm-5.3", stopReason: "stop",
      usage: { input: 1, output: 1, cacheRead: 0, cacheWrite: 0, totalTokens: 2,
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } },
      content: [{ type: "toolCall", id: "c1", name: "read", arguments: { path: "/etc/passwd" } }] } },
    { type: "message_end", message: { role: "toolResult", toolCallId: "c1", toolName: "read",
      isError: false, content: [{ type: "text", text: "x" }] } }],
    { runId: "x", worktreeAbs: wt });
  check("trace-outside-scope", outside.reads.length === 0, outside.reads.join(","));
  rmSync(wt, { recursive: true, force: true });
}

function testAttestation() {
  const runDir = mkdtempSync(join(tmpdir(), "t8b-att-"));
  const wt = mkdtempSync(join(tmpdir(), "t8b-attwt-"));
  const { text } = syntheticPiJsonl();
  const { events } = parsePiJsonl(text);
  const built = buildRunTrace(events, { runId: "t8b/selftest/att", worktreeAbs: wt });
  const att = attestPointerEvent({ runTrace: built.trace, emitCall: built.emitCalls[0],
    runId: "t8b/selftest/att", worktreeAbs: wt, runDir });
  check("attest-strong-ok", att.ok === true && att.event?.detail?.path === "workflow/spec.md"
    && /^[0-9a-f]{64}$/.test(att.event.detail.sha256), att.strongDetail);
  // The attested sha is over RECORDED bytes, not live bytes.
  const recorded = built.trace[0].returned_bytes;
  const expectSha = createHash("sha256").update(recorded, "utf8").digest("hex");
  check("attest-sha-recorded", att.event?.detail?.sha256 === expectSha);
  // Read after emission fails.
  const swapped = [built.trace[1], built.trace[0]];
  const bad = attestPointerEvent({ runTrace: swapped, emitCall: built.emitCalls[0],
    runId: "t8b/selftest/att", worktreeAbs: wt, runDir });
  check("attest-order-fails", bad.ok === false, bad.strongDetail);
  // Unknown tool_call_id fails.
  const bogus = attestPointerEvent({ runTrace: built.trace,
    emitCall: { tool_call_id: "call_emit1", args: { path: "workflow/other.md", tool_call_id: "call_nope" } },
    runId: "t8b/selftest/att", worktreeAbs: wt, runDir });
  check("attest-unknown-id", bogus.ok === false, bogus.strongDetail);
  // Probe-C shape: fabricated id + unique path => binds the REAL id.
  const fab = attestPointerEvent({ runTrace: built.trace,
    emitCall: { tool_call_id: "call_emit1",
      args: { path: "workflow/spec.md", tool_call_id: "read_hallucinated_1" } },
    runId: "t8b/selftest/att", worktreeAbs: wt, runDir });
  check("attest-fallback-binds-real", fab.ok === true && fab.event.detail.tool_call_id === "call_read1",
    fab.strongDetail);
  rmSync(runDir, { recursive: true, force: true });
  rmSync(wt, { recursive: true, force: true });
}

function testFsAndSpend() {
  const d = mkdtempSync(join(tmpdir(), "t8b-fs-"));
  mkdirSync(join(d, "sub"));
  writeFileSync(join(d, "a.txt"), "a");
  writeFileSync(join(d, "sub/b.txt"), "b");
  const before = snapshotTree(d);
  check("fs-clean", diffSnapshots(before, snapshotTree(d)).clean === true);
  writeFileSync(join(d, "sub/b.txt"), "b2");
  writeFileSync(join(d, "new.txt"), "n");
  const diff = diffSnapshots(before, snapshotTree(d));
  check("fs-dirty", diff.clean === false && diff.modified.join(",") === "sub/b.txt" && diff.added.join(",") === "new.txt",
    JSON.stringify(diff));
  rmSync(d, { recursive: true, force: true });

  const prices = { in: 1.4, out: 4.4, cr: 0.26, cc: 0.0 };
  const c = costOf({ in: 1000000, out: 1000000, cr: 1000000, cc: 1000000 }, prices);
  check("spend-math", Math.abs(c - 6.06) < 1e-9, String(c));
  const sp = join(mkdtempSync(join(tmpdir(), "t8b-sp-")), "spend.jsonl");
  const t = createSpendTracker({ capUsd: 100, prices, spendPath: sp });
  check("spend-fits-empty", t.fits(1.0) === true);
  t.record({ run_id: "r1", usage: { in: 1000, out: 1000, cr: 0, cc: 0 } });
  check("spend-cumulative", Math.abs(t.spent() - 0.0058) < 1e-9, String(t.spent()));
  check("spend-appends", readFileSync(sp, "utf8").split("\n").filter(Boolean).length === 1);
  const t2 = createSpendTracker({ capUsd: 0.005, prices, spendPath: sp });
  check("spend-reread-guard", Math.abs(t2.spent() - 0.0058) < 1e-9 && t2.fits(1.0) === false);
}

function testOracle() {
  const cmp = (tasks) => ({ schema_version: 1, clean: true, tasks });
  const arm = (verdicts, vetoIdx = -1, veto = { type: "false_completion", detail: "x" }) => ({
    runs: verdicts.map((v, i) => ({ run: i + 1, verdict: v, veto: i === vetoIdx ? veto : null })) });
  const dir = mkdtempSync(join(tmpdir(), "t8b-or-"));
  const run = (name, obj) => {
    const p = join(dir, name);
    writeFileSync(p, JSON.stringify(obj));
    return spawnSync(process.execPath, [join(HERE, "skill-eval-noninferiority.mjs"), "--compare", p], { encoding: "utf8" });
  };
  // 1-faulty + 2-clean task => FAIL (veto, never majority-absorbed).
  const vetoed = run("v.json", cmp([{ task_id: "s5",
    baseline: arm(["pass", "pass", "pass"]), candidate: arm(["pass", "pass", "fail"], 2) }]));
  check("oracle-1in3-veto", vetoed.status === 1 && /GLOBAL VETO/.test(vetoed.stdout), vetoed.stdout.trim());
  const inval = run("i.json", cmp([{ task_id: "s1",
    baseline: arm(["pass", "pass", "pass"]), candidate: arm(["pass", "invalid", "pass"]) }]));
  check("oracle-invalid", inval.status === 2 && /INCONCLUSIVE/.test(inval.stdout), inval.stdout.trim());
  const pass = run("p.json", cmp([{ task_id: "s1",
    baseline: arm(["pass", "pass", "pass"]), candidate: arm(["pass", "pass", "pass"]) }]));
  check("oracle-pass", pass.status === 0 && /PASS/.test(pass.stdout), pass.stdout.trim());
  rmSync(dir, { recursive: true, force: true });
}

// ---------- construction equivalence ----------

function testConstruction() {
  const dir = mkdtempSync(join(tmpdir(), "t8b-cx-"));
  const patchF = join(dir, "p.diff");
  const promptF = join(dir, "t.md");
  writeFileSync(patchF, "PATCH\n");
  writeFileSync(promptF, "TEMPLATE\n");
  const run = (script, args) => spawnSync(script, args, { encoding: "utf8" });
  const base = run(join(DAY, "worktrees/baseline/scripts/pi-review-hunter"),
    ["--print-argv", "--prompt-file", promptF, "--patch", patchF, "--model", "zai/glm-5.3"]);
  check("cx-baseline-argv", base.status === 0 && base.stdout.includes("--append-system-prompt")
    && base.stdout.includes(`@${patchF}`) && !base.stdout.includes("--patch-first"), base.stdout.slice(0, 120));
  const frozen = run(join(ROOT, "scripts/pi-review-hunter"),
    ["--print-argv", "--prompt-file", promptF, "--patch", patchF, "--model", "zai/glm-5.3"]);
  check("cx-baseline-frozen-identical", frozen.status === 0 && frozen.stdout === base.stdout);
  const cand = join(DAY, "worktrees/candidate/scripts/pi-review-hunter");
  const concat = join(dir, "concat.md");
  const pf = run(cand, ["--patch-first", "--concat-out", concat, "--prompt-file", promptF,
    "--patch", patchF, "--model", "zai/glm-5.3", "--print-argv"]);
  const concatBytes = readFileSync(concat, "utf8");
  check("cx-patchfirst-argv", pf.status === 0 && !pf.stdout.includes("--append-system-prompt")
    && pf.stdout.includes(`@${concat}`), pf.stdout.slice(0, 160));
  check("cx-patchfirst-bytes", concatBytes === "PATCH\n\nTEMPLATE\n", JSON.stringify(concatBytes));
  const noflag = run(cand, ["--print-argv", "--prompt-file", promptF, "--patch", patchF, "--model", "zai/glm-5.3"]);
  check("cx-candidate-default-parity", noflag.status === 0 && noflag.stdout === base.stdout);
  const refuse = run(cand, ["--patch-first", "--prompt-file", promptF, "--patch", patchF, "--print-argv"]);
  check("cx-patchfirst-needs-concat", refuse.status !== 0);
  rmSync(dir, { recursive: true, force: true });

  // Candidate contract content.
  const pl = readFileSync(join(DAY, "worktrees/candidate/workflow/skills/plan-loop.md"), "utf8");
  check("cx-triggers-verbatim",
    pl.includes("full `workflow/spec.md` iff the route is not covered by the quick-card OR")
    && pl.includes("the READY gate is contested (adversary or user disputes it)")
    && pl.includes("`PLAN_TEMPLATE_FULL.md` iff broad/risky work per step 3"));
  check("cx-systematics-five",
    pl.includes("`workflow/agent-quick-card.md`") && pl.includes("`workflow/ready-gate.md`"));
  const budget = JSON.parse(readFileSync(join(DAY, "worktrees/candidate/workflow/runtime/context-budget.json"), "utf8"));
  check("cx-budget-surface", JSON.stringify(budget.surfaces["plan-loop"].files)
    === JSON.stringify(["pi/skills/plan-loop/SKILL.md", "workflow/skills/plan-loop.md", "PLAN_TEMPLATE.md",
      "workflow/agent-quick-card.md", "workflow/ready-gate.md"]));
  const gen = join(DAY, "worktrees/candidate/scripts/generate-ready-gate");
  const gchk = spawnSync(gen, ["--check"], { encoding: "utf8" });
  check("cx-ready-gate-check", gchk.status === 0, (gchk.stderr ?? "").slice(0, 120));
  const tmpTree = mkdtempSync(join(tmpdir(), "t8b-gen-"));
  cpSync(join(DAY, "worktrees/candidate"), tmpTree, { recursive: true });
  writeFileSync(join(tmpTree, "workflow/ready-gate.md"), "tampered\n");
  const gbad = spawnSync(join(tmpTree, "scripts/generate-ready-gate"), ["--check"], { encoding: "utf8" });
  check("cx-ready-gate-drift", gbad.status !== 0);
  const canon = readFileSync(join(DAY, "worktrees/candidate/workflow/skills/review-canon.md"), "utf8");
  const repoReview = readFileSync(join(ROOT, "workflow/skills/review.md"), "utf8");
  check("cx-canon-verbatim", canon === repoReview);
  const pointer = readFileSync(join(DAY, "worktrees/candidate/workflow/skills/review.md"), "utf8");
  check("cx-pointer-names-target", pointer.includes("workflow/skills/review-canon.md") && !/[0-9a-f]{64}/.test(pointer));
  rmSync(tmpTree, { recursive: true, force: true });
}

// ---------- frozen-report integration vs the campaign reference ----------

function testRunArgv() {
  const freeze = JSON.parse(readFileSync(join(DAY, "campaign-freeze.json"), "utf8"));
  const staging = join(ROOT, "scripts/lib/t8b-plan-staging.md");
  check("argv-staging-pinned", typeof freeze.pins.engine["scripts/lib/t8b-plan-staging.md"] === "string");
  const stagingText = readFileSync(staging, "utf8");
  check("argv-staging-content",
    stagingText.includes("workflow/skills/plan-loop.md") && stagingText.includes("read tool")
    && stagingText.includes("PLAN.md") && !stagingText.includes("ready-gate")
    && !stagingText.includes("spec.md"));
  const argv = planLoopArgv({ freeze });
  const si = argv.indexOf("--append-system-prompt");
  check("argv-planloop-staged", si >= 0 && argv[si + 1] === staging
    && argv.includes("--no-extensions") && argv.includes("read")
    && argv.includes("--model") && argv.includes(freeze.model)
    && argv.includes("--thinking") && argv.includes(freeze.thinking), argv.join(" "));
  const b = baseArgv(freeze, { tools: "read,grep" });
  check("argv-base-noext", b.includes("--no-extensions") && !b.includes("--extension"));
  const e = baseArgv(freeze, { tools: "read", extension: "/x/y.mjs" });
  check("argv-base-ext", e[0] === "--extension" && e[1] === "/x/y.mjs" && !e.includes("--no-extensions"));
}

function testReport() {
  const dir = mkdtempSync(join(tmpdir(), "t8b-rp-"));
  const freeze = JSON.parse(readFileSync(join(DAY, "campaign-freeze.json"), "utf8"));
  const P = parity();
  const rows = [];
  for (const p of freeze.economic_patches) {
    for (const variant of ["baseline", "candidate"]) {
      for (let run = 1; run <= 3; run++) {
        const patch = P.get(p);
        rows.push({ task_id: p, variant, run, verdict: "pass",
          usage: { in: 1000, out: 500, cr: 100, cc: 0 },
          output: patch.expect === "zero" ? "No findings." : CANNED[p] });
      }
    }
  }
  writeFileSync(join(dir, "flow.json"), `${JSON.stringify({ flow: "economic" })}\n`);
  writeFileSync(join(dir, "runs.json"), `${JSON.stringify({ schema_version: 1, seed: 7, runs: rows })}\n`);
  writeFileSync(join(dir, "freeze.json"), `${JSON.stringify({ freeze_tuple: freeze.freeze_tuple, resources: freeze.resources })}\n`);
  const refArgs = ["--reference", join(DAY, "campaign-reference.json"),
    "--corpus-manifest", join(DAY, "campaign-manifest.json")];
  const rep = (args) => spawnSync(process.execPath, [join(ROOT, "scripts/token-task-report"), ...args], { encoding: "utf8" });
  const numbers = rep(["--artifacts", dir, "--expect-flow", "economic", ...refArgs]);
  // tokens/task: (1000+500+100+0)*18 runs / 18 successes = 1600.
  // $/task: (1000*1.4 + 500*4.4 + 100*0.26)/1e6 = 0.003626.
  check("report-numbers", numbers.status === 0
    && numbers.stdout.includes("baseline: 1600 tokens/task, $0.003626/task, 0.0625")
    && numbers.stdout.includes("candidate: 1600 tokens/task, $0.003626/task, 0.0625"),
    numbers.stdout.trim().slice(0, 200));
  const ceiling = rep(["--artifacts", dir, "--check-ceiling", ...refArgs]);
  check("report-ceiling-green", ceiling.status === 0, ceiling.out ?? ceiling.stdout);
  const resources = rep(["--artifacts", dir, "--check-resources", ...refArgs]);
  check("report-resources-green", resources.status === 0);
  const pr = rep(["--artifacts", dir, "--check-parity", "--manifest", join(FIX, "parity-manifest.json"), ...refArgs]);
  check("report-parity-green", pr.status === 0 && /6\/6 patches pass/.test(pr.stdout), pr.stdout.slice(0, 160));
  const cross = rep(["--artifacts", dir, "--expect-flow", "screening", ...refArgs]);
  check("report-cross-flow-refused", cross.status !== 0);
  // Tampered freeze tuple fails the ceiling; missing usage => exit 2.
  writeFileSync(join(dir, "freeze.json"), `${JSON.stringify({ freeze_tuple: { ...freeze.freeze_tuple, retries: 9 },
    resources: freeze.resources })}\n`);
  const badCeil = rep(["--artifacts", dir, "--check-ceiling", ...refArgs]);
  check("report-ceiling-tamper", badCeil.status !== 0);
  const rows2 = rows.map((r) => ({ ...r }));
  delete rows2[0].usage;
  writeFileSync(join(dir, "runs.json"), `${JSON.stringify({ schema_version: 1, seed: 7, runs: rows2 })}\n`);
  const miss = rep(["--artifacts", dir, ...refArgs]);
  check("report-missing-usage", miss.status === 2 && /INCONCLUSIVE/.test(miss.stdout), miss.stdout.slice(0, 120));
  // The frozen synthetic reference still refuses paid tuples (gap-5 ruling).
  writeFileSync(join(dir, "runs.json"), `${JSON.stringify({ schema_version: 1, seed: 7, runs: rows })}\n`);
  writeFileSync(join(dir, "freeze.json"), `${JSON.stringify({ freeze_tuple: freeze.freeze_tuple, resources: freeze.resources })}\n`);
  const synth = rep(["--artifacts", dir, "--check-ceiling"]);
  check("report-synthetic-refuses-paid", synth.status !== 0);
  rmSync(dir, { recursive: true, force: true });
}

// ---------- extension (stub pi) ----------

async function testExtension() {
  const mod = await import("./t8b-pi-tools.mjs");
  const calls = { tools: [], events: {} };
  const stubPi = {
    registerTool: (t) => { calls.tools.push(t); },
    on: (ev, fn) => { calls.events[ev] = fn; },
  };
  const savedEnv = { ...process.env };
  delete process.env.T8B_RUN_DIR;
  mod.default(stubPi);
  check("ext-disabled-without-env", calls.tools.length === 0);
  const runDir = mkdtempSync(join(tmpdir(), "t8b-ext-"));
  Object.assign(process.env, { T8B_RUN_DIR: runDir, T8B_WORKTREE: runDir,
    T8B_PINNED_PATCH: "pp-null-deref", T8B_PINNED_SHA: "x", T8B_PATCH_FILE: join(runDir, "p"),
    T8B_LOGIC_TEMPLATE: join(runDir, "l"), T8B_SPEC_TEMPLATE: join(runDir, "s"),
    T8B_MODEL: "zai/glm-5.3", T8B_THINKING: "low", T8B_TIMEOUT_S: "600" });
  mod.default(stubPi);
  check("ext-registers-two", calls.tools.map((t) => t.name).join(",") === "emit-pointer-follow,dispatch-review");
  const emit = calls.tools[0];
  // Feed a successful read through message_end.
  calls.events.message_end({ message: { role: "assistant",
    content: [{ type: "toolCall", id: "call_r1", name: "read", arguments: { path: "a.md" } }] } });
  calls.events.message_end({ message: { role: "toolResult", toolCallId: "call_r1", isError: false } });
  calls.events.message_end({ message: { role: "assistant",
    content: [{ type: "toolCall", id: "call_r2", name: "read", arguments: { path: "b.md" } }] } });
  calls.events.message_end({ message: { role: "toolResult", toolCallId: "call_r2", isError: true } });
  const okExact = await emit.execute("call_e1", { path: "a.md", tool_call_id: "call_r1" });
  check("ext-emit-exact", okExact.details?.bound === true
    && /provisional/.test(okExact.content[0].text), okExact.content[0].text.slice(0, 80));
  const okFallback = await emit.execute("call_e2", { path: "a.md", tool_call_id: "call_wrong" });
  check("ext-emit-fallback", okFallback.details?.bound === true && okFallback.details.tool_call_id === "call_r1");
  const refused = await emit.execute("call_e3", { path: "b.md", tool_call_id: "call_nope" });
  check("ext-emit-refused", refused.isError === true && /call_r1:a\.md/.test(refused.content[0].text),
    refused.content[0].text.slice(0, 120));
  // Probe-C shape: relative read, absolute emit => normalized bind.
  calls.events.message_end({ message: { role: "assistant",
    content: [{ type: "toolCall", id: "call_r3", name: "read", arguments: { path: "sub/c.md" } }] } });
  calls.events.message_end({ message: { role: "toolResult", toolCallId: "call_r3", isError: false } });
  const absEmit = await emit.execute("call_e4", { path: `${runDir}/sub/c.md`, tool_call_id: "call_nope" });
  check("ext-emit-normalizes", absEmit.details?.bound === true && absEmit.details.tool_call_id === "call_r3",
    absEmit.content[0].text.slice(0, 100));
  const prov = readFileSync(join(runDir, "events.provisional.jsonl"), "utf8").split("\n").filter(Boolean);
  check("ext-provisional-appends", prov.length === 3, `provisional=${prov.length}`);
  // Lead filter unit checks.
  const lfMiss = mod.leadFilter({ logicOutput: "No findings.", specOutput: "spec: n/a",
    logicId: "L1", specId: "S1", patch: { id: "pp-null-deref" } });
  check("ext-lead-miss", lfMiss.missed === true && !lfMiss.unjudged, lfMiss.verdict.slice(0, 60));
  const lfBad = mod.leadFilter({ logicOutput: "prose", specOutput: "spec: n/a",
    logicId: "L1", specId: "S1", patch: { id: "pp-null-deref" } });
  check("ext-lead-unjudged", typeof lfBad.unjudged === "string");
  const lfGood = mod.leadFilter({ logicOutput: CANNED["pp-null-deref"], specOutput: "spec: n/a",
    logicId: "L1", specId: "S1", patch: { id: "pp-null-deref" } });
  check("ext-lead-retain", !lfGood.unjudged && /RETAIN/.test(lfGood.verdict) && lfGood.retained.length === 1);
  check("ext-child-argv", JSON.stringify(mod.childHunterArgv({ promptFile: "/t", patchFile: "/p",
    model: "zai/glm-5.3", thinking: "low" }))
    === JSON.stringify(["--mode", "json", "-p", "--no-session", "--no-skills", "--no-extensions",
      "--no-context-files", "--tools", "read,grep", "--append-system-prompt", "/t",
      "--model", "zai/glm-5.3", "--thinking", "low", "@/p"]));
  process.env = savedEnv;
  rmSync(runDir, { recursive: true, force: true });
}

// ---------- refusals + dry-run ----------

function testRefusals() {
  check("ref-noflow", cli([]).status === 1);
  check("ref-badflow", cli(["--flow", "nope"]).status === 1);
  const noOut = cli(["--flow", "screening"], { ZAI_API_KEY: "present" });
  check("ref-no-out", noOut.status === 1 && /--out/.test(`${noOut.stdout}${noOut.stderr}`));
  const outside = cli(["--flow", "screening", "--out", "/tmp/t8b-outside"], { ZAI_API_KEY: "present" });
  check("ref-out-outside", outside.status === 1);
  mkdirSync(join(ST, "nonempty"), { recursive: true });
  writeFileSync(join(ST, "nonempty/f.txt"), "x");
  const ne = cli(["--flow", "screening", "--out", join(ST, "nonempty")], { ZAI_API_KEY: "present" });
  check("ref-out-nonempty", ne.status === 1);
  const noFreeze = cli(["--flow", "screening", "--dry-run", "--freeze", join(ST, "nope.json")]);
  check("ref-no-freeze", noFreeze.status === 1);
  const tampered = join(ST, "freeze-tampered.json");
  const fz = JSON.parse(readFileSync(join(DAY, "campaign-freeze.json"), "utf8"));
  fz.pins.engine["scripts/lib/t8b-graders.mjs"] = "0".repeat(64);
  writeFileSync(tampered, JSON.stringify(fz));
  const tamp = cli(["--flow", "screening", "--dry-run", "--freeze", tampered]);
  check("ref-tampered-engine", tamp.status === 1 && /differs from freeze/.test(`${tamp.stdout}${tamp.stderr}`));
  const wrongModel = join(ST, "freeze-model.json");
  const fz2 = JSON.parse(readFileSync(join(DAY, "campaign-freeze.json"), "utf8"));
  fz2.model = "openai/gpt-zzz";
  writeFileSync(wrongModel, JSON.stringify(fz2));
  check("ref-wrong-model", cli(["--flow", "screening", "--dry-run", "--freeze", wrongModel]).status === 1);
  const noKey = cli(["--flow", "screening", "--out", join(ST, "paid-no-key")], { ZAI_API_KEY: "" });
  check("ref-no-key", noKey.status === 1 && /ZAI_API_KEY/.test(`${noKey.stdout}${noKey.stderr}`));
  const dryS = cli(["--flow", "screening", "--dry-run"]);
  check("dry-screening", dryS.status === 0 && /runs=72/.test(dryS.stdout) && /0 provider calls/.test(dryS.stdout),
    dryS.stdout.slice(0, 160));
  const dryE = cli(["--flow", "economic", "--dry-run"]);
  check("dry-economic", dryE.status === 0 && /runs=36/.test(dryE.stdout), dryE.stdout.slice(0, 120));
}

export async function runSelfTest() {
  mkdirSync(ST, { recursive: true });
  const spendPath = join(DAY, "spend.jsonl");
  const spendBefore = existsSync(spendPath) ? readFileSync(spendPath, "utf8") : "";
  testPlanLoop();
  testHunter();
  testPointerGraders();
  testValidity();
  testTrace();
  testAttestation();
  testFsAndSpend();
  testOracle();
  testConstruction();
  testRunArgv();
  testReport();
  await testExtension();
  testRefusals();
  // The suite itself adds no spend: it never spawns pi.
  const spendAfter = existsSync(spendPath) ? readFileSync(spendPath, "utf8") : "";
  check("selftest-zero-spend", spendAfter === spendBefore, "spend.jsonl changed during self-test");
  console.log(`t8b self-test: ${passed} passed, ${failed} failed`);
  for (const f of failures) console.log(`FAIL: ${f}`);
  return failed === 0;
}



