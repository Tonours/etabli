/// <reference path="./bun-test.d.ts" />
import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import {
  RUNTIME_STATUS_VERSION,
  normalizeRuntimeStatus,
  parseRuntimeStatus,
  validateRuntimeStatus,
} from "../lib/runtime-status.ts";

const VALID_RUNTIME_FIXTURE = readFileSync(new URL("./fixtures/runtime-status-valid.json", import.meta.url), "utf-8");

describe("normalizeRuntimeStatus", () => {
  test("adds the current schema version", () => {
    expect(
      normalizeRuntimeStatus({
        project: "etabli",
        cwd: "/tmp/etabli",
        phase: "idle",
        thinking: "off",
        updatedAt: "2026-03-30T10:00:00.000Z",
      }),
    ).toEqual({
      version: RUNTIME_STATUS_VERSION,
      project: "etabli",
      cwd: "/tmp/etabli",
      phase: "idle",
      tool: undefined,
      model: undefined,
      thinking: "off",
      updatedAt: "2026-03-30T10:00:00.000Z",
    });
  });
});

describe("validateRuntimeStatus", () => {
  test("accepts the current schema", () => {
    const result = validateRuntimeStatus({
      version: RUNTIME_STATUS_VERSION,
      project: "etabli",
      cwd: "/tmp/etabli",
      phase: "running",
      tool: "read",
      model: "gpt-5-mini",
      thinking: "medium",
      updatedAt: "2026-03-30T10:00:00.000Z",
    });

    expect(result.ok).toBe(true);
    expect(result.errors).toEqual([]);
    expect(result.value?.version).toBe(RUNTIME_STATUS_VERSION);
  });

  test("accepts legacy payloads without a version", () => {
    const result = validateRuntimeStatus({
      project: "etabli",
      cwd: "/tmp/etabli",
      phase: "idle",
      thinking: "off",
      updatedAt: "2026-03-30T10:00:00.000Z",
    });

    expect(result.ok).toBe(true);
    expect(result.value?.version).toBe(RUNTIME_STATUS_VERSION);
  });

  test("rejects invalid payloads with clear errors", () => {
    const result = validateRuntimeStatus({
      version: 99,
      project: "",
      cwd: 42,
      phase: "busy",
      tool: 7,
      model: false,
      thinking: "",
      updatedAt: "",
    });

    expect(result.ok).toBe(false);
    expect(result.errors).toEqual([
      `Runtime status version must be ${RUNTIME_STATUS_VERSION}`,
      "Runtime status project must be a non-empty string",
      "Runtime status cwd must be a non-empty string",
      "Runtime status phase must be one of: idle, running, offline",
      "Runtime status tool must be a string when present",
      "Runtime status model must be a string when present",
      "Runtime status thinking must be a non-empty string",
      "Runtime status updatedAt must be a non-empty string",
    ]);
  });
});

describe("parseRuntimeStatus", () => {
  test("parses and validates JSON content", () => {
    const result = parseRuntimeStatus(VALID_RUNTIME_FIXTURE);

    expect(result.ok).toBe(true);
    expect(result.value?.phase).toBe("running");
    expect(result.value?.version).toBe(RUNTIME_STATUS_VERSION);
  });

  test("reports invalid JSON", () => {
    expect(parseRuntimeStatus("not-json")).toEqual({
      ok: false,
      errors: ["Runtime status is not valid JSON"],
      value: null,
    });
  });
});
