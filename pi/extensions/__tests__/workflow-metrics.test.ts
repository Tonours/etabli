import { describe, it, expect } from "bun:test";

describe("workflow-metrics", () => {
  it("should calculate phase breakdown correctly", () => {
    const sessions = [
      {
        phases: [
          { phase: "planning", durationMs: 1000 * 60 * 30 },
          { phase: "implementation", durationMs: 1000 * 60 * 60 },
        ],
      },
      {
        phases: [
          { phase: "planning", durationMs: 1000 * 60 * 15 },
          { phase: "review", durationMs: 1000 * 60 * 20 },
        ],
      },
    ];

    const breakdown: Record<string, number> = {};
    for (const session of sessions) {
      for (const phase of (session as { phases: Array<{ phase: string; durationMs?: number }> }).phases) {
        if (phase.durationMs) {
          breakdown[phase.phase] = (breakdown[phase.phase] || 0) + phase.durationMs;
        }
      }
    }

    expect(breakdown["planning"]).toBe(1000 * 60 * 45);
    expect(breakdown["implementation"]).toBe(1000 * 60 * 60);
    expect(breakdown["review"]).toBe(1000 * 60 * 20);
  });

  it("should format time correctly", () => {
    const totalMinutes = 125;
    const hours = Math.floor(totalMinutes / 60);
    const minutes = totalMinutes % 60;

    expect(hours).toBe(2);
    expect(minutes).toBe(5);
  });
});
