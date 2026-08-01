import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";

type AgentFrontmatter = Record<string, string>;

const AGENTS = {
  "etabli-scout.md": {
    model: "opencode-go/deepseek-v4-flash",
    thinking: "medium",
    maxTurns: "12",
  },
  "etabli-analyst.md": {
    model: "openai-codex/gpt-5.6-terra",
    thinking: "high",
    maxTurns: "16",
  },
  "etabli-challenger.md": {
    model: "zai/glm-5.2",
    thinking: "xhigh",
    maxTurns: "16",
  },
  "etabli-judge.md": {
    model: "openai-codex/gpt-5.6-sol",
    thinking: "xhigh",
    maxTurns: "12",
  },
  "etabli-fallback.md": {
    model: "openai-codex/gpt-5.6-luna",
    thinking: "high",
    maxTurns: "12",
  },
} as const;

function read(relative: string): string {
  return readFileSync(new URL(relative, import.meta.url), "utf-8");
}

function frontmatter(content: string): AgentFrontmatter {
  const match = content.match(/^---\n([\s\S]*?)\n---\n/);
  if (!match) throw new Error("agent frontmatter missing");

  return Object.fromEntries(match[1].split("\n").map((line) => {
    const separator = line.indexOf(":");
    if (separator === -1) throw new Error(`invalid frontmatter line: ${line}`);
    return [line.slice(0, separator).trim(), line.slice(separator + 1).trim()];
  }));
}

describe("adaptive multi-model portfolio", () => {
  test("pins exact role models, effort, bounds, and read-only tools", () => {
    for (const [filename, expected] of Object.entries(AGENTS)) {
      const metadata = frontmatter(read(`../../agents/${filename}`));
      const tools = metadata.tools.split(",").map((tool) => tool.trim());

      expect(metadata.model).toBe(expected.model);
      expect(metadata.thinking).toBe(expected.thinking);
      expect(metadata.max_turns).toBe(expected.maxTurns);
      expect(metadata.extensions).toBe("false");
      expect(metadata.skills).toBe("false");
      expect(metadata.inherit_context).toBe("false");
      expect(metadata.run_in_background).toBe("true");
      expect(metadata.isolated).toBe("true");
      expect(tools.sort()).toEqual(["find", "grep", "ls", "read"]);
      expect(tools).not.toContain("bash");
      expect(tools).not.toContain("edit");
      expect(tools).not.toContain("write");
    }
  });

  test("maps provider-specific maximum thinking without allowing K3 downgrade", () => {
    const models = JSON.parse(read("../../models.json")) as {
      providers: Record<string, {
        models: Array<{
          id: string;
          api?: string;
          baseUrl?: string;
          headers?: Record<string, string>;
          contextWindow?: number;
          maxTokens?: number;
          thinkingLevelMap: Record<string, string | null>;
        }>;
      }>;
    };
    const glm = models.providers.zai.models.find((model) => model.id === "glm-5.2");
    const kimi = models.providers["kimi-coding"].models.find((model) => model.id === "k3");

    expect(glm?.thinkingLevelMap.xhigh).toBe("max");
    expect(kimi).toMatchObject({
      id: "k3",
      api: "anthropic-messages",
      baseUrl: "https://api.kimi.com/coding",
      headers: { "User-Agent": "KimiCLI/1.5" },
      contextWindow: 262144,
      maxTokens: 32768,
      thinkingLevelMap: {
        off: null,
        minimal: null,
        low: "low",
        medium: "high",
        high: "high",
        xhigh: "max",
      },
    });
  });

  test("uses bounded global subagent defaults", () => {
    const settings = JSON.parse(read("../../agent/subagents.json")) as Record<string, unknown>;

    expect(settings).toMatchObject({
      maxConcurrent: 3,
      defaultMaxTurns: 16,
      graceTurns: 2,
      defaultJoinMode: "smart",
      schedulingEnabled: false,
      scopeModels: true,
    });
  });
});
