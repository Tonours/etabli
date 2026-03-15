import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { completeSimple } from "@mariozechner/pi-ai";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

type Entry = {
  type: string;
  summary?: string;
  message?: {
    role: string;
    content: unknown;
  };
};

const TEMPLATE_PATH = resolve(dirname(fileURLToPath(import.meta.url)), "../../claude/handoff-template.md");
const DEFAULT_HANDOFF_PATH = [".pi", "handoff.md"] as const;
const DEFAULT_IMPLEMENT_HANDOFF_PATH = [".pi", "handoff-implement.md"] as const;
const GENERIC_SYSTEM_PROMPT = "You create concise continuation handoffs for coding work. Do not continue the work. Only produce the handoff document.";
const IMPLEMENT_SYSTEM_PROMPT = "You create concise implementation continuation handoffs for coding work. Base the handoff on the existing READY plan and the current session state. Do not continue the work. Only produce the handoff document.";

type HandoffMode = "generic" | "implement";

type PlanInfo = {
  path: string;
  content: string;
  status: string | null;
};

function loadTemplate(): string {
  if (!existsSync(TEMPLATE_PATH)) {
    return [
      "# Handoff",
      "",
      "## Goal",
      "## Current State",
      "## Constraints",
      "## Decisions",
      "## Open Issues",
      "## Next Steps",
      "## References",
    ].join("\n");
  }
  return readFileSync(TEMPLATE_PATH, "utf-8").trim();
}

function extractTextContent(content: unknown): string {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";

  const parts: string[] = [];
  for (const block of content) {
    if (!block || typeof block !== "object") continue;
    const typedBlock = block as { type?: string; text?: string; name?: string };
    if (typedBlock.type === "text" && typedBlock.text) {
      parts.push(typedBlock.text);
    }
    if (typedBlock.type === "toolCall" && typedBlock.name) {
      parts.push(`[tool:${typedBlock.name}]`);
    }
  }
  return parts.join("\n");
}

function serializeEntries(entries: Entry[]): string {
  const parts: string[] = [];

  for (const entry of entries) {
    if (entry.type === "branch_summary" && entry.summary) {
      parts.push(`[Branch summary]\n${entry.summary}`);
      continue;
    }

    if (entry.type !== "message" || !entry.message) continue;
    const role = entry.message.role;
    const text = extractTextContent(entry.message.content).trim();
    if (!text) continue;

    if (role === "user") parts.push(`[User]\n${text}`);
    if (role === "assistant") parts.push(`[Assistant]\n${text}`);
    if (role === "toolResult") parts.push(`[Tool]\n${text}`);
  }

  return parts.join("\n\n");
}

function trimConversation(text: string, contextWindow?: number): string {
  const windowSize = contextWindow ?? 128000;
  const reserveTokens = 8192;
  const maxChars = Math.max(4000, (windowSize - reserveTokens) * 4);
  return text.length > maxChars ? text.slice(-maxChars) : text;
}

function resolveOutputPath(cwd: string, arg: string, mode: HandoffMode): string {
  if (!arg.trim()) {
    const parts = mode === "implement" ? DEFAULT_IMPLEMENT_HANDOFF_PATH : DEFAULT_HANDOFF_PATH;
    return join(cwd, ...parts);
  }
  if (arg.startsWith("/")) return arg;
  return join(cwd, arg);
}

function extractPlanStatus(content: string): string | null {
  const match = content.match(/^- Status:\s*(.+)$/m);
  return match?.[1]?.trim() ?? null;
}

function loadPlan(cwd: string): PlanInfo | null {
  const path = join(cwd, "PLAN.md");
  if (!existsSync(path)) return null;

  const content = readFileSync(path, "utf-8").trim();
  return { path, content, status: extractPlanStatus(content) };
}

function buildPrompt(template: string, conversation: string, mode: HandoffMode, plan: PlanInfo | null): string {
  const parts = ["Use this template exactly as the section structure:", template];

  if (mode === "implement") {
    parts.push(
      "",
      "Implementation continuation rules:",
      "- Base the handoff on the existing READY PLAN.md and current implementation state.",
      "- Focus on the next bounded implementation steps, validation state, blockers, and exact files/commands.",
      "- Do not rewrite the full plan unless it is needed to continue.",
    );

    if (plan) {
      parts.push("", `PLAN.md (${plan.path}):`, `<plan>\n${plan.content}\n</plan>`);
    }
  }

  parts.push("", "Conversation:", `<conversation>\n${conversation}\n</conversation>`);
  return parts.join("\n");
}

function systemPromptFor(mode: HandoffMode): string {
  return mode === "implement" ? IMPLEMENT_SYSTEM_PROMPT : GENERIC_SYSTEM_PROMPT;
}

function commandDescription(mode: HandoffMode): string {
  return mode === "implement"
    ? "Create or refresh a plan-aware implementation continuation handoff document"
    : "Create or refresh a continuation handoff document";
}

function commandName(mode: HandoffMode): string {
  return mode === "implement" ? "handoff-implement" : "handoff";
}

export default function (pi: ExtensionAPI) {
  for (const mode of ["generic", "implement"] as const) {
    pi.registerCommand(commandName(mode), {
      description: commandDescription(mode),
      handler: async (args, ctx) => {
        await ctx.waitForIdle();

        if (!ctx.model) {
          ctx.ui.notify("No active model", "error");
          return;
        }

        const apiKey = await ctx.modelRegistry.getApiKey(ctx.model);
        if (!apiKey) {
          ctx.ui.notify(`No API key for ${ctx.model.provider}`, "error");
          return;
        }

        const entries = ctx.sessionManager.getBranch() as Entry[];
        const serialized = serializeEntries(entries);
        if (!serialized.trim()) {
          ctx.ui.notify("No session content to summarize", "warning");
          return;
        }

        const plan = mode === "implement" ? loadPlan(ctx.cwd) : null;
        if (mode === "implement") {
          if (!plan) {
            ctx.ui.notify("Missing PLAN.md. Run /skill:plan or /skill:plan-review first", "error");
            return;
          }
          if (plan.status !== "READY") {
            ctx.ui.notify(`PLAN.md is ${plan.status ?? "missing status"}. Re-establish READY before handoff`, "error");
            return;
          }
        }

        const outputPath = resolveOutputPath(ctx.cwd, args.trim(), mode);
        const prompt = buildPrompt(loadTemplate(), trimConversation(serialized, ctx.model.contextWindow), mode, plan);

        try {
          const response = await completeSimple(
            ctx.model,
            {
              systemPrompt: systemPromptFor(mode),
              messages: [
                {
                  role: "user" as const,
                  content: [{ type: "text", text: prompt }],
                  timestamp: Date.now(),
                },
              ],
            },
            { apiKey, maxTokens: 4096 },
          );

          if (response.stopReason === "error") {
            ctx.ui.notify(`Handoff failed: ${response.errorMessage || "unknown error"}`, "error");
            return;
          }

          const handoff = response.content
            .filter((block): block is { type: "text"; text: string } => block.type === "text")
            .map((block) => block.text)
            .join("\n")
            .trim();

          if (!handoff) {
            ctx.ui.notify("No handoff generated", "error");
            return;
          }

          mkdirSync(dirname(outputPath), { recursive: true });
          writeFileSync(outputPath, `${handoff}\n`, "utf-8");
          ctx.ui.notify(`Handoff written to ${outputPath}`, "success");
        } catch (error) {
          const message = error instanceof Error ? error.message : String(error);
          ctx.ui.notify(`Handoff failed: ${message}`, "error");
        }
      },
    });
  }
}
