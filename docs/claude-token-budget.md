# Claude Code — lancements et budget de contexte

État du candidat au 2026-10-02, dans le worktree `claude-efficiency-audit`.
Les corrections sont vérifiées par fixtures hors ligne. Les modèles/efforts
natifs, la navigation et les économies d'abonnement attendent une validation
Claude avec quota disponible. Aucun gain chiffré nouveau n'est démontré.

## Points d'entrée

Depuis le worktree :

```bash
scripts/claude-daily --inspect     # CLI/store/arguments; aucune inférence
scripts/claude-daily               # capacités, modèle et effort natifs
scripts/claude-deep                # opusplan : Opus 5.5 planifie, Sonnet 5.5 exécute
scripts/claude-deep --model claude-sonnet-5-5 --effort low
scripts/claude-daily --teams       # opt-in expérimental explicite
scripts/claude-lean --inspect      # profil limité, vault choisi par projet
scripts/claude-full                # passthrough natif conservé
```

`--store DIR` exige un répertoire existant. Sans override, le store natif reste
implicite et `CLAUDE_CONFIG_DIR` n'est pas ajouté. `--claude-bin FILE` ou
`ETABLI_CLAUDE_BIN` fixe le binaire. Une cible invalide est refusée, sans fallback
silencieux. `--` protège les mots du prompt qui ressemblent aux options du
lanceur. L'inspection prouve les arguments demandés, pas le modèle/effort effectif.
Les teams valent0 par défaut pour daily/deep/lean, même avec un environnement à1.
Les agents ordinaires et leurs rôles restent définis par les préférences natives.
En terminal, Ctrl-C conserve l'annulation native; un arrêt externe du wrapper
emploie SIGTERM ou SIGHUP pour transmettre le signal et nettoyer le MCP.

Lean garde le choix natif du LSP TypeScript et de l'effort. Ses11 désactivations
explicites de plugins sont une surface facultative conservée de l'ancien profil,
pas une nouvelle optimisation validée sur macbook-work. Le résolveur partagé
choisit Etabli→obvault et ForestAdmin→brain, ou un `OBVAULT_ROOT` exclusif. Un
vault indisponible rend un MCP vide, sans fallback. Le fichier temporaire0600
est propre à la session et supprimé à la sortie. `--no-strict-mcp` transmet
également ce fichier **et conserve les MCP natifs**; leurs vaults restent
accessibles. Le mode strict isole les seuls MCP fournis.

La statusline ajoute effort, quatre compteurs `parent(last)`, cache et quota du
compte5h/7j si le payload natif les expose; absent/invalide affiche `inconnu`, zéro
reste zéro. Elle conserve Git dirty, couleurs et contexte restant. Aucun appel
provider ni lecture de credentials. `tok/s` n'est pas ajouté: l'ancien helper
optionnel n'est présent dans aucun store local inspecté. L'activation native de
l'affichage reste à vérifier; aucun settings d'authentification n'est modifié.

## État historique au 2026-09-02

Les éléments ci-dessous décrivent la campagne antérieure, pas les nouveaux
lancements ni une validation live du candidat actuel.

### 2. Matrice des subagents alignée sur `candidate_a`

| rôle | avant | après |
|---|---|---|
| scout | sonnet/medium/24 | inchangé |
| worker | opus/**high/40** | opus/**medium**/40 (sonnet/medium/24 essayé puis annulé : `6befdfe`, `2a5f3c8`) |
| reviewer | fable/medium/40 | **sonnet/medium/24** |
| adversary | fable/medium/40 | **fable/low/24** |

Fichiers historiques: `claude/scopes/shared/agents/*.md`. Leur application
dépend des liens du store choisi. Aucun rôle n’est modifié par la reprise hors ligne.

### 3. Comptabilité des tokens (schéma v2)

Les métriques (`outcome_metric`) comptent désormais les 4 composantes
(`input`, `output`, `cache_read`, `cache_creation`) via
`processed_total_tokens`; `total_tokens` garde sa sémantique historique.

## Preuves détenues (et leurs limites)

- Diagnostic de surface: premier appel lean **25 692 tokens** vs 52 538
  (1re requête pilot baseline) et 69 565 (médiane 30 j) — ratios 0.489 / 0.369.
  Diagnostic de surface uniquement.
- Calibration (fixtures synthétiques mini, lean): `candidate_a` 12/12 oracles
  verts; `baseline` rate 1 oracle review sur 3 et échoue la diversité
  adversary/reviewer; `candidate_b` incomplète. Ça valide la qualité des
  routes sur oracles déterministes, pas le gain quotidien.
- Pilot mesure: autorité `result.usage` prouvée (résidu 0 vs transcript
  dédupliqué).
- **Non prouvé**: le ratio ≤ 50 % E2E (holdout 72 mesures non joué). Le
  harness (`scripts/claude-agent-benchmark`, `scripts/claude-token-budget
  verify`) est réutilisable; prévoir un plafond ~140 processus.

## Gouvernance

- Toute nouvelle skill/plugin doit être classé dans
  `claude/settings.skill-overrides.json` (le check échoue sinon).
- L'index de skills est ré-audité par `scripts/claude-skill-load-check`
  (mode profil par défaut; `--no-profile` = gate hérité).
- Benchmark: `scripts/claude-agent-benchmark dry-run` (sans réseau) pour tout
  reprojet de mesure; ledger payant dans
  `.workflow/claude-token-budget/paid-processes.json` (68/128 consommés).


## Protocole actuel hors ligne

`scripts/claude-efficiency-campaign --dry-run` prépare36 cellules appariées et6
slots auxiliaires, avec les hashes des six prompts/fixtures/oracles. T5/T6 sont
de nouveaux holdouts par rapport à la campagne historique. Seul l'effort varie
medium→low; modèle exact, store, plugins, MCP et agents seront figés en commun
avant le premier appel. Toutes les cellules sont `not_run`, usage/quota inconnus.
Le CLI refuse `--run`: compte/usage inclus et runner live doivent encore être
établis. Les tests du protocole ne mesurent aucune livraison Claude.

L'économie d'abonnement reste **INCONCLUSIVE**. Le rapport courant et le rollback
sont dans `docs/claude-efficiency-results.md`; les preuves de reprise restent
sous `.workflow/claude-efficiency-offline/`.
