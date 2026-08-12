#!/usr/bin/env node

import { spawnSync } from "node:child_process"
import { existsSync, readFileSync } from "node:fs"
import { basename, join, resolve } from "node:path"

function usage(exitCode = 0) {
  const output = exitCode === 0 ? process.stdout : process.stderr
  output.write("Usage: session-handoff [--repo path] [--workflow-dir path] [--run slug] [--json]\n")
  process.exit(exitCode)
}

function parseArgs(argv) {
  const options = { repo: process.cwd(), workflowDir: null, run: null, json: false }
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index]
    const next = () => {
      index += 1
      if (index >= argv.length) throw new Error(`${arg} requires a value`)
      return argv[index]
    }
    switch (arg) {
      case "--repo":
        options.repo = resolve(next())
        break
      case "--workflow-dir":
        options.workflowDir = resolve(next())
        break
      case "--run":
        options.run = next()
        break
      case "--json":
        options.json = true
        break
      case "--help":
      case "-h":
        usage(0)
        break
      default:
        throw new Error(`unknown option: ${arg}`)
    }
  }
  if (options.run && !/^[a-z0-9][a-z0-9_-]*$/.test(options.run)) {
    throw new Error("--run must be a valid workflow slug")
  }
  if (!options.workflowDir) options.workflowDir = join(options.repo, ".workflow")
  return options
}

function readJson(path, label) {
  try {
    return JSON.parse(readFileSync(path, "utf8"))
  } catch (error) {
    throw new Error(`${label} is invalid: ${error.message}`)
  }
}

function resolveRun(options) {
  if (options.run) return options.run
  const pointerPath = join(options.workflowDir, ".active-run.json")
  if (!existsSync(pointerPath)) throw new Error("active run pointer is unavailable; pass --run")
  const pointer = readJson(pointerPath, "active run pointer")
  if (!/^[a-z0-9][a-z0-9_-]*$/.test(pointer?.run || "")) {
    throw new Error("active run pointer has no valid run")
  }
  return pointer.run
}

function readEvents(path, run) {
  const events = []
  const lines = readFileSync(path, "utf8").split("\n")
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index]
    if (!line.trim()) continue
    let event
    try {
      event = JSON.parse(line)
    } catch {
      throw new Error(`ledger contains invalid JSON at line ${index + 1}`)
    }
    if (event.run !== run) throw new Error(`ledger run mismatch at line ${index + 1}`)
    events.push(event)
  }
  if (events.length === 0) throw new Error("ledger is empty")
  return events
}

function planSection(text, heading) {
  const lines = text.split("\n")
  const start = lines.findIndex((line) => line.trim() === `## ${heading}`)
  if (start === -1) return ""
  const selected = []
  for (let index = start + 1; index < lines.length; index += 1) {
    if (/^##\s+/.test(lines[index])) break
    selected.push(lines[index])
  }
  return selected.join("\n").trim()
}

function firstParagraph(section) {
  return compact(section.split(/\n\s*\n/).map((value) => value.trim()).find(Boolean) || "unavailable", 500)
}

function planField(section, label) {
  const prefix = `- ${label}:`
  const line = section.split("\n").find((candidate) => candidate.startsWith(prefix))
  return line ? compact(line.slice(prefix.length), 500) : null
}

function compact(value, maxLength = 240) {
  const text = String(value ?? "").replace(/\s+/g, " ").trim()
  if (text.length <= maxLength) return text
  return `${text.slice(0, maxLength - 1)}…`
}

function gitEvidence(repo) {
  const run = (args) => spawnSync("git", args, { cwd: repo, encoding: "utf8" })
  const inside = run(["rev-parse", "--is-inside-work-tree"])
  if (inside.status !== 0 || inside.stdout.trim() !== "true") {
    return { available: false, branch: null, head: null, dirty_paths: [] }
  }
  const branch = run(["branch", "--show-current"])
  const head = run(["rev-parse", "--short=12", "HEAD"])
  const status = run(["status", "--short"])
  return {
    available: true,
    branch: branch.status === 0 ? branch.stdout.trim() || "detached" : "unknown",
    head: head.status === 0 ? head.stdout.trim() : "unborn",
    dirty_paths: status.status === 0
      ? status.stdout.split("\n").filter(Boolean).slice(0, 20).map((path) => compact(path))
      : [],
    dirty_truncated: status.status === 0 && status.stdout.split("\n").filter(Boolean).length > 20,
  }
}

function lastOf(events, type) {
  return [...events].reverse().find((event) => event.event === type) || null
}

function latestBlockingEvent(events) {
  if (events.at(-1)?.event === "completed") return null
  for (let index = events.length - 1; index >= 0; index -= 1) {
    const event = events[index]
    if (event.event === "blocked") return event
    if (event.event !== "validation_failed" && event.event !== "no_progress") continue

    const command = event.detail?.command
    const exactResolution = events.slice(index + 1).some((candidate) => (
      candidate.event === "validation_run"
      && candidate.detail?.exit === 0
      && command
      && candidate.detail?.command === command
    ))
    if (exactResolution) continue

    const retry = events[index + 1]
    if (retry?.event === "retry_classified") {
      const retryOutcome = events.slice(index + 2).find((candidate) => (
        candidate.event === "validation_run"
        || candidate.event === "validation_failed"
        || candidate.event === "no_progress"
        || candidate.event === "blocked"
      ))
      if (retryOutcome?.event === "validation_run" && retryOutcome.detail?.exit === 0) continue
    }
    return event
  }
  return null
}

function asArray(value) {
  if (Array.isArray(value)) return value.map((item) => compact(item)).filter(Boolean)
  if (value === null || value === undefined || value === "") return []
  return [compact(value)].filter(Boolean)
}

function buildHandoff(options) {
  const run = resolveRun(options)
  const ledgerPath = join(options.workflowDir, run, "events.jsonl")
  if (!existsSync(ledgerPath)) throw new Error(`active ledger is unavailable for ${run}`)
  const events = readEvents(ledgerPath, run)
  const planPath = join(options.repo, "PLAN.md")
  const plan = existsSync(planPath) ? readFileSync(planPath, "utf8") : ""
  const handoffSection = planSection(plan, "Handoff State")
  const explicit = lastOf(events, "handoff")?.detail || null
  const slice = lastOf(events, "project_slice_completed")?.detail || null
  const adversary = lastOf(events, "adversary_completed")?.detail || null
  const blockerEvent = latestBlockingEvent(events)
  const validations = events
    .filter((event) => event.event === "validation_run" || event.event === "validation_failed")
    .slice(-3)
    .map((event) => ({
      command: compact(event.detail?.command || "unavailable"),
      exit: event.detail?.exit ?? null,
      status: event.event === "validation_run" && event.detail?.exit === 0 ? "passed" : "failed",
    }))

  const blocker = blockerEvent
    ? blockerEvent.detail?.reason || blockerEvent.detail?.failure || blockerEvent.detail?.check_or_hypothesis || blockerEvent.event
    : null
  const doNotRedo = explicit?.do_not_redo
    || (blockerEvent?.event === "no_progress" ? asArray(blockerEvent.detail?.eliminated) : [])

  return {
    schema_version: 1,
    run,
    objective: firstParagraph(planSection(plan, "Goal")),
    state: explicit?.done
      ? "handoff event recorded"
      : planField(handoffSection, "Current state") || events.at(-1).event,
    decisions: asArray(adversary?.accepted_findings).slice(0, 5),
    done: asArray(explicit?.done || slice?.evidence).slice(0, 8),
    pending: asArray(explicit?.pending || slice?.remaining).slice(0, 8),
    validations,
    blocker: blocker ? compact(blocker, 500) : null,
    next_action: explicit?.next_action || planField(handoffSection, "Next action") || "unavailable",
    do_not_redo: asArray(doNotRedo).slice(0, 8),
    git: gitEvidence(options.repo),
    sources: {
      plan: existsSync(planPath) ? "PLAN.md" : null,
      ledger: `${basename(options.workflowDir)}/${run}/events.jsonl`,
    },
    projection_only: true,
  }
}

function markdown(pack) {
  const lines = [
    "# Session handoff",
    "",
    `- Run: \`${pack.run}\``,
    `- Objective: ${pack.objective}`,
    `- State: ${pack.state}`,
    `- Git: ${pack.git.available ? `${pack.git.branch}@${pack.git.head}; ${pack.git.dirty_paths.length} dirty paths` : "unavailable"}`,
    "",
    "## Done",
    ...(pack.done.length ? pack.done.map((item) => `- ${item}`) : ["- No completed slice evidence available."]),
    "",
    "## Validations",
    ...(pack.validations.length
      ? pack.validations.map((item) => `- ${item.status}: \`${item.command}\``)
      : ["- No validation evidence available."]),
    "",
    `## Blocker\n\n${pack.blocker || "None observed after the latest validation."}`,
    "",
    `## Next action\n\n${pack.next_action}`,
    "",
    "## Do not redo",
    ...(pack.do_not_redo.length ? pack.do_not_redo.map((item) => `- ${item}`) : ["- None recorded."]),
  ]
  return `${lines.join("\n")}\n`
}

function main() {
  try {
    const options = parseArgs(process.argv.slice(2))
    const pack = buildHandoff(options)
    process.stdout.write(options.json ? `${JSON.stringify(pack, null, 2)}\n` : markdown(pack))
  } catch (error) {
    process.stderr.write(`session-handoff: ${error.message}\n`)
    process.exitCode = 2
  }
}

main()
