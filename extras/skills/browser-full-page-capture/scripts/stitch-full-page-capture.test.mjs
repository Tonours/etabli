import assert from "node:assert/strict";
import test from "node:test";
import { parseArgs, planSegments, resolveContained, validateHttpUrl } from "./stitch-full-page-capture.mjs";

test("rejects unsafe numeric values and incompatible modes", () => {
  for (const argv of [
    ["--url", "https://example.com", "--out", "x.jpg", "--viewport", "0x0"],
    ["--url", "https://example.com", "--out", "x.jpg", "--step", "-1"],
    ["--url", "https://example.com", "--out", "x.jpg", "--step", "0"],
    ["--url", "https://example.com", "--out", "x.jpg", "--wait", "NaN"],
    ["--url", "file:///tmp/x", "--out", "x.jpg"],
    ["--manifest", "x.json", "--url", "https://example.com"],
    ["--url", "https://example.com", "--out", "x.jpg", "--item", "1"],
  ]) assert.throws(() => parseArgs(argv));
});

test("plans bounded forward-only segments", () => {
  assert.deepEqual(planSegments(100, 200, 50), [0]);
  assert.deepEqual(planSegments(450, 200, 100), [0, 100, 200, 250]);
  assert.throws(() => planSegments(10_000, 100, 1, 10), /segment cap/);
});

test("keeps manifest outputs contained", () => {
  assert.equal(resolveContained("/tmp/root", "images/page.jpg"), "/tmp/root/images/page.jpg");
  assert.throws(() => resolveContained("/tmp/root", "../outside.jpg"), /escapes/);
  assert.throws(() => resolveContained("/tmp/root", "/tmp/outside.jpg"), /relative/);
});

test("accepts only browser-safe URL protocols", () => {
  assert.equal(validateHttpUrl("https://example.com/a"), "https://example.com/a");
  assert.throws(() => validateHttpUrl("file:///tmp/page.html"), /http or https/);
  assert.throws(() => validateHttpUrl("not a URL"), /valid http or https/);
});
