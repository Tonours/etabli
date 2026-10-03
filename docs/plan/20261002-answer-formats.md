# Implemented: choose answer formats for comprehension and review

## Metadata
- Archived: 2026-10-02
- Source plan: `PLAN.md` — Choose answer formats for comprehension and review
- Source plan SHA-256: `7b6b56a9a6078ec1fac887e2f93105764c7939596e765e704dfa525741b6b779`
- Status: IMPLEMENTED
- Commit / branch: `docs/answer-formats`; local changes, not committed
- Workflow initiative: `answer-formats`
- Tier: standard — one contractual documentation surface

## Outcome
- `workflow/answer-quality.md` now selects presentation by the user's question
  and viewing surface, honoring an explicitly requested format.
- Text, tables, diagrams, interactive pages and animation/video have purposes.
  Diagrams have an ASCII fallback; interactivity is useful when exploration
  reduces effort. Rich artifacts carry a short text takeaway and evidence links.
- Short sentences, consistent terms, accessible sources, observations,
  assumptions and limits remain required. Rendering/playback checks are reported
  honestly; visual polish does not establish correctness or comprehension.
- All ten quality duties and four reply shapes remain. Local source-of-truth
  precedence, exact artifact names/results/units, safety and durable-check scope
  are preserved.
- Contract size: 4504 characters; base `8b523a5`: 4505 characters. Context
  ceilings and all helpers are unchanged. This is a static size result, not a
  runtime token-saving or comprehension claim.

## Context
- `workflow/answer-quality.md`: canonical answer/handoff contract.
- `scripts/answer-quality-check`: objective Markdown-marker floor.
- `scripts/answer-quality-eval`: existing positive/negative fixture corpus.
- `workflow/runtime/context-budget.json`: hot instruction ceilings.
- An isolated worktree from `8b523a5425eaa7e10480f3690e9b47fe9a5abd99`
  protects the original checkout's unrelated documents.

## Decisions
### Add advisory presentation guidance in the canonical contract
- Choice: one compact section, with purpose-based choices and explicit-format
  precedence.
- Rationale: the accepted scope concerns restitution. No runtime heuristic,
  renderer, pipeline, skill or dependency is needed.
- Consequence: rich formats still carry the existing evidence and uncertainty
  obligations.

### Offset hot-context growth inside the same document
- Choice: condense repetition while preserving requirements; keep ceilings fixed.
- Rationale: the baseline ship surface had only 8 characters of headroom.
- Consequence: the new section fits with a net reduction of 1 character.

### Freeze concrete manual scenarios
- Choice: review eight fixed stimuli, viewing surfaces and expected/forbidden
  interpretations, with cross-format checks.
- Rationale: marker fixtures cannot establish format usefulness, model adherence
  or reader comprehension.
- Consequence: the manual audit validates the written guidance only.

## Accepted Drift
- The scope stayed on the canonical contract and this post-validation archive.
- The supplementary plan adversary found the manual audit too vague; inputs,
  surfaces and expectations were frozen and independently confirmed.
- T1 Spec and code-diff adversary found weakened local-source precedence.
  Restoring `local source of truth first` resolved the accepted medium finding.
- The canonical archive contract is a valid quality sibling; a suggestion to
  replace it merely because the hot-chain inventory names its template was
  rejected with local source evidence.

## Validation Evidence
- command: `git diff --check`
  - result: passed.
- command: `bash tests/answer-quality-check-smoke.sh`
  - result: passed; existing positive and negative marker checks.
- command: `bash tests/answer-quality-eval-smoke.sh`
  - result: passed, 10/10 cases match expectations.
- command: `scripts/workflow-context-budget`
  - result: passed, 8/8 surfaces within unchanged ceilings.
  - plan-implement: 55489/55699 characters; implement: 50144/50175;
    ship: 83324/83333.
- `.workflow/answer-formats/manual-review.json`
  - result: 8/8 concrete cases reviewed against the actual final contract;
    source SHA-256 `034dbe2b095cfd1dcafaddc1495ddf323bd51388911af7aa3077076f9c6e8b29`.
- `.workflow/answer-formats/quality-report.json`
  - result: pass from parent comparison with `workflow/agent-quick-card.md:28`,
    `workflow/skills/plan-loop.md:14`, `workflow/plan-archive.md:89`.
- Simplification: `simplify: clean`; no new abstraction or duplicate helper.
- Review: T1 findings corrected, T2 GO, final F1 GO; fresh Logic and Spec hunters
  plus cross-family Grok 4.7. Native effective-model records attest the Grok
  route. Codex hunters inherit the configured model; its exact identifier is
  not exposed and is not claimed.
- Deciding-code: n/a — the only implementation path is the document
  `workflow/answer-quality.md`; no runtime behavior changes.
- Final pinned patch SHA-256:
  `031f7397e67e0f8bacd42f1df5a5d4374b823cddf7e8d68f67b8604383f989fc`.
  The source and patch hashes were rechecked before final review closure.
- Original checkout: same `main` branch and HEAD, no tracked edits, 7/7 unrelated
  untracked document hashes identical in `main-before.json` / `main-after.json`.
- Archive, cleanup and terminal completion receipts:
  `.workflow/answer-formats/events.jsonl`.

## Follow-up State
- Remaining risks: agent adherence and reader comprehension are not verified;
  Markdown markers and a content audit do not measure those outcomes.
- Parking lot: a bounded text-versus-HTML comprehension experiment is separate
  work; no experiment or media artifact is delivered in this slice.
- Superseded docs/specs: none.
- Next links: `workflow/answer-quality.md`; branch `docs/answer-formats`.
- Worktree retained for user inspection; no commit, push, PR or deployment.
