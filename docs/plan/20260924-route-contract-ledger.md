# Implemented: Pi loads the chosen route's contract; canonical ledger + open-run cleanup

## Metadata
- Archived: 2026-09-24
- Source plan: `PLAN.md` — Tranche 3 — Pi charge le contrat de la route choisie ; ledger canonique (forme) + nettoyage des runs ouverts
- Source plan SHA-256: `db1e04c69f37f095db1b06ea0f9cfa57fda6e109b7f947a62afdd12f49ef85ea`
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `main` (base `7d53652`)
- Workflow initiative: route-contract-ledger

## Outcome
- **Contract pointer injected on skill-backed routes.** `resolveContractPointer` resolves `SKILL.md` in Pi loader order (deployed-pi > deployed-agents > repo, deployed-first measured tranche 2), returns `{path, sha256, provenance}`; the router injects `<etabli-route-contract>` with a must-read line in every mode for skill-backed routes (skill-less routes keep legacy per-mode behavior). Missing skill file → null pointer, no crash.
- **`route_decided` issuance with whole-ledger dedup.** Emitted at `before_agent_start` when an explicit cwd resolves an active ledger, plus catch-up on `tool_result` and `agent_end` for first-turn gap (pendingRoute slot, dedup-idempotent). Detail `{route, reason}` + optional `contract_path`, `contract_sha256`, `provenance`. Best effort under concurrency; byte-identical concurrent dupes are valid and collapsed by the retrospect consumer (first-attribution).
- **Compliance measured and DECIDED (AC6).** Fixture-HOME A/B, same 8 prompts, same model (openrouter moonshotai/kimi-k2.6): BEFORE 9/9 reads, AFTER 8/8 reads (ledger-gated, 8/8 corroborated `name:`, chained 5/8). AFTER=100% ≥ 50% → pointer KEPT; §11 premise (0 reads) NOT reproduced locally. No injection-body spike. Artefacts `.workflow/route-contract-ledger/compliance-{before,after}.json` + `mine.mjs`.
- **`review_completed` status enum (v2).** `{GO, GO WITH NOTES, BLOCK}` enforced in strict; 12 legacy values rejected on v2 append; legacy/v1 history stays valid (lenience). `route_decided` additive keys validated in strict (closed key set, nonempty path/sha, provenance enum), mirrored with the retrospect consumer (cross-referenced).
- **Hygiene gate live.** `scripts/workflow-ledger-check` FAILs on uninventoried drift or changed pins, WARNs on quarantined/stale, SKIPs with distinct reasons (missing dir vs missing CLI); wired as `core shell-docs ledger-check` manifest row. Inventory `ledger-drift-grandfathered.json`: 15 frozen entries + 3 amendments (maintainability cleanup-truth, 2 F3 closed-key flips). Live: ok=89 quarantined=18 stale=0 failed=0.
- **6 open runs → terminal.** 3 valid via CLI append before enum (maintainability completed re-affirm preserved via amendment, resume3 + public-scrub honest blocked); 3 invalid via `recover` with reason codes.
- **Form guarantee documented.** `workflow/events.md`: agents must use the CLI; Pi/Codex harness extensions are the single named direct-append exception (sync hot paths, serialized writer parked); tightening flips are inventoried, never rewritten. Quality passes must not use `review_completed` until tranche 4 (F2).

## Context
- Roadmap slice: P0-2 (contract loading, measured) + P0-3 (ledger discipline, form guarantee per user decision 2026-09-24) + 6-run cleanup (PARTIAL: 16 macbook-work runs read-only, one-liner below).
- `append` refuses on invalid ledgers → invalid runs terminate only via `recover` (moves to `events.invalid-<stamp>.jsonl` + motivated v2 `blocked`).
- `pickPrimaryActiveLedger` rejects empty ledgers (`empty_ledger`): router emission needs a CLI-started run (found by AFTER pilot, fixture reseeded, no product change — matches "si ledger actif" scope).
- Router emission lands on line 2+ of seeded ledgers; retrospect first-route attribution is positional among route rows, not ledger rows.
- `legacy_detail` falls back to `strict_detail` first: tightening strict flips v1 history too (1 of the 2 F3 flips was v1).
- Autonomous profile applies to `completed` only when a v2 plan-implement `route_decided` exists; without it the profile is silently skipped (pre-existing lenience, widened by the agent hand-append ban — closed by catch-up emission).
- Per-turn router I/O measured: pointer 0.02ms + whole-ledger dedupe scan 0.00ms on biggest ledger (274 lines) — negligible vs model call.
- Protected skills stay visible: `alambic-brain`, `alambic-obvault`, `typesafe-ai` (asserted, untouched by this tranche).

## Decisions
### Pointer over body, threshold-arbitrated
- Context: §11 recommended pointer-or-body with ledger proof; body injection unbuilt.
- Choice: pointer (path+sha+provenance+must-read) + AC6 50% gate; AFTER=100% → kept.
- Rejected options: immediate body injection (unmeasured heaviness), pointer without measurement (unfalsifiable §11 claim).
- Rationale: measurement first; the pointer also carries ledger issuance proof the body path would lack.
- Consequences: BEFORE=100% premise-note recorded; robustness + proof are the pointer's value, not read-rate lift.

### Catch-up emission (tool_result + agent_end), not before_agent_start only
- Context: first-turn runs have no ledger when the route is decided; agents are banned from hand-appending on Pi.
- Choice: stash pendingRoute at decision; re-attempt on every tool_result while pending + one last retry at agent_end (dedup-idempotent).
- Rejected options: agent_end only (misses mid-turn terminalization), CLI-side emission (CLI doesn't know the route), allowing agent fallback appends (weak first-attribution + unenforceable).
- Rationale: closes the profile-skip hole for single-prompt runs without weakening any contract.
- Consequences: single-slot router state (justified: prompt unavailable in tool_result); residual single-tool create+terminalize still missed (documented, absurdly rare).

### Closed additive key set with parity, flips inventoried
- Context: validator ignored additive keys while the consumer enforced them (MED2 divergence).
- Choice: strict closed set mirroring `validRouteDecidedDetail` both ways; 2 honest flips (extra keys on terminal history) inventoried via amendments.
- Rejected options: open-ended extras (re-diverges), narrowing to known-keys-only validation (same), rewriting history (forbidden).
- Rationale: form guarantee means validator ≡ consumer; terminal history is evidence, amended not edited.
- Consequences: inventory 15+3; jq↔mjs mirror cross-referenced (change one, change the other).

### Cache trusted only under matching validator fingerprint
- Context: two gate bypasses found in review (cached quarantine skipped inventory; cache reads bypassed the fp gate).
- Choice: single CACHE_TRUSTED flag gating reads + carry-forward; cached quarantine re-consults its pin.
- Rejected options: cacheless always-full runs (slow live gate), trusting cache across validator changes (the bug).
- Rationale: a hygiene gate that passes on stale verdicts is worse than no gate.
- Consequences: validator edits rotate the fp and force full revalidation (this exposed the 2 honest F3 flips).

### Context-budget ceilings raised (reviewed growth)
- Context: tranche-3 normative additions to `workflow/events.md` pushed `implement`/`plan-implement` surfaces over ceiling.
- Choice: raise to ceil(chars×1.03) per tool policy (54903 / 60674) with Decision Log rationale instead of trimming.
- Rejected options: trimming normative agent-facing rules, moving them to the cold validator doc (wrong audience).
- Rationale: every added line is hot-path contract agents must read.
- Consequences: reviewers confirmed; headroom ~1600-1700 chars per surface.

## Accepted Drift
- Original plan/spec: inventory ~14 (6 multi_exec + 8 flips); AC2 dupes "sans effet" (consumer implicitly tolerant); manifest +1 row; Codex gate ≤2 tours.
- Implemented reality: inventory 15+3 (9th flip public-scrub self-history + maintainability amendment + 2 F3 closed-key flips); exact-dupe tolerance implemented in consumer (collapse before conflict check) after tour-1 remedy pinned the conflict by mistake (corrected tour 2, AC2 prose stands); manifest row added late (found missing in self-review); Codex gate took 3 tours (declared overrun, precedent T2 SHIP WITH NOTES).
- Why accepted: every deviation is identified drift with a reason string (AC4's own rule); the L2 remedy correction was honest and Codex-confirmed; the missing manifest row was a gap, now closed; the overrun bought two real gate-bypass fixes.

## Validation Evidence
- command: `bun test pi/extensions/__tests__/`
  - expected: pass (pointer, provenance, dedupe, layouts, absent, skill-less, catch-up)
  - observed: 360 pass / 0 fail, 20 files
- command: `bash tests/workflow-event-smoke.sh`
  - expected: pass (enum, 12 rejections, lenience, additive validation)
  - observed: ok
- command: `bash tests/harness-trace-retrospect-smoke.sh`
  - expected: pass (additives, route-second, dupe collapse, time-order)
  - observed: ok
- command: `scripts/workflow-ledger-check` (live, --full)
  - expected: exit 0, warns = inventory
  - observed: ok=89 quarantined=18 stale=0 failed=0
- command: `scripts/verify-agentic-infra core`
  - expected: 24/24 vert
  - observed: 24/24 pass (ledger-check 4s)
- command: AC6 A/B (mine.mjs, ledger-gated AFTER)
  - expected: decision (threshold / spike / inconclusive)
  - observed: BEFORE 9/9, AFTER 8/8 → pointer KEPT, premise-note, no spike
- reviews: Logic GO + Spec GO (inline, tour-1 fixes verified); Codex diff GO WITH NOTES tour 3 (no findings; note = sandbox couldn't run suites, covered locally); thermo SHIP (state/duplication/file-size bars argued, mirror cross-refs added)
- budget: Codex gate overrun declared (3 tours); all other gates within budget

## CI / Live Split (AC4 documentation)
- CI runs `verify-agentic-infra shell-docs` → `tests/workflow-ledger-check-smoke.sh`: fixture boundaries (a–g, k, l) always execute; step j (live repo run) degrades to SKIP exit 0 on clones without `.workflow/` (git-ignored).
- Local gate: `scripts/workflow-ledger-check` (live, cached) or `--full`; same binary the smoke exercises.
- Read-only remote census (no ssh mutation): `ssh macbook-work 'for d in ~/work/etabli/.workflow/*/; do s=$(basename "$d"); [ -f "$d/events.jsonl" ] && echo "$s: $(tail -1 "$d/events.jsonl" | jq -r .event)"; done'`

## Follow-up (Parking Lot)
- Writer sérialisé commun extension+CLI (form-guarantee residual: multi-writer race; 0/11616 non-JSON lines observed) — parked per user decision.
- Dedicated quality event (F2, tranche 4): quality passes currently proven in review `evidence` text or omitted.
- `contract_read` hook-side observation + injection-body spike: NOT triggered (AC6 ≥50%); spike path documented in PLAN AC6 if a future re-measurement drops below threshold.
- 16 macbook-work runs: untouched (read-only enforced); re-run census one-liner when remote access allows.
- Amendment-override semantics: entries win over same-slug amendments (disjoint by construction today); if an overlap is ever added, the check fails closed with "changed since freeze" — revisit wording then.
- `workflow-router-extension.test.ts` (1209 lines, already >1k pre-tranche): split when next touched.

## Skills
- `alambic-brain`, `alambic-obvault`, `typesafe-ai`: kept visible per standing user constraint (no DMI flag, no deny entry).
