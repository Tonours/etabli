/// <reference path="./bun-test.d.ts" />
/// <reference path="../lib/node-runtime.d.ts" />
import { afterEach, describe, expect, test } from "bun:test";
import { mkdirSync, readFileSync, rmSync, statSync, utimesSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import {
  OPS_SNAPSHOT_KIND,
  OPS_SNAPSHOT_VERSION,
  type OpsSnapshot,
  clearOpsSnapshotReadCache,
  formatOpsReadError,
  formatOpsStatus,
  makeOpsSnapshotFile,
  makeOpsTaskStateFile,
  normalizeOpsSnapshot,
  parseOpsSnapshot,
  readOpsSnapshotForCwd,
  validateOpsSnapshot,
} from "../lib/ops-snapshot.ts";

const VALID_FIXTURE = JSON.parse(
  readFileSync(new URL("./fixtures/ops-snapshot-valid.json", import.meta.url), "utf-8"),
) as OpsSnapshot;
const PATH_FIXTURES = JSON.parse(
  readFileSync(new URL("./fixtures/ops-snapshot-paths.json", import.meta.url), "utf-8"),
) as Array<{ cwd: string; sanitized: string }>;

const cleanupPaths = new Set<string>();

afterEach(() => {
  clearOpsSnapshotReadCache();
  for (const path of cleanupPaths) {
    rmSync(path, { force: true, recursive: true });
  }
  cleanupPaths.clear();
});

describe("normalizeOpsSnapshot", () => {
  test("fills kind version and updatedAt defaults", () => {
    const snapshot = normalizeOpsSnapshot({
      ...VALID_FIXTURE,
      kind: undefined,
      version: undefined,
      updatedAt: undefined,
    });

    expect(snapshot.kind).toBe(OPS_SNAPSHOT_KIND);
    expect(snapshot.version).toBe(OPS_SNAPSHOT_VERSION);
    expect(snapshot.updatedAt).toBe(snapshot.generatedAt);
    expect(snapshot.paths.task).toEndWith(".task.json");
    expect(snapshot.task?.title).toBeTruthy();
    expect(snapshot.task?.revision).toBe(snapshot.revision);
    expect(snapshot.task?.identitySource).toBeTruthy();
    expect(snapshot.plan.completedSlices).toEqual(VALID_FIXTURE.plan.completedSlices);
  });

  test("fills derived task defaults for legacy snapshots without task data", () => {
    const legacy = normalizeOpsSnapshot({
      ...VALID_FIXTURE,
      paths: {
        ...VALID_FIXTURE.paths,
        task: undefined,
      },
      plan: {
        ...VALID_FIXTURE.plan,
        completedSlices: undefined,
        pendingChecks: undefined,
        lastValidatedState: undefined,
      },
      task: undefined,
    });

    expect(legacy.task?.title).toBe(VALID_FIXTURE.project);
    expect(legacy.task?.nextAction).toBe(VALID_FIXTURE.nextAction.value);
    expect(legacy.paths.task).toBe(makeOpsTaskStateFile(VALID_FIXTURE.cwd));
    expect(legacy.task?.identitySource).toBe("cwd");
    expect(legacy.task?.titleSource).toBe("repo");
    expect(legacy.task?.lifecycleState).toBe("ready");
    expect(legacy.plan.completedSlices).toEqual([]);
    expect(legacy.plan.pendingChecks).toEqual([]);
    expect(legacy.plan.lastValidatedState).toBeNull();
  });
});

describe("validateOpsSnapshot", () => {
  test("accepts the current schema", () => {
    const result = validateOpsSnapshot(VALID_FIXTURE);
    expect(result.ok).toBe(true);
    expect(result.errors).toEqual([]);
    expect(result.value?.kind).toBe(OPS_SNAPSHOT_KIND);
  });

  test("accepts legacy payloads without kind version or updatedAt", () => {
    const legacy = JSON.parse(JSON.stringify(VALID_FIXTURE)) as Record<string, unknown>;
    delete legacy.kind;
    delete legacy.version;
    delete legacy.updatedAt;
    if (legacy.plan && typeof legacy.plan === "object") {
      delete (legacy.plan as Record<string, unknown>).completedSlices;
      delete (legacy.plan as Record<string, unknown>).pendingChecks;
      delete (legacy.plan as Record<string, unknown>).lastValidatedState;
    }

    const result = validateOpsSnapshot(legacy);
    expect(result.ok).toBe(true);
    expect(result.value?.kind).toBe(OPS_SNAPSHOT_KIND);
    expect(result.value?.version).toBe(OPS_SNAPSHOT_VERSION);
    expect(result.value?.updatedAt).toBe(result.value?.generatedAt);
    expect(result.value?.plan.completedSlices).toEqual([]);
    expect(result.value?.plan.pendingChecks).toEqual([]);
    expect(result.value?.plan.lastValidatedState).toBeNull();
  });

  test("rejects invalid payloads with clear errors", () => {
    const result = validateOpsSnapshot({
      kind: "wrong",
      version: 99,
      project: "",
      cwd: 42,
      generatedAt: "",
      updatedAt: "",
      revision: 0,
      paths: {},
      task: {
        taskId: "",
        title: "",
        repo: "",
        workspacePath: "",
        branch: 5,
        identitySource: "",
        titleSource: "",
        lifecycleState: "",
        mode: "",
        planStatus: 1,
        runtimePhase: 2,
        reviewSummary: "",
        nextAction: "",
        activeSlice: 3,
        completedSlices: "bad",
        pendingChecks: "bad",
        lastValidatedState: 4,
        revision: 0,
        updatedAt: "",
      },
      plan: {
        state: "broken",
        path: 1,
        status: 2,
        plannedSlice: 3,
        activeSlice: 4,
        completedSlices: "oops",
        pendingChecks: "oops",
        lastValidatedState: 5,
        nextRecommendedAction: 6,
        warnings: "oops",
      },
      review: { state: "bad", source: "weird", mayBeStale: "yes", refreshedAt: 1, actionable: -1, line: "", warnings: "oops" },
      runtime: { state: "bad", source: 1, phase: 2, tool: 3, model: 4, thinking: 5, updatedAt: 6, warnings: "oops" },
      handoff: { state: "bad", kind: 1, path: 2 },
      mode: { state: "bad", mode: "", explicit: "no", hint: { roles: "", review: "", scope: "" }, warnings: "oops" },
      nextAction: { value: "", reason: "", derivedFrom: "bad" },
    });

    expect(result.ok).toBe(false);
    expect(result.errors).toContain(`OPS snapshot kind must be ${OPS_SNAPSHOT_KIND}`);
    expect(result.errors).toContain(`OPS snapshot version must be ${OPS_SNAPSHOT_VERSION}`);
    expect(result.errors).toContain("OPS snapshot project must be a non-empty string");
    expect(result.errors).toContain("OPS snapshot task.taskId must be a non-empty string");
    expect(result.errors).toContain("OPS snapshot plan.completedSlices must be a string array when present");
    expect(result.errors).toContain("OPS snapshot review.state is invalid");
    expect(result.errors).toContain("OPS snapshot runtime.state is invalid");
    expect(result.errors).toContain("OPS snapshot nextAction.derivedFrom is invalid");
  });});

describe("parseOpsSnapshot", () => {
  test("parses and validates JSON content", () => {
    const result = parseOpsSnapshot(JSON.stringify(VALID_FIXTURE));
    expect(result.ok).toBe(true);
    expect(result.value?.review.source).toBe("stored");
  });

  test("reports invalid JSON", () => {
    expect(parseOpsSnapshot("not-json")).toEqual({
      ok: false,
      errors: ["OPS snapshot is not valid JSON"],
      value: null,
    });
  });
});

describe("makeOpsSnapshotFile", () => {
  test("uses the shared sanitized cwd convention", () => {
    for (const fixture of PATH_FIXTURES) {
      expect(makeOpsSnapshotFile(fixture.cwd)).toEndWith(`${fixture.sanitized}.ops.json`);
      expect(makeOpsTaskStateFile(fixture.cwd)).toEndWith(`${fixture.sanitized}.task.json`);
    }
  });
});

describe("readOpsSnapshotForCwd", () => {
  test("returns missing when the snapshot file does not exist", () => {
    const cwd = "/tmp/ops-snapshot-missing";
    const result = readOpsSnapshotForCwd(cwd);
    expect(result.ok).toBe(false);
    expect(result.reason).toBe("missing");
    expect(formatOpsReadError(result)).toContain("no snapshot");
  });

  test("formats invalid read errors", () => {
    expect(
      formatOpsReadError({ ok: false, path: "/tmp/x", reason: "invalid", errors: ["broken snapshot"], value: null }),
    ).toBe("OPS: broken snapshot");
  });

  test("reads a valid snapshot file for a cwd", () => {
    const cwd = VALID_FIXTURE.cwd as string;
    const path = makeOpsSnapshotFile(cwd);
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, JSON.stringify(VALID_FIXTURE, null, 2) + "\n", "utf-8");
    cleanupPaths.add(path);

    const result = readOpsSnapshotForCwd(cwd);
    expect(result.ok).toBe(true);
    expect(result.value?.cwd).toBe(cwd);
  });

  test("returns invalid instead of throwing when the snapshot path is unreadable", () => {
    const cwd = "/tmp/ops-snapshot-unreadable";
    const path = makeOpsSnapshotFile(cwd);
    mkdirSync(path, { recursive: true });
    cleanupPaths.add(path);

    const result = readOpsSnapshotForCwd(cwd);
    expect(result.ok).toBe(false);
    expect(result.reason).toBe("invalid");
    expect(result.errors?.[0]).toContain("could not be read");
  });

  test("invalidates cached snapshots when size changes but mtime stays the same", () => {
    const cwd = "/tmp/ops-snapshot-same-mtime";
    const path = makeOpsSnapshotFile(cwd);
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, JSON.stringify(VALID_FIXTURE, null, 2) + "\n", "utf-8");
    cleanupPaths.add(path);

    const first = readOpsSnapshotForCwd(cwd);
    expect(first.ok).toBe(true);

    const initialStats = statSync(path);
    const updated = {
      ...VALID_FIXTURE,
      review: { ...VALID_FIXTURE.review, actionable: 2 },
      updatedAt: "2026-04-02T00:00:01.000Z",
    };
    writeFileSync(path, JSON.stringify(updated, null, 2) + "\n \n", "utf-8");
    utimesSync(path, new Date(initialStats.mtimeMs), new Date(initialStats.mtimeMs));

    const second = readOpsSnapshotForCwd(cwd);
    expect(second.ok).toBe(true);
    expect(second.value?.review.actionable).toBe(2);
  });

  test("returns cloned snapshots so callers cannot mutate the cache", () => {
    const cwd = "/tmp/ops-snapshot-clone";
    const path = makeOpsSnapshotFile(cwd);
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, JSON.stringify(VALID_FIXTURE, null, 2) + "\n", "utf-8");
    cleanupPaths.add(path);

    const first = readOpsSnapshotForCwd(cwd);
    expect(first.ok).toBe(true);
    if (!first.ok || !first.value) throw new Error("expected snapshot");
    first.value.plan.status = "DRAFT";

    const second = readOpsSnapshotForCwd(cwd);
    expect(second.ok).toBe(true);
    expect(second.value?.plan.status).toBe(VALID_FIXTURE.plan.status);
  });
});

describe("formatOpsStatus", () => {
  test("formats a concise ambient status line", () => {
    const text = formatOpsStatus(normalizeOpsSnapshot(VALID_FIXTURE));
    expect(text).toContain("OPS");
    expect(text).toContain("READY");
    expect(text).toContain("done 1");
    expect(text).toContain("checks 2");
    expect(text).toContain("idle");
    expect(text).toContain("standard");
  });

  test("prefers actionable review counts when present", () => {
    const snapshot = normalizeOpsSnapshot({
      ...VALID_FIXTURE,
      review: {
        ...VALID_FIXTURE.review,
        actionable: 2,
      },
    });

    expect(formatOpsStatus(snapshot)).toContain("review 2");
  });
});
