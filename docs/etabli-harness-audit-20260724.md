# Audit de fiabilisation — harness Etabli

**Date:** 2026-07-24
**HEAD observé:** `89025591c5549a4f354851949f979aa8ce9f4249` (branch `main`)
**Scope:** boucles existantes uniquement — pas de nouvelle boucle métier, pas d’implémentation de fixes
**Posture:** lecture seule du harness; seul livrable intentionnel = ce rapport
**Baseline:** `scripts/verify-agentic-infra all` → **EXIT:0** (capture scratch de session)

### Légende de confiance

| Label | Sens |
| --- | --- |
| **confirmed** | Observé dans le dépôt et/ou prouvé par commande locale |
| **approximate** | Vrai sur la surface lue; généralisation limitée |
| **proxy-supported** | Preuve indirecte (doc + smoke string / proxy capability) |
| **blocked** | Non vérifiable ici (opt-in, runtime manquant) |
| **unknown** | Non re-prouvé dans cette session |

---

## 1. Cartographie des boucles et dépendances

```text
user intent
    │
    ▼
┌─────────────────┐     Claude: claude/hooks/workflow-router.mjs
│ router (route)  │────► Pi: pi/extensions/workflow-router.ts
└────────┬────────┘     Core: workflow/runtime/workflow-router-core.mjs
         │                → re-export claude/hooks/workflow-router-lib.mjs
         ▼
  route ∈ {answer, plan-loop, plan-implement, implement, adversary,
           review, verify, research-plan, ops-stop, ci-fix, pr-*,
           linear-*, bug-check, spec-guide, …}
         │
         ├─ plan-loop ──► PLAN.md (DRAFT→CHALLENGED|READY)
         │                    │
         │                    ▼
         │              adversary (plan) ──► READY / CHALLENGED
         │
         ├─ implement ──► code/docs ──► validate ──► review
         │                    │              │
         │                    │              ▼
         │                    │         docs/plan/*.md archive
         │                    │              + delete root PLAN.md
         │
         ├─ plan-implement = plan-loop then implement iff READY
         │
         ├─ ops-stop ──► risk brief (HITL)
         │
         ├─ verify / review / pr-* / sec-pr / ci-fix ──► skill contracts
         │
         └─ answer (+ optional knowledgeContext → obvault read)
                              │
                              ▼
                 ~/work/obvault session|context (untrusted pack)

Cross-cutting:
  events.jsonl  ◄── autonomous: plan-implement, /goal, ci-fix
  workflow-metrics / retrospect / dossier / monitor  (read-only)
  vNext suite (scripts/vnext-suite)  final-state graders
  project-autonomy envelope (read-only controller)
  multi-model: parent-only writer + optional scout/council
```

| Boucle | Entrée | Artefacts | Sortie / stop | Preuve |
| --- | --- | --- | --- | --- |
| Routing | prompt + plan status | injection context | route + writeAllowed | `workflow/spec.md:221+`; router-eval 32 fixtures accuracy=1 (**confirmed**, baseline verify) |
| plan-loop | tâche large | `PLAN.md` | READY / CHALLENGED | `workflow/spec.md:221-224` (**confirmed**) |
| adversary | PLAN | PLAN updated | READY / CHALLENGED / blocker | `workflow/spec.md:224` (**confirmed**) |
| implement | READY PLAN | code + archive | archive + PLAN deleted | `workflow/spec.md:225`, agent-scenarios (**confirmed**) |
| plan-implement | autonomie | ledger + PLAN | completed/blocked | `workflow/spec.md:109-116` (**confirmed**) |
| ops-stop / permissions | destructive etc. | risk brief / deny | HITL | router + plan-ready-guard Claude (**confirmed**); Pi guard parity **approximate** |
| verify / review | claim / diff | evidence | pass/fail | skills + smokes (**confirmed**) |
| dogfood UI | product flows | matrix | pass/blocked | `product-dogfood.md` (**proxy-supported**) |
| mémoire obvault | retrieve when | context pack | untrusted citations | `obvault-memory.md` (**confirmed**) |
| télémétrie | ledgers | metrics/retrospect | recommendations | scripts read-only (**confirmed**) |
| self-improvement | failures | candidates | PLAN READY then implement | `self-improvement-loop.md` (**confirmed**) |
| vNext eval | suite tasks | trials/graders | pass@1 splits | `scripts/vnext-suite` 35 tasks (**confirmed**) |
| project-autonomy | envelope+ledger | next transition | never executes | `project-autonomy-envelope.md` (**confirmed**) |
| multi-model | score signals | sidecars | parent writer | multi-model-orchestration (**confirmed**) |
| no-progress | 2 hyp / 3 red | `no_progress` event | blocked | `workflow/spec.md:160-162` (**proxy-supported**: contract+event schema; runtime agent-dependent) |

**Dépendances critiques:** READY gate → plan-ready-guard (Claude) + router semantics; ops-stop patterns dans les deux adapters via core; ledger schema v2 (`scripts/lib/workflow-event-detail.jq`); capabilities matrix (`workflow/runtime-capabilities.json` + smoke).

---

## 2. Invariants transverses — solide vs doc-only

| Invariant | Classification | Garanti-par | Preuve |
| --- | --- | --- | --- |
| **One execution artifact (PLAN.md)** | **confirmed** (doc + dual-path routing + smokes) | Contract `workflow/spec.md:81`; agent-scenarios READY vs prompt-only; docs smoke | `tests/agent-scenarios/prompt-only-ready-no-implement/`; `real-ready-implements/` |
| **One-writer (parent-only mutations multi-model)** | **proxy-supported** | Contract multi-model + portfolio; event multi_execution | `workflow/skills/multi-model-orchestration.md:5-26`; not a hard OS lock |
| **READY gate before implement** | **confirmed** (Claude tool deny); **approximate** (Pi) | Claude `plan-ready-guard.mjs` + `planReadyGuardDecision`; router refuses implement without proven READY | `claude/hooks/plan-ready-guard.mjs`; `workflow-router-lib.mjs:688-702`; `claude/settings.workflow-hooks.json` |
| **Check-freeze** | **prose + docs pin** | Spec text + docs-smoke string contain only | `workflow/spec.md:163-166`; `tests/workflow-docs-smoke.sh:382` — **no runtime enforcer** when agent weakens READY checks |
| **ops-stop / destructive / write-back / secrets** | **confirmed** | Shared router patterns + evals + scenarios + filter-output redaction (Pi) | `workflow/spec.md:239-256`; baseline router-eval ops_stop_misses=0; `pi/extensions/filter-output.ts` |
| **No auto-apply retrospect** | **confirmed** (script contract) | retrospect never applies; self-improvement forbids auto-apply; event fixture rejects auto-apply candidate | `scripts/workflow-retrospect` line ~16; `self-improvement-loop.md:67-68,95`; `tests/workflow-event-smoke.sh:67` |
| **Untrusted retrieval (obvault)** | **confirmed** (contract + smoke language) | obvault-memory trust section; graph pack trust label | `workflow/skills/obvault-memory.md:15,102`; graph-neighborhood trust field |
| **Capability freshness** | **confirmed** (mechanical smoke) | stale confirmed/proxy fails runtime-capabilities-smoke | `tests/runtime-capabilities-smoke.sh`; matrix labels (**confirmed** non-stale at 2026-07-24 for listed claims; several expire 2026-07-26) |
| **Answer-quality floor** | **confirmed** | check + eval fixtures + audit smokes in infra | `scripts/answer-quality-*`; `tests/fixtures/answer-quality/`; agentic-infra-checks |
| **Held-out / grader semantics (vNext + harness candidates)** | **confirmed** when suite used | harness_validation_completed schema; vNext meta-run-finished-not-success; sealed held-out fraction | `workflow/events.md:86-91`; `scripts/lib/vnext-suite.mjs`; inventory sealed≈0.37 |
| **No-progress stop** | **proxy-supported** | Spec + event type + docs smoke; enforcement is agent/loop discipline | `workflow/spec.md:160-162`; `workflow/events.md` `no_progress` |
| **Fresh-context final review (autonomous plan-implement)** | **proxy-supported** | Spec requires subagent/external; stop blocked if no runner | `workflow/spec.md:169-172` — not a CI assertion that a review happened |
| **Ledger for autonomous routes** | **proxy-supported** | Spec must-record; schema enforced if events written; ordinary work optional | `workflow/spec.md:158-159`; `scripts/workflow-event` |
| **PLAN not committed** | **confirmed** (Claude hook) | plan-commit-guard | `claude/hooks/plan-commit-guard.mjs` |

---

## 3. Doublons, contradictions, zones mortes, contrôles trop faibles

### Doublons / dual paths

| Item | Observation | Confiance |
| --- | --- | --- |
| Router Claude vs Pi | **Amélioré:** core unique `workflow/runtime/workflow-router-core.mjs` réexporte `workflow-router-lib.mjs`; Pi runtime thin wrapper | **confirmed** |
| Skills Claude commands vs Pi skills | Parallel surfaces (`claude/commands/*`, `pi/skills/*`) for plan-implement, etc. — adapter pattern **intentional** (ADR agent surfaces) | **confirmed** |
| READY enforcement | Claude PreToolUse hard deny; Pi relies more on extension/router guidance — **asymétrie** | **confirmed** |
| Docs smoke volume | Large string-pin suite (`workflow-docs-smoke`) duplicates many contract sentences — high maintenance, low behavioral proof | **approximate** |

### Zones mortes / opt-in verts trompeurs

| Item | Observation | Confiance |
| --- | --- | --- |
| `tests/workflow-cli-smoke.sh` | Skips with **exit 0** unless `RUN_AGENT_CLI_SMOKE=1` | **confirmed** `tests/workflow-cli-smoke.sh:54-56` |
| `tests/workflow-real-agent-scenarios.sh` | Skips exit 0 unless `RUN_REAL_AGENT_SCENARIOS=1`; **not** the main live proof in default CI path | **confirmed** lines 13-15 |
| Multi-model real smoke | Opt-in `RUN_REAL_MULTI_MODEL` | **confirmed** (capability proof_commands) |
| Capabilities near expiry | `pi.supports_subagents` / `taskexecute_tracking` expire **2026-07-26** (2 days after audit date) | **confirmed** matrix + calc |
| Large dirty worktree | Uncommitted vNext/graph/project-autonomy/kimi — vérité opérationnelle ≠ HEAD commit | **confirmed** `git status` baseline |

### Contrôles trop faibles

| Item | Observation | Confiance |
| --- | --- | --- |
| Check-freeze | Docs pin only; agent can weaken Checks on READY plan without demoting to CHALLENGED | **confirmed** absence of runtime guard |
| no_progress | Schema exists; no continuous monitor forces stop mid-session | **approximate** |
| Outcome metrics | `tokens_per_successful_outcome` counts ledger “success” outcomes, historically often “run completed” not task grader | **confirmed** research + metrics script structure; **approximate** on historical mix |
| Live effectiveness | Explicitly waived / opt-in elsewhere; not part of default green suite | **confirmed** vNext research/live-blocked artifacts |

### Contradictions potentielles

- **“Canonical suite green” vs “real agent fidelity”:** verify-agentic-infra EXIT:0 **confirmed**, yet real multi-harness agent behavior remains mostly opt-in (**confirmed** skip paths).
- **Capability labels:** honest `unknown`/`proxy_supported` coexist with marketing-level “war machine” language in older docs — operational truth is the matrix (**confirmed**).

---

## 4. Scorecard par boucle

Légende des cellules: **oui** = mécanisme + preuve locale; **partiel** = contract fort mais gap d’enforcement/couverture; **non** = absent ou trompeur; **n/a** = non applicable à la boucle.
Chaque ligne porte un label de confiance sur l’ensemble de la ligne et une preuve (path/commande).

| Boucle | Bornée | Observable | Reprenable | Vérifiable | Arrêt no-progress | Confiance | Preuve |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Router / ops-stop | oui | oui | n/a | oui | n/a | **confirmed** | `workflow/spec.md:239-256`; baseline `scripts/verify-agentic-infra all` router-eval accuracy=1 ops_stop_misses=0; `tests/agent-scenarios/destructive-routes-ops-stop/` |
| plan-loop | oui | oui | partiel | partiel | n/a | **confirmed** | `workflow/spec.md:221-224`; stop READY/CHALLENGED; resume via PLAN.md only (no ledger required for ordinary plan-loop) |
| adversary | oui | oui | partiel | partiel | n/a | **confirmed** | `workflow/spec.md:39-40,224`; event `adversary_completed` in `workflow/events.md`; validation agent/process not CI-forced |
| implement | oui | oui | partiel | oui | partiel | **confirmed** | READY-only `workflow/spec.md:67,225`; Claude `claude/hooks/plan-ready-guard.mjs`; archive `docs/plan/`; no-progress agent-dependent `workflow/spec.md:160-162` |
| plan-implement autonome | oui | oui | oui | oui | partiel | **confirmed** | `workflow/spec.md:109-116,158-162`; ledger `.workflow/<slug>/events.jsonl`; profile `autonomous-completed` via `scripts/workflow-event`; no-progress if events emitted |
| /goal | oui | partiel | partiel | partiel | partiel | **approximate** | Cap/iterations host-prompt; `pi.supports_goal_state` / `claude|codex.supports_goal_state` = **unknown** in `workflow/runtime-capabilities.json` (2026-07-23/19) |
| ci-fix | oui | oui | partiel | oui | oui | **proxy-supported** | `workflow/spec.md:168` attempt/time caps; skill `workflow/skills` / `ci-fix`; live gh path not re-run this audit (**blocked** without PR) |
| review / pr-* | oui | oui | partiel | partiel | n/a | **confirmed** | Routes in `workflow/spec.md` table; HITL write-back contracts; not full multi-runtime e2e here |
| dogfood | oui | oui | partiel | partiel | n/a | **proxy-supported** | `workflow/skills/product-dogfood.md`; `dogfood_*` events `workflow/events.md`; blocked-human allowed |
| obvault memory | oui | oui | n/a | partiel | n/a | **confirmed** | Token cap `obvault-memory.md` + `scripts/graph-neighborhood`; smokes `tests/obvault-query-smoke.sh`, `tests/graph-neighborhood-smoke.sh`; live vault multi-hop fixture-isolated |
| self-improvement | oui | oui | oui | oui | partiel | **confirmed** | `workflow/skills/self-improvement-loop.md:29-48,92-104`; held-in/out + `harness_validation_completed` schema `workflow/events.md:86-91` |
| retrospect | oui | oui | n/a | oui | n/a | **confirmed** | Read-only `scripts/workflow-retrospect` (~line 16 never applies); `tests/workflow-retrospect-smoke.sh` in agentic-infra manifest |
| vNext suite | oui | oui | n/a | oui | n/a | **confirmed** | `scripts/vnext-suite`; inventory 35 tasks sealed≈0.37; meta-run-finished-not-success in `scripts/lib/vnext-suite.mjs` |
| project-autonomy | oui | oui | oui | oui | oui | **confirmed** | `workflow/project-autonomy-envelope.md`; `scripts/project-autonomy` read-only; envelope thresholds 2 hyp / 3 red; `tests/project-autonomy-smoke.sh` if present |
| multi-model panel | oui | oui | partiel | partiel | partiel | **confirmed** | `workflow/skills/multi-model-orchestration.md` parent-only writer + budgets; quality fixtures small (`tests/multi-model-quality-score-smoke.sh`); live panel opt-in |

**Synthèse scorecard:** les boucles de **routing / permissions / vNext / retrospect / self-improvement design** sont les plus solides (**confirmed**). Les boucles **host-dependent** (`/goal`, live ci-fix end-to-end) restent **partiel** ou **approximate** faute de preuve live dans cette session.

---


## 5. Autonomie — scope, budget, permissions, checkpoints

| Mécanisme | Scope | Budget | Permissions | Checkpoint humain | Verdict |
| --- | --- | --- | --- | --- | --- |
| plan-implement | READY gate, archive rules | iterations/time in plan | ops-stop + ready-guard (Claude) | external write / ops-stop | **Suffisant P1 gaps** (Pi guard, check-freeze, ledger optional ordinary work) |
| /goal | user prompt + host | host-dependent | same | same | **P1** — host variance; goal_state capability often **unknown** |
| ci-fix | PR checks | attempt/time caps | explicit push exception | merge/deploy still HITL | **Suffisant** if skill followed (**proxy-supported**) |
| project-autonomy envelope | files/tools/slices explicit | max iterations/duration/≤8 candidates | forbidden_actions + never launches agents | named `human_checkpoint` | **Fort design** (**confirmed**); adoption optional |
| multi-model | adaptive score | token budgets in contract | parent-only write | none required | **Suffisant** pour sidecars lecture |
| self-improvement | evidence → PLAN | via implement loop | no auto-apply | READY + review | **Suffisant** |

**Gaps P0**

1. **Check-freeze non mécanisé** — autonomie peut affaiblir les checks READY silencieusement.
2. **READY/mutation hard-deny Claude-first** — Pi/Codex moins durs pour PreToolUse équivalent.

**Gaps P1**

3. Ledger obligatoire surtout “autonomous routes”; oubli de ledger = perte de reprise.
4. Fresh-context review “must” is process, not CI-enforced.
5. Capabilities subagents/task RPC close to expiry (2026-07-26).

---

## 6. Rétrospective, mémoire, reward-hacking

| Surface | Rôle | Apply? | Risque dérive |
| --- | --- | --- | --- |
| `workflow-retrospect` | cluster issues → candidates | **Never** (**confirmed** script) | Faible si respecté; **élevé** si l’agent ignore et patch sans PLAN |
| self-improvement-loop | held-in/held-out + reject log | Only via READY PLAN | Bien conçu; reward-hack adressé (held-out, no weaken checks) |
| harness_validation_completed | schema enforces strict gain | n/a | **confirmed** jq schema |
| obvault | durable memory | shadow/capture only auto | dual-write tickets = dérive (ADR forbids) |
| vNext / meta-run-finished | forbids run-finished-as-success | n/a | **confirmed** grader invariant |
| outcome_metric history | may treat “completed run” as success | n/a | **approximate** semantic weak for productivity |

**Reward-hacking residual:** narrow smokes + docs-smoke string pins can be gamed without improving user outcomes (**approximate**). Mitigation path exists (vNext graders, held-out, adversary) but daily usage still optional.

---

## 7. Mesure d’efficacité quotidienne

| Signal | Ce qu’il prouve | Ce qu’il ne prouve pas | Confiance |
| --- | --- | --- | --- |
| `tokens_per_successful_outcome` | Consommation tokens / outcomes marqués success dans ledgers | Vitesse humaine, qualité produit, “run completed” ≠ tâche utilisateur | **confirmed** for definition; **approximate** value |
| `scripts/vnext-suite` (35 tasks) | Deterministic host/control-plane outcomes + graders | Multi-turn paid agent reliability (live opt-in / waived) | **confirmed** |
| router-eval / agent-scenarios | Routing & permission matrix offline | Full agent tool loops | **confirmed** |
| answer-quality-eval | Floor on durable answer artifacts | Subjective 10/10 or live satisfaction | **confirmed** |
| multi-model quality fixtures | Small corpus (3 fixtures historically) | Broad quality | **confirmed** small |
| Live `RUN_REAL_*` / LIVE_EVAL_BUDGET | Optional real CLI | Default CI health | **blocked** unless env set |
| workflow-efficiency-report | Instruction budget / suite inventory | Productivity | **confirmed** scope-limited |

**Missing measure (P1):** small recurring **grader-backed** sample of real daily tasks (even offline deterministic + occasional live with budget), tracked as population_id over time — not more tokens dashboards.

---

## 8. Corrections concrètes (P0 → P2)

### P0

#### C1 — Mécaniser check-freeze
- **Problème prouvé:** Spec imposes check-freeze (`workflow/spec.md:163-166`) but only docs-smoke string pin (`tests/workflow-docs-smoke.sh:382`); no guard compares READY plan checks across edits.
- **Surface:** Claude/Pi plan guards or a `scripts/plan-check-freeze` invoked from implement path; optional PreToolUse on PLAN.md edit.
- **Contrôle/test:** Fixture: READY plan with Checks A; edit that weakens a check → fail unless status CHALLENGED + Decision Log.
- **Régression:** Legitimate strengthening of checks must still pass.
- **Validation:** New smoke exit 0; docs-smoke can stay as secondary pin.

#### C2 — Parité READY mutation gate (Pi / non-Claude)
- **Problème prouvé:** `plan-ready-guard` wired in Claude hooks (`claude/settings.workflow-hooks.json`); Pi has router/extension but no identical PreToolUse deny surface for all write tools.
- **Surface:** `pi/extensions` tool hooks or shared guard reused from `planReadyGuardDecision`.
- **Contrôle/test:** Extend agent-scenarios / pi tests: draft PLAN blocks mutating bash/write.
- **Régression:** READY implement path must remain allow.
- **Validation:** Pi extension test + agent-scenarios parity green.

#### C3 — Ne pas confondre skip opt-in et preuve live
- **Problème prouvé:** `workflow-cli-smoke` and `workflow-real-agent-scenarios` exit 0 when skipped (`RUN_*` unset). Canonical green does not prove live multi-runtime fidelity.
- **Surface:** docs + optional separate CI job label; report “live_coverage: skipped” in verify summary; do not change default skip without budget.
- **Contrôle/test:** verify-agentic-infra or efficiency report prints explicit `live_agent_proof: skipped|ran`.
- **Régression:** Local default stay fast.
- **Validation:** Log line present; no false “all agents proven” claim in README.

### P1

#### C4 — Refresh / relabel capabilities before 2026-07-26
- **Problème prouvé:** `pi.supports_subagents` and `taskexecute_tracking` expire 2026-07-26 (**confirmed** matrix).
- **Surface:** `workflow/runtime-capabilities.json`
- **Contrôle/test:** existing runtime-capabilities-smoke
- **Régression:** none if re-proof or honest unknown
- **Validation:** smoke green without date-only refresh

#### C5 — Lier outcome_metric aux graders de tâche
- **Problème prouvé:** metrics aggregate “success” from ledger outcomes; research notes semantic gap vs final-state graders.
- **Surface:** event writers + workflow-metrics docs/fields
- **Contrôle/test:** optional `grader_success` field; metrics distinguish `run_terminal` vs `task_grader`
- **Régression:** historical ledgers remain readable
- **Validation:** metrics JSON documents both denominators

#### C6 — Ledger hygiene for autonomous runs
- **Problème prouvé:** autonomous must record ledger (`spec.md:158-159`) but missing ledger is not CI-detectable for completed autonomous claims.
- **Surface:** autonomous completion checklist smoke on sample ledgers; archive template requires run_id
- **Contrôle/test:** fixture incomplete autonomous ledger fails `workflow-event validate --profile autonomous-completed` (already exists) — document as mandatory evidence in ship skill
- **Régression:** ordinary work stays optional
- **Validation:** ship/plan-implement skill smoke pin

#### C7 — Shrink docs-smoke / raise behavioral fixtures
- **Problème prouvé:** large prose pin suite vs golden principles “mechanical check not prose” (`spec.md:182-187`).
- **Surface:** `tests/workflow-docs-smoke.sh`
- **Contrôle/test:** replace third duplicate pin with behavioral fixture when pattern recurs
- **Régression:** temporary coverage gaps if removed carelessly
- **Validation:** behavioral smoke covers same invariant

### P2

#### C8 — Publish dual-runtime READY matrix in one smoke
- **Problème:** Parity documented partially; single table Claude vs Pi vs Codex for READY/ops-stop/guard.
- **Surface:** tests + docs/codex organization
- **Validation:** one smoke prints matrix status per runtime capability honestly

#### C9 — Sample daily task population (offline-first)
- **Problème:** efficiency story incomplete without recurring graded sample
- **Surface:** extend vNext population carefully with real failures
- **Validation:** population_id versioned; no live required

**Aucune correction ci-dessus n’est un auto-apply du harness.** Toutes passent par PLAN READY + review.

---

## 9. Feuille de route (valeur × sécurité)

| Ordre | Item | Pourquoi maintenant |
| --- | --- | --- |
| 1 | **C1 check-freeze mécanique** | Protège l’autonomie sans élargir le blast radius |
| 2 | **C2 READY guard Pi** | Ferme l’asymétrie Claude/Pi sur mutations pré-READY |
| 3 | **C4 capabilities re-proof** | Évite rouge suite dans ~2 jours |
| 4 | **C3 live-skip honesty** | Empêche sur-confiance CI |
| 5 | **C5/C6 outcome + ledger semantics** | Mesure et reprise plus honnêtes |
| 6 | **C7 docs-smoke diet** | Maintenabilité |
| 7 | **C8/C9** | Portability matrix + efficacité long terme |

**Hors roadmap immédiate:** Neo4j/vector DB, bulk stale obvault, dashboard, auto-apply, live spend sans budget.

---

## Baseline command evidence (this audit)

| Command | Result | Confidence |
| --- | --- | --- |
| `git rev-parse HEAD` | `89025591…` | **confirmed** |
| `git status --short` | Dirty worktree: vNext/graph/project-autonomy/kimi uncommitted + capability/docs mods | **confirmed** |
| `scripts/verify-agentic-infra all` | **EXIT:0** (includes router-eval accuracy=1, alignment=1, ops_stop_misses=0) | **confirmed** |
| `scripts/vnext-suite --inventory` | ok, 35 tasks, sealed held-out ≈0.37 | **confirmed** |
| Live agent CLI / real scenarios | Not run (`RUN_*` unset) | **blocked** needed_input=`RUN_REAL_AGENT_SCENARIOS=1` and/or `RUN_AGENT_CLI_SMOKE=1` for live claims |

---

## Synthèse

Etabli est déjà un **control plane evidence-first** mature: routing partagé, READY/ops-stop, ledgers typés, self-improvement sans auto-apply, answer-quality floor, vNext graders, project-autonomy envelope, suite canonique **verte** sur le HEAD observé (**confirmed**).

Les risques prioritaires ne sont pas « manquer une plateforme multi-agent », mais:

1. **invariants d’autonomie encore trop prose** (check-freeze),
2. **parité d’enforcement multi-runtime** (READY writes),
3. **vert CI ≠ preuve live / ≠ productivité réelle**,
4. **fraîcheur capabilities** à très court terme.

La fiabilisation la plus rentable = **mécaniser ce qui est déjà écrit**, pas ajouter de boucles.

---

*Audit read-only. Worktree utilisateur préservé. Aucun commit/push/deploy.*
