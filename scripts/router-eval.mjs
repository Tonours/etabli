import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join, resolve } from "node:path";
import { classifyWorkflowRoute as classifyPi } from "../pi/extensions/lib/workflow-router-runtime.ts";

const { classifyWorkflowRoute: classifyClaude } = await import("../workflow/runtime/workflow-router-core.mjs");

const args = process.argv.slice(2);
let datasetPath = "tests/router-evals";
let json = false;
let minAccuracy = null;
let requireAlignment = false;

function usage() {
  console.log(`Usage: router-eval [--dataset path] [--json] [--min-accuracy n] [--require-alignment]

Evaluate workflow-router golden scenarios against Pi and Claude classifiers.`);
}

for (let i = 0; i < args.length; i += 1) {
  const arg = args[i];
  if (arg === "--dataset") {
    datasetPath = args[++i];
    if (!datasetPath) {
      console.error("missing value for --dataset");
      process.exit(2);
    }
  } else if (arg === "--json") {
    json = true;
  } else if (arg === "--min-accuracy") {
    const value = Number(args[++i]);
    if (!Number.isFinite(value) || value < 0 || value > 1) {
      console.error("--min-accuracy must be a number between 0 and 1");
      process.exit(2);
    }
    minAccuracy = value;
  } else if (arg === "--require-alignment") {
    requireAlignment = true;
  } else if (arg === "-h" || arg === "--help") {
    usage();
    process.exit(0);
  } else {
    console.error(`unknown option: ${arg}`);
    usage();
    process.exit(2);
  }
}

function normalizeRoute(route) {
  return route === "verify-workflow" ? "verify" : route;
}

function normalizeDecision(decision) {
  return {
    route: normalizeRoute(decision.route),
    writeAllowed: Boolean(decision.writeAllowed),
    stopCondition: String(decision.stopCondition || "").replace(/Verdict: /g, ""),
    knowledgeTopics: decision.knowledgeContext?.topics ?? [],
  };
}

function loadCases(path) {
  const abs = resolve(path);
  if (!existsSync(abs)) {
    throw new Error(`dataset not found: ${path}`);
  }

  const files = statSync(abs).isDirectory()
    ? readdirSync(abs)
        .filter((file) => file.endsWith(".json"))
        .sort()
        .map((file) => join(abs, file))
    : [abs];

  const cases = [];
  for (const file of files) {
    let parsed;
    try {
      parsed = JSON.parse(readFileSync(file, "utf8"));
    } catch (error) {
      throw new Error(
        `invalid JSON in dataset ${file}: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
    const entries = Array.isArray(parsed) ? parsed : parsed.cases;
    if (!Array.isArray(entries)) {
      throw new Error(`dataset file must contain an array or { cases }: ${file}`);
    }
    for (const entry of entries) {
      cases.push({ ...entry, dataset: file });
    }
  }
  return cases;
}

const cases = loadCases(datasetPath);
const results = cases.map((testCase) => {
  const expectedRoute = testCase.expectedRoute ?? testCase.route;
  const context = testCase.context ?? {};
  const pi = normalizeDecision(classifyPi(testCase.prompt, context));
  const claude = normalizeDecision(classifyClaude(testCase.prompt, context));
  const expectedWriteAllowed = testCase.writeAllowed;
  const expectedKnowledgeTopics = testCase.expectedKnowledgeTopics;
  const piRouteOk = pi.route === expectedRoute;
  const claudeRouteOk = claude.route === expectedRoute;
  const piWriteOk = expectedWriteAllowed === undefined || pi.writeAllowed === expectedWriteAllowed;
  const claudeWriteOk = expectedWriteAllowed === undefined || claude.writeAllowed === expectedWriteAllowed;
  const piKnowledgeOk = expectedKnowledgeTopics === undefined || JSON.stringify(pi.knowledgeTopics) === JSON.stringify(expectedKnowledgeTopics);
  const claudeKnowledgeOk = expectedKnowledgeTopics === undefined || JSON.stringify(claude.knowledgeTopics) === JSON.stringify(expectedKnowledgeTopics);
  const aligned = pi.route === claude.route && pi.writeAllowed === claude.writeAllowed && JSON.stringify(pi.knowledgeTopics) === JSON.stringify(claude.knowledgeTopics);

  return {
    name: testCase.name,
    category: testCase.category ?? "uncategorized",
    prompt: testCase.prompt,
    expectedRoute,
    expectedWriteAllowed,
    expectedKnowledgeTopics,
    pi,
    claude,
    pass: piRouteOk && claudeRouteOk && piWriteOk && claudeWriteOk && piKnowledgeOk && claudeKnowledgeOk,
    aligned,
  };
});

const total = results.length;
const passed = results.filter((result) => result.pass).length;
const aligned = results.filter((result) => result.aligned).length;
const accuracy = total === 0 ? 1 : passed / total;
const alignmentRate = total === 0 ? 1 : aligned / total;
const writeRouteFalsePositives = results.filter(
  (result) =>
    result.expectedWriteAllowed === false &&
    (result.pi.writeAllowed === true || result.claude.writeAllowed === true),
).length;
const opsStopMisses = results.filter(
  (result) =>
    result.expectedRoute === "ops-stop" &&
    (result.pi.route !== "ops-stop" || result.claude.route !== "ops-stop"),
).length;
const researchRouteMisses = results.filter(
  (result) =>
    result.expectedRoute === "research-plan" &&
    (result.pi.route !== "research-plan" || result.claude.route !== "research-plan"),
).length;

const report = {
  dataset: datasetPath,
  total,
  passed,
  failed: total - passed,
  accuracy,
  aligned,
  alignmentRate,
  writeRouteFalsePositives,
  opsStopMisses,
  researchRouteMisses,
  failures: results.filter((result) => !result.pass || !result.aligned),
  results,
};

if (json) {
  console.log(JSON.stringify(report, null, 2));
} else {
  console.log(`dataset=${datasetPath}`);
  console.log(`total=${total}`);
  console.log(`passed=${passed}`);
  console.log(`failed=${total - passed}`);
  console.log(`accuracy=${accuracy}`);
  console.log(`alignment_rate=${alignmentRate}`);
  console.log(`write_route_false_positives=${writeRouteFalsePositives}`);
  console.log(`ops_stop_misses=${opsStopMisses}`);
  console.log(`research_route_misses=${researchRouteMisses}`);
  for (const failure of report.failures) {
    console.log(
      `FAIL ${failure.name}: expected=${failure.expectedRoute} pi=${failure.pi.route}/${failure.pi.writeAllowed} claude=${failure.claude.route}/${failure.claude.writeAllowed}`,
    );
  }
}

if (minAccuracy !== null && accuracy < minAccuracy) {
  console.error(`router eval accuracy ${accuracy} below minimum ${minAccuracy}`);
  process.exit(1);
}

if (requireAlignment && alignmentRate < 1) {
  console.error(`router eval alignment ${alignmentRate} below required 1`);
  process.exit(1);
}
