# Implemented: Portable PLAN guard escape hatches

## Metadata

- Archived: 2026-08-05
- Source plan: `PLAN.md` — Make abandoned PLAN guard escape hatches portable and usable
- Source plan SHA-256: `c86deda51b2090e538425a145e8e7c7120221e15159596206e2fa5ff43b38057`
- Status: IMPLEMENTED
- Branch: `main`

## Outcome

- Root-plan paths are resolved against the event/project cwd, including relative Pi tool paths.
- READY check-freeze reconstructs singular and batched host edits, including Pi `edits[].oldText/newText`, and fails closed on unmatched or ambiguous edits.
- Scaffolded projects receive the canonical executable `scripts/plan-cleanup`; the scaffold smoke proves DRAFT discard and discarded-record creation end to end.
- Pre-READY shell inspection accepts bounded `cd`, `test`, and listing-only Git forms while denying stateful Git commands, interpreter execution, output flags, combined short write flags, command substitution, and mutation after `cd`.
- Synthetic Postmark redaction fixtures preserve their runtime values without triggering blocking secret scanners.

## Context

- `claude/hooks/workflow-router-lib.mjs`: shared Pi/Claude mutation guard and check-freeze reconstruction.
- `scripts/deploy-workflow`: self-contained project workflow deployment manifest.
- `tests/dual-runtime-guard-matrix-smoke.sh`: held-in positive and adversarial guard corpus.
- `tests/workflow-scaffold-smoke.sh`: deployed cleanup executable and lifecycle proof.

## Decisions

### Preserve fail-closed unknown-shell behavior

- Context: the prior allowlist blocked common inspection forms, but reverting to mutation regexes would reopen interpreter and tool bypasses.
- Choice: add only explicit proven-read-only forms and keep unknown commands denied with honest wording.
- Rejected options: allow arbitrary Bash before READY; classify unknown commands as non-mutating.
- Rationale: fixes usability without weakening the implementation gate.
- Consequences: some uncommon read-only Git flag combinations remain conservatively denied.

### Deploy one canonical cleanup implementation

- Context: the guard advertised `scripts/plan-cleanup --discard`, but deployed projects did not receive that helper.
- Choice: deploy the existing canonical script through `scripts/deploy-workflow`.
- Rejected options: duplicate the script under templates; allow raw `rm PLAN.md`.
- Rationale: keeps discard auditable and avoids implementation drift.
- Consequences: existing scaffolded projects receive the helper on their next workflow redeployment.

### Bind check-freeze to real host payloads

- Context: Pi's actual edit payload is batched and uses `oldText/newText`; the prior reconstruction expected Claude-style keys.
- Choice: normalize singular and batched edit shapes, apply unique matches in order, and return reconstruction failure for malformed/unmatched edits.
- Rejected options: skip check-freeze for unknown payloads.
- Rationale: restores editability while preserving fail-closed weakening checks.
- Consequences: ambiguous or overlapping edits are conservatively denied.

## Accepted Drift

- Original plan/spec: use the focused guard and scaffold files only.
- Implemented reality: `pi/extensions/__tests__/filter-output.test.ts` also expresses two synthetic Postmark fixtures compositionally.
- Why accepted: fresh diagnostics flagged the literal synthetic fixtures as blocking secrets; the runtime values and redaction coverage remain unchanged, and all filter-output tests pass.

- Original plan/spec: `scripts/verify-agentic-infra core` was expected as a green held-out check.
- Implemented reality: it exits at `pi-audit` on six current transitive advisories; decomposed relevant suites were run directly.
- Why accepted: no dependency or lockfile changed in this slice, and broad dependency updates would be unrelated scope expansion.

## Validation Evidence

- `bash tests/dual-runtime-guard-matrix-smoke.sh`
  - result: PASS
- `bash tests/workflow-scaffold-smoke.sh`
  - result: PASS
- `bash tests/plan-cleanup-smoke.sh && bash tests/claude-hooks-smoke.sh`
  - result: PASS
- `cd pi && bun test ./extensions/__tests__/*.test.ts`
  - result: PASS — 192 tests, 0 failures
- `bash -n scripts/deploy-workflow tests/claude-hooks-smoke.sh tests/dual-runtime-guard-matrix-smoke.sh tests/workflow-scaffold-smoke.sh`
  - result: PASS
- `git diff --check`
  - result: PASS
- LSP diagnostics on changed JavaScript/TypeScript files
  - result: 0 diagnostics
- Pi lens diagnostics on changed files
  - result: 0 unresolved findings
- Fresh cross-model diff reviews via read-only Claude CLI
  - result: `GO WITH NOTES`; no blocker; actionable guard findings folded and tests rerun
- `scripts/verify-agentic-infra core`
  - result: known unrelated FAIL at `pi-audit` — 2 high and 4 moderate transitive advisories
- `scripts/verify-agentic-infra shell-docs`
  - result: relevant guard suites PASS, then known unrelated FAIL because tracked `scripts/deploy-agent-workflow` mode is `100644`

## Follow-up State

- Remaining risks: case-insensitive filesystem aliases are not inode-canonicalized; a cross-platform realpath fixture is required before changing this safely.
- Parking lot: dependency advisories and the unrelated `scripts/deploy-agent-workflow` executable-mode defect.
- Unrelated work preserved: existing `tmux.conf` modification was not touched.
- Next links: `workflow/plan-archive.md`, `workflow/agent-quick-card.md`.
