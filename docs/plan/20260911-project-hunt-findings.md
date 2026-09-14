# Implemented: correct project-hunt evidence and selection decisions

## Metadata
- Archived: 2026-09-11
- Source plan: `PLAN.md` — six project-hunt audit findings
- Source plan SHA-256: `1a281f1d82041f709b701e8c848d675a73f50a00b8d9df3fd8a50ffa315b7f2c`
- Status: IMPLEMENTED
- Base: `d9332d8`; isolated checkout `/tmp/etabli-project-hunt-20260911`
- Delivery: `/Volumes/Crucial/work/etabli`; no commit or push

## Outcome

All six findings are addressed in the existing skill procedure and references.
The skill distinguishes advertised pricing, a buyer's observed spending and
commitment to the proposed solution. Missing evidence produces a watchlist gap;
rejection requires supported incompatibility or material negative evidence.

| Finding | Implemented decision | Evidence cases |
| --- | --- | --- |
| F1 budget | Listed price alone is N/A; one same-job payment scores 2, repeat spend 3, allocated budget 4, paid proposed-solution pilot 5; name the payer | C01–C02 |
| F2 research gaps | Missing/inaccessible proof or exhausted cap remains watchlist; negative evidence can still reject | C03, C11–C14 |
| F3 source gates | Require facts and independent identities, not mandatory review platforms or an incumbent; emergence is optional and unscored | C04 |
| F4 capability and dates | Included authorized read may proceed without internal unit-price metadata; actual new charges or unknown operations remain gated; current official undated pages retain separate observed/publication dates | C05–C06, C09–C10 |
| F5 counterevidence | Counter-search before ranking; record sufficient alternative, switching obstacle, falsifier and search outcome; do not fabricate a counterexample after zero results | C07 |
| F6 focus | Honor vertical/language scope; default20 fetches allocate at most6 discovery and at least14 verification; transfer unused discovery capacity | C08 |

SaaS weights now total100 with recurring pain30, buyer budget20, access20,
wedge15 and founder fit15. Source coverage remains visible separately from
fact coverage. Independent opened evidence, ten-conversation access, founder
exclusions, separate mode outputs, ecommerce formulas and invocation policy remain.

## Decisions and evidence limits

The baseline execution refined the initial audit: its payment bands overlap.
A current payment could receive5 under the strongest-level rule even though
paid workarounds also appear at3. The fix removes that ambiguity; the original
16-versus12 weighted-point example was not a universal baseline ordering.

`tests/fixtures/project-hunt/scenarios.json` contains14 synthetic offline cases;
`expectations.json` was frozen before candidate execution and kept out of the
fresh candidate evaluator's input. All `.invalid` URLs are synthetic supplied
payloads, not live source claims. Expectations are reviewed semantics, not an
executable classifier or a wording-matching unit test. The parent adjudicated
each returned decision against the frozen expectation text.

| Population | Informed baseline | Fresh candidate-v1 |
| --- | --- | --- |
| Targeted C01–C08 | 0/8 | 8/8 |
| Preservation C09–C14 | 4/6 | 6/6 |
| Total | 4/14 | 14/14 |

The baseline evaluator had already reviewed the plan; the candidate evaluator
had not read the plan, audit, expectations or baseline. This is not a blinded,
causal or repeated market-quality benchmark. The two arms have different context
exposure. These counts establish decisions on this small corpus only.

| Case | Baseline observed output | Candidate observed output |
| --- | --- | --- |
| C01 | No rank but E5 price budget4; rejection/watchlist conflict | Watchlist, budget N/A, payer missing |
| C02 | PriceA4; paymentB5 or3 due to overlapping bands | PriceA N/A; one observed paymentB2 |
| C03 | Reject at exhausted cap despite next interview | Watchlist; invoice in later authorized interview |
| C04 | No rank: only practitioner family, no review/trigger/incumbent | Eligible81.00; E1/E2/E6 independent owners |
| C05 | Block included lookup for missing billing metadata | Included read permitted, metadata unknown |
| C06 | Current undated official price unusable | EUR49/month observed2026-09-11; publication unknown |
| C07 | May rank93.00 without counter-search | Counter-search E7; same-target solved job rejected |
| C08 | Scope conflict, no verification reserve | French repair shops only;4discovery plus up to16verification |
| C09 | NewEUR0.10 charge blocked | Charge blocked; authorized free fallback available |
| C10 | Unknown operation blocked | Unknown operation blocked |
| C11 | One copied identity; no rank, rejection/watchlist conflict | One identity; watchlist for independent evidence |
| C12 | Separate modes; ecommerce missing costs rejected/ambiguous | Separate modes; ecommerce empty with watchlist |
| C13 | No low-capital shortlist | No low-capital shortlist;185EUR risk versus150cap |
| C14 | Negative demand evidence rejects despite stack fit | Same supported rejection |

C04 arithmetic: `30 + 8 + 16 + 12 + 15 = 81.00`.
C13 arithmetic: `20 + 3*(35+5+10) + 3*5 = 185 EUR`, headroom `-35 EUR`.
Some fixture access/asset descriptions lack separate IDs; inaccessible pages
lack a specific failure cause. Evaluators reported those limits without inventing
attribution or access-error reasons.

## Validation Evidence

- `node pi/scripts/verify-skills-lock.mjs`: passed66 skill hashes; only project-hunt hash changed.
- `bash tests/pi-skill-load-check-smoke.sh`: passed native fixture assertions. The isolated checkout initially lacked yaml; reusing the original installed pi/node_modules resolved it without installing packages.
- Python metadata/link/scenario checks: passed retained Pi invocation metadata,5/5 local references,14 unique scenario IDs and disjoint populations.
- `git diff --check`: passed.
- Generic skill-creator quick_validate.py: baseline incompatibility, rejects the existing Pi-specific disable-model-invocation field. That field was preserved; no generic-validator pass is claimed.
- simplify: clean. quality: skill-creator applied to the cumulative diff; existing reference structure and shared hasher reused.
- Logic reviewer `/root/hunt_review_a`: GO WITH NOTES, complete deciding-behavior rows; pending native check subsequently passed.
- Spec reviewer `/root/hunt_review_b`: GO. Standard-tier adversary same-family samples A and B: GO, no findings. Both inherit parent Codex model; exact model identifier is not exposed.
- Parent lead: GO. No unresolved high/medium finding. Reviews cover the pinned full patch, including fixture JSON and lock update.

Evidence under `.workflow/project-hunt-findings/`: baseline and candidate-v1
snapshots, frozen-input-hashes.json, baseline-results.json,
candidate-v1-results.json, adjudication-v1.json, review-v1.patch and reviews-v1.json.
Result JSON files are parent transcriptions of returned evaluator outcomes,
not raw provider traces. The patch SHA-256 is
`f0b64c8f534bd591d47ef02238a5a27f30c4f1046e598405fc815ae0d0580858`.

## Follow-up State

- Remaining risks: no live web collection, Pi-provider invocation or market-quality validation; no empirical calibration of ranking weights or claim of reproducibility across models.
- New mechanical check deliberately not added: no new executable decision engine or transverse invariant; reusable input/expectation fixtures plus observed independent execution test the prose workflow.
- Original checkout's unrelated campaign PLAN.md and pi/models.json are preserved by pre-delivery hash checks. Only the isolated task plan is archived and removed.
- No market hunt, spend, outreach, publication, commit or push was performed.
