import { describe, test, before, after } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { MARKER, writeCarriedFixture, writeDuplicateCallFixture, writeFixture } from "./fixtures/claude-usage-audit.mjs";

const script = fileURLToPath(new URL("../scripts/claude-usage-audit", import.meta.url));
const skipped = (file) => new RegExp(`skipped unreadable ${file.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")} \\(`);
const audit = (...args) => spawnSync(process.execPath, [script, ...args], { encoding: "utf8" });

describe("claude-usage-audit", () => {
  let dir;
  let expected;
  let out;
  let raw;
  let stderr;
  before(() => {
    dir = mkdtempSync(join(tmpdir(), "usage-audit-"));
    expected = writeFixture(dir);
    const lockedMeta = join(dir, "projects", "-tmp-fabricated-project", "sess-cli", "subagents", "agent-locked.meta.json");
    chmodSync(lockedMeta, 0);
    const child = audit("--days", "7", "--claude-dir", dir);
    chmodSync(lockedMeta, 0o600);
    assert.equal(child.status, 0, child.stderr);
    stderr = child.stderr;
    raw = child.stdout;
    out = JSON.parse(raw);
  });
  after(() => rmSync(dir, { recursive: true, force: true }));

  test("never prints message content", () => {
    assert.equal(raw.includes(MARKER), false);
  });

  test("dedups streamed lines and skips synthetic, malformed and out-of-window rows", () => {
    assert.equal(out.schema.dedupedAssistantTurns, expected.mainTurns + expected.subagentTurns);
    assert.equal(out.schema.assistantLinesDuplicate, 2);
    assert.equal(out.schema.syntheticModelTurns, 1);
    assert.equal(out.schema.parseErrors, expected.parseErrors);
    assert.equal(out.a_total.output, expected.totalOutput);
    assert.equal(out.a_total.input, expected.totalInput);
    assert.deepEqual([out.a_tokensByModel["claude-sonnet-5-5"].main.cacheWrite5m, out.a_tokensByModel["claude-sonnet-5-5"].main.cacheWrite1h], [0, 40000 + 220000 + 10000]);
  });

  test("keeps the reference top-level sections", () => {
    assert.deepEqual(Object.keys(out), ["meta", "a_tokensByModel", "a_total", "a_unpricedModels", "a_perDay", "b_subagents", "c_sessions", "d_context", "e_cache", "f_toolResults", "g_firstTurnOverhead", "h_byEntrypoint", "h_topProjects", "i_effort", "j_carriedVsUsed", "schema"]);
  });

  test("prints transcript metadata only as classes", () => {
    assert.equal(out.a_tokensByModel["(other)"].main.output, 2);
    assert.equal(out.i_effort.byModelEffort["(other)|(other)"].turns, 1);
    assert.deepEqual(out.d_context.compactBoundaryByTrigger, { "(other)": 1 });
    assert.equal(out.h_byEntrypoint["(other)"].sessions, 1);
    assert.deepEqual(out.b_subagents.byType["(other)"].metaRequestedModel, { "(other)": 1 });
    assert.equal(out.f_toolResults.topTools["(other)"].calls, 1);
  });

  test("reports an unreadable subagent meta file", () => {
    if (process.getuid?.() === 0) return;
    assert.equal(out.schema.unreadableFiles, 1);
    assert.match(stderr, skipped(join(dir, "projects", "-tmp-fabricated-project", "sess-cli", "subagents", "agent-locked.meta.json")));
  });

  test("resolves tool results after every file, whatever the order", () => {
    assert.equal(out.f_toolResults.topTools.Read.calls, 1);
    assert.equal("(unmatched)" in out.f_toolResults.topGroups, false);
  });

  test("attributes subagents by meta type and by the model they ran on", () => {
    assert.deepEqual(out.b_subagents.byType["general-purpose"].ranOnModel, { "claude-sonnet-5-5": 1 });
    assert.equal(out.b_subagents.byType["general-purpose"].sameModelAsParent, 1);
    assert.deepEqual(out.b_subagents.byType["(other)"].ranOnModel, { "claude-opus-5-5": 1 });
    assert.equal(out.b_subagents.differentModelFromParent, 1);
    assert.equal(out.b_subagents.byModel["claude-sonnet-5-5"].tokens.output, 40 + 40 + 5);
    assert.equal(out.b_subagents.byModel["claude-opus-5-5"].tokens.output, 10 + 1 + 1);
    assert.equal(out.b_subagents.runs, 4);
    assert.equal(out.b_subagents.byType["stale-parent"].sameModelAsParent, 1);
    assert.equal(out.b_subagents.byType["late-start"].sameModelAsParent, 1);
    assert.equal(out.b_subagents.parentModelUnknown, 0);
    assert.deepEqual(out.b_subagents.agentToolCallsBySubagentTypeAndModelParam, { "general-purpose|(unset)": 1, "(other)|(other)": 1, "general-purpose|sonnet": 1 });
  });

  test("prints no Bash command words", () => {
    assert.equal("bashTopLeadingWords" in out.f_toolResults, false);
    for (const word of ["echo", "git", "cat", "API_TOKEN", "LABEL"]) assert.equal(raw.includes(`"${word}`), false, word);
    assert.equal(out.f_toolResults.bashCallsTotal, Object.values(out.f_toolResults.bashResultSizeHistogram).reduce((n, b) => n + b.calls, 0));
    assert.equal(out.f_toolResults.bashCallsExplicitRtk, 1);
  });

  test("buckets Bash result sizes on inclusive upper bounds", () => {
    const calls = Object.fromEntries(out.f_toolResults.bashResultSizeHistogram.map((b) => [b.bucket, b.calls]));
    assert.deepEqual(calls, { "<=4000": 10, "<=8000": 1, "<=15000": 1, "<=20000": 1, "<=30000": 1, "<=50000": 0, "<=128000": 0, ">128000": 1 });
    const chars = out.f_toolResults.bashResultSizeHistogram.reduce((sum, b) => sum + b.chars, 0);
    assert.equal(chars, expected.bashResultChars);
  });

  test("reports first-turn context per entrypoint", () => {
    assert.equal(out.g_firstTurnOverhead.mainSessionsStartedBeforeWindow, 1);
    assert.equal(out.g_firstTurnOverhead.mainSessionFirstTurnCtx.n, 3);
    const byEntry = out.g_firstTurnOverhead.mainSessionFirstTurnCtxByEntrypoint;
    assert.deepEqual(Object.keys(byEntry), ["(other)", "cli", "sdk-cli"]);
    for (const [entry, ctx] of Object.entries(expected.firstTurnCtx)) {
      assert.deepEqual(byEntry[entry], { n: 1, p50: ctx, p90: ctx, max: ctx });
    }
  });

  test("handles a home without transcripts and rejects a bad window", () => {
    const empty = mkdtempSync(join(tmpdir(), "usage-audit-empty-"));
    try {
      const missing = audit("--claude-dir", empty);
      assert.equal(missing.status, 2);
      assert.match(missing.stderr, /cannot read .*projects/);
      mkdirSync(join(empty, "projects", "locked"), { recursive: true });
      chmodSync(join(empty, "projects", "locked"), 0);
      writeFileSync(join(empty, "projects", "locked.jsonl"), "{}\n");
      chmodSync(join(empty, "projects", "locked.jsonl"), 0);
      const child = audit("--claude-dir", empty, "--seven-day-used-pct", "42");
      chmodSync(join(empty, "projects", "locked"), 0o700);
      if (process.getuid?.() !== 0) {
        const { schema } = JSON.parse(child.stdout);
        assert.equal(schema.unreadableDirs, 1);
        assert.equal(schema.unreadableFiles, 1);
        assert.equal(schema.filesScanned, 0);
        assert.match(child.stderr, skipped(join(empty, "projects", "locked")));
        assert.match(child.stderr, skipped(join(empty, "projects", "locked.jsonl")));
      }
      assert.equal(child.status, 0, child.stderr);
      const result = JSON.parse(child.stdout);
      assert.equal(result.a_total.turns, 0);
      assert.equal(result.meta.sevenDayUsedPct, 42);
    } finally {
      rmSync(empty, { recursive: true, force: true });
    }
    const bad = audit("--days", "0");
    assert.equal(bad.status, 2);
    assert.match(bad.stderr, /--days must be a positive number/);
    for (const argv of [["--claude-dir"], ["--days=7"], ["--days", "--claude-dir", empty], ["--bogus", "1"], ["--days", "1e300"], ["--claude-dir", "--bogus"], ["--seven-day-used-pct", "101"]]) {
      const child = audit(...argv);
      assert.equal(child.status, 2, argv.join(" "));
      assert.equal(child.stdout, "");
    }
    const help = audit("--help");
    assert.equal(help.status, 0);
    assert.match(help.stdout, /keep it private/);
  });
});

describe("claude-usage-audit j_carriedVsUsed", () => {
  const row = (carriedSessions, usedSessions, calls) => ({ carriedSessions, usedSessions, calls });
  const run = (write) => {
    const dir = mkdtempSync(join(tmpdir(), "usage-audit-carried-"));
    try {
      write(dir);
      const child = audit("--days", "7", "--claude-dir", dir);
      assert.equal(child.status, 0, child.stderr);
      return { raw: child.stdout, out: JSON.parse(child.stdout) };
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  };
  let raw;
  let j;
  let schema;
  before(() => {
    const r = run((dir) => writeCarriedFixture(dir));
    raw = r.raw;
    j = r.out.j_carriedVsUsed;
    schema = r.out.schema;
  });

  test("counts carried sessions, used sessions and calls per tool (A1, A4, A7, A8, A9)", () => {
    assert.deepEqual(j.builtinToolsByEntrypoint.cli, {
      Agent: row(0, 2, 4), Read: row(2, 1, 3), Glob: row(0, 1, 1), Grep: row(0, 1, 1),
      "(other)": row(1, 0, 0), Bash: row(1, 0, 0), WebSearch: row(1, 0, 0),
    });
    assert.deepEqual(j.builtinToolsByEntrypoint["(unknown)"], { Write: row(0, 1, 1) });
  });

  test("keys a server on one normalized name across instructions and tools (A2)", () => {
    assert.deepEqual(j.mcpServers, {
      claude_ai_Foo_Bar: { carriedSessions: 1, instructionSessions: 1, usedSessions: 1, calls: 1 },
      claude_ai_Baz_Qux: { carriedSessions: 1, instructionSessions: 1, usedSessions: 0, calls: 0 },
      "(other)": { carriedSessions: 1, instructionSessions: 0, usedSessions: 0, calls: 0 },
      srv_one: { carriedSessions: 1, instructionSessions: 0, usedSessions: 0, calls: 0 },
    });
  });

  test("lists agent types carried and spawned, unknown spawned types as a class (A3)", () => {
    assert.deepEqual(j.agentTypes, {
      "(other)": row(0, 1, 1), "general-purpose": row(1, 1, 1), Plan: row(0, 1, 1), reviewer: row(0, 1, 1), Explore: row(2, 0, 0),
    });
  });

  test("counts sessions started in the window and those with a tool snapshot (A4, A6)", () => {
    assert.deepEqual(j.sessionsStarted, {
      "(unknown)": { sessions: 1, withToolSnapshot: 0 }, cli: { sessions: 2, withToolSnapshot: 2 }, "sdk-cli": { sessions: 1, withToolSnapshot: 0 },
    });
  });

  test("never prints attachment text (A5)", () => {
    assert.equal(raw.includes(MARKER), false);
  });

  test("counts every line whose calls the use counts may miss (A10)", () => {
    assert.equal(schema.toolScanGaps, 4);
    assert.equal(schema.parseErrors, 3);
  });

  test("counts an in-window call once whatever the order of an older copy (A8)", () => {
    for (const oldInA of [true, false]) {
      const { out } = run((dir) => writeDuplicateCallFixture(dir, oldInA));
      assert.deepEqual(out.j_carriedVsUsed.builtinToolsByEntrypoint["(unknown)"], { Explore: row(0, 1, 1) }, `oldInA=${oldInA}`);
    }
  });

  test("credits a call copied into two sessions to one of them whatever the file order", () => {
    for (const oldInA of [true, false]) {
      const { out } = run((dir) => writeDuplicateCallFixture(dir, oldInA, Date.now(), true));
      assert.deepEqual(out.j_carriedVsUsed.sessionsStarted, { "(unknown)": { sessions: 1, withToolSnapshot: 0 }, cli: { sessions: 1, withToolSnapshot: 0 } }, `oldInA=${oldInA}`);
      assert.deepEqual(out.j_carriedVsUsed.builtinToolsByEntrypoint, { cli: { Explore: row(0, 1, 1) } }, `oldInA=${oldInA}`);
    }
  });
});
