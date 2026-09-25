# Ship Contract

End-to-end delivery of one task: plan, adversary, implement, checks,
fresh-context review, commit, push, PR, CI green. Invoked explicitly only —
never ambiently routed. Invoking it is consent for the branch push and PR
creation it describes, per the human-checkpoint rules in `workflow/spec.md`.

## Required Sequence

1. Isolate the run per `workflow/skills/worktree-isolation.md`: confirm the base
   worktree is clean, then create one dedicated worktree and branch named per
   `workflow/git-contract.md` (`<type>/<ticket-id>-<short-slug>`, slug 3 words
   max, whole name under 50 characters) from the default branch, or from the named
   parent branch when the user asked to stack. Never commit to the default
   branch directly. Refuse to start from a dirty base worktree unless the user
   names what to do with the existing changes.
2. Run every phase below inside that worktree. The run's root `PLAN.md` lives
   there, which is what keeps concurrent ship runs from sharing one plan.
   Open the ship ledger at the invocation root (durable — step 13 removes
   the worktree, not the root). The ledger slug is `ship-<branch-slug>`
   where `<branch-slug>` is the branch name lowercased with `/` replaced
   by `-` (`feat/ABC-123-x` → `ship-feat-abc-123-x`); the CLI slug
   alphabet is `^[a-z0-9][a-z0-9_-]*$`, so unsanitized branch names are
   rejected. On collision with a ledger opened for another branch (its
   opening record names a different `branch`), suffix `-2`, `-3`, … —
   one ledger per branch, never shared:
   `scripts/workflow-event --dir <root>/.workflow append ship-<branch-slug>
   file_changed '{"path":"<worktree>","change":"run ouvert","branch":"<branch>"}'`.
   No `route_decided`: `ship` is not a route, so the ship ledger opens
   directly on `file_changed`.
3. Run the full autonomous chain from
   `workflow/skills/implementation-loop.md`: understand, plan-loop, plan
   adversary, implement with tests, plan checks, simplification pass, quality
   pass, Logic+Spec lead review, code-diff adversary, archive, root
   `PLAN.md` cleanup.
   During implementation, make a checkpoint commit on the ship branch after
   each coherent slice whose focused checks pass — never staging `PLAN*.md`.
   Checkpoints are revert points on a squash-mergeable branch, not release
   history. The loop ledger closes here (autonomous-completed, terminal);
   ship-phase evidence goes to the ship ledger. Capture the archive hash:
   `shasum -a 256 <archive>` → ship-ledger `file_changed`. The archive is
   immutable afterwards (`plan-archive.md`): post-archive fixes live in
   the ship ledger + report, never rewritten into the archive.
4. Pre-commit pass on the cumulative branch diff, which the loop's per-slice
   passes never saw as a whole: sweep debug artifacts, leftover checkpoint
   scaffolding, and scope drift across slices; run targeted tests for the
   touched code. Skip only when the branch holds a single slice, and say so.
   Transfer the review budget first (cwd: invocation root): append to the
   ship ledger a `file_changed` carrier —
   `{"path":"<loop-ledger-dir>","change":"review budget transferred",`
   `"loop_ledger":"<loop-slug>","loop_head_sha":"<sha>",`
   `"consumed":{"T":<n>,"D":<n>,"F":<n>},"remaining":{"T":<n>,"D":<n>,"F":<n>}}`
   — with counts computed from the loop ledger's recorded review rounds
   (tour tags T1…F2 in the review evidence, plus FD counting as D;
   `remaining = {2,2,2} − consumed`). Ship-phase repeats consume the
   SAME T/D/F counter (each
   repeat decrements `remaining`; zero → `blocked`), no second budget.
5. **Thermo-nuclear quality review:** on the cumulative branch diff, run the
   `thermo-nuclear-code-quality-review` skill when it is exposed on the
   runtime's skill surface. Its bar is structural: no structural regression,
   no visible missed code-judo simplification, no unjustified file-size
   explosion, no spaghetti growth, no hacky abstraction. Findings fold like
   adversary findings — accepted ones are fixed, checks re-run, and the fold
   is recorded. When the skill is not exposed, record
   `thermo_nuclear: unavailable` and say so in the report; never skip
   silently. Record `thermo_nuclear: clean | findings:<n>-folded |
   findings:<n>-open | unavailable` (`-open` = known-unfixed: success
   profile forbids it, it routes to `ship-stopped`). Fold fixes, then
   commit them on the ship branch.
6. **Cumulative review gate:** on the FINAL diff including the step 4-5
   fixes, ensure a Logic+Spec lead review ran on
   `git diff <base>...HEAD` (merge-base with the PR base). Per-slice reviews do
   not satisfy this. Record `cumulative_review: <base>...HEAD @ <sha>` and
   `deciding_code: complete | incomplete | n/a` (`incomplete` routes to
   `ship-stopped`, like thermo `-open`).
7. Final sweep commit per `workflow/git-contract.md` (subject only, no body);
   never stage `PLAN*.md`. Closed content: review fixes + the metrics-row
   aggregate — nothing else. The archive must be committed no later than
   this sweep (record `archive_commit`). If the sweep touches code, enter
   the next unspent F round on the new SHA (positional machine: normally
   F2, a single full pass — clean→ship, findings→`blocked`; no F budget
   left → `blocked`); row-only generated records get a schema check.
8. Run the complete relevant `scripts/verify-agentic-infra` group on the final <!-- etabli-only -->
   diff per `workflow/skills/implementation-loop.md`. A red group blocks the
   push. Also run `scripts/workflow-ref-linter` (all targets); a red linter <!-- etabli-only -->
   blocks the push like a red group.
9. Push the feature branch and open a PR. The tree must be fully
   accounted before push: `git status --porcelain` empty is the clean
   case (delta = committed vs reviewed SHA); otherwise enumerate
   committed + unstaged + staged + untracked-impl per step 11 before
   pushing. Write the body per
   `workflow/pr-body-contract.md`: English, the project's template intact,
   placeholders filled, checklists unchecked, no AI attribution. The body
   answers **what changed, why, and how it was verified**, and stops there:
   three headings, 40 lines outside the template, no fourth section that
   repeats one of them. Draft it with the `write-direct` qualities — direct,
   concrete, zero filler, honest status; shortest sentence that states the
   fact; no throat-clearing, no restated context, no hedging. Then run the
   per-harness style chain below — prose qualities on every harness, skill
   invocation only where its contract allows PR bodies. Verified matrix
   (F12, partial — porting is a T7 entry item, not assumed here):
   Pi — prose only (pstack off, zero slop skills exposed, `deslop` is
   code-only); Claude — prose only (`write-direct` SKILL forbids PR
   bodies); Codex — `no-ai-slop` in detect mode (no PR exclusion in its
   contract; PR contract supplies audience/format/goal, so its conditional
   questions are satisfied; autonomous-compatible). Fold findings before
   publishing. State the
   stack explicitly when the base is not the default branch. Publish the
   dense version, then run that contract's non-ASCII check against the live
   body. The draft is not the evidence, the published body is. Record
   `pr_body_style` by chain: `write-direct` when the body was drafted with
   the write-direct qualities (every harness, prose or skill); `plain`
   when neither the qualities nor a style skill applied;
   `no-ai-slop-detect` when Codex ran the detect chain on top;
   `write-direct+unslop` only where an unslop contract allows PR bodies
   (today nowhere — pstack off — kept as a forward value). Record
   `pr_url: <published URL>`. T7 entry criterion (verifiable): the F12
   fallback closes per harness only when a style skill whose contract
   allows PR bodies exists there, its load-check is green, its
   detect-mode pin holds, and a receipt (draft, invocation, findings,
   pre-publication decision) is recorded.
10. CI: follow the `ci-fix` contract until checks are green, blocked, or
   capped. Budget is cumulative per PR across re-loops: ledger segments
   `ci-fix-<PR>-r<n>` (one ledger per loop — a terminal ledger cannot be
   reopened), GLOBAL deadline t0+45min (t0 = first segment's first ts;
   no fresh clock at preflight), attempts = Σ CI-result events across
   segments ≤ 5. Pre-loop gate: <5min left or attempts exhausted → refuse
   (capped). Record `ci_state: green | capped | blocked | not-run`.
11. After CI-driven commits that touch runtime code: **delta re-review**.
    Delta = ancestry test (`git merge-base --is-ancestor <reviewed-sha>
    HEAD`, fail → full review) + `git diff --numstat -z <reviewed-sha>
    HEAD` + unstaged (`git diff --numstat -z`) + staged (`git diff --cached
    --numstat -z`) + untracked impl (`git ls-files --others
    --exclude-standard -z`, minus `*.log`/`*.tmp`/`.DS_Store`, full
    `wc -l`; unreadable → full review); staged/unstaged numstat that
    fails to parse (unreadable output) → full review as well; any
    status change after enumeration → recompute. Lines = Σ added+deleted. Binary (`-`),
    ambiguous rename, or unclassifiable → full review. Escalate to a
    FULL review (hunters + adversary) when delta > 50 lines (heuristic:
    past it, partial re-read no longer beats full; any doubt → full),
    or it touches contractual surfaces (`workflow/`, `scripts/`,
    `tests/`, `skills/`, `pi/skills/`, `claude/scopes/`, `.github/`,
    `AGENTS.md`, `PLAN_TEMPLATE*.md`, `docs/`, `.mcp.json`, locks,
    `*.policy.json`), or any rebase happened (proof invalidated).
    Generated-records row-only deltas (closed list: `review-metrics.md`;
    `skills-lock.json`, `*-promotion.json`, `*-policy.json` — today the
    jev route-capsule instances — with every changed fingerprint
    recomputed from its pinned source — lock via the verify procedure,
    promotion via sha256 of the pinned files, manifest via sha256 of
    the file — and the rest identical over canonical `jq -S` parsed
    values) get a schema check. Negative pin: a lone changed
    fingerprint that does not recompute from its source → FULL review.
    Otherwise Logic hunter on the new diff only, justified:
    post-full-review small delta.
    Record `delta_rereview: yes|no|n/a`. Compare and record base/HEAD/
    push SHAs before deciding.
12. If reviewer or bot feedback already exists on the PR when CI settles,
    report it; treating it is a separate explicit request. Defects found
    **after** an internal GO (reviewer, colleague, CI, production) must be recorded
    with `workflow/templates/escaped-defect.md` before the miss is treated as
    closed. **Update** the registry (`.workflow/ship-metrics/<run-slug>.json`
    at the invocation root: `{run_slug, pr_url, verdict, models[],
    deciding_code, escaped_later, buckets}`) under `flock`, and refresh
    the aggregate row — never a second row. Ship ledger events are the
    frozen detailed receipt; the registry is the mutable one; the public
    table keeps synthetic aggregates only, keyed by run slug (PR↔row
    correspondence lives ONLY in the registry).
13. Remove the run's worktree, or report the path and why it was kept, per
    `workflow/skills/worktree-isolation.md`.
14. Report: branch, commits, PR URL, CI state, archive path, worktree cleanup
    status, `cumulative_review`, `delta_rereview`, `reviewer_model`,
    `adversary_model` (or `same-family-pass: double-sample`), `thermo_nuclear`,
    `pr_body_style`, `deciding_code: complete|incomplete|n/a`,
    `escaped_defects_recorded: 0|<n>`, remaining risks. When the branch carries
    checkpoint commits, say the branch is squash-merge-only so its checkpoints
    never become history. Re-check the archive hash from the branch
    (`git ls-tree <archive_commit> docs/plan/<f>`, then `git show
    <archive_commit>:docs/plan/<f> | shasum` vs the captured digest;
    divergence → `blocked`). Then emit `ship_completed` to the ship ledger
    (success form, or arrêt form + `blocked` when stopped). Arrêt
    `not-reached:<step>` mapping (normative, jq-enforced): `cumulative_review`
    → step 6, `thermo_nuclear` → step 5, `pr_body_style` → step 9,
    `delta_rereview` → step 11, `deciding_code` → step 6. Step numbers
    refer to this Required Sequence; renumbering the steps requires
    updating the mapping, the jq, and the pins together.
15. **Metrics record:** the aggregate row (`run=<slug> | 0 | 0 | 0 |
    unmeasured` drafted pre-review) travels in the branch diff, reviewed as
    content; at GO it is filled and committed in the sweep (code→full
    re-review, row-only→schema check); post-CI updates commit + delta rule +
    push + mandatory CI re-loop on the new SHA, citing the FINAL green SHA
    (defer-before-push decided upfront; published SHA + exhausted cap →
    `blocked`, PR kept, non-green CI reported, never claim green). Post-merge
    updates ship as a dedicated docs-only mini-PR (route `answer`,
    schema check, push on explicit request, owner = escaped-defect
    recorder) keyed by PR URL — upsert, never a second row.

## Test Evidence

An empty grep is not a pass. Many runners (Jest among them) print their summary
on stderr, so a filtered pipeline can return nothing while the suite failed.
Trust the **exit code**, and quote the summary line the run actually printed.
Capture output to a file when running several packages in a loop, then read the
summaries back:

```bash
for p in a b c; do
  <runner> "$p" > "$LOG/$p.log" 2>&1
  echo "$p exit=$?"
done
grep -E '^Tests:|^Test Suites:' "$LOG"/*.log
```

When a suite fails, establish whether it is **yours** before reporting or fixing
it. Stash the diff, reinstall if dependencies moved, re-run the same suite on the
untouched base, and compare. A failure that reproduces identically on the base is
pre-existing: say so with the evidence, list it under the PR's known limitations,
and do not fix it in this branch. A failure that disappears on the base is yours.

Re-run once before calling a single failure a flake, and name the mechanism
(port race, timeout, shared fixture). "Flaky" without a mechanism is a guess.

## Hard Limits

- Never merge the PR.
- Never force-push, except the consented `/ci-fix` rebase flow
  (`--force-with-lease` only, never plain `--force`); see
  `workflow/skills/ci-fix.md` Fix Mode. Single source:
  `workflow/contract-details.md`.
- Never push to the default branch from `/ship`. Direct default-branch
  integration is outside `/ship` and requires a separate current user request
  satisfying `workflow/git-contract.md`.
- All `workflow/spec.md` autonomous-loop rules apply: mandatory event ledger,
  no-progress stop, check-freeze, explicit cap, fresh-context review.
- Code-diff adversary: cross-model or documented double-sample only; single
  same-family pass blocks the ship (full autonomy).
- Any stop from the implementation loop (CHALLENGED, blocker, no validation
  surface, human checkpoint outside this contract's consented writes) stops
  the whole ship run with a `blocked` event and a handoff.

## Completion Evidence

A ship run is complete only when the final report names: PR URL, green CI (or
capped/blocked state), implemented-plan archive path, event ledger location,
the fresh-context review verdict, `cumulative_review`, `adversary_model` (or
double-sample), `thermo_nuclear`, `pr_body_style`, `deciding_code`,
`escaped_defects_recorded`, and the worktree cleanup status.
