#!/usr/bin/env node

import { createHash } from "node:crypto"
import { spawnSync } from "node:child_process"
import { existsSync, lstatSync, readFileSync, readdirSync, realpathSync } from "node:fs"
import { homedir } from "node:os"
import { join, relative, resolve } from "node:path"

const RUNTIMES = ["codex", "pi", "claude", "grok"]
const DEFAULT_SKILL = "runtime-skill-canary"

function usage(exitCode = 0) {
  const output = exitCode === 0 ? process.stdout : process.stderr
  output.write("Usage: runtime-skill-canary [--skill name] [--repo path] [--home path] [--runtime list] [--timeout seconds] [--live] [--json]\n")
  process.exit(exitCode)
}

function parseArgs(argv) {
  const options = {
    skill: DEFAULT_SKILL,
    repo: resolve(new URL("../..", import.meta.url).pathname),
    home: homedir(),
    runtimes: [...RUNTIMES],
    timeoutSeconds: 60,
    live: false,
  }
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index]
    const next = () => {
      index += 1
      if (index >= argv.length) throw new Error(`${arg} requires a value`)
      return argv[index]
    }
    switch (arg) {
      case "--skill":
        options.skill = next()
        break
      case "--repo":
        options.repo = resolve(next())
        break
      case "--home":
        options.home = resolve(next())
        break
      case "--runtime":
        options.runtimes = next().split(",").map((value) => value.trim()).filter(Boolean)
        if (options.runtimes.length === 0 || options.runtimes.some((value) => !RUNTIMES.includes(value))) {
          throw new Error(`--runtime must contain only ${RUNTIMES.join(",")}`)
        }
        break
      case "--timeout": {
        const value = Number(next())
        if (!Number.isSafeInteger(value) || value < 1 || value > 300) {
          throw new Error("--timeout must be an integer from 1 to 300")
        }
        options.timeoutSeconds = value
        break
      }
      case "--live":
        options.live = true
        break
      case "--json":
        break
      case "--help":
      case "-h":
        usage(0)
        break
      default:
        throw new Error(`unknown option: ${arg}`)
    }
  }
  if (!/^[a-z0-9][a-z0-9-]{0,63}$/.test(options.skill)) {
    throw new Error("--skill must be a lowercase skill name")
  }
  return options
}

function catalogEntry(catalogPath, name) {
  if (!existsSync(catalogPath)) return null
  for (const line of readFileSync(catalogPath, "utf8").split("\n")) {
    if (!line || line.startsWith("#")) continue
    const [entryName, source, piCore, agentsVisible, locked] = line.split("\t")
    if (entryName === name) {
      return {
        name: entryName,
        source,
        pi_core: piCore === "1",
        agents_visible: agentsVisible === "1",
        locked: locked === "1",
      }
    }
  }
  return null
}

function hashDirectory(root) {
  const hash = createHash("sha256")
  const files = []
  const stack = [root]
  while (stack.length > 0) {
    const current = stack.pop()
    const entries = readdirSync(current, { withFileTypes: true })
      .sort((a, b) => a.name.localeCompare(b.name))
    for (const entry of entries) {
      const path = join(current, entry.name)
      const stat = lstatSync(path)
      if (stat.isSymbolicLink()) throw new Error("skill source contains an unsupported symlink")
      if (stat.isDirectory()) stack.push(path)
      else if (stat.isFile()) files.push(path)
    }
  }
  for (const path of files.sort((a, b) => relative(root, a).localeCompare(relative(root, b)))) {
    hash.update(relative(root, path))
    hash.update(readFileSync(path))
  }
  return hash.digest("hex")
}

function lockEntry(lockPath, name) {
  if (!existsSync(lockPath)) return null
  try {
    return JSON.parse(readFileSync(lockPath, "utf8"))?.skills?.[name] || null
  } catch {
    return null
  }
}

function resolveBinary(runtime) {
  const envName = `ETABLI_CANARY_${runtime.toUpperCase()}_BIN`
  if (process.env[envName]) return process.env[envName]
  const probe = spawnSync("/usr/bin/env", ["sh", "-c", `command -v ${runtime}`], {
    encoding: "utf8",
    timeout: 2_000,
  })
  return probe.status === 0 ? probe.stdout.trim() : ""
}

function commandFor(runtime, binary, options, prompt) {
  switch (runtime) {
    case "codex":
      return [binary, ["exec", "--ephemeral", "--sandbox", "read-only", "-C", options.repo, prompt]]
    case "pi":
      return [binary, ["--print", "--no-session", "--no-tools", "--thinking", "off", "--approve", prompt]]
    case "claude":
      return [binary, ["--print", "--no-session-persistence", "--max-budget-usd", "0.05", "--tools", "", prompt]]
    case "grok":
      return [binary, ["--single", prompt, "--no-subagents", "--disable-web-search", "--permission-mode", "plan", "--max-turns", "1", "--output-format", "plain"]]
    default:
      throw new Error(`unsupported runtime: ${runtime}`)
  }
}

function invokeRuntime(runtime, options, expected) {
  const binary = resolveBinary(runtime)
  if (!binary) return { state: "skipped", reason: "binary_unavailable" }
  const prompt = "Invoke the shared runtime-skill-canary skill and reply with only its documented canary response. Do not use tools."
  const [command, args] = commandFor(runtime, binary, options, prompt)
  const result = spawnSync(command, args, {
    cwd: options.repo,
    encoding: "utf8",
    timeout: options.timeoutSeconds * 1_000,
    maxBuffer: 2 * 1024 * 1024,
    env: { ...process.env, PI_SKIP_VERSION_CHECK: "1" },
  })
  if (result.error?.code === "ETIMEDOUT") return { state: "unknown", reason: "timeout" }
  if (result.error) return { state: "unknown", reason: "spawn_error" }
  if (result.status !== 0) return { state: "unknown", reason: `exit_${result.status}` }
  const output = `${result.stdout || ""}\n${result.stderr || ""}`
  if (!output.split(/\s+/).includes(expected)) return { state: "failed", reason: "canary_response_missing" }
  return { state: "passed", reason: "documented_canary_response_observed" }
}

function main() {
  let options
  try {
    options = parseArgs(process.argv.slice(2))
  } catch (error) {
    process.stderr.write(`runtime-skill-canary: ${error.message}\n`)
    usage(2)
  }

  const catalogPath = join(options.repo, "workflow/runtime/skill-surface.tsv")
  const lockPath = join(options.repo, "skills-lock.json")
  const entry = catalogEntry(catalogPath, options.skill)
  const sourcePath = join(options.repo, "pi/skills", options.skill)
  const skillPath = join(sourcePath, "SKILL.md")
  const sourceExists = existsSync(skillPath)
  const sourceSha256 = sourceExists ? hashDirectory(sourcePath) : null
  const lock = lockEntry(lockPath, options.skill)
  const lockMatches = Boolean(sourceSha256 && lock?.computedHash === sourceSha256)
  const sourceLocked = Boolean(
    entry?.source === "pi"
    && entry?.locked
    && entry?.agents_visible
    && sourceExists
    && lockMatches,
  )
  const linkPath = join(options.home, ".agents/skills", options.skill)
  let linkValid = false
  let linkState = "missing"
  if (existsSync(linkPath) || (() => { try { return lstatSync(linkPath).isSymbolicLink() } catch { return false } })()) {
    if (!lstatSync(linkPath).isSymbolicLink()) linkState = "not_symlink"
    else if (!existsSync(linkPath)) linkState = "broken"
    else {
      linkValid = realpathSync(linkPath) === realpathSync(sourcePath)
      linkState = linkValid ? "valid" : "wrong_target"
    }
  }

  let canaryResponse = null
  if (sourceExists) {
    const match = readFileSync(skillPath, "utf8").match(/^Canary response: `([A-Z0-9_]+)`$/m)
    canaryResponse = match?.[1] || null
  }
  const liveAuthorized = options.live && process.env.RUN_SKILL_RUNTIME_CANARY === "1"
  const runtimes = {}
  for (const runtime of options.runtimes) {
    if (!options.live) runtimes[runtime] = { state: "skipped", reason: "live_not_requested" }
    else if (!liveAuthorized) runtimes[runtime] = { state: "skipped", reason: "live_opt_in_missing" }
    else if (!sourceLocked || !linkValid || !canaryResponse) runtimes[runtime] = { state: "skipped", reason: "offline_precondition_failed" }
    else runtimes[runtime] = invokeRuntime(runtime, options, canaryResponse)
  }

  const runtimeStates = Object.values(runtimes).map((runtime) => runtime.state)
  const offlinePassed = sourceLocked && linkValid && Boolean(sourceSha256) && Boolean(canaryResponse)
  let status = offlinePassed ? "offline_passed" : "offline_failed"
  let exitCode = offlinePassed ? 0 : 1
  if (options.live && liveAuthorized && offlinePassed) {
    if (runtimeStates.every((state) => state === "passed")) {
      status = "live_passed"
      exitCode = 0
    } else if (runtimeStates.includes("failed")) {
      status = "live_failed"
      exitCode = 1
    } else {
      status = "live_partial"
      exitCode = 3
    }
  } else if (options.live && !liveAuthorized && offlinePassed) {
    status = "live_skipped"
    exitCode = 3
  }

  process.stdout.write(`${JSON.stringify({
    schema_version: 1,
    skill: options.skill,
    status,
    source_locked: {
      passed: sourceLocked,
      catalog_declared: Boolean(entry),
      lock_declared: Boolean(lock),
      lock_matches: lockMatches,
      source_sha256: sourceSha256,
      expected_sha256: lock?.computedHash || null,
    },
    link_valid: { passed: linkValid, state: linkState, surface: "agents_visible" },
    runtime_invoked: runtimes,
    live_opt_in: { requested: options.live, authorized: liveAuthorized },
  }, null, 2)}\n`)
  process.exitCode = exitCode
}

main()
