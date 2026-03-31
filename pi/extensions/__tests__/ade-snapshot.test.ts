/// <reference path="./bun-test.d.ts" />
/// <reference path="../lib/node-runtime.d.ts" />
import { afterEach, describe, expect, test } from "bun:test";
import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import {
  ADE_SNAPSHOT_KIND,
  ADE_SNAPSHOT_VERSION,
  type AdeSnapshot,
  formatAdeReadError,
  formatAdeStatus,
  makeAdeSnapshotFile,
  normalizeAdeSnapshot,
  parseAdeSnapshot,
  readAdeSnapshotForCwd,
  validateAdeSnapshot,
} from "../lib/ade-snapshot.ts";

const VALID_FIXTURE = JSON.parse(
  readFileSync(new URL("./fixtures/ade-snapshot-valid.json", import.meta.url), "utf-8"),
) as AdeSnapshot;
const PATH_FIXTURES = JSON.parse(
  readFileSync(new URL("./fixtures/ade-snapshot-paths.json", import.meta.url), "utf-8"),
) as Array<{ cwd: string; sanitized: string }>;

const cleanupPaths = new Set<string>();

afterEach(() => {
  for (const path of cleanupPaths) {
    rmSync(path, { force: true });
  }
  cleanupPaths.clear();
});

describe("normalizeAdeSnapshot", () => {
  test("fills kind version and updatedAt defaults", () => {
    const snapshot = normalizeAdeSnapshot({
      ...VALID_FIXTURE,
      kind: undefined,
      version: undefined,
      updatedAt: undefined,
    });

    expect(snapshot.kind).toBe(ADE_SNAPSHOT_KIND);
    expect(snapshot.version).toBe(ADE_SNAPSHOT_VERSION);
    expect(snapshot.updatedAt).toBe(snapshot.generatedAt);
  });
});

describe("validateAdeSnapshot", () => {
  test("accepts the current schema", () => {
    const result = validateAdeSnapshot(VALID_FIXTURE);
    expect(result.ok).toBe(true);
    expect(result.errors).toEqual([]);
    expect(result.value?.kind).toBe(ADE_SNAPSHOT_KIND);
  });

  test("accepts legacy payloads without kind version or updatedAt", () => {
    const legacy = { ...(VALID_FIXTURE as Record<string, unknown>) };
    delete legacy.kind;
    delete legacy.version;
    delete legacy.updatedAt;

    const result = validateAdeSnapshot(legacy);
    expect(result.ok).toBe(true);
    expect(result.value?.kind).toBe(ADE_SNAPSHOT_KIND);
    expect(result.value?.version).toBe(ADE_SNAPSHOT_VERSION);
    expect(result.value?.updatedAt).toBe(result.value?.generatedAt);
  });

  test("rejects invalid payloads with clear errors", () => {
    const result = validateAdeSnapshot({
      kind: "wrong",
      version: 99,
      project: "",
      cwd: 42,
      generatedAt: "",
      updatedAt: "",
      revision: 0,
      paths: {},
      plan: { state: "broken", warnings: "oops" },
      review: { state: "bad", mayBeStale: "yes" },
      runtime: { state: "bad" },
      handoff: { state: "bad" },
      mode: { state: "bad" },
      nextAction: { value: "", reason: "", derivedFrom: "bad" },
    });

    expect(result.ok).toBe(false);
    expect(result.errors).toContain(`ADE snapshot kind must be ${ADE_SNAPSHOT_KIND}`);
    expect(result.errors).toContain(`ADE snapshot version must be ${ADE_SNAPSHOT_VERSION}`);
    expect(result.errors).toContain("ADE snapshot project must be a non-empty string");
    expect(result.errors).toContain("ADE snapshot review.state is invalid");
    expect(result.errors).toContain("ADE snapshot nextAction.derivedFrom is invalid");
  });
});

describe("parseAdeSnapshot", () => {
  test("parses and validates JSON content", () => {
    const result = parseAdeSnapshot(JSON.stringify(VALID_FIXTURE));
    expect(result.ok).toBe(true);
    expect(result.value?.review.source).toBe("stored");
  });

  test("reports invalid JSON", () => {
    expect(parseAdeSnapshot("not-json")).toEqual({
      ok: false,
      errors: ["ADE snapshot is not valid JSON"],
      value: null,
    });
  });
});

describe("makeAdeSnapshotFile", () => {
  test("uses the shared sanitized cwd convention", () => {
    for (const fixture of PATH_FIXTURES) {
      expect(makeAdeSnapshotFile(fixture.cwd)).toEndWith(`${fixture.sanitized}.ade.json`);
    }
  });
});

describe("readAdeSnapshotForCwd", () => {
  test("returns missing when the snapshot file does not exist", () => {
    const cwd = "/tmp/ade-snapshot-missing";
    const result = readAdeSnapshotForCwd(cwd);
    expect(result.ok).toBe(false);
    expect(result.reason).toBe("missing");
    expect(formatAdeReadError(result)).toContain("no snapshot");
  });

  test("reads a valid snapshot file for a cwd", () => {
    const cwd = VALID_FIXTURE.cwd as string;
    const path = makeAdeSnapshotFile(cwd);
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, JSON.stringify(VALID_FIXTURE, null, 2) + "\n", "utf-8");
    cleanupPaths.add(path);

    const result = readAdeSnapshotForCwd(cwd);
    expect(result.ok).toBe(true);
    expect(result.value?.cwd).toBe(cwd);
  });
});

describe("formatAdeStatus", () => {
  test("formats a concise ambient status line", () => {
    const text = formatAdeStatus(normalizeAdeSnapshot(VALID_FIXTURE));
    expect(text).toContain("ADE");
    expect(text).toContain("READY");
    expect(text).toContain("idle");
    expect(text).toContain("standard");
  });

  test("prefers actionable review counts when present", () => {
    const snapshot = normalizeAdeSnapshot({
      ...VALID_FIXTURE,
      review: {
        ...VALID_FIXTURE.review,
        actionable: 2,
      },
    });

    expect(formatAdeStatus(snapshot)).toContain("review 2");
  });
});
