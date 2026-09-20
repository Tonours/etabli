#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
CLI="$ROOT_DIR/scripts/typesafe-architecture-review"
LIB="$ROOT_DIR/scripts/lib/typesafe-architecture-review.mjs"
FIXTURES="$ROOT_DIR/tests/fixtures/typesafe-architecture-review"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CLI_REPO="$TMP/cli-repo"
mkdir -p "$CLI_REPO/scripts/lib" "$CLI_REPO/tests/fixtures/typesafe-architecture-review" "$CLI_REPO/workflow"
cp "$CLI" "$CLI_REPO/scripts/typesafe-architecture-review"
cp "$LIB" "$CLI_REPO/scripts/lib/typesafe-architecture-review.mjs"
cp "$FIXTURES"/*.json "$CLI_REPO/tests/fixtures/typesafe-architecture-review/"
cp "$ROOT_DIR/workflow/spec.md" "$CLI_REPO/workflow/spec.md"
printf '%s\n' '# Plan' '- Status: READY' >"$CLI_REPO/PLAN.md"
git -C "$CLI_REPO" init -q
git -C "$CLI_REPO" add workflow/spec.md
TEST_CLI="$CLI_REPO/scripts/typesafe-architecture-review"

fail() {
  printf 'typesafe architecture review smoke: %s\n' "$1" >&2
  exit 1
}

node "$TEST_CLI" --preview --plan PLAN.md --evidence workflow/spec.md | jq -e '
  .network == false and .model == "jev-latest" and
  (.questions | index("duplicates_policy")) and
  (.questions | index("disposition")) and
  (.questions | index("validation_strength")) and
  (.inputs | map(.role) | index("plan"))' >/dev/null || fail "preview request inventory"

node "$TEST_CLI" --fixture-response tests/fixtures/typesafe-architecture-review/pass.json --json |
  jq -e '.verdict == "pass" and .provenance == "fixture" and .semantic_review == "not_run" and (.inputs[0].sha256 | length) == 64' >/dev/null ||
  fail "fixture pass report"

if node "$TEST_CLI" --fixture-response tests/fixtures/typesafe-architecture-review/revise.json --json >/dev/null; then
  fail "revise fixture must exit nonzero"
fi
if node "$TEST_CLI" --fixture-response tests/fixtures/typesafe-architecture-review/block.json --json >/dev/null; then
  fail "block fixture must exit nonzero"
fi
if env -u TYPESAFE_API_KEY node "$TEST_CLI" --json >"$TMP/no-key.out" 2>"$TMP/no-key.err"; then
  fail "live mode without credentials must fail"
fi
grep -Fq 'credentials: TYPESAFE_API_KEY is not set' "$TMP/no-key.err" ||
  fail "missing credentials must be a distinct failure"

node --input-type=module <<NODE
import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, symlinkSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
const review = await import(pathToFileURL("$LIB").href);
const pass = JSON.parse(readFileSync("$FIXTURES/pass.json", "utf8"));
const assert = (condition, message) => { if (!condition) throw new Error(message); };
const clone = (value) => JSON.parse(JSON.stringify(value));

const repo = join("$TMP", "repo");
mkdirSync(repo, { recursive: true });
writeFileSync(join(repo, ".gitignore"), "PLAN.md\n");
writeFileSync(join(repo, "PLAN.md"), "# Plan\n- Status: READY\n");
writeFileSync(join(repo, "evidence.md"), "tracked evidence\n");
execFileSync("git", ["init", "-q"], { cwd: repo });
execFileSync("git", ["add", ".gitignore", "evidence.md"], { cwd: repo });
const loaded = review.loadInputs(repo, "PLAN.md", ["evidence.md"]);
assert(loaded.inputs[0].role === "plan", "ignored root PLAN.md must be accepted");
const built = review.buildRequest(loaded.inputs);
assert(built.request.model === "jev-latest", "request model");
assert(new Set(Object.values(built.request.questions).map((question) => question.type)).size === 3, "request must use Noul, Choice, and Score");

const outside = join("$TMP", "outside.md");
writeFileSync(outside, "outside\n");
for (const [name, prepare, expected] of [
  ["external path", () => outside, "outside repository"],
  ["external symlink", () => { symlinkSync(outside, join(repo, "outside-link.md")); return "outside-link.md"; }, "outside repository"],
  ["session export", () => { writeFileSync(join(repo, "pi-session-test.html"), "session"); return "pi-session-test.html"; }, "session export"],
  ["likely secret", () => { writeFileSync(join(repo, ".env"), "SECRET=x"); return ".env"; }, "secret"],
]) {
  let error = null;
  try { review.loadInputs(repo, "PLAN.md", [prepare()]); } catch (cause) { error = cause; }
  assert(error?.kind === "input" && error.message.includes(expected), name + " must be refused");
}

const lowBoundary = clone(pass);
for (const id of ["duplicates_policy", "unsupported_assumptions", "hidden_behavior_change", "missing_validation"]) lowBoundary.answers[id].noul = 0.25;
assert(review.composeReview(lowBoundary, "fixture", []).verdict === "pass", "Noul low boundary must pass");
const highBoundary = clone(pass);
highBoundary.answers.hidden_behavior_change.noul = 0.75;
assert(review.composeReview(highBoundary, "fixture", []).verdict === "block", "blocking Noul high boundary must block");
const uncertainNoul = clone(pass);
uncertainNoul.answers.missing_validation.noul = 0.5;
assert(review.composeReview(uncertainNoul, "fixture", []).verdict === "revise", "uncertain Noul must revise");
const uncertainScore = clone(pass);
uncertainScore.answers.scope_discipline.confidence = 0.54;
assert(review.composeReview(uncertainScore, "fixture", []).verdict === "revise", "uncertain Score must revise");
const choiceConfidenceBoundary = clone(pass);
choiceConfidenceBoundary.answers.disposition.confidence = 0.65;
assert(review.composeReview(choiceConfidenceBoundary, "fixture", []).verdict === "pass", "Choice confidence boundary must pass");
choiceConfidenceBoundary.answers.disposition.confidence = 0.649;
assert(review.composeReview(choiceConfidenceBoundary, "fixture", []).verdict === "revise", "Choice confidence below boundary must revise");
const scoreConfidenceBoundary = clone(pass);
scoreConfidenceBoundary.answers.abstraction_depth.confidence = 0.55;
assert(review.composeReview(scoreConfidenceBoundary, "fixture", []).verdict === "pass", "Score confidence boundary must pass");
scoreConfidenceBoundary.answers.abstraction_depth.confidence = 0.549;
assert(review.composeReview(scoreConfidenceBoundary, "fixture", []).verdict === "revise", "Score confidence below boundary must revise");
const scoreFloorBoundary = clone(pass);
scoreFloorBoundary.answers.abstraction_depth.score = 2;
scoreFloorBoundary.answers.abstraction_depth.probabilities = { "0": 0, "1": 0, "2": 1, "3": 0 };
assert(review.composeReview(scoreFloorBoundary, "fixture", []).verdict === "pass", "Score floor boundary must pass");
scoreFloorBoundary.answers.abstraction_depth.score = 1.99;
scoreFloorBoundary.answers.abstraction_depth.probabilities = { "0": 0, "1": 0.01, "2": 0.99, "3": 0 };
assert(review.composeReview(scoreFloorBoundary, "fixture", []).verdict === "revise", "Score below floor must revise");
const conflict = clone(pass);
conflict.answers.disposition.choice = "revise";
conflict.answers.disposition.probabilities = { pass: 0.15, revise: 0.8, block: 0.05 };
conflict.answers.hidden_behavior_change.noul = 0.9;
assert(review.composeReview(conflict, "fixture", []).verdict === "block", "blocking risk must outrank Choice and scores");
const malformed = clone(pass);
delete malformed.answers.validation_strength;
let malformedError = null;
try { review.composeReview(malformed, "fixture", []); } catch (cause) { malformedError = cause; }
assert(malformedError?.kind === "response", "missing typed answer must fail closed");
const invalidDistribution = clone(pass);
invalidDistribution.answers.disposition.probabilities = { pass: 0.8, revise: 0.4, block: 0.1 };
let distributionError = null;
try { review.composeReview(invalidDistribution, "fixture", []); } catch (cause) { distributionError = cause; }
assert(distributionError?.kind === "response", "invalid probability distributions must fail closed");
for (const mutate of [
  (value) => { delete value.usage; },
  (value) => { delete value.answers.abstraction_depth.legend["3"]; },
  (value) => { [value.answers.abstraction_depth.legend["0"], value.answers.abstraction_depth.legend["3"]] = [value.answers.abstraction_depth.legend["3"], value.answers.abstraction_depth.legend["0"]]; },
  (value) => { value.answers.disposition.choice = "block"; },
  (value) => { value.answers.validation_strength.score = 1; },
]) {
  const invalid = clone(pass);
  mutate(invalid);
  let error = null;
  try { review.composeReview(invalid, "fixture", []); } catch (cause) { error = cause; }
  assert(error?.kind === "response", "incoherent typed response must fail closed");
}

let calls = 0;
const response = await review.requestTypeSafe({ state: {}, model: "jev-latest", questions: {} }, {
  apiKey: "test-key",
  fetchImpl: async (url, options) => {
    calls += 1;
    assert(url === review.ENDPOINT, "fixed endpoint");
    assert(options.redirect === "error", "redirects must be refused");
    assert(options.headers.Authorization === "Bearer test-key", "authorization passed only to transport");
    return new Response(JSON.stringify(pass), { status: 200 });
  },
});
assert(calls === 1 && response.model === "jev-latest", "exactly one request");

for (const status of [401, 429, 529]) {
  let error = null;
  try {
    await review.requestTypeSafe({}, { apiKey: "secret-value", fetchImpl: async () => new Response("sensitive-body", { status }) });
  } catch (cause) { error = cause; }
  assert(error?.kind === "service" && error.status === status, "service status " + status);
  assert(!error.message.includes("sensitive-body") && !error.message.includes("secret-value"), "service errors must not leak body or key");
}
let timeout = null;
try {
  await review.requestTypeSafe({}, { apiKey: "x", fetchImpl: async () => { const error = new Error("abort"); error.name = "AbortError"; throw error; } });
} catch (cause) { timeout = cause; }
assert(timeout?.kind === "timeout", "timeout must be distinct");
let stalledBody = null;
try {
  await review.requestTypeSafe({}, {
    apiKey: "x",
    timeoutMs: 10,
    fetchImpl: async (_url, options) => new Response(new ReadableStream({
      start(controller) {
        options.signal.addEventListener("abort", () => {
          const error = new Error("aborted body");
          error.name = "AbortError";
          controller.error(error);
        });
      },
    }), { status: 200 }),
  });
} catch (cause) { stalledBody = cause; }
assert(stalledBody?.kind === "timeout", "timeout must cover stalled response bodies");
let invalid = null;
try {
  await review.requestTypeSafe({}, { apiKey: "x", fetchImpl: async () => new Response("not-json", { status: 200 }) });
} catch (cause) { invalid = cause; }
assert(invalid?.kind === "response", "invalid response must fail closed");
let oversized = null;
try {
  await review.requestTypeSafe({}, {
    apiKey: "x",
    fetchImpl: async () => new Response("x", { status: 200, headers: { "content-length": String(review.MAX_RESPONSE_BYTES + 1) } }),
  });
} catch (cause) { oversized = cause; }
assert(oversized?.kind === "response", "oversized response must fail before reading the body");
console.log("typesafe architecture review units ok");
NODE

printf 'typesafe architecture review smoke test: ok\n'
