import { expect, test } from "bun:test";
import { qualifyKills } from "./qualify-kills.ts";

test("SIGKILL recovers native intent without replaying unsafe tools or duplicating results", async () => {
  const evidence = await qualifyKills(2);
  expect(evidence.midTool).toBe(1);
  expect(evidence.midGeneration).toBe(1);
  expect(evidence.interrupted).toBeGreaterThanOrEqual(1);
}, 45_000);
