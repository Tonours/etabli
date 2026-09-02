// token-battery: mine Claude Code transcript usage telemetry per session.
// Usage: node token-battery.mjs [--projects <dir>] [--match <substr>] [--since <YYYY-MM-DD>] [--json]
// Only type:"assistant" entries carrying message.usage count as turns.
// thinking_tokens is a subset of output_tokens, reported separately, never added.
// --since filters per-entry timestamps; entries without a timestamp are kept.
// Unreadable session files are skipped with a warning, never fatal.
import { createReadStream, readdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { createInterface } from "node:readline";
import { parseArgs } from "node:util";

const { values } = parseArgs({
  options: {
    projects: { type: "string", default: join(homedir(), ".claude", "projects") },
    match: { type: "string", default: "" },
    since: { type: "string" },
    json: { type: "boolean", default: false },
    help: { type: "boolean", default: false },
  },
});

if (values.help) {
  process.stdout.write(
    "token-battery [--projects <dir>] [--match <substr>] [--since <YYYY-MM-DD>] [--json]\n",
  );
  process.exit(0);
}

let sinceMs = 0;
if (values.since !== undefined) {
  sinceMs = Date.parse(`${values.since}T00:00:00Z`);
  if (Number.isNaN(sinceMs)) {
    process.stderr.write(`invalid --since date: ${values.since}\n`);
    process.exit(2);
  }
}

function num(value) {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function modelKey(entry) {
  const model = entry.model ?? entry.message?.model;
  return typeof model === "string" && model !== "" ? model : "unknown";
}

async function sessionUsage(path) {
  const row = {
    session: path,
    turns: 0,
    input: 0,
    output: 0,
    thinking: 0,
    cacheRead: 0,
    cacheCreate: 0,
    models: Object.create(null),
  };
  const lines = createInterface({ input: createReadStream(path), crlfDelay: Infinity });
  for await (const line of lines) {
    if (!line.trim()) continue;
    let entry;
    try {
      entry = JSON.parse(line);
    } catch {
      continue;
    }
    if (typeof entry !== "object" || entry === null || entry.type !== "assistant")
      continue;
    const usage = entry.message?.usage;
    if (typeof usage !== "object" || usage === null || Array.isArray(usage))
      continue;
    if (sinceMs) {
      const ts = typeof entry.timestamp === "string" ? Date.parse(entry.timestamp) : NaN;
      if (!Number.isNaN(ts) && ts < sinceMs) continue;
    }
    row.turns += 1;
    row.input += num(usage.input_tokens);
    row.output += num(usage.output_tokens);
    row.thinking += num(usage.output_tokens_details?.thinking_tokens);
    row.cacheRead += num(usage.cache_read_input_tokens);
    row.cacheCreate += num(usage.cache_creation_input_tokens);
    const key = modelKey(entry);
    row.models[key] = (row.models[key] ?? 0) + 1;
  }
  return row;
}

const total = {
  turns: 0,
  input: 0,
  output: 0,
  thinking: 0,
  cacheRead: 0,
  cacheCreate: 0,
};
const rows = [];
let dirs;
try {
  dirs = readdirSync(values.projects, { withFileTypes: true });
} catch (error) {
  process.stderr.write(
    `cannot read projects dir ${values.projects}: ${error.code ?? error.message}\n`,
  );
  process.exit(2);
}
for (const dir of dirs) {
  if (!dir.isDirectory() || !dir.name.includes(values.match)) continue;
  for (const file of readdirSync(join(values.projects, dir.name))) {
    if (!file.endsWith(".jsonl")) continue;
    const path = join(values.projects, dir.name, file);
    let row;
    try {
      row = await sessionUsage(path);
    } catch (error) {
      process.stderr.write(`skip ${path}: ${error.code ?? error.message}\n`);
      continue;
    }
    if (row.turns === 0) continue;
    row.project = dir.name;
    rows.push(row);
    for (const key of Object.keys(total)) total[key] += row[key];
  }
}

rows.sort((a, b) => a.session.localeCompare(b.session));

if (values.json) {
  process.stdout.write(`${JSON.stringify({ sessions: rows, total }, null, 2)}\n`);
} else {
  process.stdout.write("session\tturns\tinput\toutput\tthink\tcacheRd\tcacheMk\n");
  for (const r of rows) {
    const short = r.session.slice(-44);
    process.stdout.write(
      `${short}\t${r.turns}\t${r.input}\t${r.output}\t${r.thinking}\t${r.cacheRead}\t${r.cacheCreate}\n`,
    );
  }
  process.stdout.write(
    `TOTAL\t${total.turns}\t${total.input}\t${total.output}\t${total.thinking}\t${total.cacheRead}\t${total.cacheCreate}\n`,
  );
}
