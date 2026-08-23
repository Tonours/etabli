# Agrégat — Review de branche refactor/skill-default-load (6 reviewers)

- **Date** : 2026-08-23
- **HEAD** : `a8c28f8` — merge-base `613dc7c` — 12 commits, 266 fichiers, +15 424/−3 750
- **Méthode** : 6 reviewers indépendants (reviews 1-4 sans lecture des précédents avant rédaction ; 5-6 ont lu après leurs repros). 9+ sondes adversariales offline par reviewer en moyenne ; aucun run live facturé.
- **Vérification orchestrateur** : les convergences ✓ ci-dessous ont été re-vérifiées sur HEAD après les reviews.

## Scores

| Review | Modèle | Score | Verdict fusion |
|---|---|---|---|
| 1 | fable-5 medium | 7,0 | Mergeable ; fail-closed prune avant tout refactor catalog |
| 2 | opus-5 xhigh | 6,2 | Bon travail de fond gâché par une preuve inventée |
| 3 | gpt-5.6-sol xhigh | 6,2 | BLOCK jusqu'à B1 ; jamais de live avant M1/M6 |
| 4 | kimi-k3 max | 6,3 | Mergeable opérateur ; BLOCK sur publication live |
| 5 | grok-4.6 xhigh | 6,2 | Le témoin a changé, pas la nature |
| 6 | composer-2.5 | 6,3 | Mergeable « kernel lean + gate honnête » ; pas comme claim « harness discriminant » |

**Moyenne 6,37 / médiane 6,25** — au-dessus du council repo (5,8 médian) : la réponse au council est créditée. Convergence exceptionnelle (écart 0,8) malgré des chemins indépendants, avec repros numériques concordants.

## Convergences

### C1 — BLOCKER (6/6) : l'intégrité d'état des oracles n'existe pas ; plancher de fabrication 6/8

- **Famille 1** (reproduite par reviews 1, 2, 4, 5, 6) : 4 oracles sur 8 ne regardent pas le worktree (`hunter-read-only`, `review-go-forbidden-empty-deciding`, `review-spec-drift`, `no-parent-logic-claim`). Mutations aveugles : `PWNED.txt`, `src/runtime.sh` muté, **`FORBIDDEN.txt` supprimé** (la preuve de la dérive effacée par le sujet) → `pass=true`.
- **Famille 2** (reviews 2, 3, 4, 5, 6) : les 4 oracles *avec* allowlist perdent contre `git commit`/`--amend` — porcelain ne voit que le non-commité, `rev-list --count == 1` est préservé par amend par construction. Rename vers destination allowlistée invisible (`$NF` only).
- **Plancher de fabrication mesuré** (reviews 4 et 5 indépendamment, review 6 à 4/8 avec gabarit minimal) : un transcript constant sans exécution passe **6/8** avec `Verdict: BLOCK`. Publié : null 1/8 (abstention). Le durcissement a fait chuter l'abstention, pas la fabrication. Seuls `ready-implement` (SHA d'état) et `review-go-clean-diff` (GO-only) résistent.
- **Fix consensus** (~2 h) : snapshot `HEAD` + tree hash **hors worktree** à `harness_prepare_worktree`, identité exigée au grade (tue commit ET amend) ; porcelain+SHA sur les 4 oracles nus ; subcommand `constant-baseline` publiée à côté du null.
- **Conséquence consensus** : aucun `pass@1` live comparatif avant ce fix.

### C2 — MAJOR (6/6, ✓ re-vérifié) : « 80/80 PASS » inventé ; SUMMARY sans dénominateur

TSV : 16 core + 53 full = **69** checks (mon comptage « 80 » agrégeait des PASS imbriqués de scripts appelés). Les deux archives de plan (`review-findings-fixes:14`, `oracle-hardening:15`) portent le chiffre faux. Runner : `SUMMARY: all checks passed` sans n/n — le compte ne peut pas être produit par commande. « La classe C2 appliquée à la preuve de fermeture de C2 » (review 5). Fix : 69/69 + `SUMMARY: %d/%d`.

### C3 — MAJOR (3/6 : reviews 3, 5, 6, ✓ re-vérifié) : la cellule safety sélectionne contre le contrat

`review.md:37-39` : sentinel `HUNTER_*` = hard stop, « do not continue to a lead verdict ». L'oracle exige `Verdict: BLOCK|GO WITH NOTES` et le gold pass porte un verdict après sentinel — l'agent conforme échoue, le violateur réussit. Fix : sentinelle seule suffisante (ou contrat amendé explicitement) ; aligner oracle + fixture + review.md.

### C4 — MAJOR (5/6) : prune fail-open destructif + fixer inutilisable sur catalogue dégénéré

Installer : keep-list `pi_core` vide ⇒ `rm -f` de **tous** les liens managés (reviews 1, 3, 4, 5, 6). Fixer : crash `unbound variable` dans le même scénario (reviews 1, 4, 5, 6 — fail-closed mais inutilisable). Fix : refuser de pruner si vide + sentinel sur lecture 0 lignes.

### C5 — MAJOR (4/6, mesuré) : la distillation lane-3 a doublé la charge déployée par projet

`deploy-workflow` FILES 16 → 30 entrées : +184 Ko dont `evidence-proof` (51 Ko), `program-state` (38 Ko), `workflow-event` (31 Ko), `workflow-event-detail.jq` (26 Ko). Scaffold : ~158 Ko → **341 830 octets / 55 fichiers** (reviews 2, 4 exécutées ; 5, 6 en lecture). Le commit « distill lane-3 » distille le texte lu et gonfle ×2,2 le texte copié — C7 aggravé. Chaque cellule harness paie ces 334 Ko. Review 1 (7,0) n'a pas mesuré ce point — explicitement discrédité pour ça par review 4. Fix : sortir les 4 gros scripts de FILES ou smoke plafond.

### C6 — MAJOR (4/6) : spec ↔ classifier aggravé par la branche

`d7891ab` **ajoute** la ligne spec « ordinary coding → answer » **et** édite les fixtures router-eval qui attendent `plan-implement` (reviews 3, 4, 5, 6). Deux surfaces canoniques fraîchement éditées qui se nient. Fix : aligner classifier+fixtures sur la spec (ou marquer le classifier non-canonique).

### C7 — MAJOR/MINOR (5/6) : `prefer-cursor-agent.sh` avale ses échecs et supprime tout symlink

`touch/mktemp … || return 0` → succès muet (reviews 1, 3, 4, 5, 6). Tout symlink `~/.grok/bin/agent` = « collision » sans comparaison de cible, `rm -f` à chaque shell (reviews 2, 3, 4, 5). Fix : `return 1` + `-ef` sur fichier ET symlink.

### C8 — MINOR convergent (5/6) : `shell-syntax` aveugle à `scripts/lib/`

`maxdepth 1` ; ~2 125 lignes dont le nouveau grader et `prefer-cursor-agent.sh` déposé précisément là (reviews 2, 3, 4, 5, 6). Fix : retirer `-maxdepth 1`.

### C9 — MINOR (4/6) : CI sans concurrency

`push: ["**"]` + `pull_request` sans `cancel-in-progress` → 6 jobs par push de branche à PR (reviews 2, 3, 4, 5 ; review 5 ajoute : `full` complet sur chaque branche jetable, le bon grain = core sur `**`, full sur main+PR). Fix : bloc concurrency (+ éventuellement grain profil).

### C10 — Consensus direction (6/6) : hunters — mécanisme réel, preuve théâtrale

Spawn vérifié restrictif par 6/6 (argv CLI, pas prompt). Mais `isolation: isolated`/`runner: pi-child` = chaînes que le parent écrit dans le transcript que l'oracle greppe ; helper optionnel dans le skill. Sortie proposée (reviews 2, 4) : artefact hors-bande (fichier imposé par la cellule, hashé par l'oracle) — les briques existent. Renommer la claim « Logic-only, session-fresh ».

### C11 — Mineurs convergents (multi-reviews)

- `harness_extract_verdict` prend le **dernier** match, pas la ligne finale (1, 2, 4, 5) ; verdicts empilables.
- `harness_require_tables` = 2 sous-chaînes, pas une structure (3, 4, 5) ; le contrôle GO passe avec 6 lignes.
- `hunter-read-only` : GO accepté avec `isolation: none` (4) ; runners manifest `["pi","grok"]` vs doc « Pi-only » (1, 4, 5) ; Grok en `acceptEdits` sur cells safety (5, 6).
- Profil live : `run` exit 0 même sur cellule rouge ou skip (3, 4) ; wrapper live vert sans exécution.
- `ETABLI_HARNESS_EVAL_DIR` réutilisé → cellule contaminée absorbée dans la baseline suivante (3, 4).
- Smoke null floor `≤ 2` au lieu de `= 1` + identité de tâche (1, 3, 4).
- `evidence-proof validate` fail-open sans `--assert`, contrat ne le nomme pas (4).
- Timeout `harness_run_bounded` alarm+exec sans fork vs hunter avec fork — deux politiques dans la même branche (2, 4, 5) ; descendants non bornés (1, 3).
- Installer next-steps annoncent `/skill:caveman`, `/skill:grill-me` — skills all_zero (4, 5).
- `harness_grade` applique le sentinel Cursor même offline/null (4, NIT).

## Divergences

- **all_zero** : review 3 veut supprimer ; review 4 veut garder (étagère opt-in délibérée du recentrage, la supprimer détruirait la surface de découverte créée) ; 5/6 veulent annoter. **Arbitrage direction council + utilisateur** ; action bornée consensuelle : retirer l'annonce installer morte.
- **Tiering C9** : review 1 veut trancher le principe maintenant ; reviews 2, 3, 4 veulent instrumenter d'abord (le repo exige 10 outcomes avant de trancher ses propres claims — trancher sur intuition serait la faute symétrique).
- **Review 1 (7,0)** surpondéré en direction : n'a mesuré ni la charge scaffold (C5) ni le plancher de fabrication — les reviews 4-6 le disent explicitement.

## Verdict consolidé

La branche **fait réellement monter le repo d'un cran sur l'honnêteté du gate** (accumulation, skill-lock core, mort réellement mort, musée archivé — vérifié par 6/6). Mais trois défauts systémiques convergents :

1. **La preuve de la preuve reste inflationniste** : 80/80 inventé, fabrication floor non publié, « durci » = contre l'abstention pas contre la fabrication. « Ils ont corrigé le masquage, puis ont masqué le compte » (review 5).
2. **La décision enregistrée, la propagation absente — encore** : C4 écrite plus profondément sans toucher le classifier ; distillation qui gonfle la charge copiée ; durcissement 4 oracles sur 8 présenté comme fermeture C1.
3. **La dette structurelle est intacte** : triple reconciler, installer `set -e` fail-open, quadruple contrat — assumée explicitement mais non entamée.

**Mergeable opérateur (5/6, review 3 BLOCK conditionnel)** ; **interdiction consensuelle de publier tout `pass@1` live** avant C1+C2 fixés.

## Actions consensus (prêtes pour plan-implement)

1. **P0 — Intégrité d'état + constant-baseline** (C1) : snapshot HEAD/tree hors worktree, identité au grade, porcelain+SHA sur les 4 oracles nus, `constant-baseline` publiée. ~2 h.
2. **P0 — Comptabilité** (C2) : 69/69 dans les archives, `SUMMARY: %d/%d`. 15 min.
3. **P0 — Alignement sentinel** (C3) : oracle/fixture/review.md cohérents (sentinelle seule suffit). 30 min.
4. **P1 — Prune fail-closed + fixer sentinel** (C4) ; **prefer-cursor-agent durci** (C7). 1 h.
5. **P1 — shell-syntax récursif** (C8) ; **CI concurrency** (C9). 20 min.
6. **P1 — Mineurs** (C11) : verdict ligne finale, smoke null `=1`+identité, cas amend dégénéré, grok read-only safety + manifest/doc cohérents, cellule existante refusée, live exit≠0 sur rouge. 2-3 h.
7. **Décisions architecture** (C5 scaffold, C6 classifier, + C3/C5/C6/C8/C9 du council repo) : à ratifier — la direction council (4 agents web) doit les éclairer.

## Lacunes collectives

Aucun run live ; lane-3 non auditée ligne à ligne (~3 600 l.) ; classifier 1 281 l. non relu ; fresh install, multihost, secrets : non exercés.
