import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { classifyWorkflowRoute, type WorkflowRoute } from "../lib/workflow-router-runtime.ts";

type WorkflowRouterFixture = {
  name: string;
  category: string;
  prompt: string;
  expectedRoute: WorkflowRoute;
  writeAllowed: boolean;
  context?: { planStatus?: "missing" | "draft" | "challenged" | "ready" | "unknown" };
};

const fixtures = JSON.parse(
  readFileSync(new URL("../../../tests/router-evals/core.json", import.meta.url), "utf-8"),
) as WorkflowRouterFixture[];

describe("workflow router golden prompt fixtures", () => {
  test("contains at least one anti-drift guard", () => {
    expect(fixtures.some((fixture) => fixture.category === "negative-control")).toBe(true);
  });

  for (const fixture of fixtures) {
    test(fixture.name, () => {
      const decision = classifyWorkflowRoute(fixture.prompt, fixture.context);

      expect(decision).toMatchObject({
        route: fixture.expectedRoute,
        writeAllowed: fixture.writeAllowed,
      });
    });
  }
});
