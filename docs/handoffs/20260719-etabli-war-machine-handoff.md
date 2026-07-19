# Handoff audité — Etabli War Machine

## Statut et verdict

- Date de revue : 2026-07-19
- Statut : `REVIEWED`
- Verdict repo : `change`, sur une tranche bornée de mesure comparative du
  harness.
- Transfert des gains externes : `not verified for Etabli`.
- Source de vérité workflow : `workflow/spec.md`, pas ce document.
- Source de vérité de cette revue : ce fichier; les trois autres handoffs du
  lot pointent ici.

Le handoff tiré depuis `origin/main` n'était pas implémentable tel quel. Le
fichier demandé contenait un placeholder, se déclarait source de vérité et
ordonnait un commit ainsi que des commandes non listées. Le contenu détaillé
était dispersé dans trois fichiers concurrents, avec des auteurs, statuts et
roadmaps incompatibles.

## Périmètre et provenance

Le lot audité correspond aux quatre commits consécutifs :

- `0fadd7fc` : création de `docs/handoff.md`;
- `c7b471e9` : seconde synthèse;
- `f72e2eb5` : placeholder demandé;
- `d93ef6f0` : quatrième placeholder.

Le lot arrive après :

- `0d6afa5` du 2026-07-07, qui a déjà durci la boucle de
  self-improvement;
- `7222d22` du 2026-07-19, qui a déjà livré le council multi-modèle adaptatif.

Cette chronologie invalide la roadmap qui présente ces deux capacités comme
des phases futures.

## Findings de review

### Bloquants du handoff initial

1. **Artifact incomplet.** Le fichier cible contenait du texte entre crochets
   à la place de la recherche et du plan annoncés.
2. **Ownership incorrect.** Un handoff ne peut pas remplacer
   `workflow/spec.md` comme contrat canonique.
3. **Permission boundary violée.** La proposition « apply + commit » plaçait
   mutation et supervision dans la même boucle. Etabli interdit déjà
   l'auto-application de `workflow-retrospect` et n'infère jamais une
   autorisation de commit ou push.
4. **Duplication d'architecture.** Le nouveau skill/route `self-harness-evolve`
   aurait créé un second propriétaire pour un comportement déjà défini dans
   `workflow/skills/self-improvement-loop.md`.
5. **KPI sans baseline.** Les promesses de +15-25 %, +10-20 %, 30 % et >5 %
   n'ont ni population, ni période, ni protocole, ni baseline Etabli.

### Majeurs

1. Les classements d'outils, chiffres SWE-bench et consensus X/Reddit ne sont
   associés à aucune URL, version, date de mesure ou méthodologie.
2. Les gains Self-Harness mélangent points de pourcentage et gain relatif.
3. Le routage statique « type de tâche -> modèle » ignore le portfolio mesuré,
   les fallbacks, les caps et les preuves de provenance déjà en place.
4. Un launcher générique de 3-5 worktrees contredirait le parent-only writer et
   le pilote supervisé « one PR, one worktree, one loop ».
5. Le dashboard, la skill factory, la mémoire sémantique et l'intégration
   Cursor sont des idées de backlog sans failure evidence reproductible.

## Baseline observée avant cette tranche

| Proposition du handoff | État observé au 2026-07-19 | Décision | Preuve locale |
| --- | --- | --- | --- |
| Weakness Mining -> Proposal -> Validation | Déjà implémenté | `already implemented` | `workflow/skills/self-improvement-loop.md`, `docs/plan/20260707-harness-self-improvement-hardening.md` |
| Events de failure/proposal/rejection | Déjà implémenté | `already implemented` | `workflow/events.md`, `scripts/workflow-event` |
| Retrospect automatique | Déjà read-only et testé | `already implemented` | `scripts/workflow-retrospect`, `tests/workflow-retrospect-smoke.sh` |
| Routage multi-modèle | Déjà adaptatif, borné et probé | `already implemented` | `workflow/skills/multi-model-orchestration.md`, `docs/plan/20260719-adaptive-council-routing.md` |
| Tokens par outcome | Calcul déjà disponible, données insuffisantes | `already implemented` | `scripts/workflow-metrics --json` retourne `tokens_per_successful_outcome: null` |
| Validation comparative d'un candidat harness | Avant cette tranche, aucun event accepté ne portait une baseline et un candidat comparables | `accepted gap` | Les events existants couvraient failure/proposal/rejection, pas le crédit comparatif |
| Mémoire cross-session | obvault existe déjà avec retrieval borné | `already implemented` | `workflow/skills/obvault-memory.md` |
| 3-5 agents/worktrees automatiques | Pas de besoin démontré; isolation/ownership non spécifiés | `rejected` | `workflow/skills/pr-maintenance-loop.md`, one-writer rule |
| Nouvelle route/skill Self-Harness | Double source de vérité | `rejected` | `workflow/spec.md`, `workflow/skills/self-improvement-loop.md` |
| Proxy multi-modèle | Contournerait les capacités et provenance vérifiées | `rejected` | `workflow/runtime-capabilities.json` |
| Skill factory, dashboard HTML, Cursor bridge | Pas de failure evidence ni validation surface actuelle | `parked` | `scripts/workflow-retrospect --json` |

## Vérification des sources externes

Les sources ci-dessous sont des preprints récents, pas une certification de
gain pour Etabli.

- [Self-Harness](https://arxiv.org/abs/2606.09498) décrit bien Weakness Mining,
  Harness Proposal et Proposal Validation avec regression tests. Les pass rates
  held-out publiés sont 40,5 -> 61,9, 23,8 -> 38,1 et 42,9 -> 57,1. Cela donne
  respectivement +21,4 pp (+52,8 % relatif), +14,3 pp (+60,1 % relatif) et
  +14,2 pp (+33,1 % relatif). « +20-60 % » n'est donc acceptable qu'en nommant
  la métrique et le modèle; ce n'est pas un gain Etabli attendu.
- [Self-Evolving Agent Harnesses via Gated Semantic Quality-Diversity](https://arxiv.org/abs/2607.13683)
  sépare explicitement la proposition LLM du crédit détenu par du code
  déterministe et mesure la généralisation sur un test scellé. Cette séparation
  justifie la tranche acceptée.
- [Harness Updating Is Not Harness Benefit](https://arxiv.org/abs/2605.30621)
  montre que produire une mise à jour utile et savoir en bénéficier sont deux
  capacités distinctes; un meilleur evolver ne garantit pas un meilleur agent.
- [Retrospective Harness Optimization](https://arxiv.org/abs/2606.05922),
  [AHE](https://arxiv.org/abs/2604.25850),
  [HASE](https://arxiv.org/abs/2607.03935),
  [Meta-Harness](https://arxiv.org/abs/2603.28052),
  [TRACE](https://arxiv.org/abs/2604.05336) et
  [StructAgent](https://arxiv.org/abs/2607.11388) sont pertinents comme
  recherche, mais leurs protocoles et environnements ne permettent pas
  d'extrapoler directement un pourcentage de gain sur Etabli.

## Décision d'implémentation

Une seule tranche est acceptée :

1. ajouter un événement comparatif strict pour un candidat harness;
2. exiger la même population baseline/candidat pour held-in et held-out;
3. n'accepter le candidat qu'avec gain held-in strict et non-régression
   held-out;
4. exposer couverture, verdicts et deltas en points de pourcentage par
   candidat;
5. ne jamais moyenner des suites hétérogènes et retourner `null` sans preuve;
6. garder proposal, validation, métriques et application derrière le
   `PLAN.md` `READY`, sans auto-apply, commit ou push.

Les trois documents concurrents sont conservés comme pointeurs pour préserver
l'historique Git, mais ne portent plus de recommandations actives.

## État post-implémentation

- `harness_validation_completed` porte, pour held-in et held-out, un identifiant
  de population stable et les comptes entiers `{passed,total}` de la baseline
  et du candidat.
- Le validateur exige la même population et le même total de part et d'autre,
  refuse les comptes incohérents, et n'accepte qu'un gain held-in strict sans
  régression held-out.
- `workflow-metrics` réunit propositions et validations par candidat. Un
  candidat proposé mais pas encore validé reste visible avec verdict, deltas,
  checks et preuve à `null`; une validation orpheline est signalée séparément.
- Les deltas restent exprimés en points de pourcentage par candidat. Aucune
  moyenne entre suites hétérogènes n'est produite.
- Le ledger de cette tranche expose une proposition encore non validée : la
  couverture comparative est donc `0`, et non un gain implicite.

## Validation observée

Les checks suivants ont passé sur le diff implémenté :

- `bash tests/workflow-event-smoke.sh`;
- `bash tests/workflow-metrics-smoke.sh`;
- `bash tests/workflow-docs-smoke.sh`;
- `scripts/answer-quality-check --mode handoff docs/handoffs/20260719-etabli-war-machine-handoff.md`;
- `scripts/research-proof-check docs/handoffs/20260719-etabli-war-machine-handoff.md`;
- `git diff --check`;
- `scripts/verify-agentic-infra all` : 219 tests Pi et 610 attentes,
  32 routes sur 32, skill lock, liens, installation et Neovim au vert.

Le smoke CLI réel reste conditionné à `RUN_AGENT_CLI_SMOKE=1`, et le contrôle
browser live a été ignoré faute de cible UI dans cette tranche; leurs checks
déterministes ont passé. Une revue fraîche read-only a d'abord bloqué cinq
écarts de contrat et de couverture de test; ils ont été corrigés avant la
validation finale.

## Risques restants

- Les runs historiques ne contiennent pas de validation comparative; les
  nouvelles métriques doivent donc rester `null` ou à zéro jusqu'à une vraie
  comparaison.
- Les deltas de suites différentes ne sont pas comparables et ne doivent pas
  devenir un score global.
- La télémétrie tokens reste insuffisante : 38 runs terminaux, 4 outcomes
  marqués measured, mais aucun succès avec tokens exploitables lors de cette
  revue.
- Les preprints cités sont récents et leurs résultats ne sont pas une preuve de
  performance future pour ce repo.

## Autorisations

Ce handoff n'autorise ni commit, ni push, ni PR, ni deploy, ni changement de
modèle/provider, ni écriture externe. Toute action de ce type conserve son gate
explicite.
