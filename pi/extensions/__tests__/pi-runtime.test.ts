/// <reference path="./bun-test.d.ts" />
import { describe, expect, test } from "bun:test";
import { mkdtempSync, statSync, utimesSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  FALLBACK_MODEL,
  FALLBACK_THINKING,
  mergeSubagentExtensionPaths,
  readDefaultModelSpec,
  resetRuntimeCaches,
  resolveSubagentModel,
  resolveSubagentThinking,
} from "../lib/pi-runtime.ts";

describe("readDefaultModelSpec", () => {
  test("reads default provider/model from settings", () => {
    resetRuntimeCaches();
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
    resetRuntimeCaches();
    const dir = mkdtempSync(join(tmpdir(), "pi-runtime-"));
    const file = join(dir, "settings.json");
    writeFileSync(file, "not-json", "utf-8");

    expect(readDefaultModelSpec(file, FALLBACK_MODEL)).toBe(FALLBACK_MODEL);
  });

  test("invalidates cached settings after file changes even when mtime stays the same", () => {
    resetRuntimeCaches();
    const dir = mkdtempSync(join(tmpdir(), "pi-runtime-"));
    const file = join(dir, "settings.json");
    writeFileSync(file, JSON.stringify({ defaultProvider: "openai-codex", defaultModel: "gpt-5.4" }), "utf-8");
    const initialStats = statSync(file);

    expect(readDefaultModelSpec(file)).toBe("openai-codex/gpt-5.4");

    writeFileSync(file, JSON.stringify({ defaultProvider: "github-copilot", defaultModel: "claude-sonnet-4.6" }), "utf-8");
    utimesSync(file, new Date(initialStats.mtimeMs), new Date(initialStats.mtimeMs));

    expect(readDefaultModelSpec(file)).toBe("github-copilot/claude-sonnet-4.6");
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

  test("uses role settings before current model", () => {
    const dir = mkdtempSync(join(tmpdir(), "pi-runtime-"));
    const file = join(dir, "settings.json");
    writeFileSync(
      file,
      JSON.stringify({
        subagents: {
          scout: { model: "kimi-coding/k2p5", thinking: "high" },
        },
      }),
      "utf-8",
    );

    expect(
      resolveSubagentModel({
        role: "scout",
        currentModel: "openai-codex/gpt-5.4",
        settingsPath: file,
        fallback: FALLBACK_MODEL,
      }),
    ).toBe("kimi-coding/k2p5");
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

describe("resolveSubagentThinking", () => {
  test("uses role-specific thinking when configured", () => {
    const dir = mkdtempSync(join(tmpdir(), "pi-runtime-"));
    const file = join(dir, "settings.json");
    writeFileSync(
      file,
      JSON.stringify({
        subagents: {
          reviewer: { model: "github-copilot/claude-sonnet-4.6", thinking: "high" },
        },
      }),
      "utf-8",
    );

    expect(resolveSubagentThinking({ role: "reviewer", settingsPath: file })).toBe("high");
  });

  test("falls back to off when role thinking is absent", () => {
    expect(
      resolveSubagentThinking({
        role: "worker",
        settingsPath: join(tmpdir(), "missing-pi-settings.json"),
        fallback: FALLBACK_THINKING,
      }),
    ).toBe("off");
  });
});
