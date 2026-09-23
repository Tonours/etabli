---
status: accepted
date: 2026-09-23
tags: [harness-eval, evaluator, self-improvement]
affected_components: [scripts/lib/etabli-harness-grade.sh, scripts/lib/etabli-harness-run-v2.sh, scripts/etabli-harness-eval-v2, tests/fixtures/harness-v2, tests/etabli-harness-eval-v2-smoke.sh]
---

# Split harness-eval v2 into a hashed grading contract and an unhashed runner

Harness-eval v2 (evaluator binary-final-state-v2) pins the SHA-256 of scripts/lib/etabli-harness-grade.sh alone: the review-transcript parser, the declarative oracle vocabulary, the grader, baseline and HEAD pinning and the spawn-evidence producers. Runner configuration (grok-4.7, glm-5.3, effort, timeouts) and worktree preparation live in the unhashed scripts/lib/etabli-harness-run-v2.sh, so model and performance edits no longer force a re-pin, while fixture edits still surface through a per-row task_sha. v1 stays byte-identical because frozen evaluator bundles fingerprint it, and re-pinning them would falsify recorded evidence.

v1 and v2 rows are not comparable: they differ in manifest_sha, model_requested, the new evaluator_id and task_sha, and in two grading deltas. First, a verdict on an unterminated last line now parses; v1 rejected it, so this is a loosening on the GO positive control. Second, every isolation claim now requires runner: pi-child, which review-go-forbidden-empty-deciding did not require in v1. The hash protects the judgment, not the sandbox: the runner still controls the process that produces the transcript and the worktree, so runner edits remain reviewed code changes.
