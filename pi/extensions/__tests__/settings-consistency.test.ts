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

const modelRouting = JSON.parse(
  readFileSync(new URL("../../../workflow/runtime/model-routing.json", import.meta.url), "utf-8"),
) as {
  pi_enabled_models: string[];
  pi_default: string;
  models: Record<string, { provider: string; model: string }>;
};

const installScript = readFileSync(
  new URL("../../../scripts/lib/install-main.sh", import.meta.url),
  "utf-8",
);
const deployAgentWorkflowScript = readFileSync(
  new URL("../../../scripts/deploy-agent-workflow", import.meta.url),
  "utf-8",
);
const settingsSyncModule = readFileSync(
  new URL("../../../scripts/lib/pi-agent-settings-sync.mjs", import.meta.url),
  "utf-8",
);
const skillCatalog = readFileSync(
  new URL("../../../workflow/runtime/skill-surface.tsv", import.meta.url),
  "utf-8",
)
  .split("\n")
  .filter((line) => line && !line.startsWith("#"))
  .map((line) => {
    const [name, source, piCore, locked] = line.split("\t");
    return {
      name,
      source,
      piCore: piCore === "1",
      locked: locked === "1",
    };
  });

function packageBySource(source: string): LocalPackage | undefined {
  return settings.packages.find((entry): entry is LocalPackage => {
    return (
      typeof entry === "object" && entry !== null && entry.source === source
    );
  });
}

function installCoreSkills(): string[] {
  return skillCatalog
    .filter((skill) => skill.source === "etabli" && skill.piCore)
    .map((skill) => skill.name.split("/")[1]);
}

function packageSources(): string[] {
  return settings.packages.map((entry) =>
    typeof entry === "string" ? entry : entry.source,
  );
}

describe("Pi settings consistency", () => {
  test("Pi first-party skills come from the catalog, not a settings keeper list", () => {
    expect(packageBySource("local:etabli-workflow")).toBeUndefined();
    expect(settingsSyncModule).toContain('"local:etabli-workflow"');
  });

  test("keeps the Pi core skill list synchronized across bootstrap scripts", () => {
    expect(deployAgentWorkflowScript).toContain("skillRecords(repoDir)");
    expect(installScript).toContain('"$BOOTSTRAP_DIR/deploy-agent-workflow" --apply');

    for (const shelved of ["coolify", "react-doctor-100"]) {
      expect(skillCatalog.find((s) => s.name === shelved)).toMatchObject({
        source: "extras",
        piCore: false,
      });
    }

    const keepList = [
      "plan-loop",
      "plan-implement",
      "adversary",
      "review",
      "code-quality",
      "implement",
      "verify-workflow",
      "bug-check",
      "linear-ticket-create",
      "linear-work",
      "write-direct",
      "thermo-nuclear-code-quality-review",
    ];
    expect(installCoreSkills().sort()).toEqual([...keepList].sort());
    expect(
      skillCatalog.find((skill) => skill.name === "shared/code-quality"),
    ).toMatchObject({ piCore: true });
    expect(keepList).toHaveLength(12);
    for (const banned of ["ponytail", "deslop", "code-simplifier"]) {
      expect(installCoreSkills()).not.toContain(banned);
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
    expect(packageBySource("git:github.com/badlogic/pi-skills")).toMatchObject({
      extensions: [],
      skills: [],
      prompts: [],
      themes: [],
    });
    expect(sources).toContain("npm:@tintinweb/pi-tasks@0.7.1");
    expect(packageBySource("npm:@tintinweb/pi-tasks@0.7.1")?.skills).toEqual(
      [],
    );
    for (const silenced of [
      "npm:pi-autoresearch",
      "npm:pi-cursor-sdk",
      "npm:@narumitw/pi-goal",
      "npm:pi-lens",
      "npm:pi-simplify",
    ]) {
      expect(packageBySource(silenced)?.skills).toEqual([]);
    }
    expect(packageBySource("npm:pi-mcp-adapter")?.skills).toEqual([
      "mcp-scripting",
    ]);
    expect(packageBySource("npm:@zenspc/pi-pstack")).toBeUndefined();
    expect(packageBySource("npm:pi-subagents")?.skills).toEqual([]);

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

    // Installer delegates surface convergence; deploy owns settings synchronization.
    expect(installScript).toContain('"$BOOTSTRAP_DIR/deploy-agent-workflow" --apply');
    expect(deployAgentWorkflowScript).toContain("pi-agent-settings-sync.mjs");
    expect(settingsSyncModule).not.toContain('"npm:pi-subagents",');
    expect(settingsSyncModule).toContain('"npm:@tintinweb/pi-subagents",');
    expect(settingsSyncModule).toContain('"npm:pi-hooks",');
    expect(settingsSyncModule).not.toContain('"npm:@agwab/pi-workflow@0.8.1",');
  });

  test("enables the exact managed model set without retired aliases", () => {
    const enabledModels = (
      settings as typeof settings & { enabledModels: string[] }
    ).enabledModels;

    const expected = modelRouting.pi_enabled_models.map((key) => {
      const model = modelRouting.models[key];
      return `${model.provider}/${model.model}`;
    });
    expect(enabledModels).toEqual(expected);
    expect(enabledModels).toEqual(["zai/glm-5.3", "zai/glm-5.3-flash"]);
    expect(enabledModels.every((model) => model.startsWith("zai/"))).toBe(true);
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
    const model = modelRouting.models[modelRouting.pi_default];
    expect(typed.defaultProvider).toBe(model.provider);
    expect(typed.defaultModel).toBe(model.model);
  });
});
