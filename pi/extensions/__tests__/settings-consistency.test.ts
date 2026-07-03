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

const installScript = readFileSync(new URL("../../../scripts/install.sh", import.meta.url), "utf-8");
const deployAgentWorkflowScript = readFileSync(
  new URL("../../../scripts/deploy-agent-workflow", import.meta.url),
  "utf-8",
);
const checkFixSymlinksScript = readFileSync(
  new URL("../../../scripts/check-fix-symlinks.sh", import.meta.url),
  "utf-8",
);

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
  return shellArray(installScript, "PI_CORE_SKILLS");
}

function shellArray(source: string, name: string): string[] {
  const match = source.match(new RegExp(`(?:readonly\\s+)?${name}=\\(\\n([\\s\\S]*?)\\n\\)`));
  if (!match) throw new Error(`${name} declaration missing`);

  return [...match[1].matchAll(/"([^"]+)"/g)].map((item) => item[1]);
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
    const piSkillLists = scripts.map((source) => shellArray(source, "CODEX_VISIBLE_PI_SKILLS"));
    const codexSkillLists = scripts.map((source) => shellArray(source, "CODEX_VISIBLE_CODEX_SKILLS"));

    expect(piSkillLists[1]).toEqual(piSkillLists[0]);
    expect(piSkillLists[2]).toEqual(piSkillLists[0]);
    expect(codexSkillLists[1]).toEqual(codexSkillLists[0]);
    expect(codexSkillLists[2]).toEqual(codexSkillLists[0]);
    expect(piSkillLists[0].every((skill) => (localPackage().skills ?? []).includes(skill))).toBe(true);
    expect(codexSkillLists[0]).toEqual(["goal-prompt-rewriter"]);
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
  });
});
