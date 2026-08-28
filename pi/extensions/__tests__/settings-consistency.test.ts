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

const installScript = readFileSync(
  new URL("../../../scripts/lib/install-main.sh", import.meta.url),
  "utf-8",
);
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
    return {
      name,
      source,
      piCore: piCore === "1",
      agentsVisible: agentsVisible === "1",
      locked: locked === "1",
    };
  });

function localPackage(): LocalPackage {
  const pkg = packageBySource("local:etabli-workflow");
  if (!pkg) throw new Error("local:etabli-workflow package missing");
  return pkg;
}

function packageBySource(source: string): LocalPackage | undefined {
  return settings.packages.find((entry): entry is LocalPackage => {
    return (
      typeof entry === "object" && entry !== null && entry.source === source
    );
  });
}

function installCoreSkills(): string[] {
  return skillCatalog
    .filter((skill) => skill.source === "pi" && skill.piCore)
    .map((skill) => skill.name);
}

function packageSources(): string[] {
  return settings.packages.map((entry) =>
    typeof entry === "string" ? entry : entry.source,
  );
}

describe("Pi settings consistency", () => {
  test("quasi-vanilla local package has skills only (no extensions)", () => {
    expect(localPackage().extensions).toEqual([]);
    expect(localPackage().extensions ?? []).not.toContain("damage-control.ts");
  });

  test("installer links every configured local skill", () => {
    expect(installCoreSkills().sort()).toEqual(
      [...(localPackage().skills ?? [])].sort(),
    );
  });

  test("keeps agents-visible skill lists synchronized across bootstrap scripts", () => {
    const scripts = [
      installScript,
      deployAgentWorkflowScript,
      checkFixSymlinksScript,
    ];
    for (const source of scripts)
      expect(source).toContain("skill_catalog_names");

    const agentsVisible = skillCatalog.filter((skill) => skill.agentsVisible);
    expect(agentsVisible.every((skill) => skill.source === "pi")).toBe(true);

    const coreVisible = agentsVisible
      .filter((skill) => skill.piCore)
      .map((skill) => skill.name);
    expect(
      coreVisible.every((skill) =>
        (localPackage().skills ?? []).includes(skill),
      ),
    ).toBe(true);

    const packVisible = agentsVisible
      .filter((skill) => !skill.piCore)
      .map((skill) => skill.name);
    expect(packVisible).toEqual(["runtime-skill-canary"]);
    // Fluidity: caveman stays optional (not piCore, not agents-visible);
    // grill-me, coolify, and project-hunt are promoted piCore skills (tsv 1/1/1).
    expect(skillCatalog.find((s) => s.name === "caveman")?.piCore).toBe(false);
    expect(skillCatalog.find((s) => s.name === "grill-me")?.piCore).toBe(true);
    expect(skillCatalog.find((s) => s.name === "project-hunt")?.piCore).toBe(true);

    const keepList = [
      "plan-loop",
      "plan-implement",
      "adversary",
      "review",
      "code-quality",
      "implement",
      "verify",
      "bug-check",
      "linear-ticket-create",
      "linear-work",
      "pr-review",
      "pr-qa",
      "sec-pr",
      "ci-fix",
      "coolify",
      "grill-me",
      "project-hunt",
      "thermo-nuclear-code-quality-review",
    ];
    expect(installCoreSkills().sort()).toEqual([...keepList].sort());
    expect([...(localPackage().skills ?? [])].sort()).toEqual(
      [...keepList].sort(),
    );
    expect(coreVisible.sort()).toEqual(
      keepList.filter((skill) => skill !== "code-quality").sort(),
    );
    expect(
      skillCatalog.find((skill) => skill.name === "code-quality"),
    ).toMatchObject({
      piCore: true,
      agentsVisible: false,
    });
    expect(keepList).toHaveLength(18);
    for (const banned of ["ponytail", "deslop", "code-simplifier"]) {
      expect(skillCatalog.some((skill) => skill.name === banned)).toBe(false);
      expect(localPackage().skills ?? []).not.toContain(banned);
    }
  });

  test("loads only the quasi-vanilla Pi package surface", () => {
    const sources = packageSources();

    // Present
    expect(packageBySource("npm:mitsupi")).toMatchObject({
      extensions: [],
      skills: ["github", "commit"],
      prompts: [],
      themes: [],
    });
    expect(packageBySource("local:etabli-workflow")).toBeDefined();
    expect(packageBySource("git:github.com/badlogic/pi-skills")).toMatchObject({
      extensions: [],
      skills: ["brave-search"],
      prompts: [],
      themes: [],
    });
    expect(sources).toContain("npm:@tintinweb/pi-tasks@0.7.1");

    // Removed from quasi-vanilla profile
    expect(packageBySource("npm:pi-hooks")).toBeUndefined();
    expect(packageBySource("npm:glimpseui")).toBeUndefined();
    expect(packageBySource("npm:pi-interview")).toBeUndefined();
    expect(
      packageBySource("npm:@tintinweb/pi-subagents@0.13.0"),
    ).toBeUndefined();
    expect(settings.packages).not.toContain(
      "https://github.com/davebcn87/pi-autoresearch",
    );
    expect(settings.packages).not.toContain("npm:glimpseui");
    expect(packageBySource("npm:@agwab/pi-workflow@0.8.1")).toBeUndefined();
    expect(packageBySource("npm:@agwab/pi-workflow")).toBeUndefined();

    // Install/deploy scripts manage the pin set and purge legacy sources
    expect(installScript).toContain("npm:@tintinweb/pi-tasks@0.7.1");
    expect(deployAgentWorkflowScript).toContain(
      "npm:@tintinweb/pi-tasks@0.7.1",
    );
    expect(installScript).toContain('"npm:mitsupi"');
    expect(installScript).not.toContain('"npm:@tintinweb/pi-subagents@0.13.0"');
    // Legacy purge list still names dropped packages so local settings are cleaned
    expect(installScript).toContain('"npm:pi-hooks"');
    expect(installScript).toContain('"npm:glimpseui"');
    expect(installScript).not.toContain('"npm:@agwab/pi-workflow@0.8.1",');
    expect(deployAgentWorkflowScript).not.toContain(
      '"npm:@agwab/pi-workflow@0.8.1",',
    );
  });

  test("enables the exact managed model set without retired aliases", () => {
    const enabledModels = (
      settings as typeof settings & { enabledModels: string[] }
    ).enabledModels;

    expect(enabledModels).toContain("zai/glm-5.3");
    expect(enabledModels).toContain("zai/glm-5.2");
    expect(enabledModels).toContain("opencode-go/minimax-m3");
    expect(enabledModels).toContain("opencode-go/qwen3.7-plus");
    expect(enabledModels).toContain("github-copilot/claude-sonnet-5");
    // Bare alias retired; exact L/T/S pins stay managed.
    expect(enabledModels).not.toContain("openai-codex/gpt-5.6");
    expect(enabledModels).not.toContain("opencode-go/kimi-k2.6");
    expect(enabledModels).not.toContain("kimi-coding/kimi-for-coding");
    expect(enabledModels).not.toContain("github-copilot/claude-opus-4.7");
    expect(enabledModels).not.toContain("github-copilot/claude-sonnet-4.6");
    expect(enabledModels).not.toContain("opencode-go/minimax-m2.7");
    expect(enabledModels).not.toContain("opencode-go/qwen3.6-plus");
    expect(enabledModels.some((model) => model.startsWith("local-mlx/"))).toBe(
      false,
    );
  });

  test("keeps the default model selectable", () => {
    const typed = settings as typeof settings & {
      enabledModels: string[];
      defaultProvider: string;
      defaultModel: string;
    };
    expect(typed.enabledModels).toContain(
      `${typed.defaultProvider}/${typed.defaultModel}`,
    );
  });
});
