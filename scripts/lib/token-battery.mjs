// token-battery: mine Claude Code transcript usage telemetry per session.
// Usage: node token-battery.mjs [--projects <dir>] [--match <substr>] [--since <YYYY-MM-DD>] [--json]
// Reads ~/.claude/projects by default. Every assistant message carrying
// message.usage contributes one turn. Output: one JSON row per session file.
import { readdirSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

function arg(name, fallback) {
  const i = process.argv.indexOf(name);
  return i !== -1 && i + 1 < process.argv.length ? process.argv[i + 1] : fallback;
}

const projectsRoot = arg("--projects", join(homedir(), ".claude", "projects"));
const match = arg("--match", "");
const since = arg("--since", "");
const asJson = process.argv.includes("--json");
const sinceMs = since ? Date.parse(`${since}T00:00:00Z`) : 0;

function num(value) {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function sessionUsage(path) {
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
  for (const line of readFileSync(path, "utf8").split("\n")) {
    if (!line.trim()) continue;
    let entry;
    try {
      entry = JSON.parse(line);
    } catch {
      continue;
    }
    if (typeof entry !== "object" || entry === null) continue;
    const usage = entry.message?.usage;
    if (typeof usage !== "object" || usage === null || Array.isArray(usage))
      continue;
    row.turns += 1;
    row.input += num(usage.input_tokens);
    row.output += num(usage.output_tokens);
    row.thinking += num(usage.output_tokens_details?.thinking_tokens);
    row.cacheRead += num(usage.cache_read_input_tokens);
    row.cacheCreate += num(usage.cache_creation_input_tokens);
    const model = entry.model ?? entry.message?.model ?? "unknown";
    row.models[model] = (row.models[model] ?? 0) + 1;
  }
  return row;
}

const rows = [];
for (const dir of readdirSync(projectsRoot, { withFileTypes: true })) {
  if (!dir.isDirectory() || !dir.name.includes(match)) continue;
  for (const file of readdirSync(join(projectsRoot, dir.name))) {
    if (!file.endsWith(".jsonl")) continue;
    const path = join(projectsRoot, dir.name, file);
    if (sinceMs && statSync(path).mtimeMs < sinceMs) continue;
    const row = sessionUsage(path);
    if (row.turns === 0) continue;
    row.project = dir.name;
    rows.push(row);
  }
}

rows.sort((a, b) => a.session.localeCompare(b.session));

if (asJson) {
  process.stdout.write(`${JSON.stringify(rows, null, 2)}\n`);
} else {
  const head = ["session", "turns", "input", "output", "think", "cacheRd", "cacheMk"];
  process.stdout.write(`${head.join("\t")}\n`);
  for (const r of rows) {
    const short = r.session.split("/").slice(-2).join("/").slice(0, 44);
    process.stdout.write(
      `${short}\t${r.turns}\t${r.input}\t${r.output}\t${r.thinking}\t${r.cacheRead}\t${r.cacheCreate}\n`,
    );
  }
  const sum = (k) => rows.reduce((a, r) => a + r[k], 0);
  process.stdout.write(
    `TOTAL\t${sum("turns")}\t${sum("input")}\t${sum("output")}\t${sum("thinking")}\t${sum("cacheRead")}\t${sum("cacheCreate")}\n`,
  );
}
