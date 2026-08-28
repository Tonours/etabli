# Implemented: repo hygiene goal — dead code, docs, private data

## Metadata

- Archived: 2026-08-28
- Source plan: `PLAN.md` — Repo hygiene goal — 0% dead code, 100% current docs, 0% private data
- Source plan SHA-256: `10455ebe1fb441e30ab35ce6e40caf58ef311283644166a2f7cfa701c24cedcd`
- Status: IMPLEMENTED
- Commit / branch: `chore/repo-hygiene-goal` @ `0e8df6a` (base `main` @ `855eb49`)

## Outcome

Three-axis audit (pi-lens full scan + import graph + repo-wide word sweeps +
gitleaks fresh run) executed, findings closed:

- **Dead code**: six exported symbols deleted (each verified 0 external refs
  repo-wide incl. tests/docs and 0 internal uses):
  `pi-runtime.ts::resetRuntimeCaches`,
  `ledger-integrity.mjs::inspectLedgerText` (plus a dangling doc comment),
  `no-progress-guard.mjs::{parseLedgerEvents,isTerminalLedger,findActiveLedgers}`
  (plus the then-unused `findValidActiveLedgers` import),
  `obvault-topic-resolver.mjs::resolverCacheStats` together with its entire
  write-only stats apparatus (const + 4 increment sites). Blocking
  ast-grep finding closed: `router-eval.mjs` dataset `JSON.parse` now
  wrapped with a filename-context error. Net diff −70 lines.
- **Docs**: README Layout table + "Where to go next" list reference
  `docs/pstack-strategy.md` (landed earlier today, never referenced).
  fix-links 0 issues, ADR validation ok (21 records).
- **Private data**: 23 `/Volumes/Crucial/work/obvault` occurrences replaced
  with the canonical `~/work/obvault` form across 7 answer-quality trace
  docs; account-name fragments genericized in two launchd label comments
  (`com.<account>.*`) and one path-encoding example. Tracked-tree sweeps
  report zero private volume paths and zero account fragments.

## Context

- Goal-mode directive: analyse the project for 0% dead code, 100% current
  docs, 0% secret/private content.

## Decisions

### What counts as dead

- Import-graph "dead weight" candidates were ALL disproven: launchd
  schedules `watchdog.sh` and `routines/run.sh` outside the repo; the rest
  have doc/test/CLI references. Only symbols with zero references on both
  axes were deleted.
- Export-only cleanup on internally-used symbols judged out of scope (the
  goal targets dead code, not API-surface minimization).
- `.pi/tasks/*.json` carries a local path but is untracked — not committed
  content, out of scope.

### What counts as private

- Real volume path in evidence docs → replaced with the canonical symlink
  form (meaning preserved).
- Slack channel ID and `#routines` name in the sessions-report prompt are
  operational identifiers required by the routine, not credentials — kept.
- `/Volumes/` as a generic regex prefix in `scripts/answer-quality-check`
  contains no private datum — kept.
- Dummy secrets in the redaction unit test (`filter-output.test.ts`) are
  generated fakes testing redaction itself; gitleaks clean — kept.

## Validation Evidence

- command: `scripts/verify-agentic-infra core` → 18/18
- command: `bun test pi/extensions/__tests__/` → 242 pass, 0 fail
- command: `node scripts/validate-adrs .` → ok, 21 records
- command: `bash scripts/fix-links` → 0 issues
- command: tracked-tree re-sweep (6 symbol names, volume path, account
  fragment) → CLEAN
- review: Logic hunter (fresh child) GO, zero findings, deciding-code table
  complete; Spec hunter parent clean; standard-tier double-sample documented.
- pi-lens full scan re-run: blocking router-eval finding cleared.

## Follow-up State

- Recorded, not acted on (out of goal scope): complexity hotspots
  (rtk-runtime, filter-output), dependabot cooldown suggestion, curl|bash
  installer pattern (upstream asdf install), jscpd small duplicates, French
  typos false positives (English dictionary over French prose).
- Next links: `docs/pstack-strategy.md`, ADR-0020/0021.
