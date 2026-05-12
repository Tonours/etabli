# Autoresearch — Optimisation AGENTS.md / CLAUDE.md

## Objectif
Réécrire les 3 fichiers de config agent (pi/AGENTS.md, claude/CLAUDE.md, AGENTS.md) pour qu'ils soient drastiquement plus mappés sur le profil cognitif d'Anthony.

## Fichiers cibles
- `pi/AGENTS.md` — global agent config (symlinked to ~/.pi/agent/AGENTS.md)
- `claude/CLAUDE.md` — repo-level Claude config
- `AGENTS.md` — repo-level agent config

## Benchmark script
`scripts/autoresearch-eval-agents.sh` — évalue les 3 fichiers sur :
1. Densité opérationnelle (ratio règles actionnables / mots totaux)
2. Alignement profil (règles mappées sources Hermes)
3. Non-contradiction entre fichiers
4. Compatibilité Pi conventions

## Métrique primaire
`profile_alignment_score` (higher) — score composite 0-100

## Contraintes
- Pas de breaking changes sur les conventions Pi
- Garder anti-sycophancy, contrarian stance, ticket format, testing, commit format
- Garder architecture et chemins du repo
