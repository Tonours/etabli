# Pain query pack

Replace only `{topic}`, `{incumbent}`, `{buyer}`, `{product}`, `{domain}`,
`{org}`, `{repo}`, and `{since}`.
Use the current session date to set `{since}`. Honor requested languages and
verticals; otherwise use relevant French and English searches separately. These
queries are selectable templates, not a checklist to run in full. Parenthesize
every `OR` group; do not weaken a query into
`{topic} tools` or a generic trend search.

Append `after:{since}` (or the engine's equivalent) to every time-sensitive
query below. If the engine has no date operator, post-filter by the displayed
publication/post date and leave undated historical claims `N/A`. For current
official pricing, fees, feature documentation and regulatory pages, record `observed_at` separately;
`published_at: unknown` is allowed when the page is undated. A legal effective
date or deadline still needs explicit primary-source evidence.

## X keyword search

Run `Latest` and `Top` only after the X capability/cost preflight in `SKILL.md`.
Use the exact tool schema discovered in the session; these are query strings,
not assumed function names. Add `-is:reply -is:retweet` when broad.

English:

```text
("anyone know a tool" OR "is there a tool" OR "I wish there was" OR "looking for a tool") {topic} since:{since}
("too expensive" OR "so expensive" OR "pricing is insane" OR "cancelled because") {topic} since:{since}
("I hate that" OR unusable OR "switching from" OR "migrating off") {topic} since:{since}
```

French:

```text
("je cherche" OR "vous utilisez quoi" OR "vous recommandez quoi") (outil OR logiciel) {topic} lang:fr since:{since}
("trop cher" OR rageant OR galère OR "à fuir" OR "impossible de") {topic} lang:fr since:{since}
("je quitte" OR "on laisse tomber" OR "plus jamais") {topic} lang:fr since:{since}
```

## X semantic search

Rewrite the job as spoken pain, not a product category:

- reviewers cannot keep up with AI-generated pull requests
- self-hosted backup that never restored
- French small business must receive electronic invoices
- photographer gallery storage is too expensive (not a gallery product)
- Stripe failed-payment recovery and dunning
- Coolify security advisory or remote-code-execution response
- a niche operator does the same spreadsheet or copy/paste every week

Use `from_date={since}` when the discovered schema supports it. Treat viral
posts, founder launches, and videos as hypotheses until buyer evidence exists.

## Reddit / HN / forums

```text
site:reddit.com {topic} ("expensive" OR "I switched" OR "does anyone" OR unusable OR cancelled) after:{since}
site:reddit.com {topic} ("trop cher" OR galère OR "je cherche" OR "vous utilisez") after:{since}
site:news.ycombinator.com {topic} ("Ask HN" OR "who is hiring" OR "I wish" OR expensive) after:{since}
site:lobste.rs {topic} (pain OR expensive OR migration OR manual) after:{since}
```

Fetch the thread before quoting. Prefer practitioners who pay, churn, migrate,
or describe a repeated manual workaround.

## SaaS budget and emergence

```text
"{incumbent}" ("price increase" OR "raising prices" OR "price cliff" OR "we are updating our") after:{since}
"{incumbent}" ("too expensive" OR commission OR "cancelled because") review after:{since}
site:github.com/{org}/{repo}/issues (backup OR restore OR expensive OR slow OR "doesn't work") after:{since}
site:github.com/{org}/{repo}/security/advisories after:{since}
site:linkedin.com/jobs {topic} (manual OR drowning OR "new role") after:{since}
```

Use these emergence queries when relevant to the brief. A trigger without
recurring pain is not a SaaS candidate; an established costly job needs no
recent trigger. For budget evidence, identify the payer and the same job in a
spending statement or quantified recurring workaround; a pricing page alone
is not buyer budget.

## Reviews and official pricing

```text
site:trustpilot.com/review/{domain} ("1 star" OR terrible OR cancelled) after:{since}
site:fr.trustpilot.com/review/{domain} ("trop cher" OR galère OR résiliation) after:{since}
site:capterra.com {incumbent} ("1.0" OR "too expensive") after:{since}
site:g2.com {incumbent} (dislike OR expensive OR migration) after:{since}
```

Fetch `{incumbent}/pricing` or `/tarifs` directly. Use the vendor page for the
printed price; a dated price-increase post is only a supporting trigger.

## Finalist counter-search (required before ranking)

Reserve verification fetches for these searches as well as corroboration.
Search in the selected language(s) and vertical; substitute the actual job,
not just its product category. Open the relevant results.

```text
{topic} {buyer} ("works fine" OR "already included" OR "spreadsheet is enough" OR "not worth switching") after:{since}
{topic} {buyer} ("suffit" OR "déjà inclus" OR "aucun intérêt" OR "coût de migration") after:{since}
"{incumbent}" {topic} ("built in" OR "free plan" OR "native feature")
"{incumbent}" {topic} ("fonction native" OR "offre gratuite" OR "sans supplément")
```

Check the existing manual/free alternative, a satisfied user or native feature,
and the friction of switching. Record query, result/status, and what would
falsify the unmet-job claim. Apply dates to historical claims; a current official
feature/pricing page describes availability as observed, not its release date.
Do not invent a counterexample after a zero-result search. An unperformed search
or unresolved material contradiction leaves the finalist in watchlist. A matching
current solution for the same buyer/job can justify rejection; a satisfied user
in a different segment cannot by itself.

## FR TPE / métier

```text
site:economie.gouv.fr {topic}
site:impots.gouv.fr {topic}
"facture électronique" (TPE OR micro) (réception OR obligatoire) after:{since}
site:cnil.fr {topic}
site:linkedin.com {topic} ("trop cher" OR galère) lang:fr since:{since}
```

For regulation, open the current official source and record scope, date,
deadline, and uncertainty. Do not turn a legal signal into legal advice.

## Ecommerce-cash

Use only in `ecommerce-cash` or `mixed` mode. Search buyer intent, existing
transactions, and pain around the offer—not “trending products”.

```text
("where can I buy" OR "looking for" OR recommend OR "need a") {product} {buyer} after:{since}
("trop cher" OR "rupture" OR "déçu" OR retour OR livraison) {product} {buyer} lang:fr after:{since}
("made to order" OR preorder OR "print on demand" OR "small batch") {product} after:{since}
site:etsy.com {product} (review OR "arrived" OR quality) after:{since}
site:amazon.fr {product} ("1 étoile" OR déçu OR retour) after:{since}
site:ebay.fr {product} (acheté OR vendu OR recherche) after:{since}
```

Use marketplace pages for public price/review evidence only; do not infer
volume from a ranking badge. Pair the demand signal with a sourceable offer,
landed cost, fulfilment route, return risk, and an organic test path.

## Emerging probes

```text
site:bsky.app {topic} (expensive OR "I wish" OR broken) after:{since}
site:fosstodon.org {topic} (manual OR migration OR expensive) after:{since}
site:indiehackers.com {topic} (churn OR expensive OR "failed payment") after:{since}
site:lemmy.world {topic} (tool OR pain OR migration) after:{since}
"I switched from" "{incumbent}" (youtube OR transcript) after:{since}
site:linkedin.com/jobs {topic} ("we need" OR manual OR spreadsheet) after:{since}
```

Report a source family as `zero` only after the query ran and returned no usable
evidence. An unexposed tool or missing path is `absent`; a gated, private, or
permission-denied page is `access-refused`; a known source stopped by consent,
cost, policy, or a required dependency is `blocked`; an attempted tool failure
is `error`; and an intentionally skipped family is `not-searched`. None of
these statuses is `null`, and none may be rewritten as `zero`.
