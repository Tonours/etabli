import { test, expect } from "bun:test";
import { mkdtemp, mkdir, writeFile, readFile, rm, readdir, lstat, symlink, open } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createServer } from "node:http";
import { spawn, execFile } from "node:child_process";
import { promisify } from "node:util";
import { parisDay, summarizeRuns, mcpStates, parseRecord, render, privateDirectory, history, writeReport, readRuns, collect, type RecordDay } from "../src/monitor.ts";

const now = Date.parse("2026-11-16T12:00:00Z");
function sample(time = now): RecordDay {
  return { version: 1, day: parisDay(time), timestamp: time, service: { health: "ok", restarts: 0, invocation: "a".repeat(32) }, runs: summarizeRuns({ ok: true, value: [] }, time, 22), backup: { health: "ok", newest: time - 8 * 3600000 }, mcp: { "alambic-obvault": "ready", "chrome-devtools": "ready" }, chromePackage: "ok" };
}
async function temporary() { const root = await mkdtemp(join(tmpdir(), "etabli-monitor-")); return { root, cleanup: () => rm(root, { recursive: true, force: true }) }; }

test("Paris keys are independent of UTC midnight and both DST transitions", () => {
  expect(parisDay(Date.parse("2026-01-01T23:30:00Z"))).toBe("2026-01-02");
  for (const date of ["2026-03-29T00:30:00Z", "2026-03-29T01:30:00Z"]) expect(parisDay(Date.parse(date))).toBe("2026-03-29");
  for (const date of ["2026-10-25T00:30:00Z", "2026-10-25T01:30:00Z"]) expect(parisDay(Date.parse(date))).toBe("2026-10-25");
});
test("analysis admits only aggregate fields and never copies hostile content or counts persisted failures twice", () => {
  const marker = "secret-UNTRUSTED";
  const result = summarizeRuns({ ok: true, value: [{ id: "00000000-0000-0000-0000-000000000001", status: "blocked", reason: marker, prompt: marker, deadline: 0, createdAt: now }, { id: "00000000-0000-0000-0000-000000000002", status: "queued", deadline: 0, createdAt: now - 7200000 }, { id: "00000000-0000-0000-0000-000000000003", status: "implementing", deadline: now - 1, createdAt: now - 10 }] }, now, 128);
  expect(result.blocked.other).toBe(1); expect(result.waiting).toBe(1); expect(result.stale).toBe(1);
  const row = { ...sample(), runs: result }; const prev = { ...row, timestamp: now - 86400000, day: parisDay(now - 86400000) };
  const report = render(row, [prev], []); expect(report).not.toContain(marker); expect(report).toContain("change 0"); expect(report).toContain("not new failures");
  expect(() => summarizeRuns({ ok: true, value: [{ status: marker }] }, now, 2)).toThrow();
  expect(() => parseRecord({ ...row, rawSecret: marker })).toThrow();
  expect(() => parseRecord({ ...row, service: { ...row.service, secret: marker } })).toThrow();
});
test("missing startup evidence stays unavailable and reset counters never claim improvement", () => {
  expect(mcpStates("arbitrary token\nMCP chrome-devtools: ready suffix")["chrome-devtools"]).toBe("unavailable");
  expect(mcpStates("MCP chrome-devtools: skipped\nMCP chrome-devtools: ready")["chrome-devtools"]).toBe("skipped");
  const row = sample(), previous = sample(now - 86400000); previous.service.restarts = 5;
  expect(render(row, [previous], [])).toContain("restart/reset");
  row.mcp = mcpStates(""); expect(render(row, [], [])).toContain("absence does not prove");
});
test("private history atomically replaces same-day records, caps30 and excludes corrupt state", async () => {
  const f = await temporary();
  try {
    for (let n = 0; n < 32; n++) await writeReport(f.root, sample(now + n * 86400000));
    expect((await readdir(join(f.root, "records"))).length).toBe(30);
    await writeReport(f.root, sample(now + 31 * 86400000)); expect((await history(join(f.root, "records"))).records.length).toBe(30);
    expect((await lstat(join(f.root, "latest.md"))).mode & 0o777).toBe(0o600);
    const corrupt = join(f.root, "records", parisDay(now + 30 * 86400000) + ".json"); await writeFile(corrupt, "not-json-secret");
    const h = await history(join(f.root, "records")); expect(h.warnings).toHaveLength(1); expect(h.records).toHaveLength(29);
    await writeReport(f.root, sample(now + 31 * 86400000)); expect(await readFile(join(f.root, "latest.md"), "utf8")).not.toContain("not-json-secret");
    await writeFile(join(f.root, "records", ".monitor-interrupted.tmp"), "never authoritative", { mode: 0o600 });
    expect((await history(join(f.root, "records"))).records).toHaveLength(29);
  } finally { await f.cleanup(); }
});
test("unsafe targets and directory symlinks refuse writes and preserve previous records", async () => {
  const f = await temporary();
  try {
    await writeReport(f.root, sample()); const record = join(f.root, "records", sample().day + ".json"); const old = await readFile(record, "utf8");
    await rm(join(f.root, "memory.md")); await symlink(record, join(f.root, "memory.md"));
    await expect(writeReport(f.root, sample())).rejects.toThrow(); expect(await readFile(record, "utf8")).toBe(old);
    await symlink(f.root, join(f.root, "alias")); await expect(privateDirectory(join(f.root, "alias", "nested"))).rejects.toThrow();
  } finally { await f.cleanup(); }
});
test("native Unix collection caps size and timeout without a mutation request", async () => {
  const f = await temporary(); let mode = "ok"; const methods: string[] = [];
  const server = createServer((req, res) => { methods.push(`${req.method} ${req.url}`); if (mode === "hang") return; res.end(mode === "big" ? "x".repeat(400) : JSON.stringify({ ok: true, value: [] })); });
  try {
    await new Promise<void>(r => server.listen(join(f.root, "daemon.sock"), r));
    expect((await readRuns(join(f.root, "daemon.sock"))).bytes).toBeGreaterThan(0);
    mode = "big"; await expect(readRuns(join(f.root, "daemon.sock"), 200, 100)).rejects.toThrow("oversize");
    mode = "hang"; await expect(readRuns(join(f.root, "daemon.sock"), 30)).rejects.toThrow("timeout");
    expect(methods).toEqual(["GET /v1/runs", "GET /v1/runs", "GET /v1/runs"]);
  } finally { server.closeAllConnections(); await new Promise<void>(r => server.close(() => r())); await f.cleanup(); }
});
test("native offline sample reports unavailable without exposing data and flock rejects overlap", async () => {
  const f = await temporary();
  try {
    const row = await collect(f.root, f.root, now); expect(row.runs.health).toBe("unavailable"); expect(row.backup.health).toBe("unavailable"); expect(row.chromePackage).toBe("degraded"); parseRecord(row);
    const base = join(f.root, ".local/state/etabli-durable-monitor"); await mkdir(base, { recursive: true, mode: 0o700 }); const lock = await open(join(base, "monitor.lock"), "w", 0o600);
    const held = spawn("flock", ["--exclusive", "/proc/self/fd/3", "sh", "-c", "printf ready; read ignored"], { stdio: ["pipe", "pipe", "pipe", lock.fd] });
    await new Promise<void>(r => held.stdout!.once("data", () => r()));
    const result = await promisify(execFile)(process.execPath, [resolve(import.meta.dirname, "../src/monitor.ts")], { env: { ...process.env, HOME: f.root } }).then(() => 0, (e: { code: number }) => e.code);
    expect(result).toBe(75); expect(await readdir(base)).toEqual(["monitor.lock"]);
    held.stdin!.end("done\n"); await new Promise<void>(r => held.once("exit", () => r())); await lock.close();
  } finally { await f.cleanup(); }
});
test("Chrome example explicitly disables all upstream telemetry and update paths", async () => {
  const config = JSON.parse(await readFile(resolve(import.meta.dirname, "../config.example.json"), "utf8"));
  const check = (entry: typeof config.mcpServers["chrome-devtools"]) => entry.command === "/usr/bin/node" && ["--isolated", "--headless", "--no-usage-statistics", "--no-performance-crux", "--executablePath=/usr/bin/chromium"].every(flag => entry.args.includes(flag)) && entry.env.CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS === "1" && entry.env.CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS === "1";
  const entry = config.mcpServers["chrome-devtools"]; expect(check(entry)).toBe(true);
  for (const flag of ["--no-usage-statistics", "--no-performance-crux"]) expect(check({ ...entry, args: entry.args.filter((value: string) => value !== flag) })).toBe(false);
  for (const key of Object.keys(entry.env)) expect(check({ ...entry, env: { ...entry.env, [key]: undefined } })).toBe(false);
});

test("native collector distinguishes healthy evidence, stale backup and invalid package without retaining journal content", async () => {
  const f = await temporary(); const oldPath = process.env.PATH;
  const server = createServer((_req, res) => res.end(JSON.stringify({ ok: true, value: [] })));
  try {
    const bin = join(f.root, "bin"); await mkdir(bin);
    await writeFile(join(bin, "systemctl"), '#!/bin/sh\nprintf "ActiveState=active\\nSubState=running\\nNRestarts=0\\nInvocationID=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\\n"\n', { mode: 0o700 });
    await writeFile(join(bin, "journalctl"), '#!/bin/sh\nprintf "secret-raw-journal\\nMCP alambic-obvault: ready\\nMCP chrome-devtools: ready\\n"\n', { mode: 0o700 });
    process.env.PATH = bin + ":" + oldPath;
    await mkdir(join(f.root, "backups")); const backup = join(f.root, "backups", "store-20261116T000000000Z.sqlite"); await writeFile(backup, "fixture");
    const { utimes } = await import("node:fs/promises"); await utimes(backup, now / 1000 - 28800, now / 1000 - 28800);
    const pkg = join(f.root, "package"); await mkdir(join(pkg, "build/src/bin"), { recursive: true }); await writeFile(join(pkg, "package.json"), '{"version":"1.7.0"}'); await writeFile(join(pkg, "build/src/bin/chrome-devtools-mcp.js"), "");
    await new Promise<void>(r => server.listen(join(f.root, "daemon.sock"), r));
    const row = await collect(f.root, pkg, now); expect(row.service.health).toBe("ok"); expect(row.runs.health).toBe("ok"); expect(row.backup.health).toBe("ok"); expect(row.mcp["chrome-devtools"]).toBe("ready"); expect(row.chromePackage).toBe("ok"); expect(JSON.stringify(row)).not.toContain("secret-raw-journal");
    // Model journalctl filtering before its bounded stdout is captured.
    const journal = join(f.root, "journal.txt"), argv = join(f.root, "journal-argv.json");
    await writeFile(journal, "MCP alambic-obvault: ready\nMCP chrome-devtools: ready\n" + "retry noise\n".repeat(7000));
    await writeFile(join(bin, "journalctl"), `#!${process.execPath}
const fs = require("node:fs"); const args = process.argv.slice(2); fs.writeFileSync(${JSON.stringify(argv)}, JSON.stringify(args));
const lines = fs.readFileSync(${JSON.stringify(journal)}, "utf8"); const at = args.indexOf("--grep");
process.stdout.write(at < 0 ? lines : lines.split("\\n").filter(line => new RegExp(args[at + 1]).test(line)).join("\\n"));
`, {mode:0o700});
    const noisy = await collect(f.root, pkg, now); expect(noisy.mcp["chrome-devtools"]).toBe("ready");
    const args = JSON.parse(await readFile(argv, "utf8")); expect(args).toContain("_SYSTEMD_INVOCATION_ID=" + "a".repeat(32)); expect(args).toContain("--grep");
    await utimes(backup, now / 1000 - 37 * 3600, now / 1000 - 37 * 3600); await writeFile(join(pkg, "package.json"), '{"version":"2.0.0"}');
    await writeFile(join(bin, "journalctl"), '#!/bin/sh\nexit 1\n', { mode: 0o700 });
    const partial = await collect(f.root, pkg, now); expect(partial.service.health).toBe("ok"); expect(partial.backup.health).toBe("degraded"); expect(partial.chromePackage).toBe("degraded"); expect(partial.mcp["chrome-devtools"]).toBe("unavailable");
    await writeReport(join(f.root, "report"), partial); expect(await readFile(join(f.root, "report/latest.md"), "utf8")).toContain("unavailable");
  } finally { process.env.PATH = oldPath; server.closeAllConnections(); await new Promise<void>(r => server.close(() => r())); await f.cleanup(); }
});

test("daily trends count distinct observed days, exclude retries and preserve missing evidence", () => {
  const row = sample(), a = sample(now - 86400000), b = sample(now - 2 * 86400000);
  for (const r of [row, a, b]) { r.runs.waiting = 1; r.runs.stale = 1; }
  expect(render(row, [a, b], [])).toContain("3 of 3 samples");
  const retry = sample(); retry.runs.blocked.other = 9;
  const baseline = render(sample(), [retry], []); expect(baseline).toContain("Baseline only"); expect(baseline).not.toContain("change ");
  row.service.health = "unavailable"; row.service.invocation = ""; row.runs.health = "unavailable";
  const missing = render(row, [a], []); expect(missing).not.toContain("=0"); expect(missing).not.toContain("counter: 0"); expect(missing).not.toContain("0 bytes"); expect(missing).not.toContain("restart/reset");
  expect(missing).toContain("Inactivity does not establish code quality");
});
test("automatic restart increases survive invocation changes and historical blocked rows are not degraded", () => {
  const row = sample(), prior = sample(now - 86400000); row.service.invocation = "b".repeat(32); row.service.restarts = 3;
  expect(render(row, [prior], [])).toContain("3 additional automatic restarts");
  prior.service.health = "unavailable"; expect(render(row, [prior], [])).not.toContain("restart/reset");
  expect(summarizeRuns({ok:true,value:[{id:"00000000-0000-0000-0000-000000000001",status:"blocked",reason:"user_abort",createdAt:now,deadline:0}]},now,12).health).toBe("ok");
});
