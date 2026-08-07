---
name: bug-check
description: Analyse rigoureuse d'un bug à partir d'un ticket Linear (URL ou ID). Récupère le ticket, identifie le code impacté, mène une analyse adversariale et propose un plan de fix. Exige un niveau de certitude proche de 100%, sans assumption ni angle mort. Sortie conversationnelle uniquement, pas de fichier, pas de commentaire Linear.
---

# bug-check

Procédure Claude dérivée du contrat partagé `workflow/skills/bug-check.md`. Le
contrat fait foi entre runtimes (Pi le lit aussi) ; ce fichier est
l'implémentation Claude et peut aller plus loin, jamais à rebours.

Analyse un bug Linear avec exigence de certitude maximale. **Aucune assumption non vérifiée. Aucun angle mort toléré.**

## Entrée

URL Linear (`https://linear.app/<org>/issue/<ID>/...`) ou identifiant (`PRD-387`).
Si absent ou ambigu : demander une seule question bloquante.

## Règle d'or

À chaque affirmation, te demander : *« Est-ce que je le sais ou est-ce que je le suppose ? »*
Si c'est une supposition : soit tu la vérifies (lecture code, grep, run), soit tu la marques explicitement comme **HYPOTHÈSE NON VÉRIFIÉE** dans la sortie.

Pas de phrases comme « probablement », « sans doute », « il semble que » sans qualifier le niveau de preuve juste après.

## Phases (séquentielles)

### Phase 1 — Fetch ticket Linear
- Extraire l'ID du ticket depuis l'URL (regex : `/issue/([A-Z]+-\d+)`).
- Appeler `mcp__claude_ai_Linear__get_issue` avec cet ID.
- Lire titre, description, labels, état, comments (`mcp__claude_ai_Linear__list_comments`).
- Si attachments / diffs / liens vers PR : récupérer (`get_attachment`, `list_diffs`).
- Restituer un résumé factuel : 3-5 lignes max. Reproduction steps, comportement attendu vs observé, contexte.
- Si infos manquantes critiques (pas de repro steps, pas de scope) → poser **une** question avant de continuer.

### Phase 2 — Analyse du code impacté
Objectif : localiser la zone exacte du bug avec preuves.

- Identifier mots-clés du ticket (composants, routes, fonctions, messages d'erreur).
- `grep` / `find` pour localiser les fichiers candidats.
- Lire intégralement (pas d'extraits superficiels) les fonctions impliquées.
- Tracer le flux d'exécution : entrée utilisateur → code → sortie.
- Identifier la ou les lignes spécifiques susceptibles de causer le bug.
- Pour chaque candidat root cause :
  - chemin fichier `file.ts:LIGNE`
  - extrait du code concerné (3-10 lignes)
  - mécanisme exact qui produit le bug (causalité, pas corrélation)
- Si plusieurs hypothèses concurrentes : les lister toutes, ranger par probabilité avec justification.

**Interdit** : conclure sans avoir lu le code. Pas de root cause « à priori ».

### Phase 3 — Analyse adversariale
Objectif : essayer de **détruire** ta propre hypothèse. Si elle survit, elle est solide.

Pour chaque hypothèse de root cause de la phase 2, attaquer sous ces angles :

1. **Contre-exemple** : existe-t-il un chemin de code où le bug *ne se produirait pas* alors qu'il devrait selon mon hypothèse ? Si oui → hypothèse incomplète.
2. **Reproductibilité logique** : est-ce que je peux dérouler mentalement les steps du ticket et arriver au bug observé *uniquement* via cette cause ? Lister chaque étape avec son état.
3. **Edge cases ignorés** : conditions de course, état initial, valeurs limites, async, ordre des hooks, cycle de vie, cache, i18n, permissions.
4. **Causes alternatives** : qu'est-ce qui pourrait produire le *même symptôme* via un mécanisme différent ? Énumérer au moins 2 alternatives et expliquer pourquoi elles sont écartées (avec preuve code).
5. **Angles morts** : qu'est-ce que je n'ai *pas* regardé ? (tests, config, dépendances, code généré, migrations, env vars, feature flags). Aller voir avant de conclure.
6. **Historique git** : `git log -p -S "<terme>" -- <fichier>` ou `git blame` sur la ligne suspecte. Quelqu'un a-t-il déjà touché à ça ? Pourquoi ?

À la fin de cette phase, produire un **verdict de certitude** :
- `CERTAIN` (~100%) : root cause prouvée par lecture code + repro logique complète + alternatives écartées avec preuve.
- `HAUTE CONFIANCE` (~85%) : root cause très probable, 1-2 alternatives non strictement écartées. Lister ce qui manque pour passer à CERTAIN.
- `INCERTAIN` (<85%) : ne pas conclure. Lister ce qu'il faut investiguer en plus (fichiers à lire, tests à lancer, questions au reporter).

**Tu ne passes à la phase 4 que si verdict = `CERTAIN`.** Sinon, tu remontes à l'utilisateur pour arbitrage.

### Phase 4 — Plan de fix proposé
Uniquement si phase 3 = `CERTAIN`.

- Décrire le correctif minimal (KISS, YAGNI).
- Fichier(s) et ligne(s) à modifier.
- Avant / après en pseudo-code ou diff conceptuel.
- Risques de régression : que pourrait casser ce fix ?
- Tests à ajouter ou modifier pour verrouiller le comportement.
- **Ne pas implémenter.** Plan seulement.

## Format de sortie (conversationnel, pas de fichier)

```
## Ticket
<ID> — <titre>
Résumé : <3-5 lignes>

## Code impacté
- <file:line> — <mécanisme>
- ...

## Analyse adversariale
Hypothèse principale : <…>
Alternatives écartées :
  - <alt 1> — écartée car <preuve>
  - <alt 2> — écartée car <preuve>
Angles morts vérifiés : <liste>
Verdict : CERTAIN | HAUTE CONFIANCE | INCERTAIN
Justification : <…>

## Plan de fix  (uniquement si CERTAIN)
- Fichier : <…>
- Changement : <…>
- Risques : <…>
- Tests : <…>
```

## Règles dures
- Pas de fichier créé. Pas de commentaire posté sur Linear. Sortie chat uniquement.
- Pas d'implémentation. Analyse + plan seulement.
- Pas de flatterie, pas de hedging gratuit. Si tu n'es pas sûr, dis-le et explique ce qu'il manque.
- Si le ticket est inaccessible (MCP Linear down, ID invalide) : remonter immédiatement, ne pas inventer le contenu.
