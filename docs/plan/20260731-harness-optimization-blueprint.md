# Implemented: Blueprint d’optimisation des harness Etabli

## Metadata

- Archived: 2026-07-31
- Source plan: Blueprint d’optimisation des harness Etabli
- Status: IMPLEMENTED
- Commit / branch: `main`, worktree non commité

## Outcome

Création de `docs/harness-optimization-blueprint.md`, un document français exécutable qui transforme cinq ambitions en programme expérimental falsifiable :

- −50 % de tokens totaux de tous les participants par succès task-grader;
- réduction de moitié du taux de claims matériels non sourcés, sans perte de completeness/recall;
- respect des loops mesuré depuis les événements schema v2;
- graph engineering borné en trois vues dérivées — exécution, preuve, connaissance;
- +100 % de performance, défini comme 2× le débit vérifié sur le makespan d’un batch à ressources gelées.

Le document ne prétend pas que ces gains sont déjà obtenus. Il fournit baseline, formules, floors de non-régression, architecture, candidats, protocole A/B, roadmap, scorecard, gates promote/reject/rollback et limites.

## Context

- `scripts/workflow-efficiency-report --json`: budget statique actuel 1 556/9 455 tokens estimés, ratio 0,1646; le prochain levier est le contexte dynamique, pas une compression aveugle du bootstrap.
- `scripts/vnext-suite --inventory`: 35 tâches, 13 sealed held-out, fraction 0,3714.
- `workflow/vnext/results/baseline-summary.json`: corpus offline enregistré 35/35; utilisé comme gate de régression, pas comme benchmark avec headroom.
- `scripts/workflow-metrics --json`: zéro succès task-grader avec usage mesuré et `tokens_per_successful_outcome: null`; les objectifs live restent `not verified`.
- `workflow/runtime-capabilities.json`: les capacités goal/subagents live restent honnêtement `unknown` ou `blocked`; les graphes nommés ne deviennent pas une nouvelle architecture.

## Decisions

### Définir les objectifs chiffrés sur des outcomes vérifiés

- Context: « −50 % tokens » et « +100 % performance » n’avaient ni dénominateur ni population.
- Choice: tokens totaux par succès task-grader et débit de succès par makespan de batch, sur population/configuration identiques.
- Rejected options: tokens parent-only, somme des durées comme débit, moyenne globale multi-axes.
- Rationale: ces métriques incluent les échecs et les coûts de coordination sans cacher une régression de qualité.
- Consequences: un budget live et une baseline appariée sont requis avant tout claim de gain.

### Rendre l’anti-hallucination non gameable

- Context: un simple ratio de claims non sourcés peut être amélioré par sous-réponse ou segmentation opportuniste.
- Choice: claims atomiques, corpus scellé, double annotation aveugle, arbitrage, floors completeness/recall et false-completion=0.
- Rejected options: auto-évaluation du producteur ou UCR sans rubric gelé.
- Rationale: le dénominateur et l’utilité restent contrôlés.
- Consequences: l’expérience initiale demande un travail d’annotation explicite.

### Réutiliser les sources de vérité et graphes existants

- Context: Etabli possède PLAN, ledgers et graph Markdown dérivé.
- Choice: vues dérivées d’exécution, de preuve et de connaissance avec fingerprints, fan-out/profondeur bornés et parent-only writer.
- Rejected options: Neo4j, vector DB, swarm permanent, second harness ou graph framework général.
- Rationale: aucun échec reproduit ne justifie leur overhead.
- Consequences: chaque graph futur doit prouver un gain supérieur à son coût et rester sous 10 % d’overhead.

## Accepted Drift

- Original plan/spec: première version du document avec protocole A/B général.
- Implemented reality: la fresh-context review a imposé une définition makespan du débit, un mapping exact états→events schema v2, une annotation anti-UCR-gaming et un bootstrap hiérarchique apparié.
- Why accepted: ces corrections ferment des ambiguïtés matérielles sans élargir le scope ni affaiblir les checks.

## Review Evidence

- Plan adversary initial: `GO WITH NOTES`; trois findings acceptés — total tokens de tous les participants, seuil anti-hallucination, vNext comme gate de régression.
- Fresh-context review initiale: `BLOCK`; six findings matériels acceptés et corrigés.
- Adversary code-diff cross-model: `zai/glm-5.2`, verdict `GO WITH NOTES`; cinq corrections confirmées, handoff résiduel corrigé, aucun blocker.

## Validation Evidence

- `scripts/research-proof-check docs/harness-optimization-blueprint.md`
  - result: passed.
- `scripts/answer-quality-check --mode research docs/harness-optimization-blueprint.md`
  - result: passed.
- `scripts/answer-quality-check --mode repo docs/harness-optimization-blueprint.md`
  - result: passed.
- `git diff --check`
  - result: passed.
- `scripts/verify-agentic-infra core`
  - result: passed; 224 Pi tests, router-eval 53/53, vNext/guards/contracts smokes green.
- LSP diagnostics on the Markdown artifacts
  - result: no diagnostics reported, but clean confirmation remains inconclusive for the silent Markdown surface.
- Pi-lens cached diagnostics
  - result: no issue on the dispatched document.

## Follow-up State

- Remaining risks: gains −50 %/+100 % live non mesurés; taille/power de l’échantillon à fixer avec le budget; certaines capabilities runtime live restent `unknown`.
- Parking lot: instrumentation de tous les participants, route context manifests, UCR grader, chaos/replay loop suite, graph execution/evidence seulement après baseline.
- Superseded docs/specs: aucun; ce blueprint consolide les recherches existantes sans remplacer les contrats canoniques.
- Next links:
  - `docs/harness-optimization-blueprint.md`
  - `.workflow/harness-optimization-blueprint-v2/events.jsonl` (profil `autonomous-completed` validé; le premier ledger reste un essai terminal invalide append-only)
