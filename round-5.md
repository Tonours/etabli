# Review externe — etabli (round 5)

- **Modèle** : kimi-k3 (max)
- **Date** : 2026-08-23

## Périmètre et méthode

### Lu intégralement

- `README.md`, `AGENTS.md` (racine)
- `workflow/spec.md`, `workflow/agent-quick-card.md`, `workflow/contract-details.md`
- `docs/workflow-guide.md`
- `scripts/lib/install-main.sh` (1 910 lignes, pas ~1 600 comme annoncé)
- `scripts/lib/etabli-harness-eval.sh`, `docs/harness-eval.md`,
  `tests/etabli-harness-eval-smoke.sh`, listing complet de
  `tests/fixtures/harness-v1/` + lecture de 3 oracles et 2 prompts
- `workflow/skills/implementation-loop.md`, `workflow/skills/review.md`,
  `workflow/skills/self-improvement-loop.md`
- `workflow/runtime/skill-surface.tsv`, `workflow/runtime/agentic-infra-checks.tsv`,
  `scripts/lib/skill-catalog.sh` (début), `vendor/sources.tsv`
- ADR-0013 à ADR-0017
- `SECURITY.md`, `.gitignore`, `scripts/verify-agentic-infra`,
  `tests/supply-chain-smoke.sh` (début), `scripts/deploy-agent-workflow`
  (blocs settings/cross-harness/vendor uniquement)
- `docs/adversary-etabli-10-scorecard.md` (lu en dernier, comme imposé), puis
  `round-4.md` pour positionnement

### Exécuté (preuves locales, HEAD `a18d3ef`)

- `scripts/verify-agentic-infra core` → **exit 0** (~36 s)
- `cd pi && bun run verify:skills` → **exit 1** (5 skills en drift, détails en M2)
- 3 contre-exemples d'oracles en worktrees `/tmp` → résultats en M1
- Sonde `classifyWorkflowRoute` sur 3 prompts ordinaires → résultats en M3
- `git log --oneline -30`, listings et comptages des dirs clés
- `gh run list --branch refactor/skill-default-load` → aucune run retournée

Légende : **fait vérifié** = lu ou reproduit par moi sur ce HEAD ;
**inférence** = conséquence du code non exercée en conditions réelles ;
**opinion** = jugement coût/valeur assumé.

## Findings

### BLOCKER

Aucun. Le repo est utilisable, le gate `core` passe, les guards critiques sont
réels. Les problèmes sont de convergence et de preuve, pas de sabotage.

### MAJOR

#### M1 — Les oracles de la harness eval acceptent des états que le contrat interdit

- **Fait vérifié (reproduit)** — `review-isolation-sentinel` (split **safety**) :
  `tests/fixtures/harness-v1/tasks/review-isolation-sentinel/oracle.sh:5-7`
  exige un sentinel transcript et `verdict != GO`, mais **aucun check du
  worktree** et aucun verdict parseable obligatoire. Worktree avec
  `src/runtime.sh` muté par mes soins + transcript pass synthétique →
  `{"pass":true}`. La seule propriété que la tâche existe pour protéger
  (review read-only, `prompt.md:1` « Do not edit files ») n'est pas vérifiée.
- **Fait vérifié (reproduit)** — `ready-implement-touches-only-plan-files` :
  `oracle.sh:5` se contente de greper `# harness-eval-marker`. Un
  `src/fixture.sh` réécrit en `exit 1` avec le marker → `{"pass":true}`.
  L'oracle prouve la confinement de scope, pas que l'implémentation fonctionne.
- **Fait vérifié (reproduit)** — `plan-draft-no-mutate` : l'allowlist
  (`oracle.sh:6`) autorise `docs/plan/` ; avec un `docs/plan/` pré-existant
  (cas réel : le scaffold et tout projet ayant archivé en ont un), un
  `docs/plan/unauthorized.md` écrit alors que PLAN est DRAFT → `{"pass":true}`.
  Nuance : le guard runtime a une escape `plan-cleanup --archive` vers
  `docs/plan/`, donc l'oracle reflète les escapes du guard — mais il accepte
  des écritures arbitraires que le guard dénierait. L'oracle est plus faible
  que le mécanisme qu'il est censé évaluer.
- **Pourquoi** — le smoke (`tests/etabli-harness-eval-smoke.sh`) prouve que les
  oracles sont cohérents avec leurs fixtures pass/fail et que le grader fail
  closed sur `runner_exit != 0` ; il ne prouve pas que les oracles discriminent
  le comportement contractuel. Un `pass@1` live peut récompenser une mutation
  interdite ou une implémentation cassée. Sur une suite de 7 tâches, 3 oracles
  troués est un taux élevé.
- **Fix** — pour chaque task : état final exact ou patch autorisé hashé,
  propreté du worktree obligatoire sur le split safety, verdict parseable
  obligatoire sur toute task de review.

#### M2 — `verify-agentic-infra full` est rouge sur HEAD, et sa structure masque la suite

- **Fait vérifié (reproduit)** — `cd pi && bun run verify:skills` échoue :
  `plan-implement`, `adversary`, `review`, `implement`, `pr-review` ont un hash
  réel différent de `skills-lock.json`. `git status` ne montre aucune
  modification de ces fichiers : la dérive est commitée, pas locale.
- **Fait vérifié** — `workflow/runtime/agentic-infra-checks.tsv` place
  `skill-lock` en profil `full` groupe `pi` ; `.github/workflows/` exécute
  `scripts/verify-agentic-infra pi` (qui inclut les lignes `full` du groupe).
  `scripts/verify-agentic-infra:80` tourne sous `set -euo pipefail` et
  `run_check` retourne non-zéro → **le premier échec arrête la sélection** :
  `pi-import-smoke` et tout ce qui suit ne tournent pas.
- **Inférence forte, non vérifiée côté GitHub** — la CI de la branche devrait
  être rouge sur le job `pi` ; `gh run list` ne retourne aucune run pour cette
  branche, donc je ne confirme pas le statut distant.
- **Pourquoi** — le README (`README.md:130`) présente `full` comme « every
  deterministic repository check » ; sur HEAD ce niveau de preuve n'est pas
  atteint, et le pattern « rouge pré-existant qui masque un nouvel échec » est
  exactement la leçon consignée dans ADR-0014:81-87 — non appliquée à la
  structure du runner lui-même.
- **Fix** — résoudre les 5 hashes (review du diff puis `update:skills-lock`),
  et faire rapporter tous les échecs au lieu d'arrêter au premier.

#### M3 — La table de routing canonique et le classifier exécutable divergent sur le cas le plus fréquent

- **Fait vérifié (reproduit)** —
  `classifyWorkflowRoute("Corrige ce bug", { planStatus: "missing" })` →
  `plan-implement` (idem « fix the typo in README », « implement the login
  form »). `workflow/spec.md:135` route l'ordinary coding sans PLAN et sans
  demande de plan vers `answer` avec édition directe.
- **Fait vérifié** — `scripts/router-eval` (53 cas, accuracy 1.0, dans le gate
  core) mesure la conformité du classifier à ses propres fixtures, pas à la
  table qui « wins on conflict » (`README.md:180`).
- **Pourquoi** — depuis ADR-0014 le classifier est library-only
  (observationnel), donc l'impact aujourd'hui est borné ; mais toute
  réutilisation de sa décision (-suite `claude_route`, futurs guards)
  hérite d'une sémantique contraire au contrat. Deux sources de vérité sur la
  règle la plus courante du système.
- **Fix** — une seule règle pour l'ordinary coding ; générer les fixtures du
  router depuis la table canonique, ou corriger la table.

#### M4 — La frontière mémoire work/personal est contradictoire entre l'ADR et le contrat vivant

- **Fait vérifié** — ADR-0017 (`docs/adr/0017-...md:10-13`) : la machine work
  sert `~/work/brain` et « the personal `obvault` vault … is not registered on
  a work machine ». Mais `AGENTS.md` (section Knowledge Base),
  `workflow/agent-quick-card.md:111-114`,
  `workflow/skills/obvault-memory.md:21,42,50-57` et
  `workflow/runtime/obvault-topic-resolver.mjs:25` imposent tous
  `~/work/obvault` comme entrypoint.
- **Pourquoi** — l'ADR le plus récent sur le sujet n'a pas été propagé dans le
  contrat canonique. Sur machine work, un agent suivant la quick card lit une
  base personnelle que la décision d'architecture exclut, ou échoue si elle est
  absente. C'est un cas réel de « le contrat dit deux choses incompatibles ».
- **Fix** — résoudre le vault actif depuis `~/.etabli-scope` en un seul endroit
  (le resolver), pointer work → `brain`, personal → `obvault`, et supprimer les
  paths hardcodés.

#### M5 — La convergence locale est réimplémentée (au moins) deux fois, avec des politiques déjà divergentes

- **Fait vérifié** — la sync de `~/.pi/agent/settings.json` existe dans
  `scripts/lib/install-main.sh:507-631` (ajoute **tous** les
  `enabledModels` trackés, purge 8 legacy + tout `local-mlx/*`) et dans
  `scripts/deploy-agent-workflow:391-438` (`managedModels` = ensemble hardcodé
  de **5** modèles, `legacyModels` = 1 seul). Même cible, deux politiques.
- **Fait vérifié** — les listes de stale commands diffèrent aussi
  (`install-main.sh:1704-1727` vs le bloc équivalent du deployer).
- **Partiellement vérifié** — round-4 étend l'accusation à
  `scripts/check-fix-symlinks.sh:182-323` ; je n'ai pas lu ce fichier en
  profondeur, je marque ce troisième reconciler comme non revérifié.
- **Pourquoi** — selon que l'utilisateur relance le quick start ou le deployer,
  l'état convergé n'est pas le même. C'est précisément le drift qu'un repo
  « single source of truth » est censé éliminer ; ici la source unique s'arrête
  aux fichiers, pas aux procédures.
- **Fix** — un seul moteur idempotent (le deployer), appelé par l'installer et
  le fixer ; politique settings exprimée en données déclaratives partagées.

#### M6 — L'installer est le chemin le plus privilégié et le moins discipliné du repo

- **Fait vérifié** — `scripts/lib/install-main.sh:8` : `set -e` seul, pas
  `-u`/`pipefail` (le commentaire de `:1626` montre que le problème `set -u` a
  été rencontré et contourné localement plutôt que traité).
- **Fait vérifié** — RTK via `curl … | sh` depuis `master` (`:1252`), Homebrew
  depuis `HEAD` (`:1181`), ~13 npm globaux **sans versions** (`:1275-1288`),
  échecs de paquets convertis en warnings puis « Dependencies installed »
  (`:1239`).
- **Fait vérifié** — `tests/supply-chain-smoke.sh` pine sévèrement la CI
  (actions par SHA, `hunkdiff@0.17.3`, `pi-coding-agent@0.84.2`) mais ne couvre
  aucun des téléchargements de l'installer. Le smoke de l'installer
  (`install-main.sh:747-1114`, ~370 lignes embarquées dans le fichier de
  production) sort à `:1113` avant toute branche réelle (brew/apt/npm/font) :
  seuls les helpers sont testés.
- **Pourquoi** — la discipline supply-chain est appliquée au YAML de CI et
  relâchée sur le script qui écrit dans `~/.claude`, `~/.pi`, `~/.codex`,
  `~/.agents`, `~/.zshrc` et `~/.local/bin`. Le quick start README
  (`README.md:27-31`) pointe directement dessus.
- **Fix** — strict mode complet, versions pinées avec checksums pour ce qui est
  requis, et échec franc quand une dépendance déclarée requise manque.

### MINOR

#### m1 — La lane `cross_harness` est morte mais documentée comme vivante

- **Fait vérifié** — `workflow/runtime/skill-surface.tsv` : colonne
  `cross_harness` = `0` sur **les 95 lignes** (vérifié par awk). La boucle de
  linking (`install-main.sh:1627-1644`) itère donc un ensemble vide ;
  `prune_demoted_cross_harness_pi_skills` (`:442-463`) est purement
  soustractif ; le deployer rejoue la même boucle vide
  (`deploy-agent-workflow:589-593`). Le smoke de l'installer (`:932-948`)
  teste ce mécanisme sur un cas qui ne peut plus se produire.
- **Pourquoi** — `AGENTS.md` (symlink layout) promet que `~/.codex/skills`
  reçoit « catalog entries marked `cross_harness` » : promesse structurellement
  vide aujourd'hui. Code + tests + docs entretenus pour une lane sans
  aucune entrée.
- **Fix** — soit marquer au moins une skill `cross_harness=1`, soit supprimer
  colonne, boucles et tests associés et corriger `AGENTS.md`.

#### m2 — ADR-0016 inclut `~/.agents` dans la convergence vendor ; le deployer ne le fait pas

- **Fait vérifié** — ADR-0016:26-31 : « every runtime surface that receives
  repo-managed vendor skill links… Today those surfaces are Pi, Claude, Codex,
  and Grok's shared `~/.agents` directory. » Mais
  `scripts/deploy-agent-workflow:596-602` ne lie les vendors actifs que vers
  `.pi/agent/skills`, `.claude/skills`, `.codex/skills` ; `.agents/skills`
  n'apparaît que dans le cleanup des vendors inactifs (`:580-587`).
- **Pourquoi** — le cleanup connaît une surface que l'installation ne produit
  pas ; l'invariant de convergence de l'ADR est faux tel qu'implémenté.
- **Fix** — lier les vendors actifs vers `.agents/skills`, ou amender l'ADR.

#### m3 — Dérive documentaire interne au contrat

- **Fait vérifié** — `workflow/contract-details.md:218` pointe
  `claude/commands/` (inexistant ; les commands vivent dans
  `claude/scopes/*/commands/`) ; `:286` pointe `claude/skills/playwright-*`
  (en réalité `claude/scopes/shared/skills/playwright-*`).
- **Fait vérifié** — ADR-0014:61-63 déclare
  `scripts/lib/route-context-manifest.mjs` orphelin, mais
  `agentic-infra-checks.tsv` garde `route-context-manifest-smoke` en profil
  `full` : une gate entretient un artefact sans consumer.
- **Fix** — corriger les deux pointeurs ; supprimer manifest/checker/smoke ou
  nommer un consumer réel.

#### m4 — `docs/` : discipline de bandeau inégale sur les analyses datées

- **Fait vérifié** — `docs/etabli-harness-audit-20260724.md` et
  `docs/adversary-etabli-10-baseline.md` portent un bandeau « Historical
  snapshot » ; `docs/harness-robustness-top5-20260801.md` et
  `docs/harness-optimization-blueprint.md` se présentent encore comme des
  verdicts/stratégies courants. Les analyses datées ne sont référencées que
  depuis `docs/plan/`, `docs/research/` et les rounds de review (vérifié par
  grep sur 10 d'entre elles).
- **Pourquoi** — pas un musée abandonné (les archives sont assumées et
  `docs/plan/README.md` cadre bien), mais un lecteur ne peut pas distinguer
  l'opérationnel de l'historique au niveau racine de `docs/`.
- **Fix** — un index `docs/README.md` avec statut
  `operational|historical|superseded`, ou généraliser le bandeau.

### NIT

- `install-main.sh` embarque ~370 lignes de harnais de test dans le fichier de
  production (`:747-1114`) parce que les helpers ne sont pas factorisés dans
  une lib sourceable — le test vit là par nécessité structurelle, pas par choix.
- `harness_run_bounded` (`scripts/lib/etabli-harness-eval.sh:330-340`) :
  `alarm` + `exec` en perl tue le process direct au timeout mais pas le groupe
  de process ; des grandchildren (pi spawnant des outils) peuvent survivre.
  **Inférence, non testée.**
- `install-main.sh:1207` parse l'API GitHub de lazygit avec `sed` alors que
  `jq` est une dépendance installée.
- Les compte-rendus de review (`round-*.md`) s'accumulent à la racine, non
  trackés et non couverts par `.gitignore` — le rituel de review laisse des
  artefacts hors du cadre documentaire du repo.

## Avis final

### 1. Verdict en une phrase

**Le noyau — contrat canonique, guards partagés Pi/Claude fail-closed, ADR
honnêtes — est réellement bien conçu ; mais le système complet est
surdimensionné pour un opérateur unique et sa promesse centrale (« une source
unique de vérité ») échoue précisément là où elle devrait être la plus forte :
trois sources canoniques se contredisent, la convergence est réimplémentée en
double, et la suite d'évaluation comportementale ne discrimine pas encore le
comportement.**

### 2. Top 3 forces réelles

1. **Les guards critiques sont partagés, testés et fail-closed — vérifié.**
   `planMutationGuardDecision` est une fonction unique consommée par Pi et
   Claude ; `dual-runtime-guard-matrix-smoke`, `plan-check-freeze-smoke`,
   `no-progress-mutate-deny-smoke` sont dans le gate `core`, que j'ai exécuté
   vert sur HEAD. ADR-0014 a supprimé l'injection de contexte en gardant les
   guards « because they *block* actions, which no prompt text can do » — c'est
   la bonne hiérarchie mécanisme > prose.
2. **L'ingénierie du grader de la harness eval est au-dessus de la moyenne des
   rigs personnels.** Chaque tâche a une paire de transcripts synthétiques
   pass/fail auto-testée en CI hermétique ; le grader fail closed sur
   `runner_exit != 0` (testé à `etabli-harness-eval-smoke.sh:189-199`), détecte
   les sentinels d'absence Cursor, épingle le SHA de l'évaluateur dans le
   manifest (vérifié par le smoke `:20-22`), refuse de compter un skip live
   comme un succès. Les trous sont dans la sémantique des oracles (M1), pas
   dans la plomberie — et la plomberie est la partie difficile à rattraper.
3. **La culture ADR est exceptionnellement honnête.** ADR-0013 supprime ~11k
   lignes sur preuve d'inutilité (13 events en un mois) et consigne que sa
   propre baseline était rouge alors que les archives la disaient verte ;
   ADR-0014 mesure le coût token avant suppression (~301 tok/turn) et déclare
   explicitement le risque non instrumenté ; ADR-0017 liste ses propres
   conséquences négatives (duplication d'engine sans test de drift). Peu de
   projets, personnels ou non, documentent leurs échecs avec cette précision.

### 3. Top 3 faiblesses réelles

1. **La preuve comportementale ne tient pas ses oracles.** Trois
   contre-exemples reproduits (M1) : le split safety ne vérifie pas le
   worktree, l'implémentation cassée passe, l'écriture pré-READY hors contrat
   passe. Tant que M1 n'est pas corrigé, tout `pass@1` live est une métrique
   récompensant des états interdits.
2. **La « source unique » s'arrête aux fichiers statiques.** Politiques de
   convergence dupliquées et divergentes (M5), spec ↔ classifier en
   contradiction sur le cas le plus fréquent (M3), ADR-0017 vs contrat mémoire
   (M4), ADR-0016 vs deployer (m2), `AGENTS.md` vs lane `cross_harness` vide
   (m1). Cinq instances d'un même défaut : la décision est enregistrée, sa
   propagation ne l'est pas.
3. **La sophistication du discours dépasse la preuve d'exécution.** `full` est
   rouge sur HEAD avec masquage en cascade (M2) ; le rituel d'implémentation
   impose quatre passes de review (adversary plan, simplify, quality, double
   hunter + adversary cross-model sur diff — `implementation-loop.md:5,51-98`)
   sans le moindre outcome mesuré, alors que le repo refuse lui-même toute
   claim de télémétrie avant 10 outcomes représentatifs (`spec.md:86-87`).
   **Opinion** assumée : pour un opérateur unique, c'est une discipline de
   plateforme régulée appliquée à des dotfiles.

### 4. Les 3 choses à arrêter de faire

1. **Arrêter d'ajouter des surfaces de preuve pendant que les gates existantes
   sont rouges ou trouées.** La harness eval a été ajoutée (ef11830) alors que
   `skill-lock` était déjà rouge ; chaque nouvelle lane (, ,
   harness-v1) ajoute du manifest/hash/report au-dessus d'oracles qui acceptent
   `exit 1` comme implémentation.
2. **Arrêter de réimplémenter la convergence dans chaque point d'entrée ops.**
   Installer, deployer (et probablement le fixer — non revérifié) ne doivent
   pas porter chacun leur copie de la politique ; c'est la source de M5, m1, m2.
3. **Arrêter le rituel uniforme de review à quatre passes.** Le repo connaît
   déjà le principe de proportionnalité (« validation claims proportional to
   evidence », README:8) mais ne l'applique pas à son propre pipeline : trois
   niveaux de risque, et double-hunter + cross-model réservés au high-risk ou
   aux récidives.

### 5. Les 3 choses à faire ensuite, par ROI

1. **ROI maximal, coût faible — remettre `full` vert et le rendre non
   masquant.** Revoir les 5 skills en drift, régénérer le lock si intentionnel,
   faire rapporter tous les échecs au lieu d'arrêter au premier. C'est la
   différence entre « core vert » et « deterministic checks pass » tel que le
   README l'affiche.
2. **ROI élevé — réécrire les 3 oracles troués avant tout run live.** Verdict
   obligatoire sur les tasks de review, propreté du worktree sur le split
   safety, état final exact (hash ou patch autorisé) sur les tasks
   d'implémentation. Trois petits fichiers ; sans eux la suite live ne mesure
   rien.
3. **ROI élevé — une décision, une propagation.** Trancher `brain`/`obvault`
   dans le resolver unique, aligner spec et classifier sur l'ordinary coding,
   fusionner les reconcilers de settings. Trois contradictions canoniques
   éliminées à la racine plutôt que cinq patchs de doc.

### 6. Score sur 10

| Dimension | Score | Justification |
| --- | ---: | --- |
| Cohérence architecture | **6,0** | Kernel et adapters réellement partagés ; mais 5 contradictions entre sources canoniques (M3, M4, m1, m2, m3). |
| Robustesse | **6,0** | Guards fail-closed testés et core vert vérifié ; mais oracles troués (M1), `full` rouge avec masquage (M2), installer permissif (M6). |
| Simplicité | **4,5** | 24 skills workflow, ~49 scripts, ~60 checks full, 95 skills catalogués, 4 passes de review, 2-3 reconcilers — pour un utilisateur. |
| Qualité d'exécution | **6,5** | ADR et grader au-dessus de la moyenne, smokes auto-testants ; mais gate rouge commitée, chemins réels de l'installer jamais testés, dérive doc interne. |
| Maintenabilité | **6,0** | Catalog TSV et symlink single-source réels ; mais politiques dupliquées, lanes mortes entretenues, 104 plans + analyses datées sans index de statut. |
| **Moyenne** | **5,8 / 10** | Excellent noyau, système complet non convergent. |

### Écart avec `docs/adversary-etabli-10-scorecard.md`

Je diffère frontalement de son « solid adversary 10 » :

1. **Sa définition du 10 est circulaire** (« every dimension ≥9, zero
   High/Critical open ») et le document se déclare lui-même « Historical
   snapshot… Not operational » (`:1`). Un 10 auto-attribué sur une grille
   maison, même honnête dans son slice, ne mesure pas la qualité du système.
2. **Sa dimension 6 (multi-model, 9/10)** scorait l'infrastructure du council…
   que ADR-0013 a supprimée quatre jours plus tard comme « infrastructure sized
   for a team evaluation harness in a single-operator dotfiles repo ». La
   meilleure réfutation du scorecard est interne au repo : il mesurait la
   *présence* de mécanismes, pas leur valeur.
3. **Sa suite de validation (`:9-24`) n'incluait pas `full`** ; sur HEAD actuel
   `full` est rouge (M2, reproduit). Le « 10 » ne survivait pas à sa propre
   gate complète.
4. **Aucune dimension simplicité/convergence** dans sa grille. Ma grille
   pénalise le surdimensionnement mono-utilisateur et la duplication des
   reconcilers ; la sienne récompensait l'ajout de surface.

Positionnement vs round-4 (5,6/10) : j'ai revérifié indépendamment ses M1
(3 repros identiques), M2 (mêmes 5 hashes), M3 (même sonde), M4 (mêmes paths)
et je les confirme toutes. Je monte légèrement l'exécution (6,5 vs 6,0) : le
grader de la harness eval est mieux construit que ce que round-4 crédite —
ses défauts sont sémantiques et localisés, sa plomberie (fail-closed,
sentinels, pinning, herméticité) est solide. Même bande de score, chemin
indépendant.

## Lacunes et non-vérifié

- Aucun run live Pi/Grok de la harness eval (billing + autorisation explicite
  requis) ; aucune claim comportementale live évaluée.
- Aucun fresh install macOS/Linux, aucun déplacement réel du clone, aucun
  deploy macmini : les conclusions installer/symlinks hors chemins testés sont
  des inférences de code.
- `scripts/check-fix-symlinks.sh` non lu en profondeur : le « troisième
  reconciler » de M5 est hérité de round-4, marqué partiellement vérifié.
- Non lus : `vendor/` (contenu), `nvim/`, `herdr/`, les 104 plans archivés,
  `docs/research/`, `round-1.md` à `round-3.md`, la majorité des 60 checks
  `full` individuellement, les hooks Claude autres que le router, les
  extensions Pi hors `workflow-router`.
- Pas d'audit de secrets sur l'historique git ; `.gitignore` et `SECURITY.md`
  couvrent les surfaces connues mais je ne conclus pas « aucun secret ».
- Statut CI distant non confirmé (`gh run list` vide sur la branche) : « CI
  rouge » est une inférence locale forte, pas un fait distant.
- Comparaison externe /DeepSWE non revérifiée ; seules les formulations
  prudentes du repo (status `not_established`) ont été constatées.

## État de review

**Verdict : GO WITH NOTES pour l'usage quotidien du kernel Pi/Claude ; BLOCK
pour toute claim « full validated », tout score live de la harness eval, et
toute réouverture du scorecard 10/10.**
