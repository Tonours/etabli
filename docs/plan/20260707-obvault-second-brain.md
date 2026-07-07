# Implemented: obvault strict second brain

## Metadata
- Archived: 2026-07-07
- Source plan: Local obvault second-brain setup
- Status: IMPLEMENTED
- Etabli branch / sha: `main` / `0d6afa5`
- obvault branch / sha: `main` / `0d10684`
- Event ledger: `.workflow/obvault-second-brain/events.jsonl`

## Outcome
- Created local compatibility path `/Users/tonours/work/obvault` -> `/Volumes/Crucial/work/obvault`.
- Reworked `obvault` from a personal lab notebook into a strict second-brain contract.
- Added local KB hygiene and query helpers:
  - `/Volumes/Crucial/work/obvault/_meta/validate-kb.sh`
  - `/Volumes/Crucial/work/obvault/_meta/refresh-kb.sh`
- Made `_meta/cron-run.sh` resolve its repo path from the script location and fail closed on KB validation.
- Added source-backed research at `/Volumes/Crucial/work/obvault/docs/second-brain-research.md`.
- Seeded durable notes:
  - `kb/llm-wiki-second-brain-architecture.md`
  - `kb/obvault-agent-memory-loop.md`
  - `kb/second-brain-source-capture.md`
  - `ref/second-brain-operating-model.md`
- Updated `kb/_index.md` and `ref/current-work.md`.
- Rerouted active local Codex automation `daily-obvault-conversation-kb` to write durable findings directly to obvault, with no commit/push/deploy/external write-back.

## Context
- `etabli` already routed durable knowledge to `~/work/obvault`, but the local path did not exist.
- The actual obvault repo is `/Volumes/Crucial/work/obvault`.
- Karpathy's LLM-wiki pattern maps cleanly onto `docs/` as sources, `kb/` as compiled wiki, and `CLAUDE.md`/`AGENTS.md` as schema.
- Existing staged Obsidian research notes remain source material, but live Obsidian folders were not mutated.

## Decisions
### Local-first second brain
- Context: The user asked to put the setup in place and make obvault the second brain.
- Choice: Implement the first slice entirely locally.
- Rejected options: Oz/cloud automation, Hubble install, Obsidian plugin install, all-note import.
- Rationale: Those options require external accounts, installs, or broad personal-note mutation.
- Consequences: The system is usable now; cloud/plugin work remains optional.

### Direct obvault automation
- Context: The daily automation previously wrote staged Obsidian research notes only.
- Choice: Route durable future findings directly into obvault `kb/`, capped at 3 new notes per run and validated by `_meta/validate-kb.sh`.
- Rejected options: Keep obvault read-only forever; auto-commit/push from automation.
- Rationale: A second brain must self-update locally, but external writes stay behind explicit consent.
- Consequences: Future daily runs can update local KB files; user still reviews/commits manually.

### Mechanical hygiene before scale
- Context: qmd/vector search is useful later, but obvault is still small.
- Choice: Add shell validation and `rg`/`grep` search fallback first.
- Rejected options: Install qmd and model cache now.
- Rationale: Plain Markdown plus validation gives immediate value with fewer moving parts.
- Consequences: Optional qmd setup can be revisited if search quality becomes a bottleneck.

## Accepted Drift
- Original plan/spec: Validate active automation TOML with Python `tomllib`.
- Implemented reality: The local Python runtime lacked `tomllib`; replaced with targeted prompt smoke assertions.
- Why accepted: The replacement validates the fields and policy strings that matter for this automation.

- Original plan/spec: Run `git diff --check` for obvault from the Etabli repo.
- Implemented reality: Ran `git diff --check` from each repo root.
- Why accepted: Git correctly rejects paths outside the current repo; per-repo checks are the right validation.

- Original plan/spec: `refresh-kb.sh query` could use qmd when present.
- Implemented reality: Added qmd -> rg -> grep fallback after review found qmd could be installed but unconfigured.
- Why accepted: It makes local query reliable without requiring qmd setup.

## Validation Evidence
- `bash -n /Volumes/Crucial/work/obvault/_meta/*.sh`
  - result: pass
- `/Volumes/Crucial/work/obvault/_meta/validate-kb.sh`
  - result: `validate-kb: ok`
- `/Volumes/Crucial/work/obvault/_meta/refresh-kb.sh status`
  - result: `validate-kb: ok`; `kb notes: 4`; `ref notes: 3`; `docs files: 69`
- `/Volumes/Crucial/work/obvault/_meta/refresh-kb.sh query "second brain"`
  - result: returned expected matches from `README.md`, `CLAUDE.md`, `kb/`, `ref/`, and `docs/`
- `scripts/research-proof-check /Volumes/Crucial/work/obvault/docs/second-brain-research.md`
  - result: `research proof check: ok`
- `scripts/workflow-event validate obvault-second-brain`
  - result: `30 events, ok` before archive event
- `bash tests/workflow-docs-smoke.sh`
  - result: `workflow docs smoke test: ok`
- automation prompt smoke
  - result: `automation prompt smoke: ok`
- secret/raw transcript path grep over obvault `kb/`, `ref/`, and `docs/second-brain-research.md`
  - result: no matches
- `git diff --check` in obvault
  - result: pass
- `git diff --check` in etabli
  - result: pass
- path resolution
  - result: `/Users/tonours/work/obvault` resolves to `/Volumes/Crucial/work/obvault`

## Review Evidence
- Plan adversary accepted one finding: active Codex automation had to be routed to obvault directly.
- Same-model local diff review found one issue: `refresh-kb.sh query` needed fallback when qmd is present but unusable.
- Adversary diff verdict: `GO` after the qmd fallback fix and final validation.
- No fresh-context sidecar reviewer was available in this runtime; the tool search surfaced GitHub PR tools only, not a local read-only reviewer.

## Follow-up State
- Remaining risks:
  - The next scheduled automation run should be reviewed before committing its first direct KB changes.
  - qmd remains optional and uninstalled; revisit only when plain search is insufficient.
- Parking lot:
  - Optional Obsidian Web Clipper template.
  - Optional qmd install/indexing.
  - Optional cloud runner/Oz setup after explicit credential/account approval.
- Superseded docs/specs:
  - Previous obvault framing as "personal lab notebook" is superseded by the strict second-brain contract.
- Next links:
  - `/Volumes/Crucial/work/obvault/ref/second-brain-operating-model.md`
  - `/Volumes/Crucial/work/obvault/kb/_index.md`
