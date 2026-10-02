import { createHash } from "node:crypto";
import { lstatSync, readFileSync, readdirSync, readlinkSync } from "node:fs";
import { join } from "node:path";
import { componentTotals } from "./claude-usage-rollup.mjs";

export const LIMITS = Object.freeze({
  invocations: 42,
  comparative: 36,
  auxiliary: 6,
  liveMs: 7200000,
  cellMs: 300000,
});
export const TASKS = Object.freeze([
  {
    id: "T1",
    purpose: "Canonical vault resolver search",
    holdout: false,
    oracle: "Valid file/line anchors and exact routing facts; no edits",
  },
  {
    id: "T2",
    purpose: "Non-strict MCP patch on original snapshot",
    holdout: false,
    oracle: "External strict/non-strict, render, permissions and cleanup tests",
  },
  {
    id: "T3",
    purpose: "Pure usage normalizer implementation",
    holdout: false,
    oracle: "External absent/null/zero/invalid/four-component tests",
  },
  {
    id: "T4",
    purpose: "Two injected bugs and one correct control",
    holdout: false,
    oracle: "Structured findings, both true positives and zero false positives",
  },
  {
    id: "T5",
    purpose: "Resume a started correction from PLAN/ledger",
    holdout: true,
    oracle: "External behavior tests, preserved ledger and recovered handoff",
  },
  {
    id: "T6",
    purpose: "Read-only synthetic ticket/docs through local MCP",
    holdout: true,
    oracle: "Required server calls and factual response; no external service",
  },
]);
const AUX = [
  "plan-cross-family",
  "local-runtime",
  "native-resume-and-agents",
  "macbook-private-validation",
  "diff-cross-family",
  "explicit-retry-or-probe",
];
const emptyUsage = () => ({
  input_tokens: null,
  output_tokens: null,
  cache_read_tokens: null,
  cache_creation_tokens: null,
  processed_total_tokens: null,
});
export function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === "object")
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, canonical(value[key])]),
    );
  return value;
}
export const hash = (value) =>
  createHash("sha256")
    .update(
      typeof value === "string" ? value : JSON.stringify(canonical(value)),
    )
    .digest("hex");

export function inventory(seed = 20261002) {
  if (!Number.isInteger(seed) || seed < 0)
    throw new Error("seed must be a non-negative integer");
  let state = seed >>> 0;
  const shuffled = TASKS.slice();
  for (let i = shuffled.length - 1; i > 0; i--) {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    const j = state % (i + 1);
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  const cells = [];
  for (let rep = 1; rep <= 3; rep++)
    for (const task of shuffled) {
      const pair = cells.length / 2;
      for (const arm of pair % 2 ? ["low", "medium"] : ["medium", "low"]) {
        cells.push({
          id: `${task.id}-${rep}-${arm}`,
          task: task.id,
          holdout: task.holdout,
          rep,
          arm,
          effort_requested: arm,
          effort_observed: null,
          status: "not_run",
          duration_ms: null,
          oracle: null,
          usage: emptyUsage(),
          subagent_usage: null,
          quota_before: null,
          quota_after: null,
        });
      }
    }
  return {
    comparative: cells,
    auxiliary: AUX.map((purpose, i) => ({
      id: `A${i + 1}`,
      purpose,
      status: "not_run",
      duration_ms: null,
      retry_of: null,
    })),
  };
}

export function validateArms(baseline, candidate) {
  if (baseline.effort !== "medium" || candidate.effort !== "low")
    throw new Error("only medium -> low is permitted");
  const { effort: left, ...a } = baseline,
    { effort: right, ...b } = candidate;
  const keys = Object.keys(a).sort();
  if (
    JSON.stringify(keys) !== JSON.stringify(Object.keys(b).sort()) ||
    keys.some((key) => hash(a[key]) !== hash(b[key]))
  )
    throw new Error("confounded arms: shared configuration must match");
  return true;
}

// Missing, invalid and zero remain distinct before reusing the shared accounting.
export function nativeUsage(raw) {
  const aliases = {
    input_tokens: "input_tokens",
    output_tokens: "output_tokens",
    cache_read_tokens: "cache_read_input_tokens",
    cache_creation_tokens: "cache_creation_input_tokens",
  };
  const usage = Object.fromEntries(
    Object.entries(aliases).map(([key, alias]) => {
      const value = raw?.[alias];
      return [
        key,
        typeof value === "number" && Number.isInteger(value) && value >= 0
          ? value
          : null,
      ];
    }),
  );
  return Object.values(usage).every((value) => value !== null)
    ? componentTotals(usage)
    : { ...usage, processed_total_tokens: null };
}

// Offline budgeting helper only: this does not authorize or launch a provider.
export function nextReservation(state, slot, elapsedMs) {
  if (
    !Number.isInteger(state?.launched) ||
    state.launched < 0 ||
    !Number.isFinite(state.live_ms) ||
    state.live_ms < 0 ||
    !Array.isArray(state.used_slots)
  )
    throw new Error("invalid state; preserve the ledger");
  if (!Number.isFinite(elapsedMs) || elapsedMs < 0)
    throw new Error("invalid elapsed time");
  const ids = inventory()
    .comparative.concat(inventory().auxiliary)
    .map((cell) => cell.id);
  if (!ids.includes(slot) || state.used_slots.includes(slot))
    throw new Error(
      "unknown or already consumed slot; retries use A6 explicitly",
    );
  if (
    state.launched >= LIMITS.invocations ||
    state.live_ms + elapsedMs >= LIMITS.liveMs
  )
    throw new Error("campaign cap reached");
  const timeout_ms = Math.min(
    LIMITS.cellMs,
    LIMITS.liveMs - state.live_ms - elapsedMs,
  );
  // Reserve the full timeout before spawn. Crash recovery cannot create free time.
  return {
    launched: state.launched + 1,
    used_slots: [...state.used_slots, slot],
    live_ms: state.live_ms + elapsedMs + timeout_ms,
    timeout_ms,
  };
}

export function snapshot(directory) {
  const entries = {};
  const walk = (base, relative = "") => {
    for (const name of readdirSync(base).sort()) {
      if (!relative && name === ".git") continue;
      const path = join(base, name),
        key = relative ? `${relative}/${name}` : name;
      const stat = lstatSync(path);
      if (stat.isSymbolicLink()) entries[key] = `symlink:${readlinkSync(path)}`;
      else if (stat.isDirectory()) {
        entries[key + "/"] = "directory";
        walk(path, key);
      } else if (stat.isFile())
        entries[key] =
          `${stat.mode & 0o777}:${hash(readFileSync(path).toString("base64"))}`;
      else throw new Error(`unsupported fixture entry: ${key}`);
    }
  };
  walk(directory);
  return entries;
}
export function checkScope(before, after, allowed) {
  return [...new Set([...Object.keys(before), ...Object.keys(after)])].filter(
    (path) => before[path] !== after[path] && !allowed.includes(path),
  );
}
export function checkProtected(before, after) {
  if (hash(before) !== hash(after))
    throw new Error("external oracle or fixture changed; reject the result");
}
export function gradeFindings(findings, expected) {
  if (
    !Array.isArray(findings) ||
    findings.length !== expected.length ||
    findings.some(
      (item) =>
        !item ||
        typeof item !== "object" ||
        typeof item.path !== "string" ||
        !Number.isInteger(item.line) ||
        item.line < 1,
    )
  )
    return false;
  const keys = findings.map((item) => `${item.path}:${item.line}`);
  return (
    new Set(keys).size === keys.length &&
    expected.every((item) => keys.includes(`${item.path}:${item.line}`)) &&
    findings.every(
      (item) =>
        typeof item.reason === "string" &&
        item.reason.trim().length > 0 &&
        !/\b(?:no (?:bug|defect)|line is correct|works as intended)\b/i.test(
          item.reason,
        ) &&
        (!expected.find((e) => e.path === item.path && e.line === item.line)
          ?.repro ||
          hash(item.repro) ===
            hash(
              expected.find((e) => e.path === item.path && e.line === item.line)
                .repro,
            )),
    )
  );
}

export function dryRun(fixtures = null) {
  const slots = inventory();
  return {
    schema: "claude-efficiency-offline-v1",
    seed: 20261002,
    status: "protocol_prepared",
    live_ready: false,
    limits: LIMITS,
    tasks: TASKS,
    slots,
    inventory_sha256: hash(slots),
    fixtures,
    unique_lever:
      "effort medium -> low; same exact model and shared configuration",
    model_required: "exact Opus 5.5 native identifier, not an alias",
    quota_verdict: "INCONCLUSIVE",
    launched: 0,
    pending: [
      "Freeze all fixture/oracle hashes in the live run before the first call; do not tune on holdouts",
      "Choose store/account and verify included usage, Usage credits disabled and quota available",
      "Freeze native CLI/model/settings/plugins/MCP/agents fingerprints",
      "Wire the serialized live runner and process-group timeout with native runtime evidence",
      "Cross-family review, native auxiliary probes and comparative campaign",
    ],
    inference_calls: 0,
    auth_calls: 0,
    network_calls: 0,
    writes: 0,
  };
}
