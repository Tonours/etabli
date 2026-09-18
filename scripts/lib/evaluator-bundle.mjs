import { createHash } from "node:crypto"
import { lstatSync, readFileSync } from "node:fs"
import { isAbsolute, relative, resolve, sep } from "node:path"

const SHA256 = /^[0-9a-f]{64}$/

function hashBytes(value) {
  return createHash("sha256").update(value).digest("hex")
}

function normalizedPaths(paths) {
  if (!Array.isArray(paths) || paths.length === 0) {
    throw new Error("evaluator bundle paths must be a non-empty array")
  }
  const values = paths.map((value) => {
    if (typeof value !== "string" || value.trim() === "") {
      throw new Error("evaluator bundle paths must contain non-empty strings")
    }
    const path = value.trim()
    if (isAbsolute(path)) throw new Error(`evaluator bundle path must be relative: ${path}`)
    const normalized = path.split("\\").join("/")
    if (normalized === ".." || normalized.startsWith("../") || normalized.includes("/../")) {
      throw new Error(`evaluator bundle path escapes root: ${path}`)
    }
    return normalized
  })
  const unique = [...new Set(values)].sort()
  if (unique.length !== values.length) throw new Error("evaluator bundle paths must be unique")
  return unique
}

function regularFile(root, path) {
  const absolute = resolve(root, path)
  const rel = relative(root, absolute)
  if (rel.startsWith(`..${sep}`) || rel === ".." || rel.startsWith(sep)) {
    throw new Error(`evaluator bundle path escapes root: ${path}`)
  }
  const stat = lstatSync(absolute)
  if (!stat.isFile() || stat.isSymbolicLink()) {
    throw new Error(`evaluator bundle entry is not a regular file: ${path}`)
  }
  return absolute
}

export function fingerprintEvaluatorFile(root, path) {
  const resolvedRoot = resolve(root)
  const [normalized] = normalizedPaths([path])
  return hashBytes(readFileSync(regularFile(resolvedRoot, normalized)))
}

/**
 * Hash the exact files that supplied an evaluator, preserving relative names.
 * Symlinks and traversal are rejected so a manifest cannot silently change
 * what the evaluator means between baseline and candidate runs.
 */
export function fingerprintEvaluatorBundle(root, paths) {
  const resolvedRoot = resolve(root)
  const digest = createHash("sha256")
  for (const path of normalizedPaths(paths)) {
    const absolute = regularFile(resolvedRoot, path)
    digest.update(path)
    digest.update("\0")
    digest.update(readFileSync(absolute))
    digest.update("\0")
  }
  return digest.digest("hex")
}

export function isSha256(value) {
  return typeof value === "string" && SHA256.test(value)
}

export function hashManifestBytes(value) {
  return hashBytes(value)
}
