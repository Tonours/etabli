# Implemented: polish pass — mechanical lint debt, dedup, hardening

## Metadata

- Archived: 2026-08-28
- Source plan: `PLAN.md` — Polish pass — mechanical lint debt, real duplication, dead indirection
- Source plan SHA-256: `5dc932a5c48cda21603b1ce9c81a3345e20064c019ab5ebed0214ba0b33219c8`
- Status: IMPLEMENTED
- Commit / branch: `chore/polish-pass` (single commit on top of `main` @ `8c7195b`)

## Outcome

- Mechanical: `filter-output.ts` parseInt gains radix 10 and the tool_result
  handler drops a no-await async (sync-handler precedent verified in-repo);
  `rtk.ts` registerTool drops a forwarding execute wrapper that added
  nothing over the spread.
- Nested ternaries rewritten as explicit branches at four sites —
  session-handoff (extracted `replayState`/`renderProgramSection`),
  obvault-topic-resolver comparator, workflow-router-lib
  `normalizeToolName`, ledger-auto-emit (extracted `toolResultText`).
- New `scripts/lib/predicates.mjs` (`isObject`, `isNonEmptyString`,
  `isStringArray(value, minimum=1)` with `every(isNonEmptyString)`
  semantics) replaces five byte-identical local copies across
  ledger-integrity, project-autonomy, no-progress-guard, ledger-auto-emit,
  workflow-receipts. Scope grew from the planned three consumers to five —
  same duplication, same fix.
- `.github/dependabot.yml` gains `cooldown.default-days: 7` on both
  ecosystems (zizmor/opengrep supply-chain finding).
- Merged branch `feat/project-hunt-pi-core` deleted.

## Context

- Follow-up to the hygiene goal: the user asked to make the repo cleaner
  still; this pass exhausts the mechanical lint debt without opening the
  complexity-refactor chantiers.

## Decisions

- Predicates unified on the STRONGEST consumer semantics
  (`every(isNonEmptyString)`); the first draft used a weaker
  `typeof item === "string"` check and was corrected before wiring — the
  consumers' local copies were the authority, not the schema recollection.
- Skipped and recorded: parseArgs CLI idiom duplication (divergent flags),
  sessions-report/run.sh skeleton duplication (launchd scripts),
  string-key `.sort()` (intended lexicographic fingerprint), `.reverse()`
  on spread copies (safe), filter+map with a real predicate (clearer than
  flatMap), `requiresMaxThinking` named predicate (documentary value),
  `readPointer` flag argument (pre-existing, sensitive surface, info-level
  rule), complexity hotspots (dedicated session), no-console in CLI
  scripts, curl|bash asdf installer.

## Validation Evidence

- `bun test pi/extensions/__tests__/` → 242 pass, 0 fail
- `scripts/verify-agentic-infra core` → 18/18
- lens delta on the turn → zero issues (targeted warnings gone)
- Logic hunter (fresh child) → GO, deciding-code table complete, every
  change verified behavior-identical; Spec hunter parent clean.

## Follow-up State

- Remaining recorded debt is structural only: complexity hotspots
  (rtk-runtime, filter-output, workflow-router) and the installer's
  curl|bash asdf step — both need dedicated sessions, not polish.
- Next links: `docs/pstack-strategy.md`, ADR-0020/0021.
