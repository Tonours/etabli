import { expect, test } from "bun:test";

test("Node test files run without DOM globals", () => {
  expect(Reflect.get(globalThis, "document")).toBeUndefined();
  expect(Reflect.get(globalThis, "window")).toBeUndefined();
});
