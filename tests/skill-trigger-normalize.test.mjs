// Frozen I/O vectors for the shared trigger-eval normalization.
// Run from tests/skill-trigger-eval-smoke.sh (eval gate owns eval-unit safety).
import test from "node:test";
import assert from "node:assert/strict";
import { normalizeResponse, decideResponse } from "../scripts/lib/skill-trigger-normalize.mjs";

const NORMALIZE_CASES = [
  ["bug-check", "bug-check"],
  ["NONE", "none"],
  ["  Review  ", "review"],
  ["`sec-pr`", "sec-pr"],
  ['"plan-loop"', "plan-loop"],
  ["```\nverify\n```", ""],
  ["*code-quality*", "code-quality"],
  ["NONE because reasons", "none because reasons"],
  ["bug-check.", "bug-check."],
  ["", ""],
  ["   ", ""],
];

for (const [input, expected] of NORMALIZE_CASES) {
  test(`normalize ${JSON.stringify(input)}`, () => {
    assert.equal(normalizeResponse(input), expected);
  });
}

const DECIDE_CASES = [
  ["bug-check", "bug-check", true],
  ["NONE", "NONE", true],
  ["none", "NONE", true],
  ["NONE because reasons", "NONE", false],
  ["bug-check.", "bug-check", false],
  ["review", "pr-review", false],
  ["", "verify", false],
];

for (const [raw, expected, passed] of DECIDE_CASES) {
  test(`decide ${JSON.stringify(raw)} vs ${expected}`, () => {
    assert.equal(decideResponse(raw, expected), passed);
  });
}
