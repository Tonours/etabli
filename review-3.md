# Review branche refactor/skill-default-load (review 3)

- **Modèle** : gpt-5.6-sol (xhigh)
- **Date** : 2026-08-23
- **HEAD** : a8c28f8

## Périmètre lu

### Cible et méthode

- Cible confirmée : merge-base `613dc7c`, HEAD
  `a8c28f8c6e8560b1895ff642ef65a6e7be69c8b1`, 12 commits, 266 fichiers,
  `+15 424/-3 750`.
- Diffstat et liste des fichiers lus pour les 12 commits ; numstat complet de
  `d7891ab` et stat détaillée des commits de réponse au council
  (`f35d672`, `f1438ab`, `a8c28f8`).
- `review-aggregate.md` et les deux plans de réponse lus intégralement.
  `round-1.md` et `round-2.md` lus intégralement ; dans `round-3.md`, périmètre,
  findings, axes et ROI ; dans `round-4.md` à `round-7.md`, findings, axes,
  verdicts, ROI et lacunes. Le reste des comptes-rendus bruts a été échantillonné
  par titres et convergences.
- Fichiers pivots lus intégralement : `docs/harness-eval.md`,
  `docs/how-it-works.md`, `workflow/spec.md`,
  `workflow/review-rubric.md`, `workflow/skills/review.md`,
  `workflow/skills/implementation-loop.md`, `scripts/etabli-harness-eval`,
  `scripts/lib/etabli-harness-eval.sh`, `scripts/pi-review-hunter`,
  `scripts/verify-agentic-infra`, `.github/workflows/agentic-infra.yml`,
  `workflow/runtime/agentic-infra-checks.tsv`,
  `workflow/runtime/skill-surface.tsv`, les 8 oracles/prompts harness et leur
  manifest.
- Lecture ciblée des résolveurs et reconcilers :
  `claude/hooks/workflow-router-lib.mjs`,
  `scripts/lib/install-main.sh`, `scripts/deploy-agent-workflow`,
  `scripts/check-fix-symlinks.sh`, `scripts/lib/prefer-cursor-agent.sh`,
  leurs tests de cohérence et les adaptateurs Pi/Claude de review.
- Le contexte durable consulté était actuel mais secondaire ; tous les verdicts
  ci-dessous reposent sur le dépôt et les exécutions locales.

### Vérifications exécutées

- `scripts/verify-agentic-infra core` : 16/16 checks déclarés, tous verts.
- `scripts/verify-agentic-infra full` : 69/69 checks déclarés, tous verts,
  environ 184 s.
- `bash tests/etabli-harness-eval-smoke.sh` : vert.
- `bash tests/pi-review-hunter-smoke.sh` : vert.
- `bash tests/agentic-infra-manifest-smoke.sh` : vert.
- `git diff --check 613dc7c..a8c28f8` : vert.
- Null baseline rejouée hors modèle : 1/8, seul
  `plan-draft-no-mutate` passe.
- Sondes adversariales temporaires : commit/amend d'un extra, rename vers une
  destination allowlistée, transcript GO dégénéré, isolation contradictoire,
  cellule réutilisée et oracle rouge avec exit global vert.
- Aucun modèle live/facturé n'a été lancé.

Le vert hermétique est réel. Il prouve la stabilité des checks actuels, pas
l'absence des contournements ci-dessous.

## Axe 1 — Findings

### BLOCKER

#### B1 — Le grader prend un Git modifiable par le sujet comme baseline d'intégrité

- **Fichiers** :
  `scripts/lib/etabli-harness-eval.sh:113-131`,
  `tests/fixtures/harness-v1/tasks/ready-implement-touches-only-plan-files/oracle.sh:8-9`,
  `tests/fixtures/harness-v1/tasks/review-isolation-sentinel/oracle.sh:10-13`,
  `tests/fixtures/harness-v1/tasks/review-spec-drift/oracle.sh:5-10`.
- **Fait vérifié** : les allowlists ne voient que le porcelain courant. Un
  fichier extra ajouté puis commité passe la tâche READY ; le même extra enfoui
  par `commit --amend` conserve un seul commit et passe la safety task. Pour un
  rename/copy, `harness_porcelain_paths` n'émet que `$NF`, donc
  `workflow/spec.md -> docs/plan/moved-spec.md` est accepté parce que seule la
  destination allowlistée est contrôlée. Enfin, supprimer `FORBIDDEN.txt` puis
  fournir le transcript BLOCK attendu passe `review-spec-drift`, dont l'oracle
  ne contrôle aucun état.
- **Inférence** : une cellule peut obtenir un succès tout en ayant produit une
  mutation interdite ; un futur `pass@1` live n'est donc pas une mesure fiable
  du comportement annoncé.
- **Opinion** : BLOCKER pour publier ou comparer des scores, car l'intégrité de
  l'état final est le cœur de la suite.
- **Fix** : capturer hors du worktree une baseline immuable de l'arbre, de HEAD
  et des inputs, puis comparer l'état final exact avec le delta autorisé en
  parsant le porcelain NUL et les deux côtés des renames/copies.

### MAJOR

#### M1 — Le contrôle positif GO accepte un faux protocole de six lignes

- **Fichiers** : `scripts/lib/etabli-harness-eval.sh:90-93`,
  `tests/fixtures/harness-v1/tasks/review-go-clean-diff/oracle.sh:7-21`.
- **Fait vérifié** : `harness_require_tables` vérifie deux sous-chaînes, pas les
  huit lenses ni la structure des tables. Un transcript contenant seulement
  `isolation: isolated`, `runner: pi-child`, `| Lens |`, `Deciding-code`, un
  `file:line` et `Verdict: GO` passe.
- **Inférence** : le contrôle élimine une politique always-BLOCK, mais ne prouve
  ni inspection ni respect du protocole de review.
- **Fix** : parser les huit lignes de lens et au moins une vraie ligne de
  deciding-code, avec colonnes et références valides.

#### M2 — La safety task exige un verdict que le contrat interdit après sentinel

- **Fichiers** :
  `tests/fixtures/harness-v1/tasks/review-isolation-sentinel/oracle.sh:5-6`,
  `workflow/skills/review.md:37-39`.
- **Fait vérifié** : l'oracle exige `Verdict: BLOCK` ou
  `Verdict: GO WITH NOTES`, alors que le contrat dit que
  `HUNTER_SPAWN_UNAVAILABLE`/`HUNTER_TIMEOUT` est un hard stop et qu'il ne faut
  pas continuer jusqu'au verdict lead.
- **Inférence** : l'agent conforme échoue la cellule ; l'agent qui viole le
  contrat peut la réussir.
- **Fix** : choisir une seule sémantique canonique, idéalement accepter la
  sentinel exacte sans verdict dans cette task ou modifier explicitement le
  contrat pour imposer `Verdict: BLOCK`.

#### M3 — Une isolation contradictoire passe avec un verdict non-GO

- **Fichier** :
  `tests/fixtures/harness-v1/tasks/no-parent-logic-claim/oracle.sh:14-22`.
- **Fait vérifié** : le rejet de `isolation: none` ne s'applique qu'à GO ; avec
  `isolation: isolated`, `runner: pi-child`, `isolation: none` et
  `Verdict: GO WITH NOTES`, la branche isolée sort 0.
- **Inférence** : la signature dite « exhaustive » n'est pas exclusive.
- **Fix** : rejeter d'abord tout transcript contenant simultanément les deux
  états, indépendamment du verdict.

#### M4 — Réutiliser `ETABLI_HARNESS_EVAL_DIR` contamine la prochaine baseline

- **Fichiers** : `scripts/etabli-harness-eval:117-123,139`,
  `scripts/lib/etabli-harness-eval.sh:351-372`.
- **Fait vérifié** : les noms de cellules sont déterministes et une destination
  existante n'est ni refusée ni nettoyée ; le second `git init/add/commit`
  absorbe les restes du run précédent dans sa baseline.
- **Inférence** : un run relancé dans le répertoire documenté peut noter des
  artefacts antérieurs comme état initial légitime.
- **Fix** : refuser une cellule existante ou créer un sous-répertoire de run
  unique et vide.

#### M5 — Les timeouts ne bornent pas les descendants

- **Fichiers** : `scripts/lib/etabli-harness-eval.sh:330-339`,
  `scripts/pi-review-hunter:137-166`.
- **Fait vérifié** : l'alarme/`timeout` vise le processus direct ; aucun helper
  ne crée puis ne termine un process group. Un enfant détaché peut survivre au
  timeout et continuer à écrire ou consommer des ressources.
- **Inférence** : sur les runs live, la limite de 600 s ne borne ni le coût ni
  les effets tardifs.
- **Fix** : exécuter chaque runner dans son propre process group, envoyer
  TERM puis KILL au groupe et le reap avant grading.

#### M6 — L'identité « frozen » ne couvre pas la task et le report mélange les suites

- **Fichiers** : `scripts/lib/etabli-harness-eval.sh:228-260,524-530`,
  `tests/fixtures/harness-v1/manifest.json:5-8`.
- **Fait vérifié** : une ligne ne pinne que le manifest et l'oracle ; prompt,
  overlay, uncommitted, expected, driver et SHA du dépôt sont absents. Le report
  groupe uniquement par `task_id/runner`, même si modèle, manifest ou oracle
  diffèrent.
- **Inférence** : deux populations ou implémentations incompatibles peuvent
  produire un unique `pass_at_1`, donc une comparaison historiquement fausse.
- **Fix** : calculer un `suite_run_id` couvrant tous les inputs et le code du
  runner, puis refuser ou séparer tout mélange d'identités.

#### M7 — Le live profile peut annoncer vert une cellule rouge ou un skip

- **Fichiers** : `scripts/etabli-harness-eval:141-146`,
  `tests/etabli-harness-eval-live.sh:6-11`.
- **Fait vérifié** : `run` exige seulement que `harness_run_once` retourne une
  ligne JSON non vide ; `.pass: false` ne change pas son exit status. Le wrapper
  live sort aussi 0 quand `ETABLI_HARNESS_EVAL` est absent.
- **Inférence** : `verify-agentic-infra live` peut imprimer
  `SUMMARY: all checks passed` sans succès harness, voire sans l'avoir exécuté.
- **Fix** : donner au skip un statut distinct et faire échouer `run`/le wrapper
  lorsqu'une ligne émise a `.pass != true`.

#### M8 — Le correctif de collision Cursor supprime tout symlink custom Grok

- **Fichier** : `scripts/lib/prefer-cursor-agent.sh:14-18,41-43`.
- **Fait vérifié** : tout symlink `~/.grok/bin/agent` est classé collision sans
  comparer sa cible à `~/.grok/bin/grok`, puis supprimé par l'installer et le
  hook shell.
- **Inférence** : `~/.grok/bin/agent -> /opt/custom-agent` est détruit alors
  qu'il ne s'agit pas de l'alias Grok visé.
- **Fix** : supprimer uniquement si les deux chemins résolvent vers le même
  fichier.

#### M9 — La suppression de `cross_harness` a laissé le reconciler principal sans cleanup équivalent

- **Fichiers** : `scripts/lib/install-main.sh:125-150,1570`,
  `scripts/deploy-agent-workflow:265-281`.
- **Fait vérifié** : le deployer retire les liens `pi/skills/*` présents sous
  `.claude/skills` et `.codex/skills`, mais l'installer principal ne retire que
  les liens cassés. Un lien vivant vers une skill Pi démotée survit donc à
  `scripts/install.sh`.
- **Inférence** : le chemin d'installation principal peut restaurer un état que
  le deployer et le fixer déclarent invalide.
- **Fix** : déplacer cette politique dans un reconciler partagé et l'appeler
  depuis les trois interfaces.

### MINOR

#### m1 — La table canonique et le classifier divergent sur l'ordinary coding

- **Fichiers** : `workflow/spec.md:131-141`,
  `claude/hooks/workflow-router-lib.mjs:796-807`,
  `pi/extensions/__tests__/workflow-router-runtime.test.ts:61-72`.
- **Fait vérifié** : la spec route un correctif ordinaire sans PLAN vers
  `answer`, tandis que le classifier et son test imposent `plan-implement`.
- **Inférence** : l'impact actuel est surtout documentaire/télémétrique depuis
  ADR-0014, mais toute réutilisation du classifier comme dispatch rendra le
  conflit comportemental.
- **Fix** : trancher la frontière « ordinary vs multi-slice » et générer la
  fixture depuis cette décision.

#### m2 — Le contrat d'implementation-loop contredit l'exception Daily Pi

- **Fichiers** : `workflow/skills/implementation-loop.md:86-90`,
  `workflow/skills/review.md:41-45`.
- **Fait vérifié** : le premier exige Logic et Spec en fresh context ; le second
  impose Spec dans le parent pour Daily Pi.
- **Inférence** : une exécution Pi conforme à `review.md` peut être refusée par
  la completion evidence du loop.
- **Fix** : référencer explicitement l'exception Daily Pi à l'étape 13 et dans
  la completion evidence.

#### m3 — Les archives annoncent 80/80 alors que le runner ne déclare que 69 checks

- **Fichiers** :
  `docs/plan/20260823-review-findings-fixes.md:14`,
  `docs/plan/20260823-oracle-hardening-null-baseline.md:15`,
  `workflow/runtime/agentic-infra-checks.tsv:2-70`.
- **Fait vérifié** : le manifest contient 16 entrées core et 53 full, soit
  69 checks ; le run local full a bien exécuté ces 69 lignes et les a toutes
  passées.
- **Inférence** : le statut vert est vrai, le dénominateur archivé ne l'est pas.
- **Fix** : remplacer 80/80 par 69/69 et faire produire le total par le runner.

#### m4 — Le smoke ne verrouille pas la baseline publiée à 1/8

- **Fichier** : `tests/etabli-harness-eval-smoke.sh:299-309`.
- **Fait vérifié** : le test accepte jusqu'à deux succès et ne vérifie pas que
  l'unique ID est `plan-draft-no-mutate`.
- **Inférence** : une régression de 1/8 à 2/8 peut rester verte tout en rendant
  la documentation fausse.
- **Fix** : exiger exactement un succès et son ID.

#### m5 — Les échecs d'installation du hook shell sont transformés en succès

- **Fichier** : `scripts/lib/prefer-cursor-agent.sh:58-64`.
- **Fait vérifié** : échec de `touch`, génération du hook ou `mktemp` retourne
  0 ; le caller ne peut donc pas afficher son warning.
- **Inférence** : l'installation peut annoncer un PATH réparé alors qu'aucune
  modification n'a eu lieu.
- **Fix** : retourner 1 sur ces trois branches d'échec.

### NIT

Aucun NIT retenu : les écarts de style restants n'affectent pas la décision.

## Axe 2 — Choix de direction

### 1. Recentrage kernel skills

**Verdict : bonne décision.**

La réduction à 14 `pi_core` et 14 `agents_visible`, la suppression du
suite-router obligatoire et la distillation des adapters vers des contrats
partagés vont dans le bon sens : moins de contexte par défaut, progressive
disclosure et moins de procédures copiées. Les 15 lignes `all_zero`, les
adaptateurs agents-visible qui contiennent encore une procédure Pi, et le
conflit de fraîcheur Logic/Spec montrent toutefois que la distillation n'est pas
terminée. La direction est bonne ; le commit `d7891ab` est en revanche trop
large pour être une unité de preuve propre : 141 fichiers et 9 240 ajouts
mélangent KonMari, lane-3, evidence/program-state et .

### 2. Isolation des review hunters

**Verdict : décision discutable, à conserver sous conditions.**

Ce n'est pas du théâtre pur : nouveau processus, `--no-session`,
`--no-skills`, `--no-extensions`, `--no-context-files`, patch transmis par
fichier et outils `read,grep` réduisent réellement la contamination de contexte.
Mais ce n'est ni un sandbox filesystem/environnement, ni une preuve qu'un hunt
valide a eu lieu. Les sentinelles décrivent l'échec de spawn ; elles n'attestent
pas la qualité du résultat, les timeout descendants ne sont pas bornés, et une
task exige aujourd'hui de violer le hard stop canonique. Conserver l'isolation
de contexte, mais cesser de la présenter comme une isolation opérationnelle
forte avant process-group, résultat structuré et contrat sentinel unique.

### 3. Suite harness-eval

**Verdict : décision discutable, valable seulement comme laboratoire de régression à ce stade.**

Pour un repo personnel, huit tâches originales, des oracles exécutables, un
runner gelé et une null baseline ne sont pas en soi de la sur-ingénierie : la
taille reste bornée et la méthode force des claims falsifiables. Le contrôle
GO-only et le 1/8 sont des améliorations réelles par rapport au 5–7/7 d'un agent
nul.

En revanche, la suite n'est pas encore un benchmark comparatif : baseline Git
modifiable, protocole textuel falsifiable, identité de task incomplète et report
qui mélange les populations. Le plafond textuel est structurel : sans
télémétrie indépendante du sujet ou inspection de trajectoire, un transcript
peut seulement prouver qu'il contient les chaînes attendues. La null baseline
mesure un plancher naïf, pas le plafond adversarial. Aucun score Pi/Grok ne doit
être publié avant B1, M1, M2, M6 et M7.

### 4. Réponse au council

**Verdict : bonne décision, honnêteté restaurée partiellement — pas cosmétique.**

L'accumulation des FAIL, `skill-lock` en core, la suppression de
`route-context-manifest`, la suppression de la lane `cross_harness` vide et
l'archive indexée sont des changements exécutables, pas du texte défensif. Le
full est réellement vert aujourd'hui.

La réponse reste incomplète : denominator 80/80 faux, cleanup non propagé dans
l'installer principal et oracles encore contournables. Le diagnostic du council
— une décision enregistrée mais mal propagée — se reproduit donc encore, mais
sur une surface plus petite.

### 5. CI sur toutes les branches

**Verdict : bonne décision sous condition de déduplication.**

Le changement corrige un trou réel : des commits de branche pouvaient rester
sans CI avant PR. Pour ce repo, trois jobs hermétiques par push sont un coût
acceptable. Mais une branche avec PR ouverte déclenche les trois jobs sur
`push` puis les trois mêmes sur `pull_request`, et le workflow n'a pas de
`concurrency`/`cancel-in-progress`. Garder `push: "**"`, ajouter une clé de
concurrence par branche/PR et annuler les runs superseded ; si le coût devient
visible, supprimer le doublon push d'une branche déjà couverte par PR plutôt que
réduire les checks contractuels.

## Axe 3 — Reste ouvert

### 1. Maintenant — Réconcilier spec et classifier sur l'ordinary coding

ROI maximal : décision petite, conflit canonique fréquent. Garder l'intention
de la branche : correctif borné sans PLAN explicite → édition directe ;
demande de plan, travail multi-slice, large ou ambigu → `plan-loop` /
`plan-implement`. Définir un prédicat déterministe minimal et aligner tests,
spec et classifier.

### 2. Maintenant — Un reconciler unique, trois interfaces

C'est le prochain travail structurel. `install-main.sh`,
`deploy-agent-workflow` et `check-fix-symlinks.sh` recalculent séparément le
desired state et divergent déjà. Construire un planner commun avec
`check`, `dry-run`, `apply`, puis conserver les trois scripts comme façades.
Les fixtures doivent couvrir liens personnels, targets relatifs, clone déplacé,
skills inactives et settings non managés.

### 3. Maintenant — Trancher brain/obvault

Le council a surinterprété ADR-0017 : il régit explicitement le MCP work, pas
toute lecture CLI. Le défaut opérationnel existe néanmoins :
`workflow/runtime/obvault-topic-resolver.mjs:20-27,80` résout puis réémet une
commande littérale vers `~/work/obvault`, tandis que l'ADR et `.mcp.json`
désignent `brain` pour work.

Décision recommandée : un resolver autoritaire et scope-aware,
`work -> brain`, `personal -> obvault`, avec `OBVAULT_ROOT` exclusif et aucune
fallback inter-scope. Trancher maintenant ; implémenter après avoir donné à
`brain` un entrypoint CLI équivalent ou décidé que le work scope est MCP-only.

### 4. Maintenant pour la décision, après le reconciler pour l'exécution — SPOF volume externe

Le risque n'est pas abstrait : les symlinks runtime pointent vers
`/Volumes/Crucial/work/etabli`; volume absent, plusieurs agents perdent
silencieusement leur contrat. Le choix le plus simple est un checkout canonique
sous `$HOME` et un miroir sur le volume externe. Si le volume doit rester
canonique, déployer atomiquement un snapshot last-known-good sous XDG et faire
pointer les runtimes dessus. Une simple alerte ne corrige pas la perte du
contrat.

### 5. Maintenant, après le reconciler — Scinder workstation et agent

`install-main.sh` reste un bootstrap machine privilégié, long, `set -e` seulement
et mêlé à la convergence des agents. Garder un `install-workstation` explicite
pour Homebrew/npm/fonts/editors ; faire de l'onboarding agent une application
du desired state partagé, dry-run par défaut. Ne pas dupliquer une quatrième
implémentation pendant la scission.

### 6. Maintenant, dans le même chantier — Supprimer les 15 skills `all_zero`

Elles sont intentionnellement inactives, pas « mal découvertes ». Les conserver
dans le catalogue live ajoute parsing, explications et faux affordances ;
l'installer annonce encore `/skill:caveman` et `/skill:grill-me`
(`scripts/lib/install-main.sh:1815-1822`). Retirer les lignes du catalogue
déployé et l'aide obsolète ; archiver les sources si elles ont encore une valeur.
Ne pas ajouter une nouvelle colonne d'opt-in pour justifier du stock mort.

### 7. Plus tard — Tiering du rituel implementation-loop

La critique de coût est fondée, mais changer maintenant remplacerait une opinion
par une autre. Mesurer au moins dix outcomes représentatifs après correction de
l'ordinary routing, puis comparer trois niveaux : direct borné, planned
supervisé, autonome/high-risk. Garder une review cumulative indépendante pour
les changements runtime planifiés ; réserver double adversary/cross-model aux
risques élevés si les outcomes ne montrent pas de gain sur les autres.

### 8. Jamais comme chantier générique — « Ergonomie » globale du check-freeze

La prémisse archivée est trop large : le parser supporte déjà pipes, `&&`, `||`
et les tests autorisent notamment `cd … && ls`
(`claude/hooks/workflow-router-lib.mjs:188-257`,
`tests/dual-runtime-guard-matrix-smoke.sh:97-114`). Ne pas assouplir un parser
shell par principe. Rouvrir uniquement sur un faux positif concret, avec une
fixture rouge puis une allowance minimale.

## Score global /10

| Dimension | Score | Motif |
| --- | ---: | --- |
| Correctness | 5,5 | Core/full verts, mais l'intégrité et la discrimination de la nouvelle suite sont contournables. |
| Direction | 7,3 | Kernel plus petit, dead lanes supprimées, preuve exécutable ; plusieurs frontières restent non tranchées. |
| Exécution | 6,5 | Réponse substantielle au council et 69 checks verts ; evidence count faux, sentinel/live semantics et reconcilers incomplets. |
| Maintenance | 5,5 | Moins de surfaces mortes, mais branche de 266 fichiers, trois reconcilers et contrats encore dupliqués/contradictoires. |

**Score global : 6,2/10. Verdict : BLOCK** jusqu'à correction de B1 et des
incohérences M2/M7 ; la branche ne doit surtout pas publier de comparaison live
avant M1/M6.

## Lacunes

- Je n'ai pas lu ligne par ligne les 266 fichiers. En particulier,
  `scripts/evidence-proof` (~834 lignes), `scripts/program-state` (~682),
  `scripts/workflow-event` (~763) et `scripts/lib/-suite.mjs` (~1 024) ont
  été couverts par diffstat, appels, tests et lecture ciblée, pas par audit
  intégral.
- Les vendors, Neovim, Herdr, la totalité de l'installer et tous les documents
  archivés n'ont pas été relus intégralement.
- Les paragraphes narratifs non décisifs de `round-3.md` à `round-7.md` n'ont
  pas tous été relus ; leurs findings/axes/ROI/lacunes l'ont été.
- Aucun run live Pi/Grok, aucune facturation, aucun test de disponibilité réelle
  du modèle Cursor, aucun fresh install, aucun démontage du volume, aucun
  déploiement macmini et aucun audit de secrets dans l'historique.
- Le coût GitHub Actions n'a pas été mesuré sur des runs distants ; le doublon
  push/PR est déduit du YAML.
- Les claims externes sur DeepSWE n'ont pas été revalidés sur le web ; la review
  juge l'adaptation locale et ses oracles.
- Le plan modifié localement
  `docs/plan/20260823-discarded-implemented-archived-oracle-cycle.md` a été
  exclu au profit de la version HEAD. `review-1.md` et `review-2.md`, non
  trackés, n'ont pas servi d'autorité.
