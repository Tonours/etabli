# Implemented: source-bound product QA for Claude and Pi

## Metadata

- Archived: 2026-10-02
- Source plan: `PLAN.md` — Reduce manual QA with shared project verification for Claude Code and Pi
- Source plan SHA-256: `dfdb711be9ab504028416f005c8c7fd754950cebe374a22da4c78846d6331b4c`
- Status: IMPLEMENTED
- Commit / branch: Etabli `main`; Starter `55e72e8d1c488979a08bb8cb54d03e7188c2c382` on `main`; GitHub publication and CI outcomes follow in the closeout ledger.
- Workflow initiative: trust-qa-publish-close-20261002
- Owner: Etabli; satellite: AdonisJS Starter. This is the single implemented archive.

## Outcome

Required product plans now need current, passing evidence for every material product criterion before archive/completion. Claude Code and Pi consume one Starter recipe and exercise the real authentication/profile journeys in owned isolated environments. Evidence binds acceptance IDs, source paths/bytes/modes/ref, environment, artifacts, command outcomes and cleanup. Existing Japa/Playwright and full quality remain delivery gates.

## Context

- `workflow/product-verification.md`, `scripts/project-verification-check`, `scripts/plan-cleanup` and `scripts/workflow-event` implement the shared closing contract.
- Starter `.claude/skills/verify-starter/SKILL.md` remains canonical; `.pi/skills/verify-starter/SKILL.md` is a thin versioned pointer. The feature map describes covered and unverified behavior.
- The existing supervisor owns the source snapshot, API/frontend processes, disposable SQLite and local Mailpit; QA reuses that protocol rather than introducing another orchestrator.

## Decisions

### Validate behavior and persistence before completion

- Choice: real Playwright actions plus reload and read-only observations of the owned SQLite row/token state; explicit product IDs and required proof roles.
- Rationale: a successful model response, screenshot or HTTP response cannot prove a material product criterion alone.
- Consequences: failed, skipped, stale, missing or inconclusive evidence blocks completion. Docs-only/CLI-only plans retain legacy compatibility unless product verification is explicitly required.

### Preserve identity across asynchronous boundaries

- Choice: hash captured pack bytes; recheck plan/archive/pack/receipt after waits and immediately before plan deletion; recorded ledger contract and latest archive have precedence.
- Consequences: source or artifact changes invalidate proof. Metadata-only commits after archive are allowed only with identical source paths, bytes and modes. Cancellation invalidates its own exported execution receipt in finally even if rewriting the private receipt fails; the shared pack pointer and foreign run artifacts are retained.

### Complete review and repair publication prerequisites

- Complete pinned review covered 49 files: 28 owner and 21 satellite. Cumulative patch SHA-256: `a6090a34392f10eff88af8bf698fc6c54ae25ca5f2142ea427757a5ed1ebf9b1`.
- All 14 accepted findings are fixed: 13 medium, 1 low. These cover archive/ledger identity, interruption success, metadata-only commits, nested acceptance prose, deployed Git exclusions, foreign/previous-pack ownership, archive whitespace, degraded failure recording, async PLAN deletion, captured pack hashes and private receipt IO failure.
- Full Logic deciding-code coverage plus final correction verification found no remaining change request. Fresh native Claude complete-patch and final-delta reviews: effective `claude-opus-5-5`, Plan READY, Spec GO WITH NOTES, Code GO WITH NOTES. Parent Standards lens checked framework/testing fit.
- Publication repairs: locked patched transitive dependencies, runtime nghttp2 package floor, immutable Tailscale action SHA, compatibility with upstream conditional review dispatch, and two formatting-only tracked fixes. The pre-existing dirty tooling tests and unrelated documents are excluded.

## Accepted Drift

- Original plan excluded publication; the current user explicitly authorized all confirmed fixes, commits and direct pushes to `main` in both repos.
- The ordinary bounded review machine exhausted its default budget. Its original ledger remains BLOCK; the distinct corrective closeout records the explicitly justified extension under the user fix-all request and AGENTS limit-adjustment rule. No round is relabeled and no stale clean verdict is reused.
- An early review capture raced source mutation and was invalidated. An overlapped infra run read changing shell source and failed; the stable complete suite was rerun and passed. Historical failed runs remain in local evidence.
- Native QA includes three preserved baseline differences from the clean publication commit: `scripts/tests/feature-matrix.test.mjs`, `scripts/tests/scaffolder-safety.test.mjs`, and untracked `docs/goal-roadmap-phases.md`. Runtime QA/application bytes match the clean commit. Exact clean quality and native preserved-source proof are separate observations.

## Validation Evidence

- `scripts/verify-agentic-infra full`: 84/84 passed, including core 30/30, product guards and Pi extension suite 444/444; context ceilings unchanged.
- `node --test tests/project-verification-check.test.mjs`: 68/68 passed. Starter evidence/ownership tests: 8/8 passed, including real controlled interruption/private receipt EIO. These are tooling regressions, not application journey evidence.
- Clean Starter `55e72e8` full `pnpm quality`: exit 0; tooling 102, Japa 289, coverage 289, PostgreSQL 57, mail 95 and Playwright 18 passed; zero skipped in the focused suites. Audit and both production image scans reported zero vulnerabilities; secrets scan zero leaks; SAST 116 rules across 311 tracked files, zero findings.
- Native Claude `trust-claude-publish-final-20261002`, effective `claude-opus-5-5`; native Pi `trust-pi-publish-final-20261002`, effective `zai/glm-5.3` through temporary Z.ai Coding Plan registration and default project skill discovery. Both actual QA aggregate/doctor/auth/profile/cleanup receipts exit 0; owned cleanup passed, Mailpit removed and state stopped. No global provider configuration changed.
- Both native packs bind Starter ref `55e72e8` and source SHA-256 `7c8b52635d36fe32960f927746239b07b898dfc31d5c91715e4b15216583ace3`. Parent independently reran the shared checker on both: exit 0, AC-03/AC-04 passed. Claude's shell missed the outer QA status because of zsh PIPESTATUS; the actual aggregate/command receipts and independent checker are cited without inventing that missing status.
- Controlled negative `trust-neg-publish-final-20261002`, same source: deliberately wrong profile oracle; actual QA 1, auth 0, profile 1, cleanup 0. Shared checker exits 1; owned state stopped. The assertion that this control fails closed passes, and the failed pack is retained separately.
- Frozen-plan checks passed with no removed checks. Root declared evidence pack contains the fresh final Claude bundle. Pack SHA-256: `a910826ad782d29bcdc35c9cae7818a469bd77e50844a154fa11708e59bf9dea`.
- Local review tables, native receipts, failed probes and publication outcome: `.workflow/trust-qa-publish-close-20261002/`; clean quality log: `/tmp/trust-qa-publish-quality-final.log`.

## Follow-up State

- Remaining risks: this auth/profile pilot does not verify signup/reset/mail product journeys, organizations/invitations, API keys, billing, production deployment/HTTPS configuration or authorization/concurrency isolation. Regression mail/security checks are distinct from pilot coverage.
- Evidence is cooperative local proof, not adversarial same-user attestation. A storage failure preventing even artifact invalidation remains an operating limitation. Source manifests require regular files; symlink projects need an explicit future design.
- Parking lot: select and implement additional project journeys when material changes require them; measure human QA time before claiming savings. No accepted review finding is deferred.
- Next links: `workflow/product-verification.md`; Starter canonical recipe and feature map; local closeout ledger records exact GitHub publication and terminal CI outcomes after this immutable archive.
