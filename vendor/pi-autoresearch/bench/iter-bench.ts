/**
 * Benchmark: autoresearch harness iteration overhead (metric: iter_overhead_ms).
 *
 * One "iteration" is the in-process CPU work the pi-autoresearch extension
 * performs around each experiment cycle:
 *   1. reconstructJsonlState — full .auto/log.jsonl re-parse (session start,
 *      compaction, dashboard export)
 *   2. computeConfidence — MAD-based noise floor (called by log_experiment)
 *   3. renderDashboardLines — the status widget table render
 *
 * Correctness gates (fail the bench if violated):
 *   - golden-dashboard: renderDashboardLines output on a fixed synthetic state
 *     must byte-match bench/golden.json (generated from pre-optimization code)
 *   - golden-confidence: computeConfidence on the same state must match
 *   - mad-crosscheck: computeConfidence vs a sort-based reference on random
 *     states (guards the O(n) quickselect MAD against regressions)
 *
 * Output (stdout): "METRIC name=value" lines. Primary: iter_overhead_ms.
 */

import { performance } from "node:perf_hooks";
import { readFileSync, writeFileSync } from "node:fs";
import * as path from "node:path";
import * as url from "node:url";

const here = path.dirname(url.fileURLToPath(import.meta.url));
const ext = (f: string) => path.join(here, "..", "extensions", "pi-autoresearch", f);

const { computeConfidence, renderDashboardLines } = await import(ext("index.ts"));
const { reconstructJsonlState } = await import(ext("jsonl.ts"));

// ---------------------------------------------------------------------------
// Deterministic synthetic log content (100 runs, mirroring a real session)
// ---------------------------------------------------------------------------

const RUNS = Number(process.env.BENCH_RUNS ?? 100);

/** xorshift-ish deterministic PRNG (no Math.random — golden must be stable) */
function makeRng(seed: number) {
  let s = seed >>> 0;
  return () => {
    s ^= s << 13; s >>>= 0;
    s ^= s >> 17;
    s ^= s << 5; s >>>= 0;
    return s / 0xffffffff;
  };
}

const HYPOTHESES = [
  "quickselect median for MAD — swap two sorts for one O(n) selection",
  "cache widget column widths across repaints (widths only depend on last rows)",
  "incremental jsonl tail parse — re-parse only the appended lines",
  "single-pass status counters instead of 4 filter passes over results",
  "memoize visibleWidth of theme-wrapped parts (fg(color,text) compositions)",
  "avoid deep-cloning results per log_experiment when unchanged",
  "fast path for pure-ASCII rows in truncateToWidth call sites",
  "skip re-render when state unchanged → still needs one repaint per frame",
  "precompute padEnd of commit/status cells per unique value",
  "flow-wrap secondary metrics with incremental width tracking (no re-measure)",
];

function buildLogContent(runs: number): string {
  const rng = makeRng(0x5eed);
  const lines: string[] = [
    JSON.stringify({
      type: "config",
      name: "Optimizing liquid for fastest execution and parsing 🔬",
      metricName: "render_us",
      metricUnit: "µs",
      bestDirection: "lower",
    }),
  ];
  let metric = 15200;
  const statuses = ["keep", "keep", "discard", "keep", "crash", "keep", "discard", "keep"];
  for (let i = 1; i <= runs; i++) {
    metric += Math.round((rng() - 0.45) * 500);
    metric = Math.max(800, metric);
    const status = statuses[i % statuses.length];
    const tail = i % 4 === 0 ? " → kept; secondary parse_us stable ±2%" : i % 3 === 0 ? " µs regressions on café-émoji rows" : " — measured via bench harness ✓";
    lines.push(JSON.stringify({
      run: i,
      commit: ((0xabc000 + i * 7919) & 0xffffff).toString(16).padStart(6, "0").slice(0, 7),
      metric,
      metrics: {
        parse_us: 3000 + Math.round(rng() * 1500),
        lex_kb: 42 + Math.round(rng() * 20),
        ast_nodes: 812 + Math.round(rng() * 400),
        gc_ms: Math.round(rng() * 90) / 10,
      },
      status,
      description: `Experiment #${i}: ${HYPOTHESES[i % HYPOTHESES.length]}${tail}`,
      timestamp: 1750000000000 + i * 60000,
      segment: 0,
      confidence: i < 3 ? null : Math.round((0.5 + rng() * 2.5) * 100) / 100,
      asi: {
        hypothesis: HYPOTHESES[i % HYPOTHESES.length],
        bottleneck: i % 3 === 0 ? "render: visibleWidth per cell × repaints" : "confidence: sort-based MAD",
        note: "secondary metrics stable across runs; noise floor dominated by JIT warmup; next: re-run variant with higher iters",
        score: i % 5,
      },
    }));
  }
  return lines.join("\n") + "\n";
}

// ---------------------------------------------------------------------------
// Theme stub — realistic ANSI codes so width computation follows the real path
// ---------------------------------------------------------------------------

const FGCOLORS: Record<string, string> = {
  dim: "2", muted: "2", text: "39", success: "32", warning: "33",
  error: "31", accent: "36", borderMuted: "90", toolTitle: "35",
};

function makeTheme() {
  return {
    fg(color: string, text: string): string {
      const code = FGCOLORS[color] ?? "39";
      return `\x1b[${code}m${text}\x1b[39m`;
    },
    bold(text: string): string {
      return `\x1b[1m${text}\x1b[22m`;
    },
  };
}

const HINTS = [
  "alt+u run_experiment · alt+g log_experiment",
  "alt+i ideas · alt+e export dashboard",
  "alt+o checks · /autoresearch off",
];

// ---------------------------------------------------------------------------
// One iteration = the per-log_experiment in-process work
// ---------------------------------------------------------------------------

function buildState(content: string) {
  const rec = reconstructJsonlState(content);
  return {
    results: rec.results,
    bestMetric: rec.results.length > 0 ? rec.results[0].metric : null,
    bestDirection: rec.bestDirection,
    metricName: rec.metricName,
    metricUnit: rec.metricUnit,
    secondaryMetrics: rec.secondaryMetrics,
    name: rec.name,
    currentSegment: rec.currentSegment,
    maxExperiments: 25,
    confidence: null as number | null,
  };
}

/**
 * One iteration = one experiment cycle of in-process harness work:
 *   - 1× full log.jsonl re-parse (session restore / compaction / export)
 *   - 1× computeConfidence (log_experiment)
 *   - RENDER_FRAMES× renderDashboardLines (the widget re-renders on every TUI
 *     repaint while an experiment runs — streaming output repaints it
 *     continuously, so each cycle pays many repaints of the same state)
 */
const RENDER_FRAMES = Number(process.env.BENCH_FRAMES ?? 30);

function oneIteration(content: string, theme: ReturnType<typeof makeTheme>) {
  const st = buildState(content);
  st.confidence = computeConfidence(st.results, st.currentSegment, st.bestDirection);
  let out: string[] = [];
  for (let f = 0; f < RENDER_FRAMES; f++) {
    out = renderDashboardLines(st, 120, theme, 6, HINTS);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Timing helpers
// ---------------------------------------------------------------------------

function median(xs: number[]): number {
  const s = [...xs].sort((a, b) => a - b);
  const mid = s.length >> 1;
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

function benchN(fn: () => void, iters: number, warmup = 5): number {
  for (let i = 0; i < warmup; i++) fn();
  const times: number[] = [];
  for (let i = 0; i < iters; i++) {
    const t0 = performance.now();
    fn();
    times.push(performance.now() - t0);
  }
  return median(times);
}

// ---------------------------------------------------------------------------
// Correctness gates
// ---------------------------------------------------------------------------

/** Sort-based reference implementation of the MAD confidence score */
function referenceConfidence(
  results: { metric: number; status: string; segment: number }[],
  segment: number,
  direction: "lower" | "higher"
): number | null {
  const cur = results.filter((r) => r.segment === segment && r.metric > 0);
  if (cur.length < 3) return null;
  const sortedMed = (v: number[]) => {
    const s = [...v].sort((a, b) => a - b);
    const mid = s.length >> 1;
    return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
  };
  const values = cur.map((r) => r.metric);
  const med = sortedMed(values);
  const mad = sortedMed(values.map((v) => Math.abs(v - med)));
  if (mad === 0) return null;
  // NOTE: real implementation takes the baseline from the first result of the
  // segment (unfiltered), NOT from the metric>0-filtered list.
  const inSegment = results.filter((r) => r.segment === segment);
  const baseline = inSegment.length > 0 ? inSegment[0].metric : null;
  if (baseline === null) return null;
  let bestKept: number | null = null;
  for (const r of cur) {
    if (r.status === "keep" && r.metric > 0) {
      if (bestKept === null || (direction === "lower" ? r.metric < bestKept : r.metric > bestKept)) {
        bestKept = r.metric;
      }
    }
  }
  if (bestKept === null || bestKept === baseline) return null;
  return Math.abs(bestKept - baseline) / mad;
}

function correctnessGates(content: string, theme: ReturnType<typeof makeTheme>) {
  const st = buildState(content);
  const rendered = renderDashboardLines(st, 120, theme, 6, HINTS);
  const conf = computeConfidence(st.results, st.currentSegment, st.bestDirection);

  // 1) golden files
  const goldenPath = process.env.GOLDEN_FILE;
  const golden = {
    render: rendered.join("\n"),
    confidence: conf,
    results: st.results.length,
  };
  if (goldenPath && process.env.GOLDEN_CREATE === "1") {
    writeFileSync(goldenPath, JSON.stringify(golden, null, 2) + "\n");
    console.error(`golden created: ${goldenPath} (results=${golden.results})`);
  } else if (goldenPath) {
    const expected = JSON.parse(readFileSync(goldenPath, "utf-8"));
    if (expected.render !== golden.render) {
      const gotLines = golden.render.split("\n");
      const expLines = expected.render.split("\n");
      for (let i = 0; i < Math.max(gotLines.length, expLines.length); i++) {
        if (gotLines[i] !== expLines[i]) {
          console.error(`GOLDEN MISMATCH line ${i + 1}:\n  expected: ${JSON.stringify(expLines[i])}\n  got:      ${JSON.stringify(gotLines[i])}`);
        }
      }
      throw new Error("golden-dashboard mismatch: renderDashboardLines output changed");
    }
    if (expected.confidence !== golden.confidence) {
      throw new Error(`golden-confidence mismatch: expected ${expected.confidence}, got ${golden.confidence}`);
    }
    if (expected.results !== golden.results) {
      throw new Error(`golden-results mismatch: expected ${expected.results}, got ${golden.results}`);
    }
  }

  // 2) random cross-check vs sort-based reference
  const rng = makeRng(0xc0ffee);
  const cases: { metric: number; status: string; segment: number }[][] = [];
  // deterministic edge cases: all-equal, ascending, descending, powers of two,
  // duplicates-heavy, single distinctive outlier
  cases.push([5, 5, 5, 5, 5, 5, 5, 5].map((metric) => ({ metric, status: "keep", segment: 0 })));
  cases.push(Array.from({ length: 50 }, (_, i) => ({ metric: i + 1, status: "keep", segment: 0 })));
  cases.push(Array.from({ length: 49 }, (_, i) => ({ metric: 50 - i, status: "keep", segment: 0 })));
  cases.push(Array.from({ length: 33 }, (_, i) => ({ metric: 2 ** i, status: "discard", segment: 0 })));
  cases.push(Array.from({ length: 40 }, (_, i) => ({ metric: i % 3 === 0 ? 7 : 7 + (i % 5), status: "keep", segment: 0 })));
  cases.push([1, 1, 1, 1, 99].map((metric) => ({ metric, status: "keep", segment: 0 })));
  for (let t = 0; t < 60; t++) {
    const n = 3 + Math.floor(rng() * 40);
    const results = [];
    for (let i = 0; i < n; i++) {
      const metric = rng() < 0.08 ? 0 : Math.round(rng() * 1000) / 10;
      const statusRoll = rng();
      results.push({
        metric,
        status: statusRoll < 0.6 ? "keep" : statusRoll < 0.9 ? "discard" : "crash",
        segment: 0,
      });
    }
    cases.push(results);
  }
  for (const results of cases) {
    const got = computeConfidence(results as never, 0, "lower");
    const want = referenceConfidence(results, 0, "lower");
    const norm = (v: number | null) => (v === null ? -1 : Math.round(v * 1e9));
    if (norm(got) !== norm(want)) {
      throw new Error(`mad-crosscheck mismatch: computeConfidence=${got} reference=${want} (n=${results.length})`);
    }
  }

  return conf;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

const content = buildLogContent(RUNS);
const theme = makeTheme();

const confValue = correctnessGates(content, theme);

const ITERS = Number(process.env.BENCH_ITERS ?? 40);

// Sub-metric timings (diagnostics for where the iteration time goes)
const reconstructMs = benchN(() => { reconstructJsonlState(content); }, 15);
const st0 = buildState(content);
const confidenceMs = benchN(() => { computeConfidence(st0.results, 0, "lower"); }, 15);
const renderMs = benchN(() => { renderDashboardLines(st0, 120, theme, 6, HINTS); }, 15);

// Primary: full iteration
const iterMs = benchN(() => { oneIteration(content, theme); }, ITERS);

const f = (x: number) => x.toFixed(3);
console.log(`METRIC iter_overhead_ms=${f(iterMs)}`);
console.log(`METRIC reconstruct_ms=${f(reconstructMs)}`);
console.log(`METRIC confidence_ms=${f(confidenceMs)}`);
console.log(`METRIC render_ms=${f(renderMs)}`);
console.log(`# runs=${RUNS} iters=${ITERS} frames=${RENDER_FRAMES} conf=${confValue === null ? "null" : confValue.toFixed(4)}`);
