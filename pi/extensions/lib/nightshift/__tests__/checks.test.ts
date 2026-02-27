import { describe, expect, test } from "bun:test";
import { checkBinaries } from "../checks.ts";

describe("checkBinaries", () => {
  test("returns empty missing for binaries that exist", () => {
    const result = checkBinaries(["git", "bun"]);
    expect(result.missing).toEqual([]);
  });

  test("returns missing for binaries that do not exist", () => {
    const result = checkBinaries(["nonexistent-binary-xyz-12345"]);
    expect(result.missing).toEqual(["nonexistent-binary-xyz-12345"]);
  });

  test("returns mix of found and missing", () => {
    const result = checkBinaries(["git", "nonexistent-binary-xyz-12345"]);
    expect(result.missing).toEqual(["nonexistent-binary-xyz-12345"]);
  });

  test("handles empty input", () => {
    const result = checkBinaries([]);
    expect(result.missing).toEqual([]);
  });
});
