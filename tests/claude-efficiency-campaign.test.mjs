import assert from "node:assert/strict";
import { test } from "node:test";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import {
  inventory,
  validateArms,
  nextReservation,
  nativeUsage,
  snapshot,
  checkScope,
  checkProtected,
  gradeFindings,
  LIMITS,
} from "../scripts/lib/claude-efficiency-campaign.mjs";
import {
  suite,
  gradeFixture,
  corpus,
} from "../scripts/lib/claude-efficiency-fixtures.mjs";
import { dispatch } from "../scripts/lib/claude-efficiency-mcp.mjs";
const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const fixtures = suite();
function render(id, action) {
  const work = mkdtempSync(join(tmpdir(), "efficiency-fixture-"));
  try {
    for (const [path, content] of Object.entries(fixtures[id].files)) {
      const full = join(work, path);
      mkdirSync(dirname(full), { recursive: true });
      writeFileSync(full, content);
    }
    return action(work, snapshot(work));
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
}
test("36 paired cells, two holdouts, six reserved auxiliary slots and stable order", () => {
  const result = inventory();
  assert.deepEqual(result, inventory());
  assert.equal(result.comparative.length, 36);
  assert.equal(result.auxiliary.length, 6);
  assert.equal(new Set(result.comparative.map((c) => c.id)).size, 36);
  assert.equal(result.comparative.filter((c) => c.holdout).length, 12);
  for (let i = 0; i < 36; i += 2) {
    const a = result.comparative[i],
      b = result.comparative[i + 1];
    assert.equal(a.task, b.task);
    assert.equal(a.rep, b.rep);
    assert.notEqual(a.arm, b.arm);
    assert.equal(a.status, "not_run");
    assert.equal(a.usage.processed_total_tokens, null);
  }
  assert.throws(() => inventory(-1));
});
test("only effort can vary", () => {
  const common = {
    model: "exact-native-opus",
    store: "same",
    plugins: { a: true },
    mcp: "same",
    agents: "same",
  };
  assert.ok(
    validateArms({ ...common, effort: "medium" }, { ...common, effort: "low" }),
  );
  assert.throws(() =>
    validateArms(
      { ...common, effort: "medium" },
      { ...common, effort: "low", model: "sonnet" },
    ),
  );
});
test("reservation counts failed slots, forbids free retry and reserves time before spawn", () => {
  const slot = inventory().comparative[0].id,
    start = { launched: 0, live_ms: 0, used_slots: [] };
  const state = nextReservation(start, slot, 0);
  assert.equal(state.launched, 1);
  assert.equal(state.timeout_ms, 300000);
  assert.equal(state.live_ms, 300000);
  assert.throws(() => nextReservation(state, slot, 0));
  assert.throws(() => nextReservation({ ...start, launched: 42 }, slot, 0));
  assert.throws(() => nextReservation({ ...start, live_ms: 7200000 }, slot, 0));
  assert.equal(
    nextReservation({ ...start, live_ms: 7199900 }, slot, 0).timeout_ms,
    100,
  );
  assert.throws(() => nextReservation({ ...start, live_ms: NaN }, slot, 0));
  assert.equal(nextReservation(state, "A6", 10).launched, 2);
});
test("explicit zero differs from absent/null/string and incomplete total stays null", () => {
  assert.equal(nativeUsage(null).processed_total_tokens, null);
  assert.equal(
    nativeUsage({ input_tokens: null, output_tokens: "0" }).input_tokens,
    null,
  );
  assert.equal(
    nativeUsage({
      input_tokens: 0,
      output_tokens: 0,
      cache_read_input_tokens: 0,
      cache_creation_input_tokens: 0,
    }).processed_total_tokens,
    0,
  );
  assert.equal(
    nativeUsage({
      input_tokens: 1,
      output_tokens: 2,
      cache_read_input_tokens: 3,
      cache_creation_input_tokens: 4,
    }).processed_total_tokens,
    10,
  );
});
test("scope catches untracked and oracle tampering; findings reject duplicates/false positives", () => {
  render("T4", (work, before) => {
    writeFileSync(join(work, "untracked.txt"), "unexpected");
    assert.deepEqual(checkScope(before, snapshot(work), []), ["untracked.txt"]);
  });
  assert.throws(() => checkProtected({ oracle: "a" }, { oracle: "b" }));
  assert.equal(
    gradeFindings(
      [null, null],
      [
        { path: "a", line: 1 },
        { path: "b", line: 2 },
      ],
    ),
    false,
  );
  const expected = [
    { path: "a", line: 1 },
    { path: "b", line: 2 },
  ];
  assert.ok(
    gradeFindings(
      expected.map((f) => ({ ...f, reason: "real bug" })),
      expected,
    ),
  );
  assert.equal(
    gradeFindings(
      [
        { path: "a", line: 1, reason: "bug" },
        { path: "a", line: 1, reason: "duplicate" },
      ],
      expected,
    ),
    false,
  );
  assert.equal(
    gradeFindings([...expected, { path: "c", line: 3 }], expected),
    false,
  );
});
test("T1 anchors must be actual exports and route facts exact", () =>
  render("T1", (work, before) => {
    const lines =
      fixtures.T1.files["workflow/runtime/obvault-topic-resolver.mjs"].split(
        "\n",
      );
    const response = {
      anchors: ["projectVaultRoots", "resolveObvaultRoot"].map((name) => ({
        function: name,
        file: "workflow/runtime/obvault-topic-resolver.mjs",
        line:
          lines.findIndex((line) =>
            line.startsWith(`export function ${name}(`),
          ) + 1,
      })),
      routes: { override: "exclusive", forest: "brain", other: "obvault" },
    };
    assert.ok(gradeFixture("T1", { work, before, response }).passed);
    assert.equal(
      gradeFixture("T1", {
        work,
        before,
        response: { anchors: [null, null], routes: response.routes },
      }).passed,
      false,
    );
    response.anchors[0].line++;
    assert.equal(gradeFixture("T1", { work, before, response }).passed, false);
  }));
test("T2 external oracle rejects original non-strict bug, accepts minimal correction", () =>
  render("T2", (work, before) => {
    assert.equal(gradeFixture("T2", { work, before }).passed, false);
    const fixed = fixtures.T2.files["profile.mjs"]
      .replace(
        'args.push("--strict-mcp-config", "--mcp-config", rendered.path);',
        'args.push("--strict-mcp-config");',
      )
      .replace(
        "args.push(...extraArgs);",
        'args.push("--mcp-config", rendered.path, ...extraArgs);',
      );
    writeFileSync(join(work, "profile.mjs"), fixed);
    assert.ok(gradeFixture("T2", { work, before }).passed);
  }));
test("T3 external oracle rejects no-op and accepts specified normalizer", () =>
  render("T3", (work, before) => {
    assert.equal(gradeFixture("T3", { work, before }).passed, false);
    writeFileSync(
      join(work, "usage.mjs"),
      `export function normalize(raw){const names={input_tokens:'input_tokens',output_tokens:'output_tokens',cache_read_tokens:'cache_read_input_tokens',cache_creation_tokens:'cache_creation_input_tokens'};const result=Object.fromEntries(Object.entries(names).map(([key,name])=>{const value=raw?.[name];return [key,typeof value==='number'&&Number.isInteger(value)&&value>=0?value:null]}));return {...result,processed_total_tokens:Object.values(result).some(n=>n===null)?null:Object.values(result).reduce((a,b)=>a+b,0)};}`,
    );
    assert.ok(gradeFixture("T3", { work, before }).passed);
  }));
test("oracle requires completed assertions and checks scope after import", () =>
  render("T3", (work, before) => {
    writeFileSync(join(work, "usage.mjs"), "process.exit(0);");
    assert.equal(gradeFixture("T3", { work, before }).passed, false);
    writeFileSync(
      join(work, "usage.mjs"),
      `import {writeFileSync} from 'node:fs';writeFileSync(new URL('./untracked.txt',import.meta.url),'tamper');process.exit(0);`,
    );
    const result = gradeFixture("T3", { work, before });
    assert.equal(result.passed, false);
    assert.equal(result.reason, "oracle import mutated scope");
  }));
test("T4 no false positive on correct control", () =>
  render("T4", (work, before) => {
    const response = {
      findings: [
        {
          path: "price.mjs",
          line: 2,
          reason: "Rate is fractional; multiply price by rate",
          repro: { args: [100, 0.2], actual: 99.8, expected: 80 },
        },
        {
          path: "settings.mjs",
          line: 2,
          reason: "Zero must not use the default",
          repro: { args: [0], actual: 10, expected: 0 },
        },
      ],
    };
    assert.ok(gradeFixture("T4", { work, before, response }).passed);
    const stringLines = {
      findings: response.findings.map((f) => ({
        path: f.path,
        line: String(f.line),
        reason: "Some bug",
      })),
    };
    assert.equal(
      gradeFixture("T4", { work, before, response: stringLines }).passed,
      false,
    );
    const falseReasons = {
      findings: response.findings.map((f) => ({
        ...f,
        reason: "This line is correct; no defect.",
      })),
    };
    assert.equal(
      gradeFixture("T4", { work, before, response: falseReasons }).passed,
      false,
    );
    response.findings.push({
      path: "correct.mjs",
      line: 2,
      reason: "invented",
    });
    assert.equal(gradeFixture("T4", { work, before, response }).passed, false);
  }));
test("T5 holdout behavior and preserved ledger/handoff", () =>
  render("T5", (work, before) => {
    const response = {
      objective: "Resume the visibility correction.",
      done: ["parser"],
      pending: ["visibility", "full-check"],
      files: ["resume.mjs"],
      next_action: { step: "visibility", operation: "validate" },
      do_not_redo: ["parser"],
    };
    assert.equal(gradeFixture("T5", { work, before, response }).passed, false);
    writeFileSync(
      join(work, "resume.mjs"),
      `export function remaining(events,planned){const state=new Map(events.map(e=>[e.step,e.exit]));return planned.filter(step=>state.get(step)!==0);}`,
    );
    assert.ok(gradeFixture("T5", { work, before, response }).passed);
    writeFileSync(join(work, "events.jsonl"), "");
    assert.equal(gradeFixture("T5", { work, before, response }).passed, false);
  }));
test("T6 requires successful read-only MCP calls as well as factual answer", () =>
  render("T6", (work, before) => {
    const calls = [];
    for (const [name, id] of [
      ["get_ticket", "TKT-42"],
      ["get_document", "DOC-17"],
    ])
      assert.equal(
        dispatch(
          {
            jsonrpc: "2.0",
            id: 1,
            method: "tools/call",
            params: { name, arguments: { id } },
          },
          (call) => calls.push(call),
        ).result.isError,
        false,
      );
    const response = {
      ticket: corpus.ticket.id,
      status: corpus.ticket.status,
      requirement: corpus.ticket.requirement,
      document: corpus.document.id,
      decision: corpus.document.decision,
    };
    assert.equal(gradeFixture("T6", { work, before, response }).passed, false);
    assert.ok(gradeFixture("T6", { work, before, response, calls }).passed);
    assert.ok(
      gradeFixture("T6", {
        work,
        before,
        response: Object.fromEntries(Object.entries(response).reverse()),
        calls,
      }).passed,
    );
    assert.equal(
      dispatch({
        id: 2,
        method: "tools/call",
        params: { name: "write", arguments: { id: "TKT-42" } },
      }).result.isError,
      true,
    );
  }));
test("CLI dry-run has all hashes, zero provider calls and --run fails closed", () => {
  const cli = join(root, "scripts/claude-efficiency-campaign");
  const dry = spawnSync(cli, ["--dry-run"], { encoding: "utf8" });
  assert.equal(dry.status, 0, dry.stderr);
  const report = JSON.parse(dry.stdout);
  assert.equal(report.inference_calls, 0);
  assert.equal(report.auth_calls, 0);
  assert.equal(report.live_ready, false);
  assert.equal(report.quota_verdict, "INCONCLUSIVE");
  assert.equal(Object.keys(report.fixtures).length, 6);
  const live = spawnSync(cli, ["--run"], { encoding: "utf8" });
  assert.equal(live.status, 2);
  assert.match(live.stderr, /No Claude process launched/);
  assert.equal(LIMITS.invocations, 42);
});
