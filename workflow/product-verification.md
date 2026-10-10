# Product verification

Open when planning or changing product behavior, preparing a recipe, or checking
required proof. Claude, Pi and other adapters share this sequence and checker.

## Applicability

New templates declare `Product Verification` with `Required: auto`. Every
top-level AC needs a unique `AC-ID [product|process|judgment]:` prefix. Product
criteria declare `Proof: action,result.` or `Proof: action,result,side_effect.`.
Freeze classifications, proof roles and paths before READY; progress may change.

| Declaration | Resolution |
| --- | --- |
| auto with any product AC | Required; source-bound recipe assertions mandatory |
| auto with only process/judgment ACs | Normal checks/review, no product pack |
| auto with missing/duplicate/unclassified ACs | Unresolved; blocks READY/closing |
| historical yes/no/missing | Existing explicit/non-product behavior retained |

Required plans add list fields `Evidence pack: .workflow/<slug>/evidence-pack.json`
and `Subject root: <project-root>`. Applicability can be promoted and remains
remembered by the ledger; once true, process-only edits cannot remove proof.
Retain proof or explicitly discard abandoned work. Unresolved DRAFT/CHALLENGED
events omit applicability rather than recording false.

## Prepare proof with the work

1. Discover launch, tests, environment and recipe. Run
   `scripts/project-verification discover` from the project root. Public metadata
   is a starting point, not proof of business coverage.
2. Map product ACs to observable actions/results, error boundaries and persistence.
   Reuse the project's framework/skills. Include missing setup, tests and
   observation commands in the task scope.
3. If absent, run `scripts/project-verification init`. It creates a project-owned
   `verification/recipe.json` and observation helper without overwriting files.
   Complete unresolved mappings, argv, timeouts and assertions before running;
   init never invents coverage. Examples live under `workflow/verification/`.
4. Exercise affected flows on owned test resources with
   `scripts/project-verification run --plan PLAN.md`. Retain failed cells and
   cleanup observations; human-only or unavailable legs stay `blocked`.
5. Run `scripts/project-verification-check PLAN.md` before archive. Report covered
   ACs, decisive observations, source identity, exits and gaps. Regression and
   quality checks still apply to process/judgment criteria.

`verify` only rechecks existing evidence; missing setup is inconclusive. It never
initializes, installs or repairs. Ambient instructions govern agent behavior;
helpers enforce gates when invoked, not arbitrary commands outside the workflow.

## Recipe and observations

The versioned recipe belongs outside `.workflow/`. Schema v1 names launch, doctor
and cleanup argv commands with explicit positive `timeout_ms`. Scenarios need
unique IDs, explicit product AC mappings, action/result commands and nonempty
assertions. Persistence has separate commands/assertions when declared or required.
An optional service has an owned process and readiness command.

Result/persistence commands print observed JSON only. RFC6901 `pointer` plus JSON
`expected` assertions use typed deep equality; absent values cannot equal null.
Observe actual state/DOM, never print expectations as observations. Exit 0 with a
wrong value fails. The checker independently reevaluates retained raw JSON against
the inventoried recipe at capture/completion, including mappings and assertions.

The runner executes shell-less argv in an owned regular-file snapshot; the live
subject root survives cleanup. Commands receive controlled `ETABLI_SUBJECT_ROOT`,
`ETABLI_RUN_DIR` and `ETABLI_RUN_ID`. Mutable state belongs in the owned runtime,
outside source bytes. Explicit installed dependency reuse retains identity and
makes no cold-install claim. Snapshot and origin must still match before capture.

Process receipts bind protocol `etabli-project-verification/1`, run/source/
environment/recipe hashes, argv, cwd, role, PID, timestamps, timeout and actual
exit/signal. Raw observations link to stdout hashes. Launch/doctor/isolation/
cleanup need actual passing observations. Services stay alive until intended
shutdown. Timeout/interruption bounds command closure with a 2-second shutdown
grace; cleanup starts its deadline before waiting for completion.
`ETABLI_CLEANUP_GRACE_MS` sets that deadline when the trimmed value is a
decimal integer from 1 to 2147483647 with no leading zero. Any other value,
including an unset variable, keeps the 10000 ms default.
Group signals require the observed live leader and its birth; after leader exit,
only captured member PIDs with rechecked births are signaled. A missing live
birth stays pending even after actual exit; an empty snapshot of that unanchored
group cannot prove reaping or authorize adopting a replacement. These sampled
observations are not an atomic kernel lease. If inherited pipes still block close,
the parent releases its pipe endpoints and retains `completion_forced: true`
with observed exit/signal fields, failed execution and incomplete reaping. The
checker rejects forced completion, including otherwise successful exit0 receipts.
Unknown detached children are not signaled or declared reaped. Cleanup is
attempted after failure and observes runtime removal; it cannot erase an earlier
failure. Historical receipts without the optional marker remain compatible.

## Optional engine

Deterministic proof needs no model/key. Optional engine config declares argv,
timeout, requested provider/model and credential environment **names**. Invoke
explicitly with `run --engine`, reusing an installed runtime. Preflight lists
missing config. Ask the user only if that selected engine needs configuration
they must supply; enter credentials locally through the secure runtime mechanism
or environment, never chat or recipe.

Only named credentials reach the engine; its stdout/stderr are omitted from
command evidence. Environment artifacts allow public tool/run identities and
credential names/presence booleans, never dumps or values. Provider/model fields
are requested metadata, not effective provenance. Engine success never replaces
deterministic assertions. Real provider execution needs its own runtime evidence;
test doubles do not establish it.

In CI, live engine proof is slow and billed, so it is opt-in. Run it on
default-branch pushes, manual dispatch, and pull requests labelled `trust`.
Read the label on pull-request pushes; do not add a `labeled` trigger, because
it would rerun every job. Deterministic checks still run on every push. Forks
and bots stay excluded.

## Evidence and UI

Action references include `action`, results `outcome`, persistence `side_effect`.
Launch/doctor/isolation use `execution_receipt`; cleanup uses `cleanup`. Aggregate
receipts bind environment and actual outcome. Declared persistence needs proof
even without the AC side-effect role.

Declare `mode: "ui"` explicitly on a web/UI recipe. Its `ui` section requires
boolean `responsive_in_scope`, `motion_in_scope`, `reference_in_scope`,
`not_applicable_reasons` and an `observation` command with argv, timeout and frozen
assertions. Omitted mode keeps legacy product behavior; UI is never inferred from
argv. Scope exclusions need reasons keyed by `responsive`, `reduced_motion` or
`reference`.

The UI command prints actual JSON: `checks` maps keyboard/focus/accessibility/
console/network to true observed checks, and `viewports` lists label/width/height.
Scoped responsive/reduced_motion/reference must also be true; responsive needs
two distinct observed sizes. False/missing observations fail even with exit 0 or
assertions that omit a mandatory check. The runner retains raw stdout and its
process receipt; the checker independently binds mode, scope, assertions, checks
and viewport metadata to the inventoried recipe and observed command. Cleanup
still runs on failure. Browser result proof alone does not cover these UI checks.

The deployed web example observes keyboard activation, black focus outlines on
white, accessible control names/roles, console/page errors, failed requests and
HTTP errors, and layout bounds at 1280×800 and 390×844 in Chromium. This bounded
accessibility sample does not certify WCAG conformance. Motion and visual-reference
checks are explicitly out of scope for this fixture.

## Identity and closing

The inventory uses fixed `git ls-files --cached --others --exclude-standard -z`,
hashes/modes and HEAD. Fixed exclusions include PLAN, `.workflow/`, archives,
ignored dependencies/runtime artifacts and private environment files. Source
symlinks block this regular-file contract. Artifacts use confined relative paths
and retained hashes. This prevents stale/incomplete proof in cooperative local
work; it is not authenticated attestation against a malicious same-user process.

READY events bind pack/root/criteria/assertion policy in
`product_verification_contract_sha256`. `archive_written` checks the pack and
retains paired receipt/archive paths. `plan-cleanup --archive` repeats validation,
retains exact frozen plan/archive bytes and rechecks source/artifact identity
synchronously before receipt write and PLAN unlink. Keep PLAN on failure.
`completed` and autonomous validation recheck after removal and cannot reuse an
older/foreign receipt. Later validation permits a new HEAD only with identical
full path inventory, bytes and modes.

Invoke ledger commands from the project root or set `WORKFLOW_EVENT_PROJECT_ROOT`.
CI-only ledgers without a plan lifecycle do not inherit another plan. Historical
Starter packs stay compatible; auth/profile proof covers those flows only.
Other features need their own executable observations.

## Deployment

`deploy-workflow` distributes runner/checker/libraries/schema/examples. It never
distributes or excludes project recipes/observers: these stay versioned and
inventoried. Existing projects need updated scaffold; review drift before force
redeploy. TypeBox resolves from Etabli Pi dependencies or managed Pi runtime;
missing dependencies block validation. Deployment never installs packages.
