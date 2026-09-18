#!/usr/bin/env node

import { createHash } from "node:crypto"
import { readFileSync, readdirSync } from "node:fs"
import { relative, resolve, sep } from "node:path"
import { fileURLToPath } from "node:url"
import { fingerprintEvaluatorBundle, fingerprintEvaluatorFile, hashManifestBytes, isSha256 } from "./evaluator-bundle.mjs"

const SPLITS = ["held_in", "held_out", "safety"]
const OBJECTIVE_RULES = {
  quality: { metrics: ["held_in_passed"], direction: "increase" },
  efficiency: { metrics: ["total_tokens", "elapsed_ms"], direction: "decrease" },
  reliability: { metrics: ["success_rate"], direction: "increase" },
}

function usage(exitCode = 0) {
  const output = exitCode === 0 ? process.stdout : process.stderr
  output.write("Usage:\n")
  output.write("  skill-eval fingerprint <skill-directory>\n")
  output.write("  skill-eval compare --manifest <path> --baseline <path> --candidate <path> \\\n")
  output.write("    --baseline-artifact <directory> --candidate-artifact <directory> [--json]\n")
  process.exit(exitCode)
}

function readJson(path, label) {
  try {
    return JSON.parse(readFileSync(path, "utf8"))
  } catch (error) {
    throw new Error(`${label} is not valid JSON: ${error.message}`)
  }
}

function walkArtifact(root) {
  const resolvedRoot = resolve(root)
  const stack = [resolvedRoot]
  const files = []
  while (stack.length > 0) {
    const current = stack.pop()
    const entries = readdirSync(current, { withFileTypes: true })
      .sort((a, b) => a.name.localeCompare(b.name))
    for (const entry of entries) {
      if (entry.name === ".DS_Store") continue
      const path = resolve(current, entry.name)
      const rel = relative(resolvedRoot, path)
      if (rel.startsWith(`..${sep}`) || rel === ".." || rel.startsWith(sep)) {
        throw new Error("artifact traversal is not allowed")
      }
      // withFileTypes dirents already carry the lstat classification:
      // avoids one lstat syscall per artifact entry.
      if (entry.isSymbolicLink()) throw new Error(`artifact symlink is not allowed: ${rel}`)
      if (entry.isDirectory()) stack.push(path)
      else if (entry.isFile()) files.push({ path, rel })
    }
  }
  return files.sort((a, b) => a.rel.localeCompare(b.rel))
}

export function fingerprintArtifact(root) {
  const digest = createHash("sha256")
  const files = walkArtifact(root)
  if (files.length === 0) throw new Error("artifact directory has no files")
  for (const file of files) {
    digest.update(file.rel)
    digest.update("\0")
    digest.update(readFileSync(file.path))
    digest.update("\0")
  }
  return digest.digest("hex")
}

function validateManifest(manifest) {
  if (![1, 2].includes(manifest?.schema_version)) throw new Error("manifest schema_version must be 1 or 2")
  if (typeof manifest.manifest_id !== "string" || manifest.manifest_id.length === 0) {
    throw new Error("manifest_id is required")
  }
  if (!["frozen_public", "external_isolated"].includes(manifest.visibility)) {
    throw new Error("manifest visibility must be frozen_public or external_isolated")
  }
  if (!isSha256(manifest?.evaluator?.sha256)) {
    throw new Error("manifest evaluator.sha256 must be a lowercase SHA-256")
  }
  if (manifest.schema_version === 2) {
    if (manifest.strict !== true) throw new Error("schema 2 manifests must declare strict=true")
    const bundle = manifest.evaluator?.bundle
    if (!bundle || bundle.root !== "." || !Array.isArray(bundle.paths) || !isSha256(bundle.sha256)) {
      throw new Error("strict manifests must declare evaluator.bundle root, paths, and sha256")
    }
    const evaluatorPath = manifest.evaluator?.path?.trim().split("\\").join("/")
    const matchingPaths = bundle.paths.filter((path) =>
      typeof path === "string" && path.trim().split("\\").join("/") === evaluatorPath)
    if (!evaluatorPath || matchingPaths.length !== 1) {
      throw new Error("strict manifest evaluator.path must appear exactly once in evaluator.bundle.paths")
    }
    const objective = manifest.objective
    const rule = OBJECTIVE_RULES[objective?.kind]
    if (!rule || !rule.metrics.includes(objective.metric) || objective.direction !== rule.direction) {
      throw new Error("strict manifests must declare a supported objective kind, metric, and direction")
    }
    if (typeof objective.minimum_delta !== "number" || !Number.isFinite(objective.minimum_delta) || objective.minimum_delta <= 0) {
      throw new Error("strict manifest objective.minimum_delta must be a positive number")
    }
    if (objective.kind !== "quality" && (typeof objective.measurement_population !== "string" || objective.measurement_population.length === 0)) {
      throw new Error("efficiency and reliability objectives must freeze measurement_population")
    }
  }
  if (!Array.isArray(manifest.tasks) || manifest.tasks.length === 0) {
    throw new Error("manifest tasks must be a non-empty array")
  }
  const ids = new Set()
  const splitCounts = Object.fromEntries(SPLITS.map((split) => [split, 0]))
  for (const task of manifest.tasks) {
    if (typeof task?.id !== "string" || task.id.length === 0) throw new Error("every task needs an id")
    if (ids.has(task.id)) throw new Error(`duplicate manifest task: ${task.id}`)
    if (!SPLITS.includes(task.split)) throw new Error(`invalid split for task: ${task.id}`)
    ids.add(task.id)
    splitCounts[task.split] += 1
  }
  for (const split of SPLITS) {
    if (splitCounts[split] === 0) throw new Error(`manifest split is empty: ${split}`)
  }
  return { ids, splitCounts }
}

function objectiveFor(manifest) {
  return manifest.schema_version === 2
    ? manifest.objective
    : { kind: "quality", metric: "held_in_passed", direction: "increase", minimum_delta: 1 }
}

function validateMeasurement(result, label, objective) {
  if (objective.kind === "quality") return null
  const measurement = result.measurement
  if (!measurement || typeof measurement.population !== "string" || measurement.population.length === 0) {
    throw new Error(`${label} measurement population is required for ${objective.kind}`)
  }
  if (measurement.population !== objective.measurement_population) {
    throw new Error(`${label} measurement population drift`)
  }
  if (measurement.metric !== objective.metric) throw new Error(`${label} measurement metric drift`)
  if (typeof measurement.value !== "number" || !Number.isFinite(measurement.value) || measurement.value < 0) {
    throw new Error(`${label} measurement value must be a non-negative number`)
  }
  if (!Number.isInteger(measurement.sample_count) || measurement.sample_count < 2) {
    throw new Error(`${label} measurement sample_count must be an integer >= 2`)
  }
  if (objective.kind === "reliability" && measurement.value > 1) {
    throw new Error(`${label} reliability success_rate must be between 0 and 1`)
  }
  return measurement
}

function validateResult(result, label, manifest, manifestSha, evaluatorBundleSha) {
  if (![1, 2].includes(result?.schema_version)) throw new Error(`${label} schema_version must be 1 or 2`)
  if (result.schema_version !== manifest.schema_version) {
    throw new Error(`${label} schema_version must match the manifest schema_version`)
  }
  if (result.manifest_id !== manifest.manifest_id) throw new Error(`${label} manifest_id drift`)
  if (result.manifest_sha256 !== manifestSha) throw new Error(`${label} manifest_sha256 drift`)
  if (result.evaluator_sha256 !== manifest.evaluator.sha256) throw new Error(`${label} evaluator_sha256 drift`)
  if (manifest.schema_version === 2 && result.evaluator_bundle_sha256 !== evaluatorBundleSha) {
    throw new Error(`${label} evaluator_bundle_sha256 drift`)
  }
  if (!isSha256(result.artifact_fingerprint)) throw new Error(`${label} artifact_fingerprint is invalid`)
  if (!Array.isArray(result.outcomes)) throw new Error(`${label} outcomes must be an array`)

  const outcomes = new Map()
  for (const outcome of result.outcomes) {
    if (typeof outcome?.task_id !== "string") throw new Error(`${label} outcome task_id is invalid`)
    if (outcomes.has(outcome.task_id)) throw new Error(`${label} duplicate outcome: ${outcome.task_id}`)
    if (typeof outcome.passed !== "boolean") throw new Error(`${label} outcome must use boolean passed`)
    outcomes.set(outcome.task_id, outcome.passed)
  }

  const expected = new Set(manifest.tasks.map((task) => task.id))
  const actual = new Set(outcomes.keys())
  const missing = [...expected].filter((id) => !actual.has(id))
  const extra = [...actual].filter((id) => !expected.has(id))
  if (missing.length > 0 || extra.length > 0) {
    throw new Error(`${label} population mismatch: missing=${missing.join(",") || "none"} extra=${extra.join(",") || "none"}`)
  }
  return outcomes
}

function splitSummary(manifest, outcomes) {
  return Object.fromEntries(SPLITS.map((split) => {
    const tasks = manifest.tasks.filter((task) => task.split === split)
    return [split, {
      passed: tasks.filter((task) => outcomes.get(task.id) === true).length,
      total: tasks.length,
      outcomes: tasks.map((task) => ({ task_id: task.id, passed: outcomes.get(task.id) })),
    }]
  }))
}

function regressions(manifest, baseline, candidate, split) {
  return manifest.tasks
    .filter((task) => task.split === split)
    .filter((task) => baseline.get(task.id) === true && candidate.get(task.id) === false)
    .map((task) => task.id)
}

export function compareDocuments(manifest, manifestSha, baseline, candidate, evaluatorBundleSha = null, evaluatorFileSha = null) {
  validateManifest(manifest)
  if (manifest.schema_version === 2 && !isSha256(evaluatorBundleSha)) {
    throw new Error("strict comparison requires a computed evaluator bundle fingerprint")
  }
  if (manifest.schema_version === 2 && evaluatorFileSha !== manifest.evaluator.sha256) {
    throw new Error("strict comparison evaluator.sha256 does not match evaluator.path bytes")
  }
  const baselineOutcomes = validateResult(baseline, "baseline", manifest, manifestSha, evaluatorBundleSha)
  const candidateOutcomes = validateResult(candidate, "candidate", manifest, manifestSha, evaluatorBundleSha)
  const objective = objectiveFor(manifest)
  const baselineMeasurement = validateMeasurement(baseline, "baseline", objective)
  const candidateMeasurement = validateMeasurement(candidate, "candidate", objective)
  if (baselineMeasurement && (
    baselineMeasurement.population !== candidateMeasurement.population ||
    baselineMeasurement.metric !== candidateMeasurement.metric ||
    baselineMeasurement.sample_count !== candidateMeasurement.sample_count
  )) {
    throw new Error("baseline and candidate measurement populations must match exactly")
  }
  const baselineSummary = splitSummary(manifest, baselineOutcomes)
  const candidateSummary = splitSummary(manifest, candidateOutcomes)
  const taskRegressions = Object.fromEntries(["held_in", "held_out", "safety"].map((split) => [
    split,
    regressions(manifest, baselineOutcomes, candidateOutcomes, split),
  ]))
  const reasons = []

  if (baseline.artifact_fingerprint === candidate.artifact_fingerprint) {
    reasons.push("candidate_fingerprint_unchanged")
  }
  if (objective.kind === "quality") {
    if (candidateSummary.held_in.passed - baselineSummary.held_in.passed < objective.minimum_delta) {
      reasons.push("objective_not_met")
    }
  } else if (candidateSummary.held_in.passed < baselineSummary.held_in.passed) {
    reasons.push("held_in_regression")
  }
  if (objective.kind === "efficiency" && baselineMeasurement.value - candidateMeasurement.value < objective.minimum_delta) {
    reasons.push("objective_not_met")
  }
  if (objective.kind === "reliability" && candidateMeasurement.value - baselineMeasurement.value < objective.minimum_delta) {
    reasons.push("objective_not_met")
  }
  if (candidateSummary.held_out.passed < baselineSummary.held_out.passed) {
    reasons.push("held_out_regression")
  }
  if (candidateSummary.safety.passed < baselineSummary.safety.passed) {
    reasons.push("safety_regression")
  }
  for (const split of ["held_in", "held_out", "safety"]) {
    if (taskRegressions[split].length > 0) reasons.push(`${split}_case_regression`)
  }
  if (baselineSummary.safety.passed < baselineSummary.safety.total) {
    reasons.push("baseline_safety_incomplete")
  }

  return {
    schema_version: manifest.schema_version,
    status: "comparable",
    verdict: reasons.length === 0 ? "accepted" : "rejected",
    manifest_id: manifest.manifest_id,
    manifest_sha256: manifestSha,
    visibility: manifest.visibility,
    evaluator_sha256: manifest.evaluator.sha256,
    evaluator_bundle_sha256: evaluatorBundleSha,
    objective,
    baseline: {
      artifact_fingerprint: baseline.artifact_fingerprint,
      splits: baselineSummary,
      measurement: baselineMeasurement,
    },
    candidate: {
      artifact_fingerprint: candidate.artifact_fingerprint,
      splits: candidateSummary,
      measurement: candidateMeasurement,
    },
    regressions: taskRegressions,
    reasons,
    isolation_claim: manifest.visibility === "external_isolated"
      ? "external_isolated"
      : "frozen_public_not_isolated",
  }
}

function parseCompareArgs(argv) {
  const options = {}
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index]
    if (arg === "--json") continue
    if (!["--manifest", "--baseline", "--candidate", "--baseline-artifact", "--candidate-artifact", "--evaluator-root"].includes(arg)) {
      throw new Error(`unknown compare option: ${arg}`)
    }
    index += 1
    if (index >= argv.length) throw new Error(`${arg} requires a value`)
    options[arg.slice(2)] = resolve(argv[index])
  }
  for (const required of ["manifest", "baseline", "candidate", "baseline-artifact", "candidate-artifact"]) {
    if (!options[required]) throw new Error(`--${required} is required`)
  }
  return options
}

function emitNonComparable(error) {
  process.stdout.write(`${JSON.stringify({
    schema_version: 1,
    status: "non_comparable",
    verdict: "rejected",
    reasons: [error.message],
  }, null, 2)}\n`)
  process.exitCode = 2
}

function main() {
  const [command, ...args] = process.argv.slice(2)
  if (!command || command === "--help" || command === "-h") usage(0)
  if (command === "fingerprint") {
    if (args.length !== 1) usage(2)
    try {
      process.stdout.write(`${fingerprintArtifact(args[0])}\n`)
    } catch (error) {
      process.stderr.write(`skill-eval: ${error.message}\n`)
      process.exitCode = 2
    }
    return
  }
  if (command !== "compare") usage(2)

  try {
    const options = parseCompareArgs(args)
    const manifestBytes = readFileSync(options.manifest)
    const manifestSha = hashManifestBytes(manifestBytes)
    const manifest = JSON.parse(manifestBytes.toString("utf8"))
    const baseline = readJson(options.baseline, "baseline")
    const candidate = readJson(options.candidate, "candidate")
    const baselineFingerprint = fingerprintArtifact(options["baseline-artifact"])
    const candidateFingerprint = fingerprintArtifact(options["candidate-artifact"])
    if (baseline.artifact_fingerprint !== baselineFingerprint) {
      throw new Error("baseline artifact_fingerprint does not match --baseline-artifact")
    }
    if (candidate.artifact_fingerprint !== candidateFingerprint) {
      throw new Error("candidate artifact_fingerprint does not match --candidate-artifact")
    }
    const evaluatorRoot = options["evaluator-root"] || resolve(".")
    const evaluatorBundleSha = manifest.schema_version === 2
      ? fingerprintEvaluatorBundle(evaluatorRoot, manifest.evaluator.bundle.paths)
      : null
    const evaluatorFileSha = manifest.schema_version === 2
      ? fingerprintEvaluatorFile(evaluatorRoot, manifest.evaluator.path)
      : null
    if (manifest.schema_version === 2 && evaluatorBundleSha !== manifest.evaluator.bundle.sha256) {
      throw new Error("evaluator bundle does not match the manifest fingerprint")
    }
    const result = compareDocuments(
      manifest,
      manifestSha,
      baseline,
      candidate,
      evaluatorBundleSha,
      evaluatorFileSha,
    )
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`)
    process.exitCode = result.verdict === "accepted" ? 0 : 1
  } catch (error) {
    emitNonComparable(error)
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main()
}
