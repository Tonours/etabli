# Workflow statistics and recurring patterns

Run a local report from Etabli:

```bash
scripts/workflow-ship-metrics --dir .workflow report --since 2026-09-01
scripts/workflow-ship-metrics --dir .workflow report --since 2026-09-01 --until 2026-10-01 --json
```

The command reads existing sources and prints to stdout. It creates no registry,
updates no journal and applies no recommendation. Despite its name, it covers
workflow initiatives outside `/ship` too. Single-project archives come from
`docs/plan` in the parent of the supplied workflow directory.

The text view shows source coverage, completed/blocked/correction event counts,
the top ten patterns ranked by work groups, observation dates and evidence paths with line numbers.
JSON retains the original `sources`, `primaries`, `outcome` and `counters`, and
adds `project_root` and `patterns`. JSON includes all patterns and diagnostics.

## What the counts mean

- A recurrence counts distinct `(canonical project root, initiative slug)`
  identities. Several events or an archive and ledger from the same initiative
  count once; `observation_count` separately counts the evidence observations.
- Known review-budget exhaustion phrases share `blocked/review-budget-exhausted`.
  Enum blockage reasons remain separate. Other blockage/finding text is given an
  exact-text fingerprint and labelled unclassified; this is not semantic analysis.
- Validation failures group by the check's exact trimmed command. Case and quoted
  whitespace remain significant. Commands, failure text and finding text are not
  copied into the new pattern output; source paths locate the original evidence.
- Three work groups produce a candidate mechanical-check recommendation.
  Mapped families count once; unmapped runs require an independence check first.
  Every recommendation needs review before application.
- First/last dates describe observations. Archive evidence uses its recorded date
  (`timestamp_basis: archive_recorded`), not a claimed incident time; a partial-day
  window includes archives recorded on that day.

`completed` events do not prove accepted delivery. Missing costs, review time,
accepted-merge receipts, reverts or ship rows remain `missing`/`null`, never zero
success or an invented rate. Ship registry windows still use row file mtime.

All current guard-journal records lack reliable test/live and initiative
provenance. They appear under `patterns.unattributed_guards`, with unknown origin
and `initiative_count: null`; they are excluded from initiative recurrence.
Historical journal bytes are preserved. Pi and Claude guard tests now use
disposable directories, pinned by `tests/guard-journal-isolation-smoke.sh`.

## Archive coverage

Only implemented archives qualify: an `# Implemented:` title and exactly one
`- Status: IMPLEMENTED` field inside `## Metadata` (an optional parenthesized
qualification is accepted). Draft/discarded files are ignored. Missing/ambiguous
metadata or unreadable sources produce coverage diagnostics.

Issue evidence comes from `Context`, `Decisions`, `Accepted Drift` and
`Follow-up State`, outside fenced code. The reader accepts explicit annotations
or known failure phrases on `Context:`, `Issue:`, `Risk:`, `Remaining risks:` and
`Impact:` bullet lines. Outcome/validation-success prose, negative findings and
generic "accepted findings fixed" statements are excluded.

An explicit annotation allows a precise join with a ledger pattern:

```markdown
## Metadata
- Status: IMPLEMENTED
- Archived: 2026-10-01
- Workflow initiative: owner-run

## Follow-up State
- CI wait recurred. [pattern:blocked/ci_wait] [initiative:other-run]
```

A per-line initiative overrides metadata. A single metadata slug may be bare or
backticked, followed by nothing, one balanced parenthetical covering the whole
suffix, or `, closed as documented ` followed by backticked `blocked` and prose.
Comma-separated run lists, `none` and other ambiguous identities are excluded
with a diagnostic when they carry issue evidence. Add a per-line initiative to
disambiguate; the reader never guesses identities from filenames or broadcasts
one finding to every run mentioned. Slugs need not have an existing ledger.

## Several explicit projects

Create a private JSON file containing absolute repository roots:

```json
[
  "/Volumes/Crucial/work/etabli",
  "/absolute/path/to/another-project"
]
```

```bash
scripts/workflow-ship-metrics --projects /path/to/projects.json report --since 2026-09-01
scripts/workflow-ship-metrics --projects /path/to/projects.json report --since 2026-09-01 --json
```

`--projects` replaces the leading `--dir` and works only with `report`.
Canonical duplicate roots (including symlink aliases), relative/non-directory
roots, malformed/empty inventories and mixed `--dir`/`--projects` fail with a
remediation. Each project reads its own `.workflow` and `docs/plan`; missing
sources remain visible per project. Nothing is discovered automatically.
`--herdr-history` remains single-project only.

## Validation

```bash
node --test tests/workflow-patterns.test.mjs
bash tests/workflow-ship-metrics-report-smoke.sh
bash tests/guard-journal-isolation-smoke.sh
```

Limits: fingerprints do not identify every paraphrase; conservatively excluded
archives reduce coverage; the report does not validate whole-ledger workflow
completion. Use `scripts/workflow-event validate` for that separate check.
Source-health diagnostics can concern malformed records outside the selected
window. Mixed positive/negative archive lines are conservatively excluded;
annotate a separate positive issue line when it should count.

## Work families and historical resolutions

Each project may maintain `docs/workflow-run-lineage.json`. The report reads only
that project's file, including in portfolio mode; it never infers membership from
slug prefixes, titles or handoff prose. The Etabli registry records the reviewed
Lean Context, project-vault and contract-coherence chains. Their sources are
`docs/plan/20260927-lean-context-t4.md`, `docs/plan/20261001-project-vault-cleanup.md`
and `docs/plan/20260924-contract-coherence.md`. The latter retains a Herdr incident
gap, so it is grouped but carries no resolution assertion.

```json
{
  "schema_version": 1,
  "families": [{
    "id": "one-work-item",
    "runs": ["first-attempt", "review-resume", "finished-attempt"],
    "resolutions": [{"blocked": "first-attempt", "completed": "finished-attempt"}]
  }]
}
```

The schema uses exactly these keys. IDs and listed runs use the ledger slug
alphabet. Each listed run belongs to one family. Resolutions are direct links
from one blockage to one same-family completed successor; they do not follow
chains. Invalid/duplicate identities, conflicting links, self-links or unknown
fields reject the registry with a diagnostic and leave all runs unmapped.
Missing, malformed, legacy or non-final successor ledgers leave individual links
unresolved. Missing registries leave every run unmapped. Unmapped runs have a
separate identity namespace and do not collide with explicit families.

JSON preserves `initiative_count` and `observation_count`; additive fields include
`family_count` (mapped families plus separate unmapped runs), `unmapped_run_count`,
`phase_counts`, `resolutions` and `recorded_resolved_run_count`. Both family and
run counts appear in text. Planning observations are labelled separately; a
planning finding or deliberately failing regression check is not evidence of a
production incident. No test intent is inferred from free text.

Recorded successor completion requires the existing integrity checker to accept
the source/target ledger, without legacy post-terminal compatibility. The final
successor event must be v2 `completed` with a valid canonical timestamp strictly
later than the v2 blockage and no later than report `until`. A future completion
cannot resolve an earlier report. The source blockage remains in historical
counts. This is an explicit maintainer link plus recorded workflow closure,
not incident-level verification or accepted delivery.

## Check prerequisites and closing evidence

```bash
scripts/workflow-run-check preflight --json
scripts/workflow-run-check preflight --claude-home /path/to/home
scripts/workflow-run-check close --dir .workflow your-run --json
```

Preflight checks `node`, `bun`, `jq`, `git`, local Pi agent/TypeScript metadata,
the host TypeScript 7 compiler, and native ESM resolution of the agent and
`typebox` from `pi/extensions`. It checks availability without loading packages,
installing dependencies or editing settings. `--root` selects the prerequisite
tree. `--claude-home DIR` delegates to the existing hooks checker for
`DIR/.claude`; without it, live hooks are explicitly **not checked**. Missing
prerequisites return exit 1 and name the remediation. Re-run the affected
validation when its cause or prerequisite has changed.

`close` copies only the selected ledger into an external temporary directory.
The real `workflow-event` CLI appends a placeholder `archive_written`,
`plan_removed`, then `completed`, and validates `autonomous-completed`. The copy
is removed afterwards. Terminal/missing/malformed runs, stale review evidence
and latest failed checks fail; no source ledger/pointer is changed. The result
states `scope: prospective-event-chain`, `archive_checked: false`. It neither
checks a physical archive nor removes PLAN nor completes the real run. Follow
the actual exact-hash archive and sanctioned cleanup procedure after readiness;
record the archive as `archive_written`, not as a late code `file_changed`.

Before the first review, select the existing boundary matrices relevant to the
plan and run them after implementing the smallest working slice:

| Surface | Boundary families | Existing command |
| --- | --- | --- |
| Shared shell/cleanup guards | quoted paths, shell expansion/operators, continuations, cwd and executable identity; both runtime envelopes | `bash tests/dual-runtime-guard-matrix-smoke.sh` |
| RTK and cleanup parsing | shell state, quoted/escaped tokens, display consumers and strict cleanup commands | `bun test pi/extensions/__tests__/rtk-runtime.test.ts pi/extensions/__tests__/plan-cleanup-command.test.ts` |
| Project-vault identity | Git transport/authority/encoding/lookalikes, inherited environment, cache and quoted paths | `bun test pi/extensions/__tests__/project-vault.test.ts` |

These are executable regressions, not instructions to broaden the parser's
supported language or increase review budgets. No deployment occurs here.
