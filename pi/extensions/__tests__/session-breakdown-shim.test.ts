/// <reference path="./bun-test.d.ts" />
import { describe, expect, test } from "bun:test";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const TEST_DIR = dirname(fileURLToPath(import.meta.url));

describe("session-breakdown shim", () => {
  test("disables the mitsupi package version in repo settings", () => {
    const settingsPath = new URL("../../agent/settings.json", import.meta.url);
    const settings = JSON.parse(readFileSync(settingsPath, "utf-8")) as {
      packages?: Array<string | { source?: string; extensions?: string[] }>;
    };

    const mitsupiEntry = settings.packages?.find(
      (entry): entry is { source?: string; extensions?: string[] } =>
        typeof entry === "object" && entry !== null && entry.source === "npm:mitsupi",
    );

    expect(mitsupiEntry?.extensions).toContain("-pi-extensions/session-breakdown.ts");
  });

  test("ships a local override extension", async () => {
    const file = join(TEST_DIR, "..", "session-breakdown.ts");
    expect(existsSync(file)).toBe(true);

    const mod = await import("../session-breakdown.ts");
    expect(typeof mod.default).toBe("function");
  });
});
