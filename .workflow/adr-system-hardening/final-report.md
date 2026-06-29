# Final Report: ADR system hardening

## Outcome
Implemented a lightweight hardening pass for the Claude ADR system:

- `/adr` now inventories existing ADRs, reads recent and relevant candidates,
  and must cite local files before proposing a supersession.
- ADR frontmatter stays minimal but supports optional `supersedes`,
  `superseded_by`, `tags`, and `affected_components`.
- `scripts/validate-adrs` provides deterministic checks for duplicate numbers,
  broken supersession relationships, malformed relation refs, empty retrieval
  fields, and duplicate `CLAUDE.md` index markers.
- The ADR Stop hook avoids broad substring matches for `auth` and
  `middleware`, and sees files inside untracked directories.
- Tests cover the new validator and hook false-positive/folder visibility
  behavior.

## Accepted Results
- Matt Pocock's ADR style is the right base: short by default, optional sections
  only when they pay for themselves.
- `adr-tools` is the right supersession precedent: new ADR plus bidirectional
  update to the old ADR.
- MADR is useful for optional metadata inspiration, not as the default template.
- Recent ADR/LLM research supports small grounded context windows and retrieval
  from existing ADRs, not blind prompting.
- Shohan's concern is handled by local candidate discovery and cited
  supersession analysis.
- Brian's comments are handled as follows:
  - retrieval fields added as optional metadata
  - duplicate numbering cannot be prevented in parallel branches, but is now
    detected by `scripts/validate-adrs`
  - `auth`/`middleware` regex false positives reduced
  - supersession and gap behavior covered by deterministic validator tests and
    documented in the manual e2e test
  - hidden `CLAUDE.md` index documented as non-runtime retrieval

## Rejected Results
- No vector DB or MCP retrieval layer. The evidence did not justify the
  operational weight.
- No mandatory MADR-style template. It would make the common case worse.
- No automatic mutation of old ADRs without a grounded candidate and approval.
- No claim that `max(existing)+1` is collision-proof. It is not.

## Conflicts Resolved
Brian's `last_assistant_message` concern was not implemented as a bug fix here:
the existing hook still supports transcript fallback, and the main verified
production risk found during testing was actually untracked directory
compaction. That was fixed with `--untracked-files=all`.

## Verification Evidence
- `node scripts/validate-adrs` -> `ADR validation ok: no docs/adr directory.`
- `bash tests/adr-validate-smoke.sh` -> `adr validator smoke test: ok`
- `bash tests/adr-hook-smoke.sh` -> `adr hook smoke test: ok`
- `node --check scripts/validate-adrs && node --check claude/hooks/detect-adr-signal.mjs` -> pass
- `bash -n tests/adr-validate-smoke.sh && bash -n tests/adr-hook-smoke.sh && bash -n tests/adr-skill-e2e.sh` -> pass
- `bash tests/claude-hooks-smoke.sh` -> `claude hooks smoke test: ok`
- `git diff --check` -> pass
- `python3 /Users/tonours/.codex/skills/codex-dynamic-workflows/scripts/verify_workflow.py .workflow/adr-system-hardening` -> pass after adding packet files

## Remaining Risks
- The manual `tests/adr-skill-e2e.sh` was updated but not executed because it
  runs real `claude -p` calls and has an explicit cost/API dependency.
- Supersession discovery remains LLM-assisted. The guardrail is citation and
  validation, not mathematical certainty.
- Cross-branch duplicate ADR numbers are detected after the fact; preventing
  them would require centralized allocation or accepting non-sequential IDs,
  both rejected as too heavy for now.

## Reusable Follow-up
- Consider wiring `bash tests/adr-validate-smoke.sh` into CI once the broader
  script-test workflow is cleaned up.
- If `docs/adr/` grows large enough that keyword/tag/component matching misses
  real supersessions, revisit lightweight retrieval. Start with local lexical
  search before embeddings.
