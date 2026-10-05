# Implemented: Reliable project-vault routing and narrow plan cleanup

## Metadata
- Archived: 2026-10-01
- Source plan: `PLAN.md` — complete exact GitHub authority mapping and cumulative project-vault repairs
- Source plan SHA-256: `dc82876fce8a7d4ffa54e8bf7fef6afe241e2ba3619686bfa386835b050bece3`
- Status: IMPLEMENTED
- Commit / branch: `fix/vault-plan-recovery`, uncommitted; base/HEAD `f7ec82f58903839434bbb6c87e2e6c4cc02342cf` is the reviewed base, not a delivered commit
- Workflow initiative: delivery-authority-completion
- Cumulative delivery patch SHA-256: `3efd8cb250dbb06e96784337be8d06eafbf49bd5012c7ba038b02b81cf19ede3`

## Outcome
Project identity selects the right vault independently of machine scope, Git environment and process location. Retrieval commands are quoted consistently, including valid legacy cached commands. The cleanup exception accepts only known explicit scripts and a literal same-cwd prefix. Security pins, coupled smoke fixtures and deployed documentation declarations agree. All accepted repairs from the prior blocked runs are included in the final cumulative patch.

## Context
- `workflow/runtime/obvault-topic-resolver.mjs`: root selection, availability, command factory and legacy cache handling.
- `workflow/runtime/workflow-router-core.mjs`, `pi/extensions/lib/workflow-route-context.ts`, `workflow-router-runtime.ts`: actual session cwd reaches static and dynamic paths.
- `scripts/lib/plan-cleanup-command.mjs`: all guard callers pass cwd; real cleanup still enforces archive/source hash and preserves active selection.
- `.workflow/delivery-authority-completion/delivery-pin.json`: all24 reviewed source paths and hashes; three unrelated documents excluded and preserved.

## Decisions
### Exact repository identity
ForestAdmin on GitHub selects brain; other or failed Git discovery selects obvault. Nonempty OBVAULT_ROOT is exclusive. Missing selected vault returns null from root/dynamic resolution; it never switches to a sibling vault. AGENTS.md is optional for CLI availability. Static fixed-topic commands remain advisory even without the CLI; the documented degraded action is local repo evidence/search.

[initiative:delivery-final-corrections] Supported SSH aliases, usernames and ports now follow the same identity contract. Native Node child tests prove inherited GIT_DIR, GIT_WORK_TREE, GIT_COMMON_DIR and environment config injection cannot override explicit cwd. Git subprocess discovery strips inherited GIT_* variables.

The raw ASCII URI authority is decoded once and checked against github.com alongside native URL validation. For SSH variants the full URL is decoded once before validating transport host/path, matching actual Git dispatch. Original and decoded raw paths must survive normalization unchanged. Query/fragment forms, Unicode substitutions, malformed/double escapes and host/org lookalikes stay personal. No SSH config lookup or alternate transport authority is introduced.

Native trace with core.sshCommand=/usr/bin/false proves encoded separators can change the SSH host to evil.test or path to another organization; tests assert actual dispatch while preventing any remote connection. The percent-encoded HTTPS GitHub candidate was rejected: the blocking local proxy records the same github.com CONNECT target. Unicode rejection is conservative hardening, not a demonstrated attacker-host exploit.

### Cache compatibility and quoted commands
[initiative:delivery-blocker-repair] Live/static commands share the quoted CLI factory. Canonical root remains part of cache identity; no stale root-selection memo or sibling fallback.

[initiative:delivery-final-corrections] Legacy cache schema/key remained unchanged, so a valid old command could survive its10sTTL. Rebuild positive commands from current selected root and safe string query. Zero still abstains; null, object or array queries miss without throwing. Isolated native Node cache plus real shell retrieval proves paths with spaces/apostrophes work without touching user cache.

### Narrow cleanup and coherent security gates
[initiative:delivery-blocker-repair] Slashless PATH executables, executable traversal, shell expansion/operators and arbitrary-cwd prefixes are rejected. Known explicit local/central paths, optional runners, quoted ordinary paths and canonical same-session literal cd remain usable. Existing archive and active-run preservation checks remain intact.

[initiative:delivery-blocker-repair] undici8.10.2 and brace-expansion5.0.12 are the minimal selected patched releases; manifest, lock, installed tree and supply-chain fixtures agree. No audit ignores or major/SDK upgrades. Core manifest includes all three existing Phase0 checks. UTC fixture timestamps, real central cleanup CLI and Etabli-only lease-reference declarations repair the full validation path without weakening context ceilings.

## Accepted Drift
Earlier runs ended terminal BLOCK after their bounded final reviews; they were never reopened or silently reset. User continuation authorized scoped successor plans, with exact old plans/pins and scratch worktrees retained. The final plan adds encoded authority, suffix and decode-before-split regression coverage in the same resolver surface. Source was promoted only after native cross-family plan READY.

## Validation Evidence
- command: bun test pi/extensions/__tests__/project-vault.test.ts
  - result: frozen7047 red60pass/23fail across83cases; corrected scratch83/83. Actual delivery focused suite also green. Evidence: `.workflow/delivery-authority-completion/{authority-delivery-red-final,authority-scratch-green-final,focused}.txt`.
- command: cd pi && bun test extensions/__tests__/
  - result:444/444,1294assertions across18files; same444/444 with OBVAULT_ROOT=/custom/vault. Evidence: `extensions.txt`, `extensions-override.txt` in the initiative directory.
- command: cd pi && bun run typecheck && bun audit
  - result: strict types exit0; no vulnerabilities. Evidence: `types.txt`, `audit.txt`.
- command: scripts/verify-agentic-infra core && scripts/verify-agentic-infra full
  - result:29/29core,83/83full; no waived named blockers. Evidence: `core.txt`, `full.txt`.
- command: scripts/workflow-ref-linter && scripts/workflow-context-budget && git diff --check
  - result: clean references/whitespace;8/8 original context ceilings. Evidence: `references.txt`, `context-budget.txt`, `diff-check.txt`.
- simplify: clean; cumulative quality pass compared named local siblings (`obvault-topic-resolver.test.ts`, `workflow-route-context.ts`, `plan-cleanup-command.mjs`).
- review: final full F1 lead GO, native Logic GO, Spec No findings and independent native Claude code adversary GO on unchanged pinned patch. Fresh isolated Logic/Spec model openai-codex/gpt-6.1-sol with observed high effort; all lenses and deciding-code complete. Cross-family native claude-opus-5-5 plan/code receipts retained. No claims of separately attested upstream endpoint.
- preservation: prior terminal ledgers and unrelated3documents byte-identical; active-run selection absent. Source matches pinned patch. Evidence: `preservation.json`.

## Follow-up State
- Remaining risks: local uncommitted implementation; no push/deploy or external/vault writes. Static advisory commands can reference an unavailable CLI; fallback is documented. Git discovery adds bounded latency on static topic matches. Noncanonical remote forms may conservatively select personal; SSHconfig aliases remain out of scope.
- Parking lot: none required for this task; optional future availability metadata or performance optimization needs its own scoped work.
- Superseded docs/specs: historical discarded record preserved; previous blocked execution plans remain local evidence, not mislabeled implemented archives.
- Next links: `.workflow/delivery-authority-completion/events.jsonl` and final handoff report. Archive is immutable; root cleanup uses its exact source-plan hash.
