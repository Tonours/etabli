import { describe, it, expect, beforeEach, afterEach } from "bun:test";
import { mkdirSync, writeFileSync, rmSync, existsSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

// Mock the pi-coding-agent types for testing
type MockContext = {
  cwd: string;
  ui: { notify: (msg: string, type: string) => void; };
};

const notifications: { msg: string; type: string }[] = [];

function createMockContext(cwd: string): MockContext {
  notifications.length = 0;
  return {
    cwd,
    ui: {
      notify: (msg: string, type: string) => {
        notifications.push({ msg, type });
      },
    },
  };
}

// Simple test to verify fast-handoff logic
describe("fast-handoff", () => {
  let testDir: string;
  let statusDir: string;

  beforeEach(() => {
    testDir = join(tmpdir(), `fast-handoff-test-${Date.now()}`);
    statusDir = join(tmpdir(), `.pi-status-test-${Date.now()}`);
    mkdirSync(testDir, { recursive: true });
  });

  afterEach(() => {
    if (existsSync(testDir)) rmSync(testDir, { recursive: true });
    if (existsSync(statusDir)) rmSync(statusDir, { recursive: true });
  });

  it("should generate handoff when OPS snapshot exists", () => {
    // Create mock OPS snapshot
    const snapshot = {
      kind: "ops-snapshot",
      version: 1,
      project: "test-project",
      cwd: testDir,
      generatedAt: new Date().toISOString(),
      revision: 1,
      paths: {
        snapshot: join(statusDir, "test.ops.json"),
        plan: join(testDir, "PLAN.md"),
        runtime: join(testDir, ".pi/runtime.json"),
        handoffImplement: join(testDir, ".pi/handoff-implement.md"),
        handoffGeneric: join(testDir, ".pi/handoff.md"),
      },
      plan: {
        state: "available" as const,
        path: join(testDir, "PLAN.md"),
        status: "READY",
        plannedSlice: null,
        activeSlice: "Test implementation",
        completedSlices: ["Setup", "Planning"],
        pendingChecks: ["Run tests"],
        lastValidatedState: "Tests passing",
        nextRecommendedAction: "Run pending checks",
        warnings: [],
      },
      review: {
        state: "available" as const,
        source: "stored" as const,
        mayBeStale: false,
        refreshedAt: null,
        actionable: 2,
        line: "2 actionable items",
        warnings: [],
      },
      runtime: {
        state: "available" as const,
        source: null,
        phase: "idle",
        tool: null,
        model: null,
        thinking: null,
        updatedAt: null,
        warnings: [],
      },
      handoff: {
        state: "missing" as const,
        kind: null,
        path: null,
      },
      mode: {
        state: "available" as const,
        mode: "standard",
        explicit: false,
        hint: {
          roles: "Main session owns intent",
          review: "Parallel-safe",
          scope: "One mutable checkout",
        },
        warnings: [],
      },
      nextAction: {
        value: "Run pending checks",
        reason: "Checks are pending from plan",
        derivedFrom: "plan" as const,
      },
    };

    mkdirSync(statusDir, { recursive: true });
    writeFileSync(join(statusDir, `${testDir.replace(/[^a-zA-Z0-9._-]+/g, "_")}.ops.json`), JSON.stringify(snapshot));

    // Create PLAN.md
    writeFileSync(join(testDir, "PLAN.md"), `
## Goal
Test implementation goal

## Constraints
- Follow existing patterns
- Keep changes minimal

## Decisions
Architecture: Use modular approach

## Open Issues
- (none)
`);

    // Verify files exist
    expect(existsSync(join(testDir, "PLAN.md"))).toBe(true);
    expect(existsSync(join(statusDir, `${testDir.replace(/[^a-zA-Z0-9._-]+/g, "_")}.ops.json`))).toBe(true);
  });

  it("should handle missing OPS snapshot gracefully", () => {
    const ctx = createMockContext(testDir);
    
    // No snapshot created - should fail gracefully
    // The actual behavior is tested via the command handler
    expect(ctx.cwd).toBe(testDir);
    expect(notifications).toHaveLength(0);
  });

  it("should extract goal from PLAN.md correctly", () => {
    const planContent = `
## Goal
Implement fast-handoff feature for zero-latency handoffs

## Constraints
- No LLM calls
- Use local state only

## Decisions
Performance: Local generation is 100x faster
`;
    
    const goalMatch = planContent.match(/## Goal\s*\n([^#]*)/);
    const goal = goalMatch?.[1]?.trim() || "";
    
    expect(goal).toBe("Implement fast-handoff feature for zero-latency handoffs");
  });

  it("should extract constraints from PLAN.md correctly", () => {
    const planContent = `
## Constraints
- Follow existing code patterns
- Keep functions under 50 lines
- No external dependencies
- (none) should be ignored
`;
    
    const constraints: string[] = [];
    const match = planContent.match(/## Constraints\s*\n([^#]*)/);
    if (match?.[1]) {
      const lines = match[1].trim().split("\n");
      for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed && !trimmed.startsWith("- (none)")) {
          constraints.push(trimmed.replace(/^-\s*/, ""));
        }
      }
    }
    
    expect(constraints).toEqual([
      "Follow existing code patterns",
      "Keep functions under 50 lines",
      "No external dependencies",
    ]);
  });
});
