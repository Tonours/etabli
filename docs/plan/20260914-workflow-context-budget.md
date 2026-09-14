# Implemented: resident instruction context cut ~26–49% on hot workflow routes, gated by a ratchet-only context budget, plus a bounded recursive self-improvement loop

## Metadata
- Archived: 2026-09-14
- Source plan: `PLAN.md` — workflow context budget + self-improvement loop
- Source plan SHA-256: `9b1d5354f09e52ab889e595f20e057555514da09581228f777bda2094ba28507`
- Status: IMPLEMENTED
- Commit / branch: uncommitted working tree on `main` (no commit requested)

## Outcome
- New gate `scripts/workflow-context-budget` +
  `workflow/runtime/context-budget.json`: measures declared read-chain
  surfaces in JS `String.length` chars against ceilings; `--ratchet` lowers
  ceilings to `ceil(chars * 1.03)`, never raises, refuses to write when any
  surface is `missing` or `over`. Registered in
  `workflow/runtime/agentic-infra-checks.tsv` (core cap 18 → 19).
- `workflow/spec.md` is now on-demand for hot routes; its route-critical rules
  were duplicated into `workflow/skills/implementation-loop.md` and
  `workflow/skills/plan-loop.md`. It stays canonical and wins on conflict.
- `workflow/events.md` split: validator/lock/protocol/measurement internals
  moved to `workflow/events-validator.md`; the compact agent contract stayed.
- New `workflow/templates/plan-archive.md`; symlink detail moved from
  `AGENTS.md` to `docs/symlink-layout.md` (resident "do not" warnings kept).
- `scripts/workflow-retrospect` emits `context_budget`, `telemetry`
  (measured/unmeasured only — unknowns never counted as measured), and
  `terminal` (completed/blocked/in_progress) sections; tolerates corrupt
  `events.jsonl` lines instead of dying under `pipefail`.
- `workflow/skills/self-improvement-loop.md` Token lens: retrospect →
  candidates → READY `PLAN.md` → trim → `--ratchet`. Unattended
  `recurring-run` may only retrospection-write under `.workflow/<slug>/`;
  applying anything requires a user-invoked `plan-implement`.

| surface | baseline | chars | ratcheted ceiling | Δ |
| --- | ---: | ---: | ---: | ---: |
| always-on | 28423 | 16150 | 16635 | −43 % |
| plan-loop | 5657 | 4180 | 4306 | −26 % |
| plan-implement | 80451 | 52991 | 54581 | −34 % |
| implement | 74632 | 48747 | 50210 | −35 % |
| review | 21800 | 21800 | 21800 | 0 % |
| verify | 3093 | 3071 | 3093 | −1 % |
| spec-map | 32258 | 32256 | 32258 | ~0 % |

These are resident-instruction characters, not billed tokens; est_tokens is
`chars/4` and provider-billed savings are explicitly unverified (38 of 53
`outcome_metric` ledgers are unmeasured). The resident-context multiplier is
the evidence: ledger total/(input+output) ratios of 37×–420×.

## Context
- `workflow/runtime/context-budget.json`: surface membership is the contract;
  `always-on`/`plan-loop`/`plan-implement` memberships are pinned in
  `tests/workflow-context-budget-smoke.sh`.
- `workflow/events.md` vs `workflow/events-validator.md`: the validator doc is
  deliberately cold (opened only when editing the event system); surface
  descriptions say so.
- `.workflow/workflow-context-budget/baseline.json`: frozen pre-change
  measurements; `review-patch.diff` + hunter/adversary outputs in the same dir.

### spec.md § Rules → destination mapping (AC4)

| Rule (first words) | Destination on the hot path |
| --- | --- |
| Read code before planning or editing; retry from `/`… | `workflow/skills/implementation-loop.md:54`; `workflow/skills/plan-loop.md:37` |
| For broad external research, repo-pattern, or fresh-context review… | stays route-specific in `spec.md` (detail: `workflow/contract-details.md:53`) |
| When asked whether a source implies repository changes… | stays route-specific in `spec.md` (`contract-details.md:56`) |
| Before mutable local-device or server actions… | `implementation-loop.md:43` (Standing rules) |
| One execution artifact: `PLAN.md`. No `REVIEW.md`… | `pi/skills/plan-implement/SKILL.md:24`; `workflow/agent-quick-card.md:23-24` |
| Keep facts separate from assumptions; use `PLAN_TEMPLATE.md`… | `PLAN_TEMPLATE.md` (on hot surfaces) |
| Source research / answers & handoffs… | `workflow/answer-quality.md` on hot surfaces; `pi/AGENTS.md:24` |
| Autonomous plan-loop requests use `plan-implement`; wording is not proof… | `implementation-loop.md:61`; `agent-quick-card.md:45` |
| Autonomous loops incomplete until completion evidence… | `implementation-loop.md:169-189` |
| Work spanning several repos still uses one plan… | `implementation-loop.md:139-141` → `workflow/plan-archive.md` (cold) |
| Branch-mutating routes (`/ship`, single-PR pilot, `sec-pr`)… | stays in `spec.md` (`workflow/skills/worktree-isolation.md`) |
| Product dogfood; single-PR pilot… | `implementation-loop.md:82-89`; pr-maintenance stays in `spec.md` |
| Evidence and investigations… | `implementation-loop.md:87`; investigation route stays in `spec.md` |
| Large programs: frozen control plane… | `implementation-loop.md:73-75`; control plane stays in `spec.md` |
| Events: autonomous routes must record… | `workflow/events.md` on hot surfaces; `implementation-loop.md:184,189-191` |
| Experimental read-only: `workflow-retrospect`; skill evaluation… | stays in `spec.md`; consumed via self-improvement Token lens |
| Self-improvement / ambitious / opt-in autonomy pointers… | stays in `spec.md` (echoed `pi/skills/plan-implement/SKILL.md:17-20`) |
| No-progress stop… | `implementation-loop.md:36-38` |
| Check-freeze: once READY… | `implementation-loop.md:39-42`; `pi/AGENTS.md:17` |
| Stop conditions pair measurable goal + cap; handoff events… | `implementation-loop.md:153-167,124-129,48-50` |
| Implementation depth is risk-tiered… | `implementation-loop.md:13-33,133-142` |
| Golden principles… | `implementation-loop.md:45-47,70`; `workflow/skills/review.md:128`; handoff merge at `implementation-loop.md:48-50` |
| Context budget (new bullet) | `workflow/spec.md:101-105` → budget JSON, gate script, Token lens |

## Decisions
### Metric = declared-surface chars, not provider receipts
- Context: 38/53 `outcome_metric` ledgers unmeasured; Claude/Codex receipts unavailable.
- Choice: static `String.length` chars per declared surface, one frozen script, ratchet-only ceilings.
- Rejected options: billed-token deltas (unverifiable), skill/tool catalogs (already gated).
- Consequences: gate is deterministic and CI-checkable; overclaim risk handled by reporting chars + `chars/4` estimate only.

### spec.md on-demand, with rule duplication instead of removal
- Choice: duplicate the route-critical spec rules into the loop contracts, keep spec.md canonical + conflict-winning, ceiling the `spec-map` surface so growth cannot hide there.
- Rejected: linking without duplicating (hot routes would lose the rules).

### Recursive self-improvement stays READY-gated
- Choice: unattended runs measure and report only; application requires user-invoked `plan-implement`; ceilings raise only via reviewed diff + Decision Log.
- Consequences: the loop cannot patch the harness autonomously; `--ratchet` itself fails closed on non-green runs.

## Accepted Drift
- Original plan/spec: `always-on` target ≤ 15500 chars.
- Implemented reality: 16150 after the code-diff adversary added `claude/CLAUDE.md` (1678 chars) — it deploys to `~/.claude/CLAUDE.md` and is paid on every Claude turn.
- Why accepted: a smaller number measured against an incomplete surface would be dishonest; −43 % still meets the intent.
- Also deliberate: plan-loop relative-path/realpath source-resolution rungs dropped (section-list fallback preserves shape; standard home-symlink installs unaffected); consistency rewording on `verify.md` and `adversary` adapters (unmeasured surfaces); the terminal 2026-09-05 token-quality plan was discarded as a precondition of the single-`PLAN.md` slot (`docs/plan/20260913-discarded-token-quality-optimum-blocked-terminal.md`).

## Validation Evidence
- `scripts/workflow-context-budget` (+ `--json`, `--ratchet`, `--help`): green, 7 surfaces within ratcheted ceilings.
- `bash tests/workflow-context-budget-smoke.sh`: ok (fixtures: green/over/missing/ratchet-floor/never-raise/no-write-on-red/json/exit-2/membership pins).
- `bash tests/workflow-retrospect-smoke.sh`, `workflow-event-smoke.sh`, `workflow-docs-smoke.sh`, `plan-cleanup-smoke.sh`, `claude-commands-smoke.sh`, `claude-skills-smoke.sh`: ok.
- `scripts/verify-agentic-infra core`: 18/19 — sole failure `pi-typecheck` on pre-existing untracked user file `pi/extensions/pi-mobile-bridge.ts` (missing `@pi-mobile/protocol`), out of scope and untouched.
- `router-eval`: 212/212, accuracy 1. `verify-skills-lock`: 83/83 hashes.
- `git diff --check`: clean.
- Review: fresh-context Logic + Spec hunters (cross-model `zai/glm-5.3`) → GO WITH NOTES (4 fixes folded, 1 rejected with evidence). Code-diff adversary (cross-model `zai/glm-5.3`, `adversary_model` recorded) → GO WITH NOTES (10 findings, no highs; fixes folded).
- `simplify: clean` (post-review hunks); `quality: node+bash | mechanical fixed: 0 | findings: 0 | status: clean` (sibling comparison — practice skills not exposed).
- Ledger: `.workflow/workflow-context-budget/events.jsonl` validated `--profile autonomous-completed`.

## Follow-up State
- Remaining risks: scaffold deployments carry the new files only after `scripts/deploy-workflow` redeploy; `pi-typecheck` stays red until the user resolves `@pi-mobile/protocol` in their own file.
- Parking lot: `events-validator.md` could join a future `events-maint` surface if the event system becomes a frequent edit target; unattended-bound could get a mechanical allowlist if prose ever proves insufficient; terminal counts in retrospect are the regression trigger for the next self-improvement cycle.
- Superseded docs/specs: none.
- Next links: `docs/workflow-context-budget.md` (metric + loop doc), `workflow/skills/self-improvement-loop.md` § Token lens, `.workflow/workflow-context-budget/baseline.json`.
