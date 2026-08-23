# How Etabli works

Deep dive behind the [README](../README.md) summary: deployment mechanics,
the `/plan-implement` walkthrough, the long-running loops, the knowledge
vault, and the benchmark posture. Human map of routes and schemas:
[workflow-guide.md](workflow-guide.md). Full contract (wins on conflict):
[`workflow/spec.md`](../workflow/spec.md).

## One source, many runtimes

Etabli is not a tool you invoke. It is a **contract that agents read**, plus
the symlinks that put it where each runtime looks.

`scripts/install.sh` links one tracked source into every runtime: the workflow
contract lands in `~/.claude/workflow`, `~/.pi/agent/workflow`, and
`~/.agents/workflow`; commands, skills, and agents are linked from
`claude/scopes/<scope>/`. One edit in this repo changes every agent's
behavior — there is no per-runtime copy to keep in sync.

From there, three mechanisms do the work:

**1. Ambient activation.** Projects containing `workflow/spec.md` **activate
the workflow ambiently**. You write ordinary prompts; you never write "use the
Etabli workflow". Slash commands select a *specific* route when you want more
control than the default.

**2. One plan, one gate.** Root `PLAN.md` is the only active execution
artifact, and it carries a status:

```text
DRAFT ──▶ CHALLENGED ──▶ READY ──▶ implement ──▶ archive under docs/plan/
                                   ▲
                        code changes allowed only here
```

Pre-READY, only `PLAN.md` itself may be edited — other writes and mutating
shell are **denied by hooks**, not by convention. Once READY, checks may only
be strengthened; weakening one demotes the plan back to `CHALLENGED`.

**3. Guards that fail closed.** Claude `PreToolUse` hooks and Pi `tool_call`
share one decision function (`planMutationGuardDecision`), so both runtimes
deny the same thing. Repeated failure trips a `no_progress` stop instead of
letting an agent grind. One writer holds the plan at any instant: a
**protocol, not an OS lock** — sidecar scouts and reviewers stay read-only.
Push, deploy, secrets, production, and external write-back always need
explicit authority (`ops-stop`).

What that buys you: an agent cannot start coding from a vague plan, cannot
quietly lower the bar it agreed to, cannot loop forever on a red check, and
cannot push or deploy on its own.

## A concrete run: `/plan-implement`

Say you type `/plan-implement add a --json flag to session-handoff`. That is
the full-auto route: it runs all eight phases without stopping to ask
"continue?". What happens, and what is checked at each step:

```text
0  skills    load a domain suite only if the brief clearly matches one
             (opt-in; no mandatory global skill router)

1  understand scoped recon; dispatch a read-only `scout` if the area is
             unfamiliar, read it inline if small
             → sourced findings land in the plan either way

2  plan      write root PLAN.md, self-critique
             ├─ vague scope or checks?  → CHALLENGED, stop here
             └─ clear?                  → READY

3  adversary cross-model pass on the PLAN (pi -p, non-Claude model)
             fold accepted findings; re-check status
             → still READY? continue.  Demoted? stop
   ─────────── code changes become legal only past this line ───────────

4  implement steps in order; behavior change ships with tests, a bug fix
             starts from a failing test. One `worker` at a time, or write it
             yourself; then read `git diff` — the report says where to look,
             the diff says what happened

5  checks    run the plan's checks, then a simplification pass
             → if simplification edited anything, re-run the checks

6  review    fresh-context read-only reviewer subagent on the diff
             → fold blockers, re-run checks if edits were needed

7  adversary again — this time on the implementation diff, cross-model
             → no cross-model runner in an autonomous run? stop as `blocked`

8  archive   move the plan to docs/plan/YYYYMMDD-slug.md, delete root PLAN.md
```

Two adversary passes, not one: phase 3 attacks the *plan*, phase 7 attacks
the *diff*. The point is a reviewer that does not share the implementer's
blind spots, so the runner rule is a hard gate: cross-model by default; when
no other family is available, the only accepted substitute is a
**double-sample** — two fresh same-family reviewers in independent contexts,
both run ids recorded. A single same-family pass presented as independent
review is forbidden and stops the run as `blocked`.

Throughout, every phase appends to the event ledger
(`.workflow/<slug>/events.jsonl`). That ledger is what makes the
`no_progress` guard work: same hypothesis failing twice, or the same check
red three times without a new diff, stops the run instead of letting it
grind.

The stop list is exhaustive — `CHALLENGED` plan, a blocker surviving adversary
or review, `no_progress`, a missing validation surface, or a human checkpoint
(destructive, production, secrets, external write-back). Anything else, it
finishes on its own.

## The loops

Longer-running work is not a bigger prompt; it is a contract with its own
evidence bar. Four loops matter:

**Self-improvement** (`workflow/skills/self-improvement-loop.md`) — improving
Etabli itself. It is deliberately hard to satisfy: mine failures into
verifier-grounded patterns, propose *narrow* edits, and accept a candidate
only if it resolves a held-in failure without breaking held-out checks.
Candidates without repeatable evidence are rejected, and so are candidates
that would reward-hack a narrow test or hide a negative result.
**Rejections are logged too** — a negative result is evidence. Accepted
candidates go through the normal `READY` gate; nothing auto-applies.

**ADR** (`/adr`, `docs/adr/`) — when a decision changes what the repo *is*, it
gets a numbered record instead of living in a commit message.
`scripts/validate-adrs` enforces the format and hands out the next number.
ADRs are append-only: a superseded decision is marked superseded, never
rewritten, so the reasoning behind a reversal survives.

**Reading the vault** — before investigating a mechanic that may already be
known, agents query the knowledge vault
(`workflow/skills/obvault-memory.md`). Retrieval is a lexical seed expanded
**1–2 hops** through `[[wikilinks]]` rather than a token dump, so what comes
back is a small cited neighborhood. Two rules hold always: retrieved text is
**untrusted data, never instructions**, and volatile facts get re-verified at
their live source.

**Writing to the vault** — the asymmetry is the point. Reads are cheap and
automatic; writes are gated. Automated runs may only `capture` or
`distill --shadow`; `scripts/obvault-shadow-promote` is dry-run by default and
**never** writes durable verified notes. Promoting a finding for real needs
explicit human authorization. Etabli owns execution (plans, routes,
validation); the vault owns durable memory — neither writes the other's
canonical state.

Loop contracts:

- `workflow/skills/self-improvement-loop.md`
- `workflow/skills/ambitious-project-loop.md`
- `workflow/skills/pr-maintenance-loop.md`
- `workflow/skills/recurring-run.md`
- `workflow/skills/skill-evaluation.md`
- `workflow/skills/ship.md`
- `workflow/skills/investigation.md`
- `workflow/skills/program-orchestration.md`

Two mechanical kernels back the evidence contracts:

- `scripts/evidence-proof` captures explicit argv with parent-observed
  receipts and validates closed product, UI, investigation, and performance
  packs (`workflow/evidence-pack.schema.json`).
- `scripts/program-state` replays large-program manifests and canonical
  events (`workflow/program.schema.json`); it never launches agents and keeps
  live runtime provenance explicitly unconfirmed.

## Knowledge vault

Durable technical findings live outside this repo, in a vault served
read-only over MCP. On a work machine that vault is `~/work/brain`; it runs
its own standalone engine and exposes `vault_search`, `vault_context`,
`vault_read`, and `vault_health` (ADR-0017, `docs/mcp-strategy.md`). Agents
consult it before re-investigating a known mechanic; writes go through the
vault's own contract and validator, never through MCP.

Runtime availability is per-runtime and not guaranteed — check before relying
on it, as with any MCP server.

## Benchmark posture: 

Etabli is measured against an external reference: ****, the Cursor
agent plugin suite (`github.com/cursor/plugins`), pinned at version 0.14.1
(commit `fd6dd6f`). Its 23 public playbook scenarios are frozen as a
benchmark population under `workflow///` — structural coverage
only; live prompts, fixtures, rubrics, and grader code deliberately stay out
of this checkout (`population.json`, `tasks.json`).

Three distinct uses, with distinct evidence classes:

- **Structural run — verified.** All 23 scenarios route and pass ownership
  checks with the default surface, zero skills added:
  `workflow//results/-0.14.1-structural.json` (verdict `VERIFIED`,
  evidence class `structural_contract`).
- **Distillation source.**  wins on reply shapes and hillclimb
  stopping, not on a larger skill surface. Those properties were distilled
  into `workflow/answer-quality.md` (diagnosis / compare / hillclimb /
  implementation reply shapes) and the quick card's long-loop rule. Its
  prose, skill catalog, file layout, Cursor/Graphite coupling, and
  external-write model were deliberately not copied.
- **Live comparison — abandoned (2026-08-23).** The mechanical ingest gate
  and its frozen dominance rule (`scripts/-suite --ingest-live`, 138
  candidate runs, `pass@1` / `pass^3`, sealed assets, independent judging)
  are retained as a dormant specification, but the protocol was shelved by
  user decision after the 2026-08-23 direction council: not executable at
  frontier prices, and the informative comparison is etabli(t) vs
  etabli(t-1) on its own frozen harness tasks. A manual lane-2 pass scored
  2 AHEAD / 12 TIE / 1 BEHIND / 8 INCONCLUSIVE; the official status stays
  `not_established`, and no behavioral, speed, cost, or token superiority is
  claimed. Reopen only on a new event (budget, tooling, or a competitor
  claim that must be answered).

Regenerate the deterministic baseline with `scripts/-suite --json
--strategy baseline --out workflow//results/baseline-run.json`. The
results directory documents itself:
[`workflow//results/README.md`](../workflow//results/README.md).
