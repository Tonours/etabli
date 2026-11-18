import { expect, test } from "bun:test";
import { reviewVerdict } from "../src/review.ts";

test("review cannot pass with missing provenance-independent coverage or truncated output", () => {
  expect(() => reviewVerdict("Verdict: GO\nSTATUS: truncated", "code", "adversary")).toThrow("incomplete");
  expect(() => reviewVerdict("No findings.\nSTATUS: complete", "code", "adversary")).toThrow("verdict");
  expect(() => reviewVerdict("### Lens table\n### Deciding-code table\nVerdict: GO\nSTATUS: complete", "code", "logic")).toThrow("coverage");
  expect(() => reviewVerdict("### Deciding inputs\n### Entry-point inventory\n### Reused guards\n### Deferrals\n### Rollout\n### Attack tests\nVerdict: GO\nSTATUS: complete", "code", "threat")).toThrow("tables");
  expect(reviewVerdict("No findings.\nVerdict: READY\nSTATUS: complete", "plan", "adversary")).toBe("READY");
  expect(reviewVerdict("Findings\nVerdict: BLOCK\nSTATUS: complete", "code", "adversary")).toBe("BLOCK");
  expect(reviewVerdict("No findings.\nSTATUS: complete", "code", "spec")).toBe("GO");
  expect(reviewVerdict("Findings\nNo findings.\nSTATUS: complete", "code", "spec")).toBe("GO");
  expect(reviewVerdict('Findings\nhigh / f / 1 / quotes "No findings." / leak / fix / fix\nSTATUS: complete', "code", "spec")).toBe("BLOCK");
  expect(() => reviewVerdict("No findings.\nVerdict: UNKNOWN\nSTATUS: complete", "code", "spec")).toThrow("verdict");
  expect(() => reviewVerdict("unstructured text\nSTATUS: complete", "code", "spec")).toThrow("verdict");
  const unresolved = "### Open questions\nPotential medium: unresolved resolver step; inspect f:1.\n### Lens table\n| Lens | Checked | Found |\n| precedence | f:1 | unresolved |\n### Deciding-code table\n| Changed | Code | Sibling | Result |\n| resolver | f:1 | f:2 | unknown |\nVerdict: GO WITH NOTES\nSTATUS: complete";
  expect(() => reviewVerdict(unresolved, "code", "logic")).toThrow("unresolved");
});
