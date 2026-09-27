# Audit Etabli T9 : workflows, code mort, mesure des tokens, skills, bonnes pratiques

Date : 2026-09-27. Statut : audit avec correctifs livrés pour le runner, le code
mort et l'outil de mesure ; les recommandations de contrat (§6) restent des
suites, non appliquées. Ledger : `.workflow/etabli-audit-t9/`.

Méthode : exécution de chaque profil du runner avec comparaison des labels
lancés au manifeste ; sonde du stdin par cible ; graphe de références (nom,
chemin, radical ; une référence depuis `docs/plan/`, `docs/research/` ou
`.workflow/` ne prouve pas qu'un fichier est vivant) ; mesure de chaque
`SKILL.md` ; lecture des contrats ; sources externes relues pour les seuils de
skills, les autres reprises de la recherche déléguée et revérifiées contre le
dépôt ligne par ligne. Complète, sans les répéter,
`docs/research/20260917-harness-engineering-loops.md` et
`docs/research/20260924-skill-reliability-token-economy.md`.

Statut des preuves :

| Section | Statut | Base |
| --- | --- | --- |
| §1 workflows | verified | runs locaux du runner avant et après correctif, labels comparés au manifeste |
| §2 code mort | verified | `grep` en sortie brute, historique git des consommateurs |
| §3 mesures hors ligne | verified | `scripts/token-bench`, déterministe |
| §3 mesure `--live` | approximate | estimation de Claude Code ; les catégories MCP varient d'un run à l'autre |
| §4 skills | verified | `scripts/token-bench --skills` ; seuils relus aux sources primaires |
| §5 sources lues par la recherche déléguée | not verified | reprises sans relecture intégrale, sauf les deux docs de skills |
| §5 preuves `fichier:ligne` du dépôt | verified | relues ligne par ligne |
| §6 suites | assumption | effort et impact estimés, pas mesurés |

## 1. Workflows : 34 checks ne tournaient pas

| Constat | Preuve |
| --- | --- |
| `scripts/verify-agentic-infra full` affichait `SUMMARY: 46/46` alors que le manifeste déclare 80 lignes `core`+`full` | `workflow/runtime/agentic-infra-checks.tsv` ; log du run avant correctif |
| Les enfants `( … ) &` héritaient du flux `while read … < <(sed … manifeste)`. `tests/guards-active-smoke.sh` lit son stdin et consommait les lignes restantes | sonde : 3 lignes injectées, 0 restantes, pour cette cible seulement |
| Le résumé comptait les checks lancés, pas les checks déclarés : le vert était trompeur | `run_selection` dans `scripts/verify-agentic-infra` |
| La CI appelle les groupes `shell-docs` et `pi` avec la même boucle | `.github/workflows/agentic-infra.yml:33,69` |

Correctif : le stdin des enfants vient de `/dev/null`. Un test hermétique dans
`tests/agentic-infra-manifest-smoke.sh` copie le runner, le sérialise
(`AGENTIC_INFRA_JOBS=1`) et place une cible qui consomme stdin, puis une cible
rouge, puis deux autres cibles. Chaque label doit tourner une fois et la sortie
doit être non nulle. Sur le runner d'origine, seules 2 des 4 cibles tournaient.

Après correctif, les labels lancés sont identiques aux labels sélectionnés, sans
doublon, et tout passe :

| Sélection | Checks |
| --- | --- |
| `full` | 81/81 (80 plus `token-bench-smoke`) |
| `core` | 27/27 |
| `shell-docs` | 75/75 |
| `pi` | 6/6 |
| `bun test pi/extensions/__tests__/` | 355/355 |

Aucun des 34 checks devenus muets n'était rouge.

Non exécutés : le profil `live` (payant, opt-in `RUN_*`, rapporté `skipped`) et
`review-dispatch.yml` (runner Tailscale externe).

## 2. Code mort

### Supprimé (consommateur disparu, prouvé)

| Chemin | Preuve |
| --- | --- |
| `tests/fixtures/review-cost/`, `review-guidance/`, `review-priority/`, `review-spec-drift/` | leur seul consommateur a été retiré en `c148b72` ; plus aucune référence vivante |
| `workflow/self-improvement/manifests/core-v1.json`, `core-v2.json` | lus par `scripts/etabli-harness-eval*`, retirés en `c148b72` ; `core-v2` pointe vers `tests/fixtures/harness-v1/`, qui n'existe pas |
| `docs/jev-claim-pilot-20260922.json`, `docs/jev-review-pilot-20260922.json` | données de jev, retiré en `c2bfe92` ; aucune référence |
| `tests/fixtures/jev-plan-implement/` | non suivi par git : résidu d'un seed de ledger |

Après suppression, `grep` en sortie brute ne trouve plus ces chemins que dans
les archives `docs/plan/`.

### Conservé, avec raison

| Chemin | Raison |
| --- | --- |
| `tests/router-evals/fuzz-*.json`, `claude-hooks-sync.json` | chargés par `readdirSync` (`scripts/router-eval.mjs:73`) |
| `scripts/workflow-ship-metrics`, `scripts/workflow-ledger-census` | appelés seulement par `tests/ship-order-smoke.sh`, mais `workflow/skills/ship.md:131` exige le registre qu'ils écrivent sans nommer l'outil. Suite : le nommer dans le contrat, ou retirer l'outil |
| `scripts/workflow-adapter-sync`, `scripts/codex-skill-source-check`, `scripts/lib/skill-eval-ceiling.mjs` | gates hermétiques couverts par leurs smokes ; outils de maintenance qu'aucun contrat ne documente |
| `tests/adr-skill-e2e.sh` | e2e manuel payant, documenté dans son en-tête |
| `claude/scopes/work/scripts/routines/watchdog.sh` | routine launchd locale (`claude/README.md:54`) |
| `extras/skills/*/agents/openai.yaml` | métadonnées Codex des skills |
| `tests/fixtures/lean-bench/` | appartient au plan T4 mis de côté (`docs/plan/20260927-discarded-parked-t4-for-t9-audit.md`) |
| ligne `router-parity` du manifeste (même cible que `rule-registry`) | double label assumé et épinglé |
| `t8b-runs/` (non suivi) | artefacts de campagne T8b ; déplacés le 2026-09-27, sur décision de l'utilisateur, vers `~/work/archives/etabli-t8b-runs-20260925/` (hors dépôt) |

## 3. Benchmark token-efficiency : `scripts/token-bench`

| Mode | Mesure | Gate |
| --- | --- | --- |
| défaut, « declared-surface estimate » | pour chaque route : `always-on` plus la chaîne de lecture, et le pire cas avec les lectures conditionnelles. Réutilise `scripts/workflow-context-budget --json` et son estimateur `ceil(chars/4)` ; un dépassement de plafond est mesuré, un fichier manquant est refusé | `--check` contre `workflow/runtime/token-bench-baseline.json` : exit 1 au-delà de 3 % (exactement 3 % passe), exit 2 si la comparaison est invalide |
| `--live`, « observed Claude context estimate » | `claude -p "/context" --output-format json`, commande locale à 0 $ et 0 ms d'API. Rend les tokens par catégorie, le modèle et `claude --version` ; tout coût absent ou non nul est refusé | jamais : les catégories MCP varient avec l'état des connecteurs claude.ai |
| `--skills` | chaque `SKILL.md`, voir §4 | `--check` : exit 1 sur une violation dure d'une skill hors `vendor/` |

Mesures du 2026-09-27, arbre courant avec le diff T4 non commité :

| Route | est_tokens | pire cas |
| --- | --- | --- |
| always-on | 2 959 | — |
| plan-loop | 4 574 | 4 574 |
| plan-implement | 16 481 | 18 796 |
| implement | 15 140 | 17 455 |
| review | 8 430 | 8 430 |
| verify | 3 912 | 3 912 |
| ship | 23 186 | 33 748 |

`--live` dans le dépôt a mesuré 18,4 k tokens au démarrage (`claude-opus-5-5`,
Claude Code 2.1.283) :

| Catégorie | Tokens |
| --- | --- |
| Skills | 9 000 |
| MCP server instructions | 3 300 |
| Memory files | 3 200 |
| System prompt | 1 400 |
| Custom agents | 984 |
| MCP tools | 627 |

Le même appel lancé hors du dépôt donnait 16,5 k tokens, dont 2,5 k pour les
instructions des serveurs MCP.

Limites :
- L'outil mesure un coût, pas une qualité. Pour la qualité, voir
  `scripts/answer-quality-eval` et `scripts/claude-token-budget`, qui calcule
  un ratio avec une borne bootstrap (runs payants).
- La note du 2026-09-24 rappelle que le contexte accumulé domine le coût réel ;
  les instructions Etabli n'en représentent qu'environ 1 %. Ne pas couper
  d'instruction sur la seule foi de ces chiffres.
- Après commit ou abandon de T4, relancer `scripts/token-bench --write-baseline`.

## 4. Skills : taille, poids, format

Seuils relus aux sources primaires :
- Anthropic, « Skill authoring best practices » —
  https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices ;
- Claude Code, « Skills » — https://code.claude.com/docs/en/skills.

| Règle | Source | Traitement |
| --- | --- | --- |
| `name` : 64 caractères max, `[a-z0-9-]`, ni « anthropic » ni « claude » | spec Anthropic | dure |
| `description` : non vide, 1 024 caractères max, sans balise XML | spec Anthropic | dure |
| `description` + `when_to_use` : 1 536 caractères max, tronqué au-delà dans le listing | Claude Code | dure (politique Etabli) |
| corps de SKILL.md sous 500 lignes, une recommandation de performance | Anthropic, Claude Code | dure (politique Etabli) |
| après compaction, seuls les 5 000 premiers tokens de chaque skill invoquée sont ré-attachés | Claude Code | alerte (risque estimé) |
| références à un seul niveau de profondeur ; table des matières au-delà de 100 lignes | Anthropic | alerte |

Résultat de `scripts/token-bench --skills --check` :
- 95 skills distinctes (96 chemins ; `pi/skills/herdr` est un lien vers
  `herdr/skills/herdr`), dont 60 appartiennent au dépôt ;
- 0 violation dure ;
- 20 alertes ;
- listing des skills invocables par le modèle : 13 442 caractères pour 70 skills.

Les maximums restent loin des limites :

| Mesure | Maximum observé | Limite |
| --- | --- | --- |
| description d'une skill du dépôt | 582 (`extras/skills/goal-prompt-rewriter`) | 1 024 |
| description d'une skill vendor | 660 (`vendor/typesafe-ai`) | 1 024 |
| corps de SKILL.md | 421 lignes (`extras/skills/project-hunt`) | 500 |

Le poids médian d'une skill du dépôt est d'environ 740 tokens.

| Alerte | Skills |
| --- | --- |
| SKILL.md d'environ 6,3 k tokens estimés, au-delà des 5 000 ré-attachés après compaction | `extras/skills/project-hunt` |
| deux niveaux de références : `SKILL.md` → `design-guidelines.md` → 39 fichiers `guidelines/*.md` | `extras/skills/design` |
| références de plus de 100 lignes sans table des matières | `adr`, `employer-docs-writing`, `pr-qa`, `sec-pr`, `brand-kit`, `design` (3), `maintainer-orchestrator`, `project-hunt` (3) ; vendor : `adonisjs-backend` (2), `improve-codebase-architecture`, `prototype`, `triage` (2) |
| bloc `GENERATED:adapter-sync` dans 19 SKILL.md (671 caractères en moyenne, environ 170 tokens), qui répète `name`/`description`. Dans 7 cas, le fichier canonique se désigne lui-même comme contrat à suivre | `pi/skills/*`, `extras/skills/*` |

Recommandations sur les skills, non appliquées dans cette tranche parce que
`skills-lock.json` et les adaptateurs générés dépendent de ces fichiers :
1. `project-hunt` : passer le détail des requêtes et des sources dans
   `references/` pour garder SKILL.md sous 5 k tokens.
2. `design` : lier depuis SKILL.md les guidelines chargées le plus souvent, ou
   déclarer l'index comme lecture obligatoire.
3. Ajouter une section « Contents » aux références de plus de 100 lignes des
   skills du dépôt (le vendor se corrige en amont).
4. `scripts/workflow-adapter-sync` : ne plus générer de pointeur vers soi-même
   dans le fichier canonique.

## 5. Bonnes pratiques et recherche

### Sources

Relues directement pour cet audit (verified) :
- Anthropic, « Skill authoring best practices » —
  https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- Claude Code, « Skills » — https://code.claude.com/docs/en/skills

Lues par la recherche déléguée, non relues par l'auteur de l'audit (not verified) :
- Anthropic, « Effective context engineering for AI agents » (2025-09-29) —
  https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- Anthropic, « Best practices for Claude Code » —
  https://code.claude.com/docs/en/best-practices
- Cognition, « Don't Build Multi-Agents » (Walden Yan, 2025-06) —
  https://cognition.com/blog/dont-build-multi-agents
- Chroma, « Context Rot » (Hong, Troynikov, Huber, 2025-07-14) —
  https://www.trychroma.com/research/context-rot
- Lulla et al., « On the Impact of AGENTS.md Files on the Efficiency of AI
  Coding Agents » (2026, arXiv:2601.20404)
- Chatlatanagulchai et al., « Agent READMEs: An Empirical Study of Context
  Files for Agentic Coding » (2026, arXiv:2511.12884)

Citées d'après l'article ou un résumé tiers, non relues intégralement (not verified) :
- Anthropic : « Building effective agents » (2024) ; « Effective harnesses for
  long-running agents » (2025-11) ; « How we built our multi-agent research
  system » (2025-06)
- OpenAI : « A practical guide to building agents » (2025) ; spec AGENTS.md —
  https://agents.md/
- Liu et al., « Lost in the Middle » (TACL 2024, arXiv:2307.03172)
- Huang et al., « Large Language Models Cannot Self-Correct Reasoning Yet »
  (ICLR 2024, arXiv:2310.01798)
- Panickssery et al., « LLM Evaluators Recognize and Favor Their Own
  Generations » (NeurIPS 2024)
- Jaroslawicz et al., « How Many Instructions Can LLMs Follow at Once? »
  (IFScale, arXiv:2507.11538)
- SWE-agent (arXiv:2405.15793), Agentless (arXiv:2407.01489), Reflexion
  (arXiv:2303.11366)
- Kwa et al. (METR), « Measuring AI Ability to Complete Long Tasks » (2025, arXiv:2503.14499) ; Ord, « Is there a Half-Life for the Success Rates of AI Agents? » (2025, arXiv:2505.05115)

### Confrontation

| Pratique | Statut | Preuve | Recommandation |
| --- | --- | --- | --- |
| Contexte permanent court et mesuré (context engineering ; best practices Claude Code ; Lulla 2026 ; Chatlatanagulchai 2026) | aligné | `workflow/runtime/context-budget.json` plafonne `always-on` (environ 3 k tokens) et chaque chaîne ; `scripts/workflow-context-budget` tourne en core | garder ; `token-bench` ajoute la vue par route et la mesure observée |
| Divulgation progressive, chargement juste-à-temps (Agent Skills ; context engineering) | aligné | entrées `conditional` avec déclencheur nommé | **rejeté** : différer `workflow/templates/review-*.md` (proposé par la recherche déléguée). L'étape 13 est sur le chemin par défaut de chaque plan-implement : ce serait déplacer une lecture, pas l'économiser, ce que la règle T4 « lu sur le chemin par défaut » interdit |
| La conformité baisse quand le nombre d'instructions simultanées augmente (IFScale) | partiel | règles réparties entre `workflow/agent-quick-card.md`, `workflow/spec.md` § Rules et `workflow/skills/implementation-loop.md` (18 étapes, plus 12b, 12c et 13b) ; `workflow/runtime/rule-registry.tsv` ne recense que 12 règles | suite : recenser les règles par route, puis dédupliquer |
| Vérification par check objectif ; hooks déterministes plutôt que prose (best practices Claude Code) | aligné, avec une faille corrigée | `claude/hooks/*.mjs` ; `scripts/verify-agentic-infra` rendait un vert partiel (§1) | fait en T9 : test hermétique du runner |
| Ne pas s'en remettre à la prose pour une règle transverse | écart | la machine de review T/D/F n'est contrôlée par aucun script : « No script enforces this machine » (`workflow/skills/review-rounds.md:50`), alors que `workflow/skills/implementation-loop.md:41-43` exige qu'un nouvel invariant transverse soit livré avec un check mécanique, et que la troisième occurrence d'un même finding de review en devienne un. La machine T/D/F est antérieure à cette règle, mais c'est l'invariant de contrôle le plus complexe du dépôt | suite prioritaire : valider les transitions T/D/F sur le ledger (`review_completed`, `adversary_completed`) |
| Indépendance du juge face au biais d'auto-préférence (Panickssery 2024) | aligné | `workflow/skills/adversary.md` : cross-family en high-risk, double échantillon en standard, passe unique interdite | garder |
| … mais l'exception « Daily Pi » fait tourner Spec dans le parent | partiel | `workflow/skills/review.md:50-52` | nommer le risque accepté, ou réserver l'exception aux petits diffs |
| L'auto-correction sans retour externe est peu fiable (Huang 2024) | partiel | tier small : « One self-review of the cumulative diff replaces hunters and adversary passes » (`workflow/skills/implementation-loop.md:21-22`) | acceptable, puisque small exclut tout changement de comportement ; nommer le risque |
| Un seul fil d'écriture plutôt qu'un fan-out multi-agents fragile (Cognition 2025) | aligné | `workflow/agent-quick-card.md` § One-writer ; conseil multi-modèles retiré (`workflow/spec.md:26`, ADR-0013) | garder |
| Sous-agents qui rendent des synthèses bornées (Anthropic multi-agent research) | aligné | `workflow/templates/review-*-hunter.md`, tables deciding-code | garder |
| Le texte cohérent mais hors sujet coûte avant la limite de contexte (Chroma 2025) | partiel | `ship` : environ 23 k tokens estimés, 33,7 k dans le pire cas (§3) | mesurer une session `ship` réelle avant toute coupe (note du 2026-09-24, §5) |
| Boucles bornées avec métrique figée (METR, Kwa 2025 ; Ord 2025 ; harness longue durée Anthropic) | aligné | `workflow/skills/long-loop.md` | garder |
| Poids du process proportionnel au risque (Agentless ; Building effective agents) | aligné | tiers `small/standard/high-risk` (`workflow/skills/implementation-loop.md:14-31`) | garder |
| État persistant et reprenable (harness longue durée Anthropic) | aligné | `PLAN.md`, archives `docs/plan/`, ledger `.workflow/<slug>/events.jsonl`, événement `handoff` | garder |
| Évaluer le harness sur le résultat, pas seulement sur le coût | partiel | `workflow/templates/escaped-defect.md` et `workflow/self-improvement/review-metrics.md` ne sont pas rapprochés du tier | suite : taux de défauts échappés par tier |

## 6. Suites priorisées

| # | Suite | Effort | Impact | Motif |
| --- | --- | --- | --- | --- |
| 1 | Validateur T/D/F sur le ledger | faible | fort | applique la règle du check mécanique (`implementation-loop.md:41-43`) à la machine de review |
| 2 | Corrections de skills listées au §4 | faible | moyen | `project-hunt`, `design`, tables des matières, pointeur auto-référent |
| 3 | Recenser les règles par route, puis dédupliquer | moyen | moyen | IFScale |
| 4 | Rapprocher les défauts échappés du tier | moyen | moyen | mesurer ce que le poids du process rapporte |
| 5 | Nommer les risques acceptés | trivial | faible | Spec dans le parent (Daily Pi) ; self-review du tier small |
| 6 | Décider du sort de `workflow-ship-metrics` / `workflow-ledger-census` | trivial | faible | nommer les outils dans le contrat, ou les retirer |

## Risques restants

- `--live` dépend du format markdown de `/context`, commande interne de Claude
  Code : le parseur échoue explicitement si le tableau manque, mais un changement
  de format arrêterait la mesure (not verified au-delà de Claude Code 2.1.283).
- La baseline inclut le diff T4 non commité ; elle est à réécrire après commit ou
  abandon de T4.
- L'effort et l'impact du §6 sont des estimations (assumption).
- CI Ubuntu non exécutée ici : le smoke a tourné sous Node 20.20.2 et 24.19.0 en
  local, pas sur le runner GitHub (not verified).
