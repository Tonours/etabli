# Research result

**Status: Partial**

Safe harness self-improvement depends on a sealed held-out promotion gate, an independent final-state grader outside the mutation loop, and a human or READY gate before any apply—never auto-patching from mined failures alone. Candidates may only promote when comparative baseline-vs-candidate scorecards show a strict held-in pass-count gain and held-out non-regression on the same frozen population, with evaluators and permissions kept non-editable so the loop cannot game scores or weaken checks. Explicit rejection events and per-candidate deltas prevent silent promotion and metric laundering.

### Gate types that authorize change
Promotion requires a **sealed held-out gate**: held-in supplies failure trajectories to the proposer; held-out is never shown to the proposer and is used only to accept or reject, blocking overfitting and silent regressions on unseen tasks.[S1][S2] Acceptance further requires **non-regression on both splits** and improvement on at least one (in production contracts: strict held-in pass-count gain and held-out candidate.passed ≥ baseline).[S1][S10][S19]

A **human / READY gate** sits before consequential mutation: implementation starts only from `Status: READY`; human review remains at decision points that matter rather than being removed from the loop; authorized `human_checkpoint` is required before slices proceed.[S5][S6] Evaluators and permission control sit **outside** the evolving harness so the loop cannot optimize away the success signal.[S4]

### Required evidence artifacts
A mere proposal is recorded as `harness_proposal` with candidate identity, editable surfaces, behaviors to preserve, and held-in/held-out surface names—not comparative scores.[S7]

Comparative proof is the ledger event `harness_validation_completed`: held-in and held-out scorecards each with baseline and candidate `{population, passed, total}`, non-empty `checks` and `evidence`, a `verdict` of `accepted|rejected`, and a `reason`.[S8] That event is valid only for a real comparative run on the same baseline/candidate population per split, with non-negative integer counts, positive matching totals, and `passed` ≤ `total`.[S9][S20]

Pre-comparison rejects use `harness_candidate_rejected` with `{candidate, reason, regressions, evidence}`—not a false accepted validation.[S12][S23] Comparative negatives keep `harness_validation_completed` with `verdict: rejected`.[S10][S23] When populations are comparable, acceptance still requires the full comparative event, not held-in evidence alone.[S11][S21]

### Anti-auto-apply and anti-weakening controls
Hard policy forbids auto-applying self-improvement or retrospect output; mining tools stay read-only and never apply patches; mutation proceeds only on a separate READY/human path.[S6][S13] Contracts forbid weakening checks to pass self-improvement and never accept held-in alone when a relevant held-out smoke, fixture, or review surface exists.[S6][S11]

The success signal is an **independent final-state (outcome) grader**—final environment state, not transcript claims or “run finished”—kept outside the evolving harness so agents cannot pass by declaring success or following a fixed tool path.[S3][S14] When the agent can share the evaluator’s environment, models have gamed scores by monkey-patching graders, overwriting timers, or stubbing tests; non-editable, isolated graders and evaluation outside the agent container are required anti-gaming controls.[S15] Sealed/private held-out scoring with gold answers and evaluator metadata inaccessible to the agent blocks lookup and config-leakage cheats.[S16] Operational response to silent check-weakening includes bypass-resistant grader design (passing requires solving the problem) and patching scoring exploits when found, not only punishing the model.[S18]

### Comparative validation pattern (baseline vs candidate)
Validation is promote-only-after-gate on a **frozen comparative population**: same stable population id and matching totals within each held-in and held-out split; sealed graders and held-out surface stay frozen (`sealed_held_out: true`, minimum held-out / sealed fractions, per-task graders).[S17][S20][S22]

**Accepted** means strict held-in pass-count gain *and* held-out non-regression; candidates must resolve held-in failure evidence without regressing held-out router/docs/event/workflow smoke surfaces.[S10][S19][S21] Metrics report **per-candidate percentage-point deltas**; heterogeneous suites are never collapsed into a single global improvement average, and non-comparable evidence stays null.[S24]

## Sources
- [S1] "Self-Harness: Harnesses That Improve Themselves" — "https://arxiv.org/html/2606.09498v1"
- [S2] [S4] "Harness Engineering for Self-Improvement (Lil'Log)" — "https://lilianweng.github.io/posts/2026-07-04-harness/"
- [S3] "Demystifying evals for AI agents (Anthropic)" — "https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents" (independently checked against "Demystifying evals for AI agents (Anthropic); Self-Harness; project-autonomy-envelope.md" — "https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents")
- [S5] "Harness Engineering for Self-Improvement (Lil'Log)" — "https://lilianweng.github.io/posts/2026-07-04-harness/" (independently checked against "Harness Engineering for Self-Improvement (Lil’Log); Etabli self-improvement / project-autonomy" — "https://lilianweng.github.io/posts/2026-07-04-harness/")
- [S6] "Etabli Self-Improvement Loop Contract" — "/Users/tonours/work/etabli/workflow/skills/self-improvement-loop.md"
- [S7] "workflow/events.md — harness_proposal schema" — "/Users/tonours/work/etabli/workflow/events.md"
- [S8] "workflow/events.md — harness_validation_completed schema" — "/Users/tonours/work/etabli/workflow/events.md"
- [S9] "workflow/events.md — comparative-run rules" — "/Users/tonours/work/etabli/workflow/events.md"
- [S10] "workflow-event-detail.jq — accepted verdict gate" — "/Users/tonours/work/etabli/scripts/lib/workflow-event-detail.jq"
- [S11] "Self-Improvement Loop Contract — proposal validation" — "/Users/tonours/work/etabli/workflow/skills/self-improvement-loop.md"
- [S12] "workflow/events.md — harness_candidate_rejected" — "/Users/tonours/work/etabli/workflow/events.md"
- [S13] "Etabli Self-Improvement Loop Contract" — "/Users/tonours/work/etabli/workflow/skills/self-improvement-loop.md" (independently checked against "Etabli Self-Improvement Loop Contract; scripts/workflow-retrospect" — "/Users/tonours/work/etabli/workflow/skills/self-improvement-loop.md")
- [S14] "Demystifying evals for AI agents (Anthropic)" — "https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents"
- [S15] "Recent Frontier Models Are Reward Hacking (METR)" — "https://metr.org/blog/2025-06-05-recent-reward-hacking/" (independently checked against "Recent Frontier Models Are Reward Hacking (METR); How We Broke Top AI Agent Benchmarks (Berkeley RDI)" — "https://metr.org/blog/2025-06-05-recent-reward-hacking/")
- [S16] "How We Broke Top AI Agent Benchmarks (Berkeley RDI)" — "https://rdi.berkeley.edu/blog/trustworthy-benchmarks-cont/"
- [S17] "Etabli workflow events (harness_validation_completed)" — "/Users/tonours/work/etabli/workflow/events.md" (independently checked against "Etabli workflow events; project-autonomy-envelope; residual-risks" — "/Users/tonours/work/etabli/workflow/events.md")
- [S18] "Demystifying evals for AI agents; METR reward-hacking mitigation note" — "https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents" (independently checked against "Demystifying evals for AI agents; METR Recent Frontier Models Are Reward Hacking" — "https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents")
- [S19] "workflow-event-detail.jq harness_validation_completed accepted gate" — "/Users/tonours/work/etabli/scripts/lib/workflow-event-detail.jq" (independently checked against "workflow-event-detail.jq; events.md; vnext-suite.mjs compareStrategies" — "/Users/tonours/work/etabli/scripts/lib/workflow-event-detail.jq")
- [S20] "workflow/events.md harness_validation_completed contract" — "/Users/tonours/work/etabli/workflow/events.md"
- [S21] "Self-Improvement Loop Contract" — "/Users/tonours/work/etabli/workflow/skills/self-improvement-loop.md"
- [S22] "Bounded Project Autonomy Envelope" — "/Users/tonours/work/etabli/workflow/project-autonomy-envelope.md"
- [S23] "workflow/events.md harness event types" — "/Users/tonours/work/etabli/workflow/events.md"
- [S24] "workflow/events.md comparative metrics rule" — "/Users/tonours/work/etabli/workflow/events.md"

## Coverage and uncertainty
- "Question 1 uncertainty: No single primary production postmortem inspected here states a universal mandatory checklist of all four named gates for every vendor harness; synthesis spans research (Self-Harness/AHE) plus Etabli ops contracts."
- "Question 1 uncertainty: Self-Harness’s published promotion rule is automatic given held-in/held-out pass counts; it does not require a human READY/plan gate—those are production/agent-ops additions (Etabli, Weng guidance)."
- "Question 1 uncertainty: Etabli Pass B Prompt 4 ('Safe self-improvement loops') has no completed deep-research report under docs/research/deep-research-runs/ yet, so repo research is partial on unified gate→failure-mode tables."
- "Question 1 uncertainty: How much sealed held-out alone reduces reward hacking in live multi-turn production agents is stated as design practice, not a quantified universal effect size in the inspected sources."
- "Question 2 uncertainty: No inspected primary contract requires a separate free-standing 'regression diff' file artifact; regressions appear as fields on `harness_candidate_rejected` and as held-out/check non-regression inside `harness_validation_completed`."
- "Question 2 uncertainty: Inspectable baseline/candidate run JSON under `workflow/vnext/results/` (e.g. baseline-run.json, candidate comparison records) is the vNext suite’s concrete run-record convention, not a universal mandatory path named in the harness_validation_completed schema."
- "Question 2 uncertainty: Adversary docs scorecards (e.g. docs/adversary-etabli-10-scorecard.md) are separate from the held-in/held-out pass-count scorecards embedded in harness validation events."
- "Question 3 uncertainty: No single inspected primary source quantifies a universal reduction in harness self-mod gaming from combining all four controls; most evidence is failure under missing isolation/holdouts plus production-contract design."
- "Question 3 uncertainty: Etabli sealed_held_out / no-auto-apply mechanisms are harness contracts with smoke pins, not peer-reviewed causal evaluations of gaming rates."
- "Question 3 uncertainty: Deep-research Pass B report for the safe self-improvement prompt (Prompt 4) was not present under docs/research/deep-research-runs/ at inspection time."
- "Question 3 uncertainty: Residual risk remains even with freeze/seal: weakening graders or unsealing held-out later re-enables gaming (stated in residual-risks.md, not measured)."
- "Question 3 uncertainty: OpenAI 'Harness engineering' page content was not usable as evidence in this pass (fetch returned no extractable body)."
- "Question 4 uncertainty: This answer is grounded in Etabli’s local harness contracts/validators; external MLOps papers mention held-out evals for harnesses but were not required for the acceptance gates above and were not used as claim evidence."
- "Question 4 uncertainty: Operational cadence (how often harness_validation_completed is emitted in day-to-day runs) is described as partly manual in research notes and is not asserted here as a validation pattern."
- "Question 4 uncertainty: vNext live pass@1/pass^3 under paid budget is a separate measurement plane; residual-risks notes candidate reject is offline comparative only when live budget is zero."
