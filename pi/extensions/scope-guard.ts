import type { ExtensionAPI, ToolCallEvent } from "@mariozechner/pi-coding-agent";
import { isToolCallEventType } from "@mariozechner/pi-coding-agent";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

interface PlanScope {
  goal: string;
  nonGoals: string[];
  slices: string[];
  files: string[];
  invariants: string[];
}

export interface ScopeCheck {
  type: "warning" | "error" | "info";
  message: string;
  suggestion: string;
}

export function readPlanScope(cwd: string): PlanScope | null {
  const planPath = join(cwd, "PLAN.md");
  if (!existsSync(planPath)) return null;

  const content = readFileSync(planPath, "utf-8");
  const goal = content.match(/## Goal\s*\n([^#]*)/)?.[1]?.trim() || "";
  const slices = [...content.matchAll(/###\s+(.+)/g)].map((match) => match[1].trim());
  const files = [...content.matchAll(/[\s`](?:\.\/)?([\w./-]+\.(?:ts|js|tsx|jsx|lua|md|json))/g)]
    .map((match) => match[1])
    .filter((value, index, list) => list.indexOf(value) === index);

  const parseList = (section: string) => {
    const block = content.match(new RegExp(`## ${section}\\s*\\n([^#]*)`))?.[1];
    if (!block) return [] as string[];
    return block
      .split("\n")
      .map((line) => line.trim().replace(/^[-*]\s*/, ""))
      .filter((line) => line !== "" && !line.startsWith("(none)"))
      .map((line) => line.toLowerCase());
  };

  return {
    goal,
    nonGoals: parseList("Non-goals"),
    slices,
    files,
    invariants: parseList("Invariants"),
  };
}

export function checkForScopeCreep(event: ToolCallEvent, scope: PlanScope): ScopeCheck[] {
  const checks: ScopeCheck[] = [];

  if (isToolCallEventType("write", event) || isToolCallEventType("edit", event)) {
    const path = event.input.path.toLowerCase();
    const planned = scope.files.some((file) => path.includes(file.toLowerCase()) || file.toLowerCase().includes(path));
    if (!planned && scope.files.length > 0) {
      checks.push({
        type: "warning",
        message: `Editing unplanned file: ${event.input.path}`,
        suggestion: "Update PLAN.md file scope or keep the change out of this slice.",
      });
    }

    const content = isToolCallEventType("write", event)
      ? event.input.content.toLowerCase()
      : event.input.newText.toLowerCase();

    for (const nonGoal of scope.nonGoals) {
      const keywords = nonGoal.split(/\s+/).filter((word) => word.length > 4);
      if (keywords.some((keyword) => content.includes(keyword))) {
        checks.push({
          type: "warning",
          message: `Content may touch non-goal: \"${nonGoal}\"`,
          suggestion: "Verify this change still matches PLAN.md.",
        });
        break;
      }
    }
  }

  if (isToolCallEventType("bash", event)) {
    const command = event.input.command;
    if (/rm\s+-rf|find\b.*\b-delete\b|git\s+reset\b.*--hard/.test(command)) {
      checks.push({
        type: "error",
        message: "Destructive command detected",
        suggestion: "Verify the plan explicitly allows this command before you continue.",
      });
    }
    if (/sed\s+-i\s+.*\*\./.test(command)) {
      checks.push({
        type: "warning",
        message: "Mass file modification detected",
        suggestion: "Consider a separate slice for broad edits.",
      });
    }
  }

  return checks;
}

const editCounts = new Map<string, number>();

function buildEditKey(cwd: string, path: string): string {
  return `${cwd}:${path}`;
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    const planPath = join(ctx.cwd, "PLAN.md");
    if (!existsSync(planPath)) {
      return { block: false };
    }

    const status = readFileSync(planPath, "utf-8").match(/^- Status:\s*(.+)$/m)?.[1]?.trim();
    if (status !== "READY") {
      return { block: false };
    }

    const scope = readPlanScope(ctx.cwd);
    if (!scope) {
      return { block: false };
    }

    const checks = checkForScopeCreep(event, scope);
    if (isToolCallEventType("write", event) || isToolCallEventType("edit", event)) {
      const editKey = buildEditKey(ctx.cwd, event.input.path);
      const count = (editCounts.get(editKey) || 0) + 1;
      editCounts.set(editKey, count);
      if (count === 5) {
        checks.push({
          type: "warning",
          message: `File ${event.input.path} has been edited 5 times`,
          suggestion: "Pause and check whether the slice needs a plan update.",
        });
      }
    }

    if (checks.length > 0) {
      const lines = ["Scope check warnings:"];
      for (const check of checks.slice(0, 3)) {
        lines.push(`- ${check.message}`);
        lines.push(`  -> ${check.suggestion}`);
      }
      pi.sendMessage({ customType: "scope-guard", content: lines.join("\n"), display: true });
    }

    return { block: false };
  });

  pi.on("session_start", async (_event, ctx) => {
    for (const key of editCounts.keys()) {
      if (key.startsWith(`${ctx.cwd}:`)) {
        editCounts.delete(key);
      }
    }
  });

  pi.registerCommand("scope-check", {
    description: "Check current work against PLAN.md scope",
    handler: async (_args, ctx) => {
      const scope = readPlanScope(ctx.cwd);
      if (!scope) {
        ctx.ui.notify("No PLAN.md found or scope could not be parsed.", "warning");
        return;
      }

      const lines = ["Plan Scope Summary", "", `Goal: ${scope.goal || "none"}`, ""];
      if (scope.nonGoals.length > 0) {
        lines.push("Non-goals:", ...scope.nonGoals.map((item) => `  - ${item}`), "");
      }
      if (scope.slices.length > 0) {
        lines.push("Slices:", ...scope.slices.slice(0, 5).map((slice, index) => `  ${index + 1}. ${slice}`), "");
      }
      if (scope.files.length > 0) {
        lines.push("Planned files:", ...scope.files.slice(0, 5).map((file) => `  - ${file}`));
      }

      pi.sendMessage({ customType: "scope-summary", content: lines.join("\n"), display: true });
      ctx.ui.notify(`Scope loaded: ${scope.slices.length} slices, ${scope.files.length} files`, "info");
    },
  });
}
