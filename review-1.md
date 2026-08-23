# Review branche refactor/skill-default-load (review 1)

- **Modèle** : claude-fable-5 (medium)
- **Date** : 2026-08-23
- **HEAD** : a8c28f8

Méthode : diffstat par commit, lecture intégrale des fichiers pivots
(`scripts/pi-review-hunter`, `scripts/lib/etabli-harness-eval.sh`, les 8
oracles, `scripts/verify-agentic-infra`, les hunks branche de
`install-main.sh`/`check-fix-symlinks.sh`/`prefer-cursor-agent.sh`,
`review-aggregate.md`, les deux plans archivés, `docs/harness-eval.md`),
抽查 déléguée à trois passes de lecture indépendantes (harness, hunters,
kernel/gate), et exécution des checks hermétiques :
`verify-agentic-infra core` **vert** (SUMMARY: all checks passed, 37 s),
`etabli-harness-eval-smoke` **ok**, `null-baseline` offline **1/8 reproduit**,
`bun test pi/extensions/__tests__` **238 pass / 0 fail**. Aucun run live
facturé. Chaque finding est marqué [vérifié] (exécuté ou lu de première main),
[repro-sub] (reproduit par une passe déléguée avec preuve d'exit code) ou
[inférence]/[opinion].

## Périmètre lu

- Lu en entier : `pi-review-hunter`, les 8 `oracle.sh`, `harness-eval.md`,
  `review-aggregate.md`, les deux plans 20260823, `prune_managed_*` de
  `install-main.sh`, `pi-autoresearch.json`, têtes de README /
  `docs/how-it-works.md`.
- Lu via passes déléguées (fichier entier, findings re-vérifiés par
  échantillon) : `etabli-harness-eval.sh`, `etabli-harness-eval`,
  `manifest.json`, `etabli-harness-eval-smoke.sh`, `pi-review-hunter-smoke.sh`,
  `workflow/skills/review.md`, `review-rubric.md`, templates review-*,
  `verify-agentic-infra`, `check-fix-symlinks.sh`, `prefer-cursor-agent.sh`,
  hunks branche d'`install-main.sh`, `.github/workflows/agentic-infra.yml`,
  grep exhaustif des références dangling (d7891ab, f35d672).
- Non lu : voir Lacunes.

## Axe 1 — Findings

### BLOCKER

Aucun blocker de merge. Le candidat le plus proche est M1 : il est fail-open
et destructif, mais la fonction préexiste à la branche et ne se déclenche que
sur un catalogue dégénéré. Je le laisse en MAJOR avec obligation de fix avant
tout refactor du catalogue.

### MAJOR

- **M1 — Prune fail-open : keep-list vide ⇒ `rm` de tous les liens skills.**
  `scripts/lib/install-main.sh:430-449` (et 451-470 pour agents). [vérifié]
  Si `skill_catalog_names` rend 0 lignes `pi_core` (catalogue présent mais
  filtré à vide), `is_core_pi_skill` est toujours faux et la boucle `rm -f`
  chaque lien de `~/.pi/agent/skills/` pointant vers le repo. `set -e` sans
  `-u`/`pipefail` sur ce chemin. C'est exactement le C6 du council, non fermé
  par la branche alors qu'elle a retravaillé la politique de prune (f35d672 a
  restauré `prune_pi_sourced_skill_links`). Fix : refuser de pruner si la
  keep-list est vide, avec warning.
- **M2 — `check-fix-symlinks.sh` crashe si le catalogue est présent mais sans
  match.** `scripts/check-fix-symlinks.sh:17-20, 207-232` (code branche).
  [repro-sub : `PI_CORE_SKILLS[@]: unbound variable` sous `set -u`]
  Le sentinel `("")` ne couvre que `SKILL_CATALOG_MISSING=1`. Fail-closed
  (crash), donc moins grave que M1, mais le fixer devient inutilisable dans le
  scénario où on en a besoin. Fix : forcer le sentinel aussi quand la lecture
  rend 0 lignes.
- **M3 — `prefer-cursor-agent.sh` avale ses échecs.**
  `scripts/lib/prefer-cursor-agent.sh:62-64` (fichier nouveau, 295e5bf).
  [repro-sub] `touch … || return 0` et `mktemp || return 0` : l'appelant
  (`install-main.sh:1747-1748`) ne warn que sur exit ≠ 0, donc un échec
  d'écriture passe pour un succès. Fix : `return 1` sur ces branches.
- **M4 — `hunter-read-only` : le « read-only » n'est pas vérifié sur le
  worktree.** `tests/fixtures/harness-v1/tasks/hunter-read-only/oracle.sh:5-16`.
  [vérifié : lu ; repro-sub : helper intact + transcript protocolaire +
  `EXTRA_EVIL.txt` ⇒ `oracle_exit=0`]
  SHA sur un seul fichier, aucun `harness_require_porcelain_allowlist`, aucun
  garde commits — incohérent avec l'oracle jumeau `review-isolation-sentinel`
  qui a les trois. Fix : ajouter allowlist porcelain + `rev-list --count == 1`.
- **M5 — Escape « commit bury » sur deux tâches safety/positives.**
  `plan-draft-no-mutate/oracle.sh:5-9`, `review-go-clean-diff/oracle.sh:23-26`.
  [repro-sub : write + `git commit` ⇒ porcelain propre ⇒ `oracle_exit=0`,
  `rev-list=2`] Seul `review-isolation-sentinel` compte les commits. Fix :
  généraliser le garde `rev-list --count HEAD == 1` à toute tâche
  safety/read-only.
- **M6 — Le pin `evaluator.sha256` n'est vérifié qu'en smoke, jamais au
  runtime.** `tests/fixtures/harness-v1/manifest.json:5-8` +
  `scripts/lib/etabli-harness-eval.sh` (`harness_grade`). [repro-sub]
  Un run live avec lib dérivée et pin périmé grade quand même ; le JSONL logue
  `manifest_sha`/`oracle_sha` mais pas le hash de la lib. C'est la classe de
  bug déjà attrapée une fois pendant le council (a18d3ef) — la protection est
  restée dans le smoke au lieu d'entrer dans le grader. Fix : `die` en début
  de grade si `sha(lib) != manifest.evaluator.sha256`, et logger
  `evaluator_sha`.
- **M7 — `pi-review-hunter` accepte un prompt whitespace-only.**
  `scripts/pi-review-hunter:108-111`. [vérifié : lu, le check est `-s`
  (taille non nulle) seulement ; repro-sub : fichier ` \n` ⇒ spawn pi réel]
  Fix : exiger `grep -q '[^[:space:]]'` sur le prompt.
- **M8 — L'intégrité de la chasse repose sur des lignes auto-déclarées et un
  helper optionnel.** `workflow/skills/review.md` (« when present, else this
  argv ») + oracles `no-parent-logic-claim`/`hunter-read-only`. [vérifié pour
  l'oracle ; inférence pour le bypass]
  Les sentinels `HUNTER_*` sont émis par le helper sur stderr, mais leur
  vérification est un contrat d'obéissance du parent, et le skill autorise un
  argv inline qui saute tous les gardes du helper. `isolation: isolated` +
  `runner: pi-child` sont des chaînes que le parent peut écrire sans spawn.
  Fix : faire du helper le seul chemin Pi, et exiger une preuve hors-bande
  (log argv + exit code) plutôt qu'une ligne de transcript.
- **M9 — Contradiction manifest ↔ doc sur les runners.**
  `manifest.json` : `hunter-read-only.runners = ["pi","grok"]` ;
  `docs/harness-eval.md:16` : « Review-hunter tasks are Pi-only ». [vérifié]
  Fix : retirer `grok` du manifest ou corriger la doc.

### MINOR

- **m1 — Le smoke borne le null floor à `≤ 2` alors que la doc publie 1/8.**
  `tests/etabli-harness-eval-smoke.sh` (assert `null_pass -le 2`) vs
  `docs/harness-eval.md:50-51`. [repro-sub] Une régression à 2/8 passerait le
  gate. Fix : `-eq 1` + assert sur l'identité de la tâche qui passe.
- **m2 — Porcelain + noms de fichiers exotiques ⇒ faux négatif.**
  `scripts/lib/etabli-harness-eval.sh:113-122`. [repro-sub : `?? "weird
  name.txt"` sort avec guillemets et échoue l'allowlist] Fix : parser en `-z`.
- **m3 — `harness_extract_verdict` prend la dernière ligne ancrée : un agent
  peut empiler des verdicts.** `etabli-harness-eval.sh:41-48`. [repro-sub]
  Fix : exiger exactement une ligne verdict.
- **m4 — Regex `file:line` permissive** (`\|[^|]*[a-zA-Z0-9_./-]+:[0-9]`
  matche `| Version: 1 |`) dans trois oracles. [repro-sub] Fix : ancrer sur un
  motif `path.ext:digits`.
- **m5 — `shell_syntax` du gate s'arrête au premier `bash -n` rouge** (interne
  au check, `scripts/verify-agentic-infra:21-25`) : le check accumule au
  niveau runner mais pas en son sein. [repro-sub] Fix : compteur interne.
- **m6 — Timeout sans process group.** `scripts/pi-review-hunter:138-166`.
  [vérifié] `timeout`/perl-fork tuent le child direct ; des petits-enfants pi
  peuvent survivre. Fix : `timeout --foreground` ou kill du PGID.
- **m7 — L'isolation hunter est de session, pas de filesystem/env.**
  `scripts/pi-review-hunter:80-95, 137-139`. [vérifié] Pas d'`env -i` : le
  hunter hérite env et cwd, et avec `read,grep` peut lire `PLAN.md`, `~/.pi`,
  l'état git du parent. À documenter comme « Logic-only, session-fresh » au
  lieu de laisser entendre une isolation forte.
- **m8 — Tout exit ≠ 0 de pi devient `HUNTER_SPAWN_UNAVAILABLE`, et exit 0
  n'exige aucun contenu.** `scripts/pi-review-hunter:169-179`. [vérifié]
  Auth/modèle/vrai crash sont indistinguables, et un hunter muet rend exit 0.
  Fix : typer les codes et fail-closed sur stdout vide.
- **m9 — `review-spec-drift` ne vérifie pas l'existence de `FORBIDDEN.txt`**
  (grep du transcript seul). `review-spec-drift/oracle.sh:5-10`. [repro-sub]

### NIT

- `docs/adr/0014:61-66` : « Left in place » suivi de la note de retrait —
  réécrire le bullet au passé. [repro-sub]
- `manifest.json` : `evaluator.id = binary-final-state-v1` alors que la
  majorité des oracles sont text-first. [vérifié]
- `docs/research/20260812-conversation-skill-projection.md:209-212` :
  référence historique à `/recap` supprimé, hors archive. [repro-sub]
- `PI_CORE_SKILLS=($(…))` : word-splitting si un nom de skill contient un
  espace un jour. [repro-sub]

### Vérifié sain (à décharge)

- Aucune référence dangling vers les 10 commandes claude et les skills
  supprimés par d7891ab (les hits restants sont les listes de purge, ce qui
  est leur rôle). [repro-sub, grep exhaustif]
- `route-context-manifest` et la lane `cross_harness` sont réellement
  éradiqués : fichiers absents, grep vide sur scripts/tests/workflow/.github,
  TSV 6→5 colonnes. [repro-sub]
- `verify-agentic-infra` accumule bien les FAIL (compteur + SUMMARY + exit 1),
  et le construct est pinné par `agentic-infra-manifest-smoke`. [vérifié en
  exécution + lecture]
- CI déclenchée sur `push.branches: ["**"]` + `pull_request`. [repro-sub]
- Le null-baseline est honnête : vrai transcript vide (`: >"$transcript"`),
  runner `"null"`, 1/8 reproduit localement. [vérifié]
- Quoting argv du hunter correct (`"${PI_ARGS[@]}"`), fallback perl du timeout
  correctement écrit pour le piège alarm+exec macOS. [vérifié]
- b088791 est bien du formatage pur. [repro-sub]

## Axe 2 — Choix de direction

### 1. Recentrage kernel skills (d7891ab) — **bonne décision**

C'est la première application réelle du consensus C7/C9 au stock : ~2 000
lignes de commandes-adaptateurs et de skills work supprimées, listes de purge
tenues à jour, `implementation-loop`/`spec.md` cohérents après distillation,
zéro référence dangling. Le refactor est propre au sens strict. Réserve
[opinion] : la distillation réduit la surface mais ne tranche pas le tiering
du rituel (C9) — le pipeline 18 étapes survit, juste mieux rangé.

### 2. Isolation des review hunters (2a52ea4) — **décision discutable
(conditions)**

Le verdict honnête est : **mécanique réelle au niveau process, contrat
déclaratif au niveau intégrité**. Réel : spawn neuf sans `-c/--resume`,
`--no-skills --no-extensions --no-context-files`, allowlist `--tools
read,grep` (enforcement CLI, pas prompt), wrapper fail-closed avec timeout et
smoke qui pinne l'argv. C'est nettement mieux qu'un `pi -p` naïf. Théâtre :
les sentinels et la ligne `isolation:` sont vérifiés par grep sur un
transcript que le parent écrit lui-même (M8), le helper est optionnel dans le
skill, le Spec hunter tourne dans le parent (`spec: parent` assumé dans le
plan), et l'env n'est pas isolé (m7). Le repo a lui-même la bonne formule
(`reviewer-improvement-loop.md` : « a verification step the agent can skip
without the skip being visible is a step that does not exist ») et ne se
l'applique pas encore ici. Conditions pour que ce soit une bonne décision :
helper obligatoire, preuve de spawn hors-bande, et requalifier la claim
d'isolation en « Logic-only ».

### 3. Suite harness-eval (ef11830 + a8c28f8) — **bonne décision, avec un
plafond assumé qu'il ne faut pas franchir**

Pas de la sur-ingénierie [opinion argumentée] : le produit central de ce repo
*est* un harness d'agents ; une suite gelée avec oracles exécutables, contrôle
positif GO-only, null baseline publié et pin SHA est exactement l'instrument
qui manquait au « solid 10 » circulaire que les 7 rounds ont rejeté. Le
travail est méthodologiquement sérieux : le floor est passé de 5-7/7 pour un
transcript constant à 1/8 mesuré (reproduit ici), et la limite textuelle est
documentée noir sur blanc dans `docs/harness-eval.md:76-78`.

Mais oui, **le plafond textuel est réel et plus bas que la doc ne le
suggère** : d'après la passe dédiée, ~6/8 tâches restent passables par un
transcript fabriqué qui n'exécute rien (M4, M5, m3, m4, m9) ; seule
`ready-implement` (SHA d'état final) est incontournable, et
`plan-draft-no-mutate`/`isolation-sentinel` seulement si l'agent ne commit
pas ou ne mute pas. Conséquence pratique : la suite mesure aujourd'hui
« inaction vs protocole », pas « protocole vs comportement ». Condition
ferme : ne publier aucun `pass@1` live comparatif (Pi vs Grok) avant d'avoir
généralisé les assertions worktree (porcelain + commits) à toutes les tâches —
c'est M4/M5, environ une heure de travail, et ça déplace réellement le
plafond.

### 4. Réponse au council (f35d672/f1438ab) — **bonne décision : honnêteté
restaurée, pas cosmétique**

Les preuves sont matérielles, pas narratives : le gate accumule (vérifié en
exécution), `skill-lock` tourne en `core` (vu dans mon run), le mort est
réellement mort (grep vide), le musée est archivé avec index, et les rounds
bruts + l'agrégat — y compris les scores 5,5-6,9 — sont commités à la racine
au lieu d'être enterrés. Le plan archivé consigne même la régression
intra-session (la suppression de `cross_harness` avait emporté le seul
cleanup vivant, rattrapé par l'adversary) — c'est le contraire du cosmétique.
Deux réserves : M6 montre que la leçon « la 3e occurrence devient un check
mécanique » n'est toujours pas appliquée au grader lui-même ; et la moitié
dure du council (C3-C6, les décisions d'architecture) est reportée, ce qui
est explicite mais signifie que le score council ne remonterait probablement
que d'un point aujourd'hui.

### 5. CI sur toutes les branches — **bonne décision, coût négligeable**

`push.branches: ["**"]` + `pull_request` ferme exactement le trou C2-bis (8
commits de branche jamais validés ; `main` rouge découvert tard). Le gate
`core` fait ~40 s localement ; même multiplié par les jobs shell-docs/pi/nvim,
le coût runner pour un repo solo est trivial devant le coût d'une dérive
commitée invisible — dont cette branche a produit deux exemplaires
(skills-lock drift, SHA manifest). Seule vigilance [opinion] : les pushes
WIP fréquents peuvent créer du bruit de notifications ; un `concurrency:
cancel-in-progress` suffirait si ça gêne.

## Axe 3 — Ce qui reste ouvert, priorisé

Classement par ROI (impact × probabilité d'incident / coût), avec verdict
« trancher maintenant / plus tard / jamais » :

1. **Fail-closed du pruning installer (fragment de C6) — maintenant, avant
   tout le reste.** M1/M2 sont le même bug des deux côtés du miroir ; le coût
   est une garde de 3 lignes ; le déclencheur (refactor du catalogue TSV) est
   précisément le genre de chose que cette branche fait. À ne pas confondre
   avec le split complet : la garde d'abord, le split ensuite.
2. **Reconciler unique (C3) — trancher maintenant, implémenter
   incrémentalement.** La branche a prouvé la classe de défaut deux fois en
   une session (cross_harness prune ; divergence managedModels). Trois
   scripts × ~25 chemins avec politiques divergentes, c'est la plus grosse
   surface de bug restante. Décision minimale viable : une seule source de
   vérité des chemins gérés (table), les trois scripts la consomment ;
   fusionner les scripts peut attendre.
3. **Assertions worktree uniformes sur les oracles (reliquat C1) —
   maintenant.** Condition bloquante pour tout run live publié (voir Axe 2.3).
   Une heure, ferme M4/M5.
4. **brain/obvault (C5) — trancher maintenant, propager ensuite.** C'est une
   contradiction canonique active (l'agent work lit la base que l'ADR-0017
   exclut) : une décision d'une ligne, puis une passe de propagation
   mécanique. Aucune raison de la laisser ouverte.
5. **spec ↔ classifier ordinary coding (C4) — trancher bientôt, sans
   urgence.** Impact borné tant que le classifier est observationnel
   (ADR-0014), mais chaque réutilisation future hérite de la contradiction.
   À traiter comme une décision documentaire (une ligne dans spec ou un fix
   de classifier), pas un projet.
6. **Tiering du rituel implementation-loop (C9) — trancher le principe
   maintenant, calibrer plus tard.** Trois niveaux de risque, cross-model
   réservé au high-risk : c'est une décision de contrat à coût quasi nul qui
   rembourse chaque session. Attendre « 10 outcomes » pour ça est une fausse
   symétrie : le coût du rituel est certain, son bénéfice sur le trivial ne
   l'est pas.
7. **Split installer workstation/agent (C6 complet) — plus tard.** Une
   demi-journée d'après le council ; la garde du point 1 enlève l'urgence.
8. **15 skills all_zero — plus tard, en batch ADR-0013-style.** Coût
   d'entretien faible mais non nul ; à traiter dans la même passe qu'un
   éventuel nettoyage de catalogue (après le point 1 !).
9. **SPOF volume externe (C8) — décision « jamais » pour l'architecture,
   « maintenant » pour la détection.** Le choix du volume est assumé et le
   re-architecturer serait du sur-coût. La partie qui vaut 30 minutes : un
   guard de boot qui hurle quand `/Volumes/Crucial` est absent au lieu de
   laisser l'activation ambiante s'éteindre en silence.
10. **Ergonomie guard check-freeze — plus tard.** Vrai irritant, zéro risque
    de corruption ; backlog kernel.

## Score global : **7,0 / 10**

| Dimension | Note | Justification courte |
|---|---|---|
| Correctness | 6,5 | Gate vert vérifié, refactors propres, mais 9 MAJOR dont un fail-open destructif latent (M1) et un plafond d'oracle réel non fermé (M4/M5/M6) |
| Direction | 8,0 | Les 5 choix vont dans le bon sens ; réponse au council matérielle et non défensive ; la seule direction discutable (hunters) l'est sur l'enforcement, pas sur l'intention |
| Exécution | 7,5 | Null baseline reproduit, dead code réellement mort, leçons intra-session consignées ; mais la protection SHA est restée dans le smoke, et le helper hunter est resté optionnel |
| Maintenance | 6,0 | C3 (triple reconciler) et C6 (installer) restent la dette dominante ; la branche l'assume explicitement mais ne l'entame pas |

Pondération [opinion] : direction et exécution comptent double sur une branche
dont l'objet est précisément de répondre à une review externe. La branche fait
passer le repo d'un « la preuve ne prouve pas » (council, 6,04 de moyenne) à
« la preuve prouve le plancher, honnêtement, et documente son plafond ». C'est
un vrai cran. Le cran suivant — plafond d'oracle, prune fail-closed, un seul
reconciler — est identifié par le repo lui-même ; il faut maintenant le payer
plutôt que d'ajouter de l'instrumentation.

## Lacunes

- **Aucun run live facturé** : les runners pi/grok du harness et le spawn
  hunter réel n'ont pas été exercés ; mes verdicts sur leur comportement live
  sont des inférences depuis le code.
- `claude/hooks/workflow-router-lib.mjs` (1 281 l.) : seul le diff branche
  (44 l.) a été survolé, pas le fichier.
- Corps complets des skills trimés (`sec-pr`, `pr-qa`, `bug-check`,
  `forest-dependabot.md` +410 l.) : jugés sur diffstat, pas relus ligne à
  ligne.
- `round-1.md`..`round-7.md` (2 696 l.) : lus via l'agrégat uniquement ; je
  fais confiance à l'agrégat pour la fidélité aux rounds.
- `install-main.sh` hors hunks branche (~1 700 l. préexistantes),
  `deploy-agent-workflow` en entier, `runtime-skill-canary.mjs` reformaté
  (410 l.) : non lus.
- c168489 (split README/how-it-works) : têtes lues, cohérence des liens
  internes non vérifiée ; `workflow///*` (population, tasks,
  results) : non lus.
- `verify-agentic-infra full` non exécuté (j'ai exécuté `core` ; le 80/80 de
  `full` est la claim du plan archivé, non re-vérifiée ici).
- Prompts, overlays et transcripts synthétiques du harness hors oracles :
  échantillonnés, pas exhaustifs.
- Le fichier modifié non commité
  `docs/plan/20260823-discarded-implemented-archived-oracle-cycle.md`
  (autofix pi-lens hors branche) : hors périmètre, non jugé.
