# Implemented: Portable project verification and trust

## Metadata
- Archived: 2026-10-03
- Source plan: `PLAN.md` — portable project verification and trust
- Source plan SHA-256: `231279c1565e65a74a00a3a38d17872a6fd5ed300150c8a5946d25c865a21b48`
- Status: IMPLEMENTED
- Commit / branch: local uncommitted isolated worktrees; owner detached `8b523a5425eaa7e10480f3690e9b47fe9a5abd99`; Starter satellite detached `55e72e8d1c488979a08bb8cb54d03e7188c2c382`
- Workflow initiative: portable-project-trust-20261003

## Outcome

Verified local implementation in two isolated worktrees. Etabli now supplies a portable verification producer and a normal planning/implementation sequence: discover existing checks, prepare missing project-owned assertions, execute affected behavior, retain source-bound observations, and close required product plans only after independent checking. New templates use `Required: auto`; uniquely classified product criteria activate proof. The deterministic baseline needs no provider credential. Optional agent engines have explicit argv/provider/model and credential environment names, and never replace deterministic verdicts.

| Criteria | Implemented boundary | Evidence |
| --- | --- | --- |
| AC-01–02 | Auto classification, READY/freeze/closing gates, shared workflow sequence | templates, product-verification docs, focused gate tests |
| AC-03 | Discovery and create-only `verification/recipe.json` bootstrap | recipe tests and deployed CLI |
| AC-04 | Source snapshot, argv receipts, owned process lifecycle, typed result/persistence assertions | runner tests and actual CLI/Chromium packs |
| AC-05 | Explicit optional engine, names-only preflight, credential/output isolation | engine sentinel and zero-exit-wrong-result tests |
| AC-06 | Complete helper/schema/example deployment and preserved project recipe | scaffold smoke and historical receipt recheck |
| AC-07 | Required UI/viewports, declared persistence, final synchronous source/artifact identity | checker tests and real unlink/write boundary regressions |
| AC-08 | Starter parallel branch exits and retained browser failure artifacts | 16 CI wrapper cases and workflow artifact path |
| AC-09 | Four actually deployed product fixture paths, own Git sources/READY plans/ledgers | demos/FD/results.json |
| AC-10 | Independent full Logic/Spec, Standards, native cross-family review, simplify/quality and closing protocol | final review reports and owner events.jsonl |

## Context

The existing shared checker already linked product criteria, sources, environment, phase receipts and completion. The missing reusable producer and opt-in template default prevented automatic adoption across projects. Starter supplied concrete QA but its parallel CI branch groups could return zero after a failed command. Both original checkouts were dirty; all implementation stayed in isolated worktrees. The owner controls workflow infrastructure, so its criteria are process/judgment; actual product-required completion is demonstrated on independent disposable applications, without falsely mapping their business behavior to owner infrastructure criteria.

## Decisions

### Project-owned assertions, shared deterministic authority

The recipe remains versioned project source. Bootstrap never overwrites it or invents coverage. Missing classifications, mappings, paths, timeouts, readiness or result/persistence oracles fail with remediation. The checker re-reads preserved raw JSON and typed RFC6901 expectations independently, tied to the exact recipe/source/command receipts. Legacy explicit yes/no/missing declarations remain compatible; new auto product contracts require the assertion protocol.

### Owned execution and conditional engines

Commands use argv without a shell and run in an owned regular-file source snapshot. Installed dependencies must be explicitly selected and recorded. Real process groups are terminated/reaped before and after cleanup hooks, including failed launch/readiness/timeout/interruption. Service leader death is latched on `exit`, independently of descendant-held pipes; a synchronous kernel-state check also catches zombie/absent leaders before intended shutdown when JS event delivery is delayed. Cleanup cannot retroactively turn an observed prior death into intended shutdown. Credential values and engine stdout/stderr are excluded from exported proof. Configured provider/model fields mean requested metadata; they do not attest effective model execution.

### Deployment and compatibility

`deploy-workflow` distributes the runner, all imported modules, schema and examples with matching Git exclusions. It preserves the versioned project recipe and observation helper. Existing projects need scaffold redeployment after integrating this patch; no installed/global deployment or push occurred. Historical Starter completion evidence passes the fresh checker against its current matching source, but that recheck is not a fresh Starter browser execution.

## Accepted Drift

Claude review attempts were unavailable because of quota. The configured direct native Pi xai/grok-4.7 route provided actual cross-family plan/code reviews; effective provider/model come from native records, never reviewer prose. Existing installed Playwright 1.62.1/Chromium and TypeBox were explicitly reused; cold dependency installation was not demonstrated. A pre-existing optional broken `session-handoff` reference was removed from the contract-details prose to restore the reference gate without weakening handoff requirements or raising context ceilings.

## Validation Evidence

Evidence base: `.workflow/portable-project-trust-20261003/` in the owner worktree.

- `node --test tests/project-verification-check.test.mjs tests/project-verification-assertions.test.mjs tests/project-verification-recipe.test.mjs tests/project-verification-run.test.mjs`: **151/151**, zero failed/skipped; `focused-FD.log`.
- `scripts/verify-agentic-infra core`: **31/31**, including **444** Pi tests and **41** portable assertion/recipe/runner cases; `core-FD.log`. These cases overlap the focused set; counts are not additive.
- Isolated Starter `node --test scripts/tests/ci-wrappers.test.mjs`: **16/16**; `/tmp/starter-ci-parent-final.log`. Controlled failures propagate, sibling branches finish, all-zero branches stay zero. No remote CI or live Docker integration is claimed.
- `tests/project-verification-e2e.sh` with explicit `ETABLI_TEST_PLAYWRIGHT_PACKAGE=/Volumes/Crucial/work/adonisjs-starter/apps/web/package.json`: **4/4 expected control outcomes**, `e2e-FD.log` and `demos/FD/results.json`. Positive CLI and actual Chromium web runner/checker/archive/completed return0. Both negative result commands return0, but runner/checker/archive event/completed return1 and cleanup helper2. All owned cleanup passes; negative PLANs stay present.
- Service leader regression: **0/1 before** (`service-leader-before.log`, missing expected rejection), **1/1 after** (`service-leader-canonical.log`); unexpected exit retained, owned_shutdown false, execution1, group reap/runtime removal observed, PLAN retained.
- Deferred service exit regression: **0/1 before** (`deferred-before.log`), **1/1 after** (`deferred-after.log`); actual zombie leader before cleanup is unexpected, owned_shutdown false, descendant group reaped.
- `tests/plan-check-freeze-smoke.sh`, `tests/workflow-scaffold-smoke.sh`, `tests/workflow-event-smoke.sh`, `tests/agentic-infra-manifest-smoke.sh`: passed; their named parent-final logs retained.
- `scripts/workflow-ref-linter`: all clean. `scripts/workflow-context-budget --json`: every original ceiling passes, `context-parent-final.json`. `git diff --check`: both cumulative worktree patches clean.
- Historical `trust-claude-publish-final-20261002` completion receipt/archive passes current checker; source SHA `7c8b52635d36fe32960f927746239b07b898dfc31d5c91715e4b15216583ace3`.
- `simplify: removed 2`: unnecessary private command options removed; shared owned-directory ancestor checks reused. Standards compared three existing siblings; `quality-parent.md` records the producer and cumulative pin.

## Review Evidence

High-risk review completed on cumulative51file pin `cec5aa3240b0fdb7811b35fab34222b9163da9e0e4b15c5080b4151f861cd443`, with owner/satellite baselines above. Final F2 uses fresh isolated Logic and Spec hunters; Logic supplies all **8 lenses** and **45 runtime deciding-code rows** with meaningful outside-patch callers/resolvers. Lead copied those tables unchanged; `review-logic-F2.md`, `review-spec-F2.md`, `review-lead-F2.md`. Parent Standards compared three existing siblings and refreshed the same conventions after each accepted process fix.

Native cross-family plan adversary finished READY (`01a0ff4c-8459-712b-9083-d1607000f50b`). Native code adversary ran **Pi xai/grok-4.7**, effective provider/model independently extracted from native records. Full final F2 is **GO / no findings**, run `01a0ff95-0493-74a1-b2b8-049718072784`; exact raw report `code-F2.report.md` and provenance `code-F2.provenance.json`. Plan failures from unavailable Claude quota never count as completed reviews.

Bounded sequence: T1 findings → T2 clean → F1 findings → FD clean (consumes D1) → F2 clean. T1 accepted a leader exit hidden by descendant-held pipes and fixed an independent exit latch; F1 accepted physically dead leader while its JS exit event was queued and fixed kernel-state reconciliation before owned shutdown. Both HIGH findings were corroborated by native cross-family arbitration and real before-failing/after-passing regressions. FD delta adversary `01a0ff92-24c5-763b-8003-331b20582362` returned GO. Rejected declaration-error candidate was independently cross-model refuted against actual guards/reproductions; rejected medium upload-guard candidate was disproved by the unchanged `if: failure()` guard. No surviving finding or review-budget re-entry remains.

## Follow-up State

- Remaining risks: semantic AC classification and oracle relevance require review. Evidence attests declared scenarios under cooperative local execution; it is not universal product correctness or malicious same-user attestation. No optional product engine or GLM provider success is claimed from fixture tests.
- Adoption: integrate both local patches, then deploy the updated workflow into existing projects and adapt each project recipe to its real affected flows. Existing user recipes are preserved. These publication/deployment actions remain separate.
- Preservation: Starter original status digest unchanged. Etabli's original44 status entries still match the baseline after excluding a newly observed unrelated `docs/plan/20261003-execution-quality.md`; that concurrent artifact is preserved. Earlier owner audit is preserved outside the implementation review pin.
- Closing: the single owner archive is bound to the exact final root PLAN hash. `scripts/plan-cleanup --archive` and the autonomous-completed owner ledger are the final closure checks; their records remain in the evidence base. The satellite owns no duplicate plan/archive.
