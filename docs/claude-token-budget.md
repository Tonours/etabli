# Claude token budget — configuration appliquée

État au 2026-09-02. Ce document décrit la configuration **appliquée** et son
mode d'emploi. Il ne revendique PAS de gain chiffré global: la mesure E2E
appariée (holdout 72 mesures) n'a pas été jouée — l'utilisateur a arrêté la
phase de mesure avant.

## Ce qui est actif

### 1. Entrée quotidienne légère: `claude-lean`

```bash
claude-lean          # session minimale (recommandé au quotidien)
claude-full          # surface complète, équivalent `claude`
claude               # intact, rollback natif
```

`claude-lean` applique pour la session seulement (rien de live n'est muté):

- 12 plugins désactivés (`claude/profiles/lean.settings.json`)
- surface de skills gouvernée: 78 entrées classées, 24 auto-invocables,
  index 6141 caractères (sous le garde 6510), `skillListingBudgetFraction`
  0.008
- MCP restreint et assaini (`--strict-mcp-config`): `brain` seul (scope work,
  si `~/work/brain` existe), rendu en fichier temporaire `0600` supprimé à la
  sortie
- effort de session `low` (les flags `--model`/`--effort` restent prioritaires)

### 2. Matrice des subagents alignée sur `candidate_a`

| rôle | avant | après |
|---|---|---|
| scout | sonnet/medium/24 | inchangé |
| worker | opus/**high/40** | **sonnet/medium/24** |
| reviewer | fable/medium/40 | **sonnet/medium/24** |
| adversary | fable/medium/40 | **fable/low/24** |

Fichiers: `claude/scopes/shared/agents/*.md` (symlinkés vers `~/.claude/agents/`,
effectif immédiat). Rollback par rôle: éditer le frontmatter (valeurs avant
ci-dessus) ou `git checkout`.

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
