import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";

const PLAN_FILE_PATTERN = /\bPLAN[\w.-]*\.md\b/;
const GIT_COMMIT_PATTERN = /\bgit\b[^|;&]*\bcommit\b/;
const GIT_ADD_PATTERN = /\bgit\b[^|;&]*\badd\b/;

function deny(reason) {
  return {
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: reason,
    },
  };
}

function stagedPlanFiles(cwd) {
  try {
    const output = execFileSync("git", ["-C", cwd, "diff", "--cached", "--name-only"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    });
    return output.split("\n").filter((line) => /^PLAN[\w.-]*\.md$/.test(line));
  } catch {
    return [];
  }
}

function planCommitGuardDecision(event) {
  if (event.tool_name !== "Bash") return null;
  const command = String(event.tool_input?.command || "");
  if (!/\bgit\b/.test(command)) return null;

  const namesPlanFile = PLAN_FILE_PATTERN.test(command);
  if (namesPlanFile && (GIT_ADD_PATTERN.test(command) || GIT_COMMIT_PATTERN.test(command))) {
    return deny(
      "PLAN files are session artifacts and must not be staged or committed; archive to docs/plan/ instead. Run git yourself to bypass deliberately.",
    );
  }

  if (GIT_COMMIT_PATTERN.test(command)) {
    const staged = stagedPlanFiles(event.cwd || process.cwd());
    if (staged.length > 0) {
      return deny(
        `PLAN files are session artifacts and must not be committed (staged: ${staged.join(", ")}); unstage them or archive to docs/plan/ first.`,
      );
    }
  }

  return null;
}

const input = JSON.parse(readFileSync(0, "utf8") || "{}");
const decision = planCommitGuardDecision(input);
if (decision) {
  process.stdout.write(`${JSON.stringify(decision)}\n`);
}
