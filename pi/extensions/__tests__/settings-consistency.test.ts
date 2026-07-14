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
    const [name, source, piCore, codexVisible, locked] = line.split("\t");
    return { name, source, piCore: piCore === "1", codexVisible: codexVisible === "1", locked: locked === "1" };
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

  test("keeps Codex-visible skill lists synchronized across bootstrap scripts", () => {
    const scripts = [installScript, deployAgentWorkflowScript, checkFixSymlinksScript];
    for (const source of scripts) expect(source).toContain("skill_catalog_names");

    const piSkills = skillCatalog.filter((skill) => skill.source === "pi" && skill.codexVisible).map((skill) => skill.name);
    const codexSkills = skillCatalog.filter((skill) => skill.source === "codex" && skill.codexVisible).map((skill) => skill.name);
    expect(piSkills.every((skill) => (localPackage().skills ?? []).includes(skill))).toBe(true);
    expect(codexSkills).toEqual([
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

    expect(packageBySource("npm:@tintinweb/pi-subagents")).toMatchObject({
      source: "npm:@tintinweb/pi-subagents",
    });

    expect(packageBySource("npm:@tintinweb/pi-tasks")).toMatchObject({
      source: "npm:@tintinweb/pi-tasks",
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
  });
});
