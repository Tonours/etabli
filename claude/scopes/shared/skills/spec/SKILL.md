---
name: spec
description: Write, structure or revise employer specs, tech specs, Epics and design docs using its two templates. Use for /spec or spec-writing requests.
---

# Création de spec employer

Rédiger une spec employer qui tient les standards : le format réel de l'équipe (Linear) + les bonnes pratiques design-doc de l'industrie (Google, RFC, ADR). Le but d'une spec, c'est de **récolter du feedback AVANT de construire** — pas de documenter après coup.

## Deux niveaux, ne pas confondre

employer sépare deux docs. Identifie lequel on écrit AVANT de commencer.

| | Spec produit | Epic technique |
|---|---|---|
| Répond à | le **quoi / pourquoi** | le **comment** |
| Écrit par | produit / CS | tech |
| Template | `template-product.md` | `template-technical.md` |
| Sections clés | Problem/Goal/Solution, Discovery, Description, Screens, Expected behavior, Events | Contexte, Goals/Non-goals, Technical description, Alternatives, Cross-cutting, User stories, Estimations |

Une spec d'archi très technique (un service comme le BFF) est un **hybride** : prends le template technique, il porte déjà le contexte produit léger. Les deux templates sont dans le dossier de ce skill — copie le bon, remplis les `< >`.

## Le noyau vs le jetable

Dans les ~16 Epics employer réels, ce qui est **toujours là** : Scope/Owners/Product-spec · Technical description · User stories (points, Required/Optional) · Estimations · Questions. Ce qui est **boilerplate optionnel** (souvent collé, parfois omis) : le blockquote `> **Warning**` d'entrée, Design challenge, Tech approval. Garde le noyau, supprime l'optionnel inutilisé.

## Les sections que tout le monde oublie (et qui font la valeur)

L'industrie est unanime : sans elles, une "spec" n'est qu'un manuel d'implémentation. Les templates les incluent — ne les laisse pas vides par flemme.

- **Non-goals** — ce qui pourrait être un objectif mais qu'on exclut. Coupe le scope creep.
- **Alternatives considérées** — les autres approches sérieuses et *pourquoi rejetées*. C'est ce qui distingue une décision d'un manuel. Marque les choix irréversibles (one-way door).
- **Cross-cutting** — Sécurité & privacy, Rollout/migration (+ **rollback**), Monitoring. "N/A" assumé est OK ; absent ne l'est pas.

## Principes

- **Trade-offs > implémentation.** Si la solution est évidente sans aucun trade-off, la spec est inutile. Le cœur, c'est les choix et leur justification.
- **Vérifier, pas supposer.** Tout mécanisme technique se source `fichier.ts:ligne`. Sinon, le marquer "à confirmer". Une option écartée reste en ~~barré~~ avec le pourquoi. Un choix qui a changé → callout honnête.
- **Link, don't duplicate.** Pointer vers la spec produit / le repo, pas recopier. Mais embarquer 2-3 lignes de contexte pour éviter l'aller-retour.
- **Proportionné.** Petit changement = quelques lignes. Gros projet = découper. Pas de spec pour un changement trivial.
- **Statut explicite.** Draft → In review → Accepted, + qui doit valider.

## Rédiger le contenu

**La spec se rédige en anglais** (toutes les specs employer le sont). Pour la prose (contexte, justifications, transitions), utiliser le ton direct, transposé en anglais : invoquer le skill `write-direct`. Les contrats techniques (routes, payloads, types) restent exacts, pas stylisés. Schémas ASCII propres (box alignées, flèches sous ce qu'elles connectent).

Cible Linear : la spec vit dans un **Document** Linear (équivalent page wiki), rattaché à la team Product. Markdown standard. Linear ne rend PAS les callouts GitHub `> [!NOTE]` — un titre en gras dans un blockquote (`> **Note**` puis le texte) tient le même rôle. Garder les blockquotes pour les encarts importants.

## Avant de publier

- [ ] Tous les `< >` remplis ou supprimés
- [ ] Tous les commentaires `<!-- -->` retirés
- [ ] Sections "(optionnel)" inutilisées supprimées
- [ ] Non-goals et Alternatives non vides (ou "N/A" justifié)
- [ ] Mécanismes techniques sourcés `fichier.ts:ligne`

## Longueur

Mini-spec / changement incrémental : 1-3 pages. Gros projet : 10-20 pages max, au-delà découper. Tant que ça n'a pas shippé, on met la spec à jour quand le design dévie ; après, elle devient le point d'entrée historique.
