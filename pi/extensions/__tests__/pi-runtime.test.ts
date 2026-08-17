import { describe, expect, test } from "bun:test";
import { UNKNOWN_MODEL_SPEC, readDefaultModelSpec } from "../lib/pi-runtime.ts";

describe("Pi runtime settings", () => {
  test("reads the default model spec from agent settings", () => {
    expect(
      readDefaultModelSpec(`${import.meta.dir}/../../agent/settings.json`),
    ).toBe("zai/glm-5.3");
  });

  test("returns the unknown sentinel when settings are unavailable", () => {
    expect(readDefaultModelSpec("/missing/pi/settings.json")).toBe(
      UNKNOWN_MODEL_SPEC,
    );
  });
});
