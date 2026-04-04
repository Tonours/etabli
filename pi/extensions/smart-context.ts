import type { ExtensionAPI, ToolCallEvent } from "@mariozechner/pi-coding-agent";
import { isToolCallEventType } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

function getHomeDir(): string {
  return process.env.HOME || process.env.USERPROFILE || homedir();
}

interface PatternEntry {
  pattern: string;
  context: string;
  successCount: number;
  lastUsed: string;
}

export interface ProjectPatterns {
  cwd: string;
  commonTasks: PatternEntry[];
  filePatterns: string[];
  toolUsage: Record<string, number>;
  lastUpdated: string;
}

const PATTERNS_DIR = join(getHomeDir(), ".pi", "patterns");

function getPatternsPath(cwd: string): string {
  const sanitized = cwd.replace(/[^a-zA-Z0-9._-]+/g, "_");
  return join(PATTERNS_DIR, `${sanitized}.json`);
}

export function readProjectPatterns(cwd: string): ProjectPatterns | null {
  const path = getPatternsPath(cwd);
  if (!existsSync(path)) return null;

  try {
    return JSON.parse(readFileSync(path, "utf-8")) as ProjectPatterns;
  } catch {
    return null;
  }
}

function writeProjectPatterns(patterns: ProjectPatterns): void {
  mkdirSync(PATTERNS_DIR, { recursive: true });
  writeFileSync(getPatternsPath(patterns.cwd), JSON.stringify(patterns, null, 2), "utf-8");
}

export function extractFilePatterns(files: string[]): string[] {
  const extensions = new Map<string, number>();
  const directories = new Map<string, number>();

  for (const file of files) {
    const ext = file.split(".").pop();
    if (ext && ext.length < 10) {
      extensions.set(ext, (extensions.get(ext) || 0) + 1);
    }

    const [dir] = file.split("/");
    if (dir && dir !== file) {
      directories.set(dir, (directories.get(dir) || 0) + 1);
    }
  }

  const topDirs = [...directories.entries()].sort((a, b) => b[1] - a[1]).slice(0, 3).map(([dir]) => `${dir}/`);
  const topExts = [...extensions.entries()].sort((a, b) => b[1] - a[1]).slice(0, 3).map(([ext]) => `*.${ext}`);
  return [...topDirs, ...topExts];
}

export function suggestNextTools(patterns: ProjectPatterns, currentPhase: string): string[] {
  const suggestions: string[] = [];
  if (currentPhase === "planning") {
    suggestions.push("plan_state_read", "tilldone");
  } else if (currentPhase === "implementation") {
    suggestions.push("read", "edit", "validate");
  } else if (currentPhase === "review") {
    suggestions.push("review_state_read", "review_to_tilldone");
  }

  const topTools = Object.entries(patterns.toolUsage)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([tool]) => tool);

  return [...new Set([...suggestions, ...topTools])].slice(0, 5);
}

function filePathFromEvent(event: ToolCallEvent): string | null {
  if (isToolCallEventType("read", event) || isToolCallEventType("write", event) || isToolCallEventType("edit", event)) {
    return event.input.path;
  }
  return null;
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    const patterns = readProjectPatterns(ctx.cwd) || {
      cwd: ctx.cwd,
      commonTasks: [],
      filePatterns: [],
      toolUsage: {},
      lastUpdated: new Date().toISOString(),
    };

    patterns.toolUsage[event.toolName] = (patterns.toolUsage[event.toolName] || 0) + 1;
    const path = filePathFromEvent(event);
    if (path) {
      patterns.filePatterns = extractFilePatterns([...patterns.filePatterns, path]);
    }
    patterns.lastUpdated = new Date().toISOString();

    writeProjectPatterns(patterns);
    return { block: false };
  });

  pi.registerCommand("suggest", {
    description: "Show smart suggestions based on project history",
    handler: async (_args, ctx) => {
      const patterns = readProjectPatterns(ctx.cwd);
      if (!patterns) {
        ctx.ui.notify("No history yet for this project. Keep working to build patterns.", "info");
        return;
      }

      const topTools = Object.entries(patterns.toolUsage).sort((a, b) => b[1] - a[1]).slice(0, 5);
      const lines = ["Smart Suggestions", ""];

      if (topTools.length > 0) {
        lines.push("Frequently used tools:");
        for (const [tool, count] of topTools) {
          lines.push(`  - ${tool} (${count}x)`);
        }
        lines.push("");
      }

      if (patterns.filePatterns.length > 0) {
        lines.push("Common file patterns:");
        for (const pattern of patterns.filePatterns) {
          lines.push(`  - ${pattern}`);
        }
        lines.push("");
      }

      lines.push("Suggested next steps:", "  1. Check PLAN.md status with plan_state_read");
      if (patterns.toolUsage.tilldone) {
        lines.push("  2. Review active tasks with tilldone list");
      }
      if (patterns.toolUsage.validate) {
        lines.push("  3. Run validation before committing");
      }

      pi.sendMessage({ customType: "smart-suggestions", content: lines.join("\n"), display: true });
      ctx.ui.notify(`Suggestions based on ${Object.keys(patterns.toolUsage).length} tools used`, "info");
    },
  });

  pi.registerTool({
    name: "smart_suggest",
    label: "Smart Suggest",
    description: "Get suggestions based on project history and current context.",
    parameters: Type.Object({ context: Type.Optional(Type.String()) }),
    async execute(_toolCallId, args, _signal, _onUpdate, ctx) {
      const context = (args as { context?: string }).context || "general";
      const patterns = readProjectPatterns(ctx.cwd);
      if (!patterns) {
        return {
          content: [{ type: "text" as const, text: "No project history yet. Start with PLAN.md, TillDone, and validation." }],
          details: { hasHistory: false },
        };
      }

      const suggestions = suggestNextTools(patterns, context);
      return {
        content: [{ type: "text" as const, text: `Suggestions for ${context}:\n${suggestions.map((item, index) => `${index + 1}. ${item}`).join("\n")}` }],
        details: {
          hasHistory: true,
          suggestions,
          topTools: Object.entries(patterns.toolUsage).sort((a, b) => b[1] - a[1]).slice(0, 5),
        },
      };
    },
  });
}
