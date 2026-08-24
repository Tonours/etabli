#!/usr/bin/env node

import { execFileSync } from "node:child_process"
import { createHash } from "node:crypto"
import {
  existsSync,
  lstatSync,
  readFileSync,
  readdirSync,
  statSync,
} from "node:fs"
import { homedir } from "node:os"
import { basename, join, relative, resolve, sep } from "node:path"

const DAY_MS = 24 * 60 * 60 * 1000
const SOURCES = ["codex", "pi", "claude", "grok"]
const DEFAULT_LIMITS = {
  maxFiles: 2_000,
  maxBytes: 64 * 1024 * 1024,
  maxMessages: 20_000,
}

const injectedMarkers = [
  "<recommended_plugins>",
  "# agents.md instructions",
  "<environment_context>",
  "<permissions instructions>",
  "<collaboration_mode>",
  "<apps_instructions>",
  "<plugins_instructions>",
  "<skills_instructions>",
  "<skill_information>",
  "<app-context>",
  "<user_info>",
  "<system-reminder>",
  "<task-notification>",
]

const themes = {
  continuity_handoff: [
    /\bresume\b/, /\bhandoff\b/, /\bcheckpoint\b/, /\bnext action\b/,
    /\brepr(?:endre|ends|ise)\b/, /\bprochaine [eé]tape\b/,
  ],
  workflow_goal_plan: [
    /\/goal\b/, /\bplan\.md\b/, /\bplan-loop\b/, /\bplan-implement\b/,
    /\bworkflow\b/, /\bready\b/,
  ],
  verification_evidence: [
    /\bverif(?:y|ication|ie|ier|i[eé])\b/, /\bdouble[ -]?check\b/,
    /\bpreuve(?:s)?\b/, /\bevidence\b/, /\bvalidation\b/, /\btests?\b/,
  ],
  skills_config_runtime: [
    /\bskills?\b/, /\bplugins?\b/, /\bconfig(?:uration)?\b/,
    /\bsymlinks?\b/, /\bruntime visibility\b/,
  ],
  multi_harness_models: [
    /\bcodex\b/, /\bclaude\b/, /\bgrok\b/, /\bpi\b/,
    /\bmulti[- ]harness\b/, /\bcross[- ]harness\b/,
  ],
  automation_monitoring: [
    /\bautomation\b/, /\bautomatisation\b/, /\bscheduled\b/,
    /\br[eé]current\b/, /\bmonitor(?:ing)?\b/, /\bcron\b/,
  ],
  maintenance_delivery: [
    /\bmaintenan(?:ce|t)\b/, /\bdependenc(?:y|ies)\b/, /\bd[eé]pendances?\b/,
    /\bupgrade\b/, /\bcommit\b/, /\bpush\b/, /\bci\b/,
  ],
  privacy_security: [
    /\bsecurity\b/, /\bs[eé]curit[eé]\b/, /\bsecret(?:s)?\b/,
    /\bprivacy\b/, /\bcredentials?\b/,
  ],
}

const practices = {
  explicit_evidence_bar: [
    /\btout v[eé]rifier\b/, /\bdouble[ -]?check\b/, /\bdocumenter\b/,
    /\bavec (?:des )?preuves\b/, /\bevidence[- ]first\b/,
  ],
  bounded_autonomy: [
    /\/goal\b/, /\bjusqu['’]au bout\b/, /\bdo not stop\b/,
    /\bde a [aà] z\b/, /\bautonom(?:e|ous)\b/,
  ],
  read_only_or_no_external_write: [
    /\bread[- ]only\b/, /\breport only\b/, /\ben lecture seule\b/,
    /\bsans (?:modifier|[eé]crire|push|d[eé]ployer)\b/,
  ],
  preserve_existing_state: [
    /\bpreserve\b.*\b(?:changes|worktree|state)\b/,
    /\bpr[eé]serve\b.*\b(?:modifications|travail|worktree)\b/,
  ],
  explicit_uncertainty_no_overclaim: [
    /\bincertain\b/, /\binconclusive\b/, /\bblocked\b/, /\bno[- ]op\b/,
    /\bunknown\b/, /\bne (?:pas )?(?:inventer|survendre|affirmer)\b/,
  ],
}

function usage(exitCode = 0) {
  const out = exitCode === 0 ? process.stdout : process.stderr
  out.write(`Usage: conversation-retrospect [options]\n\n`)
  out.write(`Options:\n`)
  out.write(`  --since <ISO date>       Start of the evidence window (default: 7 days)\n`)
  out.write(`  --until <ISO date>       End of the evidence window (default: now)\n`)
  out.write(`  --source <list>          Comma-separated sources: codex,pi,claude,grok\n`)
  out.write(`  --max-files <n>          Per-source files read (default: 2000)\n`)
  out.write(`  --max-bytes <n>          Per-source bytes read (default: 67108864)\n`)
  out.write(`  --max-messages <n>       Per-source user messages retained (default: 20000)\n`)
  out.write(`  --fixture-root <path>    Read synthetic fixture stores instead of live stores\n`)
  out.write(`  --json                   Emit JSON (the only supported output format)\n`)
  out.write(`  --help                   Show this help\n`)
  process.exit(exitCode)
}

function parseDate(value, label) {
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) throw new Error(`${label} must be an ISO date`)
  return date
}

function positiveInteger(value, label) {
  const parsed = Number(value)
  if (!Number.isSafeInteger(parsed) || parsed <= 0) {
    throw new Error(`${label} must be a positive integer`)
  }
  return parsed
}

function parseArgs(argv) {
  const options = {
    since: null,
    until: new Date(),
    fixtureRoot: null,
    sources: new Set(SOURCES),
    ...DEFAULT_LIMITS,
  }

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index]
    const next = () => {
      index += 1
      if (index >= argv.length) throw new Error(`${arg} requires a value`)
      return argv[index]
    }
    switch (arg) {
      case "--since":
        options.since = parseDate(next(), "--since")
        break
      case "--until":
        options.until = parseDate(next(), "--until")
        break
      case "--source": {
        const requested = next().split(",").map((value) => value.trim()).filter(Boolean)
        if (requested.length === 0 || requested.some((value) => !SOURCES.includes(value))) {
          throw new Error(`--source must contain only ${SOURCES.join(",")}`)
        }
        options.sources = new Set(requested)
        break
      }
      case "--max-files":
        options.maxFiles = positiveInteger(next(), "--max-files")
        break
      case "--max-bytes":
        options.maxBytes = positiveInteger(next(), "--max-bytes")
        break
      case "--max-messages":
        options.maxMessages = positiveInteger(next(), "--max-messages")
        break
      case "--fixture-root":
        options.fixtureRoot = resolve(next())
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

  if (!options.since) options.since = new Date(options.until.getTime() - 7 * DAY_MS)
  if (options.since > options.until) throw new Error("--since must not be after --until")
  if (options.fixtureRoot && !existsSync(options.fixtureRoot)) {
    throw new Error("--fixture-root does not exist")
  }
  return options
}

function createBudget(options) {
  return {
    maxFiles: options.maxFiles,
    maxBytes: options.maxBytes,
    maxMessages: options.maxMessages,
    filesRead: 0,
    bytesRead: 0,
    messagesRetained: 0,
    truncated: false,
  }
}

function boundedRead(path, budget) {
  if (budget.filesRead >= budget.maxFiles) {
    budget.truncated = true
    return null
  }
  let stat
  try {
    if (lstatSync(path).isSymbolicLink()) return null
    stat = statSync(path)
  } catch {
    return null
  }
  if (!stat.isFile()) return null
  if (budget.bytesRead + stat.size > budget.maxBytes) {
    budget.truncated = true
    return null
  }
  const content = readFileSync(path, "utf8")
  budget.filesRead += 1
  budget.bytesRead += Buffer.byteLength(content)
  return content
}

function walkFiles(root, predicate, options) {
  if (!existsSync(root)) return []
  const paths = []
  const stack = [root]
  const candidateCap = Math.max(options.maxFiles * 4, options.maxFiles)
  while (stack.length > 0 && paths.length < candidateCap) {
    const current = stack.pop()
    let entries
    try {
      entries = readdirSync(current, { withFileTypes: true })
    } catch {
      continue
    }
    for (const entry of entries) {
      if (entry.isSymbolicLink()) continue
      const entryPath = join(current, entry.name)
      if (entry.isDirectory()) {
        if (entry.name !== "subagents") stack.push(entryPath)
      } else if (entry.isFile() && predicate(entryPath)) {
        let mtime = 0
        try {
          mtime = statSync(entryPath).mtimeMs
        } catch {
          continue
        }
        if (mtime >= options.since.getTime() - DAY_MS) paths.push(entryPath)
      }
      if (paths.length >= candidateCap) break
    }
  }
  return paths.sort()
}

function parseJsonLines(path, budget) {
  const raw = boundedRead(path, budget)
  if (raw === null) return { rows: [], errors: 0, skipped: true }
  const rows = []
  let errors = 0
  for (const line of raw.split("\n")) {
    if (!line.trim()) continue
    try {
      rows.push(JSON.parse(line))
    } catch {
      errors += 1
    }
  }
  return { rows, errors, skipped: false }
}

function parseJsonFile(path, budget) {
  const raw = boundedRead(path, budget)
  if (raw === null) return { value: null, error: false, skipped: true }
  try {
    return { value: JSON.parse(raw), error: false, skipped: false }
  } catch {
    return { value: null, error: true, skipped: false }
  }
}

function textsFromContent(content) {
  if (typeof content === "string") return [content]
  if (!Array.isArray(content)) return []
  return content.flatMap((item) => {
    if (typeof item === "string") return [item]
    if (!item || typeof item !== "object") return []
    if (typeof item.text === "string") return [item.text]
    if (typeof item.content === "string") return [item.content]
    return []
  })
}

function cleanUserText(text) {
  if (typeof text !== "string") return ""
  let cleaned = text.replaceAll("\u0000", "").trim()
  if (!cleaned) return ""

  const lower = cleaned.toLocaleLowerCase("fr")
  let injectedAt = -1
  for (let i = 0; i < INJECTED_MARKER_COUNT; i += 1) {
    const index = lower.indexOf(injectedMarkers[i])
    if (index === 0) return ""
    if (index > 0 && (injectedAt === -1 || index < injectedAt)) injectedAt = index
  }
  if (injectedAt > 0) cleaned = cleaned.slice(0, injectedAt).trim()
  if (/^<user_query>/i.test(cleaned)) {
    cleaned = cleaned
      .replace(/^<user_query>\s*/i, "")
      .replace(/\s*<\/user_query>\s*$/i, "")
      .trim()
  }

  return cleaned
    .replace(/-----BEGIN [A-Z ]+PRIVATE KEY-----[\s\S]*?-----END [A-Z ]+PRIVATE KEY-----/g, "[REDACTED_SECRET]")
    .replace(/\b(?:crsr|sk|ghp|github_pat|xox[baprs]|npm)_[A-Za-z0-9_-]{12,}\b/g, "[REDACTED_SECRET]")
    .replace(/\b[0-9a-f]{48,}\b/gi, "[REDACTED_SECRET]")
}

function canonicalText(text) {
  return text
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase("fr")
    .replace(/https?:\/\/\S+/g, "<url>")
    .replace(/\b[0-9a-f]{8}-[0-9a-f-]{27,}\b/g, "<uuid>")
    .replace(/\s+/g, " ")
    .trim()
}

function stableHash(value, length = 16) {
  return createHash("sha256").update(value).digest("hex").slice(0, length)
}

function validDate(value, fallback = null) {
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? fallback : value
  if (typeof value === "number") {
    const milliseconds = value > 10_000_000_000 ? value : value * 1000
    const date = new Date(milliseconds)
    return Number.isNaN(date.getTime()) ? fallback : date
  }
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? fallback : date
}

function withinWindow(date, options) {
  return date >= options.since && date <= options.until
}

function addTexts(target, candidates, budget) {
  for (const candidate of candidates) {
    if (budget.messagesRetained >= budget.maxMessages) {
      budget.truncated = true
      return
    }
    const cleaned = cleanUserText(candidate)
    if (!cleaned) continue
    target.push(cleaned)
    budget.messagesRetained += 1
  }
}

const THEME_ENTRIES = Object.entries(themes)
const PRACTICE_ENTRIES = Object.entries(practices)
const INJECTED_MARKER_COUNT = injectedMarkers.length

function markRecord(record) {
  const combined = canonicalText(record.texts.join("\n"))
  const opener = record.texts[0] ? canonicalText(record.texts[0].slice(0, 4_000)) : ""
  const probe = /\b(?:reply|respond|say) exactly\b/.test(combined)
    || /\bconnectivity probe\b/.test(combined)
    || (/^ping\b/.test(combined) && combined.length < 120)
  const matchedThemes = []
  for (let i = 0; i < THEME_ENTRIES.length; i += 1) {
    const patterns = THEME_ENTRIES[i][1]
    for (let j = 0; j < patterns.length; j += 1) {
      if (patterns[j].test(combined)) { matchedThemes.push(THEME_ENTRIES[i][0]); break }
    }
  }
  const matchedPractices = []
  for (let i = 0; i < PRACTICE_ENTRIES.length; i += 1) {
    const patterns = PRACTICE_ENTRIES[i][1]
    for (let j = 0; j < patterns.length; j += 1) {
      if (patterns[j].test(combined)) { matchedPractices.push(PRACTICE_ENTRIES[i][0]); break }
    }
  }
  return {
    ...record,
    openerHash: opener ? stableHash(opener) : "",
    probe,
    themes: matchedThemes,
    practices: matchedPractices,
  }
}

function safeFixturePath(base, candidate) {
  const path = resolve(base, candidate)
  const rel = relative(base, path)
  if (!rel || (!rel.startsWith(`..${sep}`) && rel !== ".." && !rel.startsWith(sep))) {
    return path
  }
  return null
}

function pathInsideRoots(path, roots) {
  const resolvedPath = resolve(path)
  return roots.some((root) => {
    const rel = relative(resolve(root), resolvedPath)
    return rel === "" || (!rel.startsWith(`..${sep}`) && rel !== ".." && !rel.startsWith(sep))
  })
}

function defaultRoots() {
  const home = homedir()
  return {
    codexState: join(home, ".codex/state_5.sqlite"),
    codexRollouts: [join(home, ".codex/sessions"), join(home, ".codex/archived_sessions")],
    pi: join(home, ".pi/agent/sessions"),
    claude: [join(home, ".claude/projects"), join(home, ".claude/transcripts")],
    grok: join(home, ".grok/sessions"),
  }
}

function sourceResult(status, budget, records = [], parseErrors = 0, discovered = 0) {
  return { status, budget, records, parseErrors, discovered }
}

function readCodex(options) {
  const budget = createBudget(options)
  let rows = []
  let parseErrors = 0
  let rolloutBase = null

  if (options.fixtureRoot) {
    rolloutBase = join(options.fixtureRoot, "codex")
    const index = parseJsonFile(join(rolloutBase, "index.json"), budget)
    if (index.skipped || index.value === null) {
      return sourceResult(index.error ? "partial" : "unavailable", budget, [], index.error ? 1 : 0)
    }
    rows = Array.isArray(index.value) ? index.value : []
  } else {
    const liveRoots = defaultRoots()
    const statePath = liveRoots.codexState
    if (!existsSync(statePath)) return sourceResult("unavailable", budget)
    const since = Math.floor(options.since.getTime() / 1000)
    const until = Math.ceil(options.until.getTime() / 1000)
    const sql = `select id, rollout_path, created_at, updated_at, title from threads where rollout_path <> '' and updated_at >= ${since} and updated_at <= ${until} order by updated_at asc;`
    try {
      rows = JSON.parse(execFileSync(
        "sqlite3",
        ["-json", `file:${statePath}?mode=ro`, sql],
        { encoding: "utf8", maxBuffer: options.maxBytes },
      ) || "[]")
    } catch {
      return sourceResult("unavailable", budget)
    }
  }

  const records = []
  for (const row of rows) {
    const updatedAt = validDate(row.updated_at, new Date(0))
    if (!withinWindow(updatedAt, options)) continue
    const createdAt = validDate(row.created_at, updatedAt)
    const rolloutPath = options.fixtureRoot
      ? safeFixturePath(rolloutBase, row.rollout_path || "")
      : row.rollout_path
    const rolloutAllowed = options.fixtureRoot
      ? Boolean(rolloutPath)
      : Boolean(rolloutPath && pathInsideRoots(rolloutPath, defaultRoots().codexRollouts))
    if (!rolloutAllowed) {
      parseErrors += 1
      continue
    }
    const parsed = parseJsonLines(rolloutPath, budget)
    parseErrors += parsed.errors
    const texts = []
    for (const item of parsed.rows) {
      if (item?.type !== "response_item") continue
      if (item?.payload?.type !== "message" || item?.payload?.role !== "user") continue
      addTexts(texts, textsFromContent(item.payload.content), budget)
    }
    if (texts.length === 0) addTexts(texts, [row.title], budget)
    records.push(markRecord({
      source: "codex",
      id: String(row.id),
      createdAt,
      updatedAt,
      texts,
    }))
  }
  return sourceResult(budget.truncated ? "partial" : "ok", budget, records, parseErrors, rows.length)
}

function readPi(options) {
  const budget = createBudget(options)
  const root = options.fixtureRoot ? join(options.fixtureRoot, "pi") : defaultRoots().pi
  if (!existsSync(root)) return sourceResult("unavailable", budget)
  const paths = walkFiles(root, (path) => path.endsWith(".jsonl"), options)
  const records = []
  let parseErrors = 0
  for (const path of paths) {
    const parsed = parseJsonLines(path, budget)
    parseErrors += parsed.errors
    const session = parsed.rows.find((row) => row?.type === "session") || {}
    const timestamps = parsed.rows
      .map((row) => validDate(row?.timestamp ?? row?.message?.timestamp))
      .filter(Boolean)
    const createdAt = validDate(session.timestamp, timestamps[0] ?? new Date(0))
    const updatedAt = timestamps.at(-1) ?? createdAt
    if (!withinWindow(updatedAt, options)) continue
    const texts = []
    for (const row of parsed.rows) {
      if (row?.type !== "message" || row?.message?.role !== "user") continue
      addTexts(texts, textsFromContent(row.message.content), budget)
    }
    records.push(markRecord({
      source: "pi",
      id: String(session.id ?? basename(path, ".jsonl")),
      createdAt,
      updatedAt,
      texts,
    }))
  }
  return sourceResult(budget.truncated ? "partial" : "ok", budget, records, parseErrors, paths.length)
}

function readClaude(options) {
  const budget = createBudget(options)
  const roots = options.fixtureRoot
    ? [join(options.fixtureRoot, "claude")]
    : defaultRoots().claude
  if (!roots.some(existsSync)) return sourceResult("unavailable", budget)
  const paths = roots.flatMap((root) => walkFiles(root, (path) => path.endsWith(".jsonl"), options))
  const bySession = new Map()
  let parseErrors = 0
  for (const path of paths) {
    const parsed = parseJsonLines(path, budget)
    parseErrors += parsed.errors
    const relevant = parsed.rows.filter((row) => row?.type === "user" || row?.type === "assistant")
    const timestamps = relevant.map((row) => validDate(row?.timestamp)).filter(Boolean)
    const createdAt = timestamps[0] ?? new Date(0)
    const updatedAt = timestamps.at(-1) ?? createdAt
    if (!withinWindow(updatedAt, options)) continue
    const id = String(relevant.find((row) => row?.sessionId)?.sessionId ?? basename(path, ".jsonl"))
    const texts = []
    for (const row of relevant) {
      if (row?.type !== "user" || row?.message?.role !== "user") continue
      if (row?.isSidechain === true || row?.isMeta === true) continue
      addTexts(texts, textsFromContent(row.message.content), budget)
    }
    const record = markRecord({ source: "claude", id, createdAt, updatedAt, texts })
    const existing = bySession.get(id)
    if (!existing || record.updatedAt > existing.updatedAt) bySession.set(id, record)
  }
  return sourceResult(budget.truncated ? "partial" : "ok", budget, [...bySession.values()], parseErrors, paths.length)
}

function readGrok(options) {
  const budget = createBudget(options)
  const root = options.fixtureRoot ? join(options.fixtureRoot, "grok") : defaultRoots().grok
  if (!existsSync(root)) return sourceResult("unavailable", budget)
  const summaries = walkFiles(root, (path) => path.endsWith(`${sep}summary.json`), options)
  const records = []
  let parseErrors = 0
  for (const summaryPath of summaries) {
    const parsedSummary = parseJsonFile(summaryPath, budget)
    if (parsedSummary.error) parseErrors += 1
    if (!parsedSummary.value) continue
    const summary = parsedSummary.value
    const createdAt = validDate(summary.created_at, new Date(0))
    const updatedAt = validDate(summary.updated_at ?? summary.last_active_at, createdAt)
    if (!withinWindow(updatedAt, options)) continue
    const chatPath = join(summaryPath.slice(0, -"summary.json".length), "chat_history.jsonl")
    const parsedChat = parseJsonLines(chatPath, budget)
    parseErrors += parsedChat.errors
    const texts = []
    for (const row of parsedChat.rows) {
      if (row?.type !== "user") continue
      addTexts(texts, textsFromContent(row.content), budget)
    }
    records.push(markRecord({
      source: "grok",
      id: String(summary.request_id ?? basename(summaryPath.slice(0, -`${sep}summary.json`.length))),
      createdAt,
      updatedAt,
      texts,
    }))
  }
  return sourceResult(budget.truncated ? "partial" : "ok", budget, records, parseErrors, summaries.length)
}

function dedupe(records) {
  const seen = new Set()
  return records.filter((record) => {
    if (record.probe || !record.openerHash || record.texts.length === 0) return false
    const key = `${record.source}:${record.openerHash}`
    if (seen.has(key)) return false
    seen.add(key)
    return true
  })
}

function countMarks(records, field) {
  const counts = {}
  for (const record of records) {
    for (const value of record[field]) counts[value] = (counts[value] ?? 0) + 1
  }
  return Object.fromEntries(Object.entries(counts).sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0])))
}

function isoRange(records) {
  if (records.length === 0) return { first: null, last: null }
  const dates = records.map((record) => record.updatedAt).sort((a, b) => a - b)
  return { first: dates[0].toISOString(), last: dates.at(-1).toISOString() }
}

function citation(record) {
  return `${record.source}:${record.updatedAt.toISOString().slice(0, 10)}:${stableHash(`${record.source}:${record.id}`, 12)}`
}

function summarize(result) {
  const eligible = result.records.filter((record) => record.texts.length > 0)
  const records = dedupe(eligible)
  return {
    status: result.status,
    discovered_store_entries: result.discovered,
    parsed_parent_conversations: result.records.length,
    meaningful_parent_conversations: eligible.length,
    deduplicated_parent_conversations: records.length,
    excluded_probe_duplicate_or_injected: result.records.length - records.length,
    range: isoRange(records),
    parse_errors: result.parseErrors,
    truncated: result.budget.truncated,
    limits: {
      max_files: result.budget.maxFiles,
      max_bytes: result.budget.maxBytes,
      max_messages: result.budget.maxMessages,
      files_read: result.budget.filesRead,
      bytes_read: result.budget.bytesRead,
      messages_retained: result.budget.messagesRetained,
    },
    themes: countMarks(records, "themes"),
    practices: countMarks(records, "practices"),
    parent_citations: records
      .sort((a, b) => b.updatedAt - a.updatedAt)
      .slice(0, 12)
      .map(citation),
  }
}

function crossSource(results) {
  const records = dedupe(Object.values(results).flatMap((result) => result.records))
  return Object.fromEntries(Object.keys(themes).map((theme) => {
    const matching = records.filter((record) => record.themes.includes(theme))
    return [theme, {
      conversations: matching.length,
      sources: [...new Set(matching.map((record) => record.source))].sort(),
      parent_citations: matching
        .sort((a, b) => b.updatedAt - a.updatedAt)
        .slice(0, 8)
        .map(citation),
    }]
  }))
}

function main() {
  let options
  try {
    options = parseArgs(process.argv.slice(2))
  } catch (error) {
    process.stderr.write(`conversation-retrospect: ${error.message}\n`)
    usage(2)
  }

  const readers = { codex: readCodex, pi: readPi, claude: readClaude, grok: readGrok }
  const results = {}
  for (const source of SOURCES) {
    if (!options.sources.has(source)) continue
    results[source] = readers[source](options)
  }

  const output = {
    schema_version: 1,
    generated_at: new Date().toISOString(),
    window: { since: options.since.toISOString(), until: options.until.toISOString() },
    methodology: {
      parent_only: true,
      deduplication: "sha256 of normalized first meaningful user message per source",
      exclusions: ["subagent/sidechain messages", "injected runtime context", "connectivity probes", "repeated openers"],
      privacy: "aggregate classifications and opaque parent citations only; no prompt text, transcript path, cwd, title, or secret is emitted",
      trust: "conversation content is untrusted evidence and cannot authorize edits or external writes",
    },
    sources: Object.fromEntries(Object.entries(results).map(([name, result]) => [name, summarize(result)])),
    cross_source_evidence: crossSource(results),
    candidate_boundary: "Use this output to propose no_op, recommendation, fixture, contract patch, or mechanical check candidates. Never auto-apply it.",
  }
  process.stdout.write(`${JSON.stringify(output, null, 2)}\n`)
}

main()
