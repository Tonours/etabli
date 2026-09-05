---
name: week-roadmap
description: Plan/replan the week or catch up; refresh ~/work/brain/Todo.md from Gmail, Calendar, Slack, Linear and GitHub. Separate from the daily standup.
---

# week-roadmap

Réécrit `~/work/brain/Todo.md` : une roadmap ordonnancée par jour, contrainte par le calendrier réel.

Le fichier est la source de vérité opérationnelle. Ce skill le **met à jour**, il ne repart pas de zéro : les items non faits gardent leur formulation et leur historique de dates.

## Règle non négociable : vérifier, ne pas recopier

Chaque état de PR, de ticket et de merge est **revérifié à chaque run**. Ne jamais reprendre un état affiché par une exécution précédente, ni par un message `#routines`, ni par le Todo lui-même.

Raison : la routine standup a affiché `#9815`, `#40`, `#41` comme « approuvées non mergées » pendant ~6 semaines. Vérification le 03/08 : #9815 mergée le 06/07, #40 le 23/06. Elle recopiait sa propre sortie derrière un avertissement « GitHub MCP sans accès repos privés » — alors que l'outil marche. Six semaines de faux travail dans une liste de priorités.

Un état non vérifié pendant ce run ne va pas dans le fichier. S'il ne peut pas être vérifié, l'écrire comme non vérifié, avec la date de la dernière vérification connue.

## Sources

Lancer les lectures en parallèle — elles sont indépendantes.

| Source | Appel | Ce qu'on cherche |
|---|---|---|
| Calendrier | `list_events` sur 7 jours | créneaux pris, conflits, invitations `needsAction` → détermine les fenêtres de dev |
| Gmail | `search_threads`, en excluant `notifications@github.com`, `no-reply@dtdg.co`, `gemini-notes@google.com`, `do-not-reply@slite.com` | sans le filtre, ~95 % du volume est du bruit de release et noie les mails humains |
| Slack | `slack_search_public_and_private`, un terme par appel | DMs de handover, threads clients, arbitrages. Ne pas composer `OR` avec des modifiers `to:`/`from:` — la recherche renvoie 0 résultat silencieusement |
| Linear | `list_issues` avec `assignee: "me"` | ce qui est réellement In Progress |
| GitHub | `gh` CLI en local, **pas** le MCP | le MCP claude.ai n'a pas les repos privés ; `gh` les a |

Pour GitHub, l'état qui compte :

```
gh pr list --repo <owner>/<repo> --author @me --state open \
  --json number,title,reviewDecision,mergeable,statusCheckRollup
```

`mergeable: "CONFLICTING"` sur une PR d'une stack veut dire que la stack n'est pas reviewable en l'état — le signaler explicitement, avec l'ordre de review.

Vérifier séparément toute PR que le Todo dit ouverte mais qui n'apparaît plus dans `--state open` : elle est probablement mergée, et la ligne du Todo est morte.

## Structure du fichier produit

1. **Contraintes de la semaine** — tableau jour / créneaux pris / fenêtre de dev, puis les deadlines externes. Le reste du plan s'y conforme : ne pas placer une tâche de trois heures un jour qui n'a que le matin.
2. **Un bloc par jour** pour la partie ordonnancée, ordonné par dépendance réelle. Un accès expiré ou une décision non prise passe avant ce qu'il bloque.
3. **Blocs thématiques** pour ce qui n'a pas de jour imposé (dette, GTM, admin).
4. **Note sur les données** en fin de fichier — les écarts trouvés entre le Todo précédent et l'état vérifié. C'est ce qui empêche une erreur de revenir la semaine suivante.

Chaque item porte ce qu'il faut pour agir sans rouvrir cinq onglets : identifiants (`PRD-834`, `#1752`), branche et commit, chemin de fichier, date et auteur d'une demande en attente. Un item qui dit seulement « répondre à Paula » est inutilisable dans trois jours.

Pour les tâches dépendantes, nommer le bloqueur dans l'item lui-même, pas dans un commentaire à part.

## Ce qui mérite d'être signalé

Au-delà de la liste, remonter dans le texte :

- **Un même symptôme chez plusieurs clients** — trois clients sur un bug, c'est une priorité différente d'un ticket isolé.
- **Deux promesses externes incompatibles** — une ETA annoncée par le sales et une deadline annoncée en interne, sur un seul backlog : l'écart est à arbitrer, pas à reporter.
- **Une divergence assumée avec un ticket** — si le plan de fix décrit dans Linear est faux et que l'implémentation s'en écarte, la review le découvrira. Le préparer.
- **Un besoin de fond derrière un ticket ponctuel** — noter le ticket à ouvrir, pas seulement le symptôme corrigé.

Ne pas lisser. Un désaccord entre deux sources est une information : l'écrire tel quel, avec les deux versions et leur date.

## Après écriture

Mettre à jour `~/work/brain/ref/current-work.md` si le `Next action` d'une initiative active a changé — c'est le point d'entrée, il ne doit pas contredire le Todo.

Respecter le contrat de `~/work/brain/CLAUDE.md` : pas de nouveau fichier sans demande, pas de dossier, frontmatter strict, pas d'emoji.

## Automatisation

Ce skill est manuel par défaut, et c'est volontaire : il réécrit un fichier de priorités, et une réécriture non relue est exactement le mode de défaillance décrit plus haut.

Pour le planifier malgré tout (lundi matin), utiliser `/schedule`. Contraintes de la plateforme cloud : intervalle cron minimum 1 h, pas d'env de build, et `gh` CLI **absent** du runner — en cloud, l'état GitHub passe par `mcp__github__*`, qui accède bien aux repos privés (prouvé le 2026-06-09). Une routine cloud qui affiche « sans accès repos privés » n'appelle pas l'outil : c'est le bug à ne pas reproduire.
