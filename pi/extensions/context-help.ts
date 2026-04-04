import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export interface HelpTopic {
  id: string;
  trigger: string[];
  title: string;
  content: string;
  relatedCommands: string[];
}

export const HELP_TOPICS: HelpTopic[] = [
  {
    id: "getting-started",
    trigger: ["start", "begin", "help", "new"],
    title: "Getting Started",
    content: [
      "Welcome to the Pi + Claude + Neovim workflow.",
      "",
      "Quick start:",
      "1. Check current status: /health",
      "2. View TillDone tasks: tilldone list",
      "3. Switch project: /switch <name>",
      "4. Use template: /template-use new-feature",
    ].join("\n"),
    relatedCommands: ["/health", "/templates", "/switch"],
  },
  {
    id: "planning",
    trigger: ["plan", "draft", "ready"],
    title: "Planning Phase",
    content: [
      "Planning workflow:",
      "1. Create PLAN.md with goal, scope, and slices",
      "2. Status: DRAFT -> plan-review -> READY",
      "3. Never implement from DRAFT or CHALLENGED",
    ].join("\n"),
    relatedCommands: ["plan_state_read", "validate", "/scope-check"],
  },
  {
    id: "implementation",
    trigger: ["implement", "code", "edit", "write"],
    title: "Implementation Phase",
    content: [
      "Implementation workflow:",
      "1. Ensure PLAN.md is READY",
      "2. Mark the active slice in TillDone",
      "3. Make the smallest useful change",
      "4. Run slice-local checks",
      "5. Validate with /validate",
    ].join("\n"),
    relatedCommands: ["/validate", "/snapshots", "tilldone"],
  },
  {
    id: "review",
    trigger: ["review", "check", "verify", "quality"],
    title: "Review Phase",
    content: [
      "Review workflow:",
      "1. Read review state",
      "2. Mark issues clearly",
      "3. Convert blockers with /review-to-tilldone",
      "4. Fix them one by one",
    ].join("\n"),
    relatedCommands: ["review_state_read", "/review-to-tilldone", "/review-to-plan"],
  },
  {
    id: "handoff",
    trigger: ["handoff", "resume", "continue", "pause"],
    title: "Handoff & Resume",
    content: [
      "Handoff workflow:",
      "- /fast-handoff for quick local handoff",
      "- /fast-handoff-implement for READY work",
      "- /resume-from-handoff to rebuild tasks",
    ].join("\n"),
    relatedCommands: ["/fast-handoff", "/resume-from-handoff", "/handoff"],
  },
  {
    id: "troubleshooting",
    trigger: ["error", "fail", "broken", "issue", "problem"],
    title: "Troubleshooting",
    content: [
      "When things go wrong:",
      "1. Run /health",
      "2. Check the OPS snapshot",
      "3. Validate PLAN.md",
      "4. Check /error-status",
    ].join("\n"),
    relatedCommands: ["/health", "/error-status", "/snapshots"],
  },
];

function getStatusFile(cwd: string, suffix: string): string {
  const sanitized = cwd.replace(/[^a-zA-Z0-9._-]+/g, "_");
  return join(getHomeDir(), ".pi", "status", `${sanitized}.${suffix}`);
}

export function detectContext(cwd: string): string {
  const planPath = join(cwd, "PLAN.md");
  if (!existsSync(planPath)) {
    return "getting-started";
  }

  const content = readFileSync(planPath, "utf-8");
  const status = content.match(/^- Status:\s*(.+)$/m)?.[1]?.trim();
  if (status === "DRAFT" || status === "CHALLENGED") {
    return "planning";
  }
  if (status === "READY" && /Active slice:\s*(?!none)/i.test(content)) {
    return "implementation";
  }
  if (status === "READY") {
    return "planning";
  }

  return "getting-started";
}

export function findHelpTopic(query: string): HelpTopic | null {
  const normalized = query.trim().toLowerCase();
  if (!normalized) return null;

  for (const topic of HELP_TOPICS) {
    if (topic.id === normalized) return topic;
  }

  const matches = HELP_TOPICS.flatMap((topic) =>
    topic.trigger
      .filter((trigger) => normalized.includes(trigger))
      .map((trigger) => ({ topic, triggerLength: trigger.length })),
  ).sort((a, b) => b.triggerLength - a.triggerLength);

  return matches[0]?.topic || null;
}

function getHomeDir(): string {
  return process.env.HOME || process.env.USERPROFILE || homedir();
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    const hasPlan = existsSync(join(ctx.cwd, "PLAN.md"));
    const hasTillDone = existsSync(getStatusFile(ctx.cwd, "tilldone-ops.json"));
    if (hasPlan || hasTillDone) return;

    const topic = HELP_TOPICS[0];
    pi.sendMessage({
      customType: "context-help",
      content: `📖 ${topic.title}\n${topic.content}`,
      display: true,
    });
    ctx.ui.notify("New project detected. Run /help for the workflow guide.", "info");
  });

  pi.registerCommand("help", {
    description: "Show contextual help",
    handler: async (args, ctx) => {
      const query = args.trim();
      if (query) {
        const topic = findHelpTopic(query);
        if (!topic) {
          ctx.ui.notify("No help found. Try planning, implementation, review, or handoff.", "warning");
          return;
        }

        pi.sendMessage({
          customType: "context-help",
          content: `📖 ${topic.title}\n${topic.content}\n\nRelated: ${topic.relatedCommands.join(", ")}`,
          display: true,
        });
        return;
      }

      const topic = HELP_TOPICS.find((entry) => entry.id === detectContext(ctx.cwd)) || HELP_TOPICS[0];
      pi.sendMessage({
        customType: "context-help",
        content: [
          `📖 ${topic.title} (auto-detected)`,
          topic.content,
          "",
          `Available topics: ${HELP_TOPICS.map((entry) => entry.id).join(", ")}`,
          "Use /help <topic> for specific guidance",
        ].join("\n"),
        display: true,
      });
    },
  });

  pi.registerTool({
    name: "help_get",
    label: "Help Get",
    description: "Get contextual help for the current workflow state or a specific topic.",
    parameters: Type.Object({ topic: Type.Optional(Type.String()) }),
    async execute(_toolCallId, args, _signal, _onUpdate, ctx) {
      const query = (args as { topic?: string }).topic;
      const topic = query ? findHelpTopic(query) : HELP_TOPICS.find((entry) => entry.id === detectContext(ctx.cwd));

      if (!topic) {
        return {
          content: [{ type: "text" as const, text: `Topic not found. Available: ${HELP_TOPICS.map((entry) => entry.id).join(", ")}` }],
          details: { found: false, available: HELP_TOPICS.map((entry) => entry.id) },
        };
      }

      return {
        content: [{ type: "text" as const, text: `${topic.title}\n${topic.content}` }],
        details: {
          found: true,
          topic: topic.id,
          autoDetected: !query,
          relatedCommands: topic.relatedCommands,
        },
      };
    },
  });
}
