/// <reference path="./bun-test.d.ts" />
import { describe, expect, test } from "bun:test";
import { mkdtempSync, mkdirSync, statSync, writeFileSync } from "node:fs";
import { tmpdir, homedir } from "node:os";
import { dirname, join } from "node:path";
import {
  buildContextBudgetReport,
  contextBudgetClass,
  estimateTokenCount,
  formatContextBudgetReport,
} from "../lib/context-budget.ts";
import { makeOpsSnapshotFile, makeOpsTaskStateFile } from "../lib/ops-snapshot.ts";

describe("estimateTokenCount", () => {
  test("uses a simple advisory chars-to-token estimate", () => {
    expect(estimateTokenCount("abcd")).toBe(1);
    expect(estimateTokenCount("abcdefgh")).toBe(2);
    expect(estimateTokenCount("   ")).toBe(0);
  });
});

describe("buildContextBudgetReport", () => {
  test("collects existing workflow artifacts and sorts by estimated tokens", () => {
    const cwd = mkdtempSync(join(tmpdir(), "context-budget-"));
    writeFileSync(join(cwd, "PLAN.md"), "# Plan\n" + "x".repeat(400), "utf-8");
    mkdirSync(join(cwd, ".pi"), { recursive: true });
    writeFileSync(join(cwd, ".pi", "handoff.md"), "handoff\n" + "y".repeat(120), "utf-8");

    const opsPath = makeOpsSnapshotFile(cwd);
    mkdirSync(dirname(opsPath), { recursive: true });
    writeFileSync(
      opsPath,
      JSON.stringify({
        kind: "ops-snapshot",
        version: 1,
        project: "repo",
        cwd,
        generatedAt: "2026-04-02T00:00:00.000Z",
        updatedAt: "2026-04-02T00:00:00.000Z",
        revision: 1,
        paths: {
          snapshot: opsPath,
          task: makeOpsTaskStateFile(cwd),
          plan: join(cwd, "PLAN.md"),
          runtime: join(homedir(), ".pi", "status", "runtime.json"),
          handoffImplement: join(cwd, ".pi", "handoff-implement.md"),
          handoffGeneric: join(cwd, ".pi", "handoff.md"),
        },
        plan: {
          state: "available",
          path: join(cwd, "PLAN.md"),
          status: "READY",
          plannedSlice: null,
          activeSlice: null,
          completedSlices: [],
          pendingChecks: [],
          lastValidatedState: null,
          nextRecommendedAction: null,
          warnings: [],
        },
        review: {
          state: "unavailable",
          source: null,
          mayBeStale: false,
          refreshedAt: null,
          actionable: 0,
          line: "none",
          warnings: [],
        },
        runtime: {
          state: "missing",
          source: null,
          phase: null,
          tool: null,
          model: null,
          thinking: null,
          updatedAt: null,
          warnings: [],
        },
        handoff: {
          state: "missing",
          kind: null,
          path: null,
        },
        mode: {
          state: "available",
          mode: "standard",
          explicit: true,
          hint: { roles: "scout-worker-reviewer", review: "stored", scope: "bounded" },
          warnings: [],
        },
        nextAction: {
          value: "next",
          reason: "because",
          derivedFrom: "plan",
        },
      }),
      "utf-8",
    );

    const report = buildContextBudgetReport(cwd);
    expect(report.entries.length).toBeGreaterThanOrEqual(3);
    expect(report.entries.some((entry) => entry.label === "PLAN")).toBe(true);
    expect(report.entries[0]?.estimatedTokens).toBeGreaterThanOrEqual(report.entries[1]?.estimatedTokens ?? 0);
    expect(report.totalEstimatedTokens).toBeGreaterThan(0);
    expect(report.recommendations.length).toBeGreaterThan(0);
  });

  test("reports real file bytes and skips unreadable artifacts", () => {
    const cwd = mkdtempSync(join(tmpdir(), "context-budget-"));
    const planPath = join(cwd, "PLAN.md");
    writeFileSync(planPath, "éééé", "utf-8");
    const directoryArtifactPath = join(cwd, "dir-artifact");
    mkdirSync(directoryArtifactPath, { recursive: true });

    const report = buildContextBudgetReport(cwd, [
      { kind: "workflow", label: "PLAN", path: planPath },
      { kind: "workflow", label: "Unreadable directory", path: directoryArtifactPath },
    ]);

    expect(report.entries).toHaveLength(1);
    expect(report.entries[0]?.bytes).toBe(statSync(planPath).size);
  });
});

describe("formatContextBudgetReport", () => {
  test("formats warnings and recommendations when present", () => {
    const text = formatContextBudgetReport({
      cwd: "/tmp/repo",
      totalEstimatedTokens: 9_000,
      entries: [
        {
          kind: "workflow",
          label: "PLAN",
          path: "/tmp/repo/PLAN.md",
          bytes: 1024,
          lines: 40,
          estimatedTokens: 3_000,
        },
      ],
      warnings: ["Estimated context is high (9000 tokens)."],
      recommendations: ["Compact or refresh PLAN first."],
    });

    expect(contextBudgetClass(9_000)).toBe("high");
    expect(text).toContain("Context budget (high)");
    expect(text).toContain("Warnings:");
    expect(text).toContain("Recommendations:");
  });
});
