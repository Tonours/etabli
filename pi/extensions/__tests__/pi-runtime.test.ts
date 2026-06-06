import { describe, expect, test } from "bun:test";
import { CONFIGURED_DEFAULT_MODEL } from "../block-google-providers.ts";
import { FALLBACK_MODEL, readDefaultModelSpec } from "../lib/pi-runtime.ts";

describe("Pi runtime settings", () => {
  test("keeps the fallback model aligned with the configured default model", () => {
    expect(FALLBACK_MODEL).toBe(
      `${CONFIGURED_DEFAULT_MODEL.provider}/${CONFIGURED_DEFAULT_MODEL.id}`,
    );
  });

  test("uses the maintained fallback when settings are unavailable", () => {
    expect(readDefaultModelSpec("/missing/pi/settings.json")).toBe(FALLBACK_MODEL);
  });
});
