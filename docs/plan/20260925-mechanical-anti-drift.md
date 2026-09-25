# Implemented: Mechanical anti-drift — ref-linter F3, adapter-sync F4, rule-registry + router-parity F13, proof-shadow F14

## Metadata
- Archived: 2026-09-25
- Source plan: `PLAN.md` — Tranche 6 — Anti-dérive mécanique (T6, F3/F4/F13/F14)
- Source plan SHA-256: `9b093689ebef77f420d6b8123e569baff0c7f273e8840c5144abcd5ba828503a`
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `main` (base `3db5e40`)
- Workflow initiative: mechanical-anti-drift

## Outcome
- **AC1 linter F3.** `scripts/workflow-ref-linter` (scaffold/etabli/misplaced targets, pinned backtick regex, fences included, raw-marker exemption, whole-repo misplaced-union rule) + `deploy-workflow --list-files` + fix-or-mark pass (44 `<!-- etabli-only -->` marks in 15 files, 0 FILES additions — all-mark) + `tests/ref-linter-smoke.sh` + /ship gate + marker rule in implementation-loop.
- **AC2 adapters F4.** 21-name recount confirmed + `workflow/runtime/adapter-manifest.json` (MAP: 33 per-file rows — 19 pi + 14 claude — current-bytes sha256, explicit skill→paths map incl. verify→verify-workflow, `external` class for adonisjs-suite + typesafe-ai with recency) + `scripts/workflow-adapter-sync` (stamp + `--check` 4-way + `--update-hashes`) + 33 adapters stamped (pointer paragraph byte-identical per skill) + `tests/adapter-sync-smoke.sh` (12 cases).
- **AC3 registry F13.** Pinned perl census N=12 (runtime-excluded) + `workflow/runtime/rule-registry.tsv` R1–R12 (10×a excerpt-pinned+parity + 2×b presence-pinned, 0 orphans, 0 (c)) + ROUTES anchors in spec + `scripts/workflow-router-parity` (comment-stripped core extraction, 17 spec == 17 core modulo {verify-workflow: verify}, lib re-export + both pi alias sites pinned) + `tests/rule-registry-smoke.sh` (triple invariant + divergence fixtures).
- **AC4 shadow F14.** `claude/hooks/proof-shadow.mjs` (transcript-lib, closed 5-claim list, pinned class→command table, tool_use_id join + is_error:false, evidence-before-claim + strict mtime ordering, CI-green all-conclusions-success over --limit 50, dirty→unverifiable, 200-cap rotation, ledger-or-TMPDIR sink, exit 0 always) wired Stop[2] + `tests/proof-shadow-smoke.sh` (real-envelope, 12 cases incl. tie + rotation + wiring).
- **AC5 wiring.** Core manifest rows ref-linter/adapter-sync/rule-registry/router-parity/proof-shadow, core exactly 31; incident restore (12 tracked files + TSV full-hunks + runner comment); context-budget documented raise (5 surfaces ×1.03).
- **Gates.** Core 31/31; bun 361/361; census diff exit 0, 0 flips (111 ledgers, own OK); freeze attested (no snapshot exists; 2 rationale-logged edits, 0 weakenings); Logic + Spec self-review; Codex T1 BLOCK → 6 fixes → T2 GO WITH NOTES (2/2 tours, 0 overrun); thermo-equivalent via Codex axis B (no distinct structural findings).

## Context
- Roadmap slice: §12 tranche 6, tier standard/high-risk (4 validators + hook wiring + live-settings merge); plan-loop R1 CHALLENGED → R2 CHALLENGED → R3 CHALLENGED → R4 READY.
- Incident fallout (T4-documented unknown-actor deletion): 12 tracked nvim/herdr/codex files + TSV full-hunks + runner comment restored from git (0 bytes invented); nvim/herdr smokes stay red = environmental (nvim/ absent, herdr/ untracked gap awaiting user restore source).
- Pre-existing reds fixed along the way: manifest smoke core pin (T2–T5 rows never pinned) + full/nvim pins (incident-adaptation).
- Live environment writes (documented remediations, reversible): skills-lock rotation (18 hashes + herdr GC per catalog rule), context-budget raise, `claude-hooks-merge` (1 entry + backup), `deploy-agent-workflow --apply` (1 symlink).
- Protected skills stay visible: `alambic-brain`, `alambic-obvault`, `typesafe-ai` (untouched by this tranche).

## Decisions
### F4 sync direction is frontmatter→block (tripwire), not unification
- Context: plan said "frontmatter name/description sync" with per-harness patch keys; Claude descriptions are harness-role-specific (agents/adversary.md sample-role vs pi skill description).
- Choice: GENERATED block snapshots each harness's own frontmatter values; only the pointer paragraph is byte-identical cross-harness; drift = frontmatter edited without re-stamp.
- Rejected options: byte-unifying descriptions across harnesses (would corrupt Claude routing).
- Rationale: "schemas differ, whole-block identity impossible" + only the pointer paragraph required identical; formulation stays per-harness (C3 F4=N).
- Consequences: Codex T1 D1 agreed; --check trips on description edits via regeneration comparison.

### Census excludes workflow/runtime/ as machine data
- Context: registry TSV excerpts self-count (22 with runtime/, 12 without).
- Choice: prune workflow/runtime/ from the pinned census scope; N=12 over the instructional corpus.
- Rejected options: rowing registry excerpts (absurd self-reference), homoglyph-breaking excerpts (dishonest).
- Rationale: same instructional corpus, same N, same triple invariant; clarification, not weakening (no demotion).
- Consequences: Codex T1 D2 agreed; scope note in AC3 + Decision Log rationale.

### CI-green predicate is all-conclusions-success (Codex T1 C2)
- Context: pinned predicate was single-newest-run success; a failed sibling run for the same SHA went unseen.
- Choice: --limit 50, substantiated iff non-empty AND every conclusion == success (strengthening, no demotion).
- Rejected options: keeping --limit 1 (unsound), checking headSha too (deviates from the pinned predicate's exact form).
- Rationale: "CI green" is only honest when no run on the SHA failed; in-progress (null conclusion) correctly unsubstantiated.
- Consequences: mixed-conclusion fixture; reason renamed gh-all-conclusions-success.

### Evidence must precede the claim (Codex T1 C4)
- Context: plan underspecified claim/run temporal order; a later run could substantiate an earlier assertion.
- Choice: run result ts strictly before claim ts (ties fail closed), new no-prior-passing-run reason + claim_ts field (strengthening).
- Rejected options: order-agnostic linkage (lets post-hoc runs justify prior claims).
- Rationale: a completion claim asserts a finished fact; shadow linkage must respect causality.
- Consequences: claim-before-run fixture; existing run-before-claim fixtures unaffected.

### Class-(a) rows are excerpt-pinned too (Codex T1 C5)
- Context: parity compares route names only; a corrupted arbitration sentence still matches the census pattern (count invariant blind to content).
- Choice: presence-pin every row's excerpt ((a) = excerpt + parity, (b) = excerpt only); mechanism column renamed; pin extracted as a function with a corruption fixture (strengthening).
- Rejected options: parity-only (a) (hole stands), dropping the census count (loses the invariant).
- Rationale: the triple invariant counts matches; content needs its own pin per row.
- Consequences: also fixed a latent grep-dash bug (R1 excerpt starts with `-`) + audited all free-text greps.

### Parity strips JS comments before extraction (Codex T1 C1)
- Context: `route:` literals inside comments counted as active routes (latent — none exist today).
- Choice: perl block-strip then sed line-strip before grep; stripping errors can only drop routes (fail-closed); added `|| true` so the 0-extracted fail-closed check is reachable under pipefail.
- Rejected options: JS-parser extraction (heavy for a pinned-pattern gate).
- Rationale: false-clean eliminated; false-red direction preserved.
- Consequences: P7/P8 fixtures (ignored comments / comment-only fails).

## Accepted Drift
- Original plan/spec: AC3 (a) = parity-enforced; AC4 single-run predicate + no claim ordering; union "Claude commands+agents"; one smoke per manifest row.
- Implemented reality: (a) = excerpt-pinned+parity; all-success over --limit 50 + strict claim ordering; union = claude/scopes/shared/{commands,agents} (C3 bug fix); rule-registry + router-parity share one smoke file (two labels, parity cases inside per step-3 text).
- Why accepted: all deltas are strengthenings or bug fixes restoring intent (freeze: rationale-logged, no demotion); Codex T2 confirmed 6/6; row-sharing matches the step text naming a single smoke.

## Validation Evidence
- command: `scripts/verify-agentic-infra core`
  - result: SUMMARY: 31/31 checks passed (post-fix final)
- command: `bun test ./extensions/__tests__/*.test.ts` (cwd pi)
  - result: 361 pass, 0 fail
- command: `scripts/workflow-ledger-census diff` (post-baseline)
  - result: exit 0, 0 flips; mechanical-anti-drift OK (18 QUAR pre-existing, none mine)
- command: `scripts/workflow-context-budget`
  - result: all 7 surfaces ok after reviewed ×1.03 raise (5 surfaces)
- command: the 4 T6 smokes individually
  - result: all PASS (ref-linter, adapter-sync 12 cases, rule-registry incl. P7/P8 + corruption pin, proof-shadow incl. 3b/7b/7c + rotation + wiring)
- command: `scripts/workflow-router-parity` + `scripts/workflow-ref-linter` + `scripts/workflow-adapter-sync --check` (live)
  - result: clean (17 routes) / clean (all targets) / clean (--check)
- command: `tests/agentic-infra-manifest-smoke.sh`
  - result: ok (core membership + exact-31 pin)
- reviews: Logic + Spec self-review (L1–L15, S1–S6); Codex T1 BLOCK (2 HIGH + 4 MED + D1/D2 agree) → tour-1 fold → T2 GO WITH NOTES 6/6 (+ C6-mechanism dispute upheld); thermo-equivalent via Codex axis B, no distinct findings; 2/2 tours, 0 overrun.

## Follow-up State
- Remaining risks: full-profile nvim/herdr smokes red = environmental (nvim/ absent; herdr/ untracked gap still awaiting user restore source per T4); rotated proof-shadow `.1` files unmonitored by design (shadow window).
- Parking lot: staged/unstaged T1–T6 work still uncommitted on main (90+ files; ship decision is the user's); later-tranche promotion reader for proof-shadow.jsonl; alias-named future adapters (documented adapter-sync gap).
- Superseded docs/specs: none (all deltas folded into this archive + Decision Log).
- Next links: roadmap tranche 7 (hygiène des skills), tranche 8 (tokens sous protocole).
