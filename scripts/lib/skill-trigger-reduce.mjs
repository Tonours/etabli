#!/usr/bin/env node
/**
 * Majority reduction: raw run files -> skill-eval result.json.
 * Usage: skill-trigger-reduce --raw <dir> --corpus <json> --manifest <json>
 *        --evaluator-root <dir> --out <result.json>
 * Per-task passed <=> >=2/3 runs pass (majority, uniform). Fills the
 * manifest linkage (manifest_sha256, evaluator pins, artifact_fingerprint)
 * so the output feeds `skill-eval compare` directly.
 */
import { createHash } from "node:crypto";
import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { fingerprintArtifact } from "./skill-eval.mjs";
import {
  fingerprintEvaluatorBundle,
  fingerprintEvaluatorFile,
  hashManifestBytes,
} from "./evaluator-bundle.mjs";
import { normalizeResponse, decideResponse } from "./skill-trigger-normalize.mjs";

const args = process.argv.slice(2);
function flag(name) {
  const i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) {
    console.error(`usage: skill-trigger-reduce --raw <dir> --corpus <json> --manifest <json> --evaluator-root <dir> --out <result.json>`);
    process.exit(2);
  }
  return args[i + 1];
}
const rawDir = flag("--raw");
const corpusPath = flag("--corpus");
const manifestPath = flag("--manifest");
const evaluatorRoot = flag("--evaluator-root");
const outPath = flag("--out");

function tamper(file, what) {
  console.error(`skill-trigger-reduce: ${file}: ${what} (raw runs must be runner-written, never hand-edited)`);
  process.exit(2);
}

const manifestBytes = readFileSync(manifestPath);
const manifest = JSON.parse(manifestBytes.toString("utf8"));
const corpus = JSON.parse(readFileSync(corpusPath, "utf8"));
const expectedById = new Map(corpus.tasks.map((t) => [t.id, t.expected]));

let meta = null;
try {
  meta = JSON.parse(readFileSync(join(rawDir, "_meta.json"), "utf8"));
} catch {
  tamper("_meta.json", "missing or unparseable run metadata");
}
// Single run-contract boundary: the directory must hold exactly the
// run1..runN files _meta promises (continuity included — no gaps, no
// extras); the smoke pins _meta's absolute model/temperature/runs values.
const runCount = meta.runs;
if (!Number.isInteger(runCount) || runCount < 2) tamper("_meta.json", "runs must be an integer >= 2");
const runFiles = [];
for (let n = 1; n <= runCount; n += 1) runFiles.push(`run${n}.json`);
for (const file of runFiles) {
  try {
    readFileSync(join(rawDir, file));
  } catch {
    tamper(file, "promised by _meta but missing");
  }
}
const extraRuns = readdirSync(rawDir).filter((f) => /^run\d+\.json$/.test(f) && !runFiles.includes(f));
if (extraRuns.length > 0) tamper(extraRuns[0], "run file outside the _meta run set");

// One validated pass per run: envelope, record completeness, and verdict
// recomputation from response_raw + the CORPUS expected value (stored
// response_norm/passed booleans are never trusted).
function validateRun(file, runNumber) {
  const run = JSON.parse(readFileSync(join(rawDir, file), "utf8"));
  if (run.run !== runNumber) tamper(file, `envelope run ${run.run} disagrees with filename`);
  if (run.model !== meta.model) tamper(file, "envelope model disagrees with _meta");
  if (run.temperature !== meta.temperature) tamper(file, "envelope temperature disagrees with _meta");
  if (!Array.isArray(run.records)) tamper(file, "records is not an array");
  const verdicts = new Map();
  for (const r of run.records) {
    if (typeof r.task_id !== "string") tamper(file, "task_id is not a string");
    if (typeof r.expected !== "string") tamper(file, `${r.task_id}: stored expected is not a string`);
    if (typeof r.response_raw !== "string") tamper(file, `${r.task_id}: response_raw is not a string`);
    if (typeof r.response_norm !== "string") tamper(file, `${r.task_id}: stored response_norm is not a string`);
    if (typeof r.passed !== "boolean") tamper(file, `${r.task_id}: stored passed is not a boolean`);
    if (!expectedById.has(r.task_id)) tamper(file, `unknown task_id ${r.task_id}`);
    if (verdicts.has(r.task_id)) tamper(file, `duplicate task_id ${r.task_id}`);
    const corpusExpected = expectedById.get(r.task_id);
    if (r.expected !== corpusExpected) tamper(file, `${r.task_id}: stored expected disagrees with corpus`);
    if (r.response_norm !== normalizeResponse(r.response_raw)) {
      tamper(file, `${r.task_id}: stored response_norm disagrees with recompute`);
    }
    const passed = decideResponse(r.response_raw, corpusExpected);
    if (r.passed !== passed) tamper(file, `${r.task_id}: stored passed disagrees with recompute`);
    verdicts.set(r.task_id, passed);
  }
  for (const id of expectedById.keys()) {
    if (!verdicts.has(id)) tamper(file, `missing task_id ${id}`);
  }
  return verdicts;
}
const recomputed = runFiles.map((file, i) => validateRun(file, i + 1));
// Majority: strictly more than half (for 3 runs: >=2 pass).
const fixed = [...expectedById.keys()].map((id) => {
  const passes = recomputed.filter((m) => m.get(id) === true).length;
  return { task_id: id, passed: passes * 2 > runFiles.length };
});
const result = {
  schema_version: manifest.schema_version,
  manifest_id: manifest.manifest_id,
  manifest_sha256: hashManifestBytes(manifestBytes),
  evaluator_sha256: fingerprintEvaluatorFile(evaluatorRoot, manifest.evaluator.path),
  evaluator_bundle_sha256: fingerprintEvaluatorBundle(evaluatorRoot, manifest.evaluator.bundle.paths),
  artifact_fingerprint: fingerprintArtifact(rawDir),
  outcomes: fixed,
};
writeFileSync(outPath, `${JSON.stringify(result, null, 2)}\n`);
const passed = fixed.filter((o) => o.passed).length;
console.log(`skill-trigger-reduce: ${passed}/${fixed.length} passed -> ${outPath}`);
