---
name: employer-docs-writing
description: Write or rewrite pages for the employer Mintlify documentation (~/work/docs) in the corpus voice; use for any new page, section, rewrite or review of employer docs content.
---

# employer-docs-writing — voice and shape of the employer documentation

You write English pages for `~/work/docs` (Mintlify, `.mdx`). Every rule below
comes from a count over the 146 non-legacy pages. Match them.

Scope: `get-started/`, `product/`, `reference/`, `guides/`, `index.mdx`. Never
`legacy/`, a frozen v1 corpus that is not a model for anything.

Verbatim passages to imitate: `references/patterns.md`. Read it before writing a
page of a type you have not written yet.

## Voice

1. **Second person, always.** `you` 1945 occurrences, `your` 1190. `we` 28, only
   in support lines ("we'll help you get your employer back-end running"). `our` 4.
   Never "the user should"; write "you".
2. **Say what the reader gets, in the first sentence, without a preamble.** The
   opening line is a plain statement of what the thing is or what they will have:
   "The Layout Editor is employer's visual customization tool." / "You'll have a
   working employer back-end connected to your database […] in about 15 minutes."
   No "In this guide, we will explore".
3. **Comma appositive is the house tic.** Expand a noun with a comma and a
   concrete list, where other docs would use a colon or a dash: "it lets you
   control exactly what your operators see and how data is presented, which
   columns appear in tables, how detail views are organized". `—` is used 186
   times across the corpus, so reach for the comma first.
4. **Contractions, sparingly.** ~160 across 146 pages: `don't` 35, `you'll` 21,
   `it's` 21. Roughly one per page. They appear in conversational lines, never in
   a parameter description.
5. **No hype vocabulary.** Measured counts: `seamless` 0, `powerful` 0, `easily`
   0, `utilize` 0, `delve` 0, `leverage` 3, `robust` 2, `comprehensive` 3,
   `simply` 4. If your draft contains one, delete it. The sentence is always
   shorter without.
6. **`operator` is the product term** for the human doing the work in the
   back-office (335 occurrences). `user` (793) means a employer account holder, an
   end-user of the client's own product, or an SSO identity. Do not swap them.
7. **Concrete over abstract.** Every capability claim carries a real example:
   "KYC reviews, AML alerts, dispute handling, supplier onboarding". Examples use
   plausible business nouns (orders, refunds, tickets, customers), never `foo`.
8. **Present tense, active voice, no conditional hedging.** "Changes apply
   immediately in preview." Not "changes will be applied".
9. **No meta-commentary.** The page never talks about itself ("this page
   covers…", "as mentioned above"). The `## What's next` transition is the one
   allowed forward reference.

## Page shape

Frontmatter: `title` and `description`. `description` is one sentence, 25-157
characters, median 73, sentence case, final period optional (43/131 have one).
Match neighbouring pages in the same folder rather than imposing one style.
Quoting `title` is mixed (84/146), so again, match the folder.

Headings are **sentence case**: `## What you have now`, `## Customizing the table
view`, `## Set up an inbox`. Title Case appears only in proper nouns (`## Live
Query support`). Gerund (`Customizing…`) for feature description, imperative
(`Set up…`) for a task.

By page type:

- **`get-started/` step page.** One-line promise, then `## Prerequisites` if
  any, `<Steps>` for the procedure, `## What you have now` stating plainly what
  exists, optional `## Troubleshooting` as an `<AccordionGroup>`, closing
  `## What's next` with a `<Card title="Next: … →" icon="arrow-right">`.
- **`product/` feature page.** What the feature is, where it appears in the UI
  (with `<Frame>` screenshots), how to configure it, then `## Permissions` and
  `## Audit trail` when the feature touches either. Cross-link the reference
  page instead of duplicating it.
- **`reference/` page.** One paragraph placing the thing, then `<CardGroup>`
  navigation or the API itself. `## Basic usage`, `## Options`, `## Examples`
  and `## Limitations` are the established H2s.
- **`guides/` page.** Problem first, then the fix, then what it costs.

Numbered `1. 2. 3.` lists for a short in-section procedure; `<Steps>` for the
page's main procedure. Bold the UI label being clicked: **Layout Editor**,
**Project Settings** → **Environments**.

## Components

Use, in this order of preference (corpus frequency in parentheses):

| Need | Component |
|---|---|
| Multi-SDK content (Node.js / Ruby) | `<Tabs><Tab title="Node.js">` (354 Tab / 132 Tabs), never two sibling sections |
| Consequence the reader must not miss: data loss, secrets, production | `<Warning>` (275) |
| Useful context, a pointer to the full reference | `<Info>` (265) |
| Navigation to another page | `<Card>` (186), grouped in `<CardGroup cols={2}>` (38) |
| Same snippet in several languages | `<CodeGroup>` (116) |
| Main procedure of the page | `<Steps>`/`<Step>` (20/86) |
| Screenshot | `<Frame caption="…">` with an `alt` on the `img` (79) |
| Aside that is neither a risk nor a pointer | `<Note>` (59) |
| Troubleshooting entries | `<AccordionGroup>`/`<Accordion>` (6/20) |

`<Tip>` is used 8 times in the whole corpus, so you want `<Info>`. `<Warning>`
outnumbers every component except Tab. This documentation names consequences
instead of reassuring.

Links are inline and relative: `[actions](/product/process/actions/overview)`.
Images live under `/images/...`, and every `<img>` carries an `alt`.

## Before you ship the page

- Opening sentence states the thing, not the intention.
- Zero hype words from rule 5.
- `operator` vs `user` checked.
- Every heading sentence case.
- Every claim about the UI verified against the product, or marked as to
  confirm. Never guessed.
- Each `<Warning>` names a real consequence; each `<Info>` points somewhere.
- Code samples cover Node.js **and** Ruby, or the page says which SDK it is for.
- The page ends on a link forward, not on a summary of itself.
