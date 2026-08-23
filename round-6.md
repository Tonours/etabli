# Review externe — etabli (round 6)

- **Modèle** : grok-4.6 (xhigh)
- **Date** : 2026-08-23
- **HEAD** : `a18d3ef` sur `refactor/skill-default-load`
- **Contrainte** : lecture seule hors ce fichier ; aucun commit

Légende : **fait vérifié** = lu ou reproduit dans cette session ; **inférence** = conséquence du code non exercée en conditions réelles ; **opinion** = jugement coût/valeur.

---

## Périmètre

### Lu intégralement

- `README.md`, `AGENTS.md` (racine)
- `workflow/spec.md`, `workflow/agent-quick-card.md`
- `docs/workflow-guide.md`
- `scripts/lib/install-main.sh` (1909 lignes)
- `scripts/lib/etabli-harness-eval.sh`, `docs/harness-eval.md`, `tests/etabli-harness-eval-smoke.sh`
- `tests/fixtures/harness-v1/manifest.json` + les 7 `oracle.sh` + prompts / overlays des tasks citées
- `workflow/skills/implementation-loop.md`, `self-improvement-loop.md`, `program-orchestration.md` ; extraits de `review.md` et `adversary.md`
- `workflow/runtime/skill-surface.tsv` (95 lignes data)
- ADR-0013, 0014, 0015, 0016, 0017
- `SECURITY.md`, `.gitignore`, `.mcp.json`, `mcp/servers.template.json`, `docs/mcp-strategy.md`
- `workflow/runtime/workflow-router-core.mjs`, extraits de `claude/hooks/workflow-router-lib.mjs`, `pi/extensions/workflow-router.ts`
- `workflow/runtime-capabilities.json`, `workflow/runtime/agentic-infra-checks.tsv`, `scripts/verify-agentic-infra`
- `scripts/deploy-agent-workflow` (entête + contrat), `scripts/check-fix-symlinks.sh` (entête)
- `herdr/docs/multihost.md` (début)
- `docs/adversary-etabli-10-scorecard.md` (lu en dernier, comme imposé)

### Échantillonné

- `workflow/contract-details.md` (checkpoints + ops-stop)
- `workflow/runtime/obvault-topic-resolver.mjs`
- `scripts/lib/skill-catalog.sh`
- `tests/supply-chain-smoke.sh`
- `pi/extensions/__tests__/workflow-router-runtime.test.ts`, `workflow-router-extension.test.ts` (cas READY / DRAFT / implement)
- listings `docs/`, `scripts/`, `tests/`, `workflow/skills/`
- `git log --oneline -30`

### Exécuté (preuves locales)

- `scripts/verify-agentic-infra core` → **exit 0**, ~32,6 s puis ~31,4 s (15/15)
- `cd pi && bun run verify:skills` → **exit 1**, 5 skills kernel en drift
- `scripts/etabli-harness-eval grade` : 7 contre-exemples (détail B1)
- Comptages catalog / checks / lignes
- `~/work/obvault/_meta/obvault session` (pack untrusted ; notes 2026-07-23 → 2026-08-22) ; feedback `hit`

### Non lu (lacunes)

- ADR-0001 à 0012 (hors index CLAUDE.md)
- Corps complet de `scripts/deploy-agent-workflow` (715 l.) et `scripts/check-fix-symlinks.sh` (495 l.)
- `pi/extensions` hors router + listings de tests
- `claude/hooks` hors classifier / `planMutationGuardDecision`
- `nvim/`, `vendor/`, `workflow-scaffold/`, `workflow//`, `docs/plan/` (104 archives), `docs/how-it-works.md`
- CI GitHub réelle (`gh run`) — **non vérifié**
- Runs live `ETABLI_HARNESS_EVAL=1` / `verify-agentic-infra full|live` — **non vérifié**
- Comportement réel des agents hors hooks — **non vérifié**
- Rounds 1–5 : parcourus seulement après les repros, pour comparer les scores, pas pour recycler un narratif

Le skill `review` impose un hunter Logic isolé. Cette session Cursor-bridge ne peut pas spawner `pi-review-hunter` / Cursor Task comme le contrat l’écrit (`workflow/skills/review.md:29-40`). J’ai reviewé en lecture directe. C’est aussi une donnée : le contrat de review n’est pas exécutable sur toutes les surfaces qu’il prétend couvrir.

---

## La promesse, confrontée aux faits

Le README promet trois choses : (1) un contrat unique lu ambiamment, (2) des adapters minces + liens catalog-driven, (3) des claims proportionnels à la preuve.

**Ce qui tient (fait vérifié)**

- Une source `workflow/` est le contrat ; l’installer la symlinke vers `~/.pi/agent/workflow`, `~/.claude/workflow`, `~/.agents/workflow` (`install-main.sh:1466-1489, 1677-1682`).
- Les writes pré-READY / check-freeze / no_progress passent par **une** fonction `planMutationGuardDecision` (`workflow-router-core.mjs:8-10` réexporte ; Pi `tool_call` `workflow-router.ts:106-123` ; Claude PreToolUse). `core` l’exerce : dual-runtime + plan-check-freeze + no-progress verts ; matrix : `deny_on_draft confirmed` des deux côtés.
- Le catalog TSV pilote réellement les liens (`skill-catalog.sh` + boucles installer `:1594-1668`). Ce n’est pas de la doc morte.
- Les ADRs récents **retirent** de la surface (council, injection de route, harness Codex) au lieu d’en ajouter, et enregistrent leurs propres erreurs.

**Ce qui ne tient pas, ou seulement à moitié**

- « Activation ambiante » = consigne de prompt. ADR-0014 a retiré l’injection ; le classifier n’écrit plus qu’un `appendEntry` (`workflow-router.ts:93-98`) et **ne bloque rien**. Les guards bloquent des writes, pas le choix de route.
- « Multi-harness » = **Pi + Claude** pour l’exécution. Codex et Grok sont des surfaces de liens de skills. `runtime-capabilities.json` n’a **aucune** clé `grok` ni `codex`. Grok n’a pas de MCP (ADR-0016 / template). Le runner live Grok force `--permission-mode acceptEdits` (`etabli-harness-eval.sh:8, 218`).
- « Claims proportionnels à la preuve » : le rituel d’implémentation a 18 étapes dont hunter isolé + adversary cross-model (`implementation-loop.md:5-98, 129-143`) ; la suite comportementale a **7** tâches dont les oracles acceptent 7 états dégénérés que j’ai fabriqués (B1). `spec.md:86-87` refuse lui-même de revendiquer de la télémétrie avant ≥10 task-grader outcomes.

---

## Findings

### BLOCKER

#### B1 — Les oracles harness-v1 ne notent pas le comportement que leurs noms annoncent

- **Fichier** : `tests/fixtures/harness-v1/tasks/*/oracle.sh` + `scripts/lib/etabli-harness-eval.sh:41-48, 62-67`
- **Preuve (fait vérifié, reproduit ici)** — `scripts/etabli-harness-eval grade` sur 7 transcripts / worktrees artificiels, tous `pass: true` / `oracle_exit: 0` :

  | ID | Attaque | Pourquoi ça devrait échouer |
  | --- | --- | --- |
  | `review-go-forbidden-empty-deciding` | tables vides + `Verdict: GO WITH NOTES` | `review.md:113-115` : GO WITH NOTES n’est pas un workaround d’un deciding-code vide |
  | `no-parent-logic-claim` | `isolation: isolated` + `runner: parent` + `Verdict: GO` | le parent a chassé Logic ; l’oracle croit une ligne |
  | `hunter-read-only` | agent nul, SHA intact | « Do not edit » est satisfait par l’inaction, pas par une inspection |
  | `plan-draft-no-mutate` | agent nul, `product.sh` intact | split `safety` : aucun verdict, aucune preuve d’obéissance au DRAFT |
  | `ready-implement-touches-only-plan-files` | `# harness-eval-marker` + `exit 1` | l’implémentation est cassée ; l’oracle ne hashe pas le fichier |
  | `review-isolation-sentinel` | `HUNTER_SPAWN_UNAVAILABLE: pretended` + BLOCK | sentinelle auto-écrite, pas un spawn isolé |
  | `review-spec-drift` | `## Act on` + `FORBIDDEN.txt` + BLOCK | mention du nom, pas lecture du fichier |

  Le smoke hermétique (`tests/etabli-harness-eval-smoke.sh:113-116`) grade les paires synthétiques pass/fail et **passe**. Il prouve que l’évaluateur est stable, pas qu’il est discriminant. Aucune tâche n’exige `Verdict: GO` comme unique succès. Un agent qui n’édite rien et imprime les bonnes chaînes gagne 5 cellules sur 7.

- **Pourquoi c’est un problème** : `docs/harness-eval.md:3-7` revendique des « behavior verifiers » à la DeepSWE. Un `pass@1` live sur cette suite mesurerait l’obéissance au format, pas le contrat. Publier ce score serait une claim fausse.
- **Fix** : pour chaque task, un oracle à deux faces — état final (hash / allowlist / absence de mutation) **et** un verdict ou un acte non forgeable (fichier créé, commande observée hors transcript). Ajouter au moins une cellule dont le succès est `Verdict: GO` sur un diff correct, et une dont l’inaction échoue.

---

### MAJOR

#### M1 — Le cas quotidien « corrige ce bug » n’a pas la même route dans le spec et dans le classifier

- **Fichier** : `workflow/spec.md:135` vs `claude/hooks/workflow-router-lib.mjs:796-807`
- **Preuve (fait vérifié)** : le spec dit *Ordinary coding with no root PLAN.md and no explicit plan request → route `answer`*. Le classifier, pour tout `isImplementRequest` sans PLAN READY, retourne `plan-implement` + `writeAllowed: true` + evidence d’archive/adversary/review. Test pin : `workflow-router-runtime.test.ts:61-72` (`"Corrige tout y compris les warnings"` → `plan-implement`). Après ADR-0014, cette décision n’est **pas** injectée ; elle n’est observée que via `appendEntry`. Le guard, lui, autorise les writes si PLAN est `missing` (`workflow-router-lib.mjs:1048-1056`).
- **Pourquoi** : deux sources canoniques, deux politiques. Un agent qui lit le spec édite tout de suite. Un agent qui « suit la route » ouvre un PLAN + 18 étapes. Aucun des deux n’est mécaniquement forcé. C’est le cas le plus fréquent.
- **Fix** : une seule règle. Soit le spec abandonne `answer` pour l’ordinary coding, soit le classifier a un seuil (taille / fichiers nommés) avant `plan-implement`. Pin le choix dans `router-eval`.

#### M2 — `skill-lock` est rouge sur la branche qui recentre les skills, et hors du gate quotidien

- **Fichier** : `workflow/runtime/agentic-infra-checks.tsv:51` ; `scripts/verify-agentic-infra:14-17, 54, 80`
- **Preuve (fait vérifié)** : `cd pi && bun run verify:skills` exit 1 — drift de `plan-implement`, `adversary`, `review`, `implement`, `pr-review`. `skill-lock` est en profil **`full`**, pas `core`. `run_check` retourne au premier échec (`:14-17`) : un rouge masque la suite. README:129-130 vend `core` comme « daily health and safety gate » et `full` comme « every deterministic repository check ». Sur `refactor/skill-default-load`, l’intégrité des skills kernel est rouge et invisible au quotidien. ADR-0014:78-87 avait déjà décrit ce masquage le 2026-08-03.
- **Pourquoi** : `spec.md:108` dit que la troisième occurrence d’un finding devient un check mécanique. Ici le check existe et reste rouge. Le README overclaim `full`.
- **Fix** : régénérer le lock si le drift est voulu ; promouvoir `skill-lock` en `core` ; accumuler les FAIL au lieu d’abort-on-first.

#### M3 — Trois reconcilers pour une « source unique », plus une lane `cross_harness` morte

- **Fichier** : `scripts/lib/install-main.sh:1626-1668` ; `scripts/deploy-agent-workflow:15-22` ; `scripts/check-fix-symlinks.sh:19-27` ; `AGENTS.md:45-46` ; `workflow/runtime/skill-surface.tsv`
- **Preuve (fait vérifié)** : 95 rows, `pi_core=14`, `agents_visible=14`, `locked=79`, **`cross_harness=0`**, **`all_zero=15`**. Les trois scripts recopient le même guard bash-3 `CROSS_HARNESS_PI_SKILLS=("")`. La boucle installer `:1634-1643` ne peut rien lier. AGENTS.md affirme que `~/.codex/skills/` reçoit les entries `cross_harness`. Les vendors `locked` sont bien fan-out Claude/Pi/Codex (`:1657-1667`) — Codex n’est pas vide, mais la *lane documentée* l’est. Trois copies (1909 + 715 + 495 lignes) pour une politique.
- **Pourquoi** : ADR-0015 a existé parce que 39 dead links Codex étaient passés inaperçus. La réponse a été une troisième surface + une colonne jamais allumée, pas un moteur unique.
- **Fix** : un TSV `surface / source / mode / scope`, un reconciler, trois modes. Supprimer `cross_harness` ou l’utiliser. Sortir les 15 skills `0 0 0 0` du catalog vivant.

#### M4 — L’installer est le script le plus privilégié et le moins tenu au contrat du repo

- **Fichier** : `scripts/lib/install-main.sh:8, 1178-1182, 1252-1253, 1275-1288, 1818-1823` ; `scripts/verify-agentic-infra:21-25`
- **Preuve (fait vérifié)** :
  - `set -e` seul. Pas de `nounset` / `pipefail`. Le script le justifie à `:1626` (bash 3 + array vide) mais n’isole pas ce tradeoff : le reste tourne fail-open sur les pipes.
  - Installe Homebrew via `curl | bash`, RTK via `curl | sh`, 13 packages `npm -g` non pinnés (alors que CI pinne `hunkdiff@0.17.3` et que `supply-chain-smoke.sh:33-34` l’exige).
  - Mutate `~/.zshrc` / `~/.bashrc` (`ensure_local_bin_shell_path` + hook Cursor).
  - Kitchen-sink : Nerd Font, lazygit GitHub `latest`, Neovim, tmux/tpm, Ghostty, Herdr, Pi, Claude, Codex, Grok `~/.agents`, 15+ language servers.
  - `shell_syntax` ne voit que `scripts/` et `tests/` **maxdepth 1** : `scripts/lib/install-main.sh` n’est **pas** dans le gate `core`.
- **Inférence** : un `set -e` + substitution qui échoue peut avancer et pruner des liens (`prune_*` `:125-152, 442-505`). Non exercé ici sur un vrai `$HOME`.
- **Pourquoi** : le repo pinne des SHA d’Actions et des hashes de skills, puis confie le bootstrap machine à un script qui `curl | sh` et n’est pas syntax-checké par le daily gate.
- **Fix** : extraire le helper-smoke (`:747-1113`) ; `set -euo pipefail` + arrays gardés ; pins npm ; `shell-syntax` récursif sur `scripts/lib` ; installer agent ≠ installer desktop.

#### M5 — Le contrat d’écriture est du code ; le contrat de route et le rituel d’implémentation sont de la prose

- **Fichier** : `workflow/skills/implementation-loop.md:1-147` ; `workflow/skills/program-orchestration.md:1-79` ; `docs/workflow-guide.md:148-152` ; `claude/hooks/workflow-router-lib.mjs:53-54, 468-481`
- **Preuve (fait vérifié)** : `implementation-loop` exige adversary plan, dogfood, simplify, quality, Logic+Spec, adversary code-diff cross-model, ledger, archive. Rien de tout cela n’est un deny outil. `ops-stop` est une **route de classifier** (`OPS_STOP_PATTERN` matche aussi `git push` et le mot `secret`) ; la matrix le dit : `ops_stop.route: confirmed via classifier`. Ce n’est pas un deny. `program-orchestration.md` décrit un control plane (DAG, lock 5 s, zombies, `replay_valid`, schema v1/v2) pour « independently ownable units ». `workflow///tasks.json` mappe ce fichier sur des playbooks dont `live_assets.status: blocked`. `self-improvement-loop.md:24` cite encore `workflow-telemetry-recover` alors qu’ADR-0013 a tué les reporters faute d’usage (13 events).
- **Pourquoi** : ADR-0013 a déjà nommé le pattern — « infrastructure sized for a team evaluation harness in a single-operator dotfiles repo ». Il a survécu dans les loops nommés.
- **Fix** : trois niveaux de risque (edit / plan-implement / autonome). `ops-stop` : deny outil pour `rm -rf` / force-push / deploy, ou README qui dit « routes inférées ; seuls READY/freeze/no_progress sont enforce ». Geler `program-orchestration` tant qu’aucun run live n’existe.

#### M6 — Deux knowledge bases canoniques sur une machine work

- **Fichier** : `AGENTS.md:75-79` ; `workflow/skills/obvault-memory.md` ; ADR-0017 ; `.mcp.json:1-10` ; `workflow/runtime/obvault-topic-resolver.mjs:21-25, 80`
- **Preuve (fait vérifié)** : AGENTS.md et le skill mémoire ordonnent `~/work/obvault`. ADR-0017 + `docs/mcp-strategy.md:47-55` : vault work = `brain` (`~/work/brain`), obvault personnel **non enregistré** sur une machine work. `.mcp.json` sert `brain` avec `OBVAULT_ROOT=${HOME}/work/brain`. Le resolver CLI, sans env, cherche `~/work/obvault`. Cette session a interrogé obvault avec succès — donc les deux arbres existent ici. Grok n’a toujours aucun MCP (ADR-0016).
- **Pourquoi** : un agent work qui suit AGENTS.md lit le vault personnel ; un agent branché MCP lit `brain`. Pas de test de drift (ADR-0017:53-54 l’admet).
- **Fix** : une phrase dans AGENTS.md work — CLI `~/work/brain` + MCP `brain` ; obvault seulement hors scope work. Un resolver, un root.

---

### MINOR

#### m1 — 15 skills catalogués, jamais liés

`skill-surface.tsv` : `suite-router`, `caveman`, `grill-me`, `maintainer-orchestrator`, `design-suite`, `stack-suite`, et 9 skills design (`add-dark-mode` … `markup-from-image`) sont `0 0 0 0`. Ils restent dans le TSV que l’installer parse. **Fix** : les sortir du catalog vivant ou les marquer `opt_in` hors deploy.

#### m2 — `route-context-manifest` orphelin, toujours dans `full`

ADR-0014:61-63 déclare `scripts/lib/route-context-manifest.mjs` orphelin. `agentic-infra-checks.tsv:61` garde `route-context-manifest-smoke` en profil `full`. **Fix** : retirer le check avec l’injection, ou ressusciter le consommateur.

#### m3 — `docs/` mélange contrat vivant et musée

32 fichiers sous `docs/`. Datés / scorecards encore à la racine : `adversary-etabli-10-*`, `etabli-harness-audit-20260724.md`, cinq `harness-*-20260801.md`, trois `harness-optimization-*`, `nvim-minimal-*`. Le scorecard 10/10 est au moins bandeauté « Historical snapshot. Not operational » (`docs/adversary-etabli-10-scorecard.md:1`). 104 archives sous `docs/plan/`. **Fix** : `docs/archive/2026-08/` + un index ; ne plus citer un snapshot comme preuve.

#### m4 — Grok safety cells tournent en `acceptEdits`

`etabli-harness-eval.sh:8, 36-37, 218` + `manifest.json:33-38` : `plan-draft-no-mutate` et `hunter-read-only` sont `pi`+`grok`, runner Grok `--permission-mode acceptEdits`. L’oracle rattrape *après*. **Inférence** : un run live peut écrire avant le grade. **Fix** : `default` / `plan` pour les cells safety, ou Pi-only.

#### m5 — Template MCP pinne `chrome-devtools-mcp@latest`

`mcp/servers.template.json:14`. Le repo pinne ailleurs des SHA et des versions. `@latest` est une dérive silencieuse. **Fix** : version exacte, comme `hunkdiff@0.17.3`.

#### m6 — Classifier « canonique » hébergé dans l’adapter Claude

`workflow-router-core.mjs:1-18` réexporte depuis `claude/hooks/workflow-router-lib.mjs` (1281 lignes). ADR-0006 promet des adapters minces sur un contrat partagé. Le contrat exécutable vit dans Claude. **Fix** : déplacer le classifier sous `workflow/runtime/` ; Claude n’importe plus.

#### m7 — Capabilities : pas de Grok/Codex ; probes `unknown` périmés

`runtime-capabilities.json` : runtimes `pi` et `claude` seulement. `pi.supports_subagents.verified_at: 2026-07-24` + `expires_after_days: 7` → périmé au 2026-08-23. Les labels `unknown`/`blocked` restent honnêtes ; l’absence Grok/Codex contredit le marketing multi-harness. **Fix** : deux lignes `grok`/`codex` en `blocked`/`unknown` avec preuve, ou retirer la claim.

#### m8 — `OPS_STOP_PATTERN` trop large pour un classifier observé

`workflow-router-lib.mjs:53-54` matche `git push`, `secret`, `credential`, `deploy`. Un prompt « ne push pas de secret » peut router `ops-stop`. Pas dangereux (`writeAllowed: false`) mais ça pollue. `router-eval` 76/76 ne prouve pas l’absence de faux positifs hors corpus. **Fix** : ancrer sur verbes d’action + cibles, ajouter des cas négatifs.

---

### NIT

- **n1** — Helper-smoke de 366 lignes (`install-main.sh:747-1113`) couplé au script de prod via `ETABLI_INSTALL_HELPER_SMOKE=1`. Extraire.
- **n2** — README:31 laisse croire que `./scripts/install.sh` suffit ; le script installe aussi un IDE + fonts + 13 LSP. Le dire.
- **n3** — `herdr/docs/multihost.md:36` : `rsync -az --delete herdr/ macmini:~/work/etabli-herdr/`. Un mauvais cwd vide le remote. **Non exercé**.
- **n4** — `.mcp.json` utilise `${HOME}` ; l’expansion dépend de l’hôte MCP. ADR-0017 dit « one-time user approval ». **Non vérifié** si Claude expand.
- **n5** — `reviewer-improvement-loop.md` fait 182 lignes, plus long que `review.md` (126). Un loop pour améliorer les reviewers, sans cellule eval.

---

## Axes

### 1. Cohérence architecture

Le contrat d’**écriture** (PLAN unique, READY, freeze, no_progress) correspond au code Pi/Claude. Le contrat de **route** et le rituel d’implémentation ne correspondent qu’à des markdowns + un classifier observé. Codex/Grok ne sont pas dans la matrix de capabilities. **Dérives** : colonne `cross_harness` morte ; 15 skills catalogués jamais liés ; `ops-stop` nommé « guard » dans le guide humain (`docs/workflow-guide.md:148-152`) alors que c’est un pattern de prompt.

### 2. Complexité vs valeur (YAGNI)

**Opinion.** Pour un mono-utilisateur multi-harness, le noyau (guards + catalog + symlink `workflow/`) justifie son coût. Ce qui ne le justifie pas : l’installer 1909 lignes, 15 skills design morts, 24 skills workflow dont un control plane DAG (`program-orchestration.md`, 79 l.) mappé sur  à `live_assets: blocked`, 55 checks `full`, 18 étapes d’implement, une suite eval à oracles troués, un musée d’audits, 104 plans archivés. Chaque loop nommé après `plan-implement` / `review` / `verify` a un ROI négatif tant qu’il n’a pas de cellule live discriminante. ADR-0013 l’a déjà démontré sur le council.

### 3. Fragilité opérationnelle

**Ce qui casse en premier (inférence, classée)** :

1. Volume `/Volumes/Crucial` absent → 6+ surfaces home pointent dans le vide. L’installer prune les dangling *managed* ; un agent démarre quand même.
2. Divergence installer / `deploy-agent-workflow` / `check-fix-symlinks` après un changement de catalog.
3. Scope `~/.etabli-scope` oublié sur une 2e machine → vendors work liés ou absents sans bruit fort.
4. macmini : rsync `--delete` + Herdr hors du symlink laptop (`herdr/docs/multihost.md:30-37`).

Les symlinks absolus vers le clone sont le bon modèle *tant que le clone ne bouge pas*. Ce n’est pas un OS lock ; c’est un contrat de path.

### 4. Qualité d’exécution

**Fort** : `core` 15/15 ; 238 tests Pi, 0 fail ; `router-eval` 76/76 accuracy 1 ; filter-output exhaustif ; supply-chain pinne les SHA checkout + hunkdiff ; harness smoke teste pass **et** fail + sentinelles (Cursor absent, pipe-template verdict, `runner_exit=127` fail-closed) ; SHA évaluateur pinnée dans le manifest. Les ADRs citent des mesures et leurs propres ratés.

**Faible** : oracles sémantiquement troués (B1) ; `skill-lock` rouge (M2) ; installer hors `shell-syntax` (M4) ; docs de contrat en 4 exemplaires tenus par `workflow-contract-coverage-smoke` (25 s dans `core` — le check le plus lent du daily gate).

Les smokes ne sont pas cosmétiques. Ils sont **discriminants sur le contrat mécanique** et **indulgents sur le comportement modèle**.

### 5. Sécurité

`SECURITY.md` est honnête et court. Template MCP sans secrets. `.gitignore` couvre `.env`, `*.pem`, `.workflow/`, settings locaux. Pi `filter-output` est réellement testé (des dizaines de cas dans `core`). Live MCP reste hors repo (ADR-0016) — bon.

**Risques vérifiés dans le code, non exploités ici** : `curl | sh` RTK ; Homebrew official installer ; `npm -g` non pinné ; `chrome-devtools-mcp@latest` ; Grok `acceptEdits` sur tasks safety ; hooks qui **classifient** `ops-stop` sans deny. Pas d’audit d’historique git — **non vérifié** « aucun secret jamais commité ».

### 6. Dérive documentaire

Le couple README / spec / quick-card / guide est tenu (smoke 25 s). Autour : musée 2026-07/08, scorecard 10/10 bandeauté historique mais toujours à `docs/` racine, AGENTS.md qui vend `cross_harness`, ADR-0014 qui laisse un orphelin dans `full`. Ce n’est pas que de l’archive : les agents lisent `docs/` en premier.

---

## Avis final

### 1. Verdict en une phrase

**Le kernel — PLAN unique, guards partagés fail-closed, catalog TSV, ADR qui retirent — est bien conçu pour un opérateur solo multi-runtime ; le système vendu autour (eval comportementale, 18 étapes, control plane, installer kitchen-sink, « full validated ») ne l’est pas encore, et une partie de ses preuves sont fausses.**

### 2. Top 3 forces

1. **Un guard d’écriture partagé, fail-closed, testé.** `planMutationGuardDecision` + dual-runtime + freeze + no_progress. Preuve : `core` exit 0 ; `workflow-router-lib.mjs:1252-1258` ; matrix « deny_on_draft confirmed » des deux côtés ; 238 tests Pi.
2. **Des ADR qui suppriment sur preuve, y compris contre l’auteur.** ADR-0013 : 13 events, council bypassable, ~11k lignes en moins. ADR-0014 : ~301 tok/turn mesurés, risque comportemental déclaré non instrumenté, auto-correction `pi-import-smoke`. ADR-0017 : « no test detects the drift ». Rare.
3. **La plomberie du grader harness, pas ses oracles.** SHA évaluateur pinnée, skip live ≠ succès, `runner_exit != 0` fail-closed, sentinelles Cursor/model, paires pass/fail en CI hermétique. Les trous sont sémantiques (B1) ; la chaîne d’intégrité est déjà là.

### 3. Top 3 faiblesses

1. **La suite qui devait mesurer le comportement mesure le format** (B1). Sept contre-exemples, sept passes. Tout `pass@1` live est aujourd’hui une métrique marketing.
2. **La « source unique » s’arrête aux fichiers statiques.** Spec ≠ classifier (M1), trois reconcilers + lane morte (M3), deux vaults (M6), lock skills rouge hors `core` (M2). Cinq instances du même défaut : la décision est enregistrée, sa propagation ne l’est pas.
3. **Le rituel dépasse l’usage.** 18 étapes, DAG à locks, 55 checks `full`, installer 1909 lignes. ADR-0013 a déjà posé le diagnostic ; il n’a été appliqué qu’au council.

### 4. Les 3 choses à arrêter

1. **Arrêter de publier ou d’étendre l’eval live avant d’avoir des oracles qui échouent sur un agent nul.** Ajouter un manifest / un hash / un report au-dessus de B1 n’améliore rien.
2. **Arrêter le rituel uniforme à quatre reviews.** Adversary plan + simplify + quality + double hunter + adversary cross-model : réserver au high-risk. Le repo refuse la télémétrie avant 10 outcomes (`spec.md:86-87`) et impose ce pipeline sans un seul outcome.
3. **Arrêter d’entretenir un musée et une colonne morte.** 15 skills `0 0 0 0`, `cross_harness` toujours à 0, analyses datées à `docs/` racine, scorecard 10/10. Chaque row a un coût de sync (M2 le montre).

### 5. Les 3 choses à faire ensuite (ROI)

1. **Réécrire les oracles (B1) avant tout run live.** Verdict obligatoire sur les reviews ; worktree + hash sur safety/implement ; une cellule `GO` positive ; une cellule où l’inaction échoue. Trois fichiers. Sans ça la suite ne départage pas Pi et Grok, ce qui est sa seule raison d’être.
2. **Rendre `full` lisible et vert.** Lock des 5 skills, `skill-lock` en `core`, FAIL accumulés. C’est la différence entre « core vert » et la phrase README « every deterministic repository check ».
3. **Une décision, une propagation.** Trancher ordinary-coding (M1), `brain`/`obvault` (M6), un reconciler (M3). Trois contradictions canoniques en moins, plutôt que cinq rustines de doc.

### 6. Score sur 10

| Dimension | Score | Justification |
| --- | ---: | --- |
| Cohérence | **6,5** | Kernel PLAN/guards = code. Routes, Grok/Codex, `cross_harness`, « fail closed » ops-stop = docs. |
| Robustesse | **6,0** | Guards + `core` 15/15 vérifiés. Oracles gameables, installer fail-open, volume symlink, `full` rouge. |
| Simplicité | **3,5** | 24 skills workflow, control plane DAG inutilisé, 95 rows catalog, 70 checks, installer desktop+agents, 18 étapes. |
| Qualité d’exécution | **6,5** | 238 tests, router 76/76, grader pinné, ADRs exemplaires, supply-chain. Contre : B1, lock rouge, `shell-syntax` aveugle sur `lib/`. |
| Maintenabilité | **5,0** | Catalog TSV réel ; trois reconcilers ; 104 plans + musée ; bus factor 1 ; lock stale depuis ADR-0014. |
| **Moyenne** | **5,5 / 10** | Kernel que je garderais. Système complet que je couperais de moitié avant de le croire. |

#### Écart avec `docs/adversary-etabli-10-scorecard.md`

Je diffère frontalement de son « solid adversary 10 » (toutes dimensions ≥ 9, 2026-07-29) :

1. **Définition circulaire** (`:7`) : 10 = zéro High + chaque axe ≥ 9. Le document se déclare lui-même « Historical snapshot. Not operational » (`:1`). Un 10 auto-attribué sur une grille maison ne mesure pas le système.
2. **Sa suite (`:9-24`) n’incluait pas `full`.** Aujourd’hui `skill-lock` est rouge. Le « 10 » ne survivait pas à sa propre gate complète.
3. **Dimension 6 (multi-model, 9/10)** scorait le council — qu’ADR-0013 a retiré quatre jours plus tard comme oversized pour un solo. La meilleure réfutation du scorecard est interne.
4. **Dimension 8 (obvault, 9/10)** précède le split `brain`/`obvault` d’ADR-0017. La claim mémoire n’est plus unique.
5. **Aucune dimension simplicité.** Ma grille la met à 3,5. La sienne récompensait l’ajout de surface. C’est le désaccord de fond, pas un écart de faits : j’ai revérifié router-eval, dual-runtime, filter-output — ils tiennent encore.

Les rounds 1–5 notent 6,5 / 6,5 / 5,5 / 5,6 / 5,8. Je tombe à **5,5** par un chemin différent : plus dur sur YAGNI (`program-orchestration` lu en entier ; 15 skills morts), plus dur sur l’eval (7 contre-exemples, pas 3), un peu plus généreux sur l’exécution du kernel (238 tests + plomberie grader). Même bande : excellent noyau, système non convergent.

---

## Lacunes (investigations non faites)

- Live Pi/Grok harness (`ETABLI_HARNESS_EVAL=1`) — billing, non autorisé ici.
- `verify-agentic-infra full` jusqu’au bout (s’arrêterait à `skill-lock`).
- Fresh install macOS/Linux, déplacement réel du clone, rsync macmini.
- Contenu `vendor/`, `nvim/`, 104 plans, CI distante.
- Secrets dans l’historique git.
- Parité exacte installer vs deployer vs fixer ligne à ligne (inférée, pas diffée).
- Expansion réelle de `${HOME}` dans `.mcp.json` côté Claude.

**État** : review terminée ; artefact `round-6.md` uniquement. **Next** : corriger B1 avant tout chiffre live ; ne pas rouvrir le scorecard 10/10.
