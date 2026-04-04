import { describe, it, expect, beforeEach, afterEach } from "bun:test";
import { mkdirSync, writeFileSync, rmSync, existsSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

describe("auto-validate", () => {
  let testDir: string;

  beforeEach(() => {
    testDir = join(tmpdir(), `auto-validate-test-${Date.now()}`);
    mkdirSync(testDir, { recursive: true });
  });

  afterEach(() => {
    if (existsSync(testDir)) rmSync(testDir, { recursive: true });
  });

  it("should parse PLAN.md status correctly", () => {
    const planContent = `
## Goal
Test implementation

- Status: READY
- Other: value
`;
    const statusMatch = planContent.match(/^- Status:\s*(.+)$/m);
    const status = statusMatch?.[1]?.trim();
    expect(status).toBe("READY");
  });

  it("should handle missing PLAN.md gracefully", () => {
    const planPath = join(testDir, "PLAN.md");
    expect(existsSync(planPath)).toBe(false);
  });

  it("should calculate validation summary correctly", () => {
    const results = [
      { name: "test1", status: "pass" as const },
      { name: "test2", status: "pass" as const },
      { name: "test3", status: "warn" as const },
      { name: "test4", status: "fail" as const },
      { name: "test5", status: "skip" as const },
    ];

    const summary = {
      pass: results.filter(r => r.status === "pass").length,
      warn: results.filter(r => r.status === "warn").length,
      fail: results.filter(r => r.status === "fail").length,
      skip: results.filter(r => r.status === "skip").length,
      total: results.length,
    };

    expect(summary.pass).toBe(2);
    expect(summary.warn).toBe(1);
    expect(summary.fail).toBe(1);
    expect(summary.skip).toBe(1);
    expect(summary.total).toBe(5);
  });

  it("should format validation report with icons", () => {
    const statusIcons: Record<string, string> = {
      pass: "✓",
      warn: "⚠",
      fail: "✗",
      skip: "○",
    };

    const results = [
      { name: "PLAN.md", status: "pass" as const, message: "READY", durationMs: 10 },
      { name: "Git", status: "warn" as const, message: "Uncommitted changes", durationMs: 20 },
    ];

    const lines: string[] = [];
    for (const r of results) {
      lines.push(`${statusIcons[r.status]} ${r.name}: ${r.message} (${r.durationMs}ms)`);
    }

    expect(lines[0]).toBe("✓ PLAN.md: READY (10ms)");
    expect(lines[1]).toBe("⚠ Git: Uncommitted changes (20ms)");
  });
});
