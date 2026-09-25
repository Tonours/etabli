# Implemented: guards actually active (Pi DMI + Claude hooks wiring)

## Metadata
- Archived: 2026-09-24
- Source plan: `PLAN.md` — Gardes actives (DMI Pi + merge/vérification hooks Claude)
- Source plan SHA-256: `add9e1d1e0d2aca575e841be8ba2e0f0d450828261cb7829080577b0c57af469`
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `main` (base `7d53652`)
- Workflow initiative: guards-active

## Outcome
- **Pi skills hidden from the model prompt without breaking `/skill:name`.** 11 repo skills carry `disable-model-invocation: true` (versioned in `pi/skills/`); installed/package skills are stamped by `scripts/pi-dmi-stamp` (discover-by-name, repo-realpath skip, absent tolerated). Deny (`!name`) is NOT used for hiding: deny unloads `/skill:name`, DMI keeps expansion (proven in Pi source + live probes).
- **Claude hooks merged and verified.** `scripts/claude-hooks-merge` adds the 5 fragment entries to live `~/.claude/settings.json` (user hooks preserved, backup before write, refuse-before-write on conflict); `scripts/claude-hooks-check` verifies wiring (identical full hook object), refuses `disableAllHooks`, and requires every hook script to be a regular file under `~/.claude/hooks/`.
- **Load check fails closed.** `scripts/pi-skill-load-check` refuses any `*.bak.*` at any depth under the skill roots (Pi loads them; measured), fails fast on non-directory roots, keeps absent-deny tolerance for the pinned deny-list.
- **One manifest row.** `workflow/runtime/agentic-infra-checks.tsv` gains a `core shell-docs guards-active` row running `tests/guards-active-smoke.sh` with independent markers, a CI guard, and fixture + live assertions.
- **Protected skills stay visible.** `alambic-brain`, `alambic-obvault`, `typesafe-ai`: no deny entry, no DMI flag (asserted at archive time).

## Context
- Roadmap slice 2 in `docs/research/20260924-skill-reliability-token-economy.md` §12 (guards actually active); follows tranche 1 (`docs/plan/20260924-session-hygiene.md`).
- Pi discovery, measured via `HOME`-override fixture dumps (zero live mutation): `.pi` root wins over `.agents`; `*.bak.*` dirs load as real skills; nested `SKILL.md` files load; same-root top-level beats nested; cross-root nested `.pi` backup shadows top-level `.agents`.
- Claude hooks reference (code.claude.com): `async: true` hooks cannot block or control behavior; `disableAllHooks: true` disables all hooks.
- The `~/work/etabli -> /Volumes/Crucial/work/etabli` symlink exists on this machine, arming the logical-vs-real path bug class.

## Decisions
### DMI everywhere, zero deny-add, zero filter edits
- Context: v1 hid skills with deny entries.
- Choice: `disable-model-invocation` for hiding; deny-list untouched except the pinned import.
- Rejected options: deny-based hiding (breaks `/skill:name`, proven by `ideas` vs `fix-ci` probes).
- Rationale: hiding must not remove the skill surface.
- Consequences: stamp tooling owns installed/package skills; repo flags owned in `pi/skills/`.

### Fail closed on stale backups, recursively
- Context: deploy backups (`*.bak.<ts>`) land inside skill roots; Pi loads them.
- Choice: recursive `find -H -name '*.bak.*'` pre-scan, exit 1 with quarantine remedy; fail fast on non-directory roots; fail closed on scan errors.
- Rejected options: first-level glob (nested escape measured), silent exclusion (masked a live collision).
- Rationale: a guard that stays green while Pi serves stale content is worse than red.
- Consequences: future deploy backups red the check until quarantined (message says how).

### Full-object hook identity, clash before skip
- Context: 5-field identity ignored behavioral fields (`async`); exact-match `continue` skipped clash detection.
- Choice: identity = event + matcher + stable-stringified full hook object (shared lib); clash scan runs before the identical-skip; `disableAllHooks: true` refused/failed.
- Rejected options: field enumeration (drifts with new hook options).
- Rationale: any parameter difference, present or future, is a conflict.
- Consequences: live settings written by the older merge stay compatible when objects are identical; any extra field forces explicit reconciliation.

### Document-level stamp with verification
- Context: line surgery duplicated quoted keys and dedented nested homonyms, exit 0.
- Choice: yaml `Document.set` on the top-level key + reparse verification (flag true AND all other keys unchanged) + fail-closed write; atomic tmp+rename on the realpath with mode preserved and ownership preserved-or-refused.
- Rejected options: regex surgery (corrupts valid YAML).
- Rationale: the stamp must never alter anything but the flag.
- Consequences: sequence-head frontmatter fails loudly instead of corrupting.

### Three declared budget overruns
- Context: plan allowed 1 implementation pass + 2 review↔fix rounds; mandatory high-risk adversary reviews returned BLOCK, BLOCK, HOLD, HOLD.
- Choice: fix rounds 3, 4, 5 with overrun declared in `PLAN.md` each time.
- Rejected options: shipping with known HIGHs to respect the budget line.
- Rationale: a BLOCK/HOLD from a mandatory high-risk review cannot be shipped; all fixes were mechanical and fixture-covered.
- Consequences: tranche 2 cost ~5 review rounds; tranches 3-8 keep the same bar per user request.

## Accepted Drift
- `claude-skill-load-check` adjacent reds (37 stale map keys + herdr keeper): pre-existing, tranche 7 surface, not caused by the 11 DMI flags.
- macbook-work rollout stays manual (one-liner only, no ssh mutation per user constraint).
- Non-`.bak` staleness (two same-name live skills, winning-path verification): tranche 7.
- Ownership-refusal branch uncovered by fixtures (needs a second user); crash-mid-write cleanup unverified portably (stale tmp unlinked at next write).
- npm reinstall wipes package stamps (re-stamp needed); symlinked-repo-parent case fixed via realpath + `--repo` (was banked, then concretized by the existing alias).

## Validation Evidence
- command: `bash tests/guards-active-smoke.sh` on 4 cold/live configurations (empty `LIVE_HOME`, `CI=true`, full live `$HOME`, plus `bash tests/pi-skill-load-check-smoke.sh`)
  - result: all PASS (fixtures + live: stamp `stamped=0 ok=27 repo-skipped=4 absent=0 failed=0`, hooks `ok, all fragment hooks wired`)
- command: `scripts/verify-agentic-infra core`
  - result: 23/23 (includes guards-active row + skill-lock)
- command: `bun test pi/extensions/__tests__/`
  - result: 349 tests pass, 0 fail
- command: native Pi dump (`pi -p --no-session --offline` measurement extension)
  - result: ok, 6594 chars, block under gate; DMI 11/11 flags, 11/11 removals detected
- command: `HOME`-override Pi probes (discovery order, `.bak` loading, nesting)
  - result: `.pi` wins; `*.bak.*` loads; nested loads; top-level wins same-root; nested `.pi` wins cross-root
- Reviews:
  - Spec + Logic hunters: round 1 BLOCK→folded, round 2 GO WITH NOTES, round 3 GO WITH NOTES (1 banked LOW, later fixed);
  - code-diff adversary (Codex): patch3 BLOCK (2 HIGH + 6 MEDIUM + 1 LOW) → patch4 BLOCK (1 HIGH nested) → patch5 GO WITH NOTES (HIGH closed + 1 LOW fixed);
  - thermo-nuclear equivalent (Codex, skill disabled to the agent): patch6 HOLD (1 HIGH + 2 MEDIUM) → patch7 HOLD (1 HIGH dir-gate + 1 MEDIUM metadata) → patch8 SHIP WITH NOTES, no new findings.
- Final patch: `sha 3a5afe31495952b4af393a8181ace87543e6c48cd061ad56186dd931eb1b67c7` (23 files).

## Follow-up State
- Remaining risks:
  - behaviour on macbook-work is `not verified` until pulled and used there;
  - hook scripts are existence-checked, not content-hashed (malicious script content is out of scope).
- Parking lot:
  - winning-path verification per skill (tranche 7);
  - npm reinstall re-stamp automation;
  - second-user fixture for the ownership-refusal branch.
- Superseded docs/specs: none.
- Next links:
  - tranche 3 (contrat Pi + ledger discipliné) — next in the roadmap chain, same per-tranche bar (plan-implement + code-review + thermo-nuclear);
  - ledger `.workflow/guards-active/events.jsonl` (closed).
