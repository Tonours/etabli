import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { classifyWorkflowRoute, type WorkflowRoute } from "../lib/workflow-router-runtime.ts";

type WorkflowRouterFixture = {
  name: string;
  prompt: string;
  route: WorkflowRoute;
  mustNotRoute?: WorkflowRoute;
  writeAllowed: boolean;
  stopCondition: string;
};

const fixtures = JSON.parse(
  readFileSync(new URL("./fixtures/workflow-router-fixtures.json", import.meta.url), "utf-8"),
) as WorkflowRouterFixture[];

describe("workflow router golden prompt fixtures", () => {
  test("contains at least one anti-drift guard", () => {
    expect(fixtures.some((fixture) => fixture.mustNotRoute !== undefined)).toBe(true);
  });

  for (const fixture of fixtures) {
    test(fixture.name, () => {
      const decision = classifyWorkflowRoute(fixture.prompt);

      expect(decision).toMatchObject({
        route: fixture.route,
        writeAllowed: fixture.writeAllowed,
        stopCondition: fixture.stopCondition,
      });
      if (fixture.mustNotRoute) {
        expect(decision.route).not.toBe(fixture.mustNotRoute);
      }
    });
  }
});
