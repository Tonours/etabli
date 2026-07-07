# Implemented: Source-grounded answer quality loop

## Metadata
- Archived: 2026-07-07
- Source plan: Source-grounded answer quality loop
- Status: IMPLEMENTED
- Etabli branch / sha: `main` / `f7f3e26`
- obvault branch / sha: `main` / `0d10684`
- Commit / branch: uncommitted local changes in both repos
- Event ledger: `.workflow/source-grounded-answer-quality/events.jsonl`

## Outcome
- Added `workflow/answer-quality.md` as the shared Etabli answer-quality
  contract.
- Added `docs/source-grounded-answer-quality-research.md` as the sourced
  research explainer connecting external findings to `etabli` and `obvault`.
- Wired the contract into `workflow/spec.md` and
  `tests/workflow-docs-smoke.sh`.
- Added `obvault/kb/source-grounded-answer-quality.md` as a durable synthesis
  note.
- Linked the new obvault note from `kb/_index.md`,
  `ref/second-brain-operating-model.md`, `ref/current-work.md`, and
  `_meta/refresh-kb.sh agent-prompt`.

## Context
- The user goal is broader than this slice: analyze `etabli`, analyze
  `obvault`, research external practice, and make answers quality/effectiveness
  "10/10".
- This slice implements the first durable quality gate. It does not prove every
  future response is objectively perfect.
- `obvault` had an existing local dirty second-brain slice before this work.
  The new edits are additive and preserve that slice.
- Brave Search was unavailable because `BRAVE_API_KEY` was not set, so web
  research used live browsing.

## Decisions

### Define "10/10" as a gate, not a guarantee
- Context: a literal guarantee would be theater without an eval set and human
  calibration.
- Choice: encode a quality gate around intent, sources, grounding, specificity,
  completeness, efficiency, actionability, uncertainty, safety, and final review.
- Rejected options: claim every answer is perfect; add a fake automated score.
- Rationale: the researched literature points to retrieval, critique, and eval
  loops, not prose promises.
- Consequences: future work can turn this gate into eval datasets or trace
  graders when enough examples exist.

### Keep Etabli as the control plane and obvault as the memory layer
- Context: Etabli owns workflow contracts and smoke checks; obvault owns durable
  sourced memory.
- Choice: add the operative contract to `workflow/answer-quality.md`, then add a
  linked obvault synthesis note for query-time memory.
- Rejected options: duplicate the same quality prose across every adapter;
  store only a chat summary in obvault.
- Rationale: shared contracts keep adapter token load lower and obvault remains
  a compiled wiki.
- Consequences: answer quality is discoverable from both the workflow and the
  second brain.

### Do not install retrieval/vector/graph tooling yet
- Context: external research supports contextual retrieval and GraphRAG for
  larger or global corpus questions.
- Choice: document the upgrade path but keep current tooling to `rg`, strict
  Markdown, links, and validation.
- Rejected options: install qmd now; create GraphRAG indexes now.
- Rationale: no measured retrieval failure has been shown yet.
- Consequences: lower moving parts; next retrieval upgrade should start from a
  failing query or eval case.

## Accepted Drift
- Original plan/spec: use Brave Search through the local skill.
- Implemented reality: Brave Search was blocked by missing `BRAVE_API_KEY`; live
  web browsing was used instead.
- Why accepted: the user explicitly requested internet research, and the
  resulting sources are preserved in the research artifact and KB note.

- Original plan/spec: final autonomous review should be fresh-context when
  available and authorized.
- Implemented reality: no subagent delegation was explicitly authorized in this
  turn, so a same-model local diff review was recorded.
- Why accepted: this was a docs/contract slice, focused checks passed, and the
  overall user goal remains active rather than marked complete.

## Validation Evidence
- command: `bash tests/workflow-docs-smoke.sh`
  - result: passed; `workflow docs smoke test: ok`
- command: `scripts/research-proof-check workflow/answer-quality.md`
  - result: passed; `research proof check: ok`
- command: `scripts/research-proof-check docs/source-grounded-answer-quality-research.md`
  - result: passed; `research proof check: ok`
- command: `git diff --check` in `etabli`
  - result: passed with no output
- command: `bash -n _meta/*.sh` in `obvault`
  - result: passed with no output
- command: `_meta/validate-kb.sh` in `obvault`
  - result: passed; `validate-kb: ok`
- command: `_meta/refresh-kb.sh status` in `obvault`
  - result: passed; `kb notes: 5`; `ref notes: 3`; `docs files: 69`
- command: `_meta/refresh-kb.sh query "source-grounded"` in `obvault`
  - result: passed; returned the new note and related entrypoints
- command: `scripts/research-proof-check /Volumes/Crucial/work/obvault/kb/source-grounded-answer-quality.md`
  - result: passed; `research proof check: ok`
- command: secret/raw transcript scan over the new Etabli and obvault quality
  docs
  - result: passed with no matches
- command: `git diff --check` in `obvault`
  - result: passed with no output

## Follow-up State
- Remaining risks:
  - The broader goal is not complete; this slice creates the quality contract
    and durable memory, but does not yet build eval datasets or trace graders.
  - No commit or push was performed for this slice.
  - `obvault` still has the broader pre-existing dirty second-brain slice.
- Parking lot:
  - Create representative answer-quality eval cases from real future misses.
  - Add trace/dataset grading only after there are examples worth grading.
  - Consider qmd/contextual retrieval only after a measured retrieval failure.
- Superseded docs/specs: none.
- Next links:
  - `workflow/answer-quality.md`
  - `docs/source-grounded-answer-quality-research.md`
  - `/Volumes/Crucial/work/obvault/kb/source-grounded-answer-quality.md`
