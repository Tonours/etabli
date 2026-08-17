# Git Contract

Branch names and commit messages. English always.

## Branch names

```text
<type>/<ticket-id>-<short-slug>
```

- `type`: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `build`, `perf`, `style`.
- `ticket-id`: lowercase issue key when one exists (`prd-123`), omitted otherwise.
- `short-slug`: kebab-case, **3 words max**, the subject of the change.
- Whole branch name stays under 50 characters.

The slug names what changes, not how or why. Drop every word the reader can
infer: no verbs like `add`/`update`, no `the`, no restating the type.

```text
invalid  feat/prd-123-i-decided-to-be-victor-hugo-and-writes-a-lot-of-stuff
valid    feat/prd-123-i-decided-to-be-victor-hugo

invalid  fix/prd-456-fix-the-bug-where-permissions-are-not-refreshed
valid    fix/prd-456-permissions-refresh
```

If three words cannot carry the change, the branch does too much. Split it.

## Commit messages

```text
<type>(<scope>): <description>
```

Conventional Commits. **Subject line only — never a body, never trailers.**

- Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `build`, `perf`, `style`.
- `scope` is optional; use it when it disambiguates, drop it when it repeats the type.
- Description: lowercase, imperative, no trailing period, under 72 characters.
- One behavior per commit. Two behaviors are two commits.

The subject states the change, straight to the point. No narrative, no
justification, no hedging, no filler. Rationale belongs in the PR body.

```text
invalid  feat(auth): this commit adds the ability for users to refresh tokens
valid    feat(auth): refresh tokens on expiry

invalid  fix: fixed a bug
valid    fix(permissions): reload cache after role change

invalid  chore: updated stuff and also cleaned up some other things
valid    chore(deps): bump fastify to 5.2
```

## Default branch authorization

The default branch stays protected unless the current user request satisfies a
narrow consent gate. Both conditions are required in the same current user
request:

1. The branch is the write target, and the user names either the actual default
   branch exactly (for example `main`) or the words “default branch”. Naming it
   only as a source or read target does not count.
2. The user writes the exact requested operation: `commit`, `merge`, or `push`.

Only the user's exact current-request words count. Synonyms such as “land”,
“integrate”, or “ship it”, agent paraphrases, and consent carried from an earlier
request do not count. Each operation requires its own authorization. A
branch-less grant such as “commit and push”, without naming the default branch
as the write target, does not authorize it. When the same request names the
default write target and multiple exact operations, each operation is
authorized separately.

Resolve the actual default branch from remote HEAD / `origin/HEAD`, then the
repository's documented default. If it cannot be determined confidently, keep
it protected. This gate covers every mechanism that lands commits there,
including local Git, push refspecs, platform PR merges, and merge APIs.

Final relevant checks must pass before the write. Respect remote branch
protection; if it rejects the operation, stop and report instead of bypassing,
disabling, or admin-forcing it. This exception never overrides a stricter skill
contract such as `/ship` or worktree isolation.

History-rewriting operations keep their separate rules. Default-branch consent
does not authorize amend, rebase, force-push, destructive cleanup, deployment,
secret access, or production actions.

## Hard rules

- Never add AI attribution: no `Co-Authored-By`, no `Generated with`, no emoji credit.
- Never rewrite, amend, force-push, or rebase published history unless asked.
- Apply the default-branch authorization gate above; without both conditions,
  never commit, merge into, or push to the default branch.
