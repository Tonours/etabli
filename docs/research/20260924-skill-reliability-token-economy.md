# Fiabilité des skills et économie de tokens : état de l'art et écarts d'Etabli

Date de recherche : 2026-09-24. Checkout `7d53652`. Phase exploratoire : aucun
fichier de workflow n'a été modifié.

Ce document est une **recherche, pas un plan d'implémentation**. Chaque
recommandation doit passer par un `PLAN.md` READY avant d'être appliquée.

Statuts utilisés :

- `verified` : constat local vérifié par relecture du code ou exécution ;
- `confirmed` : la source externe l'énonce ;
- `inferred` : raisonnement à partir des sources et du dépôt ;
- `approximate` : estimation à partir de tailles de fichiers ;
- `not verified` : aucune mesure. C'est le cas de **tous** les gains de tokens et
  de qualité annoncés pour Etabli.

## Méthode

Dix runs au total, avec un brief commun. La règle : ne citer que les sources
ouvertes pendant le run, et étiqueter chaque affirmation.

| Id | Runner | Angle |
| --- | --- | --- |
| A | Claude subagent | Standards et cycle de vie des skills (Agent Skills, AGENTS.md, Cursor, Copilot, Gemini, portabilité) |
| B | Claude subagent | Anti-dérive et anti-hallucination (évals, conflits d'instructions, références inventées, hooks) |
| C | Claude subagent | Context engineering et tokens (cache, chargement à la demande, sorties d'outils, compaction) |
| D | Claude subagent | Coût du routage, de l'orchestration et des boucles de review |
| E | Claude subagent | Comparatif des frameworks proches (spec-kit, superpowers, BMAD, Kiro, Agent OS, HumanLayer…) |
| C1 | Codex gpt-6-astra xhigh | Audit des tokens dans le dépôt, fichier par fichier |
| C2 | Codex gpt-6-astra xhigh, web | Mesurer qu'une coupe de tokens ne dégrade pas la qualité ; économie du cache |
| P1 | Pi glm-5.3 max | Audit de dérive du graphe de skills |
| P2 | Pi glm-5.3 max, web via Brave | Sélection et déclenchement des skills à grande échelle |
| C3 | Codex gpt-6-astra xhigh, web | **Relecture adversariale de la première version de ce document** (§10) |

Les rapports bruts sont dans `.workflow/skill-reliability-token-research/`
(local, non versionné).

Limites :

- WebFetch résume les pages. C3 a revérifié en direct 8 sources clés : toutes
  existent, deux étaient mal attribuées dans la v1, corrigées ici ;
- la page primaire « Harness engineering » d'OpenAI a renvoyé 403 ;
- aucun run A/B n'a été effectué.

## Conclusion

1. **Etabli est en avance sur ses pairs sur les gates mécaniques.** Le garde
   READY, le check-freeze, le validateur du ledger et le comparateur
   `skill-eval` sont appliqués par du code. Parmi les frameworks comparés, seuls
   Kiro et spec-kit ont des hooks bloquants ; les autres reposent sur la prose,
   et BMAD le dit explicitement (E, `confirmed`). Aucun framework ne publie de
   preuve contrôlée de son efficacité. Il ne faut rien simplifier qui affaiblisse
   ces gates. Deux recommandations de la v1 le faisaient ; elles ont été
   corrigées (§10).
2. **Le problème principal est la cohérence entre prose, adaptateurs et code,
   pas le volume de règles.** Plusieurs écarts sont réels : force-push, ledger
   `ci-fix`, gate READY contre spec, route modèle morte, adversaire Claude de
   même famille (§4). Les sources convergent : un modèle n'arbitre pas un conflit
   de façon fiable (Control Illusion), donc un conflit doit faire échouer la CI.
3. **Un contrôle mécanique existant échoue aujourd'hui sans que personne ne le
   voie.**
   - `scripts/pi-skill-load-check` plafonne le bloc de skills montré au modèle à
     **7 190 caractères**.
   - Sur cette machine, il mesure **19 947 caractères**, soit ~5k tokens à chaque
     session Pi.
   - Il signale aussi des skills pstack rendus alors qu'ils doivent être
     désactivés, et une divergence entre les deny-lists du repo et celles en
     service (`verified`, exécution locale).

   C'est le constat le plus directement actionnable de toute la recherche.
4. **Des références pointent vers des outils absents de l'environnement.**
   - 19 à 20 des 22 `scripts/*` cités par les contrats déployés dans un projet
     scaffoldé n'y existent pas ; le compte varie selon l'extraction. Une partie
     est explicitement réservée à etabli (`workflow/spec.md:80`), mais ce marquage
     n'est pas lisible par la machine.
   - `/ship` compte sur `unslop`, qui ne vient que du paquet Pi pstack, que le
     check ci-dessus exige désactivé.
5. **Côté tokens, les traces réelles changent les priorités (§11).**
   - Le coût est dominé par la **taille du contexte accumulé**. Une session
     Claude envoie en médiane 204k tokens par appel et ne compacte presque
     jamais : 4 compactions sur 403 sessions.
   - Les instructions Etabli ne pèsent qu'environ 1 % des tokens envoyés. Le
     listing de skills Claude en pèse environ 3 %.
   - L'invalidation du cache par le routeur Pi (T1) existe mais est
     négligeable : moins de 0,1 % des tokens Pi.
   - Les sorties de tests et de CI sont minoritaires.
6. **Couper du prompt peut coûter de la qualité, et les preuves sont mitigées.**
   Sur les fichiers de contexte générés, une étude trouve +20 à 23 % de coût sans
   gain significatif ; une autre trouve −16,6 % de tokens de sortie (C2,
   `confirmed`). La métrique est le **coût par tâche réussie**, sous protocole de
   non-infériorité (§7).

## 1. Fiabilité : ce que disent les sources

**Densité et priorité des instructions**

- IFScale : le meilleur modèle atteint 68 % à 500 instructions, sur un benchmark
  d'inclusion de mots-clés. Il y a un biais de primauté, et l'erreur dominante
  est l'omission. Ce n'est pas un seuil universel pour des règles de workflow
  (`confirmed`, revérifié par C3).
- AgentIF : les instructions agentiques font 1 723 mots et 11,9 contraintes en
  moyenne, et les modèles y sont « generally poor » (`confirmed`).
- OctoBench : il y a un écart systématique entre résoudre la tâche et respecter
  le scaffold (`confirmed`).
- Control Illusion : la séparation system/user n'établit pas une hiérarchie
  fiable (`confirmed`).
- Laban et al. : −39 % en multi-tour, et un modèle qui ne se rattrape pas après
  un mauvais virage. C'est un argument pour la review en contexte frais
  (`confirmed`).

**Prose contre environnement**

- Claude Code : un CLAUDE.md gonflé est ignoré ; ce qui doit arriver « with zero
  exceptions » relève d'un hook (`confirmed`).
- METR : « please do not cheat » n'aide pas (`confirmed`).
- ImpossibleBench, deux expériences distinctes :
  - l'option « abandonner comme impossible » fait passer la triche de GPT-5 de
    54 % à 9 % ;
  - l'accès en lecture seule aux tests empêche leur modification.

  (`confirmed`, attribution corrigée après C3.)

**Déclaration contre preuve**

- OverclaimBench : 409 des 774 revues incomplètes (52,8 %) déclarent une
  couverture complète (`confirmed`, revérifié par C3).
- Une affirmation « tests pass » n'est prouvée que si elle est reliée à **la
  bonne commande**, sur l'état final du code (`inferred`).

**Évals**

- Anthropic, *Demystifying evals* :
  - partir de 20 à 50 tâches issues d'échecs réels ;
  - une régression doit viser près de 100 % de réussite ;
  - utiliser pass^k pour la fiabilité ;
  - noter l'état final ;
  - un grader buggé fausse tout (CORE-Bench : 42 % → 95 %).

  (`confirmed`)
- OpenAI, *eval-skills* : des prédicats déterministes sur la trace
  `codex exec --json`, avec des contrôles négatifs (`confirmed`).

**Portabilité et cycle de vie**

- Le format Agent Skills est un standard ouvert, adopté par Claude Code, Codex,
  Cursor, Copilot, Gemini CLI, Pi et Microsoft Agent Framework (`confirmed`).
- Les adaptateurs sont générés depuis une source unique, avec un
  `generate --check` qui sort en 1 en cas de dérive (rulesync, `confirmed`).
- Les références doivent rester à un seul niveau de profondeur (`confirmed`).
- Invocation par l'utilisateur seul : `disable-model-invocation` (Claude Code,
  Cursor, VS Code, Pi) ou `allow_implicit_invocation: false` (Codex)
  (`confirmed`).

**Curation**

- SkillsBench : des skills curés font passer la réussite de 33,9 % à 50,5 % ;
  des skills focalisés battent les gros paquets (`confirmed`).
- Des skills générés par LLM sans vérification n'apportent pas de gain mesurable
  (SkillAxe, `confirmed`).
- SkillOps nomme la « dette technique de skill » (`confirmed`).

## 2. Tokens : ce que disent les sources

**Moins de contexte fonctionne mieux**

- Chroma a testé 18 modèles : tous se dégradent quand l'entrée s'allonge, même
  sur des tâches triviales (`confirmed`).
- Anthropic parle de « context rot » et d'« attention budget » (`confirmed`).

**Charger à la demande**

- Tool Search : −85 % de tokens de définitions d'outils. Les évaluations MCP
  internes passent de 49 % à 74 % (Opus 4) et de 79,5 % à 88,1 % (Opus 4.5).
  C'est une précision sur des évaluations MCP, pas uniquement de la sélection
  d'outil (`confirmed`, précisé par C3).
- La sélection se dégrade au-delà de 30 à 50 outils visibles (`confirmed`).
- Plafonds de listing : Codex, 2 % du contexte ou 8 000 caractères ; Claude
  Code, 1 % du contexte (`confirmed`).

**Cache**

- L'ordre du préfixe est tools → system → messages. Une écriture coûte 1,25× et
  une lecture 0,1× (Anthropic ; OpenAI GPT-5.6+) (`confirmed`).
- L'équipe Claude Code alerte sur le taux de cache. Elle injecte les mises à
  jour comme messages `<system-reminder>`, jamais en éditant le prompt système,
  et ne change pas de modèle en cours de session (`confirmed`).
- Manus : contexte en ajout seul, préfixe stable (`confirmed`).

**Sorties d'outils**

- Ce sont elles, plus que les instructions, qui inondent le contexte.
- Filtrer les sorties de tests par hook fait passer de « tens of thousands of
  tokens to hundreds » (Claude Code costs, `confirmed`).

**Réduire le prompt : preuves mitigées**

- Cursor rapporte −66 % de prompt système et −7 % de coût total. Mais ces −7 %
  résultent de **plusieurs** changements du harness, pas de la seule réduction
  du prompt (`confirmed`, causalité précisée par C3).
- Gloaguen et al. : les fichiers de contexte **générés** coûtent +20 à 23 % sans
  gain significatif ; les fichiers écrits à la main ont des résultats distincts
  (`confirmed`).
- LLMLingua-2 : LongBench passe de 44,0 à 42,4 pour un tiers des tokens
  (`confirmed`).

**Multi-agents et review**

- Multi-agents : ~15× les tokens d'un chat, et le code s'y prête mal
  (Anthropic, `confirmed`).
- Self-review : faible (Huang ; Olausson, `confirmed`).
- Biais entre juges de même famille : +3,4 à 8,4 points, mesuré sur du jugement
  de préférence, pas de la détection de bugs (`confirmed`).
- OpenCodeReview : selon ses auteurs, la frontière d'information (le diff seul)
  compte plus que l'identité du modèle (benchmark construit par eux).
- Claude Code Review : moins de 1 % des findings sont **marqués** incorrects par
  les utilisateurs. Ce n'est pas un taux de faux positifs mesuré indépendamment.
- Cursor Bugbot : passage de 8 passes votées à une passe agentique, résolution de
  52 % à plus de 70 % (chiffres éditeur).

**Boucles bornées**

- Self-Refine s'arrête à 4 itérations ; OpenHands signale un va-et-vient après 6
  cycles (`confirmed`).
- superpowers : 5 tours de correction au maximum, re-review du diff de
  correction, **puis une dernière revue du diff complet** (`confirmed`).

**Routage**

- Une table « un modèle par type de tâche » capture 21 des 29 questions
  routables (Lee 2026, sans holdout, `confirmed`).
- Pas besoin d'un routeur plus intelligent (`inferred`, extrapolation).

## 3. Ce qu'Etabli fait déjà bien (à préserver)

- **Gates mécaniques.** Le garde READY
  (`scripts/lib/plan-check-freeze.mjs:1579`) est partagé Pi/Claude. S'y ajoutent
  le check-freeze, le no-progress guard et l'empreinte d'archive
  (`scripts/plan-cleanup`).
- **Budget de contexte.** Plafonds par route ; `--ratchet` ne fait que les
  baisser, et une hausse exige un diff revu et justifié
  (`scripts/workflow-context-budget:10`). 7/7 surfaces ok.
- **Contrôle dédié du bloc de skills Pi** (`scripts/pi-skill-load-check`). Il
  existe, mais il échoue aujourd'hui (§4, F16).
- **Reviewers Pi isolés.** Ils tournent sans fichiers de contexte, skills ni
  extensions (`workflow/skills/review.md:36-47`).
- **Un seul écrivain, des reviewers en lecture seule.**
- **Comparateur `skill-eval`.** Il rejette les régressions tâche par tâche
  (`scripts/lib/skill-eval.mjs:246`).
- **Réduction des sorties côté Pi.** L'extension RTK (`pi/extensions/rtk.ts`) et
  la troncature native de l'outil bash de Pi.
- **Routeur déterministe plus Jev qui s'abstient.**

## 4. Écarts de fiabilité

La colonne « C3 » donne le verdict de la relecture Codex : **C** correct,
**N** nuancé ou atténué ici, **R** reformulé après une erreur de la v1.

| # | Constat | Preuve | C3 |
| --- | --- | --- | --- |
| F1 | **Ambiguïté, pas contradiction démontrée.** Le tier `small` tourne hors du gate plan, alors que le profil `autonomous-completed` ne s'applique qu'aux runs `plan-implement`. Mais l'étape 5 de la séquence plan mentionne encore « optional for small », ce qui laisse croire qu'un run plan-implement peut être `small` | `implementation-loop.md:4-10,18-23,65-66` ; `scripts/workflow-event:354,685` (`verified`) | R |
| F2 | La passe qualité (12c) n'a aucun événement dans le ledger | `implementation-loop.md:113-119` ; liste d'événements de `scripts/workflow-event` (`verified`) | C |
| F3 | 19 à 20 des 22 `scripts/*` cités dans un scaffold n'y existent pas. Une partie est réservée à etabli en prose seulement | `scripts/deploy-workflow:20-60` ; `workflow/spec.md:80` (`verified`) | N |
| F4 | Les procédures de review diffèrent : `pi/skills/review` embarque la procédure des hunters, la commande Claude non. Pour l'adversaire, Pi exclut aussi la famille de l'auteur (`pi/skills/adversary/SKILL.md:26`) ; la divergence porte sur la formulation, pas sur l'exigence | `pi/skills/review/SKILL.md:15-31` vs `claude/scopes/shared/commands/review.md` (`verified`) | N |
| F5 | L'agent adversaire Claude épingle `model: fable`, `effort: low`, et se dit « cross-model » ; rien n'y garantit une famille distincte de l'auteur | `claude/scopes/shared/agents/adversary.md:3-5` ; `workflow/runtime/adversary-model-policy.json:5` (`verified`) | C |
| F6 | « Never force-push » contre le `--force-with-lease` prescrit par ci-fix, que ship appelle | `workflow/skills/ship.md:118` ; `workflow/skills/ci-fix.md:64-66` (`verified`) | C |
| F7 | Le spec exige le ledger pour `ci-fix`, sans aucune procédure correspondante | `workflow/spec.md:88` ; `workflow/skills/ci-fix.md` (`verified` par grep) | C |
| F8 | Le routeur suggère `pi -p openai-codex/*`, retiré de la politique | `workflow/runtime/workflow-router-core.mjs:1060` (`verified`) | C |
| F9 | Verdicts de l'adversaire plan : vocabulaires différents, mais le validateur accepte explicitement les deux. Aucun échec démontré ; c'est un point de clarté | `workflow/skills/adversary.md:34` ; `scripts/workflow-event:292` | N |
| F10 | Le gate READY est à la fois plus souple que le spec (« named files » jamais vérifié) et plus strict (champs conditionnels exigés sans condition) | `workflow/spec.md:130-144` vs `scripts/lib/plan-check-freeze.mjs:1583-1640` (`verified`) | C |
| F11 | `ship`, `plan-implement`, `implement`, `ci-fix` et `linear-ticket-create` restent exposés au modèle, contre `skill-design.md:15`. C'est une question d'exposition, pas de frontière d'autorisation d'écriture | frontmatters sans `disable-model-invocation` (`verified`) | C |
| F12 | `unslop` n'existe que dans le paquet Pi `@zenspc/pi-pstack`, que `pi-skill-load-check` exige désactivé. `no-ai-slop` est déployé côté Codex, pas côté Pi. `write-direct` n'existe que côté Claude. Le style de PR décrit par `/ship` n'est donc complet sur aucun harness | `workflow/skills/ship.md:58-63` ; `~/.pi/agent/npm/node_modules/@zenspc/pi-pstack/skills/unslop` ; `~/.codex/skills/no-ai-slop` (`verified`) | R |
| F13 | « `spec.md` wins on conflict » sert de règle d'arbitrage en prose | `implementation-loop.md:34-35` | C |
| F14 | Aucun hook Stop ne contrôle les affirmations de complétion (les hooks existants font métriques et signal ADR) | `claude/settings.workflow-hooks.json:37` | N |
| F15 | Spec `verify` contre routeur `verify-workflow` : nom d'interface contre identifiant interne, sans bug démontré | `workflow/spec.md:170` ; `workflow-router-core.mjs:821-824` | N |
| F16 | **`pi-skill-load-check` échoue** : bloc de 19 947 caractères pour un plafond de 7 190 ; skills pstack rendus alors que pstack doit être désactivé ; deny-lists du repo et en service divergentes. Personne ne s'en aperçoit | exécution locale de `scripts/pi-skill-load-check` (`verified`) | nouveau |

## 5. Postes de tokens

Les appartenances au manifeste de budget sont un **inventaire statique** et ne
prouvent pas qu'un fichier est effectivement lu au démarrage (C3).

| # | Poste | Preuve | Ordre de grandeur |
| --- | --- | --- | --- |
| T1 | À chaque prompt utilisateur (`before_agent_start`, hors prompts exclus), le routeur ajoute au prompt système un contrat qui dépend de la route : route, commande, artefact, condition d'arrêt, preuves. Pi place ce prompt en tête de requête, comme bloc système cachable. Quand la route change, le cache du système et de l'historique qui suit peut être invalidé | `pi/extensions/workflow-router.ts:29-39,46-62` ; sources Pi `agent-session.js:1034`, `anthropic-messages.js:790` (C3, `verified`) | Mécanisme `verified` ; fréquence et coût `not verified` |
| T2 | `implement` et `plan-implement` déclarent au budget le rubric, `review.md`, les templates de hunters (passés aux hunters par chemin), `answer-quality.md` et `events.md` | `workflow/runtime/context-budget.json` (C, C1) | ~13 à 18k caractères potentiellement différables (`approximate`) |
| T3 | `plan-loop` exige de lire `spec.md` et `PLAN_TEMPLATE_FULL.md`, que le manifeste ne compte pas | `workflow/skills/plan-loop.md:14-16` vs `context-budget.json:15-21` (`verified`) | 5 539 + 16 956 = 22 495 caractères (`verified`) |
| T4 | `ship` n'a pas de surface de budget | C1, confirmé par C3 | ~98 300 caractères pour la chaîne principale (`approximate`) |
| T5 | Chaque correction acceptée rejoue hunters et adversaires sur le patch complet, sans plafond de tours | `implementation-loop.md:140-142` | Une re-review ≈ 3k tokens d'instructions + 4 copies du patch (`approximate`, corrigé : pas 8) |
| T6 | Sorties d'outils. Pi a RTK et une troncature native, mais rien n'est prévu côté Claude pour les tests et la CI, et la couverture côté Pi n'est pas mesurée | `pi/extensions/rtk.ts:17` ; `workflow/skills/ship.md:92` | `not verified` |
| T7 | Les hunters et l'adversaire Claude, agents personnalisés, héritent probablement de CLAUDE.md et AGENTS.md | doc Claude Code (C) | Plausible ; non mesuré sur ces agents |
| T8 | Dans les prompts des hunters Pi, le template d'axe précède le patch, ce qui empêche un préfixe commun. Sur Pi, Spec tourne souvent dans le parent (`review.md:48`) | `scripts/pi-review-hunter:98` | `not verified` |
| T9 | Bloc de skills montré au modèle par Pi : **19 947 caractères en service**, contre 7 190 autorisés (F16). Pour les seuls skills du repo : 7 864 caractères de noms et descriptions, 15 525 en rendu XML complet (C3, via le formateur natif de Pi) | `scripts/pi-skill-load-check` (`verified`) | ~5k tokens par session en service (`approximate`) |
| T10 | Règles répétées : READY dans 12 fichiers des surfaces budgétées, check-freeze dans 4 | C3 | Surtout un risque de contradiction |
| T11 | Run `plan-implement` illustratif : ~25 à 32k tokens d'instructions. Avec des patchs de 12k caractères, des plans de 4k et deux adversaires diff, on atteint ~58k tokens, avant code et sorties | C1 (hypothèses explicites) | Illustration, pas une mesure |

## 6. Recommandations priorisées

Ordre révisé après C3 : **corriger, puis mesurer, puis optimiser**. Aucune
recommandation ne doit retirer une passe de contrôle existante sans en garder un
équivalent explicite.

### P0 : corrections de cohérence (ne retirent aucun contrôle)

1. **Remettre `pi-skill-load-check` au vert** et le brancher dans le groupe de
   vérification exécuté régulièrement : réappliquer le deploy, désactiver
   pstack, corriger le filtre `radius-api`. Tokens : économise ~3k tokens par
   session Pi une fois le plafond respecté (`approximate`). Effort : S. Couvre
   F16, T9.
2. **Lever l'ambiguïté du tier.**
   - Écrire explicitement que `small` ne s'applique jamais sur une route à plan,
     et retirer « optional for small » des étapes de la séquence plan.
   - Ne **pas** rendre le validateur dépendant d'un tier déclaré.
   - Ajouter séparément un événement `quality_completed`.

   Effort : S. Couvre F1, F2.
3. **Corriger l'adversaire Claude** : le reclasser comme échantillon de même
   famille, ou le router vers une famille non Anthropic. Faire consigner la
   famille effective dans le ledger. Effort : S. Couvre F5.
4. **Trancher les contradictions ponctuelles.**
   - Force-push pendant la phase CI de `/ship` (F6).
   - Ledger de `ci-fix` (F7).
   - Remplacer la route morte par une lecture de la politique (F8).
   - Chaîne de style de PR réellement disponible par harness (F12).

   Effort : S.
5. **Borner la boucle review↔fix sans l'affaiblir.**
   - Au plus 2 tours complets, puis re-review du seul diff de correction.
   - Garder **toujours une dernière revue du diff complet**, comme superpowers.
   - Au plafond, un arrêt `blocked` explicite avec décision journalisée, jamais
     une validation allégée.
   - Pour `/ship`, déplacer les étapes 5 et 6 avant la review.

   Tokens : économise. Risque : **moyen**. Effort : M. Couvre T5.
6. **Rendre invocables par l'utilisateur seul** les skills à effets de bord de
   F11. Prérequis : vérifier que le routeur et `/skill:name` continuent de
   fonctionner. Effort : S. Couvre F11.

### P1 : mesurer avant d'optimiser

7. **Mesure du bloc de skills en service** (c'est la sortie de
   `pi-skill-load-check`) et intégration au rapport de
   `workflow-context-budget`.
8. **Trace des lectures réelles par route**, pour distinguer l'inventaire
   déclaré des lectures effectives (T2).
9. **Comptabilité du cache** par session (`cache_read`, `cache_creation`), avec
   une session mixte de routes pour chiffrer T1.
10. **Rendement par passe** (findings levés, acceptés, high) et tokens par tâche
    réussie. C'est le prérequis pour retirer une passe sur données.

### P1 : anti-dérive mécanique

11. **Linter de références par cible de déploiement**, avec un marqueur
    `etabli-only` lisible par la machine. Couvre F3, F12.
12. **Adaptateurs générés depuis un manifeste**, avec `--check` en CI. Couvre
    F4.
13. **Registre de règles** `rule_id → fichier canonique → mécanisme → test`,
    avec fixtures positives et négatives. Un conflit fait échouer la CI. Couvre
    F10, F13 ; F9 et F15 en simple clarification.
14. **Stop hook de preuve**, en mode shadow d'abord. Il relie chaque affirmation
    (« tests pass », « verified », « CI green ») à **la commande
    correspondante** sur l'état final du code, et au résultat terminal pour la
    CI. Couvre F14.

### P2 : optimisations de tokens, après P1 et sous le protocole du §7

15. **Contrat de route injecté comme message** plutôt que dans le prompt
    système, si la mesure 9 montre un coût. Risque : moyen, car le contrat pèse
    peut-être moins ; à tester avec les oracles de route (T1).
16. **Différer le matériel de review** jusqu'à la phase de review, si la mesure
    8 confirme qu'il est lu au démarrage (T2).
17. **Aligner le budget sur les lectures exigées** : lecture conditionnelle de
    `spec.md` et du template complet dans `plan-loop`, surface `ship` (T3, T4).
18. **Compléter la réduction des sorties** là où RTK et la troncature native ne
    couvrent pas (inventaire d'abord ; T6).
19. **Patch en tête des prompts des hunters** (T8).
20. **Descriptions « quoi + quand + pas pour »**, validées par une éval de
    déclenchement (20 requêtes, split 60/40, 3 runs) (T9).

## 7. Protocole avant tout ratchet (C2, complété après C3)

1. **Figer :**
   - le commit et les empreintes des prompts et adaptateurs ;
   - le modèle, l'effort et l'échantillonnage ;
   - les ressources, les timeouts, les retries et les graders.

   Le bruit d'infrastructure seul peut faire bouger Terminal-Bench de 6 points
   (`confirmed`).
2. **Screening : 12 tâches × 3 runs × 2 variantes = 72 runs complets**, en
   ordre randomisé. Échec immédiat sur écriture non autorisée, fausse complétion
   ou exigence perdue.
3. **Marge de non-infériorité de 2 points**, avec zéro régression critique. Elle
   **s'ajoute** au rejet tâche par tâche de `skill-eval`, elle ne le remplace
   pas. Sinon le verdict est `inconclusive`, et le plafond ne bouge pas.
4. **Confirmation.** Avec zéro inversion nuisible sur 149 paires indépendantes,
   la borne supérieure est à 1,99 % ; il faut 298 runs. À 60 paires, la borne
   n'est que de 4,87 %.
5. **Gain économique :** au moins −10 % de tokens par tâche réussie. **Exception
   :** un changement qui vise le cache (T1, T8) se juge en dollars par tâche
   réussie, à plafond de tokens inchangé.
6. **Coût indicatif :** 37 $ à 0,10 $ par run, 370 $ à 1 $ par run. À
   recalibrer.

## 8. Tensions à trancher

- **Contrat de route en message** : gain de cache contre autorité du contrat.
- **Règles chargées selon les chemins touchés** (Kiro, Cline, OpenHands) contre
  ADR-0014. Cela demande une décision de niveau ADR.
- **Aplatir la chaîne d'instructions à un seul saut** contre la source unique :
  compatible seulement via la génération des adaptateurs.
- **Descriptions plus « poussées »** : meilleur déclenchement, mais risque de
  sur-déclenchement.
- **Fusion adversaire + Logic sur le tier standard** : D la recommande ; E et C3
  appellent à la prudence. À tester, pas à appliquer.

## 9. Pistes non vérifiées

- Coût réel de T1 : il faut une session mesurée.
- Un agent Claude Code personnalisé peut-il éviter de charger CLAUDE.md ? (T7)
- Codex lit-il encore `~/.codex/skills` ?
- `disable-model-invocation` côté Pi bloque-t-il le chargement par le routeur ?
- Le chiffre « 150-200 instructions » attribué à HumanLayer n'a pas de source
  primaire.
- Aucun éditeur ne publie de coût par finding utile.

## 10. Relecture adversariale (C3)

Codex gpt-6-astra (famille OpenAI, distincte de l'auteur) a relu la v1 et rendu
`Verdict: BLOCK` pour un usage comme plan d'implémentation. Voici ses constats et
ce qui a été corrigé ici.

| Sévérité | Constat C3 | Action |
| --- | --- | --- |
| HIGH | La v1 bornait la review en supprimant la dernière revue du diff complet, que conserve la source (superpowers), et sous-estimait le risque | Corrigé (reco 5 : passe complète finale obligatoire, risque moyen) |
| HIGH | F1 n'était pas une contradiction démontrée, et rendre le validateur dépendant du tier pouvait contourner les passes obligatoires | Corrigé (F1 reformulé en ambiguïté ; reco 2 sans exemption par tier) |
| MEDIUM | T9 confondait les objets mesurés et ignorait `pi-skill-load-check` | Corrigé. L'exécution du check a révélé F16 |
| MEDIUM | T5 comptait 8 copies du patch au lieu de 4 ; T11 présenté comme un run standard | Corrigé |
| MEDIUM | F3 19/22 non reproduit (20/22 chez C3) ; F12 faux pour `no-ai-slop` | Corrigé (fourchette 19-20 ; F12 réécrit après vérification de l'origine de `unslop`) |
| MEDIUM | T6 ignorait RTK et la troncature native de Pi | Corrigé |
| MEDIUM | Causalité Cursor et attribution ImpossibleBench | Corrigé |
| MEDIUM | Protocole sans exception pour le cache, ni articulation avec `skill-eval`, et un Stop hook trop lâche | Corrigé (§7 et reco 14) |
| LOW | F9 et F15 sont des différences de représentation ; « plafonds qui ne peuvent que baisser » était faux | Corrigé |
| — | Ordre P0/P1/P2 : la mesure doit précéder les optimisations | Corrigé (P1 mesure, P2 optimisation) |

C3 a confirmé correctes F2, F5, F6, F7, F8, F10, F11, F13, T3 et T4, et le
mécanisme de T1 dans le code de Pi. Les 8 sources externes revérifiées en direct
existent toutes.

## 11. Mesures sur les traces réelles

Source : stores Claude, Pi et Codex de `macbook-work`, sur les 90 derniers jours,
plus les ledgers `.workflow/*/events.jsonl` sous `~/work`.

L'extracteur tourne sur la machine distante via `ssh … node -` : rien n'y est
écrit, et seuls des agrégats reviennent (compteurs, sommes, percentiles, noms
de contrats publics). Aucun contenu de conversation ni nom de projet n'est
extrait.

Scripts et agrégats bruts : `.workflow/skill-reliability-token-research/trace-metrics/`.
Toutes les valeurs ci-dessous sont `verified` par extraction, avec les limites
indiquées.

**Volume**

| | Sessions | Appels modèle | Tokens de prompt par appel (p50 / p90) |
| --- | --- | --- | --- |
| Claude, fil principal | 403 (217 projets) | 27 549 | 203 645 / 584 912 |
| Claude, subagents | 628 | 7 997 | 67 699 / 108 658 |
| Pi | 173 | 7 433 | 77 020 / 193 076 |
| Codex | 14 | 156 | 45 254 / 80 307 |

**Cache**

- Claude, fil principal : **98,6 %** de hit rate.
  - 41 reconstructions complètes du cache en cours de session (écart de moins
    de 5 min), 111 après une pause.
  - Subagents : 92,8 %.
- Pi (zai) : 96,8 % ; Codex : 91 %.
- **Test de T1 sur Pi.** On regarde le premier appel après un prompt, quand
  l'écart est inférieur à 5 min et le prompt dépasse 8k tokens :

  | Situation | Appels | Part lue en cache | Appels avec moins de 50 % en cache |
  | --- | --- | --- | --- |
  | Route inchangée | 130 | 89,2 % | 7,7 % |
  | Route changée | 67 | 80,0 % | 20,9 % |
  | Après changement de modèle ou d'effort | 7 | 17,5 % | 86 % |

  Le mécanisme est confirmé. Mais l'excès de tokens non cachés est estimé à
  ~0,5 M sur 690 M tokens Pi, soit **~0,07 %** (`approximate`). **T1 est donc
  dépriorisé.**

**Où vont les tokens**

- Le contexte grossit sans compaction : 22 appels par session en médiane, 161
  au p90, jusqu'à 1 168.
- Chaque appel rejoue le contexte accumulé, qui fait ~276k tokens en moyenne côté
  Claude.
- Le listing de skills Claude est présent dans **403 sessions sur 403**. Il fait
  ~30 000 caractères par session, et le p90 bute sur ~30 000, ce qui suggère un
  plafond de troncature. Cela fait ~7,5k tokens résidents par appel, soit ~2,7 %
  des tokens de prompt Claude (`approximate`).
- Les instructions Etabli toujours chargées (~3,3k tokens) représentent ~1,2 %
  des tokens de prompt (`approximate`).
- Injections de hooks :
  - `SessionStart` : 3,5k à 10,6k caractères par session ;
  - un plugin tiers (`ponytail`) ajoute **5 495 caractères à chaque subagent**,
    sur plus de 600 subagents.
- Sorties d'outils Claude, par type :

  | Type | Volume |
  | --- | --- |
  | Lectures de fichiers via `cat`/`sed` | 12,5 M caractères |
  | `git diff`/`log` | 10,7 M |
  | Recherches | 9,2 M |
  | Outil `Read` | 17,3 M |
  | Tests | 1,3 M |
  | CI (`gh`) | 1,8 M |

  **Tests et CI sont minoritaires**, ce qui invalide la priorité donnée à T6.
- Codex :
  - listing de skills : 17,7k caractères en médiane, 22k max ;
  - instructions de base : 17,7k.

**Lectures réelles des contrats**

- Claude `plan-implement` (17 sessions) :
  - `implementation-loop.md` lu dans 14 ;
  - `spec.md` dans 11, alors que l'adaptateur dit de ne l'ouvrir qu'en cas de
    doute ;
  - `adversary.md` dans 4, `review.md` dans 4.
- Claude `ship` (20 sessions) : contrat `ship.md` lu dans 20 ;
  `implementation-loop.md` dans 13.
- **Pi `plan-implement` (11 sessions routées) : le corps du skill n'est jamais
  injecté, et `implementation-loop.md` n'apparaît dans aucun argument d'outil.**
  - Même constat pour Pi `implement` (6 sessions) et `linear-work` (22 sessions,
    2 lectures).
  - Le routeur décide la route, mais le contrat n'est pas chargé. Le modèle
    travaille avec le seul contrat JSON de route et la quick-card.
  - Réserve : la route est attribuée au niveau de la session.
- Rubric et templates de hunters : rarement lus par le parent. T2 est donc
  surtout un sur-comptage du budget, pas un coût réel.

**Gates et ledger**

- Sur `macbook-work`, `plan-ready-guard.mjs`, `ledger-auto-emit.mjs` et
  `outcome-metric-emit.mjs` sont installés dans `~/.claude/hooks/`, mais **non
  branchés dans `settings.json`**. Le gate READY n'est donc pas appliqué côté
  Claude sur la machine où tournent 37 sessions `ship` et `plan-implement`.
- 49 ledgers : 26 `completed`, 7 `blocked`, **16 jamais terminés**.
- Dérive du ledger :
  - 91 événements sur 927 (9,8 %, dans 9 runs) ont un type absent du
    validateur : `ship_complete`, `pushed`, `ci_green`, etc. ;
  - 99 événements n'ont pas de `schema_version` ;
  - **21 `review_completed` sur 47 ont un statut non canonique**, du texte libre ;
  - 11 d'entre eux servent à consigner la passe qualité, faute d'événement
    dédié (confirme F2).
  - Ces écritures contournent `scripts/workflow-event`.
- Rendement des adversaires, tel que déclaré dans le ledger :

  | Mode | Passes | Findings acceptés | Rejetés | Acceptés par passe |
  | --- | --- | --- | --- | --- |
  | Plan | 37 | 152 | 42 | 4,1 |
  | Diff | 31 | 88 | 62 | 2,8 |

  Les passes sont productives, mais l'acceptation est jugée par l'implémenteur.
- L'agent `adversary` Claude (`model: fable`, cf. F5) a été invoqué **120 fois**
  sur la période.

**Ce que ces mesures changent aux recommandations**

1. **Nouveau P0 : brancher les hooks de garde sur les machines de travail**
   (redeploy `claude/settings.workflow-hooks.json`) et vérifier leur présence
   dans un check. C'est une vraie lacune de fiabilité.
2. **Nouveau P0 : faire charger le contrat quand le routeur Pi choisit une
   route.** Soit injecter le corps du skill, soit un pointeur que le modèle doit
   suivre, vérifié par le ledger.
3. **Nouveau P0 : écritures du ledger uniquement via `scripts/workflow-event`**
   (événements et statuts canoniques), et nettoyage des 16 runs ouverts.
4. **Le levier tokens n°1 est l'hygiène de session**, pas la chasse aux
   instructions : compaction ou `/clear` entre tâches, et délégation des
   lectures larges (`cat`, `git diff`) à des subagents qui renvoient un résumé.
   Ensuite, le listing de skills Claude et Codex (~30k et ~18k caractères) et
   l'injection du plugin tiers dans chaque subagent.
5. **Dépriorisés** : T1 (routeur Pi, moins de 0,1 %), T6 (tests et CI), T2
   (surtout un sur-comptage).

**Limites**

- Seulement 90 jours.
- Codex est peu utilisé sur cette machine (14 sessions).
- L'attribution de route est faite au niveau de la session.
- Les lectures sont détectées par le chemin dans les arguments des outils : un
  contenu injecté autrement, par exemple une commande Claude développée, n'est
  pas une lecture.
- Le hit rate zai ne rapporte pas les écritures de cache.
- Les findings « acceptés » sont auto-déclarés.

## 12. Feuille de route

Décidée avec l'utilisateur le 2026-09-24 : **un `PLAN.md` par tranche**, exécutés dans l'ordre. Chaque tranche passe par plan-loop puis implement ; il n'y a jamais plus d'un `PLAN.md` actif.

| Ordre | Tranche | Constats couverts | État |
| --- | --- | --- | --- |
| 1 | Hygiène de session : compaction Pi, statusline Claude en tokens, instructions de compaction | §11 reco 4 | implémentée (`docs/plan/20260924-session-hygiene.md`) |
| 2 | Gardes réellement actives : hooks branchés sur les machines de travail, et `pi-skill-load-check` au vert | F16, §11 (hooks non branchés), déploiement Claude local absent | implémentée (`docs/plan/20260924-guards-active.md`) |
| 3 | Pi charge le contrat de la route choisie ; ledger écrit uniquement via `scripts/workflow-event`, et nettoyage des runs ouverts | §11 (contrat non lu, dérive du ledger) | implémentée (`docs/plan/20260924-route-contract-ledger.md`) |
| 4 | Cohérence des contrats | F1, F2, F5, F6, F7, F8, F9, F10, F15 ; indépendance de l'adversaire sur le plan ; `Review Changes` ; `implement` contre étape 1 | implémentée (`docs/plan/20260924-contract-coherence.md`) |
| 5 | Boucle de review bornée (passe complète finale obligatoire) et ordre de `/ship` | T5 ; ship : étapes 5-6 après la review, archive avant CI, commits CI, événements ship, métriques, chaîne de style (F12) | implémentée (`docs/plan/20260924-bounded-review-ship.md`) |
| 6 | Anti-dérive mécanique : linter de références par cible, adaptateurs générés avec `--check`, registre de règles, parité routeur↔spec, stop hook de preuve | F3, F4, F13, F14 | implémentée (`docs/plan/20260925-mechanical-anti-drift.md`) |
| 7 | Hygiène des skills : invocation par l'utilisateur seul, descriptions « quoi + quand + pas pour », éval de déclenchement, listings Claude et Codex, injection du plugin tiers dans chaque subagent | F11, T9, §11 | à planifier |
| 8 | Tokens sous protocole : lectures de `plan-loop`, budget `ship`, phase review, ordre des prompts hunters, dédoublonnage, télémétrie, corpus de régression | T2, T3, T4, T8, T10, §7 | à planifier |

## Sources principales

Sources ouvertes pendant le run par l'agent indiqué ; celles marquées ✓C3 ont
été revérifiées en direct par la relecture. Les listes complètes sont dans les
rapports bruts.

**Skills et instructions**

- Anthropic, « Skill authoring best practices », non daté —
  https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices (A, C, P2).
- Agent Skills, « Specification », non daté — https://agentskills.io/specification (A).
- Anthropic, « Equipping agents for the real world with Agent Skills », 2025-10-16 —
  https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills (A, C, P2).
- Anthropic, skill-creator `SKILL.md`, non daté —
  https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md (A, P2).
- Claude Code Docs, « Skills », non daté — https://code.claude.com/docs/en/skills (A, P2).
- OpenAI, Codex « Build skills », non daté — https://learn.chatgpt.com/docs/build-skills (A, E).
- rulesync README, non daté — https://github.com/dyoshikawa/rulesync (A).
- Li et al., « SkillsBench », 2026-02-13 — https://arxiv.org/abs/2602.12670 (A).
- Gautam et al., « SkillAxe », 2026-06-09 — arXiv:2606.10546 (P2).
- Pu et al., « SkillOps », 2026-05-13 — arXiv:2605.13716 (P2).
- Anthropic, « Introducing advanced tool use », 2025-11-24 —
  https://www.anthropic.com/engineering/advanced-tool-use (C, P2) ✓C3.

**Fiabilité et évals**

- Jaroslawicz et al., « How Many Instructions Can LLMs Follow at Once? »,
  2025-07-15 — https://arxiv.org/abs/2507.11538 (B, C, C2, E) ✓C3.
- Qi et al., « AgentIF », 2025 — https://arxiv.org/abs/2505.16944 (B).
- Ding et al., « OctoBench », 2026-01-15 — https://arxiv.org/abs/2601.10343 (B).
- Geng et al., « Control Illusion », 2025 — https://arxiv.org/abs/2502.15851 (B).
- Smyth et al., « Quantifying Overclaiming Propensity », 2026-09-22 —
  https://arxiv.org/html/2609.20812 (B) ✓C3.
- Zhong et al., « ImpossibleBench », 2025 — https://arxiv.org/html/2510.20270v1 (B) ✓C3.
- METR, « Recent Frontier Models Are Reward Hacking », 2025-06-05 —
  https://metr.org/blog/2025-06-05-recent-reward-hacking/ (B).
- Anthropic, « Demystifying evals for AI agents », 2026-01-09 —
  https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents (B, C2).
- OpenAI, « Testing Agent Skills Systematically with Evals », non daté —
  https://developers.openai.com/blog/eval-skills (B).
- GitHub spec-kit `analyze.md`, non daté —
  https://github.com/github/spec-kit/blob/main/templates/commands/analyze.md (B, E).
- Claude Code Docs, « Automate actions with hooks », non daté —
  https://code.claude.com/docs/en/hooks-guide (B).
- Claude Code Docs, « Best practices », non daté — https://code.claude.com/docs/en/best-practices (B, C).

**Contexte, cache et coût**

- Anthropic, « Effective context engineering for AI agents », 2025-09-29 —
  https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents (C, D).
- Chroma, « Context Rot », 2025-07-14 — https://www.trychroma.com/research/context-rot (B, C, C2).
- Claude Code Docs, « How Claude Code uses prompt caching », non daté —
  https://code.claude.com/docs/en/prompt-caching (C, D).
- T. Shihipar, « Prompt caching is everything », 2026-04-30 —
  https://claude.dev/blog/lessons-from-building-claude-code-prompt-caching-is-everything/ (C, D).
- Manus, « Context Engineering for AI Agents », 2025-07-18 —
  https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus (C).
- Anthropic, « Prompt caching », non daté —
  https://platform.claude.com/docs/en/build-with-claude/prompt-caching (C, C2, C3).
- OpenAI, « Prompt caching », non daté —
  https://developers.openai.com/api/docs/guides/prompt-caching (C2).
- Claude Code Docs, « Manage costs effectively », non daté — https://code.claude.com/docs/en/costs (C).
- Cursor, « Improved token efficiency for longer agent runs », 2026-09-23 —
  https://cursor.com/blog/improved-token-efficiency (C2) ✓C3.
- Gloaguen et al., « Evaluating AGENTS.md », 2026 (v2 juin) —
  https://arxiv.org/html/2602.11988v2 (B, C2, E) ✓C3.
- Lulla et al., « On the Impact of AGENTS.md Files on the Efficiency of AI
  Coding Agents », 2026 — https://arxiv.org/abs/2601.20404 (C2).
- Pan et al., « LLMLingua-2 », 2024 — https://arxiv.org/html/2403.12968v2 (C2).
- Anthropic, « Quantifying infrastructure noise in agentic coding evals »,
  2026-02-05 — https://www.anthropic.com/engineering/infrastructure-noise (C2).
- Factory, « Evaluating Context Compression for AI Agents », 2025-12-16 —
  https://factory.com/news/evaluating-compression (C, C2).

**Routage, orchestration et review**

- Anthropic, « How we built our multi-agent research system », 2025-06-13 —
  https://www.anthropic.com/engineering/multi-agent-research-system (D).
- Cognition, « Don't Build Multi-Agents », 2025-06-12 —
  https://cognition.com/blog/dont-build-multi-agents (C, D).
- J. Lee, « Most of the LLM Routing Gap Is Task Type », 2026-08-25 —
  https://arxiv.org/pdf/2608.23023 (D) ✓C3.
- Awuni et al., « Who Judges Matters », 2026-09-15 — https://arxiv.org/pdf/2609.17857 (D).
- Li et al., « OpenCodeReview », 2026-08-11 — https://arxiv.org/pdf/2608.09290 (D).
- Anthropic, « Code Review for Claude Code », 2026-03-09 — https://claude.com/blog/code-review (D) ✓C3.
- Cursor, « Building a better Bugbot », 2026-01 — https://cursor.com/blog/building-bugbot (D).
- OpenHands Docs, « Stuck Detector », non daté —
  https://docs.openhands.dev/sdk/guides/agent-stuck-detector (D).
- Adams et al. (Meta), « RADAR », 2026-05-28 — https://arxiv.org/abs/2605.30208 (D).
- obra/superpowers, `subagent-driven-development/SKILL.md` (v6.4.1, 2026-09-19) —
  https://raw.githubusercontent.com/obra/superpowers/main/skills/subagent-driven-development/SKILL.md (E).
- Anthropic, plugin Claude Code `code-review`, non daté —
  https://github.com/anthropics/claude-code/tree/main/plugins/code-review (E).
- Agent OS CHANGELOG (v3.0, 2026-01-20) —
  https://github.com/buildermethods/agent-os/blob/main/CHANGELOG.md (E).
- Taghavi & Bhavani, « Spec Kit Agents », 2026-04-07 — https://arxiv.org/html/2604.05278 (E).
