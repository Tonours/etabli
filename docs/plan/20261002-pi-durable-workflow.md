# Implemented: persistent Etabli workflows on Pi Durable

## Metadata
- Archived: 2026-10-02
- Source plan: `PLAN.md` — seven-feature Pi Durable integration
- Source plan SHA-256: `07691f1f5a1903a221eb69cc8343c2e806c13646ed3499f22447caa024061cbf`
- Status: IMPLEMENTED
- Branch: `feat/durable-workflow`; local uncommitted owner and satellite changes
- Workflow initiative: pi-durable-repair
- Owner: `/Users/tonours/.codex/worktrees/0598/etabli`
- Satellite: `/Users/tonours/.codex/worktrees/0598/pi-mobile`

## Outcome
Verified local native host and seven persisted workflows:

| Feature | Delivered behavior | Evidence |
| --- | --- | --- |
| Reviews and review hunters | Frozen SHA/inputs, recorded results, fresh missing-only retry, retained consumed request/round budgets | `pi/durable/reviews.ts`; `pi/durable/test/workflows.test.ts`; `pi/durable/test/review-regressions.test.ts` |
| Goal, plan-implement, ship | Parent phases, validations and evidence waits restore under actual READY plan/canonical journal authority; native review does not override ship parent authority | `pi/durable/groups.ts`; `pi/durable/missions.ts`; `pi/durable/test/missions-ledger.test.ts`; `pi/durable/test/completion.test.ts`; `pi/durable/test/f1-regressions.test.ts` |
| Tasks and subagents | Native parent ownership, dependency results, durable absolute deadline, cancellation and drainage | `pi/durable/tasks.ts`; `pi/durable/groups.ts`; `pi/durable/test/workflows.test.ts` |
| Pi Mobile | Shared committed public projection and exact target/content-bound stable admission ID stored before POST, including lost-ACK resends | `pi/durable/mobile.ts`; satellite `apps/mobile/outbox.ts`; `pi/durable/test/mobile.test.ts` |
| CI and PR waits | Original deadline; fresh target HEAD/checks on resume and before decisions | `pi/durable/tasks.ts`; `pi/durable/missions.ts`; `pi/durable/test/compaction-campaign.test.ts` |
| Autoresearch and benchmarks | Immutable cells/population, outcomes/errors/attempts retained; interrupted effects require receipt/reconciliation | `pi/durable/groups.ts`; `pi/durable/commands.ts`; `pi/durable/test/compaction-campaign.test.ts` |
| Compaction and handoff | Native single compaction controller; public/private handoff reconciled and copied in one transaction, including error/cancel, with public-only sequence/hash | `pi/durable/projection.ts`; `pi/durable/host.ts`; `pi/durable/test/f1-regressions.test.ts` |

The distinct `pi-durable` entrypoint uses pinned Earendil runtime 1.0.0 and SQLite. Existing classic Pi remains available; its JSONL/plugin/provider surfaces are not automatically migrated. Global Pi CLI version 1.0.0 was verified.

## Decisions
- Kernel lifetime owner lock, private Unix control socket and capability fence the local current-user boundary. Native safe tools recheck role/cwd/inputs/path/mission after awaited preparation/export; exact human grants and external effect receipts remain required.
- Canonical `.workflow` receipts remain authoritative; exports record intent before append and recover append-before-ACK without duplicate IDs. Fresh completion evidence gets a hash-bound intent; consumed budgets/results never reset.
- Public phone data omits private recovery and reasoning; shared transaction terminal reconciliation prevents contradictory handoff versions. Native review issuer is distinguished by route/contract/exact export ID.
- The mobile client refuses unknown/incomplete/conflicting target metadata. HTTP snapshot refresh preserves independent WebSocket identity; saved outbox target/content cannot silently downgrade.
- Campaign restart fixture waits an actual child marker and validated interrupted receipt, instead of assuming the execute checkpoint means the worker already started.

## Accepted Drift
- Integration is an additive native host, with explicit adapters, rather than a silent replacement of every classic extension.
- Human-authorized follow-up runs preserve the two earlier terminal blocked journals and spent review counters. `.workflow/pi-durable-repair/continuation.json` records their hashes; no native runtime budget is reset.
- [initiative:pi-durable-workflow] prior T1/T2/D1/D2/F1 remain terminal blocked, hash30de99b23cb010afa06213718bc44fc8a6a985c0fe96e7a1d90fcc7c7248d0dc.
- [initiative:pi-durable-finalization] prior T1/T2/D1/D2/F1 remain terminal blocked, hash98e50928a4b89bb3657a0653c8ca71abdfa484bd86216f4ce4d1153a695181b9.

## Validation Evidence
- `npm test --prefix pi/durable`: **70/70 passed**, real Node/SQLite/process/SIGKILL/local connector; `.workflow/pi-durable-repair/checks/native-full-renewed.log`.
- `AGENTIC_INFRA_JOBS=2 scripts/verify-agentic-infra core`: **29/29 checks**, including **444/444 classic extension tests**; `checks/core-renewed.log`. Initial unchanged vault resolver failure retained; isolated 83/83 and renewed full pass supersede that attempt, without altering that resolver.
- Strict unused/type checks passed for native host; connector/protocol/mobile types and connector smoke **14 assertions** passed; `checks/types-final.log`, `satellite-types.log`, `satellite-smoke.log`.
- Failure-first regressions on original frozen sources confirmed null/passed, lost ship refusal, null/cancelled and null/failed outcomes plus CLI help failure; corrected tests pass. `checks/failure-first-native-confirmed.log`, `failure-first-help-confirmed.log`.
- Guide quality, workflow references and all source hashes/whitespace passed. `simplify: clean`; parent quality fallback compared three named local siblings in `.workflow/pi-durable-repair/quality.md`.
- T1 and fresh cumulative F1: **GO WITH NOTES, no retained defects**, all 54 files / 9186 patch lines on SHA53052b98f1c06ec9c9149e352c066e261505cedfe0534c5f397504e73a91a594. Logic/Spec coverage 8 lenses, T1 has24 and F1 has25 deciding rows. Actual independent adversaries: claude-opus-5-5 / Anthropic firstParty / APIKeySource none, T1 session4dd9a96a-670d-4f4a-84a7-6308b315f598 and F1 session21b4cf81-df00-4497-85a9-455e34dc83a0. Normal reports saved under `reviews/t1/` and `reviews/f1/`; provider list-price accounting is not evidence of an extra bill.
- Installed `~/.local/bin/pi-durable` as a new symlink to the retained owner `scripts/pi-durable`. Actual installed CLI **SIGKILL/resume/exact-ID resend passed**: one admission, identical session/conversation/messages, request counter**1 before and after**, coherent state/handoff sequence, recovery private. Offline catalog 70 metadata rows. `checks/installed-entrypoint.log` and `installed-check.json`; five existing configs, five protected main files, both older terminal ledgers and all 54 reviewed source hashes unchanged.

## Follow-up State
- `not verified`: physical phone, Linux process supervisor, live provider output quality and real remote GitHub operations. Deterministic model responses validate coordination, not provider quality.
- Publication-specific parent/review/CI gates apply to recognized Git/GitHub publication argv; generic forms such as shell wrappers or Git aliases still require their exact human command grant. Concurrent validation may conservatively block review export until evidence is reconciled; results/costs remain recorded. Generic check-to-OS-effect window remains documented; no distributed exactly-once or OS sandbox guarantee.
- Local changes remain in retained owner/satellite worktrees; no commit, push, merge or deployment was requested. Retain owner worktree while the installed entrypoint targets it.
- Guide: `docs/pi-durable.md`; source analysis: `docs/research/20261001-pi-durable-etabli-features.md`; checks and review provenance: `.workflow/pi-durable-repair/delivery-evidence.json`.
