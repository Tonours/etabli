import { constants } from "node:fs";
import { open, lstat, mkdir, readdir, rename, unlink } from "node:fs/promises";
import { join, dirname, resolve } from "node:path";
import { homedir } from "node:os";
import { request } from "node:http";
import { execFile, spawn } from "node:child_process";
import { promisify } from "node:util";
import { randomUUID } from "node:crypto";

const statuses = ["queued", "planning", "implementing", "reviewing", "publishing", "done", "blocked", "aborted"] as const;
const reasons = ["published", "review_block_limit", "review_unavailable_or_invalid", "ci_attempts_exhausted", "wall_clock_limit", "run_setup_failed", "aborted", "user_abort", "unanswered", "other"] as const;
const servers = ["alambic-obvault", "chrome-devtools"] as const;
type Health = "ok" | "degraded" | "unavailable";
type Counts = Record<string, number>;
export type RecordDay = {
  version: 1; day: string; timestamp: number;
  service: { health: Health; restarts: number; invocation: string };
  runs: { health: Health; error: "none" | "oversize" | "unavailable"; counts: Counts; blocked: Counts; stale: number; waiting: number; bytes: number };
  backup: { health: Health; newest: number };
  mcp: Record<typeof servers[number], "ready" | "skipped" | "unavailable">;
  chromePackage: Health;
};
const countMap = (keys: readonly string[]) => Object.fromEntries(keys.map(key => [key, 0]));
const number = (value: unknown): value is number => typeof value === "number" && Number.isSafeInteger(value) && value >= 0;
const health = (value: unknown): value is Health => ["ok", "degraded", "unavailable"].includes(String(value));
const object = (value: unknown): value is Record<string, unknown> => !!value && typeof value === "object" && !Array.isArray(value);
export function parisDay(now: number): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Paris", year: "numeric", month: "2-digit", day: "2-digit" }).format(now);
}
export function summarizeRuns(raw: unknown, now: number, bytes: number): RecordDay["runs"] {
  if (!object(raw) || raw.ok !== true || !Array.isArray(raw.value) || raw.value.length > 10000) throw new Error("Invalid run response");
  const counts = countMap(statuses), blocked = countMap(reasons);
  let stale = 0, waiting = 0;
  const ids = new Set<string>();
  for (const row of raw.value) {
    if (!object(row) || typeof row.id !== "string" || !/^[a-f0-9]{8}-(?:[a-f0-9]{4}-){3}[a-f0-9]{12}$/.test(row.id) || ids.has(row.id) || !statuses.includes(row.status as typeof statuses[number]) || !number(row.createdAt) || !number(row.deadline)) throw new Error("Invalid run row");
    ids.add(row.id as string);
    const status = row.status as string;
    counts[status]++;
    if (status === "blocked") blocked[reasons.includes(row.reason as typeof reasons[number]) ? row.reason as string : "other"]++;
    if (status === "queued" && now - row.createdAt > 3_600_000) waiting++;
    if (!["queued", "done", "blocked", "aborted"].includes(status) && row.deadline > 0 && row.deadline < now) stale++;
  }
  return { health: stale || waiting ? "degraded" : "ok", error: "none", counts, blocked, stale, waiting, bytes };
}
export function mcpStates(journal: string): RecordDay["mcp"] {
  const result: RecordDay["mcp"] = { "alambic-obvault": "unavailable", "chrome-devtools": "unavailable" };
  for (const line of journal.split("\n")) {
    const match = /^MCP (alambic-obvault|chrome-devtools): (ready|skipped)$/.exec(line);
    if (match && result[match[1] as typeof servers[number]] === "unavailable") result[match[1] as typeof servers[number]] = match[2] as "ready" | "skipped";
  }
  return result;
}
export function parseRecord(raw: unknown): RecordDay {
  if (!object(raw) || raw.version !== 1 || !number(raw.timestamp) || raw.day !== parisDay(raw.timestamp) || !object(raw.service) || !object(raw.runs) || !object(raw.backup) || !object(raw.mcp)) throw new Error("Invalid record");
  const s = raw.service, r = raw.runs, b = raw.backup;
  if (!health(s.health) || !number(s.restarts) || typeof s.invocation !== "string" || !/^(?:[a-f0-9]{32})?$/.test(s.invocation) || !health(r.health) || !["none", "oversize", "unavailable"].includes(String(r.error)) || !health(b.health) || !number(b.newest) || !health(raw.chromePackage)) throw new Error("Invalid record");
  for (const [map, keys] of [[r.counts, statuses], [r.blocked, reasons]] as const) {
    if (!object(map) || Object.keys(map).length !== keys.length || keys.some(key => !number(map[key]))) throw new Error("Invalid counts");
  }
  if (![r.stale, r.waiting, r.bytes].every(number) || servers.some(key => !["ready", "skipped", "unavailable"].includes(String((raw.mcp as Record<string, unknown>)[key])))) throw new Error("Invalid record");
  const clean = { version: 1, day: raw.day, timestamp: raw.timestamp, service: s, runs: r, backup: b, mcp: raw.mcp, chromePackage: raw.chromePackage } as RecordDay;
  if (Object.keys(raw).length !== 8 || Object.keys(s).length !== 3 || Object.keys(r).length !== 7 || Object.keys(b).length !== 2 || Object.keys(raw.mcp).length !== 2) throw new Error("Unexpected fields");
  return clean;
}
export function render(current: RecordDay, previous: RecordDay[], warnings: string[]): string {
  const lines = [`# Durable daily report — ${current.day}`, `Collected: ${new Date(current.timestamp).toISOString()}`, "", "Operational analysis only; no automatic changes or device-delivery claim.", "Inactivity does not establish code quality.", "", `Service: ${current.service.health}; restart counter: ${current.service.health === "unavailable" ? "unavailable" : current.service.restarts}.`, `Run API: ${current.runs.health} (${current.runs.error}); ${current.runs.health === "unavailable" ? "unavailable bytes" : `${current.runs.bytes} bytes`}.`, `Run counts: ${current.runs.health === "unavailable" ? "unavailable" : statuses.map(key => `${key}=${current.runs.counts[key]}`).join(", ")}.`, `Backup: ${current.backup.health}; newest: ${current.backup.newest ? new Date(current.backup.newest).toISOString() : "unknown"}.`, `MCP: ${servers.map(key => `${key}=${current.mcp[key]}`).join(", ")}.`, `Chrome package pin: ${current.chromePackage}.`, "", "## Improvement proposals"];
  const proposals: string[] = [];
  if (current.service.health !== "ok") proposals.push("Inspect the daemon service state; monitoring does not restart it.");
  const days = previous.filter(row => row.day < current.day).sort((a, b) => b.day.localeCompare(a.day)).slice(0, 29);
  const prior = days[0];
  if (!prior) proposals.push("Baseline only: no previous valid daily sample to compare.");
  else if (prior.service.health !== "unavailable" && current.service.health !== "unavailable" && prior.service.invocation && current.service.invocation) {
    if (current.service.restarts > prior.service.restarts) proposals.push(`Investigate ${current.service.restarts - prior.service.restarts} additional automatic restarts since the last sample.`);
    else if (prior.service.invocation !== current.service.invocation || current.service.restarts < prior.service.restarts) proposals.push("Service invocation/counter changed; treat this as a restart/reset, not an improvement.");
  }
  const observed = [...days, current].filter(row => row.runs.health !== "unavailable");
  for (const key of ["stale", "waiting"] as const) {
    const count = observed.filter(row => row.runs[key] > 0).length;
    if (count > 1) proposals.push(`${key} runs observed in ${count} of ${observed.length} samples; repeated aggregate observations do not prove the same run persisted.`);
  }
  for (const key of reasons) {
    const count = observed.filter(row => row.runs.blocked[key] > 0).length;
    if (count > 1) proposals.push(`Blocked reason ${key} present in ${count} of ${observed.length} samples; these are not counts of new failures.`);
  }
  if (current.runs.error === "oversize") proposals.push("Run listing exceeds the monitoring bound; propose a paginated or aggregate metrics API before increasing collection.");
  else if (current.runs.health === "unavailable") proposals.push("Restore or inspect Unix API observability; missing data is not a healthy run history.");
  if (current.runs.health !== "unavailable" && current.runs.stale) proposals.push(`Inspect ${current.runs.stale} active runs past their deadline.`);
  if (current.runs.health !== "unavailable" && current.runs.waiting) proposals.push(`Inspect ${current.runs.waiting} runs queued longer than one hour.`);
  for (const key of reasons) if (current.runs.health !== "unavailable" && current.runs.blocked[key]) {
    const delta = prior?.runs.health !== "unavailable" && prior ? current.runs.blocked[key] - prior.runs.blocked[key] : undefined;
    proposals.push(`Blocked reason ${key}: ${current.runs.blocked[key]} stored runs${delta === undefined ? "; baseline" : `; change ${delta} since prior sample`}. Review causes before proposing a fix; repeated samples of the same runs are not new failures.`);
  }
  if (current.backup.health !== "ok") proposals.push("Inspect backup timer and storage; no valid backup within 36 hours was proven.");
  for (const key of servers) if (current.mcp[key] !== "ready") proposals.push(`Inspect ${key} startup: ${current.mcp[key]}; journal absence does not prove failure or readiness.`);
  if (current.chromePackage !== "ok") proposals.push("Restore the owned chrome-devtools-mcp 1.7.0 installation; monitoring never installs packages.");
  if (!proposals.length) proposals.push("No operational improvement indicated by this sample. Inactivity does not establish code quality.");
  lines.push(...proposals.map(value => `- ${value}`));
  if (warnings.length) lines.push("", "## Evidence limitations", ...warnings.map(value => `- ${value}`));
  return lines.join("\n") + "\n";
}
export async function privateDirectory(path: string): Promise<void> {
  for (let current = resolve(path); ; current = dirname(current)) {
    const st = await lstat(current).catch((e: NodeJS.ErrnoException) => { if (e.code !== "ENOENT") throw e; });
    if (st?.isSymbolicLink()) throw new Error("Symlinked monitor directory");
    if (dirname(current) === current) break;
  }
  await mkdir(path, { recursive: true, mode: 0o700 });
  const st = await lstat(path);
  if (!st.isDirectory() || st.isSymbolicLink() || st.uid !== process.getuid?.() || (st.mode & 0o077)) throw new Error("Unsafe monitor directory");
}
async function readPrivate(path: string, limit = 65536): Promise<string> {
  const file = await open(path, constants.O_RDONLY | constants.O_NOFOLLOW);
  try {
    const st = await file.stat();
    if (!st.isFile() || st.uid !== process.getuid?.() || (st.mode & 0o077) || st.size > limit) throw new Error("Unsafe report");
    const buffer = Buffer.alloc(limit + 1); const { bytesRead } = await file.read(buffer, 0, buffer.length, 0);
    if (bytesRead > limit) throw new Error("Oversize report");
    return buffer.subarray(0, bytesRead).toString();
  } finally { await file.close(); }
}
async function atomic(path: string, data: string): Promise<void> {
  const old = await lstat(path).catch((e: NodeJS.ErrnoException) => { if (e.code !== "ENOENT") throw e; });
  if (old && (!old.isFile() || old.isSymbolicLink() || old.uid !== process.getuid?.() || (old.mode & 0o077))) throw new Error("Unsafe report target");
  const temporary = join(dirname(path), `.monitor-${randomUUID()}.tmp`);
  const file = await open(temporary, "wx", 0o600);
  try { await file.writeFile(data); await file.sync(); await file.close(); await rename(temporary, path); }
  finally { await file.close(); await unlink(temporary).catch((e: NodeJS.ErrnoException) => { if (e.code !== "ENOENT") throw e; }); }
}
export async function history(directory: string): Promise<{ records: RecordDay[]; warnings: string[] }> {
  await privateDirectory(directory); const records: RecordDay[] = [], warnings: string[] = [];
  const files = await readdir(directory); if (files.length > 128) throw new Error("Monitor directory exceeds bound");
  for (const name of files.filter(name => /^\d{4}-\d{2}-\d{2}\.json$/.test(name)).sort().slice(-30)) {
    try { const row = parseRecord(JSON.parse(await readPrivate(join(directory, name)))); if (`${row.day}.json` !== name) throw new Error("Day mismatch"); records.push(row); }
    catch { warnings.push(`Excluded invalid record: ${name}`); }
  }
  return { records, warnings };
}
export async function writeReport(directory: string, row: RecordDay): Promise<boolean> {
  parseRecord(row); await privateDirectory(directory);
  await readPrivate(join(directory, "memory.md")).catch((e: NodeJS.ErrnoException) => { if (e.code !== "ENOENT") throw e; });
  const recordsDir = join(directory, "records"); const prior = await history(recordsDir);
  const markdown = render(row, prior.records, prior.warnings);
  await atomic(join(recordsDir, `${row.day}.json`), JSON.stringify(row, null, 2) + "\n");
  await atomic(join(directory, "latest.md"), markdown);
  await atomic(join(directory, "memory.md"), markdown);
  const names = (await readdir(recordsDir)).filter(name => /^\d{4}-\d{2}-\d{2}\.json$/.test(name)).sort();
  for (const name of names.slice(0, -30)) { const file = join(recordsDir, name); const st = await lstat(file); if (!st.isFile() || st.isSymbolicLink() || st.uid !== process.getuid?.()) throw new Error("Unsafe retained record"); await unlink(file); }
  const previous = prior.records.filter(item => item.day < row.day).sort((a, b) => b.day.localeCompare(a.day))[0];
  return row.runs.health !== "unavailable" && previous !== undefined && previous.runs.health !== "unavailable" && reasons.some(key => row.runs.blocked[key] > previous.runs.blocked[key]);
}
export async function runCommand(command: string, args: string[]): Promise<string> {
  return (await promisify(execFile)(command, args, { timeout: 5000, killSignal: "SIGKILL", maxBuffer: 65536, encoding: "utf8" })).stdout;
}
export function readRuns(socketPath: string, timeout = 5000, limit = 2 * 1024 * 1024): Promise<{ body: unknown; bytes: number }> {
  return new Promise((resolve, reject) => {
    let bytes = 0; const chunks: Buffer[] = [];
    const req = request({ socketPath, method: "GET", path: "/v1/runs", agent: false }, response => {
      response.on("data", (chunk: Buffer) => { bytes += chunk.length; if (bytes > limit) { reject(new Error("oversize")); req.destroy(); } else chunks.push(chunk); });
      response.on("error", reject);
      response.on("end", () => { try { if (response.statusCode !== 200) throw new Error("Unavailable API"); resolve({ body: JSON.parse(Buffer.concat(chunks).toString()), bytes }); } catch (error) { reject(error); } });
    });
    const timer = setTimeout(() => req.destroy(new Error("timeout")), timeout);
    req.once("close", () => clearTimeout(timer)); req.once("error", reject); req.end();
  });
}
export async function collect(state: string, packageRoot: string, now = Date.now()): Promise<RecordDay> {
  const row: RecordDay = { version: 1, day: parisDay(now), timestamp: now, service: { health: "unavailable", restarts: 0, invocation: "" }, runs: { health: "unavailable", error: "unavailable", counts: countMap(statuses), blocked: countMap(reasons), stale: 0, waiting: 0, bytes: 0 }, backup: { health: "unavailable", newest: 0 }, mcp: { "alambic-obvault": "unavailable", "chrome-devtools": "unavailable" }, chromePackage: "unavailable" };
  try {
    const properties = Object.fromEntries((await runCommand("systemctl", ["--user", "show", "etabli-durable.service", "-p", "InvocationID,ActiveState,SubState,NRestarts"])).trim().split("\n").map(line => { const index = line.indexOf("="); return [line.slice(0, index), line.slice(index + 1)]; }));
    if (!/^\d+$/.test(properties.NRestarts ?? "") || !number(Number(properties.NRestarts))) throw new Error("Invalid service result");
    row.service = { health: properties.ActiveState === "active" && properties.SubState === "running" ? "ok" : "degraded", restarts: Number(properties.NRestarts), invocation: /^[a-f0-9]{32}$/.test(properties.InvocationID ?? "") ? properties.InvocationID : "" };
    if (row.service.invocation) row.mcp = mcpStates(await runCommand("journalctl", ["--user", `_SYSTEMD_INVOCATION_ID=${row.service.invocation}`, "--grep", "^MCP (alambic-obvault|chrome-devtools): (ready|skipped)$", "-o", "cat", "--no-pager"]));
  } catch {}
  try { const value = await readRuns(join(state, "daemon.sock")); row.runs = summarizeRuns(value.body, now, value.bytes); } catch (e) { if (e instanceof Error && e.message === "oversize") row.runs.error = "oversize"; }
  try {
    const files = await readdir(join(state, "backups")); if (files.length > 64) throw new Error("Oversize backup directory");
    for (const name of files.filter(name => /^store-\d{8}T\d{9}Z\.sqlite$/.test(name))) { const st = await lstat(join(state, "backups", name)); if (st.isFile() && !st.isSymbolicLink() && st.size > 0 && st.mtimeMs <= now) row.backup.newest = Math.max(row.backup.newest, Math.floor(st.mtimeMs)); }
    row.backup.health = row.backup.newest && now - row.backup.newest <= 36 * 3_600_000 ? "ok" : "degraded";
  } catch { row.backup = { health: "unavailable", newest: 0 }; }
  try {
    const file = await open(join(packageRoot, "package.json"), constants.O_RDONLY | constants.O_NOFOLLOW);
    try { if ((await file.stat()).size > 65536) throw new Error("Large package"); const info: unknown = JSON.parse(await file.readFile("utf8")); if (!object(info) || typeof info.version !== "string") throw new Error("Invalid package"); row.chromePackage = info.version === "1.7.0" ? "ok" : "degraded"; } finally { await file.close(); }
    if (!(await lstat(join(packageRoot, "build/src/bin/chrome-devtools-mcp.js"))).isFile()) row.chromePackage = "degraded";
  } catch (error) { row.chromePackage = (error as NodeJS.ErrnoException).code === "ENOENT" ? "degraded" : "unavailable"; }
  return row;
}
async function main(): Promise<void> {
  const base = join(homedir(), ".local/state/etabli-durable-monitor");
  await privateDirectory(base);
  if (process.argv[2] !== "--locked") {
    const file = await open(join(base, "monitor.lock"), constants.O_CREAT | constants.O_RDWR | constants.O_NOFOLLOW, 0o600);
    try {
      const st = await file.stat(); if (!st.isFile() || st.uid !== process.getuid?.() || (st.mode & 0o077)) throw new Error("Unsafe monitor lock");
      const code = await new Promise<number>((resolve, reject) => { const child = spawn("flock", ["--nonblock", "--conflict-exit-code", "75", "--no-fork", "/proc/self/fd/3", process.execPath, resolvePath(), "--locked"], { stdio: ["ignore", "inherit", "inherit", file.fd] }); child.once("error", reject); child.once("exit", code => resolve(code ?? 1)); });
      process.exitCode = code;
    } finally { await file.close(); }
    return;
  }
  await readPrivate(join(base, "memory.md")).catch((e: NodeJS.ErrnoException) => { if (e.code !== "ENOENT") throw e; });
  const row = await collect(join(homedir(), ".local/state/etabli-durable"), join(homedir(), ".local/share/etabli-durable/mcp/node_modules/chrome-devtools-mcp"));
  const newBlocked = await writeReport(base, row);
  const healthy = !newBlocked && row.service.health === "ok" && row.runs.health === "ok" && row.backup.health === "ok" && row.chromePackage === "ok" && servers.every(key => row.mcp[key] === "ready");
  console.log(`Durable monitor ${healthy ? "healthy" : "needs-attention"}: ${join(base, "latest.md")}`);
}
function resolvePath(): string { return resolve(import.meta.filename); }
if (import.meta.main) void main().catch(() => { console.error("Durable monitor failed; inspect private directory permissions and unit state"); process.exitCode = 1; });
