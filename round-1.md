# Review externe — etabli (round 1)

- **Date** : 2026-08-23
- **Reviewer** : externe (architecte plateforme + ops agent), prompt `/tmp/fable-review-prompt.md`
- **Branche** : `refactor/skill-default-load` (HEAD `5281dd2`, working tree propre)
- **Contrainte** : lecture seule sur le code ; ce fichier est le seul artefact produit

## Périmètre

**Lu intégralement** : `README.md`, `AGENTS.md`, `workflow/spec.md`,
`workflow/agent-quick-card.md`, `docs/workflow-guide.md`,
`scripts/lib/install-main.sh` (1909 lignes), `scripts/lib/etabli-harness-eval.sh`,
`docs/harness-eval.md`, `tests/fixtures/harness-v1/` (manifest + 2 oracles),
`workflow/skills/implementation-loop.md`, `workflow/skills/review.md`,
`workflow/skills/self-improvement-loop.md`, `workflow/runtime/skill-surface.tsv`,
ADR 0013–0017, `scripts/verify-agentic-infra`, `SECURITY.md`, `.mcp.json`,
`git log --oneline -30`, `docs/adversary-etabli-10-scorecard.md` (en dernier).

**Exécuté** : `scripts/verify-agentic-infra core` (vert, ~35s),
`bash tests/etabli-harness-eval-smoke.sh` (**rouge**, exit 1).

---

## Findings

### BLOCKER

**B1 — Le smoke harness-eval est rouge à HEAD de cette branche.**
`tests/fixtures/harness-v1/manifest.json:7` pine
`evaluator.sha256 = e43d14d30fb0e445476748d7a2550e5eaafbfc45805181bd424cd5979aaea2e8` ;
le fichier réel `scripts/lib/etabli-harness-eval.sh` hashe
`d6c9b0b0656ac123d02baed9b4ffe6d365476b8f7cd1ae4df72156ceb693f9e2`.
Exit 1 : `manifest evaluator.sha256 must match scripts/lib/etabli-harness-eval.sh`.
**Fait vérifié** (exécuté localement, working tree propre). Le commit `aafa7ae`
(« fix(workflow): ignore runner noise in harness eval grading », 2026-08-23 00:13)
a modifié la lib **et** le pin dans le même commit, mais le pin a été calculé
avant la dernière édition. Conséquences : `verify-agentic-infra full` rouge, et
le job CI `shell-docs` (`.github/workflows/agentic-infra.yml:25`) exécute cette
row (`workflow/runtime/agentic-infra-checks.tsv:68`) → CI rouge sur cette
branche (déterministe ; l'état effectif du run CI est non vérifié).
**Fix** : recalculer le SHA — et faire recalculer tout pin par un helper, jamais à la main.

Note : le contrat exige des « focused checks » avant commit
(`implementation-loop.md:48`), et le commit qui casse est celui qui durcit le
grading de l'eval. Le smoke est en profil `full`, pas `core`, donc le gate
quotidien n'a rien vu.

### MAJOR

**M1 — Le gate quotidien (`core`) ne couvre pas les surfaces nouvelles.**
`workflow/runtime/agentic-infra-checks.tsv:68` place le smoke harness-eval en
`full` uniquement. Le README vend `core` comme « daily health and safety gate »
(`README.md:129`), mais B1 démontre qu'un blocker traverse `core` sans bruit.
Le smoke est hermétique et rapide (<1s). **Fait vérifié.**
**Fix** : promouvoir les smokes hermétiques rapides en `core`.

**M2 — Quatre surfaces documentaires qui se recouvrent, tenues par un check de 50K.**
`workflow/spec.md` (11K), `agent-quick-card.md` (4,3K), `contract-details.md`
(20K), `docs/workflow-guide.md` (7,5K) redisent routes, statuts et guards.
`tests/workflow-docs-smoke.sh` fait 50,3K et tourne 28s dans `core` — un test
de cette taille dont le rôle est d'empêcher quatre copies de dériver est le
symptôme, pas la solution. **Fait vérifié** (tailles, durée observée).
**Opinion** : deux surfaces suffisent (spec canonique + guide humain en pointeurs).
Coût de contexte payé à chaque session d'agent — le problème même que
l'ADR-0014 a mesuré côté injection.

**M3 — `install-main.sh` : `set -e` seul, pas de `pipefail` ni `-u`.**
`scripts/lib/install-main.sh:8`, sur le script le plus dangereux du repo (il
`rm -f` des symlinks sous `~/.claude`, `~/.codex`, `~/.agents`). Un commentaire
ligne 1626 raisonne sur `set -u`… qui n'est pas activé. Les oracles récents
utilisent tous `set -euo pipefail` — la discipline existe, pas ici.
Atténuation réelle : les prune functions vérifient l'appartenance managée avant
suppression, et le smoke embarqué (`ETABLI_INSTALL_HELPER_SMOKE`, lignes
747–1114) couvre les cas relatifs/dangling/symlinked-repo. **Fait vérifié.**
**Fix** : `set -euo pipefail` + traiter les casses.

**M4 — Fragilité structurelle de la fan-out multi-harness, admise mais non résolue.**
Quatre surfaces de liens (`~/.pi/agent`, `~/.claude`, `~/.codex`, `~/.agents`)
+ scope file + vendored + scoped commands. L'ADR-0015 documente l'incident :
39 répertoires de `~/.codex/skills` en dead symlinks « advertised to the agent
while holding no content », et admet « a fourth harness would need its own link
block » (`docs/adr/0015:49-50`). **Fait vérifié** (l'ADR le dit ; état live de
`~/.codex` non audité). Ce qui casse en premier : un skill renommé côté repo
devient un dead link sur 3–4 surfaces jusqu'au prochain install.

### MINOR

**m1 — `curl | sh` pour RTK et Homebrew.** `install-main.sh:1181,1252`.
Exécution de code distant non pinné. Incohérent avec la posture SECURITY.md.
**Fix** : pinner tag/checksum ou documenter l'acceptation.

**m2 — Le mécanisme `cross_harness` est une zone morte.**
`skill-surface.tsv` : colonne `cross_harness` à 0 sur les 95 lignes. ~60 lignes
d'installeur (`install-main.sh:1626-1644` + prune 442-463) qu'aucune donnée
n'exerce en production. **Fix** : un skill l'utilise, ou ça se supprime.

**m3 — Historique git tronqué au 2026-08-14** (50 commits) alors que les ADR
datent de juillet et que des docs citent des SHA disparus (`586e6d6` dans le
scorecard). Les claims historiques (« 13 events total », baselines) ne sont
plus auditables depuis le repo. **Fait vérifié** pour les dates ; la cause
(squash/reset) est une **inférence**.

**m4 — `brew tap homebrew/cask-fonts`** (`install-main.sh:1189`) : tap
déprécié, le `|| true` le masque ; la font est dans `homebrew/cask` désormais.
**Non vérifié en ligne** (connaissance générale).

**m5 — Docs « musée » partiellement assumé.** ~10 analyses datées (4 fichiers
« top5 » du même 2026-08-01, baseline/scorecard adversary, audit 20260724 de
25K) + 104 archives `docs/plan/`. Le scorecard a un bandeau « Historical
snapshot. Not operational » — bien — mais pas tous les autres.
**Fix** : `docs/archive/` ou bandeau systématique.

### NIT

**n1 —** `harness_extract_verdict` (`etabli-harness-eval.sh:41-49`) matche
`^Verdict: GO$` n'importe où dans le transcript, dernière occurrence gagnante —
un agent qui *cite* un verdict dans son raisonnement peut être gradé dessus.

**n2 —** `readonly PI_CORE_SKILLS=($(skill_catalog_names ...))`
(`install-main.sh:22`) : word-splitting non quoté ; sûr tant que les noms de
skills n'ont pas d'espaces, jamais garanti.

---

## Réponses aux axes d'analyse

**1. Cohérence architecture** : bonne, vérifiée par échantillon. Tous les
fichiers référencés par `spec.md` existent (11/11 testés), les guards annoncés
(plan-mutation, check-freeze, ops-stop, no-progress) sont réellement mécaniques
et le dual-runtime matrix les confirme sur Pi et Claude (`confirmed` observés
dans le run `core`). La promesse « une source, trois runtimes » tient dans
`install-main.sh`. Dérives : M2 (quatre docs), m2 (mécanisme mort), et la
posture  qui est de l'infra d'éval sans données live (bloquée budget,
honnêtement étiquetée `not_established`).

**2. Complexité vs valeur (YAGNI)** : le vrai sujet. ~19,7k lignes de markdown
workflow+docs, ~27,7k lignes de scripts+tests, 24 skill contracts, pour un
utilisateur unique. Le repo *sait* qu'il sur-construit — ADR-0013 a supprimé
11k lignes de council « sized for a team evaluation harness in a
single-operator dotfiles repo », ADR-0014 a supprimé l'injection sur mesure de
tokens. Ce réflexe d'auto-correction est la meilleure qualité du projet. Mais
le stock restant est lourd : `-suite.mjs` 55,9K + smoke 20,5K pour un
benchmark dont le volet live n'a jamais tourné ; `evidence-proof` 50K ;
`program-state` 36,8K pour des « large programs » hypothétiques. **Opinion** :
le ratio prose-de-contrôle / code-qui-fait est inversé par rapport à un projet sain.

**3. Fragilité opérationnelle** : M4 en premier (dead symlinks multi-surfaces
au renommage — déjà arrivé, 39 fois). Ensuite la duplication du moteur MCP
entre `brain` et `obvault`, que l'ADR-0017 assume avec « no test detects the
drift » — une dérive silencieuse annoncée.

**4. Qualité d'exécution** : inégale mais au-dessus de la moyenne. Les fichiers
récents (oracles, `verify-agentic-infra`) sont du bash rigoureux ; le timeout
Perl `alarm+exec` (`etabli-harness-eval.sh:330-340`) est portable et correct ;
les oracles sont **réellement discriminants** (SHA byte-à-byte du fichier
interdit + allowlist porcelain dans `plan-draft-no-mutate/oracle.sh`, verdict
GO interdit dans `review-go-forbidden` — pas du grep cosmétique), avec fixtures
pass/fail synthétiques. Contre-exemples : M3, m1, n2, et B1 qui montre que le
maillon humain reste le point faible du pipeline de preuve.

**5. Sécurité** : posture correcte. SECURITY.md concret, `.mcp.json` sans
secret avec `${HOME}` portable, MCP brain read-only avec allowlist et refus de
traversal (ADR-0017), inventaire MCP par runtime honnête (ADR-0016). Reste m1
et le fait que l'installeur écrit dans les rcfiles — mais avec des rewrites awk
testés, pas des append aveugles.

**6. Dérive documentaire** : m5. Musée partiellement étiqueté, pas rangé.

---

## Avis final

### 1. Verdict en une phrase

Un système remarquablement honnête et mécaniquement solide, mais dimensionné
comme une plateforme d'équipe pour un problème de développeur solo —
l'ingénierie de la preuve y a dépassé la valeur de ce qui est prouvé.

### 2. Top 3 forces (vérifiées)

1. **La culture de preuve.** ADR 0013/0014 d'un niveau rare : décisions sur
   mesures réelles (301 tok/turn), corrections enregistrées contre soi-même
   (« the first version of this ADR claimed… a fresh-context review caught it »,
   ADR-0014:81-87), suppressions massives assumées (~11k lignes). Le README
   distingue vérifié / distillé / bloqué-non-claimé sur .
2. **Des guards réellement mécaniques, pas de la prose.**
   `planMutationGuardDecision` partagé Pi/Claude, deny paths confirmés par le
   matrix smoke ; `core` vert en 35s.
3. **Des oracles d'éval discriminants.** Final-state, binaires, alignés sur la
   référence DeepSWE : SHA du fichier interdit + allowlist des paths modifiés ;
   verdict GO littéralement interdit.

### 3. Top 3 faiblesses (vérifiées)

1. B1/M1 : le gate quotidien laisse passer un blocker le jour même où il est
   créé — la pyramide de checks a un trou à sa base.
2. M2 : quatre surfaces de contrat redondantes tenues par un test de 50K ;
   coût de synchronisation structurel.
3. M4 + volume : fan-out symlinks à croissance manuelle, déjà pris en défaut
   (39 dead links), dans un système dont ~48k lignes de tooling servent un seul
   opérateur.

### 4. Trois choses à arrêter

1. **Écrire la même règle à quatre endroits.** Fusionner quick-card dans spec
   (ou l'inverse), rétrograder le guide humain en pointeurs. Chaque règle
   dupliquée coûte un pin dans workflow-docs-smoke.
2. **Construire de l'infra d'éval en avance de phase.** / live est
   bloqué budget depuis sa création ; `program-state` (36,8K) attend des
   « large programs » hypothétiques. Le pattern que l'ADR-0013 a tué — il en reste.
3. **Le rituel de review complet sur les petits diffs.** Cross-model adversary
   + double-sample + deciding-code table + simplification pass + quality pass
   (`implementation-loop.md` étapes 12b–13b) sur chaque changement : le blind
   gate du projet (ADR-0013) n'a trouvé « no quality gain » au council. Le même
   scepticisme mérite ce pipeline — mesurer son taux de findings réels avant de
   le maintenir obligatoire.

### 5. Trois choses à faire ensuite (par ROI)

1. **Réparer B1** (une ligne) et faire calculer les pins SHA par outillage,
   jamais à la main. ROI : CI verte aujourd'hui + classe de bug éliminée.
2. **Promouvoir les smokes hermétiques rapides en `core`** (harness-eval au
   minimum). ROI : gate quotidien digne de son nom, coût <1s.
3. **Une passe ADR-0013-style sur le stock restant** : pour `-suite`,
   `program-state`, `evidence-proof`, exiger la même preuve d'usage que celle
   imposée à la télémétrie (« ≥10 real outcomes before claiming value »). Le
   critère existe déjà dans le contrat — l'appliquer au tooling lui-même.

### 6. Score : 6,5/10

| Dimension | Note | Justification |
|---|---|---|
| Cohérence | 8 | Contrat ↔ implémentation vérifiés sur échantillon ; déductions M2, m2 |
| Robustesse | 7 | Guards réels et testés ; mais B1 à HEAD, gate core partiel, M4 |
| Simplicité | 4 | Surdimensionnement massif, partiellement auto-corrigé mais toujours dominant |
| Qualité d'exécution | 7,5 | Oracles et scripts récents excellents ; M3, m1, n2 |
| Maintenabilité | 6 | Source unique + tests partout ; coût de synchro doc élevé, bus factor 1, historique tronqué |

### Écart avec `docs/adversary-etabli-10-scorecard.md`

Il conclut « solid 10 », moi 6,5. Pas un désaccord sur les faits — ses dix
dimensions mesurent la **conformité mécanique interne** (les guards
dénient-ils, les smokes passent-ils), et sur ce terrain je confirme
l'essentiel. Mais sa grille ne contient aucune dimension pour ce que je note le
plus sévèrement : rapport complexité/valeur, coût de maintenance de la prose,
charge de contexte par session. C'est le système qui se note avec ses propres
oracles sur les axes où il est fort. Deux notes divergent concrètement :
« Validation surface 9.5 / no skip-as-success » ne tient plus au vu de B1/M1
(un check hors du gate quotidien est un skip silencieux de fait), et
« Contract clarity 9.5 » ignore que la clarté est achetée en quadruple
exemplaire. À sa décharge, le document se marque lui-même « Historical
snapshot. Not operational ».

---

## Lacunes (non vérifié, non spéculé)

- `deploy-agent-workflow` (20,9K), `evidence-proof` (50K), `program-state`
  (36,8K), `workflow-event` (30K), `-suite.mjs` (55,9K) : non lus en
  profondeur — remarques limitées à leur taille et leurs références.
- Extensions Pi (`pi/extensions/`) et hooks Claude : non lus ; seule preuve,
  les tests qui les couvrent passent dans `core`.
- État live de `~/.codex`, `~/.agents` sur cette machine : non audité.
- Run CI effectif de la branche : non consulté (rouge déduit du déterminisme du check).
- `verify-agentic-infra full` complet : non exécuté en entier ; il s'arrête au
  plus tard sur B1.
- Multihost (macmini rsync, `herdr/docs/multihost.md`) : non lu — la dérive
  entre machines reste une question ouverte.
