/// <reference path="./bun-test.d.ts" />
import { describe, expect, test } from "bun:test";
import {
  findImplementationTrackingBounds,
  parseImplementationTracking,
  summarizeImplementationTracking,
  updateImplementationTracking,
} from "../lib/plan-state.ts";

const PLAN = `## Meta
- Subject: Example
- Status: READY

## Execution Slices
### Slice 1
- Goal:
- Files / areas:
- Checks:
- Rollback point:

## Implementation Tracking
- Active slice:
  - Slice 1
- Completed slices:
  - none
- Pending checks:
  - unit test
- Last validated state:
  - partial
- Next recommended action:
  - finish slice 1

## Risks And Edge Cases
- Risk / edge case:
  - Impact:
  - Mitigation:
`;

describe("findImplementationTrackingBounds", () => {
  test("finds the tracking section", () => {
    expect(findImplementationTrackingBounds(PLAN)).toEqual({ start: 11, end: 23 });
  });

  test("returns null when the section is missing", () => {
    expect(findImplementationTrackingBounds("# no plan here")).toBeNull();
  });
});

describe("parseImplementationTracking", () => {
  test("parses the current template shape", () => {
    expect(parseImplementationTracking(PLAN)).toEqual({
      "Active slice": ["Slice 1"],
      "Completed slices": ["none"],
      "Pending checks": ["unit test"],
      "Last validated state": ["partial"],
      "Next recommended action": ["finish slice 1"],
    });
  });

  test("preserves continuation lines on the last item", () => {
    const plan = PLAN.replace("  - finish slice 1", "  - finish slice 1\n    after rerunning unit test");
    expect(parseImplementationTracking(plan)["Next recommended action"]).toEqual([
      "finish slice 1\nafter rerunning unit test",
    ]);
  });
});

describe("updateImplementationTracking", () => {
  test("updates only the tracking section", () => {
    const updated = updateImplementationTracking(PLAN, {
      "Active slice": ["Slice 2"],
      "Completed slices": ["Slice 1"],
      "Pending checks": ["lint", "typecheck"],
      "Last validated state": ["clean after slice 1"],
      "Next recommended action": ["start slice 2"],
    });

    expect(updated).toContain("## Meta\n- Subject: Example");
    expect(updated).toContain("## Risks And Edge Cases");
    expect(parseImplementationTracking(updated)).toEqual({
      "Active slice": ["Slice 2"],
      "Completed slices": ["Slice 1"],
      "Pending checks": ["lint", "typecheck"],
      "Last validated state": ["clean after slice 1"],
      "Next recommended action": ["start slice 2"],
    });
  });

  test("throws when the section is missing", () => {
    expect(() => updateImplementationTracking("# nope", { "Active slice": ["Slice 1"] })).toThrow(
      "PLAN.md is missing the Implementation Tracking section",
    );
  });
});

describe("summarizeImplementationTracking", () => {
  test("formats a concise summary", () => {
    const summary = summarizeImplementationTracking(parseImplementationTracking(PLAN));
    expect(summary).toContain("Active slice: Slice 1");
    expect(summary).toContain("Pending checks: unit test");
  });
});
