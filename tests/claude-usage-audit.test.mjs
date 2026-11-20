import { describe, test, before, after } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { MARKER, writeFixture } from "./fixtures/claude-usage-audit.mjs";

const script = fileURLToPath(new URL("../scripts/claude-usage-audit", import.meta.url));
const audit = (...args) => spawnSync(process.execPath, [script, ...args], { encoding: "utf8" });

describe("claude-usage-audit", () => {
  let dir;
  let expected;
  let out;
  let raw;
  before(() => {
    dir = mkdtempSync(join(tmpdir(), "usage-audit-"));
    expected = writeFixture(dir);
    const child = audit("--days", "7", "--claude-dir", dir);
    assert.equal(child.status, 0, child.stderr);
    raw = child.stdout;
    out = JSON.parse(raw);
  });
  after(() => rmSync(dir, { recursive: true, force: true }));

  test("never prints message content", () => {
    assert.equal(raw.includes(MARKER), false);
  });

  test("dedups streamed lines and skips synthetic, malformed and out-of-window rows", () => {
    assert.equal(out.schema.dedupedAssistantTurns, expected.mainTurns + expected.subagentTurns);
    assert.equal(out.schema.assistantLinesDuplicate, 1);
    assert.equal(out.schema.syntheticModelTurns, 1);
    assert.equal(out.schema.parseErrors, 3);
    assert.equal(out.a_total.output, 100 + 80 + 7 + 20 + 20 + 40 + 40 + 10 + 5 + 2 + 3);
    assert.equal(out.a_total.input, 10 + 5 + 1 + 10 + 1 + 10 + 10 + 10 + 10 + 1);
    assert.equal(out.a_tokensByModel.constructor.main.output, 2);
  });

  test("keeps the reference top-level sections", () => {
    assert.deepEqual(Object.keys(out), ["meta", "a_tokensByModel", "a_total", "a_unpricedModels", "a_perDay", "b_subagents", "c_sessions", "d_context", "e_cache", "f_toolResults", "g_firstTurnOverhead", "h_byEntrypoint", "h_topProjects", "i_effort", "schema"]);
  });

  test("attributes subagents by meta type and by the model they ran on", () => {
    assert.deepEqual(out.b_subagents.byType["general-purpose"].ranOnModel, { "claude-sonnet-5-5": 1 });
    assert.deepEqual(out.b_subagents.byType["(no-meta)"].ranOnModel, { "claude-opus-5-5": 1 });
    assert.equal(out.b_subagents.byModel["claude-sonnet-5-5"].tokens.output, 40 + 40 + 5);
    assert.equal(out.b_subagents.byModel["claude-opus-5-5"].tokens.output, 10);
    assert.equal(out.b_subagents.runs, 2);
    assert.deepEqual(out.b_subagents.agentToolCallsBySubagentTypeAndModelParam, { "general-purpose|(unset)": 1 });
  });

  test("buckets Bash result sizes on inclusive upper bounds", () => {
    const calls = Object.fromEntries(out.f_toolResults.bashResultSizeHistogram.map((b) => [b.bucket, b.calls]));
    assert.deepEqual(calls, { "<=4000": 1, "<=8000": 1, "<=15000": 1, "<=20000": 1, "<=30000": 1, "<=50000": 0, "<=128000": 0, ">128000": 1 });
    const chars = out.f_toolResults.bashResultSizeHistogram.reduce((sum, b) => sum + b.chars, 0);
    assert.equal(chars, expected.bashResultChars);
  });

  test("reports first-turn context per entrypoint", () => {
    assert.equal(out.g_firstTurnOverhead.mainSessionsStartedBeforeWindow, 1);
    assert.equal(out.g_firstTurnOverhead.mainSessionFirstTurnCtx.n, 2);
    const byEntry = out.g_firstTurnOverhead.mainSessionFirstTurnCtxByEntrypoint;
    assert.deepEqual(Object.keys(byEntry), ["cli", "sdk-cli"]);
    for (const [entry, ctx] of Object.entries(expected.firstTurnCtx)) {
      assert.deepEqual(byEntry[entry], { n: 1, p50: ctx, p90: ctx, max: ctx });
    }
  });

  test("handles a home without transcripts and rejects a bad window", () => {
    const empty = mkdtempSync(join(tmpdir(), "usage-audit-empty-"));
    try {
      const child = audit("--claude-dir", empty);
      assert.equal(child.status, 0, child.stderr);
      const result = JSON.parse(child.stdout);
      assert.equal(result.a_total.turns, 0);
      assert.equal(result.meta.files, 0);
    } finally {
      rmSync(empty, { recursive: true, force: true });
    }
    const bad = audit("--days", "0");
    assert.equal(bad.status, 2);
    assert.match(bad.stderr, /--days must be a positive number/);
    for (const argv of [["--claude-dir"], ["--days=7"], ["--days", "--claude-dir", empty], ["--bogus", "1"], ["--days", "1e300"], ["--claude-dir", "--bogus"]]) {
      const child = audit(...argv);
      assert.equal(child.status, 2, argv.join(" "));
      assert.equal(child.stdout, "");
    }
    const help = audit("--help");
    assert.equal(help.status, 0);
    assert.match(help.stdout, /keep it private/);
  });
});
