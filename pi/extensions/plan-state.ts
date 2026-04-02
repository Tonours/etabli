import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import {
  parseImplementationTracking,
  summarizeImplementationTracking,
  updateImplementationTracking,
  type PlanTrackingState,
} from "./lib/plan-state.ts";

function planPath(cwd: string): string {
  return join(cwd, "PLAN.md");
}

function readPlan(cwd: string): { path: string; content: string } {
  const path = planPath(cwd);
  if (!existsSync(path)) {
    throw new Error("Missing PLAN.md in current working directory");
  }
  return { path, content: readFileSync(path, "utf-8") };
}

function toPatch(args: {
  activeSlice?: string;
  completedSlices?: string[];
  pendingChecks?: string[];
  lastValidatedState?: string;
  nextRecommendedAction?: string;
}): Partial<PlanTrackingState> {
  const patch: Partial<PlanTrackingState> = {};

  if (typeof args.activeSlice === "string") {
    patch["Active slice"] = [args.activeSlice];
  }
  if (Array.isArray(args.completedSlices)) {
    patch["Completed slices"] = args.completedSlices;
  }
  if (Array.isArray(args.pendingChecks)) {
    patch["Pending checks"] = args.pendingChecks;
  }
  if (typeof args.lastValidatedState === "string") {
    patch["Last validated state"] = [args.lastValidatedState];
  }
  if (typeof args.nextRecommendedAction === "string") {
    patch["Next recommended action"] = [args.nextRecommendedAction];
  }

  return patch;
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "plan_state_read",
    label: "Plan State Read",
    description:
      "Read the current PLAN.md implementation-tracking state for the active cwd. Useful for seeing the active slice, completed slices, pending checks, and next recommended action.",
    parameters: Type.Object({}),
    async execute(_toolCallId, _args, _signal, _onUpdate, ctx) {
      try {
        const plan = readPlan(ctx.cwd);
        const state = parseImplementationTracking(plan.content);
        return {
          content: [{ type: "text" as const, text: summarizeImplementationTracking(state) }],
          details: { path: plan.path, state },
        };
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        return {
          content: [{ type: "text" as const, text: `Error: ${message}` }],
          details: { error: message },
        };
      }
    },
  });

  pi.registerTool({
    name: "plan_state_update",
    label: "Plan State Update",
    description:
      "Update the Implementation Tracking section of the current PLAN.md. Use this to keep active slice, completed slices, pending checks, last validated state, and next recommended action in sync during slice-driven execution.",
    parameters: Type.Object({
      activeSlice: Type.Optional(Type.String({ description: "Replacement value for Active slice" })),
      completedSlices: Type.Optional(Type.Array(Type.String(), { description: "Replacement list for Completed slices" })),
      pendingChecks: Type.Optional(Type.Array(Type.String(), { description: "Replacement list for Pending checks" })),
      lastValidatedState: Type.Optional(Type.String({ description: "Replacement value for Last validated state" })),
      nextRecommendedAction: Type.Optional(Type.String({ description: "Replacement value for Next recommended action" })),
    }),
    async execute(_toolCallId, args, _signal, _onUpdate, ctx) {
      try {
        const plan = readPlan(ctx.cwd);
        const patch = toPatch(args);
        const nextContent = updateImplementationTracking(plan.content, patch);
        writeFileSync(plan.path, nextContent, "utf-8");
        const state = parseImplementationTracking(nextContent);
        return {
          content: [{ type: "text" as const, text: summarizeImplementationTracking(state) }],
          details: { path: plan.path, state },
        };
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        return {
          content: [{ type: "text" as const, text: `Error: ${message}` }],
          details: { error: message },
        };
      }
    },
  });

  pi.registerCommand("plan-state", {
    description: "Show the current PLAN.md implementation-tracking state",
    handler: async (_args, ctx) => {
      try {
        const plan = readPlan(ctx.cwd);
        const state = parseImplementationTracking(plan.content);
        pi.sendMessage({
          customType: "plan-state",
          content: summarizeImplementationTracking(state),
          display: true,
        });
        ctx.ui.notify(`PLAN state loaded from ${plan.path}`, "info");
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        ctx.ui.notify(message, "error");
      }
    },
  });
}
