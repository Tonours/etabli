/// <reference path="./bun-test.d.ts" />
import { describe, expect, test } from "bun:test";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  FALLBACK_MODEL,
  mergeSubagentExtensionPaths,
  readDefaultModelSpec,
  resolveSubagentModel,
} from "../lib/pi-runtime.ts";

describe("readDefaultModelSpec", () => {
  test("reads default provider/model from settings", () => {
    const dir = mkdtempSync(join(tmpdir(), "pi-runtime-"));
    const file = join(dir, "settings.json");
    writeFileSync(
      file,
      JSON.stringify({ defaultProvider: "openai-codex", defaultModel: "gpt-5.4" }),
      "utf-8",
    );

    expect(readDefaultModelSpec(file)).toBe("openai-codex/gpt-5.4");
  });

  test("falls back when settings are invalid", () => {
    const dir = mkdtempSync(join(tmpdir(), "pi-runtime-"));
    const file = join(dir, "settings.json");
    writeFileSync(file, "not-json", "utf-8");

    expect(readDefaultModelSpec(file, FALLBACK_MODEL)).toBe(FALLBACK_MODEL);
  });
});

describe("mergeSubagentExtensionPaths", () => {
  test("dedupes while preserving order", () => {
    expect(
      mergeSubagentExtensionPaths(["worker-a", "shared"], ["safe-a", "shared", "safe-b"]),
    ).toEqual(["worker-a", "shared", "safe-a", "safe-b"]);
  });
});

describe("resolveSubagentModel", () => {
  test("prefers explicit override first", () => {
    expect(
      resolveSubagentModel({
        override: "anthropic/claude-sonnet-4-6",
        currentModel: "openai-codex/gpt-5.4",
        fallback: FALLBACK_MODEL,
      }),
    ).toBe("anthropic/claude-sonnet-4-6");
  });

  test("falls back to current model before settings", () => {
    expect(
      resolveSubagentModel({
        currentModel: "openai-codex/gpt-5.4",
        fallback: FALLBACK_MODEL,
      }),
    ).toBe("openai-codex/gpt-5.4");
  });

  test("uses settings default when no override or current model exists", () => {
    const dir = mkdtempSync(join(tmpdir(), "pi-runtime-"));
    const file = join(dir, "settings.json");
    writeFileSync(
      file,
      JSON.stringify({ defaultProvider: "github-copilot", defaultModel: "gpt-5.3-codex" }),
      "utf-8",
    );

    expect(
      resolveSubagentModel({
        settingsPath: file,
        fallback: FALLBACK_MODEL,
      }),
    ).toBe("github-copilot/gpt-5.3-codex");
  });

  test("uses hard fallback when settings are missing", () => {
    expect(
      resolveSubagentModel({
        settingsPath: join(tmpdir(), "missing-pi-settings.json"),
        fallback: FALLBACK_MODEL,
      }),
    ).toBe(FALLBACK_MODEL);
  });
});
