# Agrégat global — review externe etabli (7 rounds)

- **Date** : 2026-08-23
- **HEAD** : `a18d3ef` sur `refactor/skill-default-load`
- **Méthode** : 7 reviewers indépendants (prompt `/tmp/fable-review-prompt.md`), sans lecture des rounds précédents avant rédaction (rounds 1, 2, 3 indépendants ; 5 et 7 ont lu un round précédent après leurs repros, pour positionnement uniquement)
- **Rounds** : 1 fable-5@300k (externe antérieur), 2 fable-5 medium, 3 opus-5 xhigh, 4 gpt-5.6-sol xhigh, 5 kimi-k3 max, 6 grok-4.6 xhigh, 7 composer-2.5
- **Vérification croisée** : les findings ci-dessous marqués ✓ ont été re-vérifiés par l'orchestrateur (moi) sur HEAD après les rounds

## Scores

| Round | Modèle | Score | Verdict une phrase |
|---|---|---|---|
| 1 | fable-5 | 6,5 | Ingénierie de la preuve > valeur de ce qui est prouvé |
| 2 | fable-5 medium | 6,5 | Plateforme d'équipe habitée par une personne |
| 3 | opus-5 xhigh | 5,5 | Aucun état vert de référence ; la mesure ne mesure pas |
| 4 | gpt-5.6-sol xhigh | 5,6 | Kernel solide, système non convergent |
| 5 | kimi-k3 max | 5,8 | La source unique échoue là où elle devrait être la plus forte |
| 6 | grok-4.6 xhigh | 5,5 | Une partie des preuves est fausse |
| 7 | composer-2.5 | 6,9 | Utilisable et réfléchi, pas adversarial 10/10 |

**Moyenne 6,04 / médiane 5,8.** Convergence remarquable (écart max 1,4) malgré des chemins d'analyse indépendants. Les 7 rejettent unanimement le « solid 10 » du scorecard interne comme circulaire (grille choisie par le système, aucune dimension coût/simplicité, suite sans `full`).

## Convergences (findings retrouvés indépendamment par N rounds)

### C1 — BLOCKER : les oracles harness-eval notent le format, pas le comportement (rounds 3, 4, 5, 6, 7)

**Le finding le plus convergent et le plus grave.** Reproduit indépendamment par 5 rounds avec des contre-exemples identiques :

- Un transcript constant qui n'exécute rien et imprime les chaînes attendues passe **5 à 7 tâches sur 7** (round 3 : pass@1 = 0,857 pour un agent nul ; round 6 : 7/7).
- Trous précis : `review-isolation-sentinel` (split **safety**) ne vérifie pas le worktree — une mutation de `src/runtime.sh` + transcript synthétique passe ; `ready-implement` grep le marker sans hasher — `exit 1` + marker passe ; `plan-draft-no-mutate` allowliste `docs/plan/` entier ; aucune tâche n'exige `Verdict: GO` ; les sentinelles d'isolation sont des grep sur le transcript produit par le sujet évalué lui-même.
- Le smoke hermétique prouve que le grader est *stable*, pas *discriminant* (rounds 5, 6, 7 créditent la plomberie : fail-closed, pin SHA, sentinelles — les trous sont sémantiques).
- **Conséquence consensus** : tout `pass@1` live publié aujourd'hui serait une métrique récompensant l'obéissance au format. La suite ne peut pas départager Pi et Grok en l'état.

### C2 — BLOCKER : `full` rouge à HEAD + structure qui masque les pannes suivantes (rounds 3, 4, 5, 6, 7 ; ✓ re-vérifié)

- `skills-lock.json` en drift pour 5 skills kernel (`plan-implement`, `adversary`, `review`, `implement`, `pr-review`) — **dérive commitée** (git status propre), présente depuis `2a52ea4`/`295e5bf`, invisible au gate `core`.
- `scripts/verify-agentic-infra:80` : `run_check` sans accumulation sous `set -euo pipefail` → **le premier FAIL arrête le run**. 20 checks jamais exécutés, dont `codex-skill-description-smoke` — **également rouge** (`description drifted: herdr`, ✓ re-vérifié) et invisible.
- ADR-0014 avait documenté ce masquage exact le 2026-08-03 ; `spec.md:108` (« la 3e occurrence d'un finding devient un check mécanique ») n'est pas appliqué au runner lui-même.
- Round 3 en rajoute : `main` distant rouge depuis le 2026-08-20 (check agents Claude), 8 commits de la branche jamais validés par CI (workflow déclenché seulement sur `push: main` + PR).
- Note : le B1 de round-1 (SHA manifest harness-eval) a été corrigé pendant le council (`a18d3ef`) — c'est bien un cas réel de la classe de bug, attrapé par la review externe.

### C3 — MAJOR : trois reconcilers réimplémentent la « source unique » (rounds 3, 4, 5, 6)

`install-main.sh` (1909 l.), `deploy-agent-workflow` (715 l.), `check-fix-symlinks.sh` (495 l.) manipulent les mêmes ~25 chemins `$HOME` avec des politiques **déjà divergentes** : `managedModels` hardcodé à 5 dans le deployer vs tous les `enabledModels` trackés dans l'installer ; listes de stale commands différentes. Le « test » de parité est `expect(source).toContain("skill_catalog_names")` — une assertion de présence de chaîne. Round 3 : 38 liens dangling sur les surfaces managées, et le détecteur (`check-fix-symlinks.sh`) n'est dans **aucun profil** de gate.

### C4 — MAJOR : spec ↔ classifier divergent sur le cas le plus fréquent (rounds 4, 5, 6 ; ✓ re-vérifié)

`classifyWorkflowRoute("Corrige ce bug", { planStatus: "missing" })` → `plan-implement` (création de PLAN + 18 étapes), alors que `spec.md:135` route l'ordinary coding sans PLAN vers `answer` avec édition directe. Le `router-eval` 76/76 mesure la conformité du classifier à ses propres fixtures, pas à la table canonique qui « wins on conflict ». Impact borné aujourd'hui (classifier observationnel post-ADR-0014), mais toute réutilisation hérite de la contradiction.

### C5 — MAJOR : frontière mémoire work/personal contradictoire (rounds 4, 5, 6)

ADR-0017 : machine work = `~/work/brain`, obvault personnel **non enregistré**. Mais `AGENTS.md`, quick-card, `obvault-memory.md`, le resolver et leurs tests imposent tous `~/work/obvault`. Un agent work suivant le contrat lit la base personnelle que l'ADR exclut.

### C6 — MAJOR : l'installer est le chemin le plus privilégié et le moins discipliné (rounds 1, 2, 4, 5, 6, 7)

- `set -e` seul (pas `-u`/`pipefail`) sur 1909 lignes qui `rm -f`, `ln -sfn` et réécrivent les rcfiles ; SC2155 masque un catalogue vide → pruning **fail-open** (round 2).
- Supply chain : Homebrew `HEAD`, RTK `curl | sh` depuis `master`, 13 npm globaux non pinnés — alors que la CI pinne ses Actions par SHA. `SECURITY.md` ne couvre rien de tout ça.
- `install-smoke` n'exerce que le mode helper ; `shell-syntax` du gate (`maxdepth 1`) **saute `scripts/lib/`**.
- Rounds 4, 6, 7 : scinder installer workstation vs deployer agent ; le bon modèle existe déjà (`deploy-agent-workflow`, `set -euo pipefail`, dry-run par défaut).

### C7 — MAJOR : le contrat est écrit en quadruple exemplaire (rounds 1, 2, 3, 5)

`spec.md`, `agent-quick-card.md`, `contract-details.md`, `docs/workflow-guide.md` + tables de routing recopiées dans le README — tenus alignés par un smoke de 25-28 s (le plus lent du `core`). Round 3 chiffre : ~12,5k tokens de noyau contractuel chargés par session ; `deploy-workflow` copie 156 Ko de contrat dans chaque projet scaffoldé. Consensus : deux surfaces suffisent, les autres en pointeurs ou générées.

### C8 — MAJOR : SPOF volume externe (rounds 2, 3, 6, 7)

Tout `$HOME` pointe vers `/Volumes/Crucial/work/etabli` : volume démonté ⇒ workflow, extensions, nvim, tmux, Ghostty, herdr cassés **simultanément et silencieusement** (l'activation ambiante s'éteint sans message — l'agent continue hors contrat). Non mentionné dans README ni multihost. (Nuance : c'est un choix conscient de ce repo dotfiles sur portable ; le risque est le démarrage **sans** le disque.)

### C9 — MAJOR : rituel d'implémentation à 18 étapes / 4 passes de review sans preuve de ROI (rounds 1, 4, 5, 6, 7 — opinion convergente)

Adversary plan + simplify + quality + double hunter + adversary cross-model sur **tout** changement non-trivial, alors que le repo refuse ses propres claims de télémétrie avant 10 outcomes (`spec.md:86-87`). ADR-0013 avait mesuré « no quality gain » sur le council — le même scepticisme ne s'applique pas au pipeline de review lui-même. Consensus : trois niveaux de risque, cross-model réservé au high-risk.

### C10 — MINOR convergents

- **Lane `cross_harness` morte** (rounds 1, 3, 5, 6, 7) : 0/95 rows ; code + tests + prune + promesses AGENTS.md entretenus pour une lane vide. + 15 skills `all_zero` jamais liés mais parsés (rounds 6, 7).
- **`route-context-manifest` orphelin** (rounds 3, 4, 5, 6, 7) : ADR-0014 le déclare orphelin ; son smoke reste gated en `full`. ~410 lignes sans consumer.
- **Musée `docs/`** (tous les rounds) : ~18-21 analyses datées à la racine, bandeaux inégaux, 104 archives `docs/plan/`. Consensus : `docs/archive/` + index de statut.
- **Grok safety cells en `acceptEdits`** (rounds 6, 7) : l'oracle rattrape après coup ; un run live peut écrire avant le grade.
- **`mcp/servers.template.json` pinne `chrome-devtools-mcp@latest`** (round 6) ; **capabilities expirées sans re-proof + pas de clés grok/codex** (rounds 6, 7) ; **rsync `--delete` macmini** (rounds 6, 7) ; **pas de scanner de secrets** malgré la checklist SECURITY.md (round 4) ; **classifieur canonique hébergé dans `claude/hooks/`** (rounds 3, 6).

## Divergences notables

- **Gravité du B1 oracles** : round 4 dit « aucun BLOCKER » mais place les oracles en M1 ; rounds 3 et 6 les classent BLOCKER. Le fond est identique, la sévérité diffère.
- **Round 2 (fable medium) n'a vu aucun rouge** : il n'a pas exécuté `bun run verify:skills` ni `full` — sa fenêtre temporelle (23:11-23:18, post-`a18d3ef`) avait le smoke harness vert. Illustre la leçon de C2 : ce qu'on ne teste pas n'existe pas.
- **Round 7 (composer, sans thinking) note 6,9** — le plus généreux, notamment sur l'exécution (8,0). Cohérent avec un modèle sans raisonnement étendu moins enclin à sonder la gameabilité.

## Verdict consolidé

**Le noyau — PLAN unique, guards d'écriture partagés Pi/Claude fail-closed (`planMutationGuardDecision`), catalog TSV, ADR d'une honnêteté rare — est unanimement reconnu comme la vraie force du projet.** Autour de lui, trois défauts systémiques convergents :

1. **La preuve ne prouve pas** : la suite comportementale note le format (C1) et le gate complet est rouge en masquant ses échecs (C2).
2. **La « source unique » s'arrête aux fichiers** : procédures réimplémentées en triple avec divergence (C3), contradictions canoniques spec/classifier (C4) et brain/obvault (C5) — cinq instances du même défaut : *la décision est enregistrée, sa propagation ne l'est pas*.
3. **Le rituel dépasse l'usage** : complexité de plateforme régulée pour un opérateur solo (C7, C9), reconnue par les ADR eux-mêmes mais non ré-appliquée au stock récent.

## Actions consensus par ROI (prêtes pour plan-implement)

1. **Rendre le gate honnête puis vert** : accumulation des FAIL au lieu d'abort, régénération `skills-lock` (après review des 5 diffs), `skill-lock` promu en `core`, fix `herdr` description, CI sur toutes les branches. *(rounds 3, 5, 6 : « ~2 h, ROI immédiat »)*
2. **Durcir les oracles avant tout run live** : verdict obligatoire + worktree checké sur safety, hash d'état final sur implement, une tâche où GO est la bonne réponse, null baseline publié dans `harness_report`. *(rounds 3, 4, 5, 6, 7)*
3. **Une décision, une propagation** : trancher ordinary-coding (C4), brain/obvault (C5), un seul reconciler (C3). *(rounds 4, 5, 6)*
4. **Durcir/scinder l'installer** : `set -euo pipefail`, fail sur catalogue vide, pins npm, `shell-syntax` récursif, séparation workstation/agent. *(rounds 2, 4, 6, 7 : « une demi-journée »)*
5. **Passe ADR-0013-style sur le stock** : `cross_harness` (supprimer ou peupler), `route-context-manifest` (supprimer), 15 skills `all_zero`, `docs/archive/` + index, tier du rituel implement. *(tous)*

## Lacunes collectives (non couvertes par les 7 rounds)

- Runs live du harness (aucun round n'a facturé de modèle) ; fresh install réelle ; multihost macmini ; audit secrets de l'historique git ; `claude/hooks/workflow-router-lib.mjs` lu en profondeur (1281 l.) ; `vendor/`, `nvim/`, `herdr/` complets.
