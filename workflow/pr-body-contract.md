# PR Body Contract

How to write a pull request description. Applies whenever a PR body is authored
or rewritten, whether through `workflow/skills/ship.md`, a runtime command that
opens a PR, or a direct request to redo a description. It does not govern
mechanical edits to an existing body, such as `sec-pr` ticking its checkboxes.

The reader is a busy human reviewer, not a changelog. They decide in about
thirty seconds whether they can review this now.

## Non-negotiables

- **English.** Always, whatever language the conversation is in. Same rule as
  commits, code, and identifiers.
- **The repo's template is law.** Use `.github/PULL_REQUEST_TEMPLATE.md` (or
  the equivalent). Keep every section and checklist intact, fill only the
  placeholders, leave author/reviewer checklists unchecked.
- **No AI attribution.** No "Generated with", no robot emoji, no co-author
  trailer, nowhere in the body.
- **Link the ticket** when there is one: `fixes PRD-123` on its own line, so
  the tracker picks it up.

## Shape

**Answer three questions and stop: what changed, why, how to verify it.**
That is the whole body. One opening line states the change, then `## What`,
`## Why`, `## How to test`. Lead with the change, never with a story about the
problem; the reviewer reads the diff for the rest.

- **What** — the change. A table of touched files plus the rules that changed.
- **Why** — the need, and only the choices a reviewer would otherwise
  question. Skip the obvious ones.
- **How to test** — the commands you actually ran, with their result.

Anything else has to earn its heading against those three, and almost nothing
does. A ceiling you accepted on purpose belongs in one `## Why` bullet, not in
its own `## Known limitation` section repeating it. What the change does *not*
touch belongs there too, in a sentence, and only when it sits near auth,
permissions, or data.

**Budget: 40 lines outside the repo's template.** Past that, you are explaining
the diff instead of introducing it. Cut whole sections before trimming
sentences: the second section covering a decision goes first, then every
sentence that defends, restates, or announces.

Facts belong in tables or lists: status-code matrices, before/after, touched
packages. Prose is for the reasoning that a table cannot hold.

## Anti-slop

The style rules from `write-direct` apply to the narrative parts, in English.
Contracts stay literal: routes, payloads, signatures, error types, commands,
and security warnings are never restyled for tone.

Cut on sight:

- Decorative em-dashes used as repeated breathing room. A period works.
- Recap conclusions ("In summary", "To sum up"). The reader just read it.
- Openers that announce the plan ("This PR will describe..."). Start.
- Filler adjectives: robust, seamless, comprehensive, crucial, significant.
  Say what makes it solid instead.
- `leverage` → use. `delve into` → dig into. `moreover` / `furthermore` → "and",
  or nothing. `it's worth noting that` → say the thing.
- Mechanical parallelism: every bullet cast in the same mould. Vary or merge.
- Defending a decision across a paragraph. State it in a sentence and move on;
  a long defense reads as doubt.

Shorter wins. Between two drafts, ship the denser one.

### No AI artifacts

Typography is the tell. The body must contain **no non-ASCII character** outside
code blocks, tables, and quoted output: no `—`, no `→`, no curly quotes, no `…`.
Write `,` or a period instead of an em-dash, and `so` or `becomes` instead of an
arrow. This is checkable, so check it instead of trusting the draft:

```bash
gh pr view <N> --json body -q .body | grep -oP '[^\x00-\x7F]' | sort | uniq -c
```

Empty output means clean. Run it after writing the body, not before.

### Write the dense version first

A body that needs two rounds of "shorter please" was too long on the first pass.
Before publishing, cut every sentence that defends, restates, or announces. Two
sections covering the same decision are one section. If a heading sits above a
single short paragraph, drop the heading.

Signals the draft is still too long:

- More than three top-level headings before the repo's template.
- Over 40 lines outside that template.
- The same reasoning appearing in two sections.
- A heading over a single short paragraph.
- A sentence explaining why a decision was cheap, right, or obvious.
- Manual steps that the test suite already covers.

## Stacked PRs

When the base branch is not the default branch, say so in the first lines,
before anything else:

- which PR it is stacked on, and that the base is that branch, not `main`
- that the parent must be reviewed and merged first
- whether it stays draft until then

A reviewer who misses this reviews the parent's diff twice and reports
phantom problems.

## Honest status

Describe what the branch *is*. "Draft, the endpoint is not wired to a route
yet" beats "complete implementation". Never claim a check that did not run:
name the tests and commands you actually executed, with their result.
