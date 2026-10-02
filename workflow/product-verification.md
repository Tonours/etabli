# Product verification

Open only when a plan declares required product evidence.


## Product Verification
- Required: no

For a product plan, set Required to yes, add `Evidence pack: .workflow/<slug>/evidence-pack.json` and `Subject root: <project-root>` as list fields, and classify every acceptance criterion with a unique `AC-ID [product|process|judgment]:` prefix. Product criteria declare `Proof: action,result.` or `Proof: action,result,side_effect.`. Freeze these fields before READY. Missing or stale product proof blocks implemented archive cleanup; process and judgment criteria still need their normal checks and review.

## Declared product plan evidence

When the READY plan declares `Product Verification` with `Required: yes`, run `scripts/project-verification-check PLAN.md` against its declared pack. Report the product AC IDs, action/result/persistence evidence, source identity, command exits and uncovered features. Failed, skipped, unavailable or stale proof blocks completion. A schema-valid file is insufficient without observed execution. Select the project's existing verification skill; Claude and Pi consume the same recipe. This check does not replace process/judgment validation, regression suites or the project quality gate.

Declared product plans must pass `scripts/project-verification-check PLAN.md` before `archive_written`. The shared ledger remembers product applicability at `plan_created`; `plan-cleanup --archive` reruns the check and retains a completion receipt bound to the frozen plan, archive, pack and current source. `completed` and the autonomous profile recheck it after root plan removal. Keep the plan when proof is failed, unavailable or stale. `--discard` records abandonment and cannot substitute for implemented completion. Plans without required product verification retain their existing closing behavior.

### Product completion metadata

`plan_created.detail.product_verification_required` is an optional boolean populated from the active plan by the helper on plan-backed run events (and archive append). For required product plans, `archive_written` additionally retains `product_verification_required: true`, absolute `product_verification_receipt` and `product_archive_path`. CI-only ledgers without a plan lifecycle do not inherit an unrelated active plan. The two path fields must occur together. Archive append checks the declared product pack; cleanup produces the receipt; terminal completion and the autonomous profile revalidate the receipt and current source. Applicability can be promoted after initial plan creation and remains remembered after root plan removal, so missing receipt metadata cannot silently opt out. Legacy non-product ledgers are unchanged.

## Evidence roles and identity

Action references must include an `action` artifact; result references an `outcome`; persistence an actual `side_effect`. Launch, doctor and isolation reference `execution_receipt` artifacts and cleanup a `cleanup` artifact. Phase receipts declare their `phases` (launch/isolation may share one receipt) and contain passed status and matching run/source identity. The aggregate execution receipt also binds the retained environment fingerprint and actual exit code. Missing, failed or unavailable observations cannot pass.

The project producer preserves a sorted inventory from fixed `git ls-files --cached --others --exclude-standard -z`, with copied file hashes/modes and Git HEAD. Fixed exclusions are `PLAN.md`, `.workflow/`, `docs/plan/`, ignored dependencies/runtime artifacts and private environment files. The checker reruns the same inventory and compares live files without executing project source. Artifacts use confined relative paths and must retain their content hashes. This protects accidental stale or incomplete proof in a cooperative local workflow; it is not an authenticated attestation against a malicious process with the same OS user. Assertions and independent review establish behavior, while hashes establish identity.

The foreground Starter QA command owns launch, doctor, auth/profile drivers, safe evidence production and cleanup. Use explicit criterion mappings from the frozen plan. Other features require their own executable proofs; successful auth cannot cover mail, invitations or billing. The default project skill is shared through Claude's canonical recipe and Pi's thin pointer.

Completion receipts retain the exact frozen plan bytes privately and compare the derived contract with them and the archive hash. This prevents independent edits to the stored criterion contract from weakening the original plan.

READY plan-backed events retain `product_verification_contract_sha256`, binding the declared pack, project root and frozen criteria. Completion checks the latest archive event itself, its declared archive path and this expected contract identity; it cannot reuse an earlier or foreign receipt. Nested acceptance details remain frozen under their parent criterion; additional product criteria use separate top-level AC IDs.

Capture and initial archive validation require the captured Git HEAD. Later completion revalidation permits a changed HEAD only when the complete source path inventory, bytes and modes still match; the original ref remains retained provenance. Committing the validated bytes cannot invalidate the archived receipt, while any source change still does.

`deploy-workflow` includes the checker, plan parser and shared schema. Schema validation resolves TypeBox from the Etabli Pi dependency tree or the managed `~/.pi/agent/npm` runtime. A missing dependency blocks validation; deployment does not install packages.

Invoke ledger commands from the project root, or set `WORKFLOW_EVENT_PROJECT_ROOT` explicitly when using `--dir` from another directory. `archive_written` participates in the plan lifecycle even without an earlier `plan_created`; ordinary CI ledgers have neither event. Versioned source symlinks are unsupported by this regular-file snapshot contract and block validation; supporting them requires an explicit producer/checker adaptation.
