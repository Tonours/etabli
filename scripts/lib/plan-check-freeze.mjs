#!/usr/bin/env node
/**
 * Mechanical check-freeze for READY plans.
 * Once READY, Checks may only be strengthened (added) unless demoted to
 * CHALLENGED with a Decision Log rationale mentioning check-freeze or weaken.
 */
import { readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

export function parsePlanStatus(text) {
  const m = String(text).match(/^\s*-\s*Status:\s*(DRAFT|CHALLENGED|READY)\s*$/im);
  return m ? m[1].toLowerCase() : "unknown";
}

/**
 * Extract frozen items under ## Checks and ## Acceptance Criteria until the
 * next ## heading of another kind. command: lines count as check identifiers.
 */
export function parseChecks(text) {
  const lines = String(text).split(/\r?\n/);
  const checks = [];
  let inFreezeSection = false;
  for (const line of lines) {
    if (/^##\s+(Checks|Acceptance Criteria)\b/i.test(line)) {
      inFreezeSection = true;
      continue;
    }
    if (inFreezeSection && /^##\s+/.test(line)) {
      if (/^##\s+(Checks|Acceptance Criteria)\b/i.test(line)) {
        continue;
      }
      inFreezeSection = false;
      continue;
    }
    if (!inFreezeSection) continue;
    const cmd = line.match(/^\s*[-*]\s+command:\s*(.+?)\s*$/i);
    if (cmd) {
      const item = `command:${cmd[1].replace(/\s+/g, " ").trim()}`;
      if (item !== "command:") checks.push(item);
      continue;
    }
    const bullet = line.match(/^\s*[-*]\s+(?:\[[ xX]\]\s+)?(.+?)\s*$/);
    if (bullet) {
      const item = bullet[1].replace(/\s+/g, " ").trim();
      if (
        item &&
        !/^expected:/i.test(item) &&
        !/^last run:/i.test(item)
      ) {
        checks.push(item);
      }
    }
  }
  return checks;
}

export function parseDecisionLog(text) {
  const lines = String(text).split(/\r?\n/);
  const out = [];
  let inLog = false;
  for (const line of lines) {
    if (/^##\s+Decision Log\b/i.test(line)) {
      inLog = true;
      continue;
    }
    if (inLog && /^##\s+/.test(line)) break;
    if (inLog) out.push(line);
  }
  return out.join("\n");
}

function normalize(item) {
  return String(item).replace(/\s+/g, " ").trim().toLowerCase();
}

/**
 * @param {{ previousChecks: string[], currentText: string }} input
 * @returns {{ ok: boolean, status: string, removed: string[], reason: string }}
 */
export function evaluateCheckFreeze({ previousChecks, currentText }) {
  const status = parsePlanStatus(currentText);
  const currentChecks = parseChecks(currentText);
  const decisionLog = parseDecisionLog(currentText);
  const prev = (previousChecks || []).map(normalize).filter(Boolean);
  const curr = new Set(currentChecks.map(normalize));

  if (prev.length === 0) {
    return {
      ok: true,
      status,
      removed: [],
      reason: "no previous freeze snapshot",
      currentChecks,
    };
  }

  const removed = prev.filter((c) => !curr.has(c));
  if (removed.length === 0) {
    return {
      ok: true,
      status,
      removed: [],
      reason: "checks preserved or strengthened",
      currentChecks,
    };
  }

  const demoted = status === "challenged";
  // Structured demote (preferred): "- check_freeze_demote: <nonempty reason>"
  const structuredMatch = decisionLog.match(
    /^\s*[-*]\s*check_freeze_demote:\s*(.+?)\s*$/im,
  );
  const structuredReason =
    structuredMatch && structuredMatch[1].trim() !== ""
      ? structuredMatch[1].trim()
      : null;
  // Legacy keyword path kept for existing plans (G1 residual).
  const keywordRationale =
    /check-freeze|weaken|weakened|removed check|demot/i.test(decisionLog);

  if (demoted && structuredReason) {
    return {
      ok: true,
      status,
      removed,
      reason: "weakening allowed: CHALLENGED with structured check_freeze_demote",
      demote_mode: "structured",
      demote_reason: structuredReason,
      currentChecks,
    };
  }

  if (demoted && keywordRationale) {
    return {
      ok: true,
      status,
      removed,
      reason: "weakening allowed: CHALLENGED with Decision Log rationale",
      demote_mode: "keyword",
      demote_reason: null,
      currentChecks,
    };
  }

  return {
    ok: false,
    status,
    removed,
    reason:
      "check-freeze violation: READY checks may only be strengthened; demote to CHALLENGED and record Decision Log rationale (check_freeze_demote: … or legacy check-freeze/weaken keywords) to remove/weaken",
    demote_mode: null,
    demote_reason: null,
    currentChecks,
  };
}

function main(argv) {
  const args = argv.slice(2);
  let previousPath = null;
  let currentPath = null;
  let previousJson = null;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--previous") previousPath = args[++i];
    else if (args[i] === "--previous-json") previousJson = args[++i];
    else if (args[i] === "--current") currentPath = args[++i];
    else if (args[i] === "-h" || args[i] === "--help") {
      console.log(
        "Usage: plan-check-freeze --current PLAN.md (--previous PLAN.snapshot.md | --previous-json '[...]')",
      );
      process.exit(0);
    }
  }
  if (!currentPath || (!previousPath && !previousJson)) {
    console.error("plan-check-freeze: --current and --previous|--previous-json required");
    process.exit(2);
  }
  const currentText = readFileSync(resolve(currentPath), "utf8");
  let previousChecks = [];
  if (previousJson) {
    previousChecks = JSON.parse(previousJson);
  } else if (previousPath) {
    previousChecks = parseChecks(readFileSync(resolve(previousPath), "utf8"));
  }
  const result = evaluateCheckFreeze({ previousChecks, currentText });
  console.log(JSON.stringify(result, null, 2));
  process.exit(result.ok ? 0 : 1);
}

const isMain =
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) main(process.argv);
