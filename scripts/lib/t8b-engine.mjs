#!/usr/bin/env node
// scripts/lib/t8b-engine.mjs — T8b paid-campaign engine (NEW, T8b engine).
//
// Executes screening/economic runs via the pi CLI (model zai/glm-5.3 ONLY),
// one pi call per run (plus dispatch children inside s10), with:
//   - per-run worktree copies (read-only intent) + FS-diff write veto,
//   - pi --mode json event capture -> single ordered trace + final text,
//   - per-run usage attribution (100% required; missing => run missing),
//   - engine-side pointer attestation (sha over JSONL-recorded bytes) +
//     STRONG validation through the FROZEN scripts/pointer-follow-verify,
//   - run-by-run spend accounting against the campaign freeze cap.
// Pure helpers are exported for the offline self-test. Paid entry points
// refuse unless provider == zai/glm-5.3, ZAI_API_KEY is present, and the
// campaign freeze pins the exact invocation.

import { spawn, spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import {
  copyFileSync, cpSync, existsSync, mkdirSync, readdirSync, readFileSync,
  rmSync, statSync, writeFileSync,
} from "node:fs";
import { dirname, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
export const REPO_ROOT = resolve(HERE, "../..");
export const POINTER_VERIFY = join(REPO_ROOT, "scripts/pointer-follow-verify");
export const NONINFERIORITY = join(HERE, "skill-eval-noninferiority.mjs");

export function sha256Bytes(buf) { return createHash("sha256").update(buf).digest("hex"); }
export function sha256Text(s) { return sha256Bytes(Buffer.from(s, "utf8")); }

// ---- pi jsonl parsing ----

export function parsePiJsonl(text) {
  const events = [];
  const invalidLines = [];
  for (const [i, line] of text.split("\n").entries()) {
    if (line.trim() === "") continue;
    try {
      events.push(JSON.parse(line));
    } catch {
      invalidLines.push(i + 1);
    }
  }
  return { events, invalidLines };
}

function textOfContent(content) {
  if (!Array.isArray(content)) return "";
  return content.filter((b) => b && b.type === "text" && typeof b.text === "string")
    .map((b) => b.text).join("\n");
}

// Normalize an agent-read path to a worktree-relative posix path when the
// target sits inside the worktree; otherwise return null (outside scope).
export function normalizeWorktreePath(p, worktreeAbs) {
  if (typeof p !== "string" || p === "") return null;
  const abs = resolve(worktreeAbs, p);
  const rel = relative(worktreeAbs, abs);
  if (rel === "" || rel.startsWith("..") || resolve(abs) !== join(worktreeAbs, rel)) return null;
  return rel.split(sep).join("/");
}

// Build the single ordered trace + usage + final text from message_end
// events (the shapes pi emits in --mode json; see review-hunter-capture
// and harness-token-usage.mjs precedents).
export function buildRunTrace(events, { runId, worktreeAbs }) {
  const calls = new Map(); // toolCallId -> {name, args, order}
  const results = new Map(); // toolCallId -> {content, isError, usage}
  const order = [];
  const usage = { in: 0, out: 0, cr: 0, cc: 0 };
  let receipts = 0;
  const models = new Set();
  let finalText = "";
  let stopReason = null;
  let terminal = false;
  const addUsage = (u) => {
    if (!u || typeof u !== "object") return;
    if (!Number.isInteger(u.input) || !Number.isInteger(u.output)) return;
    usage.in += u.input;
    usage.out += u.output;
    usage.cr += Number.isInteger(u.cacheRead) ? u.cacheRead : 0;
    usage.cc += Number.isInteger(u.cacheWrite) ? u.cacheWrite : 0;
    receipts++;
  };
  for (const ev of events) {
    if (!ev || ev.type !== "message_end" || !ev.message) continue;
    const msg = ev.message;
    if (msg.role === "assistant") {
      if (msg.provider && msg.model) models.add(`${msg.provider}/${msg.model}`);
      addUsage(msg.usage);
      if (["stop", "error", "aborted", "length"].includes(msg.stopReason)) {
        terminal = true;
        stopReason = msg.stopReason;
      }
      if (msg.stopReason === "stop") {
        finalText = textOfContent(msg.content);
      }
      if (msg.stopReason === "length") {
        finalText = textOfContent(msg.content);
      }
      for (const block of msg.content ?? []) {
        if (block && block.type === "toolCall" && typeof block.id === "string") {
          if (!calls.has(block.id)) {
            calls.set(block.id, { name: block.name, args: block.arguments ?? {}, order: order.length });
            order.push(block.id);
          }
        }
      }
    } else if (msg.role === "toolResult" && typeof msg.toolCallId === "string") {
      if (!results.has(msg.toolCallId)) {
        results.set(msg.toolCallId, { content: msg.content ?? [], isError: msg.isError === true });
      }
      if (msg.usage) addUsage(msg.usage);
    }
  }
  // Single ordered trace: calls in first-seen order with their results.
  const trace = [];
  const reads = [];
  const emitCalls = [];
  const dispatchCalls = [];
  for (const id of order) {
    const call = calls.get(id);
    const res = results.get(id);
    const ok = res !== undefined && res.isError !== true;
    const entry = { tool_call_id: id, run_id: runId, tool: call.name,
      args: call.args, ok };
    if (res !== undefined) entry.returned_bytes = JSON.stringify(res.content ?? []);
    trace.push(entry);
    if (call.name === "read" && ok && typeof call.args?.path === "string") {
      const norm = normalizeWorktreePath(call.args.path, worktreeAbs);
      if (norm !== null) reads.push(norm);
    }
    if (call.name === "emit-pointer-follow") {
      emitCalls.push({ tool_call_id: id, args: call.args, ok,
        resultText: res ? textOfContent(res.content) : "" });
    }
    if (call.name === "dispatch-review") {
      let record = null;
      const resultText = res ? textOfContent(res.content) : "";
      const m = /T8B-DISPATCH-RECORD\n([\s\S]*?)\nT8B-DISPATCH-END/.exec(resultText);
      if (m) {
        try { record = JSON.parse(m[1]); } catch { record = null; }
      }
      dispatchCalls.push({ tool_call_id: id, args: call.args, ok, resultText, record });
    }
  }
  return { trace, reads, emitCalls, dispatchCalls, finalText, stopReason,
    terminal, usage: receipts > 0 ? usage : null, receipts, models: [...models] };
}

// ---- worktree snapshots (write-surface veto) ----

export function snapshotTree(dir) {
  const out = new Map();
  const walk = (d) => {
    for (const e of readdirSync(d).sort()) {
      const full = join(d, e);
      const rel = relative(dir, full).split(sep).join("/");
      const st = statSync(full);
      if (st.isDirectory()) {
        const sub = snapshotTree(full);
        for (const [k, v] of sub) out.set(`${rel}/${k}`, v);
      } else if (st.isFile()) {
        out.set(rel, sha256Bytes(readFileSync(full)));
      }
    }
  };
  walk(dir);
  return out;
}

export function diffSnapshots(before, after) {
  const added = [];
  const modified = [];
  const deleted = [];
  for (const [k, v] of after) {
    if (!before.has(k)) added.push(k);
    else if (before.get(k) !== v) modified.push(k);
  }
  for (const k of before.keys()) {
    if (!after.has(k)) deleted.push(k);
  }
  return { added, modified, deleted,
    clean: added.length === 0 && modified.length === 0 && deleted.length === 0 };
}

// ---- pointer attestation (engine-side; frozen STRONG verifier) ----

function normalizedArgs(tool, args, worktreeAbs) {
  if (!args || typeof args !== "object" || Array.isArray(args)) return args;
  const out = { ...args };
  if ((tool === "read" || tool === "grep") && typeof out.path === "string") {
    const norm = normalizeWorktreePath(out.path, worktreeAbs);
    if (norm !== null) out.path = norm;
  }
  return out;
}

// Resolve the producing read call for an emission: exact tool_call_id
// match first, else unique same-path fallback. Returns the trace entry
// or null.
export function resolveProducer(trace, { tool_call_id, path }) {
  const exact = trace.filter((c) => c.tool_call_id === tool_call_id
    && (c.tool === "read" || c.tool === "resolve_pointer") && c.ok === true);
  if (exact.length === 1) return exact[0];
  if (exact.length > 1) return null;
  const byPath = trace.filter((c) => (c.tool === "read" || c.tool === "resolve_pointer")
    && c.ok === true && c.args?.path === path);
  if (byPath.length === 1) return byPath[0];
  return null;
}

// Attest the FIRST conforming emission: rewrite args to normalized paths,
// bind the producer, attest sha over the recorded returned bytes, append
// the verdict marker, and validate with the frozen verifier.
// Returns {ok, event, strongDetail, traceFile}.
export function attestPointerEvent({ runTrace, emitCall, runId, worktreeAbs, runDir, producerTool = "read" }) {
  const trace = runTrace.map((c) => ({ ...c, args: normalizedArgs(c.tool, c.args, worktreeAbs) }));
  let emitPath = emitCall?.args?.path;
  if (typeof emitPath === "string") {
    const norm = normalizeWorktreePath(emitPath, worktreeAbs);
    if (norm !== null) emitPath = norm;
  }
  const detail = { path: emitPath, sha256: "", tool_call_id: emitCall?.args?.tool_call_id };
  const producer = typeof emitPath === "string" && typeof detail.tool_call_id === "string"
    ? resolveProducer(trace, detail) : null;
  if (!producer || producer.tool !== producerTool) {
    return { ok: false, event: null, strongDetail: "no unique successful producing call for the cited tool_call_id/path", traceFile: null };
  }
  // Bind to the true producing call: the ledger records the real
  // tool_call_id (probe C: models hallucinate ids; the runner resolves).
  detail.tool_call_id = producer.tool_call_id;
  if (typeof producer.returned_bytes !== "string") {
    return { ok: false, event: null, strongDetail: "producing call carries no recorded bytes", traceFile: null };
  }
  detail.sha256 = sha256Text(producer.returned_bytes);
  const event = { run_id: runId, type: "pointer_follow", detail };
  const full = trace.map((c) => {
    if (c.tool === "emit-pointer-follow" && c.tool_call_id === emitCall.tool_call_id) {
      return { ...c, payload: { ...detail } };
    }
    return c;
  });
  full.push({ tool_call_id: "verdict:final", run_id: runId, tool: "verdict", args: {}, ok: true });
  const doc = { schema_version: 1, run_id: runId, trace: full, ledger_event: event };
  const traceFile = join(runDir, "strong-trace.json");
  writeFileSync(traceFile, `${JSON.stringify(doc)}\n`);
  const res = spawnSync(process.execPath, [POINTER_VERIFY, "--trace", traceFile], { encoding: "utf8" });
  if (res.status !== 0) {
    return { ok: false, event, strongDetail: (res.stderr ?? res.stdout ?? "").trim().slice(0, 300), traceFile };
  }
  return { ok: true, event, strongDetail: (res.stdout ?? "").trim().slice(0, 200), traceFile };
}

// ---- run argv construction (pinned; self-tested) ----

export const PLAN_STAGING = join(HERE, "t8b-plan-staging.md");

export function baseArgv(freeze, { tools, extension }) {
  const argv = ["--mode", "json", "-p", "--no-session", "--no-skills",
    "--no-context-files", "--tools", tools,
    "--model", freeze.model, "--thinking", freeze.thinking];
  if (extension) argv.unshift("--extension", extension);
  else argv.splice(6, 0, "--no-extensions");
  return argv;
}

export const PREAMBLE = (worktreeAbs) => `Cwd: ${worktreeAbs}. Repo-relative paths (workflow/..., scripts/..., PLAN_*.md, pi/...) resolve under this directory. Read with the read tool; no writes, no other tools.\n\n`;

// R-T8b-11: plan-loop runs are staged under the variant contract (the
// variant-IDENTICAL role prompt below; the contracts differ). Without
// staging, the candidate validity rule (all five systematics read) is
// unsatisfiable by construction — the frozen bodies never invoke the
// contract, so unstaged models read only the subject file (v6 evidence:
// s1/candidate/r1 read exactly {scripts/workflow-event}).
export function planLoopArgv({ freeze }) {
  return [...baseArgv(freeze, { tools: "read" }),
    "--append-system-prompt", PLAN_STAGING];
}

// ---- pi spawning ----

export function spawnPiCapture({ argv, cwd, timeoutS, env, stdoutFile, stderrFile, maxBytes = 50 * 1024 * 1024 }) {
  return new Promise((resolvePromise) => {
    const t0 = Date.now();
    const child = spawn("pi", argv, { cwd, env: { ...process.env, ...env }, stdio: ["ignore", "pipe", "pipe"] });
    const chunks = [];
    const errChunks = [];
    let size = 0;
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      try { child.kill("SIGTERM"); } catch {}
      setTimeout(() => { try { child.kill("SIGKILL"); } catch {} }, 5000);
    }, timeoutS * 1000);
    child.stdout.on("data", (c) => {
      size += c.length;
      if (size <= maxBytes) chunks.push(c);
    });
    child.stderr.on("data", (c) => { errChunks.push(c); });
    child.on("error", (err) => {
      clearTimeout(timer);
      resolvePromise({ exit: 127, timedOut: false, elapsedMs: Date.now() - t0,
        stdout: "", stderr: String(err?.message ?? err), spawnError: true });
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      const stdout = Buffer.concat(chunks).toString("utf8");
      const stderr = Buffer.concat(errChunks).toString("utf8");
      try {
        if (stdoutFile) writeFileSync(stdoutFile, stdout);
        if (stderrFile) writeFileSync(stderrFile, stderr);
      } catch {}
      resolvePromise({ exit: code ?? 1, timedOut, elapsedMs: Date.now() - t0, stdout, stderr });
    });
  });
}

// ---- spend ----

export function costOf(usage, prices) {
  const scaled = usage.in * prices.in + usage.out * prices.out + usage.cr * prices.cr + usage.cc * prices.cc;
  return scaled / 1e6;
}

export function createSpendTracker({ capUsd, prices, spendPath }) {
  let spent = 0;
  const rows = [];
  try {
    if (existsSync(spendPath)) {
      for (const line of readFileSync(spendPath, "utf8").split("\n")) {
        if (line.trim() === "") continue;
        try {
          const row = JSON.parse(line);
          if (typeof row.cost_usd === "number") { spent += row.cost_usd; rows.push(row); }
        } catch {}
      }
    }
  } catch {}
  return {
    spent: () => spent,
    remainder: () => capUsd - spent,
    rows,
    // Launch gate: the run may start only if an upper-bound single run
    // still fits strictly inside the cap.
    fits: (worstSingleUsd) => spent + worstSingleUsd < capUsd,
    record: (row) => {
      const cost = costOf(row.usage, prices);
      spent += cost;
      const full = { ...row, cost_usd: cost, cumulative_usd: spent };
      rows.push(full);
      writeFileSync(spendPath, `${JSON.stringify(full)}\n`, { flag: "a" });
      return full;
    },
  };
}

