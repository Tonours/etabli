# Carte des surfaces du harness — Etabli (v2, 2026-08-01)

**Objectif :** expliciter non seulement les contrôles, mais aussi leurs frontières de confiance.
**État :** sources actuelles inspectées ; les libellés « gap » décrivent une limite observée, pas une régression déjà corrigée.
**Artefact :** untracked ; à versionner/valider en CI séparément pour devenir un audit durable.

## Surface et niveau d'enforcement

| Surface | Rôle | Ce qu'elle enforce réellement | Limite / risque observé |
| --- | --- | --- | --- |
| `claude/hooks/workflow-router-lib.mjs` | Router partagé, READY/check-freeze/no_progress | Normalise Write/Edit/MultiEdit/Bash et bloque les mutations reconnues | `MUTATING_BASH_PATTERN` est heuristique ; `node -e`, `python3 -c`, `git apply`, `install` sont allow en DRAFT/no_progress dans une reproduction de guard contrôlée. |
| `workflow/runtime/workflow-router-core.mjs` | Adaptateur commun Pi/Claude | Réexporte `planMutationGuardDecision` | Ne crée pas de politique supplémentaire ni de sandbox. |
| `pi/extensions/workflow-router.ts` | Hook Pi route + tool_call/result | Applique le guard partagé et borne les rôles portfolio | `guardPortfolioCall` ne couvre que les rôles portfolio; les tools inconnus héritent de la classification commune. |
| `claude/hooks/plan-ready-guard.mjs` | Hook Claude PreToolUse | Applique le guard partagé | Même surface heuristique Bash que Pi. |
| `scripts/lib/no-progress-guard.mjs` | Stop ledger pour mutation deny | Dérive 2 mêmes hypothèses / 3 reds et traite les ledgers non-terminaux | Ignore les lignes JSON invalides ; un terminal n'importe où clôt le ledger ; pas de session/lease actif. |
| `scripts/lib/ledger-auto-emit.mjs` | Auto-écrit `validation_failed`/`no_progress` | Ajoute des événements à un ledger actif, choisit le plus récent | Append sans provenance/sequence forte ; déduplique sur texte et ne prouve pas que le process a réellement tourné. |
| `claude/hooks/ledger-auto-emit.mjs` | Producer Claude post-tool | Ne traite que Bash/Shell | Échecs non-Bash non observés. |
| `pi/extensions/workflow-router.ts` `tool_result` | Producer Pi post-tool | Ne traite que `isBashToolName` | Échecs tests/outils hors Bash non observés. |
| `scripts/workflow-event` | Append + validation de ledger | Vérifie enveloppe v2, détails et ordre structurel | Ne lie pas événements à Git, process, sortie, archive ou reviewer réel. |
| `scripts/lib/workflow-event-detail.jq` | Schéma de détail | Vérifie types, champs et quelques invariants de compteurs | `candidate`, populations, checks/evidence sont textuels ; pas de manifest/diff/receipt obligatoire. |
| `scripts/workflow-loop-adherence` | Vue dérivée d'adhérence | Vérifie présences/ordre/grade task_grader | Consomme le ledger auto-déclaré ; ne valide pas les artefacts référencés. |
| `scripts/lib/project-autonomy.mjs` | Contrôleur opt-in read-only | Valide enveloppe, séquence de slice et `file_changed` déclarés | Les `allowed_files`/`allowed_tools` sont déclaratifs : aucun hook n'atteste les tool calls ou le vrai diff. |
| `workflow/project-autonomy-envelope.md` | Contrat d'autonomie bornée | Déclare budget, checkpoints, `sealed_held_out` | Ne signifie pas que le runner est isolé ; controller non-executor. |
| `workflow/runtime-capabilities.json` | Vocabulaire de capacité/fraîcheur | Empêche de requalifier sans proof command | `supports_subagents` est coarse/unknown ; à scinder par primitive (`Agent`, portfolio, TaskExecute, goal). |
| `pi/extensions/lib/workflow-router-runtime.ts` | Guidance multi-exec Pi | Passe `pending` lorsque `hasAgentTools` est vrai | Ne consulte pas la capability matrix pour cette admission. |
| `pi/extensions/workflow-router.ts` `guardPortfolioCall` | Budget/ordre sidecars Pi | Borne rôles, resumes, fallback et adjudication portfolio | One-writer reste une règle/proxy ; pas de verrou OS ni enforcement général enfant. |
| `pi/agents/etabli-*.md` | Portfolios read-only | Pins `read,grep,find,ls` | Couvre les rôles définis, pas toutes les primitives/agents potentiels. |
| `workflow/vnext/population.json` + `tasks.json` | Corpus d'évaluation | Fige le corpus et cible une fraction held-out | Tous les cas, y compris 13 `sealed:true`, sont trackés/lisibles : **frozen public**, pas held-out secret. |
| `scripts/lib/vnext-suite.mjs` | Grader final offline | Exécute drivers/grader déterministes et hash le corpus | Un candidat dans le même worktree peut lire/modifier les graders sans une séparation de promotion. |
| `scripts/workflow-retrospect` | Mine les issues récurrentes | Read-only, min-count et recommandations | Pas de candidate/diff hash, pas de population fixe, mapping `harness_failure_pattern` → `contract_patch`. |
| `scripts/workflow-metrics` | Agrège outcomes/candidates | Distingue usage/outcome et compare par candidate | Agrège les données de ledger ; ne transforme pas une auto-attestation en reçu vérifié. |
| `scripts/verify-agentic-infra` | Suite de checks | Orchestration core/full/live avec messages de remédiation | `core` vert est une baseline, pas une preuve de toutes les surfaces d'audit ; CI shell-docs exécute davantage de smokes. |
| `.github/workflows/agentic-infra.yml` | CI | Lance `shell-docs`, `pi`, `nvim` | Les cinq docs audités étant untracked, ils n'entrent pas encore dans la CI. |

## Flux et frontières de confiance

```text
user intent
  → router / route guidance
  → tool_call guard (policy, mais classification incomplète)
  → tool execution (vérité runtime à attester)
  → tool_result hooks (Bash seulement aujourd'hui)
  → events.jsonl (schéma structuré, mais auto-déclaratif)
  → guards / project-autonomy / metrics (consomment le ledger)
  → evaluator vNext (frozen public corpus)
  → promotion / archive (doit rester READY-gated et humaine)
```

Les frontières marquées « policy » ou « auto-déclaratif » ne doivent pas être présentées comme des barrières OS, cryptographiques ou comme des preuves indépendantes.

## P0 à relier avant d'augmenter l'autonomie

1. **Tool authority :** policy fail-closed pour Bash/interpréteurs/tools inconnus.
2. **Ledger integrity :** invalidité/terminal hors ordre bloque, run actif lié à une session et append observable.
3. **Evidence receipts :** diff, commandes, outputs, review et archive proviennent de hooks/artefacts, pas seulement de texte ledger.
4. **Evaluation integrity :** manifest et candidate fingerprintés ; held-out public renommé et isolé avant toute promotion forte.

## Contrôles existants à préserver

- READY + check-freeze via `planMutationGuardDecision`.
- no_progress 2-hypothèses / 3-reds comme règle de stop, après correction de l'intégrité ledger.
- `workflow-retrospect` read-only et no auto-apply.
- Labels de capacité et le refus de transformer `unknown` en `confirmed`.
- Distinction task grader / télémétrie tokens.
