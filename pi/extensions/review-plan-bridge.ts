import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

function getHomeDir(): string {
  return process.env.HOME || process.env.USERPROFILE || homedir();
}

interface ReviewEntry {
  id: string;
  filePath: string;
  hunkHeader: string;
  status: "new" | "accepted" | "needs-rework" | "question" | "ignore";
  note: string | null;
  scope: "WORKING" | "STAGED" | "STALE";
  patchHash: string;
}

interface ReviewState {
  entries: ReviewEntry[];
  updatedAt: string;
}

export interface BridgeAction {
  type: "tilldone-task" | "plan-slice" | "pending-check";
  title: string;
  description: string;
  source: {
    filePath: string;
    hunkHeader: string;
    note: string | null;
  };
}

function sanitizeCwd(cwd: string): string {
  return cwd.replace(/[^a-zA-Z0-9._-]+/g, "_");
}

function getReviewStatePath(cwd: string): string {
  return join(getHomeDir(), ".local", "share", "nvim", "etabli", "review", `${sanitizeCwd(cwd)}.json`);
}

function getOpsStatusPath(cwd: string): string {
  return join(getHomeDir(), ".pi", "status", `${sanitizeCwd(cwd)}.ops.json`);
}

function readReviewState(cwd: string): ReviewState | null {
  const path = getReviewStatePath(cwd);
  if (!existsSync(path)) return null;

  try {
    return JSON.parse(readFileSync(path, "utf-8")) as ReviewState;
  } catch {
    return null;
  }
}

function readPlanContent(cwd: string): string | null {
  const path = join(cwd, "PLAN.md");
  return existsSync(path) ? readFileSync(path, "utf-8") : null;
}

export function buildBridgeActions(reviewState: ReviewState): BridgeAction[] {
  return reviewState.entries
    .filter((entry) => entry.status === "needs-rework" || entry.status === "question")
    .map((entry) => {
      const title = entry.note
        ? `${entry.filePath}: ${entry.note.slice(0, 50)}${entry.note.length > 50 ? "..." : ""}`
        : `Fix ${entry.filePath} - ${entry.hunkHeader.slice(0, 50)}`;

      return {
        type: "tilldone-task" as const,
        title,
        description: `Review ${entry.status}: ${entry.filePath}\nHunk: ${entry.hunkHeader}${entry.note ? `\nNote: ${entry.note}` : ""}`,
        source: {
          filePath: entry.filePath,
          hunkHeader: entry.hunkHeader,
          note: entry.note,
        },
      };
    });
}

export function generateTillDoneTasksFromReview(actions: BridgeAction[]): string[] {
  return actions.map((action) => action.title);
}

export function generatePlanSliceFromReview(actions: BridgeAction[]): string {
  if (actions.length === 0) return "";

  const lines = ["### Address Review Findings", ""];
  for (const [index, action] of actions.entries()) {
    lines.push(`${index + 1}. **${action.title}**`);
    lines.push(`   - File: \`${action.source.filePath}\``);
    lines.push(`   - Hunk: \`${action.source.hunkHeader}\``);
    if (action.source.note) lines.push(`   - Note: ${action.source.note}`);
    lines.push("");
  }

  lines.push("**Checks:**", "- [ ] All review comments addressed", "- [ ] Changes validated", "- [ ] Review inbox updated", "");
  return lines.join("\n");
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("review-to-tilldone", {
    description: "Convert review findings to TillDone tasks",
    handler: async (_args, ctx) => {
      const reviewState = readReviewState(ctx.cwd);
      if (!reviewState) {
        ctx.ui.notify("No review state found. Run review from Neovim first.", "warning");
        return;
      }

      const actions = buildBridgeActions(reviewState);
      if (actions.length === 0) {
        ctx.ui.notify("No actionable review items found.", "info");
        return;
      }

      const tasks = generateTillDoneTasksFromReview(actions);
      pi.sendMessage({
        customType: "review-bridge",
        content: `Ready to create ${tasks.length} task(s):\n\n${tasks.map((task, index) => `${index + 1}. ${task}`).join("\n")}`,
        display: true,
      });
      ctx.ui.notify(`${actions.length} review item(s) ready for TillDone`, "info");
    },
  });

  pi.registerCommand("review-to-plan", {
    description: "Convert review findings to a PLAN.md slice",
    handler: async (_args, ctx) => {
      const reviewState = readReviewState(ctx.cwd);
      if (!reviewState) {
        ctx.ui.notify("No review state found. Run review from Neovim first.", "warning");
        return;
      }
      if (!readPlanContent(ctx.cwd)) {
        ctx.ui.notify("No PLAN.md found. Create a plan first.", "warning");
        return;
      }

      const actions = buildBridgeActions(reviewState);
      if (actions.length === 0) {
        ctx.ui.notify("No actionable review items found.", "info");
        return;
      }

      pi.sendMessage({
        customType: "review-bridge",
        content: `Proposed PLAN.md slice:\n\n${generatePlanSliceFromReview(actions)}`,
        display: true,
      });
      ctx.ui.notify(`${actions.length} review item(s) ready for PLAN.md`, "info");
    },
  });

  pi.registerTool({
    name: "review_state_read",
    label: "Review State Read",
    description: "Read the current review state from the Neovim review inbox.",
    parameters: Type.Object({}),
    async execute(_toolCallId, _args, _signal, _onUpdate, ctx) {
      const reviewState = readReviewState(ctx.cwd);
      if (!reviewState) {
        return {
          content: [{ type: "text" as const, text: "No review state found." }],
          details: { found: false },
        };
      }

      const actionable = reviewState.entries.filter((entry) => entry.status === "needs-rework" || entry.status === "question");
      const summary = reviewState.entries.reduce<Record<string, number>>((acc, entry) => {
        acc[entry.status] = (acc[entry.status] || 0) + 1;
        return acc;
      }, {});

      return {
        content: [{ type: "text" as const, text: `Review entries: ${reviewState.entries.length}\nActionable: ${actionable.length}` }],
        details: {
          found: true,
          totalEntries: reviewState.entries.length,
          actionableCount: actionable.length,
          summary,
          actionable: actionable.map((entry) => ({
            filePath: entry.filePath,
            status: entry.status,
            note: entry.note,
            scope: entry.scope,
          })),
        },
      };
    },
  });

  pi.registerTool({
    name: "review_to_tilldone",
    label: "Review to TillDone",
    description: "Convert actionable review items to TillDone tasks.",
    parameters: Type.Object({}),
    async execute(_toolCallId, _args, _signal, _onUpdate, ctx) {
      const reviewState = readReviewState(ctx.cwd);
      if (!reviewState) {
        return {
          content: [{ type: "text" as const, text: "No review state found." }],
          details: { created: 0 },
        };
      }

      const tasks = generateTillDoneTasksFromReview(buildBridgeActions(reviewState));
      return {
        content: [{ type: "text" as const, text: tasks.length > 0 ? tasks.join("\n") : "No actionable review items found." }],
        details: { created: tasks.length, tasks },
      };
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    const opsPath = getOpsStatusPath(ctx.cwd);
    if (!existsSync(opsPath)) return;

    try {
      const ops = JSON.parse(readFileSync(opsPath, "utf-8")) as { plan?: { status?: string }; review?: { actionable?: number } };
      if (ops.plan?.status === "READY" && (ops.review?.actionable || 0) > 0) {
        pi.sendMessage({
          customType: "review-bridge-warning",
          content: `Review inbox has ${ops.review?.actionable} actionable item(s). Use /review-to-tilldone to turn them into tasks.`,
          display: true,
        });
      }
    } catch {
      return;
    }
  });
}
