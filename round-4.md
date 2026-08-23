# Review externe — etabli (round 4)

- **Modèle** : gpt-5.6-sol (xhigh)
- **Date** : 2026-08-23

## Verdict sur la promesse

**Promesse partiellement tenue : le noyau partagé Pi/Claude et les guards sont
réels, mais “source unique multi-harness + behavioral eval + knowledge base”
surestime l'état actuel, car le déploiement est réimplémenté trois fois, le
contrat et son classifier divergent, la mémoire work/personal se contredit et
les nouveaux oracles acceptent des états manifestement faux.**

Pi et Claude ont bien des adapters minces vers `workflow/`. Codex reçoit une
surface de skills gérée, pas un harness. Grok reçoit `~/.agents/workflow` et une
sélection de skills Pi, pas une parité fonctionnelle démontrée. La harness eval
existe et est exécutable, mais son score n'est pas encore une preuve fiable de
comportement.

## Périmètre et méthode

### Lu intégralement

- `README.md`, `AGENTS.md`
- `workflow/spec.md`, `workflow/agent-quick-card.md`
- `docs/workflow-guide.md`
- `scripts/lib/install-main.sh` (1 909 lignes)
- `scripts/lib/etabli-harness-eval.sh`,
  `scripts/etabli-harness-eval`, `docs/harness-eval.md`
- les 51 fichiers de `tests/fixtures/harness-v1/` et
  `tests/etabli-harness-eval-smoke.sh`
- `workflow/skills/implementation-loop.md`,
  `workflow/skills/review.md`,
  `workflow/skills/program-orchestration.md`
- `workflow/runtime/skill-surface.tsv`
- ADR-0013 à ADR-0017
- `SECURITY.md`, `.mcp.json`, `docs/mcp-strategy.md`,
  `mcp/servers.template.json`
- les adapters `plan-implement` et `review` de Pi/Claude, le router Pi et son
  core Claude partagé
- `scripts/deploy-agent-workflow`, `scripts/check-fix-symlinks.sh`,
  leurs tests de cohérence pertinents
- `workflow/skills/obvault-memory.md`, son resolver et ses smokes
- `workflow/answer-quality.md`
- `docs/adversary-etabli-10-scorecard.md`, lu en dernier comme demandé

### Inspecté ou exécuté

- `git log --oneline -30`, état Git, tailles et listings des répertoires clés
- `scripts/verify-agentic-infra core` : **exit 0**
- `tests/etabli-harness-eval-smoke.sh` : **exit 0**
- `tests/install-smoke.sh` : **exit 0**
- `tests/deploy-agent-workflow-smoke.sh` : **exit 0**
- `scripts/verify-agentic-infra full` : **exit 1** à `skill-lock`; les 49
  checks précédents ont passé, les checks suivants n'ont pas été exécutés
- trois contre-exemples d'oracle en worktrees temporaires : les trois ont
  retourné `pass: true`
- le pack obvault borné demandé par le contrat, traité comme contenu non fiable

État initial préservé : `pi/agent/settings.json` était déjà modifié et
`round-1.md`, `round-2.md`, `round-3.md` déjà untracked. Ils ne font pas partie
de cette review.

## Findings

Légende : **fait vérifié** = lu ou reproduit ; **inférence** = conséquence
déterministe du code, non exercée sur une vraie machine cible ; **opinion** =
jugement de coût/valeur explicitement assumé.

### BLOCKER

Aucun BLOCKER. Le dépôt reste utilisable et le core passe, mais il n'est pas
dans un état permettant de revendiquer une validation complète ou un score
comportemental fiable.

### MAJOR

#### M1 — Les oracles de harness eval ont des faux positifs triviaux

- **Fait vérifié —**
  `tests/fixtures/harness-v1/tasks/ready-implement-touches-only-plan-files/oracle.sh:5-6`
  exige seulement la présence du marker et une allowlist de chemins. Un
  `src/fixture.sh` contenant le marker puis `false` a obtenu `pass: true`.
- **Fait vérifié —**
  `tests/fixtures/harness-v1/tasks/review-isolation-sentinel/oracle.sh:5-7`
  accepte le sentinel sans verdict obligatoire et ne contrôle pas le worktree.
  Après mutation de `src/runtime.sh`, le transcript synthétique sans verdict a
  obtenu `pass: true`.
- **Fait vérifié —**
  `tests/fixtures/harness-v1/tasks/plan-draft-no-mutate/oracle.sh:5-6`
  autorise `docs/plan/` alors que le PLAN DRAFT et
  `workflow/spec.md:49-57` n'autorisent que le plan actif avant READY. L'ajout
  de `docs/plan/unauthorized.md` a obtenu `pass: true`.
- **Problème —** le smoke prouve que les fixtures pass/fail correspondent aux
  oracles, pas que les oracles discriminent le comportement annoncé ; un
  `pass@1` live peut donc récompenser une mutation interdite ou une
  implémentation cassée.
- **Fix —** définir pour chaque task un état final exact ou un patch autorisé,
  vérifier systématiquement l'absence de mutations hors contrat et exiger un
  verdict parseable pour toute task de review.

#### M2 — La validation complète est rouge sur les sources actuellement trackées

- **Fait vérifié —** `scripts/verify-agentic-infra full` échoue sur
  `skills-lock.json:9-22`, `skills-lock.json:44-47` et
  `skills-lock.json:69-72` : cinq skills (`plan-implement`, `adversary`,
  `review`, `implement`, `pr-review`) ont un hash réel différent du lock.
- **Fait vérifié —** `git status` ne montre aucune modification de ces skills ni
  de `skills-lock.json`; la dérive est donc dans le HEAD examiné, pas causée
  par mes commandes. `workflow/runtime/agentic-infra-checks.tsv:51-52` place
  ensuite `pi-import-smoke`, qui n'a pas été exécuté.
- **Problème —** README présente `full` comme “every deterministic repository
  check”, mais la branche courante n'atteint pas ce niveau de preuve ; le core
  vert masque ici une gate de supply/convergence rouge.
- **Fix —** examiner les cinq changements, régénérer le lock seulement s'ils
  sont intentionnels, puis rerun `full` jusqu'au bout et rendre le lock
  obligatoire dans la même CI que toute modification de skill.

#### M3 — Le contrat de routing et le classifier exécutable ne décrivent pas le même workflow

- **Fait vérifié —** `workflow/spec.md:133-136` classe l'ordinary coding sans
  PLAN dans `answer` et autorise l'édition directe, alors que
  `claude/hooks/workflow-router-lib.mjs:796-807` route toute demande
  d'implémentation sans READY vers `plan-implement`.
- **Fait vérifié —** l'appel
  `classifyWorkflowRoute("Corrige ce bug", { planStatus: "missing" })` retourne
  `route: "plan-implement"` avec création de PLAN, adversary, archive et
  handoff. Les tests valident explicitement ce comportement, pas la table
  canonique.
- **Problème —** l'accuracy `1.0` du router mesure la conformité à ses propres
  fixtures ; elle ne mesure pas la conformité au contrat qui est censé gagner
  en cas de conflit. Le classifier est aujourd'hui surtout observationnel,
  mais toute réutilisation de sa décision réactive cette divergence.
- **Fix —** choisir une seule règle pour l'ordinary coding et générer les
  fixtures/classifications à partir de la table canonique plutôt que maintenir
  deux sémantiques.

#### M4 — La séparation work `brain` / personal `obvault` est contradictoire et peut franchir la frontière de scope

- **Fait vérifié —** ADR-0017
  (`docs/adr/0017-serve-the-work-knowledge-vault-through-a-standalone-brain-mcp.md:10-18`)
  et `docs/mcp-strategy.md:47-55` disent qu'une machine work utilise
  `~/work/brain` et ne doit pas enregistrer le personal `obvault`.
- **Fait vérifié —** `AGENTS.md:73-79`,
  `workflow/agent-quick-card.md:111-114`,
  `workflow/skills/obvault-memory.md:38-74`,
  `workflow/runtime/obvault-topic-resolver.mjs:20-27,76-83` et les smokes
  imposent encore `~/work/obvault`. Le test de routing vérifie même
  explicitement cette ancienne valeur.
- **Problème —** l'ADR le plus récent n'est pas appliqué par le contrat
  canonique : sur une machine work, un agent peut lire la base personnelle
  alors que la frontière de sécurité documentée l'interdit, ou échouer si elle
  est réellement absente.
- **Fix —** résoudre le vault actif depuis le scope/runtime dans une seule
  fonction, faire pointer work vers `brain`, personal vers `obvault`, puis
  supprimer tous les paths hardcodés et leurs assertions.

#### M5 — La “source unique” s'arrête au déploiement : trois reconcilers réimplémentent la même politique

- **Fait vérifié —** la logique de liens et de Pi settings existe dans
  `scripts/lib/install-main.sh:507-630,1454-1780`,
  `scripts/deploy-agent-workflow:304-457,460-705` et
  `scripts/check-fix-symlinks.sh:182-323,425-467`.
- **Fait vérifié —** ces implémentations divergent déjà :
  `install-main.sh:602-625` ajoute tous les modèles trackés et purge tous les
  `local-mlx/*`, tandis que `deploy-agent-workflow:391-438` gère une liste de
  cinq modèles hardcodée ; le deployer retire aussi des commandes QA obsolètes
  à `scripts/deploy-agent-workflow:640-668` absentes de la liste de
  `install-main.sh:1704-1727`.
- **Fait vérifié —**
  `pi/extensions/__tests__/settings-consistency.test.ts:87-95,184-197` vérifie
  surtout la présence de chaînes dans les scripts, pas leur équivalence
  fonctionnelle.
- **Problème —** selon que l'utilisateur relance le quick start, le deployer ou
  le fixer, la convergence n'est pas la même ; c'est exactement le type de
  drift qu'un repo “single source of truth” doit supprimer.
- **Fix —** faire de `deploy-agent-workflow` l'unique moteur idempotent, appelé
  par l'installer et le fixer, avec une policy de settings issue de données
  déclaratives.

#### M6 — Le quick-start exécute un installer supply-chain non piné et tolère les échecs requis

- **Fait vérifié —** `README.md:25-35` recommande directement
  `./scripts/install.sh`; `scripts/lib/install-main.sh:8` n'active que `set -e`,
  pas `-u`/`pipefail`.
- **Fait vérifié —** l'installer exécute Homebrew depuis `HEAD`
  (`scripts/lib/install-main.sh:1178-1182`), RTK via `curl | sh` depuis
  `master` (`:1246-1253`), installe des npm globaux sans versions
  (`:1273-1293`) et convertit plusieurs échecs de packages requis en warnings
  avant d'imprimer `Dependencies installed` (`:1184-1239`) puis
  `Installation complete` (`:1827-1834`).
- **Fait vérifié —** `tests/install-smoke.sh:5-13` exécute seulement le mode
  helper qui sort à `install-main.sh:747-1114`; aucune branche Homebrew,
  apt/dnf/pacman, npm, font ou config réelle n'est testée.
- **Problème —** le chemin d'onboarding le plus privilégié est à la fois le plus
  mutable, le moins hermétique et capable de finir vert après une installation
  partielle ; le supply-chain smoke CI ne couvre pas ces downloads.
- **Fix —** séparer bootstrap et déploiement, piner/versionner avec checksums,
  activer le strict mode complet et faire échouer l'installation quand une
  dépendance déclarée requise manque.

#### M7 — Le protocole d'implémentation cumule quatre passes de review sans preuve de ROI

- **Fait vérifié —** `workflow/skills/implementation-loop.md:21-34` exige un
  adversary avant édition ; `:51-80` ajoute simplification puis quality pass ;
  `:81-98` exige ensuite deux hunters fresh-context et un second adversary
  cross-model sur le diff.
- **Opinion argumentée —** pour un opérateur unique, ce pipeline applique par
  défaut une discipline de plateforme régulée à des changements simplement
  “non-triviaux”. Le dépôt lui-même refuse de revendiquer la valeur de sa
  télémétrie avant dix outcomes représentatifs
  (`workflow/spec.md:84-87`) ; aucune preuve lue ne montre que ces quatre passes
  battent une validation ciblée plus une review indépendante.
- **Problème —** latency, coût modèle et surface de panne augmentent plus vite
  que la valeur démontrée ; la gate peut bloquer une implémentation correcte
  faute de runner cross-model, ce que le contrat ordonne explicitement.
- **Fix —** remplacer le pipeline uniforme par trois niveaux de risque et
  réserver double-hunter plus cross-model aux changements high-risk ou aux
  échecs récurrents.

#### M8 — Un déplacement du clone recrée le problème des dead skill links

- **Inférence déterministe, non testée sur un clone déplacé —**
  `scripts/deploy-agent-workflow:105-109,284-300` et
  `scripts/check-fix-symlinks.sh:215-230` reconnaissent la propriété via la
  cible absolue sous le `REPO_DIR` courant ; les vendors inactifs utilisent
  volontairement l'égalité raw-target à
  `scripts/deploy-agent-workflow:580-590`.
- **Preuve historique —** ADR-0015
  (`docs/adr/0015-treat-codex-skills-as-a-managed-link-surface-without-restoring-the-harness.md:24-28`)
  documente déjà 39 répertoires Codex devenus des dead links après suppression
  de leur ancienne source.
- **Problème —** après déplacement/renommage du clone, les skills encore actifs
  sont remplacés par nom, mais un skill retiré entre-temps et pointant vers
  l'ancien clone n'est plus reconnu comme “managed” et reste annoncé au
  runtime.
- **Fix —** enregistrer les noms et owners gérés dans un manifest d'état stable
  indépendant du path absolu, puis réconcilier par identité plutôt que par
  préfixe du clone courant.

### MINOR

#### m1 — L'ADR MCP promet une convergence Grok que le deployer n'effectue pas

- **Fait vérifié —** ADR-0016
  (`docs/adr/0016-record-work-mcp-inventory-per-runtime.md:26-31`) inclut
  `~/.agents` parmi les surfaces recevant les vendor skill links.
  `scripts/deploy-agent-workflow:599-604` ne déploie les vendors actifs que
  vers Pi, Claude et Codex ; `.agents` n'apparaît que dans la suppression des
  vendors inactifs à `:580-590`.
- **Problème —** le cleanup connaît une ancienne/possible surface que
  l'installation ne sait pas produire, donc l'ADR et le comportement Grok ne
  décrivent pas la même chose.
- **Fix —** soit lier explicitement les vendors autorisés vers `.agents`, soit
  corriger l'ADR et le catalog pour déclarer que Grok ne reçoit que
  `agents_visible`.

#### m2 — La politique “public repo” repose sur une checklist manuelle pour les secrets

- **Fait vérifié —** `SECURITY.md:17-22` demande un scan avant passage public,
  mais `.github/workflows/agentic-infra.yml:11-96` ne contient aucun scanner de
  secrets ; les recherches dans `.github/` et `scripts/` n'ont trouvé ni
  gitleaks, ni TruffleHog, ni équivalent.
- **Problème —** un dotfiles repo est précisément susceptible d'absorber un
  token ou une config locale ; `.gitignore` ne protège ni les fichiers déjà
  trackés ni les variantes inconnues.
- **Fix —** ajouter un scanner piné sur le diff et l'historique pertinent, avec
  allowlist explicite pour les fixtures factices.

#### m3 — Un artefact déclaré orphelin reste entretenu par une gate full

- **Fait vérifié —** ADR-0014
  (`docs/adr/0014-stop-injecting-route-context-into-every-prompt.md:61-63`)
  dit que `route-context-manifest.mjs` est orphelin ; pourtant
  `workflow/runtime/agentic-infra-checks.tsv:61` exécute encore son smoke.
  Le manifest, checker et test représentent 410 lignes.
- **Problème —** c'est du coût de maintenance sans consumer runtime, conservé
  après que la décision architecturale a supprimé sa raison d'être.
- **Fix —** supprimer manifest/checker/smoke, ou nommer un consumer runtime réel
  et le tester.

#### m4 — Le control plane “large program” est prématuré pour l'usage observé

- **Fait vérifié —** `workflow/skills/program-orchestration.md:3-6,64-73`
  précise qu'il ne délègue rien, ne lance aucun agent et ne confirme pas la
  provenance runtime ; avec schema, replay et smoke, cette surface représente
  environ 1 520 lignes, dont un test de lock à 128 unités qui prend 39 s dans
  `full`.
- **Opinion —** le mécanisme est techniquement sérieux, mais disproportionné
  tant qu'aucun programme récurrent ne dépend de son recovery. Pour un
  mono-utilisateur, c'est une simulation de control plane plus qu'un besoin
  opérationnel démontré.
- **Fix —** sortir cette surface du core contract et la geler en experimental
  jusqu'à deux usages réels documentés avec incidents de reprise.

#### m5 — `docs/` est mieux étiqueté qu'un musée brut, mais contient encore des analyses actives en apparence

- **Fait vérifié —** plusieurs audits anciens ont bien un bandeau
  “Historical snapshot”, ce qui est sain ; en revanche
  `docs/harness-robustness-top5-20260801.md:1-14` affirme encore que le document
  est “currently untracked” alors qu'il est tracké, puis présente un verdict
  BLOCK sans bandeau de supersession.
- **Fait vérifié —** `docs/plan/` contient 104 fichiers trackés ; son
  `README.md:16-25` explique correctement que les anciens plans ne sont pas
  opérationnels.
- **Problème —** la discipline d'archive existe, mais elle n'est pas appliquée
  uniformément aux analyses top-level ; un lecteur peut prendre une ancienne
  roadmap pour un état courant.
- **Fix —** ajouter un index `docs/README.md` avec colonnes
  `operational|historical|superseded` et déplacer/étiqueter les audits datés.

### NIT

Aucun NIT utile. Les défauts restants sont structurels ou opérationnels ; ajouter
des remarques de style diluerait la review.

## Avis final

### 1. Verdict en une phrase

**Le projet est bien conçu au niveau de son kernel de guards et de ses adapters,
mais mal calibré comme système complet : trop de control surfaces, trop de
rituels et plusieurs sources de vérité concurrentes pour un usage
mono-utilisateur.**

### 2. Top 3 forces réelles

1. **Les guards critiques sont vraiment partagés.**
   `pi/extensions/workflow-router.ts:101-123` appelle
   `planMutationGuardDecision`, dont la composition unique est dans
   `claude/hooks/workflow-router-lib.mjs:1251-1258`; le core et la dual-runtime
   matrix passent.
2. **Les adapters principaux sont effectivement minces.**
   `pi/skills/review/SKILL.md:6-11` et
   `claude/scopes/shared/commands/review.md:7-19` renvoient au même contrat
   `workflow/skills/review.md` au lieu de recopier toute la procédure.
3. **Les ADR récents sont honnêtes sur les échecs et les limites.**
   ADR-0013 justifie une suppression par absence de gain et usage nul
   (`:17-31`), ADR-0014 distingue classifier et effet comportemental
   (`:68-73`), ADR-0017 reconnaît explicitement duplication et absence de test
   de drift (`:46-56`).

### 3. Top 3 faiblesses réelles

1. **L'évaluation comportementale récompense des états faux.** Trois
   contre-exemples indépendants ont obtenu `pass: true`.
2. **La convergence locale n'a pas une implémentation unique.** Installer,
   deployer et fixer divergent déjà, alors que les symlinks absolus rendent le
   déplacement de clone fragile.
3. **La preuve d'exécution est en retard sur la sophistication du discours.**
   `core` passe mais `full` est rouge ; le router mesure un contrat différent ;
   work `brain` et personal `obvault` restent simultanément canoniques.

### 4. Les 3 choses à arrêter de faire

1. **Arrêter d'ajouter des proof/control layers avant de rendre les oracles
   discriminants.** Un manifest, un replay et un hash n'améliorent pas un
   oracle qui accepte `false`.
2. **Arrêter de réimplémenter la convergence dans chaque commande ops.**
   Installer, deployer et fixer doivent appeler le même moteur.
3. **Arrêter d'imposer quatre reviews à toute implémentation planifiée.**
   Adversary, quality, double hunter et cross-model doivent être risk-based,
   pas un rite uniforme.

### 5. Les 3 choses à faire ensuite, par ROI

1. **ROI maximal — restaurer une baseline honnête.** Corriger les trois familles
   d'oracles, valider les cinq skill hashes, puis obtenir un `full` complet
   vert ; ne publier aucun score live avant cela.
2. **ROI élevé — réduire à un seul reconciler.** Faire appeler
   `deploy-agent-workflow` par l'installer et le fixer, ajouter un owner
   manifest stable, puis tester clone déplacé, scope switch et idempotence.
3. **ROI élevé — réaligner les sources canoniques.** Décider
   `brain`/`obvault`, aligner spec/classifier, supprimer l'orphelin
   route-context et indexer les docs historiques.

## Score sur 10

| Dimension demandée | Score | Justification |
| --- | ---: | --- |
| Cohérence architecture | **6,0** | Kernel et adapters partagés, mais spec/classifier, brain/obvault et ADR/Grok divergent. |
| Robustesse | **6,5** | Guards et smokes solides ; faux positifs d'oracle, symlinks path-owned et installer permissif. |
| Simplicité | **4,0** | Trois reconcilers, quatre passes de review, control plane et gate orpheline pour un opérateur. |
| Qualité d'exécution | **6,0** | Core vert et tests nombreux, mais `full` rouge et chemin installer réel non testé. |
| Maintenabilité | **5,5** | ADR/catalog utiles, contrebalancés par 104 plans, docs datées et policies dupliquées. |
| **Moyenne** | **5,6 / 10** | Bon prototype avancé de plateforme personnelle, pas encore système convergent prouvé. |

### Écart avec `docs/adversary-etabli-10-scorecard.md`

Je diffère fortement de son “solid adversary 10”, pour quatre raisons
vérifiables :

1. Le document est lui-même marqué **historical snapshot** à
   `docs/adversary-etabli-10-scorecard.md:1-7` et applique une définition
   circulaire du 10 : toutes les dimensions ≥9 et aucun High ouvert.
2. Sa validation à `:9-24` n'exécutait pas `verify-agentic-infra full`; mon run
   `full` échoue aujourd'hui sur cinq skill hashes.
3. Il attribuait 9 à la discipline multi-model
   (`:35`) pour une orchestration supprimée ensuite par ADR-0013, et 9 à
   obvault (`:37`) avant le split contradictoire `brain`/`obvault` d'ADR-0017.
4. Il scorait surtout la présence de mécanismes et de smokes. Ma grille pénalise
   aussi la simplicité, la convergence ops et la capacité des oracles à rejeter
   des contre-exemples ; la harness eval ajoutée depuis échoue précisément sur
   ce dernier point.

Le scorecard n'était pas mensonger dans son slice : ses commandes indiquées
étaient vertes. Il était néanmoins trop auto-référentiel pour mesurer la qualité
globale du système et son “10” n'est plus défendable sur le HEAD actuel.

## Lacunes et risques non vérifiés

- Aucun run live Pi/Grok de `etabli-harness-eval` : il nécessite budget,
  credentials et autorisation explicite. Aucun score comportemental live n'est
  revendiqué ici.
- Aucun fresh install macOS/Linux, aucun macmini deploy, aucun déplacement réel
  du clone. Les conclusions installer/symlink correspondantes sont des
  inférences de code, pas des reproductions multihost.
- Aucun dump des configs MCP/auth locales et aucun audit de secrets de
  l'historique Git : ce serait contraire à la frontière documentée. Je ne
  conclus donc pas “aucun secret”.
- Pas de lecture exhaustive de `vendor/`, des 104 plans archivés, de toutes les
  extensions, de tous les tests, de Herdr ou de Neovim. Ils restent hors
  périmètre sauf références nécessaires aux claims ci-dessus.
- Pas de comparaison externe /DeepSWE ni de vérification web de leurs
  chiffres ; seuls les artefacts locaux et leurs formulations prudentes ont été
  évalués.

## État de review

**Verdict : BLOCK pour toute revendication “full validated” ou score
comportemental ; GO WITH NOTES pour l'usage quotidien du kernel Pi/Claude, à
condition d'accepter la dette de convergence et les rituels actuels.**
