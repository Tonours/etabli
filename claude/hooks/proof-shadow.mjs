#!/usr/bin/env node
/**
 * Claude Stop hook (shadow): link completion claims to their command.
 *
 * Scans the transcript's assistant text for the closed claim list and
 * resolves each claim against transcript Bash runs (tests-pass classes) or
 * `gh run list` (CI-green class). Verdicts: substantiated | unsubstantiated
 * | unverifiable (tool error/timeout/auth — reported separately, never
 * conflated with unsubstantiated).
 *
 * Shadow = report only: records go to proof-shadow.jsonl (active session
 * ledger dir when a run pointer exists, else $TMPDIR session-keyed — NEVER
 * the repo tree); exit 0 ALWAYS, including malformed transcript input.
 * Records are best-effort (SIGKILL = silent data loss, no retry).
 *
 * Wiring: THIRD in the Stop chain (after ADR + metric emit). Ordering =
 * array position in claude/settings.workflow-hooks.json (documented
 * assumption); 5s timeout inherited from the fragment. Fresh-checkout
 * wiring flows through the check-fix-symlinks.sh link step and is asserted
 * by scripts/claude-hooks-check.
 *
 * Later-tranche promotion reader is the consumer of proof-shadow.jsonl.
 */
import { appendFileSync, existsSync, readFileSync, renameSync, statSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { parseJsonLine, readJsonLines } from "./transcript-lib.mjs";
import { readHookInput } from "./workflow-router-lib.mjs";
import { getActiveRunPointer } from "../../scripts/lib/ledger-integrity.mjs";

// Closed claim list: matcher (case-insensitive, word-boundary) -> class.
const CLAIMS = [
  { re: /\btests pass\b/i, phrase: "tests pass", klass: "tests-pass" },
  { re: /\bverified\b/i, phrase: "verified", klass: "verified" },
  { re: /\bci green\b/i, phrase: "CI green", klass: "ci-green" },
  { re: /\bsmoke vert\b/i, phrase: "smoke vert", klass: "smoke" },
  { re: /\ball green\b/i, phrase: "all green", klass: "all-green" },
];

// Pinned class->command table for tests-pass classes: unanchored substring
// alternation over tool_use.input.command. Shadow precision is a
// later-tranche promotion concern; the list is pinned, not guessed per run.
const TEST_CMD_RE =
  /(bun test|npm test|pnpm test|yarn test|pytest|jest|vitest|go test|cargo test|make test|verify-agentic-infra|smoke|retest|\.sh(\s|$))/;

const GH_TIMEOUT_MS = 3000;
const SINK_CAP = 200;

function textSegments(entry) {
  const content = entry?.message?.content;
  if (!Array.isArray(content)) return [];
  return content.filter((c) => c && c.type === "text" && typeof c.text === "string");
}

function toolUseItems(entry) {
  const content = entry?.message?.content;
  if (!Array.isArray(content)) return [];
  return content.filter((c) => c && c.type === "tool_use");
}

function toolResultItems(entry) {
  const content = entry?.message?.content;
  if (!Array.isArray(content)) return [];
  return content.filter((c) => c && c.type === "tool_result");
}

function entryTs(entry) {
  const ms = Date.parse(entry?.timestamp);
  return Number.isFinite(ms) ? ms : null;
}

/**
 * Max mtime (ms) over `git status --porcelain` paths, untracked included.
 * Returns { max, error }. Clean tree => max -Infinity. Git failure => error.
 */
function maxPorcelainMtime(cwd) {
  let out;
  try {
    out = execFileSync("git", ["status", "--porcelain"], {
      cwd,
      encoding: "utf8",
      timeout: GH_TIMEOUT_MS,
      stdio: ["ignore", "pipe", "ignore"],
    });
  } catch {
    return { max: null, error: "git-status-failed" };
  }
  let max = Number.NEGATIVE_INFINITY;
  for (const line of out.split("\n")) {
    if (line.length < 4) continue;
    let p = line.slice(3);
    const arrow = p.indexOf(" -> ");
    if (arrow >= 0) p = p.slice(arrow + 4);
    if (p.startsWith('"') && p.endsWith('"')) p = p.slice(1, -1);
    if (!p) continue;
    try {
      const ms = statSync(join(cwd, p)).mtimeMs;
      if (ms > max) max = ms;
    } catch {
      // Deleted or unreadable path: skip, it cannot prove staleness.
    }
  }
  return { max, error: null };
}

function trackedDirty(cwd) {
  try {
    const out = execFileSync("git", ["status", "--porcelain"], {
      cwd,
      encoding: "utf8",
      timeout: GH_TIMEOUT_MS,
      stdio: ["ignore", "pipe", "ignore"],
    });
    return {
      dirty: out.split("\n").some((l) => l.length >= 3 && !l.startsWith("??")),
      error: null,
    };
  } catch {
    return { dirty: false, error: "git-status-failed" };
  }
}

function headSha(cwd) {
  try {
    const sha = execFileSync("git", ["rev-parse", "HEAD"], {
      cwd,
      encoding: "utf8",
      timeout: GH_TIMEOUT_MS,
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    return { sha: /^[0-9a-f]{4,}$/i.test(sha) ? sha : null, error: null };
  } catch {
    return { sha: null, error: "git-rev-parse-failed" };
  }
}

function ghConclusion(cwd, sha, ghBin) {
  let out;
  try {
    out = execFileSync(
      ghBin,
      ["run", "list", "--commit", sha, "--limit", "50", "--json", "status,conclusion,headSha"],
      { cwd, encoding: "utf8", timeout: GH_TIMEOUT_MS, stdio: ["ignore", "pipe", "ignore"] },
    );
  } catch {
    return { runs: null, error: "gh-failed" };
  }
  try {
    const runs = JSON.parse(out);
    if (!Array.isArray(runs)) return { runs: null, error: null, malformed: true };
    return { runs, error: null };
  } catch {
    return { runs: null, error: null, malformed: true };
  }
}

function resolveSink(cwd, sessionId) {
  try {
    const pointer = getActiveRunPointer(cwd);
    if (pointer && pointer.state === "present" && pointer.run) {
      return join(cwd, ".workflow", pointer.run, "proof-shadow.jsonl");
    }
  } catch {
    // Fall through to the session-keyed temp sink.
  }
  const base = process.env.TMPDIR || tmpdir();
  const sid = sessionId && String(sessionId).trim() !== "" ? String(sessionId) : "nosession";
  return join(base, `proof-shadow-${sid}.jsonl`);
}

function appendCapped(path, record) {
  try {
    if (existsSync(path)) {
      const lines = readFileSync(path, "utf8").split("\n").filter((l) => l.trim() !== "");
      if (lines.length >= SINK_CAP) {
        renameSync(path, `${path}.1`); // clobbering rotation: 400-record window
      }
    }
    appendFileSync(path, `${JSON.stringify(record)}\n`);
  } catch {
    // best-effort sink
  }
}

function main() {
  const input = readHookInput();
  const cwd = input.cwd || process.cwd();
  const sessionId = input.session_id || input.sessionId || null;
  const ghBin = process.env.PROOF_SHADOW_GH || "gh";
  const now = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");

  const { lines, readable } = readJsonLines(input.transcript_path || input.transcriptPath);
  if (!readable) return;
  const entries = [];
  for (const line of lines) {
    const entry = parseJsonLine(line);
    if (entry) entries.push(entry);
  }

  // Index tool results by tool_use_id (timestamp = transcript time).
  const resultsById = new Map();
  entries.forEach((entry, index) => {
    const ts = entryTs(entry);
    for (const r of toolResultItems(entry)) {
      if (r.tool_use_id && !resultsById.has(r.tool_use_id)) {
        resultsById.set(r.tool_use_id, { ts, isError: r.is_error, index });
      }
    }
  });

  // Candidate Bash runs: matching command + joined is_error:false result.
  const runs = [];
  entries.forEach((entry, index) => {
    for (const u of toolUseItems(entry)) {
      if (u.name !== "Bash") continue;
      const command = u.input?.command;
      if (typeof command !== "string" || !TEST_CMD_RE.test(command)) continue;
      const res = resultsById.get(u.id);
      if (!res || res.isError !== false || res.ts === null) continue;
      runs.push({ command, toolUseId: u.id, ts: res.ts, index: res.index });
    }
  });
  // Latest first; transcript order breaks timestamp ties.
  runs.sort((a, b) => b.ts - a.ts || b.index - a.index);

  // Claim occurrences in assistant text (transcript order).
  const claims = [];
  entries.forEach((entry, index) => {
    for (const seg of textSegments(entry)) {
      for (const c of CLAIMS) {
        if (c.re.test(seg.text)) {
          claims.push({ phrase: c.phrase, klass: c.klass, index, ts: entryTs(entry) });
        }
      }
    }
  });
  if (!claims.length) return;

  const sink = resolveSink(cwd, sessionId || entries[0]?.sessionId || null);
  const mtime = maxPorcelainMtime(cwd);
  const head = headSha(cwd);

  for (const claim of claims) {
    const record = {
      schema_version: 1,
      ts: now,
      session_id: sessionId || entries[0]?.sessionId || "nosession",
      claim: claim.phrase,
      class: claim.klass,
      verdict: "unsubstantiated",
      reason: "",
    };
    if (claim.klass === "ci-green") {
      if (head.error || !head.sha) {
        record.verdict = "unverifiable";
        record.reason = head.error || "no-head-sha";
      } else {
        record.head_sha = head.sha;
        const tree = trackedDirty(cwd);
        if (tree.error) {
          record.verdict = "unverifiable";
          record.reason = tree.error;
        } else if (tree.dirty) {
          record.verdict = "unverifiable";
          record.reason = "dirty-tree-vs-head";
        } else {
          const gh = ghConclusion(cwd, head.sha, ghBin);
          if (gh.error) {
            record.verdict = "unverifiable";
            record.reason = gh.error;
          } else if (gh.malformed || !gh.runs.length) {
            record.verdict = "unsubstantiated";
            record.reason = gh.malformed ? "gh-malformed-output" : "no-runs-for-sha";
          } else if (gh.runs.every((r) => r?.conclusion === "success")) {
            record.verdict = "substantiated";
            record.reason = "gh-all-conclusions-success";
          } else {
            const bad = gh.runs.find((r) => r?.conclusion !== "success");
            record.verdict = "unsubstantiated";
            record.reason = `gh-conclusion-${bad?.conclusion ?? "missing"}`;
          }
        }
      }
    } else {
      // Evidence must precede the claim: a later run cannot substantiate an
      // earlier assertion (strictly-before; ties fail closed).
      const prior = claim.ts === null ? null : runs.find((r) => r.ts < claim.ts) || null;
      if (claim.ts !== null) {
        record.claim_ts = new Date(claim.ts).toISOString().replace(/\.\d{3}Z$/, "Z");
      }
      if (!runs.length) {
        record.reason = "no-matching-passing-run";
      } else if (!prior) {
        record.reason = "no-prior-passing-run";
      } else {
        record.command = prior.command;
        record.tool_use_id = prior.toolUseId;
        record.run_ts = new Date(prior.ts).toISOString().replace(/\.\d{3}Z$/, "Z");
        if (mtime.error) {
          record.verdict = "unverifiable";
          record.reason = mtime.error;
        } else if (prior.ts > mtime.max) {
          record.verdict = "substantiated";
          record.reason = "run-newer-than-tree";
        } else {
          record.reason = "run-not-newer-than-tree";
        }
      }
    }
    appendCapped(sink, record);
  }
}

try {
  main();
} catch {
  // shadow: never fail the session
}
process.exit(0);
