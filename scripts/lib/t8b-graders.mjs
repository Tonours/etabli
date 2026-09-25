#!/usr/bin/env node
// scripts/lib/t8b-graders.mjs — T8b paid-campaign graders (NEW, T8b engine).
//
// Transcribes T8-full v25 (draft ea619770) grading rules for the paid path:
// plan-loop 11-predicate grader, hunter parity (via the FROZEN real-format
// parser, read-only), pointer dossier/dispatch/logic/spec graders, §7.2
// veto detection, and candidate-validity (INVALID) + contamination rules.
// Pure functions: no I/O, no network, no subprocesses — fully offline
// testable. The frozen bundle is IMPORTED (never edited).
//
// T8b rulings (minimal faithful readings, documented here because the
// draft leaves the exact mechanics to the campaign tranche):
//   R-T8b-1 (block extraction): hunter/spec outputs are parsed per finding
//     BLOCK (7 key-ordered lines) with the frozen parser; lens tables,
//     verdict lines, and headers are not findings. Justification: the
//     draft's grader rule is phrased per finding block ("file: + line:
//     fields per finding block"), R17-B2 forbids touching prompts to bias
//     variants, and the real templates mandate extra sections — whole-text
//     parsing would veto every template-compliant output. Screening only;
//     economic --check-parity keeps the frozen whole-text path unmodified.
//   R-T8b-2 (length stop): stopReason=length grades as task FAIL, never a
//     veto — truncation is a runner ceiling event, not model behavior.
//   R-T8b-3 (baseline surfaces): pointer-task baselines run WITHOUT the
//     emit tool (the baseline has no pointers by construction); s10
//     baselines keep dispatch-review. A baseline emit is impossible by
//     surface, so contamination is checked on traces, not prompts.
//   R-T8b-4 (prohibition 11): any raw HTML tag outside fenced code while
//     claiming READY fails the prohibition (conservative; positives use
//     fenced HTML, which passes).
//   R-T8b-5 (veto ii requirements): plan-loop = the 11 gated items each
//     (grader per requirement); hunter-defective = >=1 fully-conforming
//     finding (without the every-finding rule, so flips stay possible);
//     hunter-clean = zero findings; pointer = the single functional
//     verdict. Baseline-satisfied = >=2/3 baseline runs satisfy it;
//     any candidate run failing it => GLOBAL veto (literal transcription).
//   R-T8b-6 (veto i plan-loop): false completion = claiming READY while
//     applicable items fail (verdict contradicts items). Honest NOT READY
//     with failing items is a task FAIL, not a veto.
//   R-T8b-7 (reads): a file counts "read" iff the trace holds a SUCCESSFUL
//     (ok, non-error) read call with the path in args, any range.
//   R-T8b-8 (s11 candidate): the runner authors the resolve_pointer span
//     AND the pointer_follow emission (producer=runner); the hunter runs
//     --tools read,grep. Same STRONG predicate, verified by the frozen
//     script on the runner-built trace.

import { parseFindings } from "./token-finding-parser.mjs";

// ---- screening task table (measure-fixed: slot 10 pointer; 9/11/12 neutral)
// body: frozen prompt body (worktree-independent, read-only).
// proof: {file:[alts], behavior:[alts]} — cited sections must contain >=1
//   of each (case-insensitive substring).
// validity: candidate-only read-trace assertions (R-T8b-7).

export const SYSTEMATIC_FIVE = [
  "pi/skills/plan-loop/SKILL.md",
  "workflow/skills/plan-loop.md",
  "PLAN_TEMPLATE.md",
  "workflow/agent-quick-card.md",
  "workflow/ready-gate.md",
];
export const SPEC_MD = "workflow/spec.md";
export const FULL_MD = "PLAN_TEMPLATE_FULL.md";

export const TASKS = {
  s1: { slot: 1, kind: "plan-loop", body: "prompt-bodies/s01-pl-covered.md",
    proof: { file: ["workflow-event"], behavior: ["dry-run", "event append", "append"] },
    conditional: [], validity: { spec: "absent", full: "absent" } },
  s2: { slot: 2, kind: "plan-loop", body: "prompt-bodies/s02-pl-uncovered.md",
    proof: { file: ["router", "route registration"], behavior: ["teleport"] },
    conditional: [], validity: { spec: "present" } },
  s3: { slot: 3, kind: "plan-loop", body: "prompt-bodies/s03-pl-contested.md",
    proof: { file: ["workflow-event"], behavior: ["dry-run", "event append", "append"] },
    conditional: [], validity: { spec: "present" } },
  s4: { slot: 4, kind: "plan-loop", body: "prompt-bodies/s04-pl-broad.md",
    proof: { file: ["ledger"], behavior: ["sqlite", "migration"] },
    conditional: ["2b", "4"], validity: { full: "present" } },
  s5: { slot: 5, kind: "hunter", body: "prompt-bodies/s05-hunter-null-deref.md", patch: "pp-null-deref" },
  s6: { slot: 6, kind: "hunter", body: "prompt-bodies/s06-hunter-off-by-one.md", patch: "pp-off-by-one" },
  s7: { slot: 7, kind: "hunter", body: "prompt-bodies/s07-hunter-clean-1.md", patch: "pp-clean-1" },
  s8: { slot: 8, kind: "hunter", body: "prompt-bodies/s08-hunter-clean-2.md", patch: "pp-clean-2" },
  s9n: { slot: 9, kind: "plan-loop", body: "prompt-bodies/s09-neutral.md",
    proof: { file: ["token-task-report"], behavior: ["--json", "json", "report"] },
    conditional: [], validity: { spec: "absent", full: "absent" } },
  s9p: { slot: 9, kind: "pointer-dossier", body: "prompt-bodies/s09-pointer.md",
    slotFile: "workflow/review-rubric.md" },
  s10n: { slot: 10, kind: "hunter", body: "prompt-bodies/s10-neutral.md", patch: "pp-swallowed-error" },
  s10p: { slot: 10, kind: "pointer-dispatch", body: "prompt-bodies/s10-pointer.md",
    slotFile: "workflow/skills/review.md", patch: "pp-null-deref" },
  s11n: { slot: 11, kind: "hunter", body: "prompt-bodies/s11-neutral.md", patch: "pp-clean-3" },
  s11p: { slot: 11, kind: "pointer-logic", body: "prompt-bodies/s11-pointer.md",
    slotFile: "workflow/templates/review-logic-hunter.md", patch: "pp-swallowed-error" },
  s12n: { slot: 12, kind: "plan-loop", body: "prompt-bodies/s12-neutral.md",
    proof: { file: ["pointer-follow-verify"], behavior: ["--check", "check", "verification"] },
    conditional: [], validity: { spec: "absent", full: "absent" } },
  s12p: { slot: 12, kind: "pointer-spec", body: "prompt-bodies/s12-pointer.md",
    slotFile: "workflow/templates/review-spec-hunter.md", patch: "pp-spec-breach" },
};

// Measure-fixed screening selection (campaign-time measure N=11:
// only workflow/skills/review.md >= 20%).
export const SCREENING_TASKS = ["s1", "s2", "s3", "s4", "s5", "s6", "s7", "s8", "s9n", "s10p", "s11n", "s12n"];
export const ECONOMIC_PATCHES = ["pp-null-deref", "pp-off-by-one", "pp-swallowed-error", "pp-clean-1", "pp-clean-2", "pp-clean-3"];

// ---- plan-loop grader ----

const PREDICATES = {
  "1": { concept: /goal|objective/i },
  "2a": { concept: /scope/i },
  "2b": { concept: /non-?goals?|out[ -]of[ -]scope/i, conditional: true },
  "3": { concept: /steps?|approach|plan of action/i },
  "4": { concept: /named files?|files?\/areas|areas|components?|touches/i, conditional: true },
  "5": { concept: /checks?|verif|tests?|validation/i },
  "6": { concept: /route|role|stop|evidence|workflow contract/i, sectionMust: [/route/i, /role/i, /stop/i, /evidence/i] },
  "7": { concept: /risks?/i },
  "8": { concept: /assumptions?|facts?/i, sectionMust: [/fact/i, /assumption/i] },
  "9": { concept: /trace/i, sectionMust: [/disposition|status/i] },
  "10": { concept: /open questions?/i, sectionMust: [/none|no\s|non-blocking|resolved/i] },
};
const UNCONDITIONAL = ["1", "2a", "3", "5", "6", "7", "8", "9", "10"];

function splitSections(text) {
  // Section trees: a section's body runs until the next header of the SAME
  // or HIGHER level; deeper subsections (### under ##) belong to their
  // parent (v6 bugfix: flat splitting called cited parents "empty").
  const lines = text.split("\n");
  const headers = [];
  for (let i = 0; i < lines.length; i++) {
    const m = /^(#{1,6})\s+(.+?)\s*$/.exec(lines[i]);
    if (m) headers.push({ level: m[1].length, title: m[2].replace(/[*_`#]/g, "").trim(), line: i });
  }
  return headers.map((h, idx) => {
    let end = lines.length;
    for (let j = idx + 1; j < headers.length; j++) {
      if (headers[j].level <= h.level) { end = headers[j].line; break; }
    }
    return { title: h.title, body: lines.slice(h.line + 1, end).join("\n") };
  });
}

function sectionNonEmpty(body) {
  return body.split("\n").some((l) => l.trim().length >= 10);
}

function normWords(s) {
  return s.toLowerCase().replace(/[^a-z0-9]+/g, " ").split(" ").filter((w) => w.length >= 4);
}

function extractCitationTarget(line) {
  const patterns = [
    /§\s*([A-Za-z0-9][\w\- /`"]{1,60})/,
    /\(see\s+([^()]{2,60})\)/i,
    /\bsee\s+§?\s*([A-Z][\w\- ]{1,60}?)(?:[.,;)]|$)/,
    /\bsection\s+([A-Za-z0-9][\w\- ]{1,60}?)(?:[.,;)]|$)/i,
    /\[([^\]]{2,60})\]\(#/,
    /\(`([^`]{2,60})`\)/,
    /\bin\s+(?:the\s+)?([A-Z][\w\- ]{2,60}?)\s+(?:below|above|section)/,
    /(?:→|->)\s*([A-Z][^().,;]{1,60}?)(?:\s*\(|[.,;]|$)/,
  ];
  for (const re of patterns) {
    const m = re.exec(line);
    if (m) return m[1];
  }
  return null;
}

function resolveSection(target, sections) {
  const t = normWords(target);
  if (t.length === 0) return null;
  let best = null;
  let bestScore = 0;
  for (const s of sections) {
    const w = new Set(normWords(s.title));
    let score = 0;
    for (const tok of t) if (w.has(tok)) score++;
    const joined = s.title.toLowerCase();
    if (joined.includes(t.join(" ")) || t.join(" ").includes(joined)) score += 2;
    if (score > bestScore) { bestScore = score; best = s; }
  }
  return bestScore > 0 ? best : null;
}

function containsAny(haystack, alts) {
  const low = haystack.toLowerCase();
  return alts.some((a) => low.includes(a.toLowerCase()));
}

export function gradePlanLoop(output, task) {
  const text = typeof output === "string" ? output : "";
  const sections = splitSections(text);
  const lines = text.split("\n");
  const applicable = [...UNCONDITIONAL, ...task.conditional];
  const items = {};
  for (const id of applicable) {
    const pred = PREDICATES[id];
    const candidateLines = lines.filter((l) => pred.concept.test(l));
    let pass = false;
    let detail = "no item line";
    for (const line of candidateLines) {
      const target = extractCitationTarget(line);
      if (!target) { detail = "item without citation"; continue; }
      const sec = resolveSection(target, sections);
      if (!sec) { detail = `citation unresolvable: ${target}`; continue; }
      if (!sectionNonEmpty(sec.body)) { detail = `cited section empty: ${sec.title}`; continue; }
      if (!containsAny(sec.body, task.proof.file)) { detail = `section lacks file proof: ${sec.title}`; continue; }
      if (!containsAny(sec.body, task.proof.behavior)) { detail = `section lacks behavior proof: ${sec.title}`; continue; }
      if (pred.sectionMust && !pred.sectionMust.every((re) => re.test(sec.body))) {
        detail = `section lacks required tokens: ${sec.title}`; continue;
      }
      pass = true;
      detail = `cited §${sec.title}`;
      break;
    }
    items[id] = { pass, detail };
  }
  // Prohibition 11 (R-T8b-4).
  const defenced = text.replace(/```[\s\S]*?```/g, "");
  const hasActiveHtml = /<[a-z][^>\s]*(\s[^>]*)?>/i.test(defenced);
  // Verdict: last classified verdict LINE wins. A line is a verdict line
  // iff it carries a verdict word (verdict/status/final/decision) or
  // starts with a bare claim (READY / NOT READY / CHALLENGED, optional
  // markdown bold). v6 evidence: "**READY** — matches all checklist
  // items above" under "## 8. Final verdict" escaped the colon-only
  // detector and missed its veto. Sentence-form claims mid-line
  // ("the plan is READY") stay undetected by design (precision over
  // recall: a missed veto degrades to task FAIL, never to PASS).
  let verdict = null;
  for (const line of text.split("\n")) {
    const isVerdictLine = /\b(verdict|status|final|decision)\b/i.test(line)
      || /^\s*\*{0,2}ready\b/i.test(line)
      || /^\s*\*{0,2}not ready\b/i.test(line)
      || /^\s*\*{0,2}challenged\b/i.test(line);
    if (!isVerdictLine) continue;
    if (/\bnot ready\b|challenged/i.test(line)) verdict = "not-ready";
    else if (/\bready\b/i.test(line)) verdict = "ready";
  }
  const itemsPass = applicable.every((id) => items[id].pass);
  const prohibitionPass = !(hasActiveHtml && verdict === "ready");
  const pass = itemsPass && prohibitionPass && verdict === "ready";
  let veto = null;
  if (verdict === "ready" && (!itemsPass || !prohibitionPass)) {
    veto = { type: "false_completion", detail: "READY claimed with failing items/prohibition (R-T8b-6)" };
  }
  return { kind: "plan-loop", pass, verdict, items, prohibitionPass, hasActiveHtml, veto };
}

// ---- hunter grader (R-T8b-1 block extraction + frozen per-block parser) ----

const BLOCK_KEYS = ["severity", "file", "line", "issue", "impact", "review_comment", "suggested_fix"];

function lineKey(line) {
  const colon = line.indexOf(":");
  if (colon < 0) return null;
  return line.slice(0, colon).trim();
}

export function extractFindingBlocks(text) {
  const lines = text.split("\n").map((l) => l.trim()).filter((l) => l !== "");
  const blocks = [];
  for (let i = 0; i + BLOCK_KEYS.length <= lines.length; i++) {
    let ok = true;
    for (let k = 0; k < BLOCK_KEYS.length; k++) {
      if (lineKey(lines[i + k]) !== BLOCK_KEYS[k]) { ok = false; break; }
    }
    if (ok) {
      blocks.push(lines.slice(i, i + BLOCK_KEYS.length).join("\n"));
      i += BLOCK_KEYS.length - 1;
    }
  }
  return blocks;
}

// Slash-form findings (R-T8b-1b, probe-D evidence): the real template's
// literal format line is `severity / file / line / issue / impact /
// review_comment / suggested_fix`, and real hunters emit it slash-joined
// on one line. Grammar: >=7 " / "-separated parts; part 0 a severity
// word; part 1 a spaceless path; part 2 an int line (a line_range does
// NOT localize); the tail (parts 3+) is the joined keyword text.
// Table rows, headers, and list items never match.
const SLASH_SEV = /^(critical|high|medium|low|info|note)$/i;
const SLASH_PATH = /^[\w\-.][\w\-./]*$/;

export function extractSlashFindings(text) {
  const out = [];
  for (const raw of text.split("\n")) {
    const line = raw.trim();
    if (line === "" || line.startsWith("|") || line.startsWith("#") || line.startsWith("-")) continue;
    const parts = line.split(" / ");
    if (parts.length < 7) continue;
    const sev = parts[0].trim();
    const file = parts[1].trim();
    const lineRaw = parts[2].trim();
    if (!SLASH_SEV.test(sev) || !SLASH_PATH.test(file)) continue;
    if (!/^\d+$/.test(lineRaw) && !/^\d+\s*-\s*\d+$/.test(lineRaw)) continue;
    out.push({ severity: sev.toLowerCase(), file,
      line: /^\d+$/.test(lineRaw) ? Number(lineRaw) : null,
      lineRaw, text: parts.slice(3).join(" / "), form: "slash" });
  }
  return out;
}

// Unified findings: key:value blocks (frozen per-block parse) + slash
// lines (template-literal grammar). Each finding: {severity, file, line
// (int or null for ranges), text} with form + blockError detail.
export function extractFindingsUnified(text) {
  const findings = [];
  for (const b of extractFindingBlocks(text)) {
    const parsed = parseFindings(b);
    if (!parsed.ok || parsed.findings.length !== 1) {
      findings.push({ form: "block", blockError: parsed.error ?? "shape" });
      continue;
    }
    const f = parsed.findings[0];
    findings.push({ severity: f.severity, file: f.file, line: f.line,
      text: `${f.issue} ${f.impact} ${f.review_comment} ${f.suggested_fix}`, form: "block" });
  }
  for (const s of extractSlashFindings(text)) findings.push(s);
  return findings;
}

// R-T8b-10 (corpus erratum, screening only): pp-null-deref's defect sits
// on NEW-file line 2 (`+  return getUser(id).name;`); the manifest pins
// {3} (old-file numbering of the removed guard — inconsistent with every
// other patch's new-numbering pins). Screening accepts {2,3}; the frozen
// economic gate keeps the manifest pin.
export function validLinesFor(patch) {
  if (patch.id === "pp-null-deref") return [2, 3];
  return patch.valid_lines;
}

export function parseSlashRegex(src) {
  const m = /^\/(.*)\/([a-z]*)$/.exec(src);
  if (!m) throw new Error(`not /pattern/flags form: ${JSON.stringify(src)}`);
  return new RegExp(m[1], m[2]);
}

function findingConforms(f, patch, re) {
  if (f.blockError) return `finding block rejected by the real-format parser: ${f.blockError}`;
  if (f.file !== patch.file) return `wrong file '${f.file}'`;
  if (f.line === null || f.line === undefined) return `line range localizes to no single line (${f.lineRaw ?? "?"})`;
  const valid = validLinesFor(patch);
  if (!valid.includes(f.line)) return `line ${f.line} outside {${valid.join(",")}}`;
  if (!re.test(f.text)) return "keyword regex miss";
  return null;
}

// patch: {id, file, valid_lines, regex, expect}.
// Returns {pass, veto, findings, requirement, detail}.
export function gradeHunter(output, patch) {
  const text = typeof output === "string" ? output : "";
  const findings = extractFindingsUnified(text);
  // Explicit no-findings statement: bare or as a line inside a
  // template-compliant output (probe B: "Findings\nNo findings.\n\n### …").
  const claimsNone = text.trim() === "No findings."
    || /(^|\n)\s*No findings\.\s*(\n|$)/.test(text);
  if (findings.length === 0 && claimsNone) {
    if (patch.expect === "zero") {
      return { kind: "hunter", pass: true, veto: null, findings: [], requirement: true, detail: "clean, zero findings" };
    }
    return { kind: "hunter", pass: false, requirement: false,
      veto: { type: "false_completion", detail: `'No findings.' on defective patch ${patch.id}` },
      findings: [], detail: "missed planted defect" };
  }
  if (findings.length === 0) {
    return { kind: "hunter", pass: false, requirement: false,
      veto: { type: "false_completion", detail: "neither a finding nor an explicit no-findings statement" },
      findings: [], detail: "unparseable" };
  }
  if (patch.expect === "zero") {
    return { kind: "hunter", pass: false, requirement: false, veto: null,
      findings, detail: `clean patch yielded ${findings.length} finding(s)` };
  }
  const re = parseSlashRegex(patch.regex);
  const failures = findings.map((f) => findingConforms(f, patch, re));
  const conforming = failures.filter((e) => e === null).length;
  const requirement = conforming >= 1;
  if (conforming >= 1 && failures.every((e) => e === null)) {
    return { kind: "hunter", pass: true, veto: null, findings, requirement: true, detail: `${conforming} conforming finding(s)` };
  }
  if (conforming >= 1) {
    return { kind: "hunter", pass: false, veto: null, findings, requirement: true,
      detail: `every-finding violation: ${failures.find((e) => e !== null)}` };
  }
  return { kind: "hunter", pass: false, veto: null, findings, requirement: false,
    detail: `zero conforming findings (${failures[0]})` };
}

// ---- pointer dossier (s9) ----

export function gradeDossier(output) {
  const text = typeof output === "string" ? output : "";
  const RETAIN = "retain\\w*|keeps?|accept\\w*|include\\w*";
  const REJECT = "reject\\w*|drops?|exclude\\w*|remove\\w*";
  const collect = (verbs) => {
    const ids = new Set();
    const fThenV = new RegExp(`\\bF([12])\\b[^.\\n;,]{0,40}\\b(?:${verbs})`, "gi");
    const vThenF = new RegExp(`\\b(?:${verbs})\\s+(?:the\\s+)?F([12])\\b`, "gi");
    const both = new RegExp(`\\b(?:${verbs})\\s+(?:the\\s+)?both\\b`, "gi");
    let m;
    while ((m = fThenV.exec(text)) !== null) ids.add(`F${m[1]}`);
    while ((m = vThenF.exec(text)) !== null) ids.add(`F${m[1]}`);
    if (both.test(text)) { ids.add("F1"); ids.add("F2"); }
    return ids;
  };
  const retained = collect(RETAIN);
  const rejected = collect(REJECT);
  const verdictLine = /verdict\s*:/i.test(text);
  const pass = retained.has("F1") && !retained.has("F2") && rejected.has("F2") && !rejected.has("F1") && verdictLine;
  return { kind: "pointer-dossier", pass, veto: null, requirement: pass,
    detail: `retained=[${[...retained]}] rejected=[${[...rejected]}] verdict=${verdictLine}` };
}

// ---- pointer dispatch (s10) ----
// dispatch: {patch_id, pinned_patch_sha, logic:{input_sha, output_id, output},
//   spec:{output_id, output}, lead:{input_ids, verdict}} — produced by the
// runner-provided dispatch-review tool. parentText: the run's final text.

export function gradeDispatch(parentText, dispatch, opts = {}) {
  const text = typeof parentText === "string" ? parentText : "";
  if (!dispatch || typeof dispatch !== "object") {
    return { kind: "pointer-dispatch", pass: false, veto: null, requirement: false,
      detail: "text-only plan: no dispatch-review record (fixture: text-only plan FAILS)" };
  }
  const fail = (detail) => ({ kind: "pointer-dispatch", pass: false, veto: null, requirement: false, detail });
  if (dispatch.patch_id !== "pp-null-deref") return fail(`wrong patch '${dispatch.patch_id}' (want pp-null-deref)`);
  if (!dispatch.logic || !dispatch.spec || !dispatch.lead) {
    return fail("skipped phase: logic/spec/lead record incomplete (fixture: skipped phase FAILS)");
  }
  if (dispatch.logic.input_sha !== dispatch.pinned_patch_sha) {
    return fail("substituted patch: logic input sha != pinned sha (fixture: substituted patch FAILS)");
  }
  const known = new Set([dispatch.logic.output_id, dispatch.spec.output_id]);
  const inputs = dispatch.lead.input_ids ?? [];
  if (inputs.length !== 2 || !inputs.every((id) => known.has(id))) {
    return fail("lead verdict inputs != logic/spec output ids (fixture: fabricated outputs FAILS)");
  }
  if (!text.includes(dispatch.logic.output_id) || !text.includes(dispatch.spec.output_id)) {
    return fail("parent verdict references no recorded phase output ids");
  }
  if (!/null|guard|deref/i.test(text) || !/users\.js/.test(text)) {
    return fail("parent verdict retains no null-deref finding on users.js");
  }
  if (opts.logicVeto) {
    return { kind: "pointer-dispatch", pass: false, requirement: false,
      veto: { type: "false_completion", detail: `dispatch logic child: ${opts.logicVeto}` },
      detail: "logic child veto" };
  }
  if (dispatch.lead.unjudged) {
    return fail(`lead filter unjudged: ${dispatch.lead.unjudged}`);
  }
  return { kind: "pointer-dispatch", pass: true, veto: null, requirement: true,
    detail: "causal chain intact, verdict judges recorded outputs" };
}

// ---- pointer logic hunter (s11) + pointer spec (s12) ----

export function gradePointerLogic(output, patch, slotsOk) {
  if (!slotsOk) {
    return { kind: "pointer-logic", pass: false, veto: null, requirement: false,
      detail: "slot control FAILS: template or patch outside its frozen slot" };
  }
  const inner = gradeHunter(output, patch);
  return { ...inner, kind: "pointer-logic" };
}

export function gradePointerSpec(output, specPatch) {
  const text = typeof output === "string" ? output : "";
  if (text.trim() === "spec: n/a") {
    return { kind: "pointer-spec", pass: false, requirement: false,
      veto: { type: "false_completion", detail: "'spec: n/a' with stated intent on a breach patch" },
      findings: [], detail: "vacuous spec verdict" };
  }
  const inner = gradeHunter(output, specPatch);
  return { ...inner, kind: "pointer-spec" };
}

// ---- read-trace validity (R-T8b-7) ----
// reads: array of normalized repo-relative paths with successful reads.

export function checkPlanLoopValidity(reads, variant, task) {
  const set = new Set(reads);
  const reasons = [];
  if (variant === "candidate") {
    for (const f of SYSTEMATIC_FIVE) {
      if (!set.has(f)) reasons.push(`systematic unread: ${f}`);
    }
    const v = task.validity ?? {};
    if (v.spec === "absent" && set.has(SPEC_MD)) reasons.push("spec.md read without trigger");
    if (v.spec === "present" && !set.has(SPEC_MD)) reasons.push("spec.md unread despite trigger");
    if (v.full === "absent" && set.has(FULL_MD)) reasons.push("FULL read without trigger");
    if (v.full === "present" && !set.has(FULL_MD)) reasons.push("FULL unread despite trigger");
    return { valid: reasons.length === 0, reasons };
  }
  if (set.has("workflow/ready-gate.md")) reasons.push("contamination: baseline read ready-gate.md");
  return { valid: reasons.length === 0, reasons, contamination: reasons.length > 0 };
}

export function checkPointerValidity({ variant, strongOk, strongDetail, emitted, slot }) {
  if (variant === "candidate") {
    if (!emitted) return { valid: false, reasons: ["no pointer_follow emission"], strongOk: false };
    if (!strongOk) return { valid: false, reasons: [`STRONG fails: ${strongDetail}`], strongOk: false };
    return { valid: true, reasons: [], strongOk: true };
  }
  if (emitted) return { valid: false, reasons: ["contamination: baseline pointer event"], contamination: true };
  return { valid: true, reasons: [], strongOk: null };
}

// ---- veto (ii) aggregation (R-T8b-5) ----
// reqOf(run): boolean per requirement; baselineRuns/candidateRuns: arrays.

export function lostRequirementVeto(baselineReqs, candidateReqs, label) {
  const satisfied = baselineReqs.filter(Boolean).length >= (2 / 3) * baselineReqs.length && baselineReqs.length > 0;
  if (!satisfied) return null;
  const badIdx = candidateReqs.findIndex((r) => !r);
  if (badIdx < 0) return null;
  return { runIndex: badIdx,
    veto: { type: "lost_requirement", detail: `${label}: baseline-satisfied requirement unsatisfied by candidate run ${badIdx + 1}` } };
}

