/**
 * Shared trigger-eval response normalization (runner + reduce import this
 * single module — never duplicate it: a sync skew would flip verdicts).
 * Strict: envelope-cleaned response must EQUAL the expected name exactly.
 * Frozen I/O vectors live in tests/skill-trigger-normalize.test.mjs.
 */

export function normalizeResponse(text) {
  return String(text || "")
    .replace(/```[\s\S]*?```/g, " ")
    .replace(/["'`*]/g, "")
    .trim()
    .toLowerCase();
}

export function decideResponse(raw, expected) {
  const want = expected === "NONE" ? "none" : expected;
  return normalizeResponse(raw) === want;
}
