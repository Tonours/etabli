# Implemented: T8a — ship budget surface + offline token-protocol instrumentation

## Metadata

- Archived: 2026-09-25
- Source plan: `PLAN.md` — Tranche 8a — Tokens: ship surfaces + offline protocol instrumentation (no paid campaigns)
- Source plan SHA-256: `a2c55d34c465914703eb177e8427b56783e29c6504e284f18a1fe5bc29e5ab9b`
- Status: IMPLEMENTED
- Commit / branch: `main` @ `3db5e40` (worktree holds T1–T7 + T8a uncommitted changes; no commit per tranche rules)
- Workflow initiative: `token-protocol`

## Outcome

- AC1 SHIPPED: `ship` budget surface with the exact v25 lists (17 systematic + 4 conditional with triggers); ceiling 89633 = measured chars; budget green on 8 surfaces; coverage check green (11/11 fixtures).
- AC2 SHIPPED: per-occurrence inventory committed (`tests/fixtures/token-protocol/ac2-inventory.json`, 8 occurrences); CONVERT set vide (honest availability-gated outcome — no availability-breaking pointer shipped); tripwire linter green (4 KEPT ranges matched, 0 unexpected); pointer-diff check green (0 CONVERT, 4 KEPT re-verified).
- AC3 BUILT+TESTED: full evaluation bundle exists; every OFFLINE check green with ZERO paid calls (dry-run 0 provider calls, validate 8+8, resolve-all 16/16 + 6/6, both $0 linkage chains with pinned numbers, oracle vectors, report numbers + refusals, verifier 6+1, parser, measure fixtures).
- AC4 WRITTEN+FINGERPRINTED: corpora transcribed/authored from the pinned v25 draft (`ea619770…`), manifest closed set (91 entries: 89 files + 2 dir shas), completeness check green.
- AC5 HELD: zero behavioral bytes published — Final `scripts/t8a-behavior-gate` exit 0 AFTER archive finalize ("0 frozen bytes changed — 14 files + 8 budget rows"); `workflow/ready-gate.md` never created; TREE RULE satisfied (tracked diffs = context-budget.json + checks manifest only; 95-leaf tree equality).
- Core battery 35/36: the single red (`supply-chain-smoke`) is a BASELINE-RED pre-existing failure (T1–T7 dirt, fix forbidden by the TREE RULE), attested below — 0 T8a regressions; all 4 new T8a rows green.
- ZERO paid runs executed in this tranche (no billing checkpoint consumed).

## Context

- The worktree carried 110+ uncommitted T1–T7 files, so AC5 is verified against the step-1 snapshot (`tests/fixtures/token-protocol/t8a-behavior-snapshot.tsv`, ledger-anchored via `snapshot_sha`), never against HEAD.
- Snapshot: 14 behavior-file rows + 8 `budget:*` rows + 4 evidence rows (`convert-start-dir`, `treestart`, `untracked-start`, `ac2-inventory`); snapshot sha `c08b1ee8…` recorded in the token-protocol ledger at step 1.
- Treestart: 1220 tracked paths (= `git ls-files` count), incl. 18 `MISSING` rows (6 symlinks recorded non-regular + 12 pre-existing HEAD-vs-worktree deletions = recorded dirt); untracked-start: 67 files, all content-identical at finalize.
- Budget canonicalisation RECOVERED (not invented): `jq -c -S <selector>` with the final newline stripped, sha256 over the bytes — proven byte-identical on all 8 frozen rows (see Decisions D1).
- Canon target for both AC2 canons is `workflow/spec.md`, systematic only in `spec-map` — the availability intersection fails on every other route, hence the empty CONVERT set (expected honest outcome per the plan's T8 AC4-economics precedent).

## Decisions

### D1 — Budget canonicalisation recovered as `jq -c -S` sans newline final

- Context: the 8 frozen `budget:*` snapshot rows needed a byte-exact recomputation rule for the step-7 gate.
- Choice: `jq -c -S '.version' | tr -d '\n'` for `version`, `jq -c -S '.surfaces["<name>"]' | tr -d '\n'` per surface, sha256 over the bytes. The gate implements exactly this (jq emits the canonical bytes; one trailing `\n` stripped — equivalent to `tr -d '\n'` on single-line `-c` output).
- Rejected options: inventing a new canonical form (rejected — would break ledger-anchored rows); hashing pretty-printed JSON (rejected — whitespace-sensitive).
- Rationale: reproduced all 8 snapshot hashes byte-identically (`6b86b273…`, `9f58cd49…`, `85580523…`, `e223d41d…`, `f819f763…`, `700dfd03…`, `372fdf70…`, `b2d1b251…`).
- Consequences: the gate's budget compares are ledger-anchored; any frozen-entry drift fails loudly.

### D2 — Gate universe = git tracked + git untracked (ignored out of scope, as step 1)

- Context: ignored paths (`.workflow/`, `.pi/`, …) were never captured at step 1 and cannot be policed by hash compare.
- Choice: the gate enumerates `git ls-files` ∪ git-untracked non-ignored files; the ledger is covered by the `snapshot_sha` anchor + explicit ledger-append-path allowlist entries.
- Rationale: mirrors the step-1 capture semantics exactly; a filesystem walk would flag ignored runtime state as foreign.
- Consequences: token-protocol foreign-file detection stays exact (95-leaf equality); ignored runtime files remain out of scope by construction.

### D3 — `MISSING` treestart rows pass iff still not-a-regular-file

- Context: 18 treestart rows hold `MISSING` (6 symlinks + 12 pre-existing deletions); step 1 recorded no finer state.
- Choice: `MISSING` fails only if a regular file exists at the path now (reappearance or symlink→file swap); absence or still-a-symlink passes.
- Rationale: strongest rule expressible from the recorded value; pre-existing deletions stay recorded dirt, never failures.
- Consequences: all 18 pass; the rule is covered by a gate self-test fixture.

### D4 — Empty CONVERT set shipped (no availability-breaking pointer)

- Context: the availability intersection (target ∈ always-on ∪ ∩ systematic files of EVERY consuming surface) fails for all 4 non-frozen, non-pointer occurrences.
- Choice: convert nothing; ship the inventory + linter + exact-grandfather tripwire + deferred-with-reasons; convert-start/ stays empty-exact.
- Rationale: T8a must never ship an availability-breaking pointer; the plan names this the expected honest outcome.
- Consequences: AC2 closes with 0 conversions and 4 KEPT-FOR-T8b (1 frozen-file + 3 target-availability), all recomputed clean by the diff check.

### D5 — supply-chain-smoke baseline-red accepted (no fix attempted)

- Context: `tests/supply-chain-smoke.sh` expects exactly 3 `actions/checkout@` steps; the worktree file has 2 (HEAD has 3).
- Choice: accept the red as baseline (T1–T7 dirt), attest it, fix nothing.
- Rationale: the file is byte-identical to its treestart sha (`359940c3…`); editing it would violate the TREE RULE allowlist (see Decision Log).
- Consequences: core battery 35/36 with a baseline-red attestation; 0 T8a regressions; the fix belongs to the tranche that owns that dirt.

## Per-Occurrence Attestations (equivalence + availability)

Inventory `tests/fixtures/token-protocol/ac2-inventory.json` (8 occurrences). All occurrence files are byte-identical to step 1 (gate-verified: the only tracked diffs tranche-wide are `context-budget.json` and `agentic-infra-checks.tsv`).

| # | File:lines | Canon | Verdict | Equivalence attestation | Availability attestation |
|---|---|---|---|---|---|
| 1 | workflow/spec.md:98-102 | check-freeze | canon | IS the canon text; T8a untouched (not in treestart diff set) | N/A (canon home) |
| 2 | workflow/spec.md:130-145 | ready-gate | canon | IS the canon text; T8a untouched | N/A (canon home) |
| 3 | workflow/skills/plan-loop.md:66-67 | ready-gate | pointer (pre-existing) | Pre-existing pointer sentence kept verbatim; file frozen (AC5 row re-hash green) | N/A (no conversion applied in T8a) |
| 4 | workflow/skills/implementation-loop.md:35-36 | check-freeze | pointer (pre-existing) | Pre-existing pointer sentence kept verbatim; file byte-identical to step 1 (`start_sha` match in diff check §5) | N/A (no conversion applied in T8a) |
| 5 | workflow/skills/implementation-loop.md:41-44 | check-freeze | KEPT-FOR-T8b / target-availability | Copy retained verbatim (no semantic change possible — bytes unchanged) | DEFERRED: spec.md not systematic in plan-implement/implement/ship; intersection lacks the target — a pointer would break ship-route readers. Recomputed clean. |
| 6 | workflow/skills/plan-loop.md:61-66 | ready-gate | KEPT-FOR-T8b / frozen-file | Copy retained verbatim inside an AC5-frozen file (bytes unchanged) | DEFERRED with the T8b contract rewrite (frozen-file rule). Recomputed clean. |
| 7 | workflow/contract-details.md:136-142 | check-freeze | KEPT-FOR-T8b / target-availability | Copy retained verbatim (bytes unchanged) | DEFERRED: ship-route conditional readers (long-rules lookup) lack spec.md (itself conditional there) — pointer not guaranteed resolvable. Recomputed clean. |
| 8 | workflow/agent-quick-card.md:50-52 | check-freeze | KEPT-FOR-T8b / target-availability | Copy retained verbatim (bytes unchanged) | DEFERRED: spec.md not in always-on; every always-on reader would pay an extra read. Recomputed clean. |

Scope verdict (inventory): no other canon-substance copies in scope; mere term mentions excluded with cause (ship.md:233, linear-work.md:6/35, contract-details.md:196, adversary.md:27-40, PLAN_TEMPLATE.md:33, status words).

## Trial Summary (AC3-measure, $0, read-only, no branch taken)

Committed at `tests/fixtures/token-protocol/trial-2026-09-25.json`: status `ok`, N=11 spawned sessions, spawnless_count=22 (excluded + counted per protocol).

| File | Pre-review % | Startup | Pre-review | Review |
|---|---|---|---|---|
| workflow/review-rubric.md | 0 | 0 | 0 | 0 |
| workflow/skills/review.md | 36.4 | 0 | 4 | 0 |
| workflow/templates/review-logic-hunter.md | 18.2 | 0 | 2 | 0 |
| workflow/templates/review-spec-hunter.md | 18.2 | 0 | 2 | 0 |
| workflow/templates/review-lead.md | 9.1 | 0 | 1 | 1 |
| workflow/templates/plan-archive.md | 0 | 0 | 0 | 4 |

No branch taken in T8a either way (per plan). T8b applies the <20% per-file rule against its own campaign-time measure.

## Census (READ-ONLY recount, zero tracked writes)

`scripts/workflow-ledger-census baseline /tmp/t8a-census.tsv` (output outside the repo): 113 ledger slugs — 95 OK, 18 QUAR (all grandfathered, no FAIL). `token-protocol` verdict OK (validates; append-only growth across the tranche).

## Accepted Drift

- Original plan/spec: core battery 36/36.
  Implemented reality: 35/36 — `supply-chain-smoke` red on a pre-existing checkout-count skew (worktree 2 vs expected 3), file byte-identical to treestart.
  Why accepted: T1–T7 dirt; any fix would violate the TREE RULE allowlist; attested baseline-red with 0 T8a regressions and 4/4 new rows green.
- Original plan/spec: AC2 ships a converted-safe-subset of pointers.
  Implemented reality: CONVERT set vide — all eligible occurrences defer on availability.
  Why accepted: the plan's stated expected honest outcome; shipping any pointer would have broken route readability.

## Validation Evidence

- command: `scripts/workflow-context-budget`
  - result: exit 0 — 8 surfaces green (always-on 13647/16635, plan-loop 6458/6458, plan-implement 66538/68268, implement 60925/62476, review 22727/22727, verify 3812/3812, spec-map 33658/34668, ship 89633/89633 = measured).
- command: `scripts/ship-coverage-check`
  - result: exit 0 — required refs all listed; exclusions classified; self-test 11/11 fixtures as expected.
- command: `scripts/verify-agentic-infra core`
  - result: 35/36 — SUMMARY: 1/36 failed: supply-chain-smoke (baseline-red, attested); PASS canonical-copy, prompt-order, hunter-parity, pointer-follow.
- command: `bash tests/canonical-copy-smoke.sh`
  - result: exit 0 — ok (51 scope files, 4 KEPT ranges matched by 4 phrase hits, 0 unexpected).
- command: `bash tests/prompt-order-smoke.sh`
  - result: exit 0 — PASS (characterization: template via --append-system-prompt, patch via @file, --patch-first absent + T8b-flip comment; coverage PASS).
- command: `bash tests/hunter-parity-smoke.sh`
  - result: exit 0 — part (a) PASS (offline, zero paid calls); part (b) SKIPPED (economic campaign NONRUN — T8b scope).
- command: `bash tests/pointer-follow-smoke.sh`
  - result: exit 0 — part (a) PASS (STRONG positive + 6 negatives + dossier/archive oracles); part (b) SKIPPED (no deferrals, no paid replays — T8b scope).
- command: `scripts/token-protocol-screen --dry-run … --provider fake-must-fail --out $TMPDIR/t8a-dryrun` (full AC3 invocation)
  - result: exit 0 — "0 provider calls", both worktrees validated; tamper/freeze/out-dir refusal fixtures each nonzero (bundle self-tests).
- command: `scripts/token-protocol-screen --validate-corpus …`
  - result: exit 0 — 8 fixed + 8 variant bodies resolved and attributed.
- command: `scripts/token-protocol-screen --resolve-all --corpus …`
  - result: exit 0 — 16/16 bodies resolved (8 fixed + 8 variant).
- command: `scripts/token-protocol-screen --resolve-all --flow economic --manifest …`
  - result: exit 0 — 6/6 parity patches resolved.
- command: screening linkage (`--local-run` fake-canned → report → oracle)
  - result: exit 0 — report prints exactly {150 tokens/task, $0.0002/task, 0.0} BOTH variants; oracle PASS (zero flips); tampered-compare + malformed-artifact refusals nonzero.
- command: economic linkage (`--local-run --flow economic` → report → `--check-parity`)
  - result: exit 0 — 12 canned runs; report {150, $0.0002, 0.0} both variants; parity 6/6 pass, variants agree (REAL parser on all 12); 5 refusals + cross-flow feed nonzero.
- command: `bun test tests/token-noninferiority.test.mjs`
  - result: 21 pass, 0 fail (incl. 1-in-3 veto, margin edges, INCONCLUSIVE-on-INVALID ordering).
- command: `scripts/token-task-report --artifacts tests/fixtures/token-protocol/report/valid`
  - result: exit 0 — baseline {4000, $0.0045, 0.25} + candidate {4000, $0.004, 0.5} over exactly 4 rows.
- command: report refusals (ceiling / resources / missing-usage / tampered-reference)
  - result: exit 1 / 1 / 2 (INCONCLUSIVE pinned) / 1 — all as expected.
- command: `bun test tests/token-finding-parser.test.mjs`
  - result: 12 pass, 0 fail (pinned pp-null-deref block + No-findings + rejections + lead-dossier-BLOCKS F1+F2).
- command: `scripts/token-corpus-check`
  - result: exit 0 — 91 manifest entries verified, 8+8 bodies, 16 prompt bodies, freeze + reference covered, dossier fidelity 2/2, archive sections pinned; tamper → nonzero.
- command: `scripts/parent-read-measure --traces <dir> --json` (synthetic edge fixtures + $0 real-trace trial)
  - result: schema `{status, n, per_file, spawnless_count}`; spawn#1 / spawn-less / pre+post green; trial committed (`ok`, N=11), no branch taken.
- command: `scripts/t8a-pointer-diff-check` (full pinned invocation)
  - result: exit 0 — ledger-anchored capture integrity + 0 CONVERT green + 4 KEPT re-verified + availability clean; 6 tamper fixtures each nonzero (diff-check self-tests).
- command: `scripts/t8a-pointer-diff-check --verdict-only` (availability-split)
  - result: prints KEPT-FOR-T8b reason target-availability for the split row.
- command: `scripts/t8a-behavior-gate --self-test`
  - result: 25/25 fixtures as expected (positive green + 24 negatives: budget row, extra/missing surface, top-level key, snapshot tamper, ledger mismatch, ready-gate created, out-of-allowlist modification, foreign in-tree file, unlisted new file, tracked/untracked deletion, checks 5th-line/target-swap/prefix-edit, dirtied untracked, trial 0/2, convert-start stray, archive 0/2, MISSING-reappearance, treestart tamper, manifest leaf deletion).
- command: `scripts/t8a-behavior-gate` (FINAL, after archive finalize + ledger wiring)
  - result: exit 0 — "0 frozen bytes changed — 14 files + 8 budget rows" (14 re-hashed + ledger anchor + 8 budget rows + surface set + ready-gate absent + tree allowlist + 95-leaf equality + exactly-one trial/archive).
- command: `scripts/t8a-pointer-diff-check` (FINAL, last run after the last write)
  - result: exit 0 — ok.
- command: `bun test pi/extensions/__tests__/`
  - result: 361 pass, 0 fail.
- command: `scripts/workflow-ledger-census baseline /tmp/t8a-census.tsv`
  - result: 113 slugs, 95 OK + 18 QUAR, token-protocol OK; zero tracked writes.

## T8b Handoff (ALL ITEMS BELOW: NON-EXECUTED WITHOUT VERDICT)

T8b input draft: `docs/plan/20260925-t8-full-draft.md` (sha256 `ea6197703dbded479e28967ad8613ad072f4c4558c679865abac42ef49d0a181`) — own plan + billing authorization required before anything below runs.

Frozen starting point (T8b MUST re-verify fingerprints before its first paid run):

- corpus-manifest.json `d0a59fb0…` · freeze-record.json `3ae116bf…` · corpus.json `60b54bcc…` · parity-manifest.json `8e43543c…` · slot-criteria.json `31128f1c…`
- `scripts/token-corpus-check` exit 0 + `scripts/t8a-behavior-gate` exit 0 re-run at T8b step 1.

Billing checkpoint (per spec.md:108): ALL paid campaigns share ONE cap of $25 AND 45 min wall-clock (screening 72 + economic 36 + lead/archive ≤12 runs); order screening → lead/archive replays → economic; a campaign launches iff its FULL estimated cost fits the REMAINDER (no half-campaign); unfunded → clean NONRUN per the master decision table. Absent authorization → no paid runs, behavioral verdicts INCONCLUSIVE without running.

Campaigns (NON-EXECUTED WITHOUT VERDICT):

1. Screening (72 runs): `scripts/token-protocol-screen --corpus tests/fixtures/token-protocol/corpus.json --tasks 12 --runs 3 --variants baseline,candidate --seed <freeze-seed> --baseline-tree <wt> --candidate-tree <wt> --out tests/fixtures/token-protocol/runs/<date>` → report + noninferiority oracle verdict (PASS/FAIL/INCONCLUSIVE/NONRUN per the master table). NON-EXECUTED WITHOUT VERDICT.
2. Economic (36 runs): `scripts/token-protocol-screen --flow economic --manifest parity-manifest.json --tasks 6 --runs 3 --variants baseline,candidate --seed <freeze-seed> … --out …-econ` → `--check-ceiling` + `--check-resources` + `--check-parity` verdicts. NON-EXECUTED WITHOUT VERDICT.
3. Lead/archive owner-path replays (only for actually-deferred files, ×3 runs each, UNANIMOUS exact invariants): `tests/pointer-follow-smoke.sh` part (b). NON-EXECUTED WITHOUT VERDICT.
4. T8b contract rewrite: plan-loop.md rewrite, `workflow/ready-gate.md` generation + `--check`, `--patch-first` Logic flag, review.md pointers, `pointer_follow` ledger wiring, T2/T3 surface edits, frozen-file conversions (incl. plan-loop.md:61-66). NON-EXECUTED WITHOUT VERDICT.
5. Paid decision table: the v25 master decision table (measure × quality × parity × cost × smoke) is REFERENCED, never a T8a closure condition.

Expected-UNCLAIMED note (AC4-economics): the shipped Logic-only flow shares no cross-axe prefix, so verdict (ii) ($/task ≤ 0.9× baseline) will likely FAIL or go INCONCLUSIVE → reorder UNCLAIMED + revert is the EXPECTED honest outcome; T8a's shipped value is the instrumentation + proven verdicts.

## Roadmap Slice

- Roadmap row 8 = "T8a shipped, T8b planned" (partial flip, honestly labeled; recorded here per the T6/T7 precedent — no separate roadmap file exists).

## Follow-up State

- Remaining risks: supply-chain baseline-red persists until the owning tranche fixes the checkout skew; ignored-path runtime state (`.pi/`, `.workflow/`) stays outside the AC5 gate by construction; T8b campaign cost must fit $25/45min or campaigns go NONRUN cleanly.
- Parking lot: 298-run confirmation + 149-pair manifest (future work, unchanged); multi-axe prefix deployment (own parity burden).
- Superseded docs/specs: none (T8-full v25 draft retained as T8b input, not superseded).
- Next links: T8b plan (own plan from the v25 draft + this handoff; billing authorization required); roadmap tranche 8 completion after T8b verdicts.

## Decision Log

- 2026-09-25: T8a implement — supply-chain-smoke BASELINE-RED attested (REQUIRED entry): worktree `.github/workflows/agentic-infra.yml` carries 2 `actions/checkout@` steps vs 3 at HEAD; the file is byte-identical to its step-1 treestart sha (`359940c34ab858591e81cfa9ff6aa2581cacca6df0c2d42d556ef96463c80142`) — the skew is T1–T7 dirt, and any fix is forbidden by the TREE RULE (file outside {context-budget.json, agentic-infra-checks.tsv, CONVERT=∅}). Battery outcome: core 35/36 with baseline-red attestation, 0 T8a regressions; the 4 new Scope-pinned rows (`canonical-copy`, `prompt-order`, `hunter-parity`, `pointer-follow`) are all green. Fix ownership: the tranche that owns that dirt.
- 2026-09-25: T8a implement — budget canonicalisation recovered as `jq -c -S` sans newline final, proven on all 8 frozen rows; no new method invented.
- 2026-09-25: T8a implement — AC2 CONVERT set vide shipped with exact-grandfather tripwire; availability-breaking pointers refused by design.
- 2026-09-25: T8a implement — gate self-test 25/25 (git sandboxes in $TMPDIR); FINAL behavior-gate + pointer-diff-check both exit 0 after the last write; census read-only (113 slugs, 95 OK / 18 QUAR, token-protocol OK).
- 2026-09-25: T8a implement — $0 real-trace trial committed (`trial-2026-09-25.json`, status ok, N=11, spawnless 22); no branch taken.
