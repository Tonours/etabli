# Review Rounds

Bounded re-review machine for implementation runs. Open it only
when a round returned blocking findings, a fold or re-review is due, or
CI-driven commits landed after a review (`workflow/skills/implementation-loop.md`
step 13b). A clean T1 never
needs it.

## Review budget machine

One T/D counter per run. T = full tour (hunters + code_diff adversary, fresh
context, pinned patch + SHA). D = delta round (fix diff vs previous
pinned patch ONLY; Logic hunter + the finding's hunter family, fresh;
hunter unavailable → `blocked`). T1/T2/D1/D2 are POSITIONAL: the
first/second round of that kind SPENT in this run; re-entry with none
left goes `blocked` instead of reusing a spent round.
Blocking = an accepted finding of high severity or an unmet AC, or a
`BLOCK` verdict. A round is
`clean` when its review is not `BLOCK` and every code_diff adversary of
the round is `GO`/`GO WITH NOTES` with no blocking accepted finding.
Non-blocking findings never spend a round: fold them or list them in the
final report. `widening` on a T round counts as findings.
- Clean (any round) → VALIDATE. A later fold or fix within the delta bar
  (§ Delta re-review) takes the next unspent D; a larger one takes the
  next unspent T.
- T1: findings → fold → T2. T2: findings → fold → D1.
- D: findings within delta → fold → next unspent D. Widening beyond
  delta → next unspent T. Nothing left → `blocked`.
Adversary: every T round, plus a D round after a findings round or whose
window holds a change on a contractual surface; at least one such
pass must follow the round's last change. No code_diff adversary
may follow the closing clean round once no round remains or the run
completes.
Limit cases: (a) D2 findings → `blocked` (D exhausted);
(b) widening with both T spent → `blocked` (T exhausted);
(c) out-of-delta change during D → full tour or `blocked`.
Each round is recorded in `PLAN.md` § Review Changes.

## Delta re-review

After CI-driven commits that touch runtime code on a PR branch:

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
`tests/`, `skills/`, `claude/scopes/`, `.github/`,
`AGENTS.md`, `PLAN_TEMPLATE*.md`, `docs/`, `.mcp.json`, locks,
`*.policy.json`), or any rebase happened (proof invalidated).
Generated-records row-only deltas (closed list:
`skills-lock.json` — with every changed fingerprint recomputed from
its pinned source via the verify procedure — and the rest identical
over canonical `jq -S` parsed values) get a schema check. Negative pin: a lone changed
fingerprint that does not recompute from its source → FULL review.
Otherwise Logic hunter on the new diff only, justified:
post-full-review small delta.
