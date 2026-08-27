# Source catalog

This catalog defines coverage and evidence quality. `SKILL.md` owns the
workflow; this file owns source families, audience proxies, and limitations.

Use the same coverage statuses everywhere: `found`, `zero`, `absent`,
`access-refused`, `blocked`, `error`, and `not-searched`. Keep `zero` for a
query that actually ran with no usable result; keep the other failure or skip
states explicit rather than converting them to `null`.

## Tool contract

- Built-in web: use the exact exposed search/fetch capabilities for discovery
  and opened canonical pages. `web_search`/`web_fetch` are examples, not
  guaranteed APIs. If discovery or fetch is absent, mark that capability
  `absent`; discovery snippets are not quotable without a fetch. `open_page` is
  not assumed.
- MCP: when `search_tool` (or another discovery helper) is exposed, call it
  first, then use the exact namespaced tool and schema it returns. If no helper
  is exposed, use only already-listed tools and mark undiscoverable families
  `absent`; never silently skip a required family.
- X: the available MCP and tool names vary. Use only the discovered read
  operations after the X guide, current-user probe, cost estimate, and cap.
  If the server or guide is missing, mark X `absent`; if access is denied, mark
  it `access-refused`. If the probe, estimate, or cap check is missing or
  errors, mark X `blocked`/`error` and do not call it. Never paste keys or use
  write/billing operations for research.
- GitHub: prefer read-only `gh` commands, GitHub MCP search/read, or public
  web results. A GHSA/issue URL must be opened before quoting.
- Brave Search: use the installed `brave-search` skill only when exposed; if it
  is not exposed, mark that capability `absent`. Its output remains discovery
  evidence until the result page is opened.

## Evidence classes

| Class              | Examples                                                                         | What it can prove                                     |
| ------------------ | -------------------------------------------------------------------------------- | ----------------------------------------------------- |
| Primary/user       | practitioner post, customer review, GitHub issue, official regulator/vendor page | observed pain, rule, price, failure, or stated change |
| Independent report | primary industry report, dated job-market report, incident/changelog             | trend, budget, trigger, or market context             |
| Discovery only     | search snippet, trend chart, affiliate/alternative list, video                   | lead to investigate; never sole demand or price proof |

Every printed citation carries `evidence_id`, `URL`, an ISO date/post timestamp,
a quote of ≤25 words, an audience proxy, `source_family`, and
publisher/domain/author. Assign one immutable `evidence_id` per opened
source/claim and reuse it when the same citation supports multiple cards. Use two independent source families for a SaaS
shortlist and two independent demand signals for ecommerce. A source can
support only the claim it actually contains. Two citations are independent only
when their publisher/domain/author and ownership are distinct, or when unrelated
primary and user evidence corroborate the claim; mirrored or copied material is
one identity.

## SaaS families

### Must

| Family                 | How                                                                                             | Limitation / proxy                                                                  |
| ---------------------- | ----------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Practitioner pain      | X MCP when available; otherwise public web search of X, Reddit, HN, Lobsters, métier forums     | X follower/views/likes; Reddit sub + score; HN/Lobsters points; snippets need fetch |
| Paying dissatisfaction | 1–2★ Trustpilot, G2, Capterra, App Store, Google Play, Chrome Web Store                         | review count + score + date; ignore incentivized dumps                              |
| Budget / incumbent     | vendor `/pricing` or `/tarifs`, fees, hours billed, fines, job budget                           | vendor URL fetched this run; print currency, plan, period                           |
| Trigger                | official changelog/status/incident, API/platform change, regulation, GHSA, repeated recent jobs | primary date and scope; freshness does not prove demand                             |
| Build/access fit       | founder profile, named community/contact, existing asset or stack                               | fit is not market proof; keep it in a separate column                               |

### Should (theme-matched)

| Theme                | Sources                                                                                               |
| -------------------- | ----------------------------------------------------------------------------------------------------- |
| Self-host / homelab  | GitHub issues + GHSA, restic forum, Coolify community, r/selfhosted                                   |
| FR TPE / e-invoicing | economie.gouv.fr, impots.gouv.fr, JO, CNIL, public entrepreneur discussions                           |
| Photographer FR      | métier blogs, FFPMI, Label Photographie, public Capterra/Helpho/Pixieset reviews; not another gallery |
| Engineering / agents | GitHub Blog, Faros/GitClear/Linear primary reports, maintainer issues, practitioner posts             |
| SaaS billing         | Stripe docs/incidents, Chargebee/Recurly reports, r/SaaS churn discussions                            |
| Ember / MFE          | r/emberjs, employer community, Intercom/Lighthouse engineering posts, webpack/rspack issues             |

French Facebook groups are phase-2 access signals only. Do not quote gated
posts; name a group only when a public page attests it exists.

## Ecommerce-cash families

The goal is a low-risk cash test, not a product-trend catalogue.

| Family                            | Sources                                                                                               | Required use                                                                                                                 |
| --------------------------------- | ----------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Buyer intent                      | public “where can I buy”, recommendation, problem, return, delivery, or custom-request posts          | prove a job and language; not volume alone                                                                                   |
| Existing offer/transaction signal | dated public reviews, sold/order evidence, or listings on Etsy, Amazon, eBay, specialist marketplaces | reviews/sold evidence can support demand; a listing proves only an available offer/price; never infer sales from rank badges |
| Offer economics                   | supplier/manufacturer price, shipping quote, packaging, platform/payment fees, return policy          | calculate landed cost and contribution margin                                                                                |
| Organic access                    | named niche community, local group, search demand, existing audience or partner                       | route to first three preorders/paid orders without paid ads                                                                  |
| Risk / fulfilment                 | regulator, platform policy, shipping constraints, IP/trademark, returns and tax pages                 | reject or gate unsafe, counterfeit, or heavily regulated offers                                                              |

A marketplace page is not a supplier guarantee. Verify availability, delivery
time, fees, VAT/tax treatment, and return cost for the actual country and
channel before scoring an offer. Two pages from the same seller or marketplace
do not count as independent demand signals by themselves.

## Emerging probes (run every requested mode)

Probe at least three relevant families and report one canonical status:
`found`, `zero`, `absent`, `access-refused`, `blocked`, `error`, or
`not-searched`. `zero` means the query ran and yielded no usable evidence;
`absent` means the source/capability does not exist in the session;
`access-refused` means gated/private/permission-denied; `blocked` means a known
source was stopped by consent, cost, policy, or a dependency; `error` means an
attempted operation failed; `not-searched` means intentionally outside the
mode/cap. Keep the status visible in the coverage map.

- Bluesky, Mastodon/Fosstodon, Lemmy/kbin, Indie Hackers, Product Hunt comments;
- Lobsters and Stack Exchange unanswered/recent “is there a tool” threads;
- job posts and vendor changelogs/status incidents;
- dated price cliffs, regulatory consultations, sanctions, or platform policy
  changes;
- YouTube switching stories only as hypotheses until a buyer/source confirms.

“Emerging” requires a recent trigger or acceleration plus recurring pain. A
single viral post, launch thread, or trend chart cannot earn a shortlist rank.

## Marketer and provenance traps

Do not use as pain or price proof:

- “best alternatives” pages written to sell leads;
- affiliate roundups, PDP comparison pages, SEO lists, or AI-generated pain
  points without a named user;
- vendor marketing claims presented as customer evidence;
- private/gated posts, copied snippets, or a subagent summary without the URL;
- TikTok, Instagram, WhatsApp, or Discord content without a dated public URL.

Keep: the practitioner post, dated 1★ review, GitHub issue/GHSA, official
pricing/regulator page, and primary industry report.

## Audience proxies

| Channel                    | Print this                                                       |
| -------------------------- | ---------------------------------------------------------------- |
| X                          | author followers + views/likes on the post, if exposed           |
| Reddit                     | subreddit name + score                                           |
| HN / Lobsters              | points + comment count when visible                              |
| Trustpilot / G2 / Capterra | review count + score + review date                               |
| GitHub                     | repository stars + issue/advisory number                         |
| Official regulator/vendor  | official source + publication/update date; no invented visitors  |
| Marketplace                | displayed review count/score and listed price; no inferred sales |
| Facebook group             | member count only when a public source states it                 |

If a proxy is unavailable, print `N/A` and keep the uncertainty visible.
