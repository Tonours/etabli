#!/usr/bin/env node
/**
 * Trigger-eval runner: one minimal probe call per (task, run) against a
 * PINNED model, using the NATIVE Pi listing formatter over a materialized
 * skills dir. Part of the frozen evaluator bundle (with the corpus and the
 * reduction script) — the manifest pins this file's bytes.
 *
 * Usage: skill-trigger-runner --corpus <json> --skills-dir <dir>
 *        --out <dir> --runs <n> [--model <id>] [--api-key-env <VAR>]
 *        [--api-base <url>] [--variant <name>]
 *
 * Defaults: model qwen/qwen3-8b (PINNED — changing it changes the evaluator),
 * temperature 0, max_tokens 20, 60s timeout, 1 retry on transport/5xx/429.
 * Transport failure after retry is LOUD (nonzero exit, no silent false).
 * Writes run1.json..runN.json: [{task_id, expected, response_raw,
 * response_norm, passed}] plus _meta.json {model, temperature, listing_sha256}.
 */
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { basename, join } from "node:path";
import { normalizeResponse, decideResponse } from "./skill-trigger-normalize.mjs";
import { loadPiSkillsModule } from "./pi-loader.mjs";

const PINNED_MODEL = "qwen/qwen3-8b";

const args = process.argv.slice(2);
function flag(name, def = null) {
  const i = args.indexOf(name);
  if (i < 0) return def;
  if (i + 1 >= args.length) {
    console.error(`skill-trigger-runner: ${name} needs a value`);
    process.exit(2);
  }
  return args[i + 1];
}
const corpusPath = flag("--corpus");
const skillsDir = flag("--skills-dir");
const outDir = flag("--out");
const runs = Number(flag("--runs", "3"));
const model = flag("--model", PINNED_MODEL);
const apiKeyEnv = flag("--api-key-env", "OPENROUTER_API_KEY");
const apiBase = flag("--api-base", "https://openrouter.ai/api/v1");
const variant = flag("--variant", "unmarked");
if (!corpusPath || !skillsDir || !outDir || !Number.isInteger(runs) || runs < 1) {
  console.error("usage: skill-trigger-runner --corpus <json> --skills-dir <dir> --out <dir> --runs <n> [--model <id>] [--api-key-env <VAR>] [--api-base <url>] [--variant <name>]");
  process.exit(2);
}
const apiKey = process.env[apiKeyEnv];
if (!apiKey) {
  console.error(`skill-trigger-runner: missing $${apiKeyEnv} (provider calls need credentials; CI re-verifies committed artifacts instead)`);
  process.exit(2);
}
const corpus = JSON.parse(readFileSync(corpusPath, "utf8"));
if (!Array.isArray(corpus.tasks) || corpus.tasks.length === 0) {
  console.error("skill-trigger-runner: corpus has no tasks");
  process.exit(2);
}

// Native Pi loader + formatter (same rendering the model sees in service).
const { loadSkillsFromDir, formatSkillsForPrompt } = await loadPiSkillsModule();
const { skills } = loadSkillsFromDir({ dir: skillsDir });
const listing = formatSkillsForPrompt(skills);
const listingSha = createHash("sha256").update(listing).digest("hex");

const SYSTEM = "You are a skill router. Given the skill listing and one user request, reply with EXACTLY ONE skill name from the listing, or NONE if no skill applies. No other text.";

async function probe(request) {
  const body = JSON.stringify({
    model,
    temperature: 0,
    max_tokens: 20,
    messages: [
      { role: "system", content: SYSTEM },
      { role: "user", content: `${listing}\n\nRequest: ${request}\nSkill:` },
    ],
  });
  let lastError = null;
  for (let attempt = 0; attempt < 2; attempt += 1) {
    if (attempt > 0) await new Promise((r) => setTimeout(r, 2000));
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 60000);
    try {
      const res = await fetch(`${apiBase}/chat/completions`, {
        method: "POST",
        headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
        body,
        signal: ctrl.signal,
      });
      clearTimeout(timer);
      if (res.status === 429 || res.status >= 500) {
        lastError = new Error(`provider http ${res.status}`);
        continue;
      }
      if (!res.ok) throw new Error(`provider http ${res.status}: ${(await res.text()).slice(0, 200)}`);
      const data = await res.json();
      const content = data?.choices?.[0]?.message?.content;
      if (typeof content !== "string") throw new Error("provider returned no message content");
      return content;
    } catch (error) {
      clearTimeout(timer);
      lastError = error;
      if (error?.name === "AbortError") continue;
      if (attempt === 0 && /fetch failed|network|socket|timeout/i.test(String(error?.message || error))) continue;
      throw error;
    }
  }
  throw lastError;
}

mkdirSync(outDir, { recursive: true });
const runFiles = [];
for (let run = 1; run <= runs; run += 1) {
  const records = [];
  for (const task of corpus.tasks) {
    const raw = await probe(task.request);
    const stored = raw.slice(0, 200);
    const norm = normalizeResponse(stored);
    const passed = decideResponse(stored, task.expected);
    records.push({ task_id: task.id, expected: task.expected, response_raw: stored, response_norm: norm, passed });
    process.stderr.write(`run ${run}/${runs} task ${task.id}: ${norm} ${passed ? "PASS" : "FAIL"}\n`);
  }
  const file = join(outDir, `run${run}.json`);
  writeFileSync(file, `${JSON.stringify({ variant, run, model, temperature: 0, records }, null, 2)}\n`);
  runFiles.push(basename(file));
}
writeFileSync(join(outDir, "_meta.json"), `${JSON.stringify({ variant, model, temperature: 0, runs, listing_sha256: listingSha, skills_loaded: skills.length, corpus_id: corpus.corpus_id }, null, 2)}\n`);
console.log(`skill-trigger-runner: wrote ${runFiles.join(", ")} + _meta.json to ${outDir}`);
