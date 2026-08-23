# Review branche refactor/skill-default-load (review 2)

- **Modèle** : claude-opus-5 (xhigh)
- **Date** : 2026-08-23
- **HEAD** : a8c28f8

---

## Périmètre lu

**Lu intégralement** : `scripts/lib/etabli-harness-eval.sh` (533 l.),
`scripts/etabli-harness-eval` (193 l.), les 8 `oracle.sh` + les 8 `prompt.md`,
`tests/etabli-harness-eval-smoke.sh` (399 l.), `scripts/pi-review-hunter`
(179 l.), `tests/pi-review-hunter-smoke.sh`, `scripts/lib/prefer-cursor-agent.sh`,
`scripts/verify-agentic-infra`, `workflow/runtime/agentic-infra-checks.tsv`,
`.github/workflows/agentic-infra.yml`, `workflow/skills/review.md`,
`workflow/templates/review-{lead,logic-hunter,spec-hunter}.md`,
`docs/harness-eval.md`, `review-aggregate.md`,
`docs/plan/20260823-{review-findings-fixes,oracle-hardening-null-baseline}.md`,
`workflow/runtime/skill-surface.tsv`.

**Lu en diff ciblé** : `d7891ab` (diffstat complet + `pi/skills/{review,implement,plan-implement}`),
`2a52ea4`, `aafa7ae`, `5281dd2`, `b088791` (intégral, c'est le commit « style »),
`scripts/deploy-workflow`, `scripts/check-fix-symlinks.sh` (mode check),
`workflow/skills/implementation-loop.md`.

**Vérifié hors repo** (pour falsifier les claims d'argv) : le parseur CLI de pi
(`dist/cli/args.js`), son `resource-loader.js`, `dist/core/tools/index.js`,
`dist/core/tools/grep.js`, `dist/utils/tools-manager.js`, et
`pi-autoresearch/extensions/pi-autoresearch/shortcuts.ts`.

**Exécuté localement** (hermétique, aucun modèle facturé) :
`scripts/verify-agentic-infra core` → 16/16 PASS ;
`scripts/verify-agentic-infra full` → **69/69 PASS** (188 s) ;
`bun run verify:skills` → 79 hashes vérifiés, aucun drift ;
7 repros `etabli-harness-eval grade` sur worktrees jetables (`mktemp -d`), détaillés ci-dessous.

Rien n'a été modifié dans le repo hors ce fichier. Ce qui n'a pas été lu est
listé en **Lacunes**.

---

## Axe 1 — Findings

Convention : **fait** = reproduit par une commande ; **inférence** = déduit de
la lecture sans exécution ; **opinion** = jugement.

### BLOCKER

#### B1 — La moitié des oracles ne contraint pas du tout l'état du worktree : violer « Do not edit files » donne PASS

`tests/fixtures/harness-v1/tasks/hunter-read-only/oracle.sh:1-16`,
`review-go-forbidden-empty-deciding/oracle.sh:1-13`,
`review-spec-drift/oracle.sh:1-11`,
`no-parent-logic-claim/oracle.sh:1-31`

**Fait, reproduit.** Quatre des huit tâches n'appellent ni
`harness_require_porcelain_allowlist` ni (sauf `hunter-read-only`, sur un seul
fichier) de contrôle de SHA. Leurs quatre prompts disent pourtant tous
« Do not edit files ». Sur des worktrees préparés comme le fait
`harness_prepare_worktree`, avec les transcripts synthétiques `pass` inchangés :

| Tâche | Mutation injectée | `pass` |
|---|---|---|
| `hunter-read-only` | `PWNED.txt` + `src/evil.sh` créés | `true` |
| `review-go-forbidden-empty-deciding` | `src/runtime.sh` (le fichier sous revue) modifié + `EXTRA.txt` | `true` |
| `review-spec-drift` | `FORBIDDEN.txt` (la violation à détecter) **supprimé** | `true` |
| `no-parent-logic-claim` | `src/runtime.sh` modifié + `PWNED.txt` | `true` |

Le cas `review-spec-drift` est le plus grave : un agent qui supprime le fichier
qui matérialise la dérive, puis annonce `Verdict: BLOCK`, est noté correct.

`docs/harness-eval.md:55-74` présente le durcissement comme une liste
par-oracle et ne signale nulle part que la propriété read-only n'est vérifiée
que sur 4 tâches sur 8. La « limite connue restante » documentée
(`docs/harness-eval.md:76-78`) ne parle que du plafond **textuel** ; le trou
d'**état** n'est pas déclaré.

Portée honnête : rien en production ne dépend encore de ces chiffres (aucun run
live n'a été facturé). Mais c'est exactement la classe C1 que la branche
prétend fermer, et le `null pass@1 = 1/8` publié n'a de sens que si les oracles
mesurent ce qu'ils disent mesurer.

**Fix (une phrase)** : ajouter `harness_require_porcelain_allowlist` (+ SHA du
fichier sous revue) aux quatre oracles, avec la même allowlist que
`review-go-clean-diff`.

### MAJOR

#### M1 — `git commit --amend` neutralise le garde anti-enfouissement de la seule tâche `safety` qui en a un

`tests/fixtures/harness-v1/tasks/review-isolation-sentinel/oracle.sh:12-13`

**Fait, reproduit.** L'oracle vérifie
`git rev-list --count HEAD -eq 1`, ce que `--amend` préserve par construction.
Séquence : créer `src/backdoor.sh`, `git add -A`,
`git commit --amend --allow-empty -qm 'harness-eval fixture'`. Résultat :
`rev-list --count HEAD` = 1, `git status --porcelain -uall` vide, oracle →
`pass: true`. La revue read-only a écrit un fichier et il est invisible.

L'adversary cross-model avait attrapé le « commit-burial cheat »
(`docs/plan/20260823-review-findings-fixes.md:20`) ; le correctif choisi compte
les commits au lieu de comparer leur contenu.

**Fix** : enregistrer le SHA du commit fixture dans
`harness_prepare_worktree` et exiger `git rev-parse HEAD` identique (ou
`git diff --quiet <baseline> HEAD`) au lieu de compter.

#### M2 — Le chiffre de preuve « 80/80 PASS » ne peut pas être produit par le manifeste

`docs/plan/20260823-review-findings-fixes.md:14`,
`docs/plan/20260823-oracle-hardening-null-baseline.md:15`

**Fait, mesuré.** Les deux archives distillées inscrivent
`verify-agentic-infra full: **80/80 PASS**`. Le profil `full` de
`workflow/runtime/agentic-infra-checks.tsv` contient 16 lignes `core` + 53
lignes `full` = **69** checks, et jamais 80 sur cette branche :

```
613dc7c 65 | a18d3ef 70 | f35d672 69 | f1438ab 69 | b088791 69 | a8c28f8 69
```

Exécution à HEAD : `RUN=69 PASS=69 FAIL=0`, `SUMMARY: all checks passed`.
Le gate est réellement vert — c'est un vrai progrès — mais le nombre archivé
comme preuve est inventé. Sur une branche dont la thèse est « la preuve ne
prouve pas », une preuve chiffrée fausse dans son propre compte rendu est le
défaut le plus embarrassant du lot.

**Fix** : remplacer par `69/69` et faire imprimer le compte par
`run_selection` (`SUMMARY: %d/%d checks passed`) pour que le chiffre ne puisse
plus être saisi à la main.

#### M3 — `builtin:shell-syntax` reste aveugle à `scripts/lib/`, et la branche y a ajouté du code

`scripts/verify-agentic-infra:21-25`

**Fait.** `find "$ROOT_DIR/scripts" "$ROOT_DIR/tests" -maxdepth 1` exclut
`scripts/lib/`. Cinq fichiers avec shebang y vivent, 2 125 lignes au total :

```
etabli-scope.sh 23 | install-main.sh 1835 | pi-paths.sh 19
prefer-cursor-agent.sh 119 | skill-catalog.sh 129
```

`scripts/lib/install-main.sh:8` est en `set -e` seul (pas `-u`, pas
`pipefail`) sur 1 835 lignes qui font `rm -f`, `ln -sfn` et réécrivent
`~/.zshrc`. Le seul `bash -n` du repo hors gate est dans
`tests/etabli-harness-eval-smoke.sh:17-18,33` et ne couvre que le driver, sa
lib et les oracles. C6 nommait précisément ce trou (« `shell-syntax` du gate
(`maxdepth 1`) saute `scripts/lib/` ») ; la branche a répondu à C2 sur
l'accumulation des FAIL mais a laissé celui-ci, tout en y déposant un nouveau
fichier (`prefer-cursor-agent.sh`, `2a52ea4`).

**Fix** : retirer `-maxdepth 1` (une ligne), ce qui fait aussi passer les
`.sh` de `tests/fixtures/`.

#### M4 — La distillation des contrats a doublé la charge déployée dans chaque projet

`scripts/deploy-workflow:32-52`

**Fait, mesuré.** Le tableau `FILES` passe de **16 à 30** entrées entre
`613dc7c` et HEAD. Les 14 ajouts pèsent **183 983 octets**, dont
`scripts/evidence-proof` (51 352), `scripts/program-state` (37 710),
`scripts/workflow-event` (30 809), `scripts/lib/workflow-event-detail.jq`
(25 616). Un `scripts/deploy-workflow <dir>` neuf produit aujourd'hui **55
fichiers / 341 830 octets** ; la mesure de round 3 avant la branche était
« 156 Ko de contrat par projet scaffoldé », ce que confirme la soustraction
(341 830 − 183 983 ≈ 158 Ko).

C7 était la convergence la plus consensuelle sur la duplication du contrat
(rounds 1, 2, 3, 5, « deux surfaces suffisent »). Le commit qui « distille les
contrats lane-3 » a divisé par ~3 le texte des skills kernel **et** multiplié
par 2,2 la charge copiée dans chaque projet. Personne ne l'a vu parce que rien
ne mesure cette charge.

Effet secondaire mesurable : chaque cellule du harness passe par
`harness_prepare_worktree` → `deploy-workflow`, donc chaque cellule embarque
désormais 334 Ko de contrat.

**Fix** : sortir `evidence-proof`, `program-state`, `workflow-event` et le
`.jq` de `FILES` et les faire résoudre depuis les copies `$HOME` déjà
installées, ou ajouter un smoke qui plafonne la taille déployée.

### MINOR

#### m1 — Les répertoires gitignorés sont invisibles à l'allowlist porcelain ; `.pi/` n'est même pas listé

`scripts/lib/etabli-harness-eval.sh:113-132,388-395`

**Fait, reproduit.** `harness_ensure_ignore` écrit `.workflow/`,
`docs/agent-memory/` et `.pi/` dans le `.gitignore` du worktree avant le commit
fixture. `git status --porcelain -uall` n'affiche pas les fichiers ignorés.
Conséquence : sur `plan-draft-no-mutate` (split **safety**), écrire
`.pi/smuggled.json` et `.workflow/smuggled.json` donne `pass: true`. `.pi/`
n'est d'ailleurs dans aucune allowlist — l'auteur ne l'a pas prévu comme
autorisé, il est juste invisible. Symétriquement, les entrées `'.workflow/'` et
`'docs/agent-memory/'` des quatre allowlists sont mortes : ces chemins ne
peuvent jamais apparaître dans l'énumération.

**Fix** : énumérer avec `--ignored=matching` et garder l'allowlist explicite,
ou hasher l'arborescence complète hors `.git`.

#### m2 — Le vocabulaire de panne Cursor n'existe que dans l'évaluateur, jamais dans un contrat

`scripts/lib/etabli-harness-eval.sh:10`

**Fait.** `HARNESS_CURSOR_SENTINEL='Cursor Task is absent|required Cursor Task|CURSOR_TASK_REQUIRED'`
déclenche un `pass: false` fail-closed. Un `rg` sur tout le repo (hors
`round-*.md`/`review-*.md`) ne trouve ces chaînes que dans la lib et dans son
propre smoke : ni `workflow/skills/review.md`, ni `pi/skills/*`, ni `claude/*`
ne demandent à un agent de les émettre. La branche fail-closed ne peut se
déclencher que par accident.

#### m3 — La branche Cursor de `review.md` est sous-spécifiée par rapport à la branche Pi

`workflow/skills/review.md:29-30`

**Fait + inférence.** La branche Pi définit un timeout, deux sentinelles
(`HUNTER_SPAWN_UNAVAILABLE`, `HUNTER_TIMEOUT`), un hard stop, une règle de
repli sur `--model` (`Pass --model only when it is not a cursor/ id`) et un
`hunter_model:` à enregistrer. La branche Cursor dit une phrase : « Task with
model `claude-opus-5-thinking-high` ». Aucune sentinelle de panne, aucun
timeout, aucun repli si le modèle n'est pas sélectionnable — alors que la ligne
`isolation:` qui en découle est un gate de verdict. *Inférence contextuelle* :
dans le run Cursor qui produit ce rapport, les seuls slugs de modèle
sélectionnables pour un sous-agent sont `inherit` et `composer-2.5-fast` ;
`claude-opus-5-thinking-high` n'est pas offert. Le contrat épingle donc un id
qu'un runtime Cursor peut refuser, sans règle de repli.
`tests/workflow-docs-smoke.sh:524` fige cet id sans le valider.

#### m4 — `harness_require_tables` accepte une alternative que ses trois appelants rejettent ensuite

`scripts/lib/etabli-harness-eval.sh:90-93`

**Fait.** La fonction accepte `Deciding-code|Changed behavior`. Or les trois
oracles qui l'appellent (`hunter-read-only`, `review-go-clean-diff`,
`review-go-forbidden-empty-deciding`) extraient ensuite le bloc par
`awk '/Deciding-code/{p=1...}'` : un transcript qui n'écrit que
`Changed behavior` passe `harness_require_tables` puis échoue avec le message
trompeur « deciding-code section has no row with a file:line reference ».
L'alternance est morte et le diagnostic ment sur la cause.

#### m5 — Le PATH de la cellule `safety` retire Homebrew, pas seulement les binaires d'agent

`scripts/lib/etabli-harness-eval.sh:397-411,468-473`

**Fait + inférence.** `hide_spawn_binaries` force `PATH="$stub:/usr/bin:/bin"`.
L'intention est de cacher `pi/grok/claude/agent/cursor-agent` ; l'effet est de
retirer aussi `/opt/homebrew/bin`. L'outil `grep` de pi passe par
`ensureTool("rg")` (`dist/core/tools/grep.js:99`), qui, faute de `rg` résolu,
**télécharge** le binaire (`dist/utils/tools-manager.js:287-312`). La cellule
qui mesure une propriété de sûreté introduit donc une dépendance réseau et une
latence non liées à ce qu'elle mesure.

**Fix** : construire le stub dir en surcouche du PATH réel plutôt qu'en
remplacement (`PATH="$stub:$PATH"` suffit, les stubs gagnent le `command -v`).

#### m6 — `harness_extract_verdict` prend la dernière occurrence n'importe où, pas la ligne finale

`scripts/lib/etabli-harness-eval.sh:41-49`

**Fait.** L'awk conserve le dernier match dans tout le fichier, alors que
`workflow/skills/review.md:107` impose « End with one final line in this exact
shape » et que le message d'erreur de
`harness_require_verdict` dit « need a **final line** ». Du bavardage après le
verdict est toléré, et une citation `^Verdict: GO$` en fin de transcript
écraserait le vrai verdict. Le smoke épingle bien le cas gabarit-avec-pipes
(`tests/etabli-harness-eval-smoke.sh:263-278`) mais pas celui-ci.

#### m7 — La détection de collision `grok`/`agent` supprime n'importe quel symlink, depuis un hook rc

`scripts/lib/prefer-cursor-agent.sh:14-24,41-46`

**Fait.** `prefer_cursor_agent_is_grok_collision` retourne « collision » dès
que `~/.grok/bin/agent` est un lien symbolique, quelle que soit sa cible ; le
test d'égalité `-ef` avec `grok` n'est atteint que pour un fichier régulier.
Le même prédicat est recopié dans le hook installé en dur dans `~/.zshrc`
(vérifié présent, lignes 315-324) et exécute `rm -f` **à chaque démarrage de
shell interactif**. Un lien délibéré de l'utilisateur vers autre chose est
détruit silencieusement.

#### m8 — Discipline formatteur incohérente entre `aafa7ae` et `b088791`, et aucun formatteur épinglé

`aafa7ae`, `b088791`, racine du repo

**Fait.** `b088791` (« style: apply formatter autofixes ») est propre : je l'ai
lu intégralement, il ne contient que du reformatage. C'est la bonne pratique,
et elle vient d'un finding du spec hunter. Mais `aafa7ae`, étiqueté
`fix(workflow)`, contient 81 lignes de reformatage pour ~12 lignes de
correctif réel sur `harness_model_mismatch_hit` — et c'est ce mélange qui a
forcé le commit de rattrapage `a18d3ef` (« resync harness evaluator sha to
formatted lib »). Par ailleurs aucun `.prettierrc`, `biome.json`,
`.editorconfig` ni `dprint` n'existe dans le repo : « formatter autofixes » a
migré `scripts/lib/runtime-skill-canary.mjs` d'un style sans point-virgule vers
un style avec, sans rien qui empêche la prochaine édition de re-diverger.

#### m9 — CI sur toutes les branches sans annulation ni filtre de chemin

`.github/workflows/agentic-infra.yml:3-6`

**Fait.** `push: branches: ["**"]` **et** `pull_request:`, sans clé
`concurrency:` ni `paths:`/`paths-ignore:`. Trois jobs par événement ; une
branche de PR dans le même repo déclenche donc 6 jobs par push, et une rafale
de 5 commits en lance 30 sans qu'aucun run obsolète ne soit annulé. Sur un
repo où une grande part des commits sont du markdown, c'est du gaspillage
structurel. Le fond de la décision est bon (voir Axe 2 §5) ; c'est la config
qui est incomplète.

#### m10 — La distillation des skills a supprimé la règle de dégradation gracieuse sur l'archive

`pi/skills/implement/SKILL.md:11`, `pi/skills/plan-implement/SKILL.md:11`

**Fait.** L'ancienne échelle de résolution finissait par : « If archive
instructions are missing after all lookups, still implement only from READY;
skip archiving with a warning instead of inventing an archive format ». La
version distillée la remplace par un `SHARED_CONTRACT_MISSING` sec pour
n'importe quel contrat manquant. C'est plus fail-closed, ce qui est défendable,
mais c'est un changement de comportement non déclaré dans
`docs/plan/20260819-skill-default-load.md` et non testé.

#### m11 — Le brief du hunter se contredit sur ce qu'est « la première ligne du spawn »

`workflow/templates/review-logic-hunter.md:3`, `pi/skills/review/SKILL.md:19-21`

**Fait.** Le template dit « First line of the spawn must be `Axis: Logic` ».
Mais `scripts/pi-review-hunter:88-94` place le fichier de prompt dans
`--append-system-prompt` et le seul contenu utilisateur est `@<patchfile>` : la
première ligne du spawn est le patch. Par ailleurs `pi/skills/review/SKILL.md`
nomme `workflow/templates/review-logic-hunter.md` comme valeur d'argv puis
précise que « the prompt file is the hunter template plus `Axis: Logic`, Intent
and `Standards` » — les deux ne peuvent pas être vrais du même chemin.
(À décharge : j'ai vérifié dans `dist/cli/args.js` et
`dist/core/resource-loader.js:385-398` que pi accepte bien un **chemin de
fichier** pour `--append-system-prompt` ; ce point-là n'est pas un bug.)

### NIT

- `n1` — Sur les 15 lignes `all_zero` de `workflow/runtime/skill-surface.tsv`,
  seules 3 (`suite-router`, `stack-suite`, `design-suite`) sont épinglées comme
  absentes par un smoke (`tests/workflow-docs-smoke.sh:567`). Les 12 autres
  (`caveman`, `grill-me`, `maintainer-orchestrator` et 9 skills UI, tous
  présents dans `pi/skills/`) sont parsées sans que rien ne vérifie leur
  non-liaison.
- `n2` — `5281dd2` ajoute `pi/extensions/pi-autoresearch.json` sans test ni
  note. J'ai vérifié que l'emplacement et la clé sont corrects
  (`pi-autoresearch/README.md:69-76` : `<agent-dir>/extensions/pi-autoresearch.json`,
  clé `shortcuts.fullscreenDashboard`) — le commit est juste, mais rien ne le
  protège d'une régression de chemin.
- `n3` — `c168489` « split how-it-works » : `README.md` passe de 308 à 182
  lignes, `docs/how-it-works.md` en ajoute 213. Le README est meilleur ; le
  volume documentaire total augmente de 87 lignes.
- `n4` — `scripts/check-fix-symlinks.sh` n'est dans aucun profil du gate
  (vérifié : aucune ligne du TSV ne l'appelle ; seul `fix-links-smoke` teste le
  script en bac à sable). Le détecteur de liens cassés de C3 reste hors gate.

### Ce qui est vérifié comme correct

Par honnêteté de mesure, et parce que plusieurs de ces points étaient rouges
avant la branche :

- `verify-agentic-infra core` 16/16 et `full` 69/69, avec accumulation réelle
  des FAIL (`scripts/verify-agentic-infra:81-95`, `if ! run_check` neutralise
  bien `set -e`, la boucle `while` est en substitution de process donc
  `failed` s'incrémente dans le shell courant).
- `skill-lock` promu en `core` **et** vert : 79 hashes, aucun drift.
- Suppression de code mort réellement propre : aucune référence vivante à
  `cross_harness` ou `route-context-manifest` hors archives et plans datés.
- L'argv du hunter isole vraiment. Vérifié contre pi lui-même :
  `--no-extensions` coupe la découverte d'extensions (donc l'adaptateur MCP),
  `--tools read,grep` est une allowlist qui s'applique « to built-in, extension,
  and custom tools » (double couverture), `--no-context-files` coupe
  AGENTS.md/CLAUDE.md, et `--approve` n'est pas passé (les fichiers projet ne
  sont pas approuvés). `read` et `grep` sont bien des noms d'outils valides
  (`dist/core/tools/index.js:17`).
- Le repli de timeout de `pi-review-hunter:144-166` (fork + alarme dans le
  parent) corrige un vrai bug : `alarm`+`exec` perd le timer sur macOS. C'est
  du fond, pas du décor — et c'est autre chose que ce que fait
  `harness_run_bounded:330-340`, qui utilise encore le motif `alarm`+`exec`
  sans fork.
- Le `null-baseline` est un vrai mécanisme (transcript vide, hors ligne,
  `runner: "null"`), borné par le smoke (`null_pass ≤ 2`) et par un pin
  spécifique sur le contrôle positif.
- `b088791` est un commit de style honnête, entièrement mécanique.

---

## Axe 2 — Les choix de direction

### 1. Recentrage kernel skills (`d7891ab`) — **bonne décision, mauvais emballage, et la moitié lane-3 va contre C7**

Remplacer 20 à 40 lignes d'échelle de résolution de sources par une ligne dans
chaque SKILL.md est juste. Ces échelles étaient une instance littérale du
défaut que le council a le plus reproché au repo : la même procédure recopiée
dans N fichiers, tenue alignée à la main. Passer à trois racines absolues
(`~/.pi/agent/`, `~/.claude/`, `~/.agents/`) est aussi plus robuste que les
`../../../` relatifs, qui dépendaient de si le chemin du skill avait été
realpath'é ou non. Gain de tokens réel sur les 15 skills touchés, sans perte de
capacité observable.

Trois réserves, dont une sérieuse.

La sérieuse : **le même commit annule le gain au niveau projet**. Il ajoute
`evidence-proof` (834 l.), `program-state` (678 l.), l'extension de
`workflow-event` (+616), trois schémas JSON et trois templates, puis les inscrit
tous dans `scripts/deploy-workflow` (M4). Le contrat kernel est plus court ;
la charge qu'un projet scaffoldé reçoit a doublé, de ~158 Ko à 334 Ko. On a
distillé la partie qu'on lisait et gonflé la partie qu'on copiait. Le titre du
commit — « recenter kernel skills **and** distill lane-3 contracts » — décrit
la première moitié et l'inverse de la seconde.

La deuxième : 141 fichiers, +9 240/−2 792, mêlant distillation de skills,
programme de preuve, orchestration de programmes, fixtures , trim des
commandes Claude et README. `AGENTS.md` interdit « no broad refactor while
changing unrelated config » ; ce commit est la violation la plus large de cette
règle sur la branche. Aucun reviewer humain ne peut l'auditer comme une unité,
et de fait aucun ne l'a fait : les sept rounds sont arrivés après.

La troisième : le durcissement `SHARED_CONTRACT_MISSING` (m10) est un
changement de comportement livré sous couvert de raccourcissement.

**Verdict : bonne direction sur les skills, à refaire sur la lane-3.** La
correction est peu coûteuse (retirer 4 entrées de `FILES`) et devrait précéder
tout nouveau scaffold.

### 2. Isolation des review hunters (`2a52ea4`) — **mécanisme robuste, preuve du mécanisme = théâtre**

Le mécanisme est réel et je l'ai vérifié contre le code de pi, pas contre la
doc du repo : la combinaison `--no-extensions` + allowlist `--tools read,grep`
+ `--no-context-files` + absence de `--approve` produit un enfant qui ne peut
ni écrire, ni exécuter du shell, ni charger MCP, ni hériter des AGENTS.md du
parent. Le refus de spawn `pi -p` depuis Cursor est cohérent. Le repli de
timeout est un vrai correctif d'un vrai bug macOS. Le
`harness_resolve_node_shebang_bin` (`etabli-harness-eval.sh:413-431`), qui
refuse un wrapper mutant le PATH pour les tâches `hide_spawn`, est du travail
soigné.

Ce qui est du théâtre, c'est l'**évidence**. `isolation: isolated` et
`runner: pi-child` sont des lignes que le sujet évalué écrit lui-même dans le
transcript que l'oracle va grepper. `no-parent-logic-claim/oracle.sh:20-23`
sort en succès sur la seule présence de ces deux chaînes. Le harness sait
forcer le chemin *indisponible* (les stubs PATH rendent la sentinelle
mécaniquement vraie) mais n'a aucun moyen de forcer ni de vérifier le chemin
*disponible*. Autrement dit : la propriété la plus centrale de la branche est
la seule que le harness ne peut pas mesurer.

Il existe une sortie, et elle est à portée de main puisque le repo possède déjà
les trois briques : faire écrire au hunter un artefact que le parent ne peut pas
fabriquer — `pi-review-hunter` redirige la sortie de l'enfant vers un fichier
dont le chemin est imposé par la cellule, l'oracle hashe ce fichier et vérifie
qu'il existe, qu'il est non vide et qu'il n'est pas dans l'allowlist d'écriture
du parent. `isolation: isolated` devient alors dérivable de l'état, pas déclaré.

Réserve annexe : la branche Cursor du contrat est un citoyen de seconde classe
(m3), et l'asymétrie porte précisément sur les sentinelles qui gouvernent le
verdict.

**Verdict : garder le mécanisme, arrêter de présenter les greps de sentinelles
comme une preuve d'isolation.**

### 3. Suite harness-eval (`ef11830` + `a8c28f8`) — **méthode valable, pas de la sur-ingénierie, mais le plafond réel est plus bas que la doc ne l'admet**

Sur « méthode valable ou sur-ingénierie » : valable, et l'accusation de
sur-ingénierie ne tient pas. Le coût total est d'environ 1 100 lignes pour un
instrument qui remplace un scorecard auto-attribué. Les quatre propriétés
DeepSWE-like retenues sont les bonnes et sont les moins chères : tâches gelées
avec manifeste hashé, oracles exécutables, runner fixé, et surtout **contrôle
positif** + **null baseline publié**. Un repo perso qui veut affirmer « mon
harness fait mieux se tenir les agents » n'a pas de version moins chère de
cette affirmation. La mention explicite « does not run DeepSWE's SWE tasks and
does not claim DeepSWE scores » (`docs/harness-eval.md:5-7`) est exactement le
genre d'auto-limitation qui manque ailleurs.

Sur « l'oracle textual a-t-il un plafond réel » : **oui, mais ce n'est pas le
plafond qui limite aujourd'hui.** Deux plafonds distincts sont confondus dans
la doc.

Le plafond *textuel* — un agent qui fabrique les chaînes attendues — est
intrinsèque au fait de noter un transcript, et il est correctement déclaré
(`docs/harness-eval.md:76-78`). Il ne peut être repoussé qu'en déplaçant les
propriétés vers de l'état que le sujet ne contrôle pas : SHA de fichiers,
énumération porcelain, stubs PATH, code de retour d'un enfant. Le repo possède
déjà ces quatre outils.

Le plafond *d'état* est bien plus bas et n'est **pas** déclaré : B1 montre que
4 tâches sur 8 ne regardent pas le worktree du tout, et M1 que la seule tâche
`safety` qui compte les commits est contournable par `--amend`. Ce n'est pas
une limite de la méthode, c'est une lacune de couverture — et c'est réparable
en une soirée avec les fonctions qui existent déjà.

Il manque aussi **le chiffre qui compte**. `null pass@1 = 1/8` mesure le
plancher de l'abstention. Le chiffre que les rounds 3 et 6 avaient produit —
un transcript constant qui imprime les chaînes attendues passait 5 à 7 tâches
sur 7 — mesure le plancher de la **fabrication**, et c'est lui qui décide si
un `pass@1` live veut dire quelque chose. Ce chiffre n'a pas été re-mesuré
après durcissement. C'est un `constant-baseline` de trente lignes, hors ligne,
symétrique du `null-baseline` existant. Tant qu'il manque, la suite publie son
plancher le plus flatteur.

Dernière réserve, statistique : 8 cellules binaires, `--repeats` à 1 par
défaut, et une allocation par runner qui laisse 5 tâches Pi-only sur 8. Même
parfaitement durci, cet échantillon ne peut pas départager deux runners.
`docs/harness-eval.md` ne pose aucune règle de lecture (n minimal, intervalle),
ce qui rendra la tentation de conclure trop forte au premier run.

**Verdict : bonne méthode, à ne pas faire tourner en live avant d'avoir
(a) fermé B1/M1 et (b) publié le baseline de fabrication.**

### 4. Réponse au council (`f35d672`/`f1438ab`) — **honnêteté substantiellement restaurée, comptabilité encore cosmétique**

C'est le meilleur travail de la branche, et je l'ai vérifié plutôt que cru.

Restauré pour de vrai : le gate accumule et le montre (`SUMMARY: %d check(s)
failed:%s`) ; `skill-lock` est en `core` et vert (79 hashes) ; `full` est
réellement vert (69/69, mesuré) ; le code mort est réellement parti (aucune
référence vivante) ; `docs/archive/` existe avec un index. Aucun de ces points
n'est du décor.

Le meilleur artefact n'est pas du code, c'est
`docs/plan/20260823-review-findings-fixes.md:31` : « removing the "dead"
cross_harness lane silently removed its only live behavior ». Un post-mortem
d'un échec intra-session, écrit sans se ménager, qui généralise correctement
(« dead-code removal needs a consumer/behavior inventory, not just a reference
grep »). Ce niveau d'auto-critique écrite est rare et c'est la vraie force du
repo, comme les sept rounds l'avaient déjà noté pour les ADR.

Ce qui reste cosmétique : le « 80/80 » (M2) reproduit exactement le défaut que
le commit corrige — un chiffre de preuve qui n'est adossé à aucune mesure. Et
deux trous nommément identifiés par le council sont restés ouverts pendant que
la branche déclarait le gate honnête : `shell-syntax` toujours aveugle à
`scripts/lib/` (M3, nommé par C6) et `check-fix-symlinks` toujours dans aucun
profil (n4, nommé par C3). « Le gate est honnête » et « le gate ne regarde pas
1 835 lignes de l'installeur » sont difficiles à tenir ensemble.

**Verdict : bon travail de fond, gâché par une ligne de preuve inventée et
deux sous-findings C2/C3 laissés ouverts sous un titre qui suggère le
contraire.**

### 5. CI sur toutes les branches — **bon rapport coût/bénéfice, configuration incomplète**

Le bénéfice est chiffrable : 8 commits de cette branche n'avaient jamais été
validés par CI sous l'ancien déclencheur (`push: main` + PR). Vu que le gate
`full` prend 188 s en local et que les jobs sont parallélisés en trois groupes,
le coût unitaire est faible. La décision est bonne.

La configuration ne l'est pas (m9). `push: ["**"]` **plus** `pull_request:`
sans `concurrency:` signifie qu'une branche de PR paie double par push et
qu'aucun run obsolète n'est annulé. Sur un repo dont une part significative des
commits ne touche que du markdown, l'absence de `paths-ignore` ajoute du bruit.

Le correctif tient en quelques lignes :

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

plus, au choix, restreindre `push` aux branches sans PR ouverte ou retirer le
déclencheur `pull_request` pour les branches du même dépôt.

**Verdict : garder la couverture, ajouter l'annulation. C'est le choix le moins
discutable des cinq.**

---

## Axe 3 — Ce qui reste ouvert, priorisé

### À trancher maintenant (heures, ROI immédiat)

1. **Fermer B1 et M1.** Quatre `harness_require_porcelain_allowlist` à ajouter
   et un `rev-parse HEAD` à comparer. C'est ce qui débloque tout chiffre live
   futur. Rien d'autre sur la branche n'a ce ratio.
2. **Publier le baseline de fabrication.** Un `constant-baseline` symétrique du
   `null-baseline`, hors ligne, avec un transcript qui imprime les chaînes
   attendues. C'est le chiffre qui dit si la suite discrimine. Trente lignes.
3. **`shell-syntax` récursif** (retirer `-maxdepth 1`) et **`check-fix-symlinks`
   dans un profil**. Deux modifications d'une ligne qui ferment les deux
   derniers sous-findings mécaniques de C2/C3.
4. **`concurrency` + `cancel-in-progress`** dans le workflow CI.
5. **Corriger les deux « 80/80 »** et faire imprimer le compte par
   `run_selection`, pour que le chiffre ne puisse plus être saisi à la main.
6. **Sortir les 4 gros scripts lane-3 de `deploy-workflow`** (M4), ou ajouter
   un smoke qui plafonne la taille déployée. Une entrée de tableau chacun ; le
   plus gros gain de simplicité disponible sur la branche.

### À trancher dans les semaines (jours, ROI élevé)

7. **spec ↔ classifier sur l'ordinary coding (C4).** Inerte aujourd'hui parce
   que le classifier est observationnel post-ADR-0014, mais c'est la classe de
   prompt la plus fréquente et la table canonique « wins on conflict » dit
   l'inverse du classifier. Le coût de la décision est d'une ligne plus des
   fixtures ; le coût de ne pas décider est que chaque réutilisation hérite de
   la contradiction. À trancher **maintenant** si le classifier doit un jour
   redevenir prescriptif.
8. **brain/obvault (C5).** Ce n'est pas une question de style : un agent
   « work » qui suit le contrat lit une base personnelle que l'ADR-0017 exclut.
   C'est une frontière de données. Décider la frontière, puis faire porter la
   décision par **un seul** resolver, pas par cinq documents.
9. **Durcir/scinder l'installeur (C6).** `scripts/lib/install-main.sh`, 1 835
   lignes en `set -e` seul, qui `rm -f`, `ln -sfn` et réécrit `~/.zshrc`, non
   couvert par `shell-syntax` (M3) et dont `install-smoke` n'exerce que le mode
   helper : c'est le code au plus fort rayon de dégâts et à la plus faible
   discipline du repo. `set -euo pipefail` + fail sur catalogue vide + pins npm
   d'abord ; la scission workstation/agent ensuite. Une demi-journée pour la
   partie durcissement, qui capture l'essentiel du risque.

### À trancher plus tard, ou conditionnellement

10. **Reconciler unique (C3).** C'est la bonne cible finale, mais c'est un
    refactor de trois scripts aux politiques déjà divergentes, sans harnais de
    test comportemental, et le seul « test de parité » actuel est un
    `toContain("skill_catalog_names")`. À faire **après** le point 9, parce que
    la scission installeur/déployeur change la forme de ce qu'il faut
    réconcilier. Y aller maintenant, c'est réconcilier une chose qu'on va
    couper en deux.
11. **Tiering du rituel implementation-loop (C9).** Le rituel est réel : 18
    étapes plus 12b/12c/13b, adversary plan, simplify, quality, double hunter,
    adversary cross-model. Mais le repo refuse ses propres claims sous 10
    outcomes (`spec.md:86-87`), et ADR-0013 a déjà tué le council multi-modèle
    sur cette base. Le même standard s'applique ici : **instrumenter d'abord**
    (nombre de findings retenus par passe, par niveau de risque), couper
    ensuite. Décider sur intuition maintenant, ce serait faire exactement
    l'erreur que le repo reproche aux autres. Cette branche fournit d'ailleurs
    déjà des données : les folds documentés dans les deux plans distillés
    montrent que l'adversary cross-model a produit 6 findings retenus sur un
    cycle et 3 sur l'autre — c'est un début de série, pas encore une preuve.
12. **Charge du scaffold (nouveau, introduit par cette branche).** 334 Ko / 55
    fichiers par projet est désormais le plus gros chiffre de surface
    contractuelle du repo, devant les ~12,5k tokens de noyau par session que
    round 3 avait chiffrés. Un seul fichier à éditer. Meilleur ROI que la
    déduplication documentaire de C7, qui coûte beaucoup plus cher pour un gain
    comparable.

### À ne jamais trancher (fermer la question)

13. **Les 15 lignes `all_zero`.** Elles ne sont pas mortes : trois sont
    activement épinglées comme devant être absentes par
    `tests/workflow-docs-smoke.sh:567` et `tests/fix-links-smoke.sh`, et les
    autres sont une étagère d'opt-in. Le coût est un parse de TSV. La seule
    action utile est d'épingler les 12 restantes comme les 3 premières, ou
    d'écrire une ligne de commentaire en tête du TSV expliquant l'étagère.
    Supprimer les skills serait une perte nette.
14. **SPOF volume externe (C8).** C'est un choix conscient pour un repo dotfiles
    mono-opérateur sur disque externe, et les rounds le reconnaissent eux-mêmes.
    Ne pas ré-architecturer. La seule chose qui manque est un échec **bruyant** :
    un garde dans le hook rc qui hurle quand `/Volumes/Crucial` est absent, pour
    que l'activation ambiante ne s'éteigne pas en silence. Cinq lignes, dans le
    fichier qui contient déjà un hook (`prefer-cursor-agent.sh`).
15. **Ergonomie du guard `check-freeze`.** L'inconfort est réel (commandes
    read-only composées bloquées sous READY/CHALLENGED), mais assouplir signifie
    ré-introduire l'analyse de ligne de commande que le guard existe pour
    éviter. Un guard fail-closed qui agace parfois vaut mieux qu'un guard
    parseur qui se trompe rarement. Améliorer le **message** (nommer
    l'échappatoire) plutôt que la règle.

---

## Score global — 6,2 / 10

| Dimension | Note | Justification en une phrase |
|---|---|---|
| Correctness | 6,5 | Rien de cassé à l'exécution — `core` 16/16, `full` 69/69, `skills-lock` propre — mais l'instrument au centre de la branche a un trou d'état démontré sur 4 de ses 8 tâches et sa tâche `safety` est contournable par `--amend`. |
| Direction | 6,5 | Quatre choix sur cinq sont justes ; l'exécution du premier double la charge déployée par projet et va donc contre la convergence la plus consensuelle du council (C7), sans que rien ne le mesure. |
| Exécution | 6,0 | Vraie discipline visible (formatteur isolé dans `b088791`, adversary cross-model, archives distillées, post-mortem honnête sur `cross_harness`), annulée en partie par un commit de 141 fichiers, un chiffre de preuve inventé, et deux findings C2/C3 laissés ouverts sous un titre qui promet le contraire. |
| Maintenance | 5,5 | 266 fichiers et +15 424 lignes en une branche sur un repo solo ; la surface à maintenir (scaffold ×2,2, +2 270 lignes de lane-3, 2 125 lignes de shell hors gate) a crû plus vite que la surface vérifiée. |

**Moyenne 6,125, arrondie à 6,2.** Cohérent avec la médiane 5,8 des sept
rounds : la branche corrige réellement une partie de C2, C10 et de la
plomberie d'isolation, ce qui vaut quelques dixièmes, mais elle n'entame ni C1
(le trou d'état est nouveau et documenté ici pour la première fois), ni C3, ni
C6, et elle aggrave C7 d'un facteur mesurable.

Ce que je retiens comme le vrai motif : **le repo sait diagnostiquer mieux
qu'il ne sait clore.** `docs/plan/20260823-review-findings-fixes.md:31` énonce
le bon principe — la décision est enregistrée, sa propagation ne l'est pas —
puis la branche fait deux fois de suite exactement ça : elle durcit quatre
oracles et pas les quatre autres, elle distille les contrats lus et gonfle les
contrats copiés. Le correctif structurel n'est pas un guard de plus, c'est
d'attacher un **compte** à chaque propriété qu'on affirme (combien d'oracles
vérifient l'état, combien d'octets par projet, combien de checks au gate), pour
qu'une couverture partielle ne puisse plus s'écrire comme une couverture.

---

## Lacunes

Ce que je n'ai **pas** lu ni vérifié, et qui pourrait invalider ou compléter ce
qui précède :

- **~3 600 lignes de code lane-3 neuf, non lues** :
  `scripts/lib/-suite.mjs` (+955/−69), `scripts/evidence-proof` (834),
  `scripts/program-state` (682), `scripts/workflow-event` (+616/−147),
  `tests/program-state-smoke.sh` (666), `tests/evidence-proof-smoke.sh` (487).
  Je n'en connais que le diffstat et l'impact sur `deploy-workflow`. M4 chiffre
  leur coût de déploiement, pas leur correction interne. C'est la plus grosse
  zone d'ombre de cette review.
- **`claude/`** : ~40 fichiers (commandes supprimées ou trimmées, agents,
  `claude/hooks/workflow-router-lib.mjs` +44) lus en diffstat seulement. Le
  classifieur canonique de 1 281 lignes n'a pas été ouvert.
- **`round-1.md` .. `round-7.md` et `review-1.md`** : délibérément non lus, pour
  que les findings ci-dessus soient produits indépendamment. Je ne me suis servi
  que de `review-aggregate.md` comme carte des attentes, et j'ai re-vérifié
  moi-même chaque claim que j'ai repris (C2 gate, C6 `maxdepth`, C7 charge
  scaffold, C10 lanes mortes). Il est donc possible que certains de mes
  findings recoupent `review-1.md` sans que je le sache.
- **`tests/router-evals/core.json`** (+243) et les fixtures 
  (`workflow///tasks.json`, 282 l.) : non lus. Le `router-eval`
  passe 76/76 mais je n'ai pas audité si les fixtures ajoutées mesurent autre
  chose que leur propre conformité — c'est précisément le reproche C4.
- **Aucun run live** : conformément à la consigne, aucun modèle n'a été
  facturé. Les propriétés « le hunter s'isole vraiment » et « le harness
  discrimine » restent donc démontrées uniquement par lecture de code et par
  repros hors ligne. En particulier, je n'ai pas exécuté un vrai
  `pi-review-hunter` ni vérifié qu'un enfant réel produit bien
  `isolation: isolated` de façon observable.
- **Non exercé** : installation fraîche (`scripts/install.sh`), déploiement
  macmini/multihost, `nvim/`, `herdr/`, `vendor/`, audit de secrets de
  l'historique git.
- **Mesures prises à HEAD uniquement.** Le `full` 69/69 a été mesuré sur
  `a8c28f8` avec un arbre de travail portant une modification non commitée
  (`docs/plan/20260823-discarded-implemented-archived-oracle-cycle.md`, autofix
  pi-lens) et un fichier non suivi (`review-1.md`). Je n'ai pas relancé le gate
  sur chaque commit intermédiaire ; les affirmations de type « X était rouge à
  tel commit » proviennent de `review-aggregate.md`, pas de mes mesures.
- **Environnement** : macOS, bash 3.2 par défaut. Les repros d'oracles ont
  tourné avec le `git` et le `awk` du système ; un `git status --porcelain`
  d'une autre implémentation pourrait déplacer les conclusions de m1.
