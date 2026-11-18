import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { clampThinkingLevel, type Model } from "@earendil-works/pi-ai";
import { resolveSamplingParams } from "../../../node_modules/@earendil-works/pi-ai/dist/api/simple-options.js";

test("installed resolver distinguishes supported levels and clamps unsupported high levels", () => {
  const data = JSON.parse(readFileSync(new URL("../../../models.json", import.meta.url), "utf8")) as {
    providers: Record<string, { models: Model<"openai-completions">[] }>;
  };
  const model = data.providers["macmini-gemma"]!.models[0]!;
  for (const [level, expected] of [["off", 0], ["minimal", 128], ["low", 512], ["medium", 1024], ["high", 2048], ["xhigh", 2048], ["max", 2048]] as const) {
    const params = resolveSamplingParams(model, level);
    expect(params?.thinking_budget_tokens).toBe(expected);
    expect(params?.chat_template_kwargs).toEqual({ enable_thinking: expected > 0 });
    expect(model.maxTokens).toBeGreaterThan(expected);
  }
  expect(clampThinkingLevel(model, "xhigh")).toBe("high");
  expect(clampThinkingLevel(model, "max")).toBe("high");
});
