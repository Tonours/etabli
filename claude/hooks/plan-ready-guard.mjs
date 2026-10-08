import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const REMEDY =
  "repair the Etabli install with scripts/deploy-agent-workflow --apply from the etabli checkout, then check /hooks";

function readInput() {
  try {
    return JSON.parse(readFileSync(0, "utf8") || "{}") || {};
  } catch {
    return {};
  }
}

function projectRoot(cwd) {
  try {
    return execFileSync("git", ["-C", cwd, "rev-parse", "--show-toplevel"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim() || cwd;
  } catch {
    return cwd;
  }
}

function guardExpected(input) {
  const cwd = input.cwd || process.cwd();
  if (existsSync(join(cwd, "PLAN.md")) || existsSync(join(projectRoot(cwd), "PLAN.md"))) return true;
  const command = String(input.tool_input?.command ?? input.tool_input?.cmd ?? "");
  return /\b(?:push|rm)\b/.test(command);
}

function emit(decision) {
  process.stdout.write(`${JSON.stringify(decision)}\n`);
}

const input = readInput();

try {
  const lib = await import("./workflow-router-lib.mjs");
  const decision = lib.planMutationGuardDecision(input) || lib.planCommitGuardDecision(input);
  if (decision) emit(decision);
} catch (error) {
  const reason = `plan-ready-guard failed (${error?.message ?? error}); ${REMEDY}.`;
  if (guardExpected(input)) {
    emit({
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: reason,
      },
    });
  } else {
    process.stderr.write(`${reason}\n`);
  }
}
