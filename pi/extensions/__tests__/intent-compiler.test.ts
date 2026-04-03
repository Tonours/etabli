/// <reference path="./bun-test.d.ts" />
import { describe, expect, test } from "bun:test";
import { compileTodoIntent } from "../lib/intent-compiler.ts";

describe("compileTodoIntent", () => {
  test("strips conversational wrappers and trailing punctuation", () => {
    expect(compileTodoIntent("please can you fix auth token refresh bug?"))
      .toBe("fix auth token refresh bug");
    expect(compileTodoIntent("we need to review onboarding copy in settings modal."))
      .toBe("review onboarding copy in settings modal");
  });

  test("removes leading hedges but preserves concrete nouns", () => {
    expect(compileTodoIntent("maybe just update context budget report wording"))
      .toBe("update context budget report wording");
  });

  test("keeps already good task text stable", () => {
    expect(compileTodoIntent("fix auth token refresh bug")).toBe("fix auth token refresh bug");
  });

  test("returns empty for empty input", () => {
    expect(compileTodoIntent("   ")).toBe("");
  });
});
