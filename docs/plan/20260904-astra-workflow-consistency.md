# Implemented: align workflow instructions across agent surfaces

## Metadata
- Archived: 2026-09-04
- Source plan: `PLAN.md` — align workflow instructions before evaluating GPT-6 Astra
- Source plan SHA-256: `b8cd4e3f4ebde78a43ab5163d4dcc681a925fdb811f4b1350f8433b70f1457cd`
- Status: IMPLEMENTED
- Implementation branch: `docs/astra-workflow`; uncommitted at implementation handoff
- Base: `c7cbb09888ce9c1dc72cebfca0cf8de3b76612b9`
- Worktree: `/Volumes/Crucial/work/etabli-astra-workflow`
- Risk tier: high-risk (shared workflow contracts and adapters)
- Reviewed implementation patch SHA-256: `7624e40c038c2a866826b8ba6d7e0182de1792c6cabddbf5d7253b08edc88e4e`

## Outcome
Verified instruction consistency across Pi, Claude, shared workflow entrypoints,
and deployable scaffold entrypoints. All seven plan acceptance criteria were met.
This is structural and review evidence; Astra latency, token use, cost, and task
success improvements remain **not verified**.

## Decisions

### Keep the canonical review tiers
Pi and Claude adversary descriptions/bodies now follow the existing contract:
small skips code-diff adversary; standard accepts cross-model or two fresh
independent same-family samples; high-risk requires cross-model. Plan-mode
reviewer preferences and model IDs are unchanged. The shared adversary contract
itself did not change.

### Select the route before applying implementation depth
READY exclusivity now explicitly applies to routes with a plan. The ordinary
no-plan route still permits bounded runtime fixes; those fixes are not thereby
reclassified as small. Explicit plan requests, multi-slice work, existing
DRAFT/CHALLENGED plans, and high-risk contractual work keep their gates.
Global Pi/Claude entrypoints and both scaffold entrypoints carry this distinction.
Router and guard code, fixture expectations, and permission rules are unchanged.

### Correct the scope of the Codex capability claim
ADR-0015 defines Etabli's managed skills integration; it does not establish
native-tool absence in a host session. Only Codex `surface_class` and
`supports_subagents` changed. The latter is `unknown`, with a source-inspection
command/result/date and an explicit distinction from the successful, narrower
dispatch observed in this session. Hook, guard, and task-tracking claims remain
unchanged. No schema, harness, provider, or model configuration was introduced.

### Use narrow regression checks
Existing docs/capability smokes now reject known unqualified obligations and
source-only native capability overclaims. Temporary negative fixtures and
positive witnesses exercise these checks. They do not parse arbitrary prose or
authenticate free-form runtime evidence. Only the managed `adversary` skill hash
changed in `skills-lock.json`.

## Validation Evidence

| Command / inspection | Final result |
| --- | --- |
| `scripts/verify-agentic-infra core` | **18/18 passed**, including **254/254 Pi tests**, **212/212 router scenarios**, check-freeze and no-progress guards |
| `bash tests/workflow-docs-smoke.sh` | Passed, including negative/positive scope fixtures and the existing 120-line quick-card cap |
| `bash tests/runtime-capabilities-smoke.sh` | Passed, including source-only claim rejection and a synthetic future-proof acceptance witness |
| `bash tests/review-contract-surface-smoke.sh` | **16/16 anchors**; union **10315/10700 B**, lead **1517/1580 B** |
| `bash tests/skill-catalog-name-smoke.sh` | Passed |
| `bun run --cwd pi verify:skills` | **66 hashes verified**; only `adversary` changed |
| Baseline replay with the frozen instruction checker | Five historical excerpts rejected as expected: Pi adversary, Pi AGENTS, Claude CLAUDE, spec, scaffold CLAUDE |
| `git diff --check` | Passed |
| Simplification / convention pass | `simplify: clean`; shell fixtures/cleanup/error conventions checked against `tests/skill-catalog-name-smoke.sh` and `tests/skill-tree-hash-smoke.sh`; no mechanical finding |

The first core run was 17/18 because TypeScript was absent in the isolated
worktree. `bun install --frozen-lockfile --ignore-scripts` prepared its local
dependencies without changing lockfiles. Both subsequent core runs passed.
The final log is `.workflow/astra-workflow/core-final.log`, SHA-256
`247cb225b479f1ec12c66cd940c4cb7b431b5f001dd77dce5aa743fd420107b5`.

## Independent Review
- Logic: fresh native Codex reviewer `/root/logic_review`, **GO**, re-reviewed the corrected cumulative patch.
- Spec: fresh native Codex reviewer `/root/spec_review`, **No findings**, re-reviewed the corrected cumulative patch.
- Native runner: session-exposed Codex collaboration; inherited model configuration, not separately provider-verified or mislabelled as a Pi child.
- Cross-model runner: isolated Pi child, no tools on the final complete packet; structured metadata identifies **`github-copilot/claude-sonnet-5`**, medium reasoning, normal stop.
- Final cross-model session: `01a06e16-6f09-78e0-8b07-9cd2a0f553f6`; verdict **GO WITH NOTES**.
- Final raw evidence: `.workflow/astra-workflow/adversary-final.jsonl`, SHA-256 `a5d409c2b9614210791e116a8a2c7f30e5ceea70135ba8c993e6ec93f29a9bd8`.

The first cross-model diff attempt timed out after 180 seconds and is not a pass.
The complete-packet retry identified missing explicit READY exclusivity in two
entrypoints. Both that wording and its targeted negative fixture were corrected,
then focused checks, core, Logic, Spec, and cross-model review were repeated.

The final low notes suggested broader prose matching, another restatement of
standard-tier runner alternatives, and separate checker self-test scripts.
No concrete correctness failure remained. These were not applied: the checker
explicitly covers historical patterns, the preceding instruction already names
both standard alternatives, and fixtures inside existing smokes follow the
approved scope and neighboring test conventions.

### Lens table
| Lens | Checked (file:line) | Found |
| --- | --- | --- |
| Precedence | workflow/skills/adversary.md:55 | Adapters follow the shared contract |
| Degraded modes | workflow/skills/adversary.md:59; tests/runtime-capabilities-smoke.sh:14 | Standard fallback and unknown evidence remain bounded |
| Impossible states | tests/runtime-capabilities-smoke.sh:20; tests/workflow-docs-smoke.sh:104 | Negative fixtures match the checks |
| Prose vs machine-readable | workflow/runtime-capabilities.json:205; tests/workflow-docs-smoke.sh:88 | Declarations and targeted checks agree |
| Exhaustive reachability | workflow/skills/adversary.md:57; tests/workflow-docs-smoke.sh:112 | Three tiers; qualified READY witness accepted |
| Asymmetry | pi/AGENTS.md:16; claude/CLAUDE.md:17 | READY exclusivity explicit in both |
| Boundary drift | workflow/skills/implementation-loop.md:8 | Route and risk remain separate |
| Convention | deferred: parent convention pass | Completed against the two smoke siblings above |

### Deciding-code table
| Changed behavior | Deciding code opened (file:line) | Sibling / resolver | Result |
| --- | --- | --- | --- |
| Review independence | workflow/skills/adversary.md:55 | workflow/skills/implementation-loop.md:126 | Three tiers preserved |
| READY exclusivity | pi/AGENTS.md:16; claude/CLAUDE.md:17 | workflow/skills/implementation-loop.md:45 | DRAFT/CHALLENGED remain blocking |
| Codex unknown claim | workflow/runtime-capabilities.json:205 | tests/runtime-capabilities-smoke.sh:64 | Label and evidence scope agree |
| Source-only overclaims | tests/runtime-capabilities-smoke.sh:11 | tests/runtime-capabilities-smoke.sh:20 | Negative and synthetic positive cases pass |
| Historical unqualified rules | tests/workflow-docs-smoke.sh:79 | tests/workflow-docs-smoke.sh:101 | Targeted detection matches its stated scope |
| Missing READY exclusivity | tests/workflow-docs-smoke.sh:88 | tests/workflow-docs-smoke.sh:104 | Regression rejected, corrected prose accepted |
| Fixture cleanup | tests/runtime-capabilities-smoke.sh:19 | tests/workflow-docs-smoke.sh:99 | EXIT cleanup retained |

Extra-lens: no

## Accepted Drift
None in implementation scope or acceptance criteria. Local dependency preparation
and a better-bounded review packet resolved environment/reviewer execution limits.
No benchmark, gate relaxation, external skill edit, or model migration was added.

## Follow-up State
- At implementation handoff, this worktree held the uncommitted implementation, this archive, and local raw evidence. Publication is handled separately from that validation snapshot.
- The original Claude token-economy PLAN and unrelated `pi/models.json` changes are preserved, with their initial SHA-256 fingerprints rechecked.
- Root `PLAN.md` in this worktree was removed by `scripts/plan-cleanup --archive` after the archive passed its quality check and exact source-plan hash check.
- Remaining risks: static checks cover known wording and evidence mismatches, not universal semantic correctness. Runtime efficiency and behavior across other hosts require a separately frozen, authorized evaluation.
- Deferred: quality-unavailable policy changes, skill-eval efficiency work, external skills, Pi migration, and the unfinished Claude token-economy task.
