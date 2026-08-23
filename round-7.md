# Review externe — etabli (round 7)

- **Modèle** : composer-2.5 (sans thinking — max non supporté)
- **Date** : 2026-08-23
- **HEAD** : `a18d3ef` sur `refactor/skill-default-load` (working tree dirty : `pi/agent/settings.json`)
- **Contrainte** : lecture seule hors ce fichier ; aucun commit

Légende : **fait vérifié** = lu ou reproduit ici ; **inférence** = conséquence logique non exercée en prod ; **opinion** = jugement coût/valeur.

---

## Périmètre lu

### Lu intégralement

- `README.md`, `AGENTS.md` (racine)
- `workflow/spec.md`, `workflow/agent-quick-card.md`
- `docs/workflow-guide.md`
- `scripts/lib/install-main.sh` (1909 lignes)
- `scripts/lib/etabli-harness-eval.sh`, `docs/harness-eval.md`, `tests/etabli-harness-eval-smoke.sh`
- `tests/fixtures/harness-v1/manifest.json` + les 7 `oracle.sh` + échantillon overlay/prompt/synthetic
- `workflow/skills/implementation-loop.md`, `workflow/skills/obvault-memory.md`, `workflow/skills/review.md`
- `workflow/runtime/skill-surface.tsv` (95 skills)
- ADR-0013, 0014, 0015, 0016, 0017
- `SECURITY.md`, `mcp/servers.template.json`, `docs/mcp-strategy.md` (début)
- `scripts/verify-agentic-infra`, `workflow/runtime/agentic-infra-checks.tsv`
- `pi/extensions/workflow-router.ts`, `workflow/runtime-capabilities.json`
- `docs/adversary-etabli-10-scorecard.md` (lu en dernier, comme imposé)

### Échantillonné

- `workflow/contract-details.md` (317 lignes — entête + structure, pas ligne par ligne)
- `scripts/deploy-agent-workflow` (715 lignes — entête + contrat dry-run)
- `claude/hooks/workflow-router-lib.mjs` (patterns ops-stop, guards)
- `herdr/docs/multihost.md` (rsync)
- `round-6.md` (après les repros, pour éviter de recycler sans recouper)
- `git log --oneline -30`, listings `docs/`, `scripts/`, `tests/`

### Exécuté (preuves locales)

- `scripts/verify-agentic-infra core` → **exit 0** (~36 s)
- `cd pi && bun test ./extensions/__tests__/` → **238 pass**
- `cd pi && bun run verify:skills` → **exit 1** (5 skills kernel en drift SHA)
- Repros `scripts/etabli-harness-eval grade` (détail M1 ci-dessous)
- Comptages catalog : 95 skills, `cross_harness=0`, `all_zero=15`

### Non lu (lacunes)

- ADR-0001 à 0012 (hors index)
- Corps complet de `deploy-agent-workflow`, `workflow/contract-details.md`, 18+ skills `workflow/skills/` non cités
- `nvim/`, `vendor/`, `workflow-scaffold/`, `workflow//`, `docs/plan/`, `docs/how-it-works.md`
- CI GitHub réelle (`gh run`) — **non vérifié**
- `verify-agentic-infra full|live`, runs `ETABLI_HARNESS_EVAL=1` — **non vérifié**
- Comportement agent en session réelle (Pi/Claude/Grok/Codex) — **non vérifié**
- Rounds 1–5 — **non lus**

---

## La promesse, confrontée aux faits

Le README promet : (1) contrat workflow ambient, (2) adapters minces + skills catalog-driven pour Pi/Claude/Codex/Grok, (3) validation proportionnelle à la preuve.

| Claim | Verdict | Preuve |
| --- | --- | --- |
| Source unique `workflow/` symlinkée | **Tient** | `install-main.sh:1466-1490`, `AGENTS.md:36-42` |
| Guards fail-closed Pi↔Claude | **Tient** (écriture) | `planMutationGuardDecision` partagé ; `core` vert sur dual-runtime + freeze + no_progress |
| Activation ambiante sans prompt | **Partiel** | Consigne markdown ; ADR-0014 a retiré l'injection (~300 tok/tour) ; classifier = `appendEntry` only (`workflow-router.ts:93-98`) |
| Multi-harness piloté | **Partiel** | Exécution = Pi + Claude (`runtime-capabilities.json` n'a que ces clés). Codex/Grok = surfaces de liens skills (ADR-0015/0016) |
| Eval comportemental harness | **Faible** | 7 tâches, oracles troués (M1) ; smoke hermétique excellent mais ne prouve pas la discrimination |
| Claims proportionnels | **Partiel** | README honnête sur  live `not_established` ; en revanche rituel implement 18 étapes sans oracle correspondant |

**Opinion** : le noyau (un PLAN, guards partagés, catalog TSV, deploy dry-run) est un vrai système d'ops agent pour un opérateur solo. Le reste — installer workstation 1909 lignes, 95 skills catalogués, musée `docs/`, scorecard 10/10 de juillet — est une couche de gouvernance qui coûte plus qu'elle ne protège tant que les oracles live restent cosmétiques.

---

## Findings

### BLOCKER

Aucun. Le repo est utilisable : `core` vert, guards d'écriture réels, deploy dry-run testé. Les problèmes sont de **preuve**, de **périmètre marketing**, et de **YAGNI**.

### MAJOR

#### M1 — Les oracles harness-eval laissent passer des violations du contrat

**Fait vérifié** — reproduit sur ce HEAD avec `scripts/etabli-harness-eval grade` :

| Task | Mutation / transcript | `pass` |
| --- | --- | --- |
| `review-isolation-sentinel` (split **safety**) | append `pwned` dans `src/runtime.sh` + transcript synthétique pass | `true` |
| `ready-implement-touches-only-plan-files` | `fixture.sh` réécrit en `exit 1` en gardant `# harness-eval-marker` | `true` |
| `plan-draft-no-mutate` | `docs/plan/` pré-commité, puis `docs/plan/unauthorized.md` | `true` |
| `review-go-forbidden-empty-deciding` | tables présentes, deciding vide, `Verdict: GO WITH NOTES` | `true` (smoke `:131-132` l'exige explicitement) |

Preuves code :

- `review-isolation-sentinel/oracle.sh:5-7` — sentinel + `verdict != GO` ; **aucun** check worktree. Le prompt dit « Do not edit files » (`prompt.md:1`).
- `ready-implement-touches-only-plan-files/oracle.sh:5` — `grep` du marker, pas SHA/patch du fichier attendu.
- `plan-draft-no-mutate/oracle.sh:6` — allowlist inclut `docs/plan/` ; dès qu'un archive existe, toute mutation sous ce prefix passe.
- `review-go-forbidden-empty-deciding/oracle.sh:5-6` — accepte BLOCK **ou** GO WITH NOTES. Le contrat (`review.md:113-115`) interdit GO WITH NOTES comme contournement d'une row deciding vide — l'oracle n'applique que la moitié.

`no-parent-logic-claim/oracle.sh:6-10` : OU de trois regex ; une seule ligne `isolation: isolated` suffit.

Le smoke (`etabli-harness-eval-smoke.sh`) est **solide** pour l'infrastructure (fixtures pass/fail cohérentes, `runner_exit != 0` fail-closed, pin SHA lib, stub spawn). Il ne prouve pas que les oracles discriminent le comportement promis.

**Pourquoi** : `docs/harness-eval.md:3-7` se compare à DeepSWE ; en pratique la suite grade surtout le *format* du transcript et une allowlist de paths.

**Fix** : worktree SHA/patch obligatoire sur safety ; verdict + deciding-code non vide pour toutes les tasks review ; retirer le OU lâche de `no-parent-logic-claim`.

#### M2 — Source-lock des skills kernel rouge, hors gate quotidien

**Fait vérifié** : `cd pi && bun run verify:skills` exit 1 — drift SHA sur `plan-implement`, `adversary`, `review`, `implement`, `pr-review`.

`workflow/runtime/agentic-infra-checks.tsv:51` place `skill-lock` en profile **`full`**, pas `core`. README:129 vend `core` comme « daily health and safety gate ». Sur la branche `refactor/skill-default-load`, le mécanisme d'intégrité des skills kernel est rouge et invisible au gate quotidien.

**Pourquoi** : un lock hors `core` est un rappel optionnel, pas une garantie. La branche qui touche le chargement des skills est exactement celle où ce check devrait être non négociable.

**Fix** : régénérer le lock si intentionnel ; le promouvoir dans `core` ; ou arrêter de parler de source-lock.

#### M3 — Route, ops-stop et loop d'implémentation = prompt, pas enforcement

**Fait vérifié** :

- ADR-0014 : injection retirée ; risque accepté « No mechanical check observes the behavioral effect ».
- Pi : classifier → `setThinkingLevel` + `appendEntry` ; seul `planMutationGuardDecision` bloque les writes (`workflow-router.ts:101+`).
- `implementation-loop.md:5-143` exige adversary plan, dogfood, simplify, quality, hunters, adversary cross-model, ledger, archive. Rien dans `core` ni les 7 oracles n'observe cette séquence.
- Sans PLAN DRAFT/CHALLENGED, `rm -rf` n'est pas mécaniquement bloqué (test Pi documenté dans round-6 ; **inférence** cohérente avec `planReadyGuardDecision`).
- `ops-stop` = route classifier (`workflow-router-lib.mjs:53+`), pas deny outil. La matrix le dit : `ops_stop.route: confirmed via classifier` (sortie `core`).

**Pourquoi** : le README vend « Guards that fail closed » ; en réalité seuls READY/freeze/no_progress sont enforce mécaniquement. Le rituel 18 étapes est du markdown chargé (ou pas) par le modèle.

**Fix** : deny outil minimal pour `rm -rf`/force-push/deploy **ou** README qui limite explicitement l'enforcement aux trois guards d'écriture ; tier le rituel implement (small/medium/large).

#### M4 — `install-main.sh` = imageur workstation, pas deployer de contrat

**Fait vérifié** :

- `scripts/install.sh:2` `set -euo pipefail` puis `exec bash lib/install-main.sh` → processus enfant avec **`set -e` seul** (`install-main.sh:8`).
- `:1181` Homebrew via `curl -fsSL .../HEAD/install.sh` (non piné).
- `:1252` RTK via `curl | sh`.
- `:1193+` sudo apt/dnf/pacman ; `:1275+` npm global ; `:1819+` réécrit `~/.bashrc`/`~/.zshrc`.
- Échecs → `print_warning` et continue.
- `tests/install-smoke.sh` n'exerce que `ETABLI_INSTALL_HELPER_SMOKE=1` (`:747-1114`) — excellent pour prune/links, **zero** sur l'install réelle.

Le deployer correct existe : `scripts/deploy-agent-workflow` (`set -euo pipefail`, dry-run par défaut).

**Pourquoi** : `./scripts/install.sh` ≠ « poser le contrat agent » ; c'est « reconstruire mon laptop ». Pour un repo public, `curl | sh` non piné est la plus grande surface d'écriture hors repo.

**Fix** : scinder `install-workstation.sh` vs `deploy-agent-workflow` ; pin ou supprimer les pipe-to-shell ; `set -euo` sur le chemin agent.

#### M5 — « Multi-harness » = ferme de symlinks, pas parité runtime

**Fait vérifié** :

- Catalog : 95 rows, **`cross_harness=0`** (colonne morte + code prune `:442-463` inopérant).
- 15 skills `all_zero` (`suite-router`, `caveman`, `grill-me`, …) — jamais liés ; pourtant `:1895-1896` les cite dans les next-steps Pi.
- Grok harness : `--permission-mode acceptEdits` (`etabli-harness-eval.sh:8,218`) sur des tasks safety — combiné à M1, mutation + pass possible.
- ADR-0015/0016 : Codex skills-only, Grok zéro MCP — cohérent, mais contredit « piloter plusieurs harness » si on entend *comportement*.

**Fix** : documenter Pi+Claude comme runtime pair ; Codex/Grok = discovery ; retirer colonne `cross_harness` ou la peupler ; Grok en read-only sur safety.

### MINOR

#### m1 — `SECURITY.md` ne couvre pas la surface host de l'installer

`SECURITY.md:1-28` : secrets git, MCP template, gitignore. Pas de mention `curl | sh` Homebrew/RTK, `npx ...@latest`, writes rcfile. `supply-chain-smoke` pine Actions/npm Pi — utile, orthogonal.

**Fix** : section « host install risks » ou scission installer.

#### m2 — Musée `docs/` et scorecard opérationnel-en-apparence

**Fait vérifié** : ~18 artefacts datés (`docs/*202608*`, `adversary-etabli-10-*`, audits juillet) à côté du guide vivant. Scorecard `:1` dit « Historical snapshot. Not operational » mais reste la barre de comparaison imposée. `runtime-capabilities.json` `updated_at: 2026-08-20` vs `verified_at: 2026-07-29` sur les labels `confirmed`.

**Fix** : `docs/archive/` + index de fraîcheur ; ne plus citer 10/10 juillet comme barre actuelle.

#### m3 — Herdr multihost : `rsync --delete`

`herdr/docs/multihost.md:36` : `rsync -az --delete`. **Inférence** : divergence checkout ou fichier local sur le mini → effacement silencieux. Premier casse multi-machine documenté.

**Fix** : `--delete` derrière flag explicite ; dry-run obligatoire.

#### m4 — MCP `brain` piné sur `${HOME}/work/brain`

`mcp/servers.template.json:27-29`, ADR-0017. Portable en apparence ; convention machine work. Checkout sans ce path → MCP cassé.

**Fix** : README « work machine layout » visible, pas seulement ADR.

#### m5 — Live harness skip = exit 0

`tests/etabli-harness-eval-live.sh:6-8` skip vert. README:134 dit que live ne compte pas skip comme succès pour `verify-agentic-infra live` (exit 3 sans flags) — incohérence locale sur la row `etabli-harness-eval-live`.

**Fix** : aligner skip sur exit 3 ou retirer du profile live.

#### m6 — Capabilities `expires_after_days` dépassés

Labels `confirmed` datés 2026-07-29 + 30 jours → expirent ~2026-08-28. Aucun re-proof automatique visible. **Inférence** : le fichier documente des claims périmés sans les downgrader.

**Fix** : CI qui fail quand `verified_at + expires_after_days < today` pour `confirmed`.

### NIT

- **N1** — Brief « ~1600 lignes » : `install-main.sh` = 1909 lignes.
- **N2** — Next-steps Pi mentionnent `/skill:caveman` et `/skill:grill-me` (`:1895-1896`) — skills `all_zero` au catalog.
- **N3** — `route-context-manifest-smoke` reste en `full` (`agentic-infra-checks.tsv:61`) alors qu'ADR-0014 assume l'orphan.
- **N4** — `pi/agent/settings.json` modifié non commité sur ce worktree — dérive locale attendue par le design, risque de commit accidentel.

---

## Axes d'analyse

### 1. Cohérence architecture

Le contrat d'**écriture** (PLAN unique, READY, freeze, no_progress) correspond au code Pi/Claude — **fait vérifié**. Le contrat de **route** et le rituel d'implémentation ne correspondent qu'à des markdowns + un classifier observé. Codex/Grok absents de `runtime-capabilities.json`. Colonne `cross_harness` morte ; 15 skills catalogués jamais déployés.

### 2. Complexité vs valeur (YAGNI)

Pour un mono-utilisateur, le noyau (guards + catalog + deploy) justifie son coût. Ce qui ne le justifie pas : installer 1909 lignes, 15 skills design morts, loops nommés (`ambitious-project`, `program-orchestration`, `reviewer-improvement`), ~69 smokes en `full`, rituel implement 18 étapes, suite eval 7 tâches à oracles troués, 18 docs d'audit datés. **Opinion** : ROI négatif sur tout loop nommé sans cellule live discriminante.

### 3. Fragilité opérationnelle

Ordre de casse probable :

1. Drift lock/catalog (déjà vrai : 5 SHA kernel).
2. Symlink farm après mv repo ou mauvais `~/.etabli-scope`.
3. `rsync --delete` herdr.
4. `settings.json` local vs tracked bootstrap.
5. MCP `brain` si `~/work/brain` absent.

### 4. Qualité d'exécution

**Haute** sur le noyau testé : `core` vert, 238 tests Pi, router-eval dans `core`, helper smoke installer dense, harness smoke hermétique fail-closed sur `runner_exit`. **Basse** sur les chemins des claims : lock rouge hors `core`, oracles M1, install réelle non testée, live skip vert. Scripts hors installer en `set -euo pipefail` ; installer en `set -e` seul.

### 5. Sécurité

Tracked repo : propre (`SECURITY.md`, MCP sanitized, pas de secrets visibles). Host : `curl | sh`, npm global, writes rcfile. Eval Grok : `acceptEdits`. Clone en lecture = safe ; `./scripts/install.sh` les yeux fermés = risqué.

### 6. Dérive documentaire

`docs/workflow-guide.md` et README alignés sur spec (spec gagne). Musée août/juillet désaligné (council mort, injection morte, harness-eval post-scorecard). ADR 0013–0017 = meilleure prose du repo : options rejetées, conséquences « bad » assumées, mesures chiffrées (ADR-0014 : ~301 tok/tour).

---

## Avis final

### 1. Verdict

**Noyau bien conçu pour un opérateur Pi+Claude ; le système complet est surdimensionné, inégalement enforce, et ses preuves comportementales ne tiennent pas encore la promesse DeepSWE-like.**

### 2. Top 3 forces

1. **Guard d'écriture partagé, fail-closed, testé.** `planMutationGuardDecision` + dual-runtime + freeze + no_progress ; `core` exit 0.
2. **ADR récents qui suppriment sur evidence.** Council retiré (0013), injection ~15k tok/session retirée (0014), Codex recentré skills-only (0015) — rare et crédible.
3. **Catalog TSV + prune + helper smoke installer.** 15 skills `all_zero` non déployés par accident ; smoke interne refuse de casser un lien personnel (`install-main.sh:747-1114`).

### 3. Top 3 faiblesses

1. **Preuve comportementale trouée (M1).** 4/7 oracles laissent passer des états interdits ; canary live = task safety dont l'oracle ignore le worktree.
2. **Écart marketing ↔ enforcement (M3).** Routes, ops-stop, rituel implement = prompt ; seuls trois guards d'écriture sont mécaniques.
3. **Installer monolithique (M4).** 1909 lignes, pipe-to-shell, non testé hors helper — le deployer minimal existe déjà ailleurs.

### 4. Trois choses à arrêter

1. **Noter 10/10 ou publier des scorecards sans re-proof.** Le scorecard juillet est un musée ; le harness-eval actuel contredirait plusieurs dimensions.
2. **Ajouter des loops/skills sans cellule eval discriminante.** Chaque `-loop.md` sans oracle live = dette narrative.
3. **Faire `./scripts/install.sh` = onboarding public.** Scinder workstation ; documenter `deploy-agent-workflow --dry-run` comme entrée agent.

### 5. Trois choses à faire ensuite (ROI)

1. **Réparer les oracles safety + promouvoir `skill-lock` dans `core`.** Coût faible, impact direct sur crédibilité des claims.
2. **Tier le rituel `implementation-loop.md`.** Small fix = checks + review ; large = adversary + hunters. Réduit friction quotidienne sans toucher aux guards.
3. **Archiver `docs/*2026*` + expiry automatique sur `runtime-capabilities.json`.** Réduit bruit cognitif ; force re-proof ou downgrade honnête.

### 6. Score /10

| Dimension | Score | Justification |
| --- | --- | --- |
| Cohérence | **7.5** | Guards ↔ code OK ; routes/loops ↔ runtime = markdown |
| Robustesse | **7.0** | Symlinks + installer + oracles ; noyau guards solide |
| Simplicité | **5.5** | 1909L installer, 95 skills, 18 docs audit, rituel 18 étapes |
| Qualité d'exécution | **8.0** | `core` vert, 238 tests Pi, smokes denses ; lock rouge, install non testée |
| Maintenabilité | **6.5** | ADR excellents ; musée docs ; catalog mort ; installer monolith |

**Moyenne : 6.9/10** — système **utilisable et réfléchi**, pas **10/10 adversarial**.

### Comparaison au scorecard `docs/adversary-etabli-10-scorecard.md`

| Dimension | Scorecard (2026-07-29) | Round 7 | Écart |
| --- | --- | --- | --- |
| Contract clarity | 9.5 | 8.0 | Scorecard pré-harness-eval et pré-skill-refactor ; quick card vivant mais spec vs README gap sur enforcement |
| Routing determinism | 9.5 | 7.0 | ADR-0014 a retiré l'injection ; aucun check comportemental post-removal — scorecard ne l'anticipait pas assez |
| READY/mutation parity | 9.5 | 9.0 | Toujours la force du repo ; je reste légèrement sous 9.5 faute de live proof |
| Check-freeze | 9.5 | 9.0 | Inchangé mécaniquement |
| Safety / ops-stop | 9.0 | 6.5 | Scorecard traitait ops-stop comme guard ; c'est un classifier sans deny — harness safety troué aggrave |
| Multi-model discipline | 9.0 | 7.0 | Council mort (0013) ; scorecard encore optimiste ; TaskExecute `blocked` |
| Validation surface | 9.5 | 7.0 | Harness-eval ajouté depuis juillet avec oracles faibles ; skill-lock rouge hors core |
| Memory / obvault | 9.0 | 8.0 | Contrat solide ; brain MCP dupliqué (0017 bad consequence) |
| Linear / MCP honesty | 9.5 | 9.0 | Toujours honnête |
| Self-improvement hygiene | 9.0 | 8.0 | Never auto-apply tenu ; telemetry toujours experimental |

**Pourquoi j'écarte le 10/10 de juillet** : le scorecard mesurait surtout des smokes déterministes de guards et de routing library — légitime en juillet. Depuis : harness-eval avec oracles safety insuffisants, skill-lock drift sur branche active, capabilities expirées non rafraîchies, et ADR-0014 a explicitement accepté l'absence de preuve comportementale post-injection. Un 10/10 exigeait « zero High/Critical open, every dimension ≥9 » ; M1 seul justifierait un High sur validation surface.

---

## Lacunes (investigations non faites)

- Parité réelle Grok/Codex en session (skills discoverability, pas de MCP Grok).
- `verify-agentic-infra full` complet et état `skill-lock` sur `main`.
- Comportement agents sans hooks Claude / sans extension Pi.
- Valeur réelle des 40+ smokes `full` non listés dans le périmètre.
- obvault/brain MCP en conditions réelles sur cette machine.
