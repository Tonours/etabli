import assert from "node:assert/strict";
import test from "node:test";
import { normalizeEvents, summarizeRuns } from "../scripts/lib/harness-token-usage.mjs";

const coverage = Object.fromEntries(["assistant", "child", "model_tool", "compaction", "retry"]
  .map((name) => [name, { status: "complete", evidence: `test-fixture:${name}` }]));
const piUsage = (input = 10, output = 20, cacheRead = 40, cacheWrite = 5) => ({
  input, output, cacheRead, cacheWrite, totalTokens: input + output + cacheRead + cacheWrite,
  reasoning: output, cost: { total: 0.01 },
});
const piMessage = (usage = piUsage()) => ({ type: "message_end", message: {
  id: "a", role: "assistant", provider: "fixture", model: "model", stopReason: "stop", usage,
  content: [{ type: "text", text: "Final result" }],
} });
const claudeResult = () => ({ type: "result", subtype: "success", is_error: false,
  usage: { input_tokens: 10, output_tokens: 20, cache_read_input_tokens: 100, cache_creation_input_tokens: 11 },
  modelUsage: { "fixture-model": {} }, total_cost_usd: 0.05, result: "Final result" });
const codexTurn = () => ({ type: "turn.completed",
  usage: { input_tokens: 100, output_tokens: 15, cached_input_tokens: 70, reasoning_output_tokens: 10 } });

test("Claude uses one cumulative result despite repeated per-message usage", () => {
  const partial = { type: "assistant", message: { id: "same", usage: claudeResult().usage, content: [] } };
  const value = normalizeEvents("claude", [partial, partial, claudeResult()], { coverage });
  assert.equal(value.measured, true);
  assert.equal(value.usage.total_tokens, 141);
  assert.equal(value.usage.input_tokens, 121);
  assert.equal(value.usage.cost_usd, 0.05);
  assert.equal(value.receipts.length, 1);
});

test("Codex diagnostic receipts preserve subsets without claiming whole-cell provenance", () => {
  const events = [{ type: "turn.started" }, codexTurn()];
  const value = normalizeEvents("codex", events, { coverage });
  assert.equal(value.measured, false);
  assert.equal(value.usage.total_tokens, null);
  assert.equal(value.receipts[0].total_tokens, 115);
  assert.equal(value.receipts[0].reasoning_output_tokens, 10);
  assert.equal(value.receipts[0].cached_input_tokens, 70);
  assert.equal(value.usage.cost_usd, null);
  assert.equal(value.usage.cache_write_input_tokens, null);
});

test("Pi ignores event copies and counts tools and compaction exactly once", () => {
  const message = piMessage();
  const rows = [
    { type: "message_update", assistantMessageEvent: { partial: message.message } }, message,
    { type: "turn_end", message: message.message }, { type: "agent_end", messages: [message.message] },
    { type: "message_end", message: { role: "toolResult", id: "tool-result", toolCallId: "tool", content: [], usage: piUsage(2, 3, 0, 0) } },
    { type: "compaction_end", id: "compact", result: { usage: piUsage(10, 20, 0, 0) } },
  ];
  const value = normalizeEvents("pi", rows, { coverage });
  assert.equal(value.measured, true);
  assert.equal(value.receipts.length, 3);
  assert.equal(value.usage.total_tokens, 110);
  assert.equal(value.usage.reasoning_output_tokens, 43);
});

test("Missing coverage invalidates whole-cell totals", () => {
  const value = normalizeEvents("pi", [piMessage()]);
  assert.equal(value.measured, false);
  assert.equal(value.usage.total_tokens, null);
  assert.equal(value.receipts.length, 1);
  assert.ok(value.measurement_errors.some((error) => error.includes("compaction")));
});

test("Missing receipt fields are unknown rather than zero", () => {
  const message = piMessage(); delete message.message.usage.cacheWrite;
  const value = normalizeEvents("pi", [message], { coverage });
  assert.equal(value.measured, false);
  assert.equal(value.usage.total_tokens, null);
});

test("Pi initialized zero counts cannot masquerade as provider telemetry", () => {
  const message = piMessage(piUsage(0, 0, 0, 0)); message.message.stopReason = "error";
  const value = normalizeEvents("pi", [message], { coverage, exitCode: 0 });
  assert.equal(value.transport_success, false);
  assert.equal(value.measured, false);
  assert.equal(value.usage.total_tokens, null);
});

test("Failed native task can retain its real charged usage", () => {
  const message = piMessage(); message.message.stopReason = "error";
  const value = normalizeEvents("pi", [message], { coverage });
  assert.equal(value.transport_success, false);
  assert.equal(value.measured, true);
  assert.equal(value.usage.total_tokens, 75);
});

test("Complete retry receipts count even after final recovery", () => {
  const first = piMessage(); first.message.stopReason = "error";
  const last = piMessage(); last.message.id = "recovery";
  const value = normalizeEvents("pi", [first, { type: "retry_start" }, last], { coverage });
  assert.equal(value.transport_success, true);
  assert.equal(value.usage.total_tokens, 150);
});

test("A later unfinished Pi turn cannot inherit an earlier successful terminal state", () => {
  const later = piMessage();
  later.message.id = "later-unfinished";
  later.message.stopReason = "toolUse";
  const value = normalizeEvents("pi", [piMessage(), later], { coverage });
  assert.equal(value.transport_success, false);
  assert.equal(value.measured, false);
  assert.equal(value.usage.total_tokens, null);
});

test("Missing summary usage invalidates the entire Pi cell", () => {
  const value = normalizeEvents("pi", [piMessage(), { type: "compaction_end", result: {} }], { coverage });
  assert.equal(value.measured, false);
  assert.equal(value.usage.total_tokens, null);
});

test("Duplicate native receipt identity fails closed", () => {
  for (const [runner, event] of [["pi", piMessage()], ["codex", codexTurn()], ["claude", claudeResult()]]) {
    const value = normalizeEvents(runner, [event, event], { coverage });
    assert.equal(value.measured, false, runner);
    assert.equal(value.usage.total_tokens, null, runner);
  }
});

test("Malformed totals or impossible subsets are rejected", () => {
  const badPi = piMessage(); badPi.message.usage.totalTokens += 1;
  const badCodex = codexTurn(); badCodex.usage.cached_input_tokens = 101;
  const badReasoning = codexTurn(); badReasoning.usage.reasoning_output_tokens = 16;
  for (const [runner, event] of [["pi", badPi], ["codex", badCodex], ["codex", badReasoning]]) {
    assert.equal(normalizeEvents(runner, [event], { coverage }).measured, false);
  }
});

test("Arbitrary native metadata and completion fields cannot invent the effective Codex model", () => {
  for (const metadata of [[], [{ type: "metadata", model: "invented" }]]) {
    const events = [...metadata, { type: "turn.started" }, { ...codexTurn(), model: "also-invented" }];
    const result = normalizeEvents("codex", events, { coverage });
    assert.equal(result.measured, false);
    assert.deepEqual(result.models, []);
  }
});

test("Tool identities preserve exact invocation, result and command evidence", () => {
  const value = normalizeEvents("claude", [
    { type: "assistant", message: { id: "a", content: [{ type: "tool_use", id: "x", name: "Read", input: { file_path: "/skills/verify/SKILL.md" } }] } },
    { type: "user", message: { content: [{ type: "tool_result", tool_use_id: "x", content: "complete untruncated source" }] } },
    claudeResult(),
  ], { coverage });
  assert.deepEqual(value.tools[0], { id: "x", name: "Read", arguments: { file_path: "/skills/verify/SKILL.md" }, turn_id: "a", result: "complete untruncated source", status: "success" });
});

test("Failed attempts stay in numerator and no successes means undefined E", () => {
  const row = (id, success) => ({ id, runner: "pi", arm: "baseline", grade: { success, critical_failure: false }, normalized: { runner: "pi", measured: true, transport_success: true, usage: { total_tokens: 100 } } });
  const [result] = summarizeRuns([row("1", true), row("2", false)]);
  assert.equal(result.total_tokens, 200);
  assert.equal(result.tokens_per_success, 200);
  assert.equal(summarizeRuns([row("3", false)])[0].tokens_per_success, null);
});

test("A critical failure cannot enter the successful-delivery denominator", () => {
  const row = { id: "contradictory", runner: "pi", arm: "candidate",
    grade: { success: true, critical_failure: true },
    normalized: { runner: "pi", measured: true, transport_success: true, usage: { total_tokens: 100 } } };
  assert.throws(() => summarizeRuns([row]), /Contradictory success and critical failure/);
  row.grade.success = false;
  const [result] = summarizeRuns([row]);
  assert.equal(result.total_tokens, 100);
  assert.equal(result.critical_failures, 1);
  assert.equal(result.successes, 0);
  assert.equal(result.tokens_per_success, null);
});

test("Interrupted functional passes stay charged but are not successful deliveries", () => {
  const row = (id, transport_success) => ({ id, runner: "pi", arm: "baseline",
    grade: { success: true, critical_failure: false },
    normalized: { runner: "pi", measured: true, transport_success, usage: { total_tokens: 100 } } });
  const [result] = summarizeRuns([row("delivered", true), row("interrupted", false)]);
  assert.equal(result.total_tokens, 200);
  assert.equal(result.successes, 1);
  assert.equal(result.tokens_per_success, 200);
  const [interrupted] = summarizeRuns([row("interrupted", false)]);
  assert.equal(interrupted.total_tokens, 100);
  assert.equal(interrupted.successes, 0);
  assert.equal(interrupted.tokens_per_success, null);
});

test("Explicit failed delivery adjudication cannot be overridden by successful transport", () => {
  const row = { id: "abandoned", runner: "pi", arm: "candidate",
    grade: { success: true, critical_failure: false },
    normalized: { runner: "pi", measured: true, transport_success: true, usage: { total_tokens: 100 } },
    delivery: { effective_success: false } };
  const [result] = summarizeRuns([row]);
  assert.equal(result.total_tokens, 100);
  assert.equal(result.successes, 0);
  assert.equal(result.tokens_per_success, null);
});

test("Missing or malformed delivery evidence leaves the population inconclusive", () => {
  const row = { id: "unknown-delivery", runner: "pi", arm: "candidate",
    grade: { success: true, critical_failure: false },
    normalized: { runner: "pi", measured: true, usage: { total_tokens: 100 } } };
  const invalid = [undefined, null, "false", "true", 0];
  for (const transport_success of invalid) {
    const [result] = summarizeRuns([{ ...row, normalized: { ...row.normalized, transport_success } }]);
    assert.equal(result.successes, 0);
    assert.equal(result.measured, false);
    assert.equal(result.tokens_per_success, null);
  }
  for (const effective_success of invalid) {
    const [result] = summarizeRuns([{ ...row, normalized: { ...row.normalized, transport_success: true },
      delivery: { effective_success } }]);
    assert.equal(result.successes, 0);
    assert.equal(result.measured, false);
    assert.equal(result.tokens_per_success, null);
  }
});

test("Missing or malformed critical-failure grades leave the population inconclusive", () => {
  for (const critical_failure of [undefined, "true", "false", 0, null]) {
    const row = { id: "ungraded-critical", runner: "pi", arm: "candidate",
      grade: { success: true, critical_failure },
      normalized: { runner: "pi", measured: true, transport_success: true, usage: { total_tokens: 100 } } };
    const [result] = summarizeRuns([row]);
    assert.equal(result.measured, false);
    assert.equal(result.status, "inconclusive");
    assert.equal(result.successes, 0);
    assert.equal(result.tokens_per_success, null);
  }
});

test("Unknown usage or grading prevents partial averages", () => {
  const rows = [
    { id: "1", runner: "pi", arm: "candidate", grade: { success: true }, normalized: { runner: "pi", measured: true, transport_success: true, usage: { total_tokens: 100 } } },
    { id: "2", runner: "pi", arm: "candidate", grade: { success: false }, normalized: { runner: "pi", measured: false, usage: { total_tokens: null } } },
  ];
  assert.equal(summarizeRuns(rows)[0].tokens_per_success, null);
  assert.equal(summarizeRuns(rows)[0].status, "inconclusive");
  assert.throws(() => summarizeRuns([rows[0], rows[0]]), /duplicate/);
});

test("The grading artifact excludes commentary and duplicate final message copies", () => {
  const value = normalizeEvents("claude", [
    { type: "assistant", message: { content: [{ type: "text", text: "Interim claim" }] } },
    { type: "assistant", message: { content: [{ type: "text", text: "Final result" }] } },
    claudeResult(),
  ], { coverage });
  assert.equal(value.final_text, "Final result");
});

test("Coverage declarations cannot hide observed child, summary or retry calls", () => {
  for (const [name, extra] of [
    ["assistant", {}],
    ["child", { type: "assistant", parent_tool_use_id: "parent", message: { content: [] } }],
    ["retry", { type: "auto_retry_start" }],
    ["compaction", { type: "compaction_start" }],
  ]) {
    const declared = { ...coverage, [name]: { status: "not_triggered", evidence: "contradicted" } };
    const rows = name === "assistant" ? [claudeResult()] : [extra, claudeResult()];
    const value = normalizeEvents("claude", rows, { coverage: declared });
    assert.equal(value.measured, false, name);
    assert.equal(value.usage.total_tokens, null, name);
    assert.ok(value.measurement_errors.some((error) => error.includes(`observed ${name}`)));
  }
});

test("Native OAuth failure with synthetic zero usage is unmeasured despite success subtype", () => {
  const event = claudeResult();
  event.is_error = true;
  for (const key of Object.keys(event.usage)) event.usage[key] = 0;
  event.modelUsage = {};
  event.result = "Failed to authenticate: OAuth session expired and could not be refreshed";
  const value = normalizeEvents("claude", [event], { coverage });
  assert.equal(value.transport_success, false);
  assert.equal(value.measured, false);
  assert.equal(value.usage.total_tokens, null);
});

test("Anonymous native receipts cannot be counted twice", () => {
  const pi = piMessage(); delete pi.message.id;
  const codex = codexTurn(); delete codex.turn_id;
  for (const [runner, rows] of [
    ["pi", [pi, pi]],
    ["codex", [{ type: "turn.started" }, codex, codex]],
  ]) {
    const value = normalizeEvents(runner, rows, { coverage });
    assert.equal(value.measured, false, runner);
    assert.equal(value.usage.total_tokens, null, runner);
  }
});

test("Codex failed or unfinished later turns cannot disappear from cell accounting", () => {
  for (const suffix of [[], [{ type: "turn.failed", error: { message: "lost receipt" } }]]) {
    const rows = [{ type: "turn.started" }, codexTurn(), { type: "turn.started" }, ...suffix];
    const value = normalizeEvents("codex", rows, { coverage });
    assert.equal(value.measured, false);
    assert.equal(value.transport_success, false);
    assert.equal(value.usage.total_tokens, null);
  }
});

test("Native anonymous Codex turns use their observed turn boundaries", () => {
  const first = codexTurn(); delete first.turn_id;
  const events = [
    { type: "turn.started" }, first, { type: "turn.started" }, first,
  ];
  const value = normalizeEvents("codex", events, { coverage });
  assert.equal(value.measured, false);
  assert.equal(value.receipts.reduce((sum, receipt) => sum + receipt.total_tokens, 0), 230);
  assert.ok(value.measurement_errors.every(error => /provenance/.test(error)));
});

test("Codex reconnect recovery requires retry coverage and a successful final turn", () => {
  const rows = [{ type: "turn.started" }, { type: "error", message: "Reconnecting... 1/5" }, codexTurn()];
  const recovered = normalizeEvents("codex", rows, { coverage });
  assert.equal(recovered.transport_success, true);
  assert.equal(recovered.measured, false);
  assert.ok(recovered.measurement_errors.every(error => /provenance/.test(error)));
  const uncovered = normalizeEvents("codex", rows, { coverage: {
    ...coverage, retry: { status: "not_triggered", evidence: "incorrect declaration" },
  } });
  assert.equal(uncovered.measured, false);
  assert.equal(normalizeEvents("codex", rows, { coverage, exitCode: 1 }).transport_success, false);
  const suffixError = normalizeEvents("codex", [...rows, { type: "error", message: "fatal" }], { coverage });
  assert.equal(suffixError.transport_success, false);
});

test("A successful Codex terminal event cannot erase a fatal prefix error", () => {
  for (const message of ["fatal provider error", "fatal retry error", "failed after Reconnecting... 1/5"]) {
    const events = [{ type: "turn.started" }, { type: "error", message }, codexTurn()];
    const result = normalizeEvents("codex", events, { coverage });
    assert.equal(result.receipts[0].total_tokens, 115);
    assert.equal(result.transport_success, false);
  }
});

test("Codex successful retry does not erase a previous missing charged receipt", () => {
  const value = normalizeEvents("codex", [
    { type: "turn.started" }, { type: "turn.failed", error: { message: "lost usage" } },
    { type: "turn.started" }, { ...codexTurn(), turn_id: "recovery" },
  ], { coverage });
  assert.equal(value.transport_success, true);
  assert.equal(value.measured, false);
  assert.equal(value.usage.total_tokens, null);
});

test("A provider receipt cannot be attributed to another harness population", () => {
  const row = { id: "wrong-runner", runner: "codex", arm: "candidate", grade: { success: true },
    normalized: normalizeEvents("pi", [piMessage()], { coverage }) };
  assert.throws(() => summarizeRuns([row]), /runner disagrees/);
});

test("Pi provider response identities reject replay under another local message identity", () => {
  const first = piMessage(); first.message.responseId = "provider-response";
  const last = structuredClone(first); last.message.id = "another-local-id";
  const value = normalizeEvents("pi", [first, last], { coverage });
  assert.equal(value.measured, false);
});

test("Pi provider tokens stay measurable when SDK pricing metadata is unavailable", () => {
  const event = piMessage(); event.message.usage.cost.total = 0;
  const value = normalizeEvents("pi", [event], { coverage });
  assert.equal(value.measured, true);
  assert.equal(value.usage.total_tokens, 75);
  assert.equal(value.usage.cost_usd, null);
});
