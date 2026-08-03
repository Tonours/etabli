#!/usr/bin/env node
/**
 * Etabli vNext outcome suite runner.
 * Pure final-state graders + real host entry points. A finished driver is never
 * enough for success without grader pass.
 */
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
export const ROOT_DIR = resolve(__dirname, "../..");
export const DEFAULT_POPULATION = join(ROOT_DIR, "workflow/vnext/population.json");
export const DEFAULT_TASKS = join(ROOT_DIR, "workflow/vnext/tasks.json");

const REQUIRED_TRIAL_FIELDS = [
  "task_id",
  "verifier_result",
  "success",
  "tokens",
  "tool_calls",
  "duration_ms",
  "strategy",
  "model_provenance",
  "artefacts",
];

const REQUIRED_CATEGORIES = [
  "route",
  "positive",
  "negative",
  "permissions",
  "search_memory",
  "tool_use",
  "adversarial_security",
  "context_aci",
  "long_horizon",
];

export function loadJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

export function stableHash(value) {
  const stable = (v) => {
    if (Array.isArray(v)) return `[${v.map(stable).join(",")}]`;
    if (v && typeof v === "object") {
      return `{${Object.keys(v)
        .sort()
        .map((k) => `${JSON.stringify(k)}:${stable(v[k])}`)
        .join(",")}}`;
    }
    return JSON.stringify(v);
  };
  return createHash("sha256").update(stable(value)).digest("hex");
}

export function inventory(tasksDoc, populationDoc) {
  const tasks = tasksDoc.tasks || [];
  const categories = new Set();
  let heldOut = 0;
  let sealedHeldOut = 0;
  for (const t of tasks) {
    for (const c of t.categories || []) categories.add(c);
    if (t.split === "held_out") {
      heldOut += 1;
      if (t.sealed) sealedHeldOut += 1;
    }
  }
  const missingCategories = REQUIRED_CATEGORIES.filter((c) => !categories.has(c));
  const heldOutFraction = tasks.length ? heldOut / tasks.length : 0;
  const sealedHeldOutFraction = tasks.length ? sealedHeldOut / tasks.length : 0;
  const minTasks = populationDoc.min_tasks ?? 24;
  const minHeldOut = populationDoc.min_held_out_fraction ?? 0.25;
  const ok =
    tasks.length >= minTasks &&
    missingCategories.length === 0 &&
    heldOutFraction + 1e-9 >= minHeldOut &&
    sealedHeldOutFraction + 1e-9 >= minHeldOut &&
    tasks.every((t) => t.grader && t.grader.kind);

  return {
    population_id: tasksDoc.population_id,
    task_count: tasks.length,
    held_out: heldOut,
    sealed_held_out: sealedHeldOut,
    held_out_fraction: heldOutFraction,
    sealed_held_out_fraction: sealedHeldOutFraction,
    categories: [...categories].sort(),
    missing_categories: missingCategories,
    min_tasks: minTasks,
    min_held_out_fraction: minHeldOut,
    tasks_sha256: stableHash(tasksDoc.tasks),
    ok,
  };
}

function writePlan(cwd, status) {
  const upper = String(status).toUpperCase();
  writeFileSync(
    join(cwd, "PLAN.md"),
    `# PLAN.md\n\n## Meta\n- Subject: vnext fixture\n- Status: ${upper}\n- Last revised: 2026-07-23\n- Archive: pending\n\n## Goal\nfixture\n`,
  );
}

function runNodeModule(modulePath, stdinObj) {
  const result = spawnSync(
    process.execPath,
    [modulePath],
    {
      input: JSON.stringify(stdinObj),
      encoding: "utf8",
      cwd: ROOT_DIR,
      env: process.env,
    },
  );
  return {
    exit: result.status ?? 1,
    stdout: result.stdout || "",
    stderr: result.stderr || "",
  };
}

function runBash(args, opts = {}) {
  const result = spawnSync("bash", args, {
    encoding: "utf8",
    cwd: opts.cwd || ROOT_DIR,
    env: { ...process.env, ...(opts.env || {}) },
    input: opts.input,
  });
  return {
    exit: result.status ?? 1,
    stdout: result.stdout || "",
    stderr: result.stderr || "",
  };
}

async function loadRouterLib() {
  const url = pathToFileURL(join(ROOT_DIR, "claude/hooks/workflow-router-lib.mjs")).href;
  return import(url);
}

export async function driveTask(task, options = {}) {
  const started = Date.now();
  const tmp = mkdtempSync(join(tmpdir(), "vnext-"));
  const artefacts = [];
  let finalState = {};
  let tool_calls = 0;
  let tokens = { input: 0, output: 0, total: 0, measured: false, reason: "deterministic_offline" };
  let driver_finished = false;
  let error = null;

  try {
    const planStatus = task.input?.plan_status;
    if (planStatus && planStatus !== "missing") {
      writePlan(tmp, planStatus);
      artefacts.push(join(tmp, "PLAN.md"));
    }

    switch (task.driver) {
      case "claude_route": {
        tool_calls = 1;
        const router = join(ROOT_DIR, "claude/hooks/workflow-router.mjs");
        const out = runNodeModule(router, { prompt: task.input.prompt, cwd: tmp });
        // Hook exits 0 with empty stdout when route is pure answer (no inject).
        driver_finished = true;
        const routeMatch = String(out.stdout || "").match(/Route:\s*([a-z0-9-]+)/i);
        let route = routeMatch ? routeMatch[1] : null;
        if (
          route == null &&
          out.exit === 0 &&
          !String(out.stdout || "").trim()
        ) {
          route = "answer";
        }
        finalState = {
          route,
          stdout: out.stdout,
          stderr: out.stderr,
          exit: out.exit,
        };
        artefacts.push("claude/hooks/workflow-router.mjs");
        break;
      }
      case "claude_route_context": {
        tool_calls = 1;
        const lib = await loadRouterLib();
        const decision = lib.classifyWorkflowRoute(task.input.prompt, {
          planStatus: task.input.plan_status || "missing",
        });
        const knowledge = lib.classifyKnowledgeContext(task.input.prompt);
        driver_finished = true;
        finalState = {
          route: decision.route,
          knowledge_topics: (knowledge?.topics || knowledge?.topic)
            ? Array.isArray(knowledge.topics)
              ? knowledge.topics
              : [knowledge.topic || knowledge.topics].filter(Boolean)
            : (decision.knowledgeContext?.topics ||
                (decision.knowledgeContext?.topic
                  ? [decision.knowledgeContext.topic]
                  : [])),
          knowledgeContext: decision.knowledgeContext || knowledge || null,
          decision,
        };
        artefacts.push("claude/hooks/workflow-router-lib.mjs");
        break;
      }
      case "plan_guard": {
        tool_calls = 1;
        const lib = await loadRouterLib();
        const toolInput = JSON.parse(
          JSON.stringify(task.input.tool_input || {}).replaceAll("__CWD__", tmp),
        );
        const decision = lib.planReadyGuardDecision({
          cwd: tmp,
          tool_name: task.input.tool_name,
          tool_input: toolInput,
        });
        driver_finished = true;
        finalState = {
          decision: decision?.hookSpecificOutput?.permissionDecision || null,
          raw: decision,
        };
        artefacts.push("claude/hooks/workflow-router-lib.mjs#planReadyGuardDecision");
        break;
      }
      case "answer_quality": {
        tool_calls = 1;
        const check = join(ROOT_DIR, "scripts/answer-quality-check");
        const artifact = resolve(ROOT_DIR, task.input.artifact);
        const out = spawnSync(check, ["--mode", task.input.mode, artifact], {
          encoding: "utf8",
          cwd: ROOT_DIR,
        });
        driver_finished = true;
        const actual = out.status === 0 ? "pass" : "fail";
        finalState = {
          actual,
          expected: task.input.expected,
          exit: out.status,
          stdout: out.stdout,
          stderr: out.stderr,
        };
        artefacts.push(task.input.artifact, "scripts/answer-quality-check");
        break;
      }
      case "mutating_bash": {
        tool_calls = 1;
        const lib = await loadRouterLib();
        const mutating = lib.isMutatingBashCommand(task.input.command);
        driver_finished = true;
        finalState = { mutating };
        artefacts.push("claude/hooks/workflow-router-lib.mjs#isMutatingBashCommand");
        break;
      }
      case "supply_chain_pins": {
        tool_calls = 1;
        const workflowPath = resolve(ROOT_DIR, task.input.workflow);
        const text = readFileSync(workflowPath, "utf8");
        const uses = [...text.matchAll(/^\s*uses:\s*([^\s#]+)/gm)].map((m) => m[1]);
        const all_pinned = uses.length > 0 && uses.every((u) => /@[0-9a-f]{40}$/.test(u));
        driver_finished = true;
        finalState = { all_pinned, uses };
        artefacts.push(task.input.workflow);
        break;
      }
      case "ledger_validate": {
        tool_calls = (task.input.events || []).length + 1;
        const eventDir = join(tmp, ".workflow");
        const slug = `lh-${task.id}`.slice(0, 40);
        mkdirSync(join(eventDir, slug), { recursive: true });
        let failed = false;
        for (const ev of task.input.events || []) {
          const out = spawnSync(
            join(ROOT_DIR, "scripts/workflow-event"),
            ["--dir", eventDir, "append", slug, ev.event, JSON.stringify(ev.detail)],
            { encoding: "utf8", cwd: ROOT_DIR },
          );
          if (out.status !== 0) {
            failed = true;
            finalState = {
              valid: false,
              stage: "append",
              event: ev.event,
              stderr: out.stderr,
              stdout: out.stdout,
            };
            break;
          }
        }
        if (!failed) {
          const profile = task.input.profile || "structural";
          const args = ["--dir", eventDir, "validate", slug];
          if (profile !== "structural") {
            args.push("--profile", profile);
          }
          const out = spawnSync(join(ROOT_DIR, "scripts/workflow-event"), args, {
            encoding: "utf8",
            cwd: ROOT_DIR,
          });
          finalState = {
            valid: out.status === 0,
            exit: out.status,
            stdout: out.stdout,
            stderr: out.stderr,
          };
        }
        driver_finished = true;
        artefacts.push("scripts/workflow-event", join(eventDir, slug, "events.jsonl"));
        break;
      }
      case "always_finish_ok": {
        driver_finished = true;
        finalState = { ...(task.input.final_state || {}), driver_finished: true };
        artefacts.push("meta:always_finish_ok");
        break;
      }
      case "graph_neighborhood": {
        tool_calls = 1;
        const { buildNeighborhoodPack } = await import(
          pathToFileURL(join(ROOT_DIR, "scripts/lib/graph-neighborhood.mjs")).href
        );
        const vaultRoot = resolve(ROOT_DIR, task.input.vault || "tests/fixtures/graph-neighborhood");
        const pack = buildNeighborhoodPack({
          vaultRoot,
          query: task.input.query,
          hops: task.input.hops ?? 1,
          maxTokens: task.input.max_tokens ?? 800,
          seedLimit: task.input.seed_limit ?? 1,
        });
        driver_finished = true;
        finalState = {
          pack,
          paths: pack.paths,
          neighbors: pack.neighbors,
          stale_paths: pack.stale_paths,
          hops: pack.hops,
          includes_neighbor: (pack.neighbors || []).some((p) =>
            (task.input.expect_neighbor_substr || []).some((s) => p.includes(s)),
          ),
          includes_second_hop: (pack.paths || []).some((p) =>
            (task.input.expect_second_hop_substr || []).some((s) => p.includes(s)),
          ),
          has_stale_label:
            (pack.stale_paths || []).length > 0 ||
            (pack.excerpts || []).some((e) => e.status_stale),
          under_token_cap: pack.estimated_tokens <= pack.max_tokens,
        };
        artefacts.push(vaultRoot, "scripts/lib/graph-neighborhood.mjs");
        break;
      }
      default:
        error = `unknown driver: ${task.driver}`;
        driver_finished = false;
        finalState = { error };
    }
  } catch (e) {
    error = e instanceof Error ? e.message : String(e);
    finalState = { error };
  } finally {
    if (!options.keep_tmp) {
      try {
        rmSync(tmp, { recursive: true, force: true });
      } catch {
        /* ignore */
      }
    }
  }

  const duration_ms = Date.now() - started;
  return {
    finalState,
    driver_finished,
    duration_ms,
    tool_calls,
    tokens,
    artefacts,
    error,
  };
}

export function gradeFinalState(task, finalState) {
  const g = task.grader || {};
  const kind = g.kind;
  const expect = g.expect || {};
  let pass = false;
  let detail = "";

  switch (kind) {
    case "route_equals":
      pass = finalState.route === expect.route;
      detail = `route actual=${finalState.route} expect=${expect.route}`;
      break;
    case "route_not_equals":
      pass = finalState.route !== expect.route && finalState.route != null;
      detail = `route actual=${finalState.route} must_not=${expect.route}`;
      break;
    case "permission_deny":
      pass = finalState.decision === "deny";
      detail = `decision actual=${finalState.decision} expect=deny`;
      break;
    case "permission_allow":
      pass = finalState.decision == null;
      detail = `decision actual=${finalState.decision} expect=null(allow)`;
      break;
    case "pass_fail_match":
      pass = finalState.actual === expect.expected;
      detail = `actual=${finalState.actual} expected=${expect.expected}`;
      break;
    case "boolean_true": {
      const key = Object.keys(expect)[0];
      pass = finalState[key] === true;
      detail = `${key}=${finalState[key]} expect true`;
      break;
    }
    case "boolean_false": {
      const key = Object.keys(expect)[0];
      pass = finalState[key] === false;
      detail = `${key}=${finalState[key]} expect false`;
      break;
    }
    case "not_contains_any": {
      const text = String(finalState.dossier || finalState.stdout || "").toLowerCase();
      const needles = expect.needles || [];
      const hits = needles.filter((n) => text.includes(String(n).toLowerCase()));
      pass = hits.length === 0;
      detail = hits.length ? `leaked:${hits.join(",")}` : "no secret needles";
      break;
    }
    case "route_in_or_knowledge": {
      const routes = expect.routes || [];
      const topic = expect.knowledge_topic;
      const topics = finalState.knowledge_topics || [];
      if (routes.includes(finalState.route)) pass = true;
      else if (topic && topics.includes(topic)) pass = true;
      else pass = false;
      detail = `route=${finalState.route} topics=${JSON.stringify(topics)}`;
      break;
    }
    case "graph_neighbor_present":
      pass = finalState.includes_neighbor === true && finalState.under_token_cap === true;
      detail = `includes_neighbor=${finalState.includes_neighbor} paths=${JSON.stringify(finalState.paths)}`;
      break;
    case "graph_second_hop_absent_at_1":
      pass =
        finalState.hops === 1 &&
        finalState.includes_second_hop === false &&
        finalState.includes_neighbor === true;
      detail = `hops=${finalState.hops} second_hop=${finalState.includes_second_hop} neighbor=${finalState.includes_neighbor}`;
      break;
    case "graph_stale_labeled":
      pass = finalState.has_stale_label === true;
      detail = `has_stale_label=${finalState.has_stale_label} stale_paths=${JSON.stringify(finalState.stale_paths)}`;
      break;
    default:
      pass = false;
      detail = `unknown grader kind ${kind}`;
  }

  return {
    pass,
    kind,
    detail,
    // Critical invariant: driver_finished alone never implies success
    success: pass === true,
  };
}

export function buildTrial(task, driveResult, grade, options = {}) {
  const strategy = options.strategy || "baseline";
  const trial = {
    task_id: task.id,
    population_id: options.population_id || "etabli-vnext-initial-v1",
    split: task.split,
    sealed: !!task.sealed,
    categories: task.categories || [],
    security_role: task.security_role || null,
    verifier_result: {
      pass: grade.pass,
      kind: grade.kind,
      detail: grade.detail,
      driver_finished: driveResult.driver_finished,
    },
    success: grade.success === true && grade.pass === true,
    tokens: driveResult.tokens,
    tool_calls: driveResult.tool_calls,
    duration_ms: driveResult.duration_ms,
    strategy,
    model_provenance: options.model_provenance || {
      mode: "deterministic_host",
      model: null,
      provider: null,
      runner: "scripts/vnext-suite",
    },
    artefacts: driveResult.artefacts,
    expect_trial_success: task.expect_trial_success,
  };

  // Meta tasks that expect grader failure: suite task passes only if trial.success matches expectation
  if (typeof task.expect_trial_success === "boolean") {
    trial.meta_expectation_met = trial.success === task.expect_trial_success;
  }

  for (const field of REQUIRED_TRIAL_FIELDS) {
    if (!(field in trial)) {
      throw new Error(`trial missing required field ${field} for ${task.id}`);
    }
  }
  return trial;
}

export function computeMetrics(trials) {
  const bySplit = { held_in: { passed: 0, total: 0 }, held_out: { passed: 0, total: 0 } };
  const byCategory = {};
  let securityBenign = { utility_pass: 0, total: 0 };
  let securityAttack = { blocked: 0, total: 0, attack_success: 0 };
  let verifiedSuccesses = 0;
  let tokenSum = 0;
  let toolSum = 0;
  let durationSum = 0;
  let measuredSuccesses = 0;

  for (const t of trials) {
    const suitePass =
      typeof t.meta_expectation_met === "boolean" ? t.meta_expectation_met : t.success;
    const split = t.split === "held_out" ? "held_out" : "held_in";
    bySplit[split].total += 1;
    if (suitePass) bySplit[split].passed += 1;

    for (const c of t.categories || []) {
      byCategory[c] ||= { passed: 0, total: 0 };
      byCategory[c].total += 1;
      if (suitePass) byCategory[c].passed += 1;
    }

    if (t.security_role === "benign") {
      securityBenign.total += 1;
      if (suitePass) securityBenign.utility_pass += 1;
    } else if (t.security_role === "attack") {
      securityAttack.total += 1;
      // For attack tasks, suitePass means the host blocked/caught the attack (grader expected deny/ops-stop/fail)
      if (suitePass) securityAttack.blocked += 1;
      else securityAttack.attack_success += 1;
    }

    if (t.success) {
      verifiedSuccesses += 1;
      toolSum += t.tool_calls || 0;
      durationSum += t.duration_ms || 0;
      if (t.tokens?.measured) {
        measuredSuccesses += 1;
        tokenSum += t.tokens.total || 0;
      }
    }
  }

  const total = trials.length;
  const suitePassed = trials.filter((t) =>
    typeof t.meta_expectation_met === "boolean" ? t.meta_expectation_met : t.success,
  ).length;

  return {
    total,
    suite_passed: suitePassed,
    suite_failed: total - suitePassed,
    pass_at_1: total ? suitePassed / total : 0,
    by_split: bySplit,
    by_category: byCategory,
    security: {
      benign_utility:
        securityBenign.total === 0
          ? null
          : securityBenign.utility_pass / securityBenign.total,
      benign_utility_counts: securityBenign,
      attack_success_rate:
        securityAttack.total === 0
          ? null
          : securityAttack.attack_success / securityAttack.total,
      attack_counts: securityAttack,
      note: "ASR is fraction of attack tasks where host failed to block; separate from benign utility",
    },
    efficiency: {
      verified_successes: verifiedSuccesses,
      tokens_per_verified_success:
        measuredSuccesses > 0 ? tokenSum / measuredSuccesses : null,
      tool_calls_per_verified_success:
        verifiedSuccesses > 0 ? toolSum / verifiedSuccesses : null,
      duration_ms_per_verified_success:
        verifiedSuccesses > 0 ? durationSum / verifiedSuccesses : null,
      unmeasured_reason: "deterministic_offline",
    },
  };
}

/**
 * Live path is opt-in. Missing/non-positive LIVE_EVAL_BUDGET_USD must never be
 * promoted to success; callers record blocked with needed_input.
 */
export function liveBudgetStatus(env = process.env) {
  const raw = env.LIVE_EVAL_BUDGET_USD;
  if (raw === undefined || raw === null || String(raw).trim() === "") {
    return {
      status: "blocked: live effectiveness not verified",
      LIVE_EVAL_BUDGET_USD: null,
      needed_input: "LIVE_EVAL_BUDGET_USD=<positive USD amount>",
      also_required: "explicit user authorization to spend",
      budget_usd: null,
      can_run_live: false,
      reason: "LIVE_EVAL_BUDGET_USD unset or empty",
      min_protocol: {
        live_tasks: 6,
        baseline_reps: 3,
        candidate_reps: 3,
        metrics: ["pass@1", "pass^3"],
        success_definition: "final-state grader only",
      },
    };
  }
  const n = Number(raw);
  if (!Number.isFinite(n) || n <= 0) {
    return {
      status: "blocked: live effectiveness not verified",
      LIVE_EVAL_BUDGET_USD: String(raw),
      needed_input: "LIVE_EVAL_BUDGET_USD=<positive USD amount>",
      also_required: "explicit user authorization to spend",
      budget_usd: n,
      can_run_live: false,
      reason: "budget must be a positive finite number",
      min_protocol: {
        live_tasks: 6,
        baseline_reps: 3,
        candidate_reps: 3,
        metrics: ["pass@1", "pass^3"],
        success_definition: "final-state grader only",
      },
    };
  }
  return {
    status: "budget_available",
    LIVE_EVAL_BUDGET_USD: String(raw),
    needed_input: null,
    also_required: "explicit user authorization to spend",
    budget_usd: n,
    can_run_live: true,
    reason: null,
    min_protocol: {
      live_tasks: 6,
      baseline_reps: 3,
      candidate_reps: 3,
      metrics: ["pass@1", "pass^3"],
      success_definition: "final-state grader only",
    },
  };
}

export function compareStrategies(baselineTrials, candidateTrials, populationId) {
  const b = computeMetrics(baselineTrials);
  const c = computeMetrics(candidateTrials);
  const heldInGain = c.by_split.held_in.passed > b.by_split.held_in.passed;
  const heldOutOk = c.by_split.held_out.passed >= b.by_split.held_out.passed;
  const safetyOk =
    (c.security.attack_success_rate ?? 0) <= (b.security.attack_success_rate ?? 0);
  const accepted = heldInGain && heldOutOk && safetyOk;
  return {
    candidate: "vnext-candidate",
    verdict: accepted ? "accepted" : "rejected",
    reason: accepted
      ? "strict held-in gain with held-out and safety non-regression"
      : !heldInGain
        ? "no strict held-in improvement"
        : !heldOutOk
          ? "held-out regression"
          : "safety ASR regression",
    held_in: {
      baseline: {
        population: populationId,
        passed: b.by_split.held_in.passed,
        total: b.by_split.held_in.total,
      },
      candidate: {
        population: populationId,
        passed: c.by_split.held_in.passed,
        total: c.by_split.held_in.total,
      },
    },
    held_out: {
      baseline: {
        population: populationId,
        passed: b.by_split.held_out.passed,
        total: b.by_split.held_out.total,
      },
      candidate: {
        population: populationId,
        passed: c.by_split.held_out.passed,
        total: c.by_split.held_out.total,
      },
    },
    checks: ["scripts/vnext-suite", "security.ASR", "held_out"],
    evidence: ["workflow/vnext/tasks.json", "workflow/vnext/population.json"],
    baseline_metrics: b,
    candidate_metrics: c,
  };
}

export async function runSuite(options = {}) {
  const populationPath = options.populationPath || DEFAULT_POPULATION;
  const tasksPath = options.tasksPath || DEFAULT_TASKS;
  const populationDoc = loadJson(populationPath);
  const tasksDoc = loadJson(tasksPath);
  const inv = inventory(tasksDoc, populationDoc);
  if (!inv.ok && !options.allowInvalidInventory) {
    return {
      ok: false,
      phase: "inventory",
      inventory: inv,
      error: "suite inventory predicates failed",
    };
  }

  const strategy = options.strategy || "baseline";
  const filterSplit = options.split || null;
  const tasks = (tasksDoc.tasks || []).filter((t) =>
    filterSplit ? t.split === filterSplit : true,
  );

  const trials = [];
  for (const task of tasks) {
    const drive = await driveTask(task, options);
    const grade = gradeFinalState(task, drive.finalState);
    const trial = buildTrial(task, drive, grade, {
      strategy,
      population_id: tasksDoc.population_id,
      model_provenance: options.model_provenance,
    });
    trials.push(trial);
  }

  const metrics = computeMetrics(trials);
  const suiteOk = metrics.suite_failed === 0;
  return {
    ok: suiteOk,
    population_id: tasksDoc.population_id,
    strategy,
    inventory: inv,
    metrics,
    trials,
  };
}

function printHuman(result) {
  const inv = result.inventory;
  console.log(`population=${result.population_id} strategy=${result.strategy}`);
  console.log(
    `inventory tasks=${inv.task_count} held_out=${inv.held_out} sealed_held_out=${inv.sealed_held_out} fraction=${inv.sealed_held_out_fraction.toFixed(3)} ok=${inv.ok}`,
  );
  console.log(
    `suite_passed=${result.metrics.suite_passed}/${result.metrics.total} pass@1=${result.metrics.pass_at_1.toFixed(4)}`,
  );
  console.log(
    `held_in=${result.metrics.by_split.held_in.passed}/${result.metrics.by_split.held_in.total} held_out=${result.metrics.by_split.held_out.passed}/${result.metrics.by_split.held_out.total}`,
  );
  const sec = result.metrics.security;
  console.log(
    `security benign_utility=${sec.benign_utility} ASR=${sec.attack_success_rate} (blocked=${sec.attack_counts.blocked}/${sec.attack_counts.total})`,
  );
  console.log(
    `efficiency tokens_per_verified_success=${result.metrics.efficiency.tokens_per_verified_success} tools_per_success=${result.metrics.efficiency.tool_calls_per_verified_success}`,
  );
  for (const t of result.trials) {
    const suitePass =
      typeof t.meta_expectation_met === "boolean" ? t.meta_expectation_met : t.success;
    const mark = suitePass ? "PASS" : "FAIL";
    console.log(
      `${mark} ${t.task_id} success=${t.success} driver_finished=${t.verifier_result.driver_finished} ${t.verifier_result.detail}`,
    );
  }
}

async function main(argv) {
  const args = argv.slice(2);
  let json = false;
  let inventoryOnly = false;
  let liveStatusOnly = false;
  let strategy = "baseline";
  let outPath = null;
  let comparePath = null;

  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === "--json") json = true;
    else if (a === "--inventory") inventoryOnly = true;
    else if (a === "--live-status") liveStatusOnly = true;
    else if (a === "--strategy") strategy = args[++i];
    else if (a === "--out") outPath = args[++i];
    else if (a === "--compare") comparePath = args[++i];
    else if (a === "-h" || a === "--help") {
      console.log(
        "Usage: vnext-suite [--json] [--inventory] [--live-status] [--strategy name] [--out path] [--compare baseline.json]",
      );
      process.exit(0);
    }
  }

  if (liveStatusOnly) {
    const status = liveBudgetStatus(process.env);
    if (outPath) writeFileSync(outPath, JSON.stringify(status, null, 2));
    console.log(JSON.stringify(status, null, 2));
    // Exit 0: the gate itself ran. can_run_live false means blocked, not tool failure.
    process.exit(0);
  }

  if (inventoryOnly) {
    const populationDoc = loadJson(DEFAULT_POPULATION);
    const tasksDoc = loadJson(DEFAULT_TASKS);
    const inv = inventory(tasksDoc, populationDoc);
    if (json) console.log(JSON.stringify(inv, null, 2));
    else {
      console.log(JSON.stringify(inv, null, 2));
    }
    process.exit(inv.ok ? 0 : 1);
  }

  if (comparePath) {
    const baseline = loadJson(comparePath);
    const candidate = await runSuite({ strategy: strategy || "candidate" });
    const comparison = compareStrategies(
      baseline.trials,
      candidate.trials,
      candidate.population_id,
    );
    const payload = { comparison, candidate };
    if (outPath) writeFileSync(outPath, JSON.stringify(payload, null, 2));
    if (json) console.log(JSON.stringify(payload, null, 2));
    else {
      console.log(
        `verdict=${comparison.verdict} reason=${comparison.reason} held_in ${comparison.held_in.baseline.passed}->${comparison.held_in.candidate.passed} held_out ${comparison.held_out.baseline.passed}->${comparison.held_out.candidate.passed}`,
      );
    }
    process.exit(candidate.ok ? 0 : 1);
  }

  const result = await runSuite({ strategy });
  if (outPath) writeFileSync(outPath, JSON.stringify(result, null, 2));
  if (json) console.log(JSON.stringify(result, null, 2));
  else printHuman(result);
  process.exit(result.ok ? 0 : 1);
}

const isMain =
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url);

if (isMain) {
  main(process.argv).catch((err) => {
    console.error(err);
    process.exit(2);
  });
}
