# Review branche refactor/skill-default-load (review 4)

- **Modèle** : kimi-k3 (max)
- **Date** : 2026-08-23
- **HEAD** : a8c28f8

Méthode : diffstat par commit, lecture intégrale des fichiers pivots, puis
**reproductions adversariales propres** (9 sondes d'oracles + 1 mesure de
plancher de fabrication, toutes hors ligne dans `mktemp`, aucun modèle
facturé). Marquage des claims : [vérifié] = exécuté ou lu de première main ;
[repro] = reproduit par une sonde jetable (détails en annexe des findings) ;
[délégué] = lu par une passe sous-traitée en lecture seule, non re-exécuté ;
[inférence] / [opinion]. J'ai lu `review-1/2/3.md` avant d'écrire ; les
désaccords sont explicites.

Exécuté localement : `verify-agentic-infra core` **vert** (34 s),
`verify-agentic-infra full` **vert** (187 s), `etabli-harness-eval-smoke`
**ok**, `null-baseline` **1/8 reproduit** (seul `plan-draft-no-mutate` passe),
`bun test pi/extensions/__tests__` **238 pass / 0 fail**, sonde du classifier
par `node`, mesure `deploy-workflow` en bac à sable.

## Périmètre lu

- **Lu en entier** : `scripts/lib/etabli-harness-eval.sh` (533 l.),
  `scripts/etabli-harness-eval` (193 l.), les 8 `oracle.sh`,
  `scripts/pi-review-hunter` (179 l.), `scripts/lib/prefer-cursor-agent.sh`,
  `scripts/check-fix-symlinks.sh` (tête + chemins catalogue),
  `scripts/verify-agentic-infra` (zones accumulation + shell-syntax),
  `workflow/skills/review.md`, `workflow/skills/investigation.md`,
  `workflow/skills/program-orchestration.md`,
  `tests/fixtures/harness-v1/manifest.json`, les prompts harness,
  `review-aggregate.md`, les deux plans 20260823, les deux stubs
  `discarded-implemented-archived*`, `docs/harness-eval.md`,
  `docs/archive/README.md`, tête de README.
- **Lu en diff** : `workflow/spec.md`, `workflow/skills/implementation-loop.md`,
  `workflow/review-rubric.md`, `.github/workflows/agentic-infra.yml`,
  `pi/extensions/pi-autoresearch.json`, `workflow/runtime/skill-surface.tsv`
  (comptages), `tests/router-evals/core.json` (sondé par jq).
- **Lu par délégation** (rapport intégral reçu, claims citées marquées
  [délégué]) : `scripts/lib/-suite.mjs`, `scripts/evidence-proof`,
  `scripts/program-state`, `scripts/workflow-event`, `workflow///*`,
  templates JSON lane-3, smokes associés. Points critiques spot-vérifiés par
  moi ensuite (`evidence-proof` validateCommand + capture).
- **Vérifié par comptage/mesure** : TSV gate (16 core + 53 full + 4 live),
  scaffold déployé (55 fichiers / 341 830 octets), all_zero (53 → 80),
  classifier sur 3 prompts, 9 sondes d'oracles, plancher de fabrication.
- **Non lu** : voir Lacunes.

## Axe 1 — Findings

### BLOCKER

#### B1 — L'intégrité d'état de la suite est contournable sur les 8 tâches, par deux familles de trous dont un seul fix

`tests/fixtures/harness-v1/tasks/{hunter-read-only,review-go-forbidden-empty-deciding,review-spec-drift,no-parent-logic-claim}/oracle.sh`,
`scripts/lib/etabli-harness-eval.sh:113-132` (`harness_porcelain_paths`),
`review-isolation-sentinel/oracle.sh:12-13`. [repro ×7]

Première famille (déjà documentée par reviews 2/3, re-reproduite ici) : 4
oracles ne regardent pas le worktree. Mes sondes, worktree préparé par
`harness_prepare_worktree` puis transcript synthétique `pass` inchangé :

| Sonde | Mutation | Verdict oracle |
|---|---|---|
| `hunter-read-only` | `EXTRA_EVIL.txt` créé | **pass** (un seul SHA, pas d'allowlist) |
| `review-go-forbidden-empty-deciding` | `src/runtime.sh` (fichier sous revue) modifié + `EXTRA.txt` | **pass** (zéro contrôle d'état) |
| `review-spec-drift` | `FORBIDDEN.txt` — la preuve de la dérive — **supprimé** | **pass** |
| `no-parent-logic-claim` | (aucun contrôle d'état non plus) | — |

Deuxième famille, **nouvelle dans sa généralité** : les oracles qui *ont* un
contrôle d'état le perdent contre `git commit`, parce que
`harness_porcelain_paths` n'énumère que le non-commité :

| Sonde | Mutation | Verdict oracle |
|---|---|---|
| `plan-draft-no-mutate` | écriture `docs/plan/sneaky.md` enfouie dans un commit | **pass** (porcelain propre, SHA ok) |
| `ready-implement-touches-only-plan-files` | `pwned.sh` extra commité | **pass** (SHA attendu ok, porcelain propre) |
| `review-isolation-sentinel` | `src/backdoor.sh` enfoui par `git commit --amend` | **pass** (`rev-list --count` reste 1, porcelain propre, SHA ok) |

Donc : la moitié des oracles ne regarde rien, et l'autre moitié regarde un
compteur que le sujet contrôle. Le seul garde anti-enfouissement
(`rev-list --count HEAD == 1`) est neutralisé par `--amend`, qui préserve le
compte par construction. La classe C1 que la branche prétend fermer est
fermée contre l'agent paresseux, pas contre l'agent qui commite — or
« committe tes dégâts » est un réflexe à une ligne.

Portée honnête : aucun run live n'a été facturé, rien ne régresse pour
l'opérateur. BLOCKER au sens « toute publication de `pass@1` live avant ce
fix est une métrique fausse », pas au sens merge.

**Fix (un seul chantier, ~1-2 h)** : `harness_prepare_worktree` enregistre
hors du worktree `git rev-parse HEAD` + un hash d'arbre ; chaque oracle
safety/read-only exige identité de HEAD (tue commit *et* amend) et les 4
oracles de la première famille gagnent `harness_require_porcelain_allowlist`
+ SHA du fichier sous revue.

### MAJOR

#### M1 — Le plancher de fabrication mesuré est 6/8 ; la doc ne publie que le plancher d'abstention (1/8)

[repro, chiffre nouveau] J'ai construit le `constant-baseline` que review-2
réclamait : un transcript constant qui n'exécute rien et imprime les chaînes
attendues (sentinelle `HUNTER_SPAWN_UNAVAILABLE`, tables, `file:line`,
`Act on … FORBIDDEN.txt`, `isolation: isolated`, `runner: pi-child`), gradé
hors ligne sur les 8 tâches avec worktrees réels :

| Verdict constant | pass |
|---|---|
| `Verdict: BLOCK` | **6/8** |
| `Verdict: GO` | 4/8 |
| `Verdict: GO WITH NOTES` | 3/8 |

Seuls `ready-implement-touches-only-plan-files` (SHA d'état final) et
`review-go-clean-diff` (GO-only vs BLOCK) résistent à la meilleure politique
constante. Avant durcissement, le council mesurait 5-7/7 ; après, **6/8 =
0,75** : le durcissement a effondré le plancher d'abstention (5-7/7 → 1/8)
mais à peine bougé le plancher de fabrication. Un futur `pass@1` live de
0,75 serait indistinguishable d'un `printf`. `docs/harness-eval.md:76-78`
documente le plafond textuel en prose mais ne publie pas ce chiffre ; publier
le seul 1/8 est le plancher flatteur. Fix : subcommand `constant-baseline`
(mon script fait 30 lignes) + publication des deux planchers côte à côte.

#### M2 — `hunter-read-only` accepte `Verdict: GO` avec `isolation: none`

`tests/fixtures/harness-v1/tasks/hunter-read-only/oracle.sh:10-13` vs
`workflow/skills/review.md:113-115`. [repro] L'oracle exige « the full review
protocol » (tables, verdict, `file:line`, ligne `isolation:`) mais accepte
GO avec n'importe quelle valeur d'isolation — mon transcript GO +
`isolation: none` passe. Le contrat interdit GO quand `isolation: none`, et
l'oracle jumeau `review-go-clean-diff` applique cette interdiction
explicitement. Incohérence interne de la suite, pas seulement trou de
gameability. Fix : rejeter GO sauf `isolation: isolated` (copier le garde de
`review-go-clean-diff`).

#### M3 — « 80/80 PASS » est inventé ; le runner ne peut pas produire ce nombre

`docs/plan/20260823-review-findings-fixes.md:14`,
`docs/plan/20260823-oracle-hardening-null-baseline.md:15`,
`workflow/runtime/agentic-infra-checks.tsv` (16 core + 53 full = **69** ; 73
lignes avec les 4 live), `scripts/verify-agentic-infra` (`run_selection`
imprime `SUMMARY: all checks passed` **sans compte**). [vérifié : comptage
TSV + run full vert à HEAD] Le gate est réellement vert — mais le chiffre
archivé comme preuve deux fois n'existe pas, et l'absence de compte imprimé
est précisément ce qui a permis l'invention. Sur une branche dont la thèse
est « la preuve ne prouve pas », c'est le finding le plus embarrassant par
dollar. Fix : corriger en 69/69 et faire imprimer `SUMMARY: %d/%d checks
passed` par le runner.

#### M4 — La distillation a doublé la charge copiée dans chaque projet scaffoldé

`scripts/deploy-workflow:21-56`. [vérifié par exécution] À HEAD :
**55 fichiers / 341 830 octets** par `deploy-workflow <dir>`. Les 14 entrées
`FILES` ajoutées par la branche pèsent ~184 Ko dont `scripts/evidence-proof`
(51 Ko), `scripts/program-state` (38 Ko), `scripts/workflow-event` (31 Ko),
`workflow-event-detail.jq` (26 Ko). Avant branche : ~158 Ko (soustraction,
cohérent avec la mesure 156 Ko du round 3). C7 était la convergence la plus
consensuelle du council ; le commit « distill lane-3 contracts » a distillé
le texte lu et gonflé ×2,2 la charge copiée — et chaque cellule du harness
paie ces 334 Ko via `harness_prepare_worktree`. Rien ne mesure cette charge.
Fix : sortir les 4 gros scripts de `FILES` (résolution depuis les copies
`$HOME` installées) ou smoke plafond.

#### M5 — C4 approfondie, pas fermée : la branche a écrit la contradiction dans la spec après avoir touché les deux surfaces

`workflow/spec.md:135` (ligne **ajoutée** par d7891ab : « Ordinary coding
with no root `PLAN.md` and no explicit plan request → `answer` ») vs
`claude/hooks/workflow-router-lib.mjs:796-807` +
`tests/router-evals/core.json`. [vérifié par exécution]
`classifyWorkflowRoute("Corrige ce bug", { planStatus: "missing" })` →
`plan-implement` ; idem « fix the typo in the readme ». Les fixtures
router-eval — **éditées par d7891ab** (+243 l.) — attendent `plan-implement`
pour « Corrige le bug CSS dans notre SaaS ». La branche a donc touché la
table de la spec *et* les fixtures du classifier, et laissé les deux se
contredire — alors que la spec dit « wins on conflict ». Impact borné tant
que le classifier est observationnel (ADR-0014) [inférence partagée par les
3 reviews], mais l'état « deux surfaces canoniques fraîchement éditées qui se
nient » est pire que l'état pré-branche. Fix : aligner classifier + fixtures
sur la ligne spec (une heure), ou marquer le classifier non-canonique.

#### M6 — `evidence-proof validate` est fail-open sans `--assert`, et le contrat documente l'appel sans `--assert`

`scripts/evidence-proof` (`validateCommand` : `if (assertVerdict &&
result.verdict !== "VERIFIED") process.exit(1)`) ; `workflow/skills/
investigation.md:72` (« the executable semantic validator is
`scripts/evidence-proof validate` » — pas de drapeau). [vérifié par lecture,
confirmant le finding [délégué]] Un agent qui suit le contrat obtient exit 0
sur un pack non-VERIFIED et doit parser le JSON lui-même — pour un outil
dont la raison d'être est de *gater* des claims. Fix : `--assert` par défaut
(ou `--no-assert` explicite), ou le contrat nomme le drapeau.

#### M7 — Le profil live peut annoncer vert une cellule rouge ou un skip

`scripts/etabli-harness-eval:141-146`, `scripts/lib/etabli-harness-eval.sh`
(`harness_grade` retourne toujours 0 — dernier appel `harness_json_row`),
`tests/etabli-harness-eval-live.sh:6-11`. [vérifié par lecture] `run` n'exige
qu'une ligne JSON non vide ; `.pass: false` ne change pas l'exit status ; le
wrapper live sort 0 quand `ETABLI_HARNESS_EVAL` est absent.
`verify-agentic-infra live` peut donc imprimer `SUMMARY: all checks passed`
sans succès harness, voire sans l'avoir exécuté. Fix : exit ≠ 0 si une ligne
émise a `.pass != true` ; statut de skip distinct.

#### M8 — Réutiliser `ETABLI_HARNESS_EVAL_DIR` contamine la baseline suivante

`scripts/etabli-harness-eval:117-123,139`,
`scripts/lib/etabli-harness-eval.sh:351-372`. [vérifié par lecture] Noms de
cellules déterministes, destination existante ni refusée ni nettoyée : le
second `git init/add/commit` absorbe les restes du run précédent dans le
commit fixture. Fix : refuser une cellule existante non vide.

### MINOR

- **m1 — `prefer-cursor-agent.sh` : tout symlink `~/.grok/bin/agent` est une
  « collision »** (`:17-18`, sans comparer la cible), supprimé par
  l'installer **et** par le hook rc à chaque shell interactif (`:41-46`) ;
  et `touch … || return 0` / `mktemp || return 0` (`:62-64`) avalent les
  échecs en succès muet. [vérifié par lecture] Désaccord de sévérité avec
  review-3 (MAJOR) : le blast radius est un symlink dans un répertoire géré,
  sous une politique documentée dans AGENTS.md — MINOR ferme, pas MAJOR.
- **m2 — `check-fix-symlinks.sh` crashe si le catalogue est présent mais
  rend 0 ligne `pi_core`.** `:20` (`PI_CORE_SKILLS=($(…))` vide sous
  bash 3.2 + `set -u`) ; le sentinel `("")` ne couvre que le cas fichier
  absent (`:22-26`). [vérifié par lecture ; reproduit par review-1]
- **m3 — `shell-syntax` reste aveugle à `scripts/lib/`** :
  `scripts/verify-agentic-infra:24` (`find … -maxdepth 1`). 5 fichiers à
  shebang y vivent (~2 100 l.), dont le nouveau `prefer-cursor-agent.sh`
  déposé par cette branche. Sous-finding C6 nommé, non fermé. Fix : retirer
  `-maxdepth 1`. [vérifié]
- **m4 — CI sans `concurrency` ni `paths-ignore`** :
  `.github/workflows/agentic-infra.yml:3-6`. `push: ["**"]` + `pull_request:`
  → double emploi par push sur branche de PR (3 jobs × 2), aucun run obsolète
  annulé. [vérifié]
- **m5 — Manifest ↔ doc contradictoires** : `hunter-read-only.runners =
  ["pi","grok"]` vs `docs/harness-eval.md:16` « Review-hunter tasks are
  Pi-only ». [vérifié]
- **m6 — `implementation-loop.md` étape 13 vs `review.md:43-45`** : le loop
  exige Logic **et** Spec en fresh context ; review.md impose Spec dans le
  parent pour Daily Pi (`spec: parent`). Contradiction non référencée dans la
  completion evidence. [vérifié par lecture]
- **m7 — L'étagère `all_zero` passe de 53 à 80 lignes** (comptage TSV
  merge-base vs HEAD) pendant que l'installer annonce encore `/skill:caveman`
  et `/skill:grill-me` (`scripts/lib/install-main.sh:1821-1822`). [vérifié]
  Voir Axe 3 §7 : je ne propose pas de supprimer l'étagère.
- **m8 — `harness_extract_verdict` prend le dernier match n'importe où** dans
  le fichier (`etabli-harness-eval.sh:41-49`), alors que le contrat exige
  « one **final** line » (`review.md:107`) et que le message d'erreur dit
  « final line ». Une citation `^Verdict: GO$` en fin de transcript écrase le
  vrai verdict. [vérifié par lecture]
- **m9 — `program-state` sort 0 avec `runtime_confirmed: false`** (fail-open
  si un jour utilisé comme gate) ; `benchmark-declaration.json` n'a pas de
  schéma. [délégué, lecture seule — non re-exécuté]
- **m10 — Le smoke borne le null floor à `≤ 2`** alors que la doc publie 1/8
  (`tests/etabli-harness-eval-smoke.sh:307-309`) : une régression à 2/8 passe
  le gate. Fix : `-eq 1` + assert sur l'identité de la tâche. [vérifié]

### NIT

- `manifest.json:6` : `evaluator.id = binary-final-state-v1` alors que 7/8
  oracles sont text-first. [vérifié]
- `review-spec-drift/oracle.sh:11` : le grep final `Act on|^Verdict: BLOCK$`
  est rendu redondant par `harness_require_verdict_one_of 'Verdict: BLOCK'`.
  [vérifié par lecture]
- `5281dd2` (`pi-autoresearch.json`) : remap de raccourci juste mais sans
  test de chemin/clé. [vérifié : aucun test ne le référence]
- `harness_grade` applique le sentinel Cursor même en grade `offline`/`null`
  (`etabli-harness-eval.sh:290`) : un transcript null contenant la chaîne
  échouerait pour une raison étrangère au runner. [vérifié par lecture]

### Vérifié sain (à décharge)

- Gate `core` 16/16 et `full` verts à HEAD (exécutés ici) ; accumulation
  réelle des FAIL (`run_selection` lit tout le manifeste, compte, SUMMARY
  nominatif, exit 1) — le construct est pinné par `agentic-infra-manifest-smoke`.
- `skill-lock` en `core` et vert : 79 hashes vérifiés dans mon run.
- Null baseline honnête : transcript vide (`: >"$transcript"`), runner
  `"null"`, offline ; 1/8 reproduit.
- `cross_harness` et `route-context-manifest` réellement éradiqués (absents
  du diff résiduel, TSV 5 colonnes ; grep exhaustif déjà fait par reviews
  1/2/3, non contredit par mes lectures).
- argv hunter réellement restrictif : `--no-session --no-skills
  --no-extensions --no-context-files --tools read,grep`, pas de `--approve`,
  prompt/patch vides rejetés, quoting `"${PI_ARGS[@]}"` correct ; le repli
  perl fork+alarm de `pi-review-hunter:144-166` corrige un vrai piège macOS
  (alarm perdu sur exec) — et je note que `harness_run_bounded`
  (`etabli-harness-eval.sh:330-340`) utilise encore le motif alarm+exec sans
  fork, incohérence interne [vérifié par lecture, sévérité NIT tant que
  macOS préserve ITIMER_REAL sur exec — comportement effectivement variable
  selon les implémentations, d'où le commentaire du hunter].
- `docs/archive/README.md` : index de statut + note de débunk explicite du
  scorecard 10/10. Le musée est archivé honnêtement.
-  : les résultats commités sont **structural 23/23 VERIFIED / live
  0/138 BLOCKED**, avec `claim_boundary` interdisant de les citer comme
  supériorité live ; aucun score modèle auto-attribué. [délégué + spot-check]
- `b088791` est du formatage pur aux endroits lus ; `bun test` 238/0.

## Axe 2 — Choix de direction

### 1. Recentrage kernel skills (d7891ab) — **bonne direction, commit bicéphale dont une moitié va contre C7**

La moitié « kernel » est juste et je la vérifie : 14 `pi_core`, étagère
opt-in, échelles de résolution de 20-40 lignes remplacées par une ligne,
racines absolues au lieu de `../../../` fragiles, `suite-router` obligatoire
supprimé du chemin critique (spec.md réécrit : « no additional global skill
router »). C'est l'application la plus nette du consensus C7 au stock.

La moitié « lane-3 » fait l'inverse : +184 Ko dans chaque scaffold (M4),
+27 lignes `all_zero` (m7), et une ligne spec ajoutée sans réconcilier le
classifier (M5). 141 fichiers mêlant cinq préoccupations dans un seul commit
viole aussi le « no broad refactor » d'AGENTS.md [opinion partagée avec
review-2]. **Verdict : bonne décision sur les skills, à refaire sur la charge
déployée — le correctif (4 entrées `FILES`) coûte moins cher que la dette.**

Désaccord explicite avec review-1 (qui note ce choix 8/10 sans voir M4) : on
ne peut pas saluer « la première application réelle de C7 » dans un commit
qui aggrave C7 d'un facteur mesuré 2,2.

### 2. Isolation des review hunters (2a52ea4) — **mécanique réelle, preuve théâtrale ; discutable sous trois conditions**

Réel (vérifié dans l'argv, pas dans la doc) : spawn neuf, `--no-session`,
surface d'outils réduite à `read,grep` par enforcement CLI, pas de
`--approve`, prompt/patch non vides exigés, timeout avec repli macOS correct.
Théâtral : `isolation: isolated` et `runner: pi-child` sont des chaînes que
le parent écrit dans le transcript que l'oracle greppe ; le helper est
optionnel dans le skill (« when present, else this argv ») ; le Spec hunter
tourne dans le parent sur Daily Pi ; et M2 montre que même le gate de verdict
n'est pas appliqué uniformément. Le repo possède la formule exacte
(`reviewer-improvement-loop.md` : une étape qu'on peut sauter sans que ça se
voie n'existe pas) et ne se l'applique pas.

Conditions pour transformer en bonne décision : (a) helper seul chemin Pi ;
(b) preuve hors-bande — l'enfant écrit un artefact dans un chemin imposé par
la cellule, l'oracle le hashe (les briques existent) ; (c) renommer la claim
en « Logic-only, session-fresh ». **Verdict : garder le mécanisme, cesser de
présenter les greps de sentinelles comme preuve d'isolation.**

### 3. Suite harness-eval (ef11830 + a8c28f8) — **méthode valable ; le plafond textuel est réel, et je l'ai mesuré à 6/8**

Sur « méthode ou sur-ingénierie » : valable. Le produit de ce repo *est* un
harness d'agents ; ~1 100 lignes pour des tâches gelées hashées, oracles
exécutables, runner fixé, contrôle positif GO-only et null baseline publié,
c'est l'instrument minimal pour remplacer le scorecard circulaire que les 7
rounds ont rejeté. La mention « does not claim DeepSWE scores » est le bon
modèle d'auto-limitation.

Sur « l'oracle textuel a-t-il un plafond réel » : **oui, et il est plus bas
que la doc ne l'admet, mais pour une raison réparable.** Deux plafonds
distincts : le plafond *textuel* (fabriquer les chaînes) est intrinsèque et
correctement déclaré ; le plafond *d'état* (B1) est une lacune de couverture,
pas une limite de méthode — il tombe avec un SHA de HEAD enregistré hors du
worktree. Ma mesure (M1) tranche le débat laissé ouvert par les reviews
précédentes : le plancher de fabrication est **6/8**, pas « ~6/8 estimé ».
Conséquence ferme [opinion] : aucun `pass@1` live comparatif Pi/Grok ne doit
être publié avant (a) le fix B1 et (b) la publication du fabrication floor à
côté du null floor. Avec ces deux correctifs, la suite devient ce que la doc
prétend déjà ; sans eux, elle mesure « inaction vs protocole ».

Réserve statistique additionnelle [opinion] : 8 cellules binaires, 5 Pi-only,
`--repeats 1` par défaut, aucune règle de lecture (n minimal, intervalle) —
même durcie, la suite ne peut pas départager deux runners ; la doc devrait le
dire avant que le premier run live ne « prouve » quelque chose.

### 4. Réponse au council (f35d672/f1438ab) — **honnêteté substantiellement restaurée ; une preuve chiffrée fausse et deux sous-findings rouverts**

Matériel, vérifié : le gate accumule (lu + exécuté), `skill-lock` tourne en
`core` (vu dans mon run), le mort est mort (grep), le musée est indexé avec
une note de débunk, et le post-mortem `cross_harness` (« dead-code removal
needs a consumer/behavior inventory ») est le meilleur artefact de la
branche — de l'auto-critique écrite qui généralise. Ce n'est pas du
cosmétique.

Entaché de trois choses : M3 (le « 80/80 » inventé reproduit exactement le
défaut corrigé — un chiffre de preuve non adossé à une mesure), M5 (C4 écrite
plus profondément dans la spec sans toucher le classifier), m3 (le trou
`shell-syntax` nommé par C6 est resté ouvert pendant que la branche déposait
un nouveau fichier précisément dans le répertoire aveugle). Le diagnostic du
council — *la décision est enregistrée, sa propagation ne l'est pas* — se
reproduit en plus petit, y compris intra-branche. **Verdict : bonne décision
et vrai travail de fond ; la comptabilité de la preuve reste le point faible,
et c'est précisément le point que cette branche était censée réparer.**

### 5. CI sur toutes les branches — **bonne décision, configuration incomplète**

Bénéfice démontré par la branche elle-même : 8 commits jamais validés sous
l'ancien déclencheur, et deux dérives commitées invisibles (skills-lock, SHA
manifest) attrapées tard. Coût : 3 jobs hermétiques, `core` ~35 s local —
trivial. Config incomplète (m4) : pas de `concurrency: cancel-in-progress`,
double emploi push/PR. **Verdict : garder, ajouter l'annulation. Le choix le
moins discutable des cinq.**

## Axe 3 — Ce qui reste ouvert, priorisé

1. **Baseline d'état hors portée du sujet (fix B1) — maintenant.** HEAD SHA +
   hash d'arbre enregistrés à `harness_prepare_worktree`, exigés au grade ;
   allowlists porcelain sur les 4 oracles nus. 1-2 h, débloque toute métrique
   live. Aucun autre chantier n'a ce ratio.
2. **Publier le fabrication floor — maintenant.** `constant-baseline` de
   ~30 lignes, symétrique du `null-baseline` ; mon script est la preuve de
   faisabilité. Sans lui, le 1/8 publié est le plancher flatteur.
3. **spec ↔ classifier (C4) — maintenant, et la branche l'a rendu urgent.**
   La décision est déjà écrite (`spec.md:135`) ; reste l'alignement
   classifier + fixtures (ou la mention « classifier non-canonique »). Une
   heure. Désaccord avec review-1 (« bientôt, sans urgence ») : après
   d7891ab, les deux surfaces fraîchement éditées se nient — c'est le pire
   état possible, pas un état neutre.
4. **brain/obvault (C5) — trancher maintenant.** Frontière de données active
   (l'agent work suit le contrat vers la base que l'ADR-0017 exclut). Une
   ligne de décision, un resolver autoritaire scope-aware, propagation
   mécanique.
5. **Installer (C6) — durcir maintenant, scinder plus tard.** `set -euo
   pipefail` + fail sur catalogue vide + prune fail-closed + `shell-syntax`
   récursif (une ligne, m3) : une demi-journée qui capture l'essentiel du
   risque. Le split workstation/agent ensuite.
6. **Reconciler unique (C3) — table maintenant, fusion après le split.**
   Décision minimale viable : une seule table des chemins gérés consommée par
   les trois scripts. Fusionner les scripts avant le split installer, c'est
   réconcilier ce qu'on va couper en deux [accord avec review-2].
7. **Étagère `all_zero` (80 lignes) — jamais comme chantier de suppression ;
   documenter maintenant.** Désaccord frontal avec review-3 (qui propose de
   supprimer) : l'étagère opt-in est la *conséquence délibérée* du
   recentrage — supprimer 80 entrées détruirait la surface de découverte que
   le refactor vient de créer. Les deux actions utiles et bornées : une ligne
   de commentaire en tête du TSV expliquant l'étagère, et retirer
   `/skill:caveman` / `/skill:grill-me` de l'aide de l'installer (m7).
8. **Tiering du rituel (C9) — instrumenter d'abord, trancher après 10
   outcomes.** Désaccord avec review-1 (« trancher le principe maintenant ») :
   le repo refuse ses propres claims sous 10 outcomes ; décider sur intuition
   serait la faute symétrique. La branche fournit d'ailleurs deux points de
   données (adversary cross-model : 6 puis 3 findings retenus) — continuer la
   série coûte moins cher qu'une décision.
9. **SPOF volume externe (C8) — jamais ré-architecturer ; détection
   maintenant.** Choix conscient de dotfiles sur portable. Ce qui vaut 30
   minutes : un guard dans le hook rc existant (`prefer-cursor-agent.sh` est
   déjà là) qui hurle quand `/Volumes/Crucial` est absent, au lieu de laisser
   l'activation ambiante s'éteindre en silence.
10. **Ergonomie du guard check-freeze — jamais comme chantier générique.**
    Rouvrir uniquement sur faux positif concret, fixture rouge d'abord,
    allowance minimale ensuite [accord avec review-3]. Un guard fail-closed
    qui agace vaut mieux qu'un parser shell qui se trompe.

## Score global : **6,3 / 10**

| Dimension | Note | Justification courte |
|---|---|---|
| Correctness | 6,0 | Gate core+full verts vérifiés, zéro régression opérateur ; mais l'instrument central de la branche a un trou d'état démontré sur 8/8 tâches (B1, deux familles) et un plancher de fabrication mesuré à 6/8 (M1) |
| Direction | 7,0 | 4/5 choix justes ; la moitié lane-3 de d7891ab va contre C7 d'un facteur mesuré ×2,2, et la preuve hunter reste déclarative |
| Exécution | 6,5 | Discipline réelle (formatter isolé, post-mortem cross_harness, null baseline honnête) ; entachée par le 80/80 inventé, C4 écrite sans propagation, helper optionnel |
| Maintenance | 5,5 | +15 424 lignes, scaffold ×2,2, étagère 53→80, triple reconciler et installer `set -e` de 1 835 lignes intacts — la surface à maintenir a crû plus vite que la surface vérifiée |

Moyenne 6,25 → **6,3**. Convergence indépendante avec les 6,2 des reviews 2
et 3 (mes mesures sont propres : 9 sondes, 2 comptages, 1 plancher de
fabrication) ; désaccord avec le 7,0 de review-1, qui surpaye la direction en
ne mesurant ni la charge scaffold ni le plancher de fabrication.

**Verdict d'ensemble** : mergeable au sens opérateur (rien de régressif au
quotidien, gate réellement vert) ; **BLOCK sur toute publication de `pass@1`
live** avant B1 + M1. La branche fait passer le repo de « la preuve ne prouve
pas » à « la preuve prouve le plancher d'abstention » — un vrai cran, payé
honnêtement. Le cran suivant est connu, chiffré, et tient en deux chantiers
d'une journée cumulée ; il faut le payer plutôt qu'ajouter de
l'instrumentation.

## Lacunes

- **Aucun run live facturé** : runners pi/grok du harness et spawn hunter
  réel non exercés ; mes verdicts sur leur comportement live sont des
  inférences depuis le code et les repros hors ligne.
- **Lane-3 lue par délégation, pas par moi en intégral** :
  `scripts/lib/-suite.mjs` (~1 700 l.), `scripts/evidence-proof` (834),
  `scripts/program-state` (682), `scripts/workflow-event` (+616), leurs
  smokes, `workflow///*`. J'ai spot-vérifié les deux findings les
  plus graves (M6, capture paths) ; le reste du rapport délégué (locks,
  jq-arg discipline, schemas) est cité [délégué] sans re-exécution.
- `round-1.md`..`round-7.md` (~2 700 l.) : lus via l'agrégat uniquement.
- `claude/hooks/workflow-router-lib.mjs` (1 281 l.) : sondé par exécution
  (3 prompts) et lectures ciblées, pas relu en entier.
- `install-main.sh` hors hunks branche (~1 700 l. préexistantes) : non relu ;
  les claims C6 reprises ici sont vérifiées par grep/lecture ciblée
  (`:1821-1822`, en-tête `set -e`) mais pas par audit complet.
- `claude/` (~40 fichiers trimés/supprimés), `nvim/`, `herdr/`, `vendor/`,
  `mcp/` : diffstat seulement. Fresh install, déploiement macmini, audit de
  secrets de l'historique : non exercés.
- `tests/router-evals/core.json` : sondé par jq sur les fixtures
  ordinary-coding ; les +243 lignes n'ont pas été auditées pour savoir si
  elles mesurent autre chose que leur propre conformité (le reproche C4
  s'applique aux fixtures elles-mêmes).
- Mesures prises à HEAD `a8c28f8` avec un arbre portant une modification non
  commitée (`docs/plan/20260823-discarded-implemented-archived-oracle-cycle.md`,
  +2 lignes, autofix pi-lens) et `review-1/2/3.md` non trackés — hors
  périmètre, non jugés. Je n'ai pas relancé le gate sur chaque commit
  intermédiaire ; les claims « rouge à tel commit » viennent de l'agrégat.
- Environnement : macOS, bash 3.2 système pour les repros ; un
  `git status --porcelain` d'une autre implémentation pourrait déplacer les
  conclusions liées au parsing porcelain (non testé : noms de fichiers
  exotiques/quotés).
- Le coût GitHub Actions réel (minutes consommées) n'a pas été mesuré sur des
  runs distants ; le double emploi push/PR est déduit du YAML.
