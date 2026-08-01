#!/usr/bin/env node

import { spawn } from "node:child_process";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(fileURLToPath(new URL("..", import.meta.url)));
const AGENT_FIXTURES_PATH = join(ROOT, "tests/fixtures/multi-model-quality/agent-fixtures.json");
const SCORE_KEY_PATH = join(ROOT, "tests/fixtures/multi-model-quality/score-key.json");
const DEFAULT_PI_CANDIDATES = [
  process.env.PI_BIN,
  "pi",
].filter(Boolean);

// Live parents must match the managed Pi portfolio in pi/agent/settings.json
// (no retired openai-codex/gpt-5.6-* aliases). Sidecar roles stay pinned by
// pi/agents/etabli-*.md (scout/challenger/judge/analyst).
const PORTFOLIO = {
  coordinator: { provider: "openai-codex", model: "gpt-5.5", thinking: "high" },
  baseline: { provider: "openai-codex", model: "gpt-5.5", thinking: "high" },
  // Strong single-model ceiling arm (historical "sol" role); K3 is the portfolio adjudicator pin.
  ceiling: { provider: "kimi-coding", model: "k3", thinking: "xhigh" },
  taskRpc: { provider: "openai-codex", model: "gpt-5.3-codex-spark", thinking: "medium" },
};

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function parseArgs(argv) {
  const modes = new Set(argv);
  if (modes.has("--self-test")) return { mode: "self-test" };
  if (modes.has("--probe-only")) return { mode: "probe" };
  if (modes.has("--quality")) return { mode: "quality" };
  if (modes.has("--panel-debug")) return { mode: "panel-debug" };
  if (modes.has("--task-rpc")) return { mode: "task-rpc" };
  if (modes.has("--conversation")) return { mode: "conversation" };
  if (modes.has("--all")) return { mode: "all" };
  return { mode: "skip" };
}

async function resolvePiBinary() {
  for (const candidate of DEFAULT_PI_CANDIDATES) {
    try {
      await runProcess(candidate, ["--version"], { timeoutMs: 10_000 });
      return candidate;
    } catch {
      // Try the next explicit location.
    }
  }
  throw new Error("pi executable not found; set PI_BIN to its absolute path");
}

async function runProcess(command, args, { timeoutMs = null, cwd = ROOT } = {}) {
  const startedAt = performance.now();
  return await new Promise((resolveRun, rejectRun) => {
    const child = spawn(command, args, {
      cwd,
      env: process.env,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    const timer = typeof timeoutMs === "number" && timeoutMs > 0
      ? setTimeout(() => {
          child.kill("SIGTERM");
          rejectRun(new Error(`${command} timed out after ${timeoutMs}ms`));
        }, timeoutMs)
      : null;
    child.stdout.on("data", (chunk) => {
      stdout += chunk;
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.on("error", (error) => {
      if (timer) clearTimeout(timer);
      rejectRun(error);
    });
    child.on("close", (status) => {
      if (timer) clearTimeout(timer);
      const elapsedMs = Math.round(performance.now() - startedAt);
      if (status !== 0) {
        rejectRun(new Error(`${command} exited ${status}: ${stderr || stdout}`));
        return;
      }
      resolveRun({ stdout, stderr, elapsedMs });
    });
  });
}

function parseJsonLines(raw) {
  return raw
    .split("\n")
    .filter((line) => line.trim().startsWith("{"))
    .map((line) => JSON.parse(line));
}

function messageText(message) {
  return (message?.content ?? [])
    .filter((part) => part.type === "text")
    .map((part) => part.text)
    .join("\n");
}

function extractJsonObject(text) {
  const candidates = text.match(/\{[^{}]*"findings"\s*:\s*\[[^\]]*\][^{}]*\}/gu) ?? [];
  for (const candidate of candidates.reverse()) {
    try {
      const parsed = JSON.parse(candidate);
      if (Array.isArray(parsed.findings)) return parsed;
    } catch {
      // Ignore prose or malformed JSON and continue looking.
    }
  }
  throw new Error(`no findings JSON in output: ${text.slice(0, 400)}`);
}

function toolCalls(events, name) {
  const calls = [];
  for (const event of events) {
    if (event.type !== "message_end" || event.message?.role !== "assistant") continue;
    for (const part of event.message.content ?? []) {
      if (part.type === "toolCall" && part.name === name) calls.push(part);
    }
  }
  return calls;
}

const PANEL_AGENT_ROLES = new Set([
  "etabli-scout",
  "etabli-analyst",
  "etabli-challenger",
  "etabli-judge",
  "etabli-fallback",
]);

function panelAgentCalls(events) {
  return toolCalls(events, "Agent").filter((call) => PANEL_AGENT_ROLES.has(call.arguments?.subagent_type));
}

function validateCouncilTrace(trace) {
  const expected = {
    agreement: [2, 0, 0],
    deterministic_check: [2, 0, 0],
    rebuttal_resolved: [2, 2, 0],
    adjudicated: [2, 2, 1],
  }[trace.stopReason];
  assert(expected, `unsupported council stop reason: ${trace.stopReason}`);
  const actual = [trace.firstPassCalls, trace.resumeCalls, trace.adjudicationCalls];
  assert(JSON.stringify(actual) === JSON.stringify(expected), `invalid ${trace.stopReason} trace: ${actual.join("/")}`);
  return true;
}

function toolResults(events, name) {
  return events.filter((event) => event.type === "tool_execution_end" && event.toolName === name);
}

function routerDecisionEvidence(events) {
  return events
    .filter((event) => event.type === "entry_appended" && event.entry?.customType === "etabli.workflow-router")
    .map((event) => ({
      version: event.entry?.data?.version,
      route: event.entry?.data?.decision?.route,
      reason: event.entry?.data?.decision?.reason,
      multiExecution: event.entry?.data?.decision?.multiExecution,
    }));
}

function finalModelEvidence(events) {
  const messages = events
    .filter((event) => event.type === "message_end" && event.message?.role === "assistant")
    .map((event) => event.message);
  assert(messages.length > 0, "missing assistant message_end event");
  const final = messages.at(-1);
  return {
    provider: final.provider,
    model: final.model,
    text: messages.map(messageText).join("\n"),
    nonCacheTokens: messages.reduce(
      (sum, message) =>
        sum +
        Number(message.usage?.input ?? 0) +
        Number(message.usage?.output ?? 0) +
        Number(message.usage?.cacheWrite ?? 0),
      0,
    ),
  };
}

function resultText(resultEvent) {
  return (resultEvent.result?.content ?? [])
    .filter((part) => part.type === "text")
    .map((part) => part.text)
    .join("\n");
}

function compactTokenCount(text) {
  const match = text.match(/(?:\||\s)([\d.]+)\s*([kKmM]?)\s+tokens?\b/u);
  if (!match) return 0;
  let multiplier = 1;
  if (match[2].toLowerCase() === "k") multiplier = 1_000;
  if (match[2].toLowerCase() === "m") multiplier = 1_000_000;
  return Math.round(Number(match[1]) * multiplier);
}

function sidecarLifetimeTokens(results) {
  const maximumByAgent = new Map();
  for (const result of results) {
    const text = resultText(result);
    const agentId = text.match(/^Agent:\s*(\S+)/mu)?.[1];
    if (!agentId) continue;
    maximumByAgent.set(agentId, Math.max(maximumByAgent.get(agentId) ?? 0, compactTokenCount(text)));
  }
  return [...maximumByAgent.values()].reduce((sum, tokens) => sum + tokens, 0);
}

function scoreFindings(fixture, findings) {
  const unique = [...new Set(findings.filter((finding) => typeof finding === "string"))];
  const expected = new Set(fixture.expected);
  const foundExpected = unique.filter((finding) => expected.has(finding));
  const falsePositives = unique.filter((finding) => !expected.has(finding));
  return {
    findings: unique,
    foundExpected,
    falsePositives,
    recall: foundExpected.length / fixture.expected.length,
  };
}

function qualityPrompt(fixture) {
  return [
    "Read agent-fixtures.json from the current directory and select the fixture whose id is shown below.",
    "Perform an independent, read-only defect classification of that fixture's source.",
    "Return exactly one JSON object shaped as {\"findings\":[\"ISSUE_ID\"]} and no prose.",
    "Use only IDs from that fixture's catalog. Include an ID only when the defect is directly demonstrated by the code.",
    "Do not invent IDs and do not report style or missing-feature suggestions.",
    `FIXTURE_ID: ${fixture.id}`,
  ].join("\n");
}

async function runPi(piBinary, { provider, model, thinking, prompt, prompts, tools = "read,grep,find,ls", cwd = ROOT }) {
  const messages = prompts ?? [prompt];
  assert(messages.length > 0 && messages.every((message) => typeof message === "string"), "runPi requires prompt strings");
  const result = await runProcess(
    piBinary,
    [
      "--provider",
      provider,
      "--model",
      model,
      "--thinking",
      thinking,
      "--mode",
      "json",
      "--no-session",
      "--tools",
      tools,
      ...messages,
    ],
    { cwd, timeoutMs: 900_000 },
  );
  return { ...result, events: parseJsonLines(result.stdout) };
}

async function runStandalone(piBinary, fixture, arm, benchmarkDir) {
  const prompt = qualityPrompt(fixture);
  const run = await runPi(piBinary, {
    provider: arm.provider,
    model: arm.model,
    thinking: arm.thinking,
    prompt,
    cwd: benchmarkDir,
  });
  const evidence = finalModelEvidence(run.events);
  assert(evidence.provider === arm.provider, `unexpected provider ${evidence.provider}; wanted ${arm.provider}`);
  assert(evidence.model === arm.model, `unexpected model ${evidence.model}; wanted ${arm.model}`);
  const parsed = extractJsonObject(evidence.text);
  return {
    ...scoreFindings(fixture, parsed.findings),
    elapsedMs: run.elapsedMs,
    nonCacheTokens: evidence.nonCacheTokens,
    provider: evidence.provider,
    model: evidence.model,
  };
}

async function runPanel(piBinary, fixture, benchmarkDir) {
  const payload = qualityPrompt(fixture);
  const coordinatorPrompt = [
    "Run an explicit multi-model Etabli council quality benchmark. This is a non-trivial independent code review.",
    "In one assistant turn, launch exactly two background Agent calls: etabli-scout and etabli-challenger.",
    "For BOTH calls, pass the exact text between PAYLOAD_START and PAYLOAD_END as the prompt, without any prefix or suffix.",
    "Then retrieve both with get_subagent_result(wait=true). Return exactly PANEL_COMPLETE and do not add your own findings.",
    "PAYLOAD_START",
    payload,
    "PAYLOAD_END",
  ].join("\n");
  const run = await runPi(piBinary, {
    provider: PORTFOLIO.coordinator.provider,
    model: PORTFOLIO.coordinator.model,
    thinking: PORTFOLIO.coordinator.thinking,
    tools: "Agent,get_subagent_result",
    prompt: coordinatorPrompt,
    cwd: benchmarkDir,
  });
  const agentCalls = toolCalls(run.events, "Agent");
  assert(agentCalls.length === 2, `panel launched ${agentCalls.length} agents instead of 2`);
  const roles = agentCalls.map((call) => call.arguments?.subagent_type).sort();
  assert(
    JSON.stringify(roles) === JSON.stringify(["etabli-challenger", "etabli-scout"]),
    `unexpected panel roles: ${roles.join(", ")}`,
  );
  for (const call of agentCalls) {
    assert(
      call.arguments?.prompt === payload,
      `${call.arguments?.subagent_type} did not receive the frozen prompt verbatim: ${JSON.stringify(call.arguments?.prompt)}`,
    );
    assert(call.arguments?.run_in_background !== false, `${call.arguments?.subagent_type} disabled background execution`);
  }
  const spawnResults = toolResults(run.events, "Agent");
  assert(spawnResults.length === 2, `panel produced ${spawnResults.length} spawn results instead of 2`);
  const expectedModels = new Map([
    ["Etabli Scout", "glm-5-turbo"],
    ["Etabli Challenger", "glm-5.2"],
  ]);
  for (const result of spawnResults) {
    assert(result.result?.details?.status === "background", "runtime did not confirm background execution");
    const expectedModel = expectedModels.get(result.result?.details?.displayName);
    assert(expectedModel === result.result?.details?.modelName, "runtime sidecar model provenance mismatch");
  }

  const results = toolResults(run.events, "get_subagent_result");
  assert(results.length === 2, `panel retrieved ${results.length} results instead of 2`);
  const findings = [];
  let sidecarTokens = 0;
  for (const result of results) {
    const text = resultText(result);
    assert(text.includes("Status: completed"), `sidecar did not complete: ${text.slice(0, 200)}`);
    findings.push(...extractJsonObject(text).findings);
    sidecarTokens += compactTokenCount(text);
  }
  const parent = finalModelEvidence(run.events);
  assert(
    parent.provider === PORTFOLIO.coordinator.provider && parent.model === PORTFOLIO.coordinator.model,
    "panel coordinator provenance mismatch",
  );
  return {
    ...scoreFindings(fixture, findings),
    elapsedMs: run.elapsedMs,
    nonCacheTokens: parent.nonCacheTokens + sidecarTokens,
    provider: parent.provider,
    model: parent.model,
    roles,
  };
}

function mean(values) {
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function range(values) {
  return Math.max(...values) - Math.min(...values);
}

function evaluateQuality(fixtures, runs) {
  const failures = [];
  for (const fixture of fixtures) {
    const baseline = runs.filter((run) => run.fixtureId === fixture.id && run.kind === "baseline");
    const panel = runs.filter((run) => run.fixtureId === fixture.id && run.kind === "panel");
    assert(baseline.length === 2 && panel.length === 2, `incomplete repetitions for ${fixture.id}`);
    const maxBaselineFalsePositives = Math.max(...baseline.map((run) => run.falsePositives.length));
    const baselineRecallRange = range(baseline.map((run) => run.recall));
    const baselineTimeMean = mean(baseline.map((run) => run.elapsedMs));
    const baselineTokenMean = mean(baseline.map((run) => run.nonCacheTokens));
    for (const run of panel) {
      if (run.recall < 0.85) failures.push(`${fixture.id}: panel recall ${run.recall.toFixed(2)} < 0.85`);
      if (run.falsePositives.length > maxBaselineFalsePositives) {
        failures.push(`${fixture.id}: panel false positives exceed baseline maximum`);
      }
      if (run.elapsedMs > baselineTimeMean * 4) failures.push(`${fixture.id}: panel latency exceeds 4x baseline`);
      if (run.nonCacheTokens > baselineTokenMean * 4) failures.push(`${fixture.id}: panel tokens exceed 4x baseline`);
    }
    if (range(panel.map((run) => run.recall)) > baselineRecallRange) {
      failures.push(`${fixture.id}: panel recall variance exceeds baseline`);
    }
  }

  const baseline = runs.filter((run) => run.kind === "baseline");
  const panel = runs.filter((run) => run.kind === "panel");
  // Accept historical kind name from prior reports for offline re-eval fixtures.
  const ceiling = runs.filter((run) => run.kind === "ceiling" || run.kind === "sol-ceiling");
  const baselineRecall = mean(baseline.map((run) => run.recall));
  const panelRecall = mean(panel.map((run) => run.recall));
  const baselineFp = mean(baseline.map((run) => run.falsePositives.length));
  const panelFp = mean(panel.map((run) => run.falsePositives.length));
  if (panelRecall < baselineRecall) failures.push("aggregate panel recall is below baseline");
  if (panelFp > baselineFp) failures.push("aggregate panel false positives exceed baseline");
  if (baselineRecall < 0.9 && panelRecall - baselineRecall < 0.1) {
    failures.push("aggregate panel recall gain is below 0.10 while baseline recall is below 0.90");
  }

  const ceilingDominates =
    ceiling.length > 0 &&
    mean(ceiling.map((run) => run.recall)) > panelRecall &&
    mean(ceiling.map((run) => run.falsePositives.length)) < panelFp &&
    mean(ceiling.map((run) => run.elapsedMs)) < mean(panel.map((run) => run.elapsedMs)) &&
    mean(ceiling.map((run) => run.nonCacheTokens)) < mean(panel.map((run) => run.nonCacheTokens));
  return {
    verdict: failures.length === 0 && !ceilingDominates ? "GO" : "ROLLBACK_TO_OPT_IN",
    failures,
    ceilingDominates,
    // Keep legacy key for older consumers of quality reports.
    solDominates: ceilingDominates,
    aggregate: {
      baseline: { recall: baselineRecall, falsePositives: baselineFp },
      panel: { recall: panelRecall, falsePositives: panelFp },
      ceiling: {
        recall: ceiling.length ? mean(ceiling.map((run) => run.recall)) : null,
        falsePositives: ceiling.length ? mean(ceiling.map((run) => run.falsePositives.length)) : null,
      },
      sol: {
        recall: ceiling.length ? mean(ceiling.map((run) => run.recall)) : null,
        falsePositives: ceiling.length ? mean(ceiling.map((run) => run.falsePositives.length)) : null,
      },
    },
  };
}

async function runProbes(piBinary) {
  const modelProbes = [
    ["zai", "glm-5-turbo", "medium", "GLM_TURBO_PROBE_OK"],
    ["xai", "grok-4.5", "high", "GROK_PROBE_OK"],
    ["zai", "glm-5.2", "xhigh", "GLM_PROBE_OK"],
    ["zai", "glm-5.1", "xhigh", "GLM_51_PROBE_OK"],
    ["kimi-coding", "k3", "xhigh", "KIMI_K3_PROBE_OK"],
  ];
  const results = [];
  for (const [provider, model, thinking, marker] of modelProbes) {
    const run = await runPi(piBinary, {
      provider,
      model,
      thinking,
      tools: "read,grep,find,ls",
      prompt: `Return exactly ${marker} and nothing else.`,
    });
    const evidence = finalModelEvidence(run.events);
    assert(evidence.provider === provider && evidence.model === model, `${marker} provenance mismatch`);
    assert(evidence.text.includes(marker), `${marker} response missing`);
    results.push({ provider, model, elapsedMs: run.elapsedMs, nonCacheTokens: evidence.nonCacheTokens });
  }

  const historyNonce = "KIMI_K3_HISTORY_7319";
  const historyRun = await runPi(piBinary, {
    provider: "kimi-coding",
    model: "k3",
    thinking: "xhigh",
    tools: "read,grep,find,ls",
    prompts: [
      `Remember the exact nonce ${historyNonce}. Return exactly STORED.`,
      "Return exactly the nonce from the previous message and nothing else.",
    ],
  });
  const historyMessages = historyRun.events
    .filter((event) => event.type === "message_end" && event.message?.role === "assistant")
    .map((event) => event.message);
  assert(historyMessages.length === 2, `K3 history probe returned ${historyMessages.length} assistant turns`);
  for (const message of historyMessages) {
    assert(message.provider === "kimi-coding" && message.model === "k3", "K3 history provenance mismatch");
    assert(message.content.some((part) => part.type === "thinking"), "K3 history turn omitted thinking evidence");
  }
  assert(messageText(historyMessages[0]).includes("STORED"), "K3 history setup response mismatch");
  assert(messageText(historyMessages[1]).includes(historyNonce), "K3 did not preserve multi-turn history");

  return {
    models: results,
    kimiHistoryTurns: historyMessages.length,
  };
}

const EXPECTED_ROLE_PROVENANCE = new Map([
  ["etabli-scout", { displayName: "Etabli Scout", modelName: "glm-5-turbo" }],
  ["etabli-challenger", { displayName: "Etabli Challenger", modelName: "glm-5.2" }],
]);

function validateAgentCallProvenance(calls, results) {
  assert(results.length === calls.length, `expected ${calls.length} Agent results, received ${results.length}`);
  calls.forEach((call, index) => {
    const role = call.arguments?.subagent_type;
    const details = results[index].result?.details;
    const expected = EXPECTED_ROLE_PROVENANCE.get(role);
    assert(expected, `${role} has no pinned provenance expectation`);
    assert(details?.displayName === expected.displayName, `${role} runtime role provenance mismatch: ${JSON.stringify(results[index])}`);
    assert(details?.modelName === expected.modelName, `${role} runtime model provenance mismatch: ${JSON.stringify(results[index])}`);
  });
}

async function runAgreementProbe(piBinary) {
  const run = await runPi(piBinary, {
    provider: PORTFOLIO.coordinator.provider,
    model: PORTFOLIO.coordinator.model,
    thinking: PORTFOLIO.coordinator.thinking,
    tools: "Agent,get_subagent_result",
    prompt: [
      "Run an explicit multi-model council read-only review capability probe.",
      "In one assistant turn launch exactly two background Agent calls: etabli-scout and etabli-challenger.",
      "Give each the task: Return exactly CLAIM:AGREEMENT_N42 and nothing else.",
      "Retrieve both with get_subagent_result(wait=true). Their claims agree, so stop after deterministic comparison.",
      "Do not resume either participant. Do not call the judge or Kimi. Return exactly AGREEMENT_STOP_OK.",
    ].join("\n"),
  });
  const calls = panelAgentCalls(run.events);
  assert(calls.length === 2, `agreement probe launched ${calls.length} portfolio calls instead of 2: ${JSON.stringify(calls.map((call) => call.arguments))}`);
  assert(calls.every((call) => !call.arguments?.resume), "agreement probe unexpectedly resumed a participant");
  const roles = calls.map((call) => call.arguments?.subagent_type).sort();
  assert(
    JSON.stringify(roles) === JSON.stringify(["etabli-challenger", "etabli-scout"]),
    `agreement probe roles mismatch: ${roles.join(", ")}`,
  );
  const agentResults = toolResults(run.events, "Agent");
  assert(agentResults.every((result) => !result.isError), `agreement Agent call blocked: ${JSON.stringify({ agentResults, router: routerDecisionEvidence(run.events) })}`);
  validateAgentCallProvenance(calls, agentResults);
  const retrieved = toolResults(run.events, "get_subagent_result");
  assert(retrieved.length === 2, `agreement probe retrieved ${retrieved.length} results`);
  assert(retrieved.every((result) => resultText(result).includes("CLAIM:AGREEMENT_N42")), "agreement marker missing");
  assert(finalModelEvidence(run.events).text.includes("AGREEMENT_STOP_OK"), "agreement coordinator marker missing");
  validateCouncilTrace({ stopReason: "agreement", firstPassCalls: 2, resumeCalls: 0, adjudicationCalls: 0 });
  return {
    stopReason: "agreement",
    firstPassCalls: 2,
    resumeCalls: 0,
    adjudicationCalls: 0,
    elapsedMs: run.elapsedMs,
    sidecarTokens: sidecarLifetimeTokens(retrieved),
    roles,
  };
}

async function runRebuttalProbe(piBinary) {
  const run = await runPi(piBinary, {
    provider: PORTFOLIO.coordinator.provider,
    model: PORTFOLIO.coordinator.model,
    thinking: PORTFOLIO.coordinator.thinking,
    tools: "Agent,get_subagent_result",
    prompt: [
      "Run an explicit multi-model council read-only review conversation probe.",
      "First, in one assistant turn launch exactly two background Agent calls.",
      "Call etabli-scout with: First turn. Remember nonce SCOUT_N719. Return exactly FIRST:SCOUT_N719|CLAIM:L1.",
      "Call etabli-challenger with: First turn. Remember nonce CHALLENGER_N719. Return exactly FIRST:CHALLENGER_N719|CLAIM:G1.",
      "Retrieve both with get_subagent_result(wait=true). Treat L1 and G1 as unresolved material claims.",
      "Then resume each exact original agent id once, in one assistant turn, using the same subagent_type.",
      "For Scout use only: Second turn. Without being told your prior nonce again, rebut anonymized opposing claim C-OTHER and return SECOND:<remembered nonce>|REBUT:C-OTHER.",
      "For Challenger use only: Second turn. Without being told your prior nonce again, rebut anonymized opposing claim C-OTHER and return SECOND:<remembered nonce>|REBUT:C-OTHER.",
      "Retrieve both resumed agents with get_subagent_result(wait=true). Stop after this one rebuttal round.",
      "Do not call the judge or Kimi. Do not launch another agent. Return exactly REBUTTAL_STOP_OK.",
    ].join("\n"),
  });
  const calls = panelAgentCalls(run.events);
  const initialCalls = calls.filter((call) => !call.arguments?.resume);
  const resumedCalls = calls.filter((call) => typeof call.arguments?.resume === "string");
  assert(initialCalls.length === 2, `rebuttal probe launched ${initialCalls.length} first passes`);
  assert(resumedCalls.length === 2, `rebuttal probe launched ${resumedCalls.length} resumes`);
  assert(calls.every((call) => !["etabli-judge", "etabli-fallback"].includes(call.arguments?.subagent_type)), "rebuttal probe invoked judge or fallback");

  const agentResults = toolResults(run.events, "Agent");
  validateAgentCallProvenance(calls, agentResults);
  const initialIds = new Map();
  initialCalls.forEach((call, index) => initialIds.set(call.arguments?.subagent_type, agentResults[index].result?.details?.agentId));
  resumedCalls.forEach((call, index) => {
    const role = call.arguments?.subagent_type;
    assert(call.arguments?.resume === initialIds.get(role), `${role} did not resume its original agent id`);
    assert(agentResults[initialCalls.length + index].result?.details?.agentId === initialIds.get(role), `${role} result changed agent id`);
  });

  const retrieved = toolResults(run.events, "get_subagent_result");
  assert(retrieved.length === 4, `rebuttal probe retrieved ${retrieved.length} results`);
  const combined = retrieved.map(resultText).join("\n");
  for (const marker of ["FIRST:SCOUT_N719", "FIRST:CHALLENGER_N719", "SECOND:SCOUT_N719", "SECOND:CHALLENGER_N719", "REBUT:C-OTHER"]) {
    assert(combined.includes(marker), `rebuttal marker missing: ${marker}`);
  }
  const sidecarTokens = sidecarLifetimeTokens(retrieved);
  assert(sidecarTokens <= 30_000, `rebuttal sidecars used ${sidecarTokens} reported tokens, cap is 30000`);
  assert(finalModelEvidence(run.events).text.includes("REBUTTAL_STOP_OK"), "rebuttal coordinator marker missing");
  validateCouncilTrace({ stopReason: "rebuttal_resolved", firstPassCalls: 2, resumeCalls: 2, adjudicationCalls: 0 });
  return {
    stopReason: "rebuttal_resolved",
    firstPassCalls: 2,
    resumeCalls: 2,
    adjudicationCalls: 0,
    elapsedMs: run.elapsedMs,
    sidecarTokens,
    roles: [...initialIds.keys()].sort(),
    agentIds: Object.fromEntries(initialIds),
  };
}

async function runConversation(piBinary) {
  return {
    agreement: await runAgreementProbe(piBinary),
    rebuttal: await runRebuttalProbe(piBinary),
  };
}

async function runTaskRpc(piBinary) {
  const run = await runPi(piBinary, {
    provider: PORTFOLIO.taskRpc.provider,
    model: PORTFOLIO.taskRpc.model,
    thinking: PORTFOLIO.taskRpc.thinking,
    tools: "TaskCreate,TaskExecute,TaskOutput,TaskGet",
    prompt: [
      "Run a read-only Pi task tracking/RPC probe.",
      "First call TaskCreate exactly once with subject 'RPC probe', description 'Return exactly CHILD_RPC_OK and do not use tools.', and agentType 'general-purpose'.",
      "Then call TaskExecute for the returned task ID with max_turns 1 and no model override.",
      "Then call TaskOutput for that task with block true and timeout 60000. After TaskOutput returns, you MUST call TaskGet for the same task even if TaskOutput already contains CHILD_RPC_OK; never finish before TaskGet.",
      "Do not call Agent. Return exactly TASK_RPC_OK only if the tracked output contains CHILD_RPC_OK.",
    ].join("\n"),
  });
  assert(toolCalls(run.events, "Agent").length === 0, "TaskExecute probe used an untracked direct Agent call");
  assert(toolCalls(run.events, "TaskCreate").length === 1, "TaskExecute probe did not create exactly one task");
  assert(toolCalls(run.events, "TaskExecute").length === 1, "TaskExecute probe did not execute exactly one task");
  const executeResults = toolResults(run.events, "TaskExecute");
  assert(executeResults.length === 1, "TaskExecute probe has no execution result");
  const executionText = resultText(executeResults[0]);
  assert(executionText.includes("Launched 1 agent"), `TaskExecute RPC spawn was not confirmed: ${executionText}`);
  const outputResults = toolResults(run.events, "TaskOutput");
  assert(outputResults.length === 1, "TaskExecute probe has no tracked TaskOutput result");
  const outputText = resultText(outputResults[0]);
  assert(outputText.includes("[completed]"), `TaskOutput did not confirm completion: ${outputText}`);
  const getResults = toolResults(run.events, "TaskGet");
  assert(getResults.length === 1, "TaskExecute probe has no tracked TaskGet result");
  const getText = resultText(getResults[0]);
  assert(getText.includes("CHILD_RPC_OK"), `TaskGet metadata is missing child result: ${getText}`);
  const evidence = finalModelEvidence(run.events);
  assert(evidence.text.includes("TASK_RPC_OK"), "TaskExecute coordinator marker missing");
  return {
    provider: evidence.provider,
    model: evidence.model,
    elapsedMs: run.elapsedMs,
    nonCacheTokens: evidence.nonCacheTokens,
    spawnConfirmed: true,
    completionConfirmed: true,
    resultConfirmed: true,
    stopConfirmed: false,
  };
}

async function runQuality(piBinary, fixtures, agentFixtures) {
  const benchmarkDir = await mkdtemp(join(tmpdir(), "etabli-multi-model-blind-"));
  const agentPayloadPath = join(benchmarkDir, "agent-fixtures.json");
  await writeFile(agentPayloadPath, `${JSON.stringify(agentFixtures, null, 2)}\n`);
  const visiblePayload = JSON.parse(await readFile(agentPayloadPath, "utf8"));
  assert(
    visiblePayload.fixtures.every((fixture) => !("expected" in fixture)),
    "agent-visible benchmark payload leaked the scoring key",
  );
  const runs = [];
  for (const fixture of fixtures) {
    for (let repetition = 1; repetition <= 2; repetition += 1) {
      runs.push({
        fixtureId: fixture.id,
        kind: "baseline",
        repetition,
        ...(await runStandalone(piBinary, fixture, PORTFOLIO.baseline, benchmarkDir)),
      });
    }
    for (let repetition = 1; repetition <= 2; repetition += 1) {
      runs.push({ fixtureId: fixture.id, kind: "panel", repetition, ...(await runPanel(piBinary, fixture, benchmarkDir)) });
    }
    runs.push({
      fixtureId: fixture.id,
      kind: "ceiling",
      repetition: 1,
      ...(await runStandalone(piBinary, fixture, PORTFOLIO.ceiling, benchmarkDir)),
    });
  }
  return { benchmarkDir, runs, evaluation: evaluateQuality(fixtures, runs) };
}

function selfTest() {
  const fixture = { id: "test", expected: ["A", "B"], catalog: ["A", "B", "C"] };
  const scored = scoreFindings(fixture, ["A", "A", "C"]);
  assert(scored.recall === 0.5, "recall calculation failed");
  assert(JSON.stringify(scored.falsePositives) === JSON.stringify(["C"]), "false-positive calculation failed");
  assert(compactTokenCount("| 1.6k tokens |") === 1_600, "compact token parser failed");
  assert(extractJsonObject('text {"findings":["A"]}').findings[0] === "A", "JSON extraction failed");
  for (const trace of [
    { stopReason: "agreement", firstPassCalls: 2, resumeCalls: 0, adjudicationCalls: 0 },
    { stopReason: "deterministic_check", firstPassCalls: 2, resumeCalls: 0, adjudicationCalls: 0 },
    { stopReason: "rebuttal_resolved", firstPassCalls: 2, resumeCalls: 2, adjudicationCalls: 0 },
    { stopReason: "adjudicated", firstPassCalls: 2, resumeCalls: 2, adjudicationCalls: 1 },
  ]) {
    assert(validateCouncilTrace(trace), `valid ${trace.stopReason} trace rejected`);
  }
  let rejectedInvalidTrace = false;
  try {
    validateCouncilTrace({ stopReason: "agreement", firstPassCalls: 2, resumeCalls: 2, adjudicationCalls: 0 });
  } catch {
    rejectedInvalidTrace = true;
  }
  assert(rejectedInvalidTrace, "invalid agreement trace was accepted");
  process.stdout.write("multi-model quality scorer self-test: ok\n");
}

async function main() {
  const { mode } = parseArgs(process.argv.slice(2));
  if (mode === "self-test") {
    selfTest();
    return;
  }
  if (mode === "skip" || process.env.RUN_REAL_MULTI_MODEL !== "1") {
    process.stdout.write("multi-model real smoke: SKIP (set RUN_REAL_MULTI_MODEL=1 and choose --probe-only, --quality, --conversation, --task-rpc, --panel-debug, or --all)\n");
    return;
  }

  const piBinary = await resolvePiBinary();
  const agentFixtures = JSON.parse(await readFile(AGENT_FIXTURES_PATH, "utf8"));
  const scoreKey = JSON.parse(await readFile(SCORE_KEY_PATH, "utf8"));
  assert(agentFixtures.fixtures.length === 3, "agent fixture set must contain exactly three fixtures");
  assert(scoreKey.fixtures.length === 3, "quality score key must contain exactly three fixtures");
  const scoreById = new Map(scoreKey.fixtures.map((fixture) => [fixture.id, fixture.expected]));
  const fixtures = agentFixtures.fixtures.map((fixture) => {
    const expected = scoreById.get(fixture.id);
    assert(Array.isArray(expected), `missing score key for ${fixture.id}`);
    return { ...fixture, expected };
  });
  assert(fixtures.every((fixture) => fixture.expected.length === 3), "each quality fixture must have exactly three expected IDs");
  const before = await runProcess("git", ["status", "--porcelain=v1"], { timeoutMs: 10_000 });
  const artifactDir = await mkdtemp(join(tmpdir(), "etabli-multi-model-"));
  const report = {
    version: 1,
    startedAt: new Date().toISOString(),
    piBinary,
    agentFixtures: AGENT_FIXTURES_PATH,
    scoreKey: SCORE_KEY_PATH,
    probes: null,
    conversation: null,
    taskRpc: null,
    quality: null,
  };
  if (mode === "panel-debug") {
    const benchmarkDir = await mkdtemp(join(tmpdir(), "etabli-multi-model-blind-"));
    await writeFile(join(benchmarkDir, "agent-fixtures.json"), `${JSON.stringify(agentFixtures, null, 2)}\n`);
    report.quality = { debug: await runPanel(piBinary, fixtures[0], benchmarkDir) };
  }
  if (mode === "probe" || mode === "all") report.probes = await runProbes(piBinary);
  if (mode === "conversation" || mode === "all") report.conversation = await runConversation(piBinary);
  if (mode === "task-rpc" || mode === "all") report.taskRpc = await runTaskRpc(piBinary);
  if (mode === "quality" || mode === "all") report.quality = await runQuality(piBinary, fixtures, agentFixtures);
  report.completedAt = new Date().toISOString();
  const after = await runProcess("git", ["status", "--porcelain=v1"], { timeoutMs: 10_000 });
  assert(after.stdout === before.stdout, "real probes changed the repository worktree");
  const reportPath = join(artifactDir, "report.json");
  await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`);
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  process.stdout.write(`multi-model evidence: ${reportPath}\n`);
  if (report.quality?.evaluation && report.quality.evaluation.verdict !== "GO") process.exitCode = 1;
}

main().catch((error) => {
  process.stderr.write(`multi-model real smoke: FAIL: ${error.message}\n`);
  process.exitCode = 1;
});
