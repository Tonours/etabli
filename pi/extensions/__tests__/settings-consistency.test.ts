import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";

type LocalPackage = {
  source: string;
  extensions?: string[];
  skills?: string[];
  prompts?: string[];
  themes?: string[];
};

const settings = JSON.parse(
  readFileSync(new URL("../../agent/settings.json", import.meta.url), "utf-8"),
) as {
  packages: Array<string | LocalPackage>;
};

const installScript = readFileSync(new URL("../../../scripts/lib/install-main.sh", import.meta.url), "utf-8");
const deployAgentWorkflowScript = readFileSync(
  new URL("../../../scripts/deploy-agent-workflow", import.meta.url),
  "utf-8",
);
const checkFixSymlinksScript = readFileSync(
  new URL("../../../scripts/check-fix-symlinks.sh", import.meta.url),
  "utf-8",
);
const skillCatalog = readFileSync(
  new URL("../../../workflow/runtime/skill-surface.tsv", import.meta.url),
  "utf-8",
)
  .split("\n")
  .filter((line) => line && !line.startsWith("#"))
  .map((line) => {
    const [name, source, piCore, agentsVisible, locked] = line.split("\t");
    return { name, source, piCore: piCore === "1", agentsVisible: agentsVisible === "1", locked: locked === "1" };
  });

function localPackage(): LocalPackage {
  const pkg = packageBySource("local:etabli-workflow");
  if (!pkg) throw new Error("local:etabli-workflow package missing");
  return pkg;
}

function packageBySource(source: string): LocalPackage | undefined {
  return settings.packages.find((entry): entry is LocalPackage => {
    return typeof entry === "object" && entry !== null && entry.source === source;
  });
}

function installCoreSkills(): string[] {
  return skillCatalog.filter((skill) => skill.source === "pi" && skill.piCore).map((skill) => skill.name);
}

describe("Pi settings consistency", () => {
  test("loads the maintained local extension surface", () => {
    expect(localPackage().extensions).toEqual([
      "rtk.ts",
      "filter-output.ts",
      "block-google-providers.ts",
      "prefer-ipv4-dns.ts",
      "workflow-router.ts",
      "tasks-till-done.ts",
    ]);
  });

  test("keeps damage-control disabled by default", () => {
    expect(localPackage().extensions ?? []).not.toContain("damage-control.ts");
  });

  test("installer links every configured local skill", () => {
    expect(installCoreSkills().sort()).toEqual([...(localPackage().skills ?? [])].sort());
  });

  test("keeps agents-visible skill lists synchronized across bootstrap scripts", () => {
    const scripts = [installScript, deployAgentWorkflowScript, checkFixSymlinksScript];
    for (const source of scripts) expect(source).toContain("skill_catalog_names");

    const agentsVisible = skillCatalog.filter((skill) => skill.agentsVisible);
    expect(agentsVisible.every((skill) => skill.source === "pi")).toBe(true);

    const coreVisible = agentsVisible.filter((skill) => skill.piCore).map((skill) => skill.name);
    expect(coreVisible.every((skill) => (localPackage().skills ?? []).includes(skill))).toBe(true);

    const packVisible = agentsVisible.filter((skill) => !skill.piCore).map((skill) => skill.name);
    expect(packVisible).toEqual([
      "browser-full-page-capture",
      "frontend-motion-performance",
      "goal-prompt-rewriter",
      "ui-reference-capture",
    ]);
  });

  test("loads only the curated third-party Pi package surface", () => {
    expect(settings.packages).not.toContain("npm:pi-interview");
    expect(settings.packages).not.toContain("https://github.com/davebcn87/pi-autoresearch");
    expect(settings.packages).not.toContain("npm:glimpseui");

    expect(packageBySource("npm:pi-hooks")).toMatchObject({
      extensions: ["lsp/lsp.ts", "lsp/lsp-tool.ts"],
      skills: [],
      prompts: [],
      themes: [],
    });

    expect(packageBySource("npm:mitsupi")).toMatchObject({
      extensions: [],
      skills: ["github", "commit"],
      prompts: [],
      themes: [],
    });

    expect(packageBySource("git:github.com/badlogic/pi-skills")).toMatchObject({
      extensions: [],
      skills: ["brave-search"],
      prompts: [],
      themes: [],
    });

    expect(packageBySource("npm:pi-interview")).toMatchObject({
      extensions: ["index.ts"],
      skills: [],
      prompts: [],
      themes: [],
    });

    expect(packageBySource("npm:glimpseui")).toMatchObject({
      extensions: [],
      skills: [],
      prompts: [],
      themes: [],
    });

    expect(packageBySource("npm:@tintinweb/pi-subagents@0.13.0")).toMatchObject({
      source: "npm:@tintinweb/pi-subagents@0.13.0",
    });

    expect(packageBySource("npm:@tintinweb/pi-tasks@0.7.1")).toMatchObject({
      source: "npm:@tintinweb/pi-tasks@0.7.1",
    });

    expect(packageBySource("npm:@agwab/pi-workflow@0.8.1")).toMatchObject({
      extensions: ["src/extension.ts"],
      skills: ["workflow-guide", "execution-router"],
      prompts: [],
      themes: [],
    });
    expect(packageBySource("npm:@agwab/pi-workflow")).toBeUndefined();
    expect(installScript).toContain("npm:@agwab/pi-workflow@0.8.1");
    expect(deployAgentWorkflowScript).toContain("npm:@agwab/pi-workflow@0.8.1");
    expect(installScript).toContain("npm:@tintinweb/pi-subagents@0.13.0");
    expect(installScript).toContain("npm:@tintinweb/pi-tasks@0.7.1");
  });

  test("enables the exact managed model portfolio without retired aliases", () => {
    const enabledModels = (settings as typeof settings & { enabledModels: string[] }).enabledModels;

    expect(enabledModels).toContain("zai/glm-5.2");
    expect(enabledModels).toContain("zai/glm-5.1");
    expect(enabledModels).toContain("zai/glm-5-turbo");
    expect(enabledModels).toContain("xai/grok-4.5");
    expect(enabledModels).toContain("kimi-coding/k3");
    expect(enabledModels).toContain("opencode-go/minimax-m3");
    expect(enabledModels).toContain("opencode-go/qwen3.7-plus");
    expect(enabledModels).toContain("github-copilot/claude-sonnet-5");
    expect(enabledModels).toContain("github-copilot/claude-sonnet-4.6");
    expect(enabledModels).not.toContain("openai-codex/gpt-5.6-luna");
    expect(enabledModels).not.toContain("openai-codex/gpt-5.6-terra");
    expect(enabledModels).not.toContain("openai-codex/gpt-5.6-sol");
    expect(enabledModels).not.toContain("openai-codex/gpt-5.6");
    expect(enabledModels).not.toContain("opencode-go/kimi-k2.6");
    expect(enabledModels).not.toContain("kimi-coding/kimi-for-coding");
    expect(enabledModels).not.toContain("github-copilot/claude-opus-4.7");
    expect(enabledModels).not.toContain("opencode-go/minimax-m2.7");
    expect(enabledModels).not.toContain("opencode-go/qwen3.6-plus");
    expect(enabledModels.some((model) => model.startsWith("local-mlx/"))).toBe(false);
  });
});
