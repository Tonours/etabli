# Implemented: workflow friction from the two-machine audit, in five stacked PRs

## Metadata
- Archived: 2026-11-06
- Source plan: `PLAN.md` — Etabli workflow friction consolidation
- Source plan SHA-256: `cc4c51443a4fe2490a1bd7ad2ba62f14881d84758c3be672c902ba4d883af1f3`
- Status: IMPLEMENTED
- Commit / branch: five stacked PRs, owner merges in order: #80 `fix/skill-health-check`, #81 `refactor/short-fix-route`, #82 `feat/codex-runtime`, #84 `refactor/editorial-guards`, #86 `chore/workflow-baseline` (this archive); side fix #85 `fix/probe-memory-cap` on `main`
- Workflow initiative: workflow-friction

## Outcome
- `deploy --check` runs the Claude and Pi skill-load checks on live homes and counts their failures; a personal skill listed in `~/.config/etabli/machine-local-skills.json` stays governed without a repo edit; the fixture index dropped 2811 to 2709 chars (#80).
- A `bounded-fix` tier (reproducer, focused checks, one fresh review, no plan) and a council `--reuse-review` that skips phase A when a committed final review has the same patch fingerprint (#81).
- Codex is a managed runtime again (ADR-0043): adapter, workflow tree, templates and catalog skills linked under `~/.codex`, refused when any Codex path overlaps what Pi or Claude reads (#82).
- 59 editorial-guard mutants killed by new tests, a dead tool-name branch removed, and the commit guard reads a `-F` file named through `$PWD` in a static command (#84).
- The entry chain went from 418 to 400 lines and its cap from 420 to 405 (#86).
- The mutation probe kills a test tree over `--max-rss` (default 2048 MB), after three host reaps on allocating infinite-loop mutants (#85).

## Findings disposition (AC-1)
| Finding | Disposition | Reason |
| --- | --- | --- |
| F01 personal skill drift | implemented (#80) | machine-local list under `~/.config/etabli/`, index trim; remote config is a post-merge action |
| F02 link-only health | implemented (#80) | check mode runs both skill-load checks |
| F03 entry context | measured, implemented (#86) | read counts below; duplicated index cut |
| F04 short fixes | implemented (#81) | `bounded-fix` tier |
| F05 review stacking | implemented (#81), measured | reuse by fingerprint; review passes per task in the baseline |
| F06 detection evidence | deferred | needs held-out escaped defects; none collected |
| F07 replay integrity | measured: unavailable | see replay line below |
| F08 native validator | REVIEW-2 measured: unavailable; REVIEW-1 deferred | gh token invalid on macbook-work; REVIEW-1 needs a disposable work-repo PR, outside scope |
| F09 editorial guards | implemented (#84) | mutation-guided tests, one dead branch |
| F10 Codex support | implemented (#82) | ADR-0043 |
| F11 instruction drift | already addressed | the stale Codex copy is replaced by the managed adapter |
| F12 ownership boundary | implemented (#81) | failure ownership table in `claude/README.md` |
| F13 outcome metrics | measured | baseline below |
| F14 self-maintenance | implemented | each PR body names its benefit outside Etabli; re-measure date below |

## Baseline (AC-11, F13)
Throwaway script outside Git over local Claude transcripts, 2026-09-06 to 2026-11-06, this session excluded: 686 sessions scanned, 55 routed tasks (route from the first workflow slash command or Skill call).

| Route | Tasks | Owner interventions median (p75) | Session span median, h | Review passes median |
| --- | --- | --- | --- | --- |
| plan-implement | 31 | 6 (18) | 27.7 | 31 |
| plan-loop | 11 | 11 (22) | 9.8 | 29 |
| grilling | 6 | 19 (25) | 49.2 | 48 |
| implement | 3 | 7 (81) | 18.2 | 17 |
| code-review | 3 | 2 (18) | 0.2 | 0 |
| pr | 1 | 1 (1) | 0.2 | 4 |

- Owner interventions: genuine user messages after the routing one, excluding tool results, notifications and injected context.
- Session span includes idle time between turns; it is not active work time.
- Review passes: reviewer and adversary subagents plus `codex exec`, `pi-review-hunter` and council runs.
- Completion: `unavailable`. Transcripts carry no task outcome; the last-message PR-link proxy found 2 of 31 plan-implement tasks, an undercount since sessions continue after the PR and compaction splits them (A5).
- Pi and Codex transcripts were not parsed: `unavailable` for this baseline.
- Entry-chain reads: `workflow/spec.md` in 53 sessions (276 reads), `workflow/contract-details.md` in 18 (45), `workflow/agent-rules.md` in 9 (24); `AGENTS.md` matches every repo's file and is not attributable.
- Re-measure: 2027-02-06, same script and window length, to compare interventions and review passes after these PRs.

## Decisions
### Cut the surface index, not a live rule
- Context: AC-10 asked for 405 lines with cuts chosen from measured reads.
- Choice: delete `workflow/contract-details.md` § Runtime surfaces (detail).
- Rejected options: trimming `AGENTS.md` or `workflow/agent-rules.md`, which are loaded every session and whose reads cannot be told apart.
- Rationale: it was among the least read sections of the chain, and 9 of its 14 entries are already named by `spec.md`, `agent-rules.md` or `AGENTS.md`; the other five moved into `spec.md` § Runtime surfaces, with a pointer to `workflow/memory.md`.
- Consequences: chain at 400 lines; the cap is lowered to 405 so the gain holds.

### Owner budget overrides
- L2 hit the review ceiling twice; the owner chose one extra round each time (D3, then D4, which ended GO).
- L3 ended D2 with a BLOCK on deep user links into `~/.codex/skills`; the owner chose to ship it as a documented residual (ADR-0043).
- The #84 PR review fix (`$PWD` in commit `-F` names) hit D2 and D3 BLOCKs; the owner granted D3 and D4 with a stricter rule. D4 findings, already open for relative names, were closed by narrowing only.

## Accepted Drift
- Original plan/spec: L4 verification by the mutation probe alone.
- Implemented reality: the probe was reaped three times by the host at low memory on allocating infinite-loop mutants; the guard tail was replayed in place, then the full file was reprobed once the memory cap (#85) existed.
- Why accepted: the cap is a separate behavior, so it got its own PR on `main`.

## Validation Evidence
- `scripts/verify-agentic-infra full`: 46/46 on the final diff of each PR (#80, #81, #82, #84, #85, #86).
- Reviews per lot: fresh Logic/Spec hunters and a cross-family adversary per round, verdicts and thread ids in each PR and the source plan.
- `bash tests/entry-chain-budget-smoke.sh`: 400/405.
- replay corpus: 0 cases reachable, hashes unavailable (the frozen inputs of 2026-11-01 are on neither this machine nor macbook-work).
- AC-12: no conversation content, credential or work-org skill name is committed; raw baseline data stays outside Git.
- REVIEW-2 preflight: `unavailable` (macbook-work `gh` token invalid, so no validator report is readable read-only from there).

## Follow-up State
- Remaining risks: L3 deep user links into `~/.codex/skills`; L2 reuse guard blind to assume-unchanged, skip-worktree and `GIT_INDEX_FILE`; `pr-body-guard.mjs:500` open mutant; L4 `$PWD` residuals shared with relative `-F` names (conditional `cd`, `cd -P`, a planted `PWD` glob, sourced files).
- Post-merge, this machine, from the main checkout: `scripts/deploy-agent-workflow --check`, `--apply`, `--check`, then restart Codex.
- Post-merge, macbook-work: `gh auth login`; `cd ~/work/etabli && git pull && scripts/deploy-agent-workflow --apply`; list the personal skill in `~/.config/etabli/machine-local-skills.json`; `scripts/claude-skill-load-check`.
- Parking lot: F06 held-out defects; REVIEW-1; REVIEW-2 rerun once `gh` works on macbook-work.
- Next links: ADR-0043, ADR-0042.
