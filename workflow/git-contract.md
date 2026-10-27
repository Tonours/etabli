# Git Contract

Branch names and commit messages. English always.

## Branch names

```text
<type>/<ticket-id>-<short-slug>
```

**Precedence rule:** when the user's current request explicitly names a branch
(`branch item1 off main`, `stay on feature-x`, `call it hotfix-login`), use the
user's exact name. The scheme below is the default for agent-chosen names
only; it never renames or "corrects" a name the user explicitly gave. When
explicitly named branches and the default scheme must coexist, keep the user's
names verbatim and apply the scheme only to the others.

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

## Default branch and history

No consent gate. Commit, merge, push, rebase, amend, and force-push whenever
the work calls for it, the default branch included, except under a host that
gates effects (`workflow/spec.md` § Human checkpoints). Prefer
`--force-with-lease` over plain `--force`. If a remote rejects the write,
report it.

## Hard rules

- Never add AI attribution: no `Co-Authored-By`, no `Generated with`, no emoji credit.
