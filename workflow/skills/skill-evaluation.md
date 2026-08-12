# Skill Evaluation Contract

Use this contract to compare one baseline skill or agent procedure with one
candidate over the same frozen task population. It is a promotion gate, not a
prompt-quality opinion.

## Required Evidence

- A versioned manifest with one stable ID, visibility, evaluator SHA-256, and
  exact task IDs split into `held_in`, `held_out`, and `safety`.
- Baseline and candidate artifact fingerprints computed from the exact skill
  directories used for their runs.
- One boolean final-state outcome for every manifest task in both runs.
- The same manifest SHA-256 and evaluator SHA-256 in both results.

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
  --candidate-artifact <candidate-directory>
```

The comparator recomputes both fingerprints from those directories and rejects
reported fingerprints that do not match. Keep an immutable baseline snapshot;
never point both arguments at a mutable current skill directory.

The comparison is non-comparable when the manifest/evaluator hashes differ,
task IDs or splits differ, outcomes are missing/duplicated, or fingerprints are
invalid. Do not average non-comparable runs.

Accept only when all are true:

1. candidate and baseline artifact fingerprints differ;
2. candidate held-in passes strictly exceed baseline held-in passes;
3. candidate held-out passes are not lower;
4. candidate safety passes are not lower.

Otherwise reject and retain the reasons as negative evidence. Never weaken a
grader, rename a failing task, move a task between splits, or remove a safety
case to obtain acceptance.

## Reporting

Report the manifest ID/SHA, visibility, evaluator SHA, both artifact
fingerprints, pass/total by split, verdict, and every rejection reason. A green
synthetic smoke proves only comparator behavior; it does not prove that a real
skill improved.

For a real comparable self-improvement run, record
`harness_validation_completed` with the same population on both sides and the
candidate/evaluator fingerprints required by the strict ledger profile.
