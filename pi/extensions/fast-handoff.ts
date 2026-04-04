import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { readOpsSnapshotForCwd } from "./lib/ops-snapshot.ts";

const DEFAULT_HANDOFF_PATH = [".pi", "handoff.md"] as const;
const DEFAULT_IMPLEMENT_HANDOFF_PATH = [".pi", "handoff-implement.md"] as const;

interface FastHandoffData {
  goal: string;
  currentState: string;
  activeSlice: string | null;
  completedSlices: string[];
  pendingChecks: string[];
  lastValidatedState: string | null;
  nextRecommendedAction: string | null;
  planStatus: string | null;
  reviewActionable: number;
  mode: string;
  lifecycleState: string;
}

export function readPlanContent(cwd: string): string | null {
  const path = join(cwd, "PLAN.md");
  if (!existsSync(path)) return null;
  return readFileSync(path, "utf-8");
}

export function extractGoalFromPlan(content: string): string {
  const match = content.match(/## Goal\s*\n([^#]*)/);
  return match?.[1]?.trim() || "Continue current implementation";
}

export function extractConstraintsFromPlan(content: string): string[] {
  const constraints: string[] = [];
  const match = content.match(/## Constraints\s*\n([^#]*)/);
  if (match?.[1]) {
    const lines = match[1].trim().split("\n");
    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed && !trimmed.startsWith("- (none)")) {
        constraints.push(trimmed.replace(/^-\s*/, ""));
      }
    }
  }
  return constraints.length > 0 ? constraints : ["Follow existing code patterns", "Keep changes minimal"];
}

export function extractDecisionsFromPlan(content: string): string[] {
  const decisions: string[] = [];
  const match = content.match(/## Decisions\s*\n([^#]*)/);
  if (match?.[1]) {
    const lines = match[1].trim().split("\n");
    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed && !trimmed.startsWith("- (none)") && trimmed.includes(":")) {
        decisions.push(trimmed.replace(/^-\s*/, ""));
      }
    }
  }
  return decisions;
}

export function extractOpenIssuesFromPlan(content: string): string[] {
  const issues: string[] = [];
  const match = content.match(/## Open Issues\s*\n([^#]*)/);
  if (match?.[1]) {
    const lines = match[1].trim().split("\n");
    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed && !trimmed.startsWith("- (none)")) {
        issues.push(trimmed.replace(/^-\s*/, ""));
      }
    }
  }
  return issues;
}

export function buildFastHandoff(data: FastHandoffData, planContent: string | null): string {
  const lines: string[] = [];
  
  lines.push("# Handoff");
  lines.push("");
  lines.push("## Goal");
  lines.push(planContent ? extractGoalFromPlan(planContent) : data.goal);
  lines.push("");
  
  lines.push("## Current State");
  lines.push(`- Lifecycle: ${data.lifecycleState}`);
  lines.push(`- Mode: ${data.mode}`);
  lines.push(`- Plan status: ${data.planStatus || "unknown"}`);
  if (data.reviewActionable > 0) {
    lines.push(`- Review: ${data.reviewActionable} actionable items`);
  }
  lines.push("");
  
  lines.push("## Implementation State");
  lines.push(`- Active slice: ${data.activeSlice || "none"}`);
  lines.push(`- Completed slices: ${data.completedSlices.length > 0 ? data.completedSlices.join(", ") : "none"}`);
  lines.push(`- Pending checks: ${data.pendingChecks.length > 0 ? data.pendingChecks.join(", ") : "none"}`);
  lines.push(`- Last validated state: ${data.lastValidatedState || "unknown"}`);
  lines.push(`- Next recommended action: ${data.nextRecommendedAction || "Review current state"}`);
  lines.push("");
  
  if (planContent) {
    const constraints = extractConstraintsFromPlan(planContent);
    if (constraints.length > 0) {
      lines.push("## Constraints");
      for (const c of constraints) lines.push(`- ${c}`);
      lines.push("");
    }
    
    const decisions = extractDecisionsFromPlan(planContent);
    if (decisions.length > 0) {
      lines.push("## Decisions");
      for (const d of decisions) lines.push(`- ${d}`);
      lines.push("");
    }
    
    const issues = extractOpenIssuesFromPlan(planContent);
    lines.push("## Open Issues");
    if (issues.length > 0) {
      for (const i of issues) lines.push(`- ${i}`);
    } else {
      lines.push("- (none)");
    }
    lines.push("");
  }
  
  lines.push("## Next Steps");
  if (data.nextRecommendedAction) {
    lines.push(`1. ${data.nextRecommendedAction}`);
    lines.push(`2. ${data.pendingChecks.length > 0 ? `Run pending checks: ${data.pendingChecks[0]}` : "Validate and continue to next slice"}`);
  } else if (data.pendingChecks.length > 0) {
    lines.push(`1. Run pending checks: ${data.pendingChecks[0]}`);
    lines.push("2. Continue implementation or handoff");
  } else if (data.planStatus === "READY" && !data.activeSlice) {
    lines.push("1. Select next slice to implement");
    lines.push("2. Mark slice active in PLAN.md");
  } else {
    lines.push("1. Review current state");
    lines.push("2. Determine next bounded action");
  }
  lines.push("");
  
  lines.push("## References");
  lines.push("- `./PLAN.md` - Execution contract");
  lines.push("- `~/.pi/status/<cwd>.ops.json` - Runtime snapshot");
  if (data.planStatus) {
    lines.push(`- Status: ${data.planStatus}, Mode: ${data.mode}`);
  }
  lines.push("");
  
  lines.push("---");
  lines.push(`*Generated: ${new Date().toISOString()} | Fast-handoff (no LLM)*`);
  lines.push("");
  
  return lines.join("\n");
}

export function resolveOutputPath(cwd: string, arg: string, isImplement: boolean): string {
  if (!arg.trim()) {
    const parts = isImplement ? DEFAULT_IMPLEMENT_HANDOFF_PATH : DEFAULT_HANDOFF_PATH;
    return join(cwd, ...parts);
  }
  if (arg.startsWith("/")) return arg;
  return join(cwd, arg);
}

export function generateFastHandoff(cwd: string, isImplement: boolean): { content: string; data: FastHandoffData } | null {
  const snapshotResult = readOpsSnapshotForCwd(cwd);
  
  if (!snapshotResult.ok || !snapshotResult.value) {
    return null;
  }
  
  const snap = snapshotResult.value;
  const planContent = readPlanContent(cwd);
  
  const data: FastHandoffData = {
    goal: snap.task?.title || snap.project,
    currentState: snap.task?.lifecycleState || "unknown",
    activeSlice: snap.plan.activeSlice || snap.task?.activeSlice || null,
    completedSlices: snap.plan.completedSlices?.length ? snap.plan.completedSlices : snap.task?.completedSlices || [],
    pendingChecks: snap.plan.pendingChecks?.length ? snap.plan.pendingChecks : snap.task?.pendingChecks || [],
    lastValidatedState: snap.plan.lastValidatedState || snap.task?.lastValidatedState || null,
    nextRecommendedAction: snap.plan.nextRecommendedAction || snap.task?.nextAction || null,
    planStatus: snap.plan.status || snap.task?.planStatus || null,
    reviewActionable: snap.review.actionable,
    mode: snap.mode.mode,
    lifecycleState: snap.task?.lifecycleState || "unknown",
  };
  
  // For implement mode, require READY plan
  if (isImplement && data.planStatus !== "READY") {
    return null;
  }
  
  const content = buildFastHandoff(data, planContent);
  return { content, data };
}

export default function (pi: ExtensionAPI) {
  // Fast handoff - no LLM, local generation only
  pi.registerCommand("fast-handoff", {
    description: "Generate handoff instantly from local state (no LLM call)",
    handler: async (args, ctx) => {
      const outputPath = resolveOutputPath(ctx.cwd, args.trim(), false);
      
      const result = generateFastHandoff(ctx.cwd, false);
      if (!result) {
        ctx.ui.notify("Fast-handoff failed: no OPS snapshot available. Run /handoff for LLM fallback.", "warning");
        return;
      }
      
      mkdirSync(dirname(outputPath), { recursive: true });
      writeFileSync(outputPath, result.content, "utf-8");
      
      ctx.ui.notify(
        `Fast-handoff written to ${outputPath} (${result.data.completedSlices.length} slices done, ${result.data.pendingChecks.length} checks pending)`,
        "info"
      );
    },
  });
  
  // Fast implement handoff
  pi.registerCommand("fast-handoff-implement", {
    description: "Generate implementation handoff instantly from local state (requires READY plan, no LLM call)",
    handler: async (args, ctx) => {
      const outputPath = resolveOutputPath(ctx.cwd, args.trim(), true);
      
      const result = generateFastHandoff(ctx.cwd, true);
      if (!result) {
        const planContent = readPlanContent(ctx.cwd);
        const status = planContent?.match(/^- Status:\s*(.+)$/m)?.[1]?.trim();
        ctx.ui.notify(
          `Fast-handoff-implement requires READY plan (current: ${status || "missing"}). Run /handoff-implement for LLM fallback.`,
          "warning"
        );
        return;
      }
      
      mkdirSync(dirname(outputPath), { recursive: true });
      writeFileSync(outputPath, result.content, "utf-8");
      
      ctx.ui.notify(
        `Fast-handoff-implement written to ${outputPath} (active: ${result.data.activeSlice || "none"})`,
        "info"
      );
    },
  });
  
  // Auto-handoff on idle (configurable)
  pi.on("agent_end", async (_event, ctx) => {
    const autoHandoff = process.env.PI_AUTO_HANDOFF;
    if (autoHandoff !== "1" && autoHandoff !== "true") return;
    
    const result = generateFastHandoff(ctx.cwd, false);
    if (!result) return;
    
    // Only auto-generate if there's meaningful state
    if (result.data.completedSlices.length === 0 && !result.data.activeSlice) return;
    
    const outputPath = join(ctx.cwd, ...DEFAULT_HANDOFF_PATH);
    mkdirSync(dirname(outputPath), { recursive: true });
    writeFileSync(outputPath, result.content, "utf-8");
    
    ctx.ui.notify("Auto-handoff updated", "info");
  });
}
