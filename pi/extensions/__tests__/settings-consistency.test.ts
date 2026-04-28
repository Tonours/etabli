import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";

type LocalPackage = {
  source: string;
  extensions?: string[];
  skills?: string[];
};

const settings = JSON.parse(
  readFileSync(new URL("../../agent/settings.json", import.meta.url), "utf-8"),
) as {
  packages: Array<string | LocalPackage>;
};

const installScript = readFileSync(new URL("../../../scripts/install.sh", import.meta.url), "utf-8");

function localPackage(): LocalPackage {
  const pkg = settings.packages.find((entry): entry is LocalPackage => {
    return typeof entry === "object" && entry !== null && entry.source === "local:etabli-workflow";
  });

  if (!pkg) throw new Error("local:etabli-workflow package missing");
  return pkg;
}

function installCoreSkills(): string[] {
  const match = installScript.match(/readonly PI_CORE_SKILLS=\(\n([\s\S]*?)\n\)/);
  if (!match) throw new Error("PI_CORE_SKILLS declaration missing");

  return [...match[1].matchAll(/"([^"]+)"/g)].map((item) => item[1]);
}

describe("Pi settings consistency", () => {
  test("loads the maintained local extension surface", () => {
    expect(localPackage().extensions).toEqual([
      "rtk.ts",
      "filter-output.ts",
      "block-google-providers.ts",
    ]);
  });

  test("keeps damage-control disabled by default", () => {
    expect(localPackage().extensions ?? []).not.toContain("damage-control.ts");
  });

  test("installer links every configured local skill", () => {
    expect(installCoreSkills().sort()).toEqual([...(localPackage().skills ?? [])].sort());
  });
});
