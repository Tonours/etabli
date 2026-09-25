// scripts/lib/t8b-pi-tools.mjs — T8b runner-provided pi tools (NEW, T8b engine).
//
// Loaded via `pi --extension <this file>` ONLY for pointer-task runs.
// Provides exactly:
//   - emit-pointer-follow {path, tool_call_id, sha256?}: provisional
//     pointer_follow recording. The model cites the producing read call;
//     sha is RUNNER-ATTESTED by the engine from JSONL-recorded bytes
//     (models cannot compute sha256; the anti-fabrication property is the
//     exact-call binding + order + attested bytes, verified by the frozen
//     STRONG script). Unknown ids resolve by unique-path fallback, else
//     REFUSED with the enumerated successful reads for retry.
//   - dispatch-review {patch_id}: the R24-B2 runner-provided dispatch. Pins
//     the patch to temp (sha-checked), spawns the REAL Logic hunter child,
//     runs the Spec phase (no intent exists for the pinned patch, so the
//     child input carries `spec: n/a`), applies the MECHANICAL lead filter
//     over the recorded outputs, and returns the chained phase record.
//     Children use the frozen invocation flags (equivalence self-tested).
//     A crashed child => T8B-DISPATCH-CRASH (the engine treats the run as
//     missing = crash path, never a soft verdict).
//
// The tools self-disable unless T8B_RUN_DIR is set (never in production).
// Spec-child scaffolding rule: spec-phase format issues => task FAIL via
// lead.unjudged, never a veto (the planted defect is Logic-axis).

import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import { appendFileSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, relative, resolve, sep } from "node:path";
import { Type } from "../../pi/extensions/node_modules/typebox/build/index.mjs";
import { buildRunTrace, parsePiJsonl } from "./t8b-engine.mjs";
import { extractFindingsUnified } from "./t8b-graders.mjs";

const sha8 = (s) => createHash("sha256").update(s, "utf8").digest("hex").slice(0, 12);
const sha256 = (s) => createHash("sha256").update(s, "utf8").digest("hex");

function requiredEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`t8b-pi-tools: missing env ${name}`);
  return v;
}

function runPiJson(args, { cwd, timeoutS, stdoutCap = 20 * 1024 * 1024 }) {
  return new Promise((done) => {
    const child = spawn("pi", args, { cwd, stdio: ["ignore", "pipe", "pipe"] });
    const out = [];
    const err = [];
    let size = 0;
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      try { child.kill("SIGTERM"); } catch {}
      setTimeout(() => { try { child.kill("SIGKILL"); } catch {} }, 5000);
    }, timeoutS * 1000);
    child.stdout.on("data", (c) => { size += c.length; if (size <= stdoutCap) out.push(c); });
    child.stderr.on("data", (c) => { err.push(c); });
    child.on("error", (e) => {
      clearTimeout(timer);
      done({ exit: 127, timedOut: false, stdout: "", stderr: String(e?.message ?? e), spawnError: true });
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      done({ exit: code ?? 1, timedOut, stdout: Buffer.concat(out).toString("utf8"),
        stderr: Buffer.concat(err).toString("utf8") });
    });
  });
}

// Child argv = the frozen pi-review-hunter invocation flags (see self-test
// byte-equivalence), + json mode + model + thinking for capture.
// promptFile/patchFile are absolute paths.
export function childHunterArgv({ promptFile, patchFile, model, thinking }) {
  return ["--mode", "json", "-p", "--no-session", "--no-skills", "--no-extensions",
    "--no-context-files", "--tools", "read,grep",
    "--append-system-prompt", promptFile, "--model", model, "--thinking", thinking,
    `@${patchFile}`];
}

export function summarizeChildJsonl(stdout, worktreeAbs) {
  const { events, invalidLines } = parsePiJsonl(stdout);
  const built = buildRunTrace(events, { runId: "child", worktreeAbs });
  return { ...built, invalidLines };
}

// Mechanical lead filter over the recorded Logic/Spec outputs.
export function leadFilter({ logicOutput, specOutput, logicId, specId, patch }) {
  const input_ids = [logicId, specId];
  const claimsNone = logicOutput.trim() === "No findings."
    || /(^|\n)\s*No findings\.\s*(\n|$)/.test(logicOutput);
  const findings = extractFindingsUnified(logicOutput).filter((f) => !f.blockError && f.line !== null);
  if (findings.length === 0 && claimsNone) {
    return { input_ids,
      verdict: `Lead verdict on [${logicId}, ${specId}]: logic reports no findings on ${patch.id}; miss recorded, nothing retained. Spec noted: ${specOutput.trim().slice(0, 60)}`,
      retained: [], missed: true };
  }
  if (findings.length === 0) {
    return { input_ids, verdict: "", retained: [],
      unjudged: `logic output unparseable (${logicOutput.trim().slice(0, 80)})` };
  }
  const refs = findings.map((f) => `${f.file}:${f.line}`).join(", ");
  return { input_ids, retained: findings,
    verdict: `Lead verdict on [${logicId}, ${specId}]: RETAIN logic finding(s) ${refs} on ${patch.id}; spec phase ${specId} noted.` };
}

export default function t8bTools(pi) {
  if (!process.env.T8B_RUN_DIR) return;
  const RUN_DIR = requiredEnv("T8B_RUN_DIR");
  const WORKTREE = requiredEnv("T8B_WORKTREE");
  const PINNED_PATCH = requiredEnv("T8B_PINNED_PATCH");
  const PINNED_SHA = requiredEnv("T8B_PINNED_SHA");
  const PATCH_FILE = requiredEnv("T8B_PATCH_FILE");
  const LOGIC_TEMPLATE = requiredEnv("T8B_LOGIC_TEMPLATE");
  const SPEC_TEMPLATE = requiredEnv("T8B_SPEC_TEMPLATE");
  const MODEL = requiredEnv("T8B_MODEL");
  const THINKING = requiredEnv("T8B_THINKING");
  const TIMEOUT_S = Number(requiredEnv("T8B_TIMEOUT_S"));
  const PROVISIONAL = join(RUN_DIR, "events.provisional.jsonl");

  // Live read log from message_end events (best-effort resolution aid;
  // the engine's JSONL attestation is authoritative).
  const readLog = new Map(); // toolCallId -> {path, ok}
  pi.on("message_end", (event) => {
    try {
      const msg = event?.message;
      if (!msg) return;
      if (msg.role === "assistant") {
        for (const block of msg.content ?? []) {
          if (block?.type === "toolCall" && block.name === "read" && typeof block.id === "string") {
            readLog.set(block.id, { path: block.arguments?.path, ok: null });
          }
        }
      } else if (msg.role === "toolResult" && typeof msg.toolCallId === "string") {
        const row = readLog.get(msg.toolCallId);
        if (row) row.ok = msg.isError !== true;
      }
    } catch {}
  });

  pi.registerTool({
    name: "emit-pointer-follow",
    label: "Emit pointer follow",
    description: "Record a pointer_follow event after reading a must-follow pointer target. Cite the successful read call (its tool call id) whose returned bytes you attest, plus the target path. The sha256 is runner-attested from the recorded bytes: pass the literal string 'runner-attested'.",
    parameters: Type.Object({
      path: Type.String(),
      tool_call_id: Type.String(),
      sha256: Type.Optional(Type.String()),
    }),
    async execute(toolCallId, params) {
      const norm = (p) => {
        if (typeof p !== "string" || p === "") return null;
        try {
          const abs = resolve(WORKTREE, p);
          const rel = relative(WORKTREE, abs);
          if (rel === "" || rel.startsWith("..")) return abs;
          return rel.split(sep).join("/");
        } catch { return null; }
      };
      const wantPath = norm(params.path);
      const okReads = [...readLog.entries()].filter(([, r]) => r.ok === true && typeof r.path === "string");
      const cited = readLog.get(params.tool_call_id);
      let bound = null;
      if (cited && cited.ok === true && norm(cited.path) === wantPath) {
        bound = params.tool_call_id;
      } else {
        const same = okReads.filter(([, r]) => norm(r.path) === wantPath);
        if (same.length === 1) bound = same[0][0];
      }
      if (!bound) {
        const enumerated = okReads.map(([id, r]) => `${id}:${r.path}`).join(", ") || "(no successful reads yet)";
        return {
          content: [{ type: "text", text: `REFUSED: tool_call_id '${params.tool_call_id}' designates no successful read of '${params.path}'. Successful reads in this run: ${enumerated}. Retry with a listed id.` }],
          details: { bound: false },
          isError: true,
        };
      }
      const row = { path: params.path, tool_call_id: bound, emit_call_id: toolCallId,
        supplied_sha256: params.sha256 ?? null };
      try {
        appendFileSync(PROVISIONAL, `${JSON.stringify(row)}\n`);
      } catch (err) {
        return {
          content: [{ type: "text", text: `REFUSED: provisional append failed: ${err.message}` }],
          details: { bound: false },
          isError: true,
        };
      }
      return {
        content: [{ type: "text", text: `pointer_follow recorded (provisional): path=${params.path} tool_call_id=${bound} — sha is runner-attested from the recorded returned bytes.` }],
        details: { bound: true, path: params.path, tool_call_id: bound },
      };
    },
  });

  pi.registerTool({
    name: "dispatch-review",
    label: "Dispatch review",
    description: `Execute the REAL review dispatch on the pinned patch ${PINNED_PATCH}: pins the patch to temp (sha-checked), spawns the Logic hunter child, runs the Spec phase, applies the lead filter, and returns the chained phase record. The functional result is the EXECUTION verdict over the recorded phases.`,
    parameters: Type.Object({ patch_id: Type.String() }),
    async execute(toolCallId, params) {
      if (params.patch_id !== PINNED_PATCH) {
        return {
          content: [{ type: "text", text: `REFUSED: patch_id '${params.patch_id}' != pinned '${PINNED_PATCH}'.` }],
          details: { ok: false },
          isError: true,
        };
      }
      let patchBytes;
      try {
        patchBytes = readFileSync(PATCH_FILE, "utf8");
      } catch (err) {
        return { content: [{ type: "text", text: `T8B-DISPATCH-CRASH: cannot read pinned patch: ${err.message}` }],
          details: { ok: false, crash: "patch unreadable" }, isError: true };
      }
      if (sha256(patchBytes) !== PINNED_SHA) {
        return { content: [{ type: "text", text: "T8B-DISPATCH-CRASH: pinned patch bytes differ from the frozen sha." }],
          details: { ok: false, crash: "patch sha mismatch" }, isError: true };
      }
      const scratch = mkdtempSync(join(tmpdir(), "t8b-dispatch-"));
      const logicPatch = join(scratch, "input.patch");
      const specInput = join(scratch, "spec-input.md");
      writeFileSync(logicPatch, patchBytes);
      writeFileSync(specInput, `${patchBytes}\n--- intent ---\nspec: n/a (no PLAN.md or PR/user intent exists for this pinned patch)\n`);
      const runChild = async (promptFile, patchArg) => {
        const res = await runPiJson(
          childHunterArgv({ promptFile, patchFile: patchArg, model: MODEL, thinking: THINKING }),
          { cwd: WORKTREE, timeoutS: TIMEOUT_S });
        if (res.timedOut || res.exit !== 0) {
          return { crash: res.timedOut ? "child timeout" : `child exit ${res.exit}: ${res.stderr.slice(0, 200)}` };
        }
        const sum = summarizeChildJsonl(res.stdout, WORKTREE);
        if (!sum.terminal || sum.stopReason !== "stop" || !sum.usage) {
          return { crash: `child non-terminal (stop=${sum.stopReason}, receipts=${sum.receipts})` };
        }
        if (sum.models.some((m) => m !== MODEL)) {
          return { crash: `child model provenance ${sum.models.join(",")} != ${MODEL}` };
        }
        return { output: sum.finalText, usage: sum.usage };
      };
      const logic = await runChild(LOGIC_TEMPLATE, logicPatch);
      if (logic.crash) {
        return { content: [{ type: "text", text: `T8B-DISPATCH-CRASH: logic child: ${logic.crash}` }],
          details: { ok: false, crash: logic.crash }, isError: true };
      }
      const spec = await runChild(SPEC_TEMPLATE, specInput);
      if (spec.crash) {
        return { content: [{ type: "text", text: `T8B-DISPATCH-CRASH: spec child: ${spec.crash}` }],
          details: { ok: false, crash: spec.crash }, isError: true };
      }
      const logicId = `L${sha8(logic.output)}`;
      const specId = `S${sha8(spec.output)}`;
      const lead = leadFilter({ logicOutput: logic.output, specOutput: spec.output,
        logicId, specId, patch: { id: PINNED_PATCH } });
      if (spec.output.trim() !== "spec: n/a" && extractFindingsUnified(spec.output).length === 0
          && spec.output.trim() !== "No findings." && !lead.unjudged) {
        lead.unjudged = `spec phase unparseable (${spec.output.trim().slice(0, 80)})`;
        lead.verdict = "";
      }
      const record = { patch_id: PINNED_PATCH, pinned_patch_sha: PINNED_SHA,
        logic: { input_sha: sha256(patchBytes), output_id: logicId, output: logic.output },
        spec: { output_id: specId, output: spec.output }, lead };
      const usage = {
        input: logic.usage.in + spec.usage.in,
        output: logic.usage.out + spec.usage.out,
        cacheRead: logic.usage.cr + spec.usage.cr,
        cacheWrite: logic.usage.cc + spec.usage.cc,
        totalTokens: 0,
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
      };
      usage.totalTokens = usage.input + usage.output + usage.cacheRead + usage.cacheWrite;
      const text = [
        `Dispatch executed on ${PINNED_PATCH} (sha ${PINNED_SHA.slice(0, 12)}):`,
        `logic child -> ${logicId} (${logic.output.trim().split("\n")[0] ?? ""})`,
        `spec phase -> ${specId} (${spec.output.trim().split("\n")[0] ?? ""})`,
        lead.verdict || `UNJUDGED: ${lead.unjudged}`,
        "Judge these recorded outputs in your final verdict, citing both output ids.",
        "T8B-DISPATCH-RECORD",
        JSON.stringify(record),
        "T8B-DISPATCH-END",
      ].join("\n");
      return { content: [{ type: "text", text }], details: { ok: true, record }, usage };
    },
  });
}
