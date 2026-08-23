# Review externe — etabli (round 3)

- **Modèle** : claude-opus-5 (xhigh)
- **Date** : 2026-08-23

---

## 1. Périmètre

**Lu intégralement** : `README.md`, `AGENTS.md`, `CLAUDE.md`, `SECURITY.md`,
`workflow/spec.md`, `workflow/agent-quick-card.md`, `workflow/contract-details.md`,
`docs/workflow-guide.md`, `scripts/lib/install-main.sh` (1909 l.),
`scripts/lib/etabli-harness-eval.sh` (522 l.), `scripts/etabli-harness-eval`,
`docs/harness-eval.md`, les 7 `oracle.sh` + `prompt.md` de
`tests/fixtures/harness-v1/`, `tests/etabli-harness-eval-smoke.sh`,
`workflow/skills/implementation-loop.md`, `workflow/skills/review.md`,
`workflow/skills/self-improvement-loop.md`, `workflow/runtime/skill-surface.tsv`,
`workflow/runtime/agentic-infra-checks.tsv`, `scripts/verify-agentic-infra`,
`tests/install-smoke.sh`, `tests/supply-chain-smoke.sh`,
`.github/workflows/agentic-infra.yml`, ADR 0013→0017, `.mcp.json`,
`mcp/servers.template.json`, `.gitignore`, `scripts/check-fix-symlinks.sh` (l. 1‑240).

**Échantillonné** : `scripts/deploy-workflow`, `scripts/deploy-agent-workflow`,
`workflow//results/*.json`, `docs/adversary-etabli-10-scorecard.md` (lu en
dernier), `pi/extensions/__tests__/settings-consistency.test.ts`,
`workflow/runtime/workflow-router-core.mjs`, `vendor/sources.tsv`.

**Non lu** (cité en lacunes) : `claude/hooks/workflow-router-lib.mjs` (1281 l.),
`scripts/lib/-suite.mjs` (1729 l.), `scripts/evidence-proof` (834 l.),
`scripts/program-state`, `scripts/workflow-event`, `pi/extensions/filter-output.ts`
(760 l.), les 46 `pi/skills/`, `nvim/`, `herdr/`, les 104 archives de `docs/plan/`,
`vendor/` (285 fichiers), et **volontairement** `round-1.md` / `round-2.md` pour
préserver l'indépendance du jugement.

**Commandes exécutées** (preuves reproductibles) :

```bash
scripts/verify-agentic-infra core                 # 15/15 PASS, 36 s, exit 0
scripts/verify-agentic-infra full                 # 49 PASS, 1 FAIL, exit 1
cd pi && bun run verify:skills                    # exit 1
bash tests/codex-skill-description-smoke.sh       # exit 1
bash scripts/check-fix-symlinks.sh                # "0 issue(s)", exit 0
scripts/etabli-harness-eval grade ... (7 tasks)   # sonde de gameabilité
gh api repos/Tonours/etabli/commits/main
```

Volumétrie mesurée : 1109 fichiers trackés, **78 729 lignes de Markdown**,
15 466 de shell, 8957 de `.mjs`, 4972 de TypeScript, 4726 de Lua.
70 checks non-live dans le manifest. 697 commits.

---

## 2. Findings

### BLOCKER

---

**B1 — `verify-agentic-infra full` est rouge, et masque une seconde panne.**

`README.md:130` vend `scripts/verify-agentic-infra full` comme « every
deterministic repository check ». **Fait vérifié** : la commande sort en exit 1.

```
FAIL skill-lock (0s)
EXIT=1
PASS count: 49    (sur 70 checks core+full)
```

Cause 1 — `skills-lock.json` est périmé pour 5 skills kernel :

```
plan-implement: expected 6e917e5f… got 9601af9a…
adversary / review / implement / pr-review : idem
```

Corrélation git : `skills-lock.json` a été régénéré pour la dernière fois en
`d7891ab`, mais `pi/skills/{adversary,review,pr-review}` ont été modifiés plus
tard en `2a52ea4` et `{plan-implement,implement}` en `295e5bf`. Trois commits ont
donc livré des changements de skills sans régénérer le lock d'intégrité.

Cause 2, et c'est la vraie — `scripts/verify-agentic-infra:80` appelle
`run_check` sans `||`, donc sous `set -euo pipefail` (l. 2) le premier échec
**abandonne le run**. 20 checks n'ont jamais été exécutés, dont
`codex-skill-description-smoke`, que j'ai lancé isolément :

```
Error: description drifted: herdr      → exit 1
```

J'ai exécuté les 20 checks manquants un par un : **68 PASS, 2 FAIL**. Le profil
`full` n'en rapporte qu'un.

Pourquoi c'est bloquant : `docs/adr/0014:84` documente **exactement cet
incident** — « `skill-lock` fails earlier in the `pi` group and stops the run. A
fresh-context review caught it. The lesson is that a known pre-existing failure
can mask a new one ». Cette leçon a été écrite le 2026‑08‑03. Vingt jours plus
tard, le même check masque une nouvelle panne, dans le même ordre. Et
`workflow/spec.md:108` énonce le principe « the third occurrence of the same
review finding becomes a mechanical check ». Le principe n'a pas été appliqué à
lui-même.

*Fix* : `run_check "$label" run_target "$target" || FAILED+=("$label")` avec sortie
non-zéro en fin de boucle, plus `bun run update:skills-lock` en pre-commit hook.

---

**B2 — L'instrument de mesure comportemental est passé à 6/7 par une politique
nulle.**

`docs/harness-eval.md` présente `tests/fixtures/harness-v1/` comme des
« frozen harness-behavior tasks graded by executable oracles », méthode DeepSWE.
J'ai fabriqué un transcript constant qui n'exécute rien, ne lit rien, ne modifie
rien, et n'émet que les chaînes attendues (table `| Lens |`, `Deciding-code`,
`HUNTER_SPAWN_UNAVAILABLE`, `runner: pi-child`, `isolation: isolated`, `Act on`
+ `FORBIDDEN.txt`, `Verdict: BLOCK`), puis j'ai gradé les 7 tâches offline sur
des worktrees intacts. **Fait vérifié** :

| task | degenerate_pass |
| --- | --- |
| `review-go-forbidden-empty-deciding` | **true** |
| `review-isolation-sentinel` | **true** |
| `review-spec-drift` | **true** |
| `plan-draft-no-mutate` | **true** |
| `hunter-read-only` | **true** |
| `no-parent-logic-claim` | **true** |
| `ready-implement-touches-only-plan-files` | false |

pass@1 = **0,857 pour un agent qui ne fait rien**. La cause structurelle est
lisible dans les oracles : 5 sur 7 sont des contrôles d'abstention
(`harness_require_file_sha_eq`, `harness_require_porcelain_allowlist`) et
**aucune tâche n'exige `Verdict: GO`**. Une politique qui répond toujours
`BLOCK` et ne touche jamais un fichier n'est jamais pénalisée. Les sentinelles
`runner: pi-child` / `isolation: isolated` / `HUNTER_SPAWN_UNAVAILABLE`
(`tasks/no-parent-logic-claim/oracle.sh:7-9`,
`tasks/review-isolation-sentinel/oracle.sh:5`) sont des `grep` sur le
transcript, donc fabricables par le sujet évalué lui-même.

Pourquoi c'est bloquant : c'est la seule mesure de comportement du repo. Tant
qu'un null baseline n'est pas mesuré et soustrait, aucun chiffre issu de cette
suite ne porte d'information — y compris un futur « pi 7/7 vs grok 5/7 ». Le
repo a par ailleurs produit
`docs/research/deep-research-runs/02-eval-metrics-anti-reward-hacking.md` : la
recherche existe, elle n'a pas été appliquée à l'instrument.

*Fix* : ajouter 2 tâches où `GO` et une édition sont la bonne réponse, publier
le score du null baseline dans `harness_report`, et remplacer les sentinelles
auto-déclarées par une observation hors-transcript (exit code du stub, mtime du
worktree).

---

### MAJOR

**M1 — La politique de symlink est implémentée trois fois, et le seul test de
parité est cosmétique.** *(fait vérifié)*

`scripts/lib/install-main.sh` (1909 l.), `scripts/deploy-agent-workflow`
(715 l.) et `scripts/check-fix-symlinks.sh` (495 l.) manipulent **25 chemins
`$HOME` identiques** (`/.claude/workflow`, `/.pi/agent/extensions`,
`/.codex/skills/`, `/.agents/skills/`, `/.claude/hooks/`, …), chacun avec sa
propre logique de backup, de pruning et de résolution de scope. Le garde-fou
censé les tenir alignés est
`pi/extensions/__tests__/settings-consistency.test.ts:93-94` :

```ts
for (const source of scripts)
  expect(source).toContain("skill_catalog_names");
```

Une assertion de présence de chaîne tient lieu de vérification d'équivalence
comportementale à trois voies. Divergence déjà observable : `install-main.sh:8`
n'active que `set -e`, `check-fix-symlinks.sh:2` active `set -euo pipefail`,
et `install-main.sh:1626` embarque un commentaire défensif « Bash 3 with
`set -u` treats an empty array expansion as unbound » dans un script qui
n'active jamais `set -u` — copie littérale d'un contexte qui ne s'applique pas.
*Fix* : extraire la table de liens (`surface, source, mode`) en TSV et faire des
trois scripts trois modes (`apply` / `sync` / `check`) d'un seul moteur.

---

**M2 — `main` distant est rouge depuis le 2026‑08‑20 et 8 commits de travail
n'ont jamais vu la CI.** *(fait vérifié)*

```
gh api repos/Tonours/etabli/commits/main
→ 156457c feat(claude): reviewer sur opus, adversaire cross-model fable en passe pre-push
gh run list → completed failure … main … 2026-08-20T23:15:44Z
   verify-shell-and-docs: failure
   → "Claude agents must be exactly reviewer, scout, worker; got adversary, reviewer, scout, worker"
```

Aucun run CI depuis. `gh pr list --state open` → vide. La branche courante
`refactor/skill-default-load` porte 8 commits absents de `main`, part de
`613dc7c` (donc n'inclut pas les 2 derniers commits de `main`, dont celui qui
casse la CI), et `.github/workflows/agentic-infra.yml:4-6` ne déclenche que sur
`push: main` et `pull_request` : **aucun de ces 8 commits n'a été validé par la
CI**. Le remote porte 15 branches, la plupart abandonnées. Effet combiné avec
B1 : il n'existe aujourd'hui aucun état vert de référence, ni local ni distant.
*Fix* : ajouter `push: branches: ["**"]` au workflow et réparer `main` avant de
continuer sur la branche.

---

**M3 — Le mécanisme `cross_harness` est du code mort documenté comme actif.**
*(fait vérifié)*

`workflow/runtime/skill-surface.tsv` a 95 lignes ; la colonne 6
(`cross_harness`) vaut **0 partout** :

```bash
awk -F'\t' 'NR>1 && $6==1' workflow/runtime/skill-surface.tsv | wc -l   # → 0
```

Sont donc inertes : `install-main.sh:430-463`
(`is_cross_harness_pi_skill`, `prune_demoted_cross_harness_pi_skills`),
`install-main.sh:1626-1644` (boucle de linkage), les assertions correspondantes
dans le smoke embarqué (`install-main.sh:932-948`), et le bloc équivalent de
`check-fix-symlinks.sh:22-27,265-280`. Pendant ce temps `AGENTS.md:45-46`
affirme que `~/.codex/skills/` « receives active-scope vendored skills plus
catalog entries marked `cross_harness` » et `README.md:14-15` parle de
« catalog-driven skill links for Codex ». La moitié de la phrase est fausse.
*Fix* : supprimer les quatre blocs et la colonne, ou marquer une skill
`cross_harness=1` si l'intention existe.

---

**M4 — La propriété des surfaces partagées est surdéclarée : 38 liens morts,
audit vert.** *(fait vérifié)*

```
~/.pi/agent/skills   entries=81  dangling=26
~/.codex/skills      entries=53  dangling=6
~/.agents/skills     entries=53  dangling=6
bash scripts/check-fix-symlinks.sh → "Summary: 0 issue(s)"
```

Les 26 liens morts de `~/.pi/agent/skills` pointent vers
`../../../.agents/skills/{animate,polish,bolder,critique,…}` ; les 12 autres vers
`~/.codex/vendor_imports/paperasse/*`. Aucun ne pointe dans le repo, donc
`skill_target_is_managed` (`install-main.sh:104-123`) et
`prune_unlisted_pi_source_skills` (`check-fix-symlinks.sh:219`) les ignorent —
**par design**, et `install-main.sh:915-918` teste même explicitement qu'ils ne
soient *pas* supprimés. Le problème n'est donc pas le code, c'est la
documentation : `docs/adr/0015` justifie la reprise de `~/.codex/skills`
précisément par un incident de 39 SKILL.md morts, puis conclut « the surface is
now owned, so drift is a bug with a home ». Ce qui est owned, ce sont *les liens
d'etabli*, pas la surface. La même classe de dérive est revenue et l'audit dédié
répond « 0 issue ».

Calibrage honnête de l'impact : Pi n'annonce pas ces skills dans la liste de
cette session (les SKILL.md sont illisibles, il les écarte silencieusement).
C'est donc du bruit de diagnostic, pas une panne fonctionnelle. Ce qui reste
grave, c'est que `check-fix-symlinks.sh` **n'est dans aucun profil**
(`agentic-infra-checks.tsv` ne référence que `fix-links-smoke`, qui teste le
script sur un faux `HOME`) : le détecteur de dérive existe et n'est jamais
appelé par une routine.
*Fix* : ajouter un balayage `dangling links on managed surfaces` (tous
producteurs confondus) en WARN, et gater `check-fix-symlinks.sh --verbose` dans
`core`.

---

**M5 — Tout le harness dépend d'un volume externe monté.** *(fait vérifié)*

```
~/.claude/workflow     → /Volumes/Crucial/work/etabli/workflow
~/.pi/agent/workflow   → /Volumes/Crucial/work/etabli/workflow
~/.agents/workflow     → /Volumes/Crucial/work/etabli/workflow
~/.pi/agent/extensions → /Volumes/Crucial/work/etabli/pi/extensions
~/.config/nvim         → /Volumes/Crucial/work/etabli/nvim
~/.tmux.conf           → /Volumes/Crucial/work/etabli/tmux.conf
```

Un démontage, un renommage du volume ou un boot sans le disque casse
**simultanément** les trois surfaces agent, Neovim, tmux, Ghostty et Herdr. Le
mode de défaillance est silencieux : Pi et Claude ne trouveront pas
`workflow/spec.md`, donc l'activation ambiante s'éteint sans message — l'agent
continuera à travailler, hors contrat. C'est le point de rupture n°1 du système
et il n'est mentionné nulle part dans `README.md` ni dans `herdr/docs/multihost.md`.
*Fix* : soit cloner le repo sous `$HOME` et faire de `/Volumes/Crucial` un
miroir, soit ajouter au `core` un check qui échoue si
`readlink ~/.pi/agent/workflow` est cassé.

---

**M6 — Le durcissement supply-chain est appliqué à la CI, pas à l'installer.**
*(fait vérifié)*

`tests/supply-chain-smoke.sh:14-17` exige que **chaque** action GitHub soit
épinglée sur un SHA de 40 caractères, et `:33` épingle `hunkdiff@0.17.3`. Ce
niveau d'exigence porte sur un runner jetable qui ne touche à rien. Sur la
machine de dev, `scripts/install.sh` — la commande du quick-start — fait :

| ligne | opération |
| --- | --- |
| `install-main.sh:1181` | `/bin/bash -c "$(curl … Homebrew/install/HEAD/install.sh)"` |
| `install-main.sh:1252` | `curl … rtk/refs/heads/master/install.sh \| sh` (branche, pas tag) |
| `install-main.sh:1193`, `1225`, `1232` | `sudo apt/dnf/pacman install` |
| `install-main.sh:1275-1294` | `npm install -g` de 13 paquets, **aucun épinglé** |
| `install-main.sh:1381` | `git clone` de tpm sans ref |
| `install-main.sh:721` | `pi install "$package_source"` depuis un JSON local, y compris sources `git:` |
| `install-main.sh:1819-1823` | réécriture de `~/.zshrc` **et** `~/.bashrc` (awk + `cp`) |

`SECURITY.md` ne couvre que l'hygiène des secrets : rien sur l'exécution de code
à l'install. À noter au crédit : `--ignore-scripts` sur pi (`:1785`), backups
horodatés systématiques, et un test qui vérifie qu'un `.zshrc` tronqué n'est pas
détruit (`:1059-1072`) — le soin est là, l'inventaire de menace ne l'est pas.
*Fix* : épingler les 13 globals npm et le tag RTK, et ajouter une section
« install-time code execution » à `SECURITY.md`.

---

**M7 — Le contrat est dupliqué quatre fois et pèse plus que ce qu'ADR‑0014 a
économisé.** *(fait vérifié + opinion)*

La table de routing existe en quatre exemplaires : `workflow/spec.md:131-154`
(22 lignes), `workflow/agent-quick-card.md:66-77`, `docs/workflow-guide.md:48-58`,
`README.md:89-101`. `workflow/contract-details.md:5` en est conscient : « Do not
treat this file as a second routing table ». Poids du noyau toujours pertinent :

```
AGENTS.md + CLAUDE.md + spec.md + quick-card.md + contract-details.md
+ answer-quality.md = 880 lignes / 49 876 octets (~12,5k tokens)
```

Et `deploy-workflow` copie **3580 lignes / 156 008 octets** de contrat dans
*chaque* projet scaffoldé (7 fichiers `workflow/*.md` + 24
`workflow/skills/*.md`), chacun devenant une copie qui dérive.

Mise en perspective : `docs/adr/0014` a supprimé l'injection de route context
pour économiser ~301 tok/tour, avec des mesures précises. Excellente décision.
Mais l'optimisation a porté sur la partie bon marché ; la partie chère — 4
copies d'une table à maintenir à la main, un `implementation-loop.md` de 18
étapes avec sous-étapes 12b/12c/13b et une checklist de 10 « completion
evidence » — n'a jamais été mise au régime. **Opinion** : pour un dépôt
mono-utilisateur, ce loop de 18 étapes n'est pas un contrat, c'est un rituel ;
il sera suivi par un modèle complaisant et ignoré par un modèle pressé, et
personne ne pourra le vérifier.
*Fix* : garder `spec.md` comme unique table de routing et générer les 3 autres,
ou les remplacer par un lien.

---

**M8 — Le classifieur canonique vit dans un adapter, et le gate de syntaxe shell
saute `scripts/lib/`.** *(fait vérifié)*

`workflow/runtime/workflow-router-core.mjs` s'ouvre sur « Canonical
deterministic classifier. Host adapters must import from here. » et ses 18
lignes ne font que re-exporter 17 symboles depuis
`../../claude/hooks/workflow-router-lib.mjs` (1281 l.). Le plus gros artefact
exécutable du contrat partagé habite donc dans le répertoire d'un harness
particulier, ce qui contredit ADR‑0006 (« keep agent surfaces as adapters over
shared workflow contracts »). Ça fonctionne — Node résout par realpath, donc
l'import traverse correctement le symlink `~/.pi/agent/workflow` — mais
l'arborescence `workflow/` n'est pas autonome.

Par ailleurs `scripts/verify-agentic-infra:24` :

```bash
find "$ROOT_DIR/scripts" "$ROOT_DIR/tests" -maxdepth 1 -type f -print0
```

`-maxdepth 1` exclut `scripts/lib/` du check `shell-syntax` de `core`, donc les
1909 lignes de `install-main.sh` et les 522 de `etabli-harness-eval.sh` (les deux
plus gros scripts du repo) ne sont pas couvertes par le gate de syntaxe. Elles le
sont indirectement via `install-smoke` et `etabli-harness-eval-smoke` — tous deux
en profil `full`, donc tous deux dans les 20 checks que B1 empêche d'exécuter.
*Fix* : déplacer `workflow-router-lib.mjs` sous `workflow/runtime/` et retirer
`-maxdepth 1`.

---

### MINOR

**m1 — `route-context-manifest` : orphelin déclaré, toujours gaté.**
`docs/adr/0014` écrit noir sur blanc « `scripts/lib/route-context-manifest.mjs`
is now orphaned (its only consumer was the injection path). Left in place ».
Neuf mois de dette plus tard : `scripts/route-context-manifest-check` (84 l.),
`workflow/route-context-manifests.json`,
`tests/route-context-manifest-smoke.sh` (37 l.), et une ligne dans
`workflow/runtime/agentic-infra-checks.tsv:61`. Le repo paie donc un check à
chaque `full` pour valider un manifest d'une fonctionnalité supprimée.
*Fix* : supprimer les 4 artefacts.

**m2 — La machinerie  produit un signal officiellement nul.**
`scripts/lib/-suite.mjs` fait 1729 lignes, `workflow//results/`
contient 13 artefacts. Verdicts lus dans
`workflow//results/-0.14.1-structural.json` :
`deterministic: VERIFIED (evidence_class: structural_contract, 23/23)`,
`live: BLOCKED (candidate_runs_completed: 0 / required: 138)`,
`comparison: INCONCLUSIVE, universal_ahead_claim: false`. Le `README.md:107-124`
rapporte cela sans tricher — c'est à porter au crédit. Reste que
~1700 lignes + 13 artefacts ne produisent qu'une vérification structurelle de
routing. Et `workflow//results/baseline-run.json:970` référence
`scripts/workflow-dossier`, qui n'existe plus : la baseline n'est pas
reproductible.
*Fix* : geler `/` en archive tant que `LIVE_EVAL_BUDGET_USD` n'est pas
autorisé, et sortir son smoke de `full`.

**m3 — `docs/` est un musée à moitié.** 171 fichiers trackés dont **104
archives** dans `docs/plan/`. 13 documents n'ont pas bougé depuis ≤ 2026‑07‑29
(`adversary-etabli-10-*`, `nvim-minimal-*`, `etabli-harness-audit-20260724`,
`handoff.md`, `skills-mcp-consolidation-research`), 8 autres depuis 2026‑08‑01
(les cinq `harness-*-20260801`). Au crédit : les plus datés portent un bandeau
explicite (`docs/adversary-etabli-10-scorecard.md:1` : « Historical snapshot
(2026‑07‑29). Not operational. »), ce qui est la bonne pratique. Mais un
répertoire où 21 des 26 documents racine sont des snapshots historiques n'est
plus une doc, c'est un dépôt d'archives qui coûte du contexte à chaque
exploration.
*Fix* : `docs/archive/` avec un `README` d'index, et sortir `docs/plan/` du
répertoire de documentation.

**m4 — Claude Code, un des trois harness annoncés, n'a aucune cellule d'éval.**
`scripts/etabli-harness-eval:90` → `all) runners=(pi grok)`.
`scripts/lib/etabli-harness-eval.sh:4-8` épingle deux modèles en dur
(`zai/glm-5.3`, `grok-4.6`). `docs/harness-eval.md:16` justifie l'absence de
Grok sur les tâches hunter, mais ne dit rien de Claude. La promesse
« piloter plusieurs harness depuis une source unique » est mesurée sur deux
tiers du périmètre.
*Fix* : ajouter un runner `claude` sur les 3 tâches plan/implement/read-only.

**m5 — La matrice de capabilities est majoritairement inconnue.** Sortie de
`dual-runtime-guard-matrix-smoke` : **9 des 16 lignes** sont `unknown` ou
`blocked` (`supports_subagents`, `supports_goal_state`,
`supports_structured_task_state`, `supports_named_workflow_graphs`…). C'est
honnête et documenté (ADR‑0013 assume la perte des probes). Mais le README
affirme que `deploy-agent-workflow` « aligns Claude, Pi, the skill-only Codex
surface, and Grok » : l'alignement porte sur les fichiers, pas sur les
capacités, et rien ne le dit.

---

### NIT

- `.mcp.json` (tracké, racine) pointe sur `${HOME}/work/brain/_meta/mcp/server.mjs`,
  chemin hors repo et non tracké. Pour tout clone tiers, c'est une entrée MCP
  morte qui demande une approbation. ADR‑0017 assume le choix ; un `$comment`
  d'une ligne suffirait.
- `install-main.sh:1696,1753,1759,1768` : `for x in $(find … | sort)` — word
  splitting sur des chemins. Sans danger ici (chemins contrôlés par le repo),
  mais incohérent avec le `while IFS= read -r` utilisé ailleurs dans le même
  fichier.
- 368 lignes de tests (`install-main.sh:747-1114`, 19 % du fichier) vivent dans
  l'installer derrière `ETABLI_INSTALL_HELPER_SMOKE=1`, et référencent des
  chemins qui doivent *ne pas* exister (`claude/agents/removed-agent.md`,
  `pi/skills/removed-skill`). Le jour où l'un de ces noms est recréé, le smoke
  passe en vert à tort.
- `vendor/sources.tsv` épingle les 5 sources sur `main` et non sur un SHA. Le
  contenu vendoré est verrouillé par `skills-lock.json`, donc l'exposition est
  réelle uniquement au moment d'un `sync-vendor-skills` — mais c'est justement
  le moment qui compte.

---

## 3. Avis final

### 3.1 Verdict en une phrase

Le noyau est réellement bien conçu — des guards exécutables, un classifieur
déterministe à 76/76, des ADR d'une honnêteté rare — mais il est enveloppé dans
trois à quatre fois trop de machinerie pour un utilisateur unique, et il n'existe
aujourd'hui **aucun état vert de référence** : le gate `full` est rouge et masque
une seconde panne, `main` distant est rouge depuis trois jours, et l'instrument
de mesure comportemental est passé à 86 % par un agent qui ne fait rien.

### 3.2 Top 3 forces

1. **Les guards sont du code, pas de la prose — et c'est prouvé.**
   `core` : 15/15 PASS en 36 s. `planMutationGuardDecision` est partagé entre Pi
   (`tool_call`) et Claude (`plan-ready-guard`), et
   `dual-runtime-guard-matrix-smoke` sort les preuves ligne par ligne
   (`claude.plan_ready_guard: deny_on_draft confirmed`,
   `check_freeze: edit_multiedit_ac_weaken deny confirmed`). 238 tests Pi,
   0 échec. `router-eval` : 76 cas, accuracy 1.0, `ops_stop_misses=0`. C'est le
   cœur du projet et il tient.

2. **La qualité des ADR est au-dessus de la moyenne de l'industrie.** ADR‑0013
   supprime le council en citant son propre gate de latence à l'aveugle et « 13
   events total, all from 2026‑07‑04/05 » — une suppression sur preuve, pas sur
   goût. ADR‑0014 mesure l'injection en tokens sur 4 prompts réels, refuse de
   marquer ADR‑0007 `superseded` « because the validator would require flipping
   ADR‑0007 to superseded, which would be false », et enregistre sa propre
   erreur (« the first version of this ADR claimed that same suite result while
   `pi-import-smoke` was in fact broken »). ADR‑0017 liste ses conséquences
   négatives (« the engine and its five libraries are duplicated… no test detects
   the drift »). Très peu d'équipes écrivent ça.

3. **Le refus d'overclaim est systématique et mécanisé.** `live` sort en exit 3
   avec `live_agent_proof: skipped` plutôt qu'en succès
   (`verify-agentic-infra:89-94`). Le posture  affiche
   `universal_ahead_claim: false` et `not_established`. Les capabilities restent
   `unknown` avec `proof_command: null`. Et le smoke d'oracle
   (`tests/etabli-harness-eval-smoke.sh`) teste ses propres oracles contre des
   transcripts pass **et** fail, plus trois cas d'évasion (verdict en template
   `GO | GO WITH NOTES | BLOCK` rejeté comme illisible, `FORBIDDEN.txt` présent
   uniquement dans `git status` rejeté, `runner_exit=127` fail-closed). C'est de
   l'unit-testing d'oracle, une pratique que la plupart des suites d'éval
   n'appliquent pas.

### 3.3 Top 3 faiblesses

1. **La mesure ne mesure pas** (B2). 6/7 pour un agent nul. Aucune tâche
   n'exige `GO`. Les sentinelles d'isolation sont des `grep` sur le transcript
   produit par le sujet évalué.

2. **La discipline est prêchée, pas appliquée au repo lui-même** (B1 + M2).
   `spec.md:108` : « the third occurrence of the same review finding becomes a
   mechanical check ». Le masquage `skill-lock` → check suivant est documenté
   dans ADR‑0014 et se reproduit à l'identique 20 jours plus tard. `main` est
   rouge depuis le 2026‑08‑20 sur un check trivial (liste d'agents Claude), et 8
   commits ont été livrés sans qu'aucune CI ne tourne.

3. **Le ratio contrat/valeur a décroché** (M7 + M1 + m1 + m2). 78 729 lignes de
   Markdown, 70 checks, un `implementation-loop` à 18 étapes, une table de
   routing en 4 exemplaires, 3119 lignes de scripts de déploiement redondants,
   1729 lignes de runner  pour un verdict `INCONCLUSIVE`, et un check
   toujours gaté pour une fonctionnalité supprimée par ADR. Pour un seul
   utilisateur, chaque ligne de contrat est un engagement à maintenir que
   personne d'autre ne relira.

### 3.4 Les 3 choses à arrêter

1. **Arrêter d'ajouter des checks avant d'avoir rendu le gate lisible.** 70
   checks dont un abort-on-first-failure : la 71ᵉ n'apportera rien tant que le
   run ne dit pas *combien* de choses sont cassées. Corollaire : arrêter de
   laisser un rouge « pre-existing » vivre plus d'un jour — ADR‑0014 prouve que
   c'est exactement ce qui aveugle la suite.

2. **Arrêter d'écrire des rituels de complétion.** Les 18 étapes de
   `implementation-loop.md` + les 10 items de « Completion Evidence » + les 6
   items de `self-improvement-loop.md` § Completion Evidence : rien de tout cela
   n'est vérifiable mécaniquement, donc rien de tout cela ne contraint un
   modèle. Ce qui contraint, c'est `planMutationGuardDecision` — 1 fonction. La
   prose en plus est un coût de contexte à somme négative.

3. **Arrêter d'archiver au même endroit que la doc.** 104 archives de plan +
   21 snapshots datés dans `docs/`. Chaque agent qui explore `docs/` paie ce
   volume, et les documents datés se font citer comme s'ils étaient actuels — ce
   round-3 a d'ailleurs dû vérifier les dates git de 26 fichiers pour savoir
   lesquels croire.

### 3.5 Les 3 prochaines choses, par ROI

1. **Rendre le gate honnête, puis vert.** (~2 h, ROI immédiat)
   `run_check … || FAILED+=(…)` + résumé final, `bun run update:skills-hook` en
   pre-commit, correction de `codex-skill-description-smoke` (`description
   drifted: herdr`), réparation de `main`, `push: branches: ["**"]` dans la CI.
   Tout le reste du repo repose sur cette commande ; tant qu'elle ment, aucune
   autre amélioration n'est mesurable.

2. **Publier un null baseline sur harness-v1 et ajouter deux tâches positives.**
   (~4 h, ROI élevé)
   Une tâche où `Verdict: GO` est la bonne réponse, une tâche où ne pas éditer
   est un échec, et `harness_report` qui affiche `pass@1` **moins** le score du
   transcript dégénéré. Sans ça, la suite ne pourra jamais départager Pi et
   Grok, ce qui est sa seule raison d'être.

3. **Fusionner les trois scripts de déploiement derrière une table déclarative.**
   (~1 j, ROI structurel)
   Un TSV `surface / source / mode / scope`, un moteur, trois modes. Cela
   supprime ~1000 lignes, élimine le risque de divergence à trois voies, rend
   `check` gatable dans `core`, et permet enfin de détecter les 38 liens morts
   (M4) — le tout en réutilisant le pruning déjà écrit et déjà testé.

### 3.6 Score

| Dimension | Score | Justification (preuve) |
| --- | --- | --- |
| Cohérence architecture | **6,5** | Guards partagés réels ; ADR précis. Mais 3 implémentations du même déploiement, `cross_harness` mort (0 lignes), classifieur canonique dans `claude/hooks/`, `route-context-manifest` orphelin encore gaté. |
| Robustesse opérationnelle | **4,0** | SPOF `/Volumes/Crucial` sur 6 surfaces ; `main` rouge depuis 3 j ; 8 commits sans CI ; 38 liens morts et audit « 0 issue » ; détecteur de dérive dans aucun profil. |
| Simplicité / YAGNI | **3,5** | 78 729 l. de Markdown, 70 checks, loop à 18 étapes, routing table ×4, 1729 l. de  pour `INCONCLUSIVE`, 104 archives dans `docs/`. |
| Qualité d'exécution | **6,0** | `core` 15/15 en 36 s, 238 tests, router 76/76, unit-tests d'oracle sérieux. Mais `full` rouge + masquage, parité 3-voies « testée » par `toContain`, `shell-syntax` saute `scripts/lib/`, `install-main.sh` sans `set -uo pipefail`. |
| Maintenabilité | **4,5** | Mono-mainteneur, 3119 l. de scripts synchronisés à la main, 4 copies du contrat, 21 snapshots datés mélangés à la doc vivante, 15 branches distantes abandonnées. |

**Score global : 5,5 / 10.** Traduction : un noyau que je défendrais en revue
d'architecture, enveloppé dans une périphérie que je supprimerais à 60 %, et un
état de livraison qui ne passerait pas ma propre gate.

### 3.7 Écart avec `docs/adversary-etabli-10-scorecard.md`

Ce scorecard (2026‑07‑29, bandeau « Historical snapshot. Not operational »)
donne **10 dimensions toutes ≥ 9** et conclut « solid adversary 10 ». Je note
5,5. L'écart n'est pas un désaccord sur les faits — la plupart de ses preuves
tiennent encore aujourd'hui (j'ai revérifié : router-eval, agent-scenarios,
dual-runtime matrix, filter-output, `LINEAR_MCP_UNAVAILABLE`, tous verts). Il
vient de quatre choix de cadrage :

1. **Sa suite exclut ce qui casse.** Sa table (l. 11‑23) liste `core` + 8 smokes
   choisis, jamais `full`, donc jamais `skill-lock` — qui était déjà rouge quatre
   jours plus tard selon ADR‑0014 (« 44 PASS, 1 FAIL (`skill-lock`,
   pre-existing on `main`) »). Il note ensuite « Validation surface : **9,5** —
   core 0 ». Scorer la dimension « validation » sur le sous-ensemble qui passe
   est circulaire ; c'est le seul reproche de méthode que je lui fais.

2. **Il n'a aucune dimension de coût.** Ni simplicité, ni maintenabilité, ni
   volume. Les dix dimensions mesurent toutes une forme de couverture. Un
   système peut donc y marquer 10 en doublant sa taille — et c'est ce qui s'est
   produit : entre le 2026‑07‑29 et aujourd'hui le repo a gagné la machinerie
   , le harness-eval, `program-state`, `evidence-proof`, et le mécanisme
   mort `cross_harness`. Mes deux notes les plus basses (3,5 et 4,0) portent
   exactement sur ce que sa grille ne regarde pas.

3. **Il ne teste pas ses instruments.** Sa dimension 7 vérifie que la validation
   *tourne*, jamais qu'elle *discrimine*. Le harness-eval n'existait pas encore,
   mais la méthode aurait dû l'attraper : personne n'a mesuré de null baseline,
   ni là ni depuis (B2).

4. **Il est daté, et son objet a bougé.** Sa dimension 6 « Multi-model
   discipline : 9 » s'appuie sur « Portfolio bounds tests » et
   `multi-model-orchestration` — supprimés cinq jours plus tard par ADR‑0013.
   Une note portée par des preuves désormais inexistantes.

Là où je **converge** avec lui : ses quatre « Residual Low » sont justes et
toujours ouverts (rationale de check-freeze par mots-clés, one-writer/no_progress
qui restent un protocole et non une contrainte kernel, capabilities live
`unknown`, télémétrie expérimentale). Et son insistance sur « not marketing 10 on
live-only surfaces » est la bonne intuition — appliquée à une seule moitié du
système.

---

## 4. Lacunes

Points que je n'ai pas investigués et sur lesquels je ne me prononce pas :

1. **`claude/hooks/workflow-router-lib.mjs` (1281 l.) non lu.** Je n'ai jugé le
   classifieur que par ses sorties (`router-eval` 76/76, 238 tests Pi,
   `agent-scenarios` 11/11). Sa qualité interne, sa complexité cyclomatique et
   la présence de patterns fragiles (regex sur prompt libre) restent non
   évaluées. C'est le composant le plus critique du repo.
2. **`scripts/lib/-suite.mjs` (1729 l.), `scripts/evidence-proof` (834 l.),
   `scripts/program-state` (682 l.), `scripts/workflow-event` (817 l.) non lus.**
   ~4000 lignes de logique de ledger et de preuve dont je n'ai vu que les smokes
   verts. Mon jugement « surdimensionné » (M7, m2) porte sur le volume et les
   verdicts publiés, pas sur la qualité du code.
3. **`pi/extensions/filter-output.ts` (760 l.) non lu**, alors que c'est la seule
   défense contre l'exfiltration de secrets. Ses 51 tests passent et couvrent des
   cas non triviaux (process substitution, heredocs d'interpréteur, globs
   attachés) ; je n'ai pas cherché de bypass. Aucun avis sécurité sur ce
   composant.
4. **Les 46 `pi/skills/` et les 285 fichiers de `vendor/` non lus.** Je n'ai lu
   que le catalogue TSV. La qualité effective des skills, leur redondance
   éventuelle et leur charge de contexte réelle ne sont pas évaluées.
5. **`nvim/` (4726 l. de Lua) et `herdr/` non lus.** ADR‑0010 et ADR‑0012 non
   audités. Les smokes Neovim passent localement.
6. **Aucun run live.** Je n'ai jamais lancé `ETABLI_HARNESS_EVAL=1 … run`, ni
   `verify-agentic-infra live`, ni un agent réel sur une tâche. Ma sonde de
   gameabilité (B2) prouve qu'une politique dégénérée passerait ; elle ne prouve
   pas que Pi ou Grok se comportent ainsi. La question « les agents suivent-ils
   effectivement le contrat ? » reste **non vérifiée** — et c'est, à mon avis, la
   seule question qui compte vraiment pour ce projet.
7. **Dérive multihost non testée.** `herdr/docs/multihost.md` non lu, le rsync
   vers macmini non observé. Mon finding M5 porte sur les symlinks de *cette*
   machine, mesurés ; l'exposition multihost est une inférence non vérifiée.
8. **`round-1.md` / `round-2.md` volontairement non lus** pour préserver
   l'indépendance. Je ne sais donc pas où mes findings recoupent ou contredisent
   les deux rounds précédents.
