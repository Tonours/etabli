# Review externe — etabli (round 2)

- **Modèle** : claude-fable-5 (medium)
- **Date** : 2026-08-23

---

## Périmètre lu

Lecture complète : `README.md`, `AGENTS.md`, `workflow/spec.md`,
`workflow/agent-quick-card.md`, `workflow/contract-details.md`,
`docs/workflow-guide.md`, `scripts/lib/install-main.sh` (1909 lignes),
`scripts/install.sh`, `scripts/lib/etabli-harness-eval.sh` (522 lignes),
`docs/harness-eval.md`, `tests/fixtures/harness-v1/manifest.json` + 2 oracles
(`ready-implement-touches-only-plan-files`, `review-isolation-sentinel`,
`review-spec-drift`), `tests/etabli-harness-eval-smoke.sh`,
`workflow/skills/implementation-loop.md`, `workflow/skills/review.md`,
`workflow/skills/adversary.md`, `workflow/runtime/skill-surface.tsv`,
`scripts/verify-agentic-infra` + `workflow/runtime/agentic-infra-checks.tsv`,
`SECURITY.md`, ADR 0013–0017, `docs/adversary-etabli-10-scorecard.md` (lu en
dernier), extraits de `scripts/lib/{skill-catalog,etabli-scope,pi-paths}.sh`.

Commandes exécutées (lecture seule / tmp) :

| Commande | Résultat |
| --- | --- |
| `bash tests/etabli-harness-eval-smoke.sh` | ok, exit 0, ~2 s |
| `scripts/verify-agentic-infra core` | exit 0, tous PASS (~35 s) |
| `shasum -a 256 scripts/lib/etabli-harness-eval.sh` | `d6c9b0…f9e2`, identique au `evaluator.sha256` du manifest |
| `rg '/Users/tonours'` sur `workflow/ pi/ claude/ scripts/ mcp/` | aucun hit hors archives `docs/plan/` et `docs/research/` |
| `git log --oneline -30`, `ls` des dirs clés | ok |

**La promesse de base tient.** Contrat unique dans `workflow/`, fan-out par
symlinks vers `~/.pi`, `~/.claude`, `~/.codex`, `~/.agents` implémenté dans
l'installer (`scripts/lib/install-main.sh:1466-1774`), catalog TSV comme source
de vérité des surfaces (`workflow/runtime/skill-surface.tsv`), suite eval avec
oracles exécutables et SHA pinné, gate quotidien vert. Ce n'est pas du
vaporware. La question n'est pas « est-ce que ça marche » mais « est-ce que ça
vaut son coût » — voir l'avis final.

---

## Findings

### BLOCKER

Aucun. Rien de cassé à l'instant T sur les surfaces vérifiées : le gate core
passe, la SHA de l'évaluateur est synchrone, aucun secret ni chemin absolu
utilisateur sur les surfaces vivantes.

### MAJOR

**M1 — L'installer masque les échecs de son propre catalogue et devient
destructeur en cas de TSV illisible.**
`scripts/lib/install-main.sh:22-23` :
`readonly PI_CORE_SKILLS=($(skill_catalog_names "$SKILL_CATALOG" pi pi_core))`.
Fait vérifié : `readonly VAR=$(cmd)` masque le code retour de `cmd`
(SC2155) ; si le TSV est absent ou illisible, l'array est vide et `set -e` ne
déclenche rien. Inférence directe : `prune_managed_pi_skills`
(`install-main.sh:465-484`) supprime alors **tous** les liens de skills
managés (`is_core_pi_skill` retourne faux pour tout), idem
`prune_managed_agents_skills`. Récupérable au run suivant, mais c'est un
fail-open sur un chemin de suppression. Fix : séparer déclaration et
affectation, et `harness_die` si le catalogue rend zéro nom.

**M2 — `install-main.sh` tourne sous `set -e` seul, sans `-u` ni `pipefail`.**
`scripts/lib/install-main.sh:8` (fait vérifié). Le wrapper `scripts/install.sh`
a bien `set -euo pipefail` mais fait `exec bash lib/install-main.sh`, donc les
options ne se propagent pas. 1900 lignes de bash qui font `rm -f`, `ln -sfn`,
`backup_path_move` dans `$HOME` sans protection contre les variables vides.
Les helpers récents sont défensifs (`${VAR:-}`), le corps historique ne l'est
pas partout. Fix : `set -euo pipefail` en tête de `install-main.sh` et un
passage shellcheck bloquant en CI sur ce fichier.

**M3 — Supply chain de l'installer : `curl | sh` non pinné.**
`install-main.sh:1252` (`curl … rtk/install.sh | sh`), `:1181` (bootstrap
Homebrew), `:1207` (version lazygit via API GitHub non pinnée), `:1275-1288`
(douze paquets npm globaux **sans version**). Faits vérifiés. `SECURITY.md`
couvre les secrets mais ne dit rien de la chaîne d'approvisionnement de
l'installer, alors que ce script écrit dans `$PATH` et les rcfiles. C'est
incohérent avec le niveau de paranoïa du reste du repo (skills lock,
`supply-chain-smoke`). Fix : pinner les versions npm et remplacer `curl|sh`
par un téléchargement vérifié (checksum) ou l'abandon de RTK côté installer.

**M4 — Le repo vit sur un volume externe et tout `$HOME` pointe dessus.**
Fait vérifié : workspace = `/Volumes/Crucial/work/etabli` ; l'installer crée
des liens absolus depuis `~/.pi`, `~/.claude`, `~/.codex`, `~/.agents` vers ce
volume. Inférence : volume démonté ⇒ les quatre harness perdent workflow,
skills, templates et hooks simultanément, en plein milieu de sessions
éventuelles. C'est la première chose qui casse, avant toute dérive multihost.
Fix : soit déplacer le repo sur le disque interne, soit documenter/scripter un
mode dégradé (copies locales au lieu de liens pour les surfaces critiques).

**M5 — Complexité hors de proportion avec un usage mono-utilisateur.**
Faits vérifiés : 48 scripts dans `scripts/`, ~70 smokes dans `tests/`,
24 contrats dans `workflow/skills/`, ~4500 lignes de markdown normatif
(`workflow/*.md` = 1901, `workflow/skills/*.md` = 2637), 20 routes dans la
table de routage de `workflow/spec.md:131-154`, plus des schémas JSON
(`program.schema.json`, `evidence-pack.schema.json`,
`project-autonomy-envelope.schema.json`) et leurs scripts. Le repo a déjà
prouvé lui-même que ce niveau d'infra dépasse l'usage : ADR-0013 constate
« 13 events total » dans le ledger en un mois et supprime le council (~11k
lignes). Opinion argumentée : `program-orchestration`, `project-autonomy`,
`evidence-proof`, `workflow-telemetry-recover` et une partie des routes
(`research-plan`, `spec-guide`, `recurring-run`) sont dans la même situation
que le council avant ADR-0013 — de l'infra pour une équipe d'éval, maintenue
par une personne. Chaque contrat non exercé est du texte que les agents
chargent et que les smokes re-vérifient à chaque run.

**M6 — Le contrat est écrit en quatre exemplaires qui se paraphrasent.**
`workflow/spec.md`, `workflow/agent-quick-card.md`,
`workflow/contract-details.md` et `docs/workflow-guide.md` répètent chacun le
cycle PLAN, les statuts, check-freeze, no-progress et ops-stop avec une règle
de préséance (« spec wins »). Fait vérifié : la table de routage courte du
quick-card et celle du guide sont des sous-ensembles resynchronisés à la main
de celle du spec. La dérive doc↔doc est contenue par
`workflow-contract-coverage-smoke` (27 s, le check le plus lent du core) —
autrement dit vous payez un test permanent pour maintenir une duplication
choisie. Fix : réduire à deux documents (map agent + détails), générer le
guide humain ou l'assumer comme non normatif sans tables dupliquées.

### MINOR

**m1 — ~370 lignes de smoke test embarquées dans le script d'installation de
production.** `install-main.sh:747-1114`, gated par
`ETABLI_INSTALL_HELPER_SMOKE=1`, avec réassignation de `HOME`, `NODE_CMD` et
`PATH` au milieu du fichier partagé. Ça teste du vrai comportement (bien),
mais le test et la prod partagent l'état global d'un même script de 1900
lignes : toute variable oubliée fuit d'un monde à l'autre. Fix : extraire dans
`tests/install-helpers-smoke.sh` qui source les helpers.

**m2 — Suite harness-eval : 7 tâches, pass@1, modèles pinnés.** Fait vérifié :
`tests/fixtures/harness-v1/manifest.json` liste 7 tâches, le split `held_out`
en contient 2. Les oracles sont réellement discriminants (le smoke vérifie
pass **et** fail par tâche, fail-closed sur `runner_exit != 0`,
sentinelles Cursor/model-mismatch) — c'est mieux que cosmétique. Mais avec
n=7 et un run par cellule, aucune conclusion comportementale robuste n'est
possible ; c'est un canari, pas un benchmark. Le README le présente
honnêtement, `docs/harness-eval.md` cite DeepSWE — la filiation
méthodologique est flatteuse pour ce que c'est. Fix : rien d'urgent ;
étiqueter « canari » et n'étendre que si une régression réelle échappe au
suite actuelle.

**m3 — Dérive documentaire : le musée est mélangé au vivant.** Fait vérifié :
`docs/` racine contient une quinzaine d'analyses datées
(`adversary-etabli-10-*`, `etabli-harness-audit-20260724.md`,
`harness-robustness-top5-*-20260801.md`, `harness-top5-consolide-20260801.md`,
`harness-surface-map-20260801.md`, `docs/handoffs/`…) à côté des documents
opérationnels (`workflow-guide.md`, `mcp-strategy.md`, `harness-eval.md`).
Certaines portent un bandeau « Historical snapshot », d'autres non. `docs/plan/`
est un vrai dossier d'archives assumé ; le reste, non. Fix : `docs/archive/`
et un déplacement mécanique de tout document daté non référencé par le README.

**m4 — Douze outils npm globaux non versionnés = dérive multihost garantie.**
`install-main.sh:1275-1288`. Deux machines installées à un mois d'écart auront
des LSP différents. Contraste : `PI_AGENT_NPM_PINS` est exact au patch près
(`:24-26`). Fix : pinner, comme le fait déjà le reste du repo.

**m5 — Échec en plein milieu d'installation = état partiel sans reprise.**
`etabli_active_scopes` retourne 2 sur un scope inconnu
(`scripts/lib/etabli-scope.sh:19-21`, bien), mais appelé à
`install-main.sh:1618` sous `set -e` : l'installer meurt après avoir déjà lié
Pi/agents et avant Claude/vendor. Idempotent au rerun, mais aucun message ne
dit « relancez après correction ». Fix : valider le scope en tête de script.

### NIT

**n1 — Timeout par `perl alarm` sans kill du process group.**
`scripts/lib/etabli-harness-eval.sh:330-340`. Si le runner spawne des enfants
(ce que fait un agent), SIGALRM tue le parent et peut laisser des orphelins
sur un run live. Non vérifié en live.

**n2 — `spec.md` § Rules viole son propre principe « maps, not manuals ».**
`workflow/spec.md:45-113` : la « map » des règles fait ~70 lignes denses avec
des exceptions imbriquées. Opinion : plusieurs items appartiennent à
`contract-details.md`.

**n3 — `harness_extract_verdict` accepte plusieurs lignes Verdict et prend la
dernière.** `etabli-harness-eval.sh:41-49`. Un transcript qui cite le contrat
(« Verdict: GO ») avant son vrai verdict est notés sur la citation si elle est
en fin de fichier. Le smoke couvre le cas gabarit (`Verdict: GO | GO WITH
NOTES | BLOCK` rejeté) mais pas celui-ci. Théorique.

---

## Avis final

### 1. Verdict en une phrase

Bien conçu et exécuté avec une rigueur rare pour son objectif technique, mais
surdimensionné d'un facteur 2 à 3 pour un seul opérateur : c'est une plateforme
d'équipe habitée par une personne, et le repo passe une part croissante de son
énergie à se vérifier lui-même.

### 2. Top 3 forces (avec preuve)

1. **Les guards sont mécaniques, testés des deux côtés, et fail-closed.**
   `planMutationGuardDecision` partagé Pi/Claude, matrice
   `dual-runtime-guard-matrix-smoke` observée verte ici même (deny_on_draft,
   check-freeze weaken deny, ops-stop), oracles harness qui échouent quand le
   runner meurt (`runner_exit 127 ⇒ pass=false`, vérifié dans le smoke). La
   promesse « guards that fail closed » du README est tenue dans le code.
2. **La culture d'honnêteté épistémique est réelle, pas déclarative.**
   ADR-0014 enregistre sa propre erreur (le `pi-import-smoke` cassé masqué par
   un `skill-lock` rouge) ; ADR-0013 supprime 11k lignes sur preuve d'inutilité
   (13 events/mois) ; la capability matrix affiche `unknown`/`blocked` au lieu
   de sur-déclarer ; le README dit « live comparison — blocked, not claimed ».
   C'est le meilleur historique de décisions que j'aie vu dans un repo perso.
3. **La chaîne d'intégrité de l'eval est vérifiable de bout en bout.** SHA de
   l'évaluateur pinnée dans le manifest et vérifiée par le smoke (contrôlée
   ici : identique), fixtures pass **et** fail par tâche, sentinelles
   d'environnement (Cursor absent, model mismatch) qui échouent la cellule au
   lieu de la passer, argv figé et inspectable sans facturer un modèle.

### 3. Top 3 faiblesses (avec preuve)

1. **L'installer est le composant le plus dangereux et le moins tenu aux
   standards du repo** : `set -e` seul (M2), SC2155 masquant un catalogue
   illisible avec pruning destructeur en aval (M1), `curl|sh` et npm non pinné
   (M3, m4) — alors que le même repo pinne `vscode-languageserver-protocol` au
   patch près et verrouille ses skills par hash.
2. **Coût de possession du contrat.** ~4500 lignes normatives en 4 documents
   qui se paraphrasent, 20 routes, 24 skills de workflow, et un smoke de 27 s
   dont le seul rôle est d'empêcher ces textes de diverger (M5, M6). Le
   précédent interne (ADR-0013) démontre que ce système accumule de l'infra
   plus vite qu'il ne la consomme.
3. **Point de défaillance unique non traité : le volume externe** (M4). Toute
   la sophistication des guards ne protège pas du cas trivial où
   `/Volumes/Crucial` est absent et où quatre harness démarrent avec des
   symlinks morts.

### 4. Les 3 choses à arrêter de faire

1. **Arrêter d'écrire des contrats pour des scénarios non exercés.** Geler
   toute nouvelle route/skill/schéma tant qu'un compteur d'usage réel
   (l'équivalent des « ≥10 task-grader outcomes » déjà imposés à la télémétrie)
   n'est pas atteint pour l'existant. Appliquer aux candidats évidents :
   `program-orchestration`, `project-autonomy-envelope`,
   `workflow-telemetry-recover`.
2. **Arrêter de maintenir quatre documents de contrat.** Deux suffisent
   (quick-card agent + détails) ; le guide humain devient une visite guidée
   sans tables normatives dupliquées, et `workflow-contract-coverage-smoke`
   rétrécit d'autant.
3. **Arrêter d'empiler des analyses datées dans `docs/` racine.** Le réflexe
   audit/scorecard/handoff produit du musée ; une note distillée dans obvault
   ou un ADR vaut mieux qu'un cinquième « top5 consolidé » horodaté.

### 5. Les 3 choses à faire ensuite (par ROI)

1. **Durcir l'installer** (M1+M2+m4, une demi-journée) : `set -euo pipefail`,
   fail si catalogue vide, shellcheck bloquant en CI, pin des npm globaux.
   C'est le seul endroit du repo où un bug efface des choses chez vous.
2. **Traiter le risque volume externe** (M4) : décision explicite — déplacer le
   repo, ou copier (pas lier) les surfaces critiques avec un check de
   fraîcheur. Une heure de travail, supprime le pire mode de panne.
3. **Une passe ADR-0013-style sur le tail de `scripts/` et `workflow/skills/`**
   (M5) : mesurer ce qui a été invoqué en 60 jours (les ledgers et l'historique
   git suffisent), supprimer ou geler le reste. Le repo sait déjà faire cet
   exercice ; il faut juste le refaire sur la couche qui a poussé depuis.

### 6. Score sur 10

Grille (pondération égale) :

| Dimension | Note | Justification courte |
| --- | --- | --- |
| Cohérence contrat↔implémentation | 8 | Promesses du README vérifiées dans le code et les checks ; quelques pans `unknown` non prouvés (subagents, goal_state) assumés honnêtement |
| Robustesse opérationnelle | 6 | Guards excellents, mais installer fail-open (M1), volume externe (M4), état partiel sans reprise (m5) |
| Simplicité / YAGNI | 4 | M5+M6 ; le repo lui-même a documenté le pattern de sur-construction et y retombe |
| Qualité d'exécution | 8 | Oracles discriminants, SHA pinning, ADRs exemplaires ; contre-exemples concentrés dans l'installer |
| Maintenabilité | 6 | Mono-mainteneur, 4500 lignes normatives, duplication contractuelle compensée par des smokes ; les ADR aident beaucoup |

**Score global : 6,5/10.**

**Écart avec `docs/adversary-etabli-10-scorecard.md` (« solid 10 », toutes
dimensions ≥9)** : je ne conteste presque aucune de ses lignes — les
dimensions 1-10 qu'il mesure (guards, routing, parity, check-freeze, honnêteté
MCP) sont effectivement au niveau 9+, et mes propres runs le confirment. Le
désaccord est structurel : ce scorecard note le système **sur la grille que le
système s'est choisie**, et cette grille ne contient ni dimension « coût de
possession / simplicité », ni « robustesse de l'installer », ni « risque
d'environnement » (volume, supply chain). C'est un 10 de conformité interne,
daté du 2026-07-29 et auto-étiqueté « historical snapshot » ; mon 6,5 est une
note d'architecte externe qui inclut ce que la grille interne exclut. Si je ne
notais que les dimensions du scorecard, je serais à 9.

---

## Lacunes (non vérifié, listé au lieu de spéculer)

- `scripts/deploy-agent-workflow` et `scripts/deploy-workflow` : non lus ; le
  jugement sur le fan-out repose sur `install-main.sh` et le smoke deploy vu
  passer.
- `pi/extensions/*.ts` et `claude/hooks/*.mjs` : implémentation des guards non
  lue ; je m'appuie sur la matrice smoke observée verte.
- `tests/supply-chain-smoke.sh` : passé au core mais contenu non lu — je ne
  sais pas s'il couvre les `curl|sh` de M3.
- `verify-agentic-infra full` et le profil `live` : non exécutés.
- Installation de bout en bout (`./scripts/install.sh`) : non exécutée
  (mutation de `$HOME`) ; M1/M2 sont des lectures de code, pas des repros.
- `vendor/`, `herdr/`, `nvim/`, obvault : hors périmètre de ce round.
- `round-1.md` : volontairement non lu avant rédaction, pour garder ce round
  indépendant.
- Fragilité multihost réelle (macmini rsync, dérive de machines) : jugée sur
  docs seulement.
