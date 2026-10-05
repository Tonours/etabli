import { randomUUID } from "node:crypto";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  hash,
  snapshot,
  checkScope,
  gradeFindings,
} from "./claude-efficiency-campaign.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const resolver = readFileSync(
  join(root, "workflow/runtime/obvault-topic-resolver.mjs"),
  "utf8",
);
const original = readFileSync(
  join(root, "tests/fixtures/claude-efficiency/profile-original.mjs"),
  "utf8",
);
const builder = original.slice(
  original.indexOf("export function buildLeanLaunch("),
);
const prefix = `import { existsSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
const leanProfilePath = (root) => join(root,'settings.json');
const loadScope = () => 'personal';
function renderMcpConfig() {
 const dir=mkdtempSync(join(tmpdir(),'efficiency-oracle-mcp-'));
 const path=join(dir,'mcp.json');writeFileSync(path,'{"mcpServers":{}}',{mode:0o600});
 return { path, skipped: [] };
}
`;
const fixtures = {
  T1: {
    prompt:
      "Read only. Locate the canonical project vault resolver. Return JSON with anchors {function,file,line} for projectVaultRoots and resolveObvaultRoot, and routes {override,forest,other}. State precedence and exact default vault names. Do not edit files.",
    files: { "workflow/runtime/obvault-topic-resolver.mjs": resolver },
    allowed: [],
  },
  T2: {
    prompt:
      "This fixture contains the original buildLeanLaunch function and a synthetic private MCP renderer. Correct its non-strict branch so --mcp-config is passed in both modes. Preserve strict behavior, extra args and cleanup. Modify only profile.mjs.",
    files: { "profile.mjs": prefix + builder, "settings.json": "{}\n" },
    allowed: ["profile.mjs"],
  },
  T3: {
    prompt:
      "Implement normalize(raw) in usage.mjs. Return input_tokens, output_tokens, cache_read_tokens, cache_creation_tokens and processed_total_tokens. Native fields use cache_*_input_tokens. Integers >=0 are valid; missing/null/string/negative -> null per field. Total is null if any field is unknown. Preserve explicit zero. Pure function; modify only usage.mjs.",
    files: { "usage.mjs": "export function normalize(raw) { return raw; }\n" },
    allowed: ["usage.mjs"],
  },
  T4: {
    prompt:
      "Read only. Review these modules for real bugs. Return JSON {findings:[{path,line,reason,repro:{args,actual,expected}}]}. Include a numeric reproduction for each defect: discount(100,0.2) or amount(0), as applicable. Include only actionable defects and no stylistic comments. Do not edit files.",
    files: {
      "price.mjs":
        "export function discount(price, rate) {\n return price - rate;\n}\n",
      "settings.mjs":
        "export function amount(value) {\n return value || 10;\n}\n",
      "correct.mjs": "export function sum(a, b) {\n return a + b;\n}\n",
      "README.md":
        "discount(price, rate) uses a fractional rate (0.2 means 20%). amount(value) defaults to10 only for null/undefined; zero is valid. sum adds two numbers.\n",
    },
    allowed: [],
  },
  T5: {
    prompt:
      "Resume this started correction using PLAN.md and the initial ledger. Complete remaining(events, planned) in resume.mjs so only successfully validated steps are removed, preserving planned order. A failure is pending and a later failure overrides an earlier pass. Do not rewrite PLAN or the ledger. Return a JSON handoff with objective (copy the Goal), done, pending, files, do_not_redo, and next_action:{step,operation}. Use operation validate for the first pending step. Modify only resume.mjs.",
    files: {
      "PLAN.md":
        "# Goal\nResume the visibility correction.\n# State\nparser completed; visibility started; full-check pending.\n# Do not redo\nparser\n",
      "events.jsonl":
        '{"step":"parser","exit":0}\n{"step":"visibility","exit":1}\n',
      "resume.mjs":
        "export function remaining(events, planned) {\n const done = events.map(event => event.step);\n return planned.filter(step => !done.includes(step));\n}\n",
    },
    allowed: ["resume.mjs"],
  },
  T6: {
    prompt:
      "Read only. Use the local read-only corpus MCP tools get_ticket(TKT-42) and get_document(DOC-17). Return JSON {ticket,status,requirement,document,decision}. Do not read hidden corpus files or modify the workspace.",
    files: {
      "README.md":
        "This task has a synthetic local MCP corpus supplied externally by the runner. No Slack/Linear service is contacted.\n",
    },
    allowed: [],
  },
};
const counters = {
  input_tokens: 10,
  output_tokens: 2,
  cache_read_input_tokens: 3,
  cache_creation_input_tokens: 5,
};
const expectedUsage = {
  input_tokens: 10,
  output_tokens: 2,
  cache_read_tokens: 3,
  cache_creation_tokens: 5,
  processed_total_tokens: 20,
};
const tests = {
  T2: `const {buildLeanLaunch}=await import(target); const fs=await import('node:fs');
 for(const strictMcp of [false,true]) {const run=buildLeanLaunch({repoRoot:work,home:work,strictMcp,extraArgs:['--effort','low']});try {
 assert.equal(run.args.includes('--strict-mcp-config'),strictMcp);
 assert.ok(run.args.includes('--mcp-config'));assert.equal(run.args[run.args.indexOf('--mcp-config')+1],run.mcpPath);
 assert.equal(fs.statSync(run.mcpPath).mode&511,384);assert.deepEqual(run.args.slice(-2),['--effort','low']);
 } finally {run.cleanup();} assert.equal(fs.existsSync(run.mcpPath),false);}`,
  T3: `const {normalize}=await import(target);
 assert.deepEqual(normalize(${JSON.stringify(counters)}),${JSON.stringify(expectedUsage)});
 const zero=Object.fromEntries(Object.keys(${JSON.stringify(counters)}).map(key=>[key,0]));assert.deepEqual(Object.values(normalize(zero)),[0,0,0,0,0]);
 for(const value of [undefined,null,'0',-1,NaN,0.1]) {assert.equal(normalize({input_tokens:value}).input_tokens,null);assert.equal(normalize({input_tokens:value}).processed_total_tokens,null);}
 assert.deepEqual(Object.values(normalize(null)),[null,null,null,null,null]);`,
  T5: `const {remaining}=await import(target);
 assert.deepEqual(remaining([{step:'parser',exit:0},{step:'visibility',exit:1}],['parser','visibility','full-check']),['visibility','full-check']);
 assert.deepEqual(remaining([{step:'a',exit:0},{step:'a',exit:1}],['a','b']),['a','b']);
 assert.deepEqual(remaining([{step:'a',exit:1},{step:'a',exit:0}],['b','a']),['b']);
 assert.deepEqual(remaining([{step:'a'}],['a']),['a']);`,
};
export const corpus = Object.freeze({
  ticket: {
    id: "TKT-42",
    status: "in-progress",
    requirement: "preserve zero counters",
  },
  document: { id: "DOC-17", decision: "unknown fields remain null" },
});
export function suite() {
  return Object.fromEntries(
    Object.entries(fixtures).map(([id, fixture]) => [
      id,
      {
        ...fixture,
        prompt_sha256: hash(fixture.prompt),
        files_sha256: hash(fixture.files),
        oracle_sha256: hash({
          implementation: Object.fromEntries(
            [
              "claude-efficiency-fixtures.mjs",
              "claude-efficiency-campaign.mjs",
              "claude-efficiency-mcp.mjs",
            ].map((name) => [
              name,
              hash(
                readFileSync(join(root, "scripts/lib", name)).toString(
                  "base64",
                ),
              ),
            ]),
          ),
          tests: tests[id] ?? null,
          contract: oracleContract(id),
        }),
      },
    ]),
  );
}
function oracleContract(id) {
  return id === "T1"
    ? [
        "projectVaultRoots",
        "resolveObvaultRoot",
        "override-exclusive",
        "brain",
        "obvault",
      ]
    : id === "T4"
      ? [
          {
            path: "price.mjs",
            line: 2,
            repro: { args: [100, 0.2], actual: 99.8, expected: 80 },
          },
          {
            path: "settings.mjs",
            line: 2,
            repro: { args: [0], actual: 10, expected: 0 },
          },
        ]
      : id === "T6"
        ? corpus
        : id === "T5"
          ? {
              objective: "Resume the visibility correction.",
              done: ["parser"],
              pending: ["visibility", "full-check"],
              files: ["resume.mjs"],
              next_action: { step: "visibility", operation: "validate" },
              do_not_redo: ["parser"],
            }
          : null;
}
export function externalTest(id, work) {
  if (id === "T3" || id === "T5") {
    const rows =
      id === "T3"
        ? [
            { input: [counters], expected: expectedUsage },
            {
              input: [
                {
                  input_tokens: 0,
                  output_tokens: 0,
                  cache_read_input_tokens: 0,
                  cache_creation_input_tokens: 0,
                },
              ],
              expected: {
                input_tokens: 0,
                output_tokens: 0,
                cache_read_tokens: 0,
                cache_creation_tokens: 0,
                processed_total_tokens: 0,
              },
            },
            ...Object.entries({
              input_tokens: "input_tokens",
              output_tokens: "output_tokens",
              cache_read_input_tokens: "cache_read_tokens",
              cache_creation_input_tokens: "cache_creation_tokens",
            }).flatMap(([field, key]) =>
              [undefined, null, "0", -1, 0.1].map((value) => {
                const raw = { ...counters };
                if (value === undefined) delete raw[field];
                else raw[field] = value;
                return {
                  input: [raw],
                  expected: {
                    ...expectedUsage,
                    [key]: null,
                    processed_total_tokens: null,
                  },
                };
              }),
            ),
            {
              input: [null],
              expected: {
                input_tokens: null,
                output_tokens: null,
                cache_read_tokens: null,
                cache_creation_tokens: null,
                processed_total_tokens: null,
              },
            },
          ]
        : [
            {
              input: [
                [
                  { step: "parser", exit: 0 },
                  { step: "visibility", exit: 1 },
                ],
                ["parser", "visibility", "full-check"],
              ],
              expected: ["visibility", "full-check"],
            },
            {
              input: [
                [
                  { step: "a", exit: 0 },
                  { step: "a", exit: 1 },
                ],
                ["a", "b"],
              ],
              expected: ["a", "b"],
            },
            {
              input: [
                [
                  { step: "a", exit: 1 },
                  { step: "a", exit: 0 },
                ],
                ["b", "a"],
              ],
              expected: ["b"],
            },
            { input: [[{ step: "a" }], ["a"]], expected: ["a"] },
          ];
    const worker = `import {readFileSync} from 'node:fs';import {pathToFileURL} from 'node:url';const inputs=JSON.parse(readFileSync(0,'utf8'));const mod=await import(pathToFileURL(process.argv[1]).href);const fn=mod[process.argv[2]];if(typeof fn!=='function')process.exit(2);process.stdout.write(JSON.stringify(inputs.map(args=>fn(...args))));`;
    const result = spawnSync(
      process.execPath,
      [
        "--input-type=module",
        "-e",
        worker,
        join(work, id === "T3" ? "usage.mjs" : "resume.mjs"),
        id === "T3" ? "normalize" : "remaining",
      ],
      {
        input: JSON.stringify(rows.map((row) => row.input)),
        encoding: "utf8",
        timeout: 5000,
        env: { PATH: process.env.PATH },
      },
    );
    if (result.status !== 0 || result.error) return false;
    try {
      return (
        hash(JSON.parse(result.stdout)) ===
        hash(rows.map((row) => row.expected))
      );
    } catch {
      return false;
    }
  }
  const file =
    id === "T2" ? "profile.mjs" : id === "T3" ? "usage.mjs" : "resume.mjs";
  const marker = randomUUID();
  const code = `import assert from 'node:assert/strict';import {pathToFileURL} from 'node:url';const work=process.argv[1],target=pathToFileURL(process.argv[2]).href;${tests[id]};process.stdout.write(${JSON.stringify(marker)});`;
  const temp = mkdtempSync(join(tmpdir(), "efficiency-external-test-"));
  try {
    const result = spawnSync(
      process.execPath,
      ["--input-type=module", "-e", code, work, join(work, file)],
      {
        encoding: "utf8",
        timeout: 5000,
        env: { PATH: process.env.PATH, TMPDIR: temp },
      },
    );
    return result.status === 0 && !result.error && result.stdout === marker;
  } finally {
    rmSync(temp, { recursive: true, force: true });
  }
}
export function gradeFixture(id, { work, before, response, calls = [] }) {
  const fixture = fixtures[id];
  if (!fixture) throw new Error("unknown fixture");
  const violations = checkScope(before, snapshot(work), fixture.allowed);
  if (violations.length) return { passed: false, reason: "scope", violations };
  let passed = false;
  if (tests[id]) passed = externalTest(id, work);
  if (id === "T1") {
    const anchors = response?.anchors;
    passed =
      Array.isArray(anchors) &&
      anchors.length === 2 &&
      ["projectVaultRoots", "resolveObvaultRoot"].every((name) =>
        anchors.some(
          (a) =>
            a &&
            typeof a === "object" &&
            a.function === name &&
            a.file === "workflow/runtime/obvault-topic-resolver.mjs" &&
            Number.isInteger(a.line) &&
            resolver
              .split("\n")
              [a.line - 1]?.startsWith(`export function ${name}(`),
        ),
      ) &&
      response?.routes?.override === "exclusive" &&
      response?.routes?.forest === "brain" &&
      response?.routes?.other === "obvault";
  }
  if (id === "T4")
    passed = gradeFindings(response?.findings, oracleContract(id));
  if (id === "T5")
    passed = passed && hash(response) === hash(oracleContract(id));
  if (id === "T6") {
    passed =
      hash(response) ===
        hash({
          ticket: corpus.ticket.id,
          status: corpus.ticket.status,
          requirement: corpus.ticket.requirement,
          document: corpus.document.id,
          decision: corpus.document.decision,
        }) &&
      ["get_ticket", "get_document"].every((tool) =>
        calls.some(
          (call) =>
            call.tool === tool &&
            call.argument === (tool === "get_ticket" ? "TKT-42" : "DOC-17") &&
            call.ok === true,
        ),
      );
  }
  const afterViolations = checkScope(before, snapshot(work), fixture.allowed);
  if (afterViolations.length)
    return {
      passed: false,
      reason: "oracle import mutated scope",
      violations: afterViolations,
    };
  return {
    passed,
    reason: passed ? "oracle passed" : "external oracle rejected",
  };
}
