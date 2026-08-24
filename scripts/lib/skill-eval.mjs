#!/usr/bin/env node

import { createHash } from "node:crypto"
import { readFileSync, readdirSync } from "node:fs"
import { relative, resolve, sep } from "node:path"

const SHA256 = /^[0-9a-f]{64}$/
const SPLITS = ["held_in", "held_out", "safety"]

function usage(exitCode = 0) {
  const output = exitCode === 0 ? process.stdout : process.stderr
  output.write("Usage:\n")
  output.write("  skill-eval fingerprint <skill-directory>\n")
  output.write("  skill-eval compare --manifest <path> --baseline <path> --candidate <path> \\\n")
  output.write("    --baseline-artifact <directory> --candidate-artifact <directory> [--json]\n")
  process.exit(exitCode)
}

function hashBytes(value) {
  return createHash("sha256").update(value).digest("hex")
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
  if (manifest?.schema_version !== 1) throw new Error("manifest schema_version must be 1")
  if (typeof manifest.manifest_id !== "string" || manifest.manifest_id.length === 0) {
    throw new Error("manifest_id is required")
  }
  if (!["frozen_public", "external_isolated"].includes(manifest.visibility)) {
    throw new Error("manifest visibility must be frozen_public or external_isolated")
  }
  if (!SHA256.test(manifest?.evaluator?.sha256 || "")) {
    throw new Error("manifest evaluator.sha256 must be a lowercase SHA-256")
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

function validateResult(result, label, manifest, manifestSha) {
  if (result?.schema_version !== 1) throw new Error(`${label} schema_version must be 1`)
  if (result.manifest_id !== manifest.manifest_id) throw new Error(`${label} manifest_id drift`)
  if (result.manifest_sha256 !== manifestSha) throw new Error(`${label} manifest_sha256 drift`)
  if (result.evaluator_sha256 !== manifest.evaluator.sha256) throw new Error(`${label} evaluator_sha256 drift`)
  if (!SHA256.test(result.artifact_fingerprint || "")) throw new Error(`${label} artifact_fingerprint is invalid`)
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
    }]
  }))
}

export function compareDocuments(manifest, manifestSha, baseline, candidate) {
  validateManifest(manifest)
  const baselineOutcomes = validateResult(baseline, "baseline", manifest, manifestSha)
  const candidateOutcomes = validateResult(candidate, "candidate", manifest, manifestSha)
  const baselineSummary = splitSummary(manifest, baselineOutcomes)
  const candidateSummary = splitSummary(manifest, candidateOutcomes)
  const reasons = []

  if (baseline.artifact_fingerprint === candidate.artifact_fingerprint) {
    reasons.push("candidate_fingerprint_unchanged")
  }
  if (candidateSummary.held_in.passed <= baselineSummary.held_in.passed) {
    reasons.push("held_in_no_strict_gain")
  }
  if (candidateSummary.held_out.passed < baselineSummary.held_out.passed) {
    reasons.push("held_out_regression")
  }
  if (candidateSummary.safety.passed < baselineSummary.safety.passed) {
    reasons.push("safety_regression")
  }

  return {
    schema_version: 1,
    status: "comparable",
    verdict: reasons.length === 0 ? "accepted" : "rejected",
    manifest_id: manifest.manifest_id,
    manifest_sha256: manifestSha,
    visibility: manifest.visibility,
    evaluator_sha256: manifest.evaluator.sha256,
    baseline: {
      artifact_fingerprint: baseline.artifact_fingerprint,
      splits: baselineSummary,
    },
    candidate: {
      artifact_fingerprint: candidate.artifact_fingerprint,
      splits: candidateSummary,
    },
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
    if (!["--manifest", "--baseline", "--candidate", "--baseline-artifact", "--candidate-artifact"].includes(arg)) {
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
    const manifestSha = hashBytes(manifestBytes)
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
    const result = compareDocuments(
      JSON.parse(manifestBytes.toString("utf8")),
      manifestSha,
      baseline,
      candidate,
    )
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`)
    process.exitCode = result.verdict === "accepted" ? 0 : 1
  } catch (error) {
    emitNonComparable(error)
  }
}

main()
