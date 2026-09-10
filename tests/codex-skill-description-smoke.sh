#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

ROOT_DIR="$ROOT_DIR" node --input-type=module <<'NODE'
import { createHash } from 'node:crypto'
import { lstatSync, readFileSync, readdirSync } from 'node:fs'
import { dirname, join, relative } from 'node:path'

const root = process.env.ROOT_DIR
const fixturePath = join(root, 'tests/fixtures/codex-skill-descriptions.tsv')
const sha256 = value => createHash('sha256').update(value).digest('hex')
const rows = readFileSync(fixturePath, 'utf8')
  .split('\n')
  .filter(line => line && !line.startsWith('#'))
  .map(line => {
    const fields = line.split('\t')
    if (fields.length !== 10) throw new Error(`fixture row has ${fields.length} fields`)
    const [
      runtimeName, lockKey, sourcePath, expectedBytes, description,
      routePattern, bodyHash, frontHash, otherCount, otherHash,
    ] = fields
    return {
      runtimeName,
      lockKey,
      sourcePath,
      expectedBytes: Number(expectedBytes),
      description,
      routePattern: routePattern.replaceAll('\\\\', '\\'),
      bodyHash,
      frontHash,
      otherCount: Number(otherCount),
      otherHash,
    }
  })

const expectedNames = [
  'herdr',
]
const actualNames = rows.map(row => row.runtimeName).sort()
if (JSON.stringify(actualNames) !== JSON.stringify(expectedNames)) {
  throw new Error(`target set drifted: ${actualNames.join(',')}`)
}

const expectedLockKeys = []
const actualLockKeys = rows.filter(row => row.lockKey !== '-').map(row => row.lockKey).sort()
if (JSON.stringify(actualLockKeys) !== JSON.stringify(expectedLockKeys)) {
  throw new Error(`lock key set drifted: ${actualLockKeys.join(',')}`)
}

function otherFilesManifest(skillFile) {
  const skillRoot = dirname(skillFile)
  const entries = []
  function walk(directory) {
    for (const name of readdirSync(directory).sort()) {
      const path = join(directory, name)
      const stat = lstatSync(path)
      if (stat.isSymbolicLink()) throw new Error(`unexpected symlink in skill: ${path}`)
      if (stat.isDirectory()) walk(path)
      else if (path !== skillFile) {
        const data = readFileSync(path)
        entries.push(`${relative(skillRoot, path)}\t${data.length}\t${sha256(data)}`)
      }
    }
  }
  walk(skillRoot)
  return entries
}

// Prompt classification is not tested here: no offline skill router exists, so
// the Codex skill description stays proxy_supported. The description's routing
// anchor is asserted per row below.

let descriptionBytes = 0
for (const row of rows) {
  const skillFile = join(root, row.sourcePath)
  const raw = readFileSync(skillFile)
  const text = raw.toString('utf8')
  if (!text.startsWith('---\n')) throw new Error(`missing frontmatter: ${row.sourcePath}`)
  const closing = text.indexOf('\n---\n', 4)
  if (closing < 0) throw new Error(`missing closing frontmatter: ${row.sourcePath}`)
  const frontmatter = text.slice(4, closing)
  const descriptionLine = frontmatter.split('\n').find(line => line.startsWith('description: '))
  if (!descriptionLine) throw new Error(`missing description: ${row.sourcePath}`)
  let description = descriptionLine.slice('description: '.length)
  if (description.startsWith('"')) description = JSON.parse(description)
  const bytes = Buffer.byteLength(description, 'utf8')
  if (description !== row.description || bytes !== row.expectedBytes || bytes > 160) {
    throw new Error(`description drifted: ${row.runtimeName}`)
  }
  descriptionBytes += bytes

  const declaredName = frontmatter.split('\n').find(line => line.startsWith('name: '))?.slice('name: '.length)
  if (declaredName !== row.runtimeName) throw new Error(`frontmatter name drifted: ${row.sourcePath}`)
  const frontWithoutDescription = frontmatter
    .split('\n')
    .filter(line => !line.startsWith('description: '))
    .join('\n')
  if (sha256(frontWithoutDescription) !== row.frontHash) {
    throw new Error(`non-description frontmatter changed: ${row.runtimeName}`)
  }
  const prefix = text.slice(0, closing + '\n---\n'.length)
  const body = raw.subarray(Buffer.byteLength(prefix, 'utf8'))
  if (sha256(body) !== row.bodyHash) throw new Error(`body changed: ${row.runtimeName}`)
  const otherFiles = otherFilesManifest(skillFile)
  if (otherFiles.length !== row.otherCount || sha256(otherFiles.join('\n')) !== row.otherHash) {
    throw new Error(`referenced file tree changed: ${row.runtimeName}`)
  }

  const ownPattern = new RegExp(row.routePattern, 'iu')
  if (!ownPattern.test(description)) throw new Error(`description lost routing anchor: ${row.runtimeName}`)
}

if (descriptionBytes !== 142 || descriptionBytes > 1036) {
  throw new Error(`description total drifted: ${descriptionBytes}`)
}

process.stdout.write(
  `codex skill description smoke: ok (1 skill, ${descriptionBytes} bytes, proxy_supported)\n`,
)
NODE
