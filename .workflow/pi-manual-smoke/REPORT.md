# pi-manual-smoke — REPORT

Smoke test of the Pi **`TaskExecute` / subagents** workflow on the real `etabli/`
project. Orchestrator + 2 parallel subagents. Read-only on product; all writes
confined to this directory.

## TL;DR — verdict: **GO**

- `TaskExecute` was **genuinely used** (not simulated): 2 distinct agent IDs
  launched, both reached `completed`, with independent, specific returns
  (file:line refs, byte sizes, a jq edge-case I did not feed them).
- Both subagents + my own parallel local run agree: dry-run is clean (exit 0),
  and both `@tintinweb/pi-*` packages are declared and installed.

## What was actually run (mechanics proof)

| Step | Tool | Outcome |
| --- | --- | --- |
| Plan tracking | `TaskCreate` x4, `TaskUpdate`, `TaskList`, `TaskGet` | OK |
| Parallel dispatch | `TaskExecute` task_ids `[2,3]` | Launched `f4f1f954…` + `1d14896e…` |
| Retrieval | `TaskGet` (metadata.result) | Both `completed`, full results recovered |
| Local dry-run | `scripts/deploy-agent-workflow --dry-run` (cd etabli) | exit **0**, `SUMMARY dry-run complete` x3 |
| Package probe | exact brief jq + grep | both lines printed, grep exit 0 |

> Subagent gotcha worth recording: `TaskExecute` requires tasks in `pending`
> status. Marking them `in_progress` (the convention for self-work) makes
> `TaskExecute` skip them. Delegated tasks stay `pending`.

## Accepted (verified, multiple sources agree)

1. **Packages real & installed** — `npm:@tintinweb/pi-tasks` (settings L83) and
   `npm:@tintinweb/pi-subagents` (L86); on disk at
   `~/.pi/agent/npm/node_modules/@tintinweb/{pi-tasks,pi-subagents}`. Confirmed
   by subagent B **and** my own jq.
2. **Dry-run clean & replayable** — exit 0, all `OK` lines, three
   `dry-run complete` summaries; subagent B re-ran it twice with identical
   output, no side effects.
3. **Docs accuracy** — `workflow/skills/orchestration.md` and
   `docs/agentic-workflow-hardening.md` correctly describe the `Task*` family,
   `TaskExecute`, and the `subagents:rpc:*` tracking prerequisite.

## Rejected (claims not supported)

1. "Scenario is fictional" — the brief framed it as fictif, but every referenced
   artifact exists in `etabli/` and the packages are real. No fabrication was
   needed or performed.
2. Subagent B's first impression that the brief's jq "errored" — the **naive**
   `.packages[].source` errors (exit 5) on bare-string entries; the brief's
   actual command (with the `type=="string"` guard) works and returned both
   lines at exit 0 in my run.

## Conflicts / discrepancies

1. **AGENTS.md vs orchestration.md** — `etabli/pi/AGENTS.md` does not name the
   `Task*` family or the packages (0 grep hits); it defers to
   `orchestration.md`, which is accurate. Not a contradiction, but a reader who
   only reads `AGENTS.md` will miss the mechanism. → Accepted as intentional
   layering, logged as a risk.
2. **jq shape** — `settings.json` `packages[]` mixes strings and `{source:…}`
   objects. Tooling assuming a uniform shape will break; always use the
   type-guarded expression.

## Decisions

- Treat `TaskExecute` + the `@tintinweb/pi-*` packages as the live, working
  subagent path in this environment (RPC bridge active — indirect proof: the
  spawned Explore agents completed and returned).
- Keep all artifacts under `.workflow/pi-manual-smoke/`; no product edits.
- No push, no secret/env access performed.

## Final evidence

- `local-dry-run.log` — captured dry-run, exit 0.
- `subagent-a.md` / `subagent-b.md` — verbatim subagent returns.
- `TaskList` snapshot: #1 completed, #2 completed, #3 completed, #4 this report.
- `TaskGet` metadata held full `result` strings for both subagents.

## Remaining risks

1. **RPC bridge not directly probed** — I did not run an explicit
   `subagents:rpc:ping`/`spawn`/`stop` handshake; success is inferred from the
   two completed subagents. If the bridge is flaky elsewhere, `TaskExecute`
   could degrade to skipped/simulated. Recommend a direct rpc probe in a future
   run.
2. **`pi/AGENTS.md` is generic** — add a one-line pointer to the `Task*` family
   - packages if single-file discoverability matters. (Out of scope here;
   product edit, would need its own ticket.)
3. **`--apply` untested** — dry-run proves the plan is clean, not that the real
   apply is idempotent. Intentionally out of scope.
4. **Agent ID truncation** — the launch message truncated IDs; `TaskOutput` with
   the partial ID returned "No task found" once tasks cleared. Use `TaskGet`
   (numeric id) or full agent IDs for retrieval.

## Verdict: **GO**

Mechanics work end-to-end on real infra: `TaskExecute` spawned 2 real parallel
subagents, both completed, results integrated; the local dry-run is clean
(exit 0) and both required packages are present. No NO-GO blockers.
