# Implemented: Minimal core T1 — router narrowed to 8 core routes, non-core skills shelved in extras/

## Metadata
- Archived: 2026-09-26
- Source plan: `PLAN.md` — Recentrage minimal — Tranche 1 : routeur réduit au cœur + skills hors cœur déplacées dans `extras/`
- Source plan SHA-256: `7968b317416e90e20100ab345a736aeed15038c51b6d5422cb98abc08fa6bd00`
- Status: IMPLEMENTED
- Commit / branch: `refactor/minimal-core-routes` (single tranche commit, based on `main` @ `c40522e`; not pushed)
- Workflow initiative: `minimal-core-t1`

## Outcome
- Router reduced from 17 to 8 routes: `answer`, `ops-stop`, `plan-loop`, `implement`, `plan-implement`, `review`, `verify`, `adversary`. `scripts/workflow-router-parity` → `clean (8 routes)`.
- Work commands (`/linear-work`, `/linear-ticket-create`, `/linear-project-setup`, `/bug-check`, `/pr-review`, `/github-pr-review`, `/pr-qa`, `/sec-pr`, `/ci-fix`, `/spec-guide`) moved to `claude/scopes/work/commands/` — explicit only; slash prompts bypass the classifier, so `/ci-fix` keeps pushing under its own contract.
- Natural-language Linear ticket work → `plan-implement` (`implement` with a READY plan); natural-language Linear ticket creation and bounded `push PR/branch/commits/origin` → `ops-stop`.
- HEAD's read-only predicates (sec-pr, pr-qa, pr-review, bug-check) kept at HEAD's position but return core decisions (`answer` read-only, `review`) — writeAllowed parity with HEAD by construction.
- 29 non-core Pi skills moved to the `extras/skills/` shelf (source `extras`, never deployed); `pi/skills` 49 → 19 entries; `ship` now deployed on Pi.
- Removed: Jev route-capsule runtime (promotion was SHA-bound to the router source) and the runtime skill canary tool with its skill.
- Added `CONTEXT.md` (glossary: Route, Cœur, Commande explicite, Scope, Étagère, Surface) and ADR-0027 (narrows ADR-0007; motive = maintained surface, not tokens).

## Context
- `workflow/runtime/workflow-router-core.mjs`: route ids are `route:` literals; `scripts/workflow-router-parity` pins them to the `workflow/spec.md` ROUTES table.
- `workflow/runtime/skill-surface.tsv` + `scripts/lib/skill-catalog.sh`, `pi/scripts/verify-skills-lock.mjs`, `pi/extensions/lib/semantic-skill-suggestion.mjs`: three source-root resolvers, all taught `extras`.
- `pi/agent/settings.json` local skills must equal the catalog `pi_core=1` set (lock verifier invariant).
- `workflow/runtime/jev-route-capsule-promotion.json` bound 13 sources by SHA-256, including the router: any router change failed the capsule closed.
- `scripts/deploy-agent-workflow` defaults to dry-run; `--apply` prunes stale managed links (it also leaves `*.bak.<ts>` backups of replaced links).

## Decisions
### Physical move to `extras/` instead of flag-only shelving or `vendor/`
- Context: the `0 0 0` catalog shelf already existed; `vendor/` assumes an upstream repo (`sync-vendor-skills` clones every row).
- Choice: `git mv` to `extras/skills/` with a new `extras` source (user decision).
- Rejected options: flags only (less visible); `vendor/` (sync contract).
- Rationale: readable tree, reversible by `git mv` back + catalog row.
- Consequences: every hardcoded `pi/skills/<name>` consumer had to learn `extras`.
### Router in T1, with HEAD-parity read-only predicates
- Context: removing specialized routes exposed their prompts to the implement detector; three rounds of new report heuristics kept producing counter-examples (T1/T2/D1).
- Choice: keep HEAD's exact predicates and order, map them to core read-only decisions.
- Rejected options: new REPORT/QA/FIX regex heuristics.
- Rationale: parity by construction; differential proof beats heuristics.
- Consequences: 0 writeAllowed escalations vs HEAD over 4 972 evaluations (2 486 prompts × missing/ready).
### Jev capsule and canary removed early; Jev semantic shadow left for T2
- Context: capsule promotion SHA-bound to router; canary requires a deployed target skill; semantic shadow is `disabled` and its promotion binds its route list.
- Choice: remove capsule + canary in T1; leave semantic lists untouched (inert, disabled) — user decisions.
- Consequences: T2 owns the rest of Jev.
### Budget ceiling for `ship` raised 89 633 → 90 138
- Context: deploying `ship` on Pi requires adapter-sync stamps (+527 chars) on a zero-headroom surface.
- Choice: raise to the measured value (user decision); T3 ratchets back down.

## Accepted Drift
- Original plan/spec: 30 skills moved; `pi/skills/herdr` link deleted; `runtime-skill-canary-smoke` kept green; AC4 Jev lists edited; `core.json` +3 cases; skills-lock coverage floor 16.
- Implemented reality: 29 moved + canary tool removed; herdr link kept (target is tracked, restored by `a4a5b04`); AC4 lists untouched; `core.json` +18 cases (review witnesses); floor 13 (css links removed).
- Why accepted: each recorded in the plan Decision Log with a user or autonomous decision; all are either strengthening or bounded, documented weakenings.
- Conservative over-stops accepted (no write escalation): "Explain how to push my commits", "Create a mock/local Linear issue", "Fix CI for the local credential/billing tests", "Add a parser test for push branch" → `ops-stop`. Spec creation → `answer`/write as at HEAD's spec-guide (write already allowed).

## Validation Evidence
- command: `scripts/verify-agentic-infra core`
  - result: 35/36, same as baseline (only `supply-chain-smoke`, red on HEAD).
- command: full profile run check by check vs HEAD worktree
  - result: no regression; reds on both sides: workflow-docs-smoke (description cap; the masked remainder passes), agentic-infra-manifest-smoke, install-smoke and claude-profile-smoke (exit 126), jev-efficiency-candidate-test.
- command: `scripts/router-eval`
  - result: 230/230; per-file case counts ≥ HEAD; 0 `writeAllowed` false→true on named cases and agent-scenarios.
- command: differential HEAD vs new router (`/tmp/t1-diff-evidence.mjs`, Codex-extended to 2 486 prompts)
  - result: 0 escalations over 4 972 evaluations.
- command: `bun test pi/extensions/__tests__/`
  - result: 383/383.
- command: `scripts/workflow-adapter-sync --check`, `bun ./scripts/verify-skills-lock.mjs`, `scripts/workflow-context-budget`, `scripts/check-fix-symlinks.sh`, `node scripts/validate-adrs`
  - result: clean / 81 hashes / 8 surfaces within ceiling / 0 issue / 27 records.
- Reviews: T1 (Spec GO, Logic GO WITH NOTES, Codex BLOCK → folded), T2 (Spec GO, Logic BLOCK, Codex BLOCK → folded), D1 (Codex + Logic findings → HEAD-parity redesign), D2 (Logic GO WITH NOTES, Codex 0 escalations + accepted over-stops), F1 (Logic GO, Spec GO, Codex 1 MEDIUM ship canonical → folded), F2 user-authorized (Logic GO, Codex 1 MEDIUM (unstaged lock rotation) → staged). Cross-model adversary: OpenAI `gpt-6` via Codex CLI.
- simplify: removed 1 (reverse-order Linear-create alternative; later superseded by the HEAD-parity redesign). quality: pass (sibling comparison; `code-quality` not exposed in Claude).

## Follow-up State
- Remaining risks: conservative ops-stop over-stops on local prompts mentioning push/credential/billing/Linear creation; `workflow-ref-linter` prints `awk: Argument list too long` yet reports clean (possibly partially blind); stale comment naming the removed canary in `scripts/lib/skill-tree-hash.mjs:6-7` (no-comments hook blocks rewrite).
- Parking lot: pre-existing reds (`supply-chain-smoke`, manifest smoke core list missing the 4 T8a rows, description cap 2 939 > 2 000).
- Superseded docs/specs: none (ADR-0027 narrows ADR-0007).
- Next links: T2 — remove the rest of Jev (semantic shadow, route promotion, campaigns, calibration), token-protocol T8a/T8b bundle, self-improvement/reviewer-improvement loops, program-state, evidence-proof, ambiguous no_progress/ledger hooks. T3 — move non-core `workflow/skills/*` contracts to extras, rewrite `spec.md`/`contract-details.md` short, bring `plan-implement`/`implement` under budget, ratchet the `ship` ceiling down.
