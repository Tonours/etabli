# Skill Evaluation Contract

Use this contract to compare one baseline skill or agent procedure with one
candidate over the same frozen task population. It is a promotion gate, not a
prompt-quality opinion.

## Required Evidence

- A versioned manifest with one stable ID, visibility, evaluator SHA-256, and
  exact task IDs split into `held_in`, `held_out`, and `safety`. New strict
  manifests use `schema_version: 2`, declare `strict: true`, and list every
  runner/library/oracle file in an evaluator bundle with its SHA-256. The
  evaluator entry path must appear exactly once in that bundle and its own
  SHA-256 must match the file bytes.
- A frozen objective: `quality` (`held_in_passed`), `efficiency`
  (`total_tokens` or `elapsed_ms`), or `reliability` (`success_rate`), with its
  direction and positive minimum delta. This makes quality, efficiency, or reliability
  explicit before comparison. Efficiency/reliability objectives also freeze
  the measurement population; both results bind it with the same metric and
  repeated sample count.
- Baseline and candidate artifact fingerprints computed from the exact skill
  directories used for their runs.
- One boolean final-state outcome for every manifest task in both runs.
- The same manifest SHA-256 and evaluator SHA-256 in both results. Strict
  results also carry the computed evaluator-bundle SHA-256; a stale bundle or
  manifest is non-comparable, never a legacy fallback.

Tracked fixtures are `frozen_public`: they detect regressions but are readable
by the candidate and are not confidentially isolated. Use
`external_isolated` only when an evaluator outside the editable worktree owns
and seals the population.

## Decision Rule

Run:

```bash
scripts/skill-eval fingerprint <skill-directory>
scripts/skill-eval compare --manifest <manifest.json> \
  --baseline <baseline.json> --candidate <candidate.json> \
  --baseline-artifact <baseline-snapshot-directory> \
  --candidate-artifact <candidate-directory> \
  [--evaluator-root <bundle-root>]
```

The comparator recomputes both fingerprints from those directories and rejects
reported fingerprints that do not match. Keep an immutable baseline snapshot;
never point both arguments at a mutable current skill directory.

The comparison is non-comparable when the manifest/evaluator hashes differ,
task IDs or splits differ, outcomes are missing/duplicated, or fingerprints are
invalid. Do not average non-comparable runs.

Accept only when all are true:

1. candidate and baseline artifact fingerprints differ;
2. the frozen objective is met: quality strictly improves held-in passes;
   efficiency lowers its metric; or reliability raises success rate;
3. candidate held-out passes are not lower;
4. candidate safety passes are not lower;
5. no task that passed in the baseline fails in the candidate, including
   held-out and safety transitions; and
6. the baseline has no failed safety case; efficiency and reliability also
   preserve held-in pass count. An incomplete safety baseline is
   rejected until resolved or explicitly adjudicated outside this deterministic
   gate.

Otherwise reject and retain the reasons as negative evidence. Never weaken a
grader, rename a failing task, move a task between splits, or remove a safety
case to obtain acceptance.

## Reporting

Report the manifest ID/SHA, objective, visibility, evaluator and (for strict manifests)
bundle SHA, both artifact fingerprints, pass/total by split, per-task
regressions, verdict, and every rejection reason. A green
synthetic smoke proves only comparator behavior; it does not prove that a real
skill improved.

Report a real comparable run in the handoff with the same population on both
sides. Do not record `harness_validation_completed`: the
`autonomous-completed-strict` profile refuses it since the comparator chain was
removed.
