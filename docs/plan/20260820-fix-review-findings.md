# Implemented: close evidence boundaries and runtime quality fallback

## Metadata
- Archived: 2026-08-20
- Source plan: `PLAN.md` — Close evidence-root and runtime-skill resolution findings
- Source plan SHA-256: `66bdd71d2267513ce87d2827f875b523295e05f341fa0747031ace75eddad6ef`
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `refactor/skill-default-load`

## Outcome
- `scripts/evidence-proof` now resolves and confines the target under
  `validate --root` and the observed tree under `capture --cwd` before hashing
  or walking them.
- Terminal target symlinks remain rejected, safe in-root ancestor symlinks stay
  valid, and escaping ancestor symlinks fail closed.
- External capture subjects and predeclared inputs remain supported and have a
  dedicated positive regression fixture.
- Quality and review routing now uses an exposed narrow skill, then local
  sibling evidence, then an explicit `unavailable` / `not run` result.
- Active adapters no longer require inactive generic suites. Mechanical smokes
  resolve every leaf in the Pi routing table, reject inactive-suite names
  independently of Markdown formatting, and prevent non-core Pi CSS routes.
- The untracked zero-byte root artifact `1` was removed.

## Context
- `--cwd` is an execution context, not an authority boundary for the captured
  subject or predeclared input.
- The worktree already contained broad user changes. Only the files recorded in
  `.workflow/fix-review-findings/events.jsonl` belong to this repair run.

## Decisions
### Confine only declared filesystem boundaries
- Context: lexical containment allowed ancestor symlinks to resolve outside a
  validation or observation root.
- Choice: keep the lexical terminal-symlink check, resolve the canonical path,
  enforce realpath containment, and reuse the canonical target in receipt
  validation.
- Rejected options: blanket symlink rejection; treating all capture inputs as
  children of `--cwd`.
- Rationale: safe in-root indirection remains valid while declared roots fail
  closed.
- Consequences: this is a deterministic validation boundary, not a hostile
  same-UID or TOCTOU security guarantee.

### Route quality through capabilities that are actually exposed
- Context: core contracts referenced optional suites absent from managed active
  surfaces, while Pi-only CSS skills could be named from Pi core adapters.
- Choice: route directly to exposed leaf skills, fall back to local siblings,
  report unavailable explicitly, and derive anti-drift checks from the managed
  catalog and routing table.
- Rejected options: restoring demoted suites; adding default skills; claiming a
  missing convention pass was clean.
- Rationale: the mandatory workflow remains executable without widening the
  default surface.
- Consequences: Claude may still use valid cross-harness CSS skills; Pi core
  adapters may use them only after the catalog promotes them to `pi_core=1`.

## Accepted Drift
- Original plan/spec: the first repair scope did not list `skills-lock.json` or
  a dedicated external-predeclared fixture.
- Implemented reality: the canonical 79-entry lock was regenerated after skill
  edits, and the adversarial review added the external-input and Pi CSS guards.
- Why accepted: both changes are required proof for the original behavior and
  managed-surface criteria; they do not expand the runtime catalog.

## Validation Evidence
- `bash tests/evidence-proof-smoke.sh`
  - result: exit 0; positive and negative realpath boundaries plus external
    subject/predeclared capture passed.
- `bash tests/workflow-docs-smoke.sh`
  - result: exit 0; inactive suites, table-derived leaves, degraded status, and
    non-core Pi CSS routes were checked.
- `cd pi && bun run verify:skills`
  - result: 79 skill hashes verified.
- `scripts/check-fix-symlinks.sh --verbose`
  - result: 0 issues, 0 fixes, 0 unresolved.
- `scripts/verify-agentic-infra full`
  - result: final exit 0; 192 Pi tests, 53/53 router cases, 79 skill hashes, and
    every deterministic smoke group passed.
- `git diff --check HEAD`
  - result: final exit 0.
- Independent same-family code-diff samples
  - result: sample A `/root/final_review` GO; sample B
    `/root/plan_adversary#code-diff-final` GO; no remaining finding.

## Follow-up State
- Remaining risks: cooperative filesystem checks cannot exclude a hostile
  same-UID writer racing between validation and use; no stronger guarantee is
  claimed.
- Parking lot: comparable live runtime-token telemetry and paid live-agent
  evaluation were outside scope, so no efficiency improvement is claimed.
- Superseded docs/specs: none.
- Next links: `.workflow/fix-review-findings/events.jsonl`.
- Publication: no commit, push, PR, deploy, or external write was performed.
