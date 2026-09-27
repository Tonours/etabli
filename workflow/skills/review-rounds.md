# Review Rounds

Bounded re-review machine for implementation and ship runs. Open it only
when a review round returned findings, a re-review is due, or CI-driven
commits landed after a review (`workflow/skills/implementation-loop.md`
step 13b, `workflow/skills/ship.md` steps 4, 7 and 11). A first clean tour
(T1 → F1) never needs it.

## Review budget machine

One T/D/F counter per run; the ship phase inherits it (see the `ship.md`
transfer record). T = full tour (hunters +
adversary, fresh context, pinned patch + SHA). D = delta round (fix
diff vs previous pinned patch ONLY; Logic hunter + the finding's
hunter family, fresh; adversary only if a high-severity finding was
folded; hunter unavailable → `blocked`). F = final full pass (whole
patch, pinned final SHA). T1/T2/D1/D2/F1/F2 are POSITIONAL: the
first/second round of that kind SPENT in this run. Every entry
consumes the next unspent round of that kind; re-entry with none
left goes `blocked` instead of reusing a spent round. F rounds are
SHA-bound: a second full pass is always F2, never a new F1.
- T1: findings → fold → T2. T1 clean → F1.
- T2: findings → fold → D1. T2 clean → F1.
- D1: findings within delta → fold → D2. Findings widening beyond
  delta → reclassify as full tour (next unspent T: T1 if unspent,
  else T2, else `blocked`). D1 clean → F1.
- D2: findings within delta → fold → F1 (F covers D2 fixes).
  Widening → `blocked`. D2 clean → F1.
- F1: clean → VALIDATE at F1 SHA. Findings → fold on the delivery
  branch → one FD round (next unspent D required, else `blocked`)
  → F2 on the new delivery SHA.
- FD (the post-F1 delta round; tour tag `FD`, consumes one D unit):
  findings within delta → fold → F2 (F2 covers: it re-reads the
  whole new delivery SHA). Widening → `blocked` (no T re-entry
  post-F1: F1 already validated the full scope, new scope needs a
  new plan). Clean → F2. FD never routes to F1 or D2.
- F2 (always on the delivery SHA, never on scratch): clean →
  VALIDATE. Findings → fix on pre-created scratch branch
  `review-f2/<slug>` (SHA + clean worktree verified at creation) →
  `blocked`: deliverable SHA stays frozen, worktree kept, never push
  from a HEAD containing scratch fixes, no scratch→delivery
  promotion without a new plan. Refused checkout → `blocked` with
  the frozen SHA named. Never `reset --hard` implicitly: deletion
  needs a `spec.md` checkpoint.
Limit cases: (a) fix with exhausted D budget at F1 → `blocked`;
(b) findings at F2 → `blocked`, fixes abandoned on scratch;
(c) out-of-delta change during D → full tour or `blocked`;
(d) second D-round widening → `blocked` (T exhausted);
(e) FD widening → `blocked` (no post-F1 T re-entry).
Enforced for tagged `plan-implement` runs by `scripts/lib/review-rounds.jq`
(`workflow-event` append and validate; fields in `workflow/events.md`). Ship
inheritance and D-round adversaries after a high fold stay prose-only.

## Delta re-review

After CI-driven commits that touch runtime code on a ship branch:

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
`skills-lock.json` — with every changed fingerprint recomputed from
its pinned source via the verify procedure — and the rest identical
over canonical `jq -S` parsed values) get a schema check. Negative pin: a lone changed
fingerprint that does not recompute from its source → FULL review.
Otherwise Logic hunter on the new diff only, justified:
post-full-review small delta.
