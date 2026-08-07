---
name: pr-qa
description: Analyse QA d'une PR GitHub pour comprendre son impact et generer un plan de test complet. Execute en 3 phases - comprehension, analyse d'impact, generation du plan de test (happy path + edge cases). Utiliser quand on demande comment tester une PR, analyser l'impact d'une PR, ou /pr-qa <PR_ID>.
---

# PR QA Skill

Procedure Claude derivee du contrat partage `workflow/skills/pr-qa.md`. Le
contrat fait foi entre runtimes (Pi le lit aussi) ; ce fichier est
l'implementation Claude et peut aller plus loin, jamais a rebours.

Analyse QA d'une PR GitHub en 3 phases pour generer un plan de test complet.

## Repos Supportes

| Alias | Repository | Stack |
|-------|------------|-------|
| frontend | ForestAdmin/forestadmin | Ember.js 4.12 Octane, TypeScript 5.9, SCSS, Module Federation (React MFEs) |
| backend | ForestAdmin/forestadmin-server | Node.js 22.12.0, TypeScript, Express, Sequelize, Elasticsearch, BullMQ |
| agent | ForestAdmin/agent-nodejs | Node.js, TypeScript, Monorepo |
| zendesk | ForestAdmin/forest-for-zendesk | React 18, TypeScript, Vite, Zendesk Garden |

## Usage

```
/pr-qa <PR_ID>                    # Demande quel repo
/pr-qa frontend 123               # PR #123 sur frontend
/pr-qa backend 456                # PR #456 sur backend
/pr-qa agent 789                  # PR #789 sur agent
/pr-qa zendesk 42                 # PR #42 sur zendesk
```

Ou en langage naturel: "comment tester la PR #123", "quel est l'impact de la PR 456"

## Phase 1: Comprehension

### Selection du repo

Si seulement un ID est fourni, utiliser AskUserQuestion:

```
Question: "Sur quel repository se trouve cette PR ?"
Options:
- "frontend (ForestAdmin/forestadmin)"
- "backend (ForestAdmin/forestadmin-server)"
- "agent (ForestAdmin/agent-nodejs)"
- "zendesk (ForestAdmin/forest-for-zendesk)"
```

### Recuperer les donnees

```bash
# Metadata
gh pr view <PR_ID> --repo <OWNER/REPO> --json title,body,author,files,additions,deletions,baseRefName,headRefName,number,url,commits,labels

# Diff complet
gh pr diff <PR_ID> --repo <OWNER/REPO>

# Commentaires de review (contexte supplementaire)
gh pr view <PR_ID> --repo <OWNER/REPO> --json comments,reviews
```

### Resume pour l'utilisateur

Presenter:
- Titre et description de la PR
- Type de changement (fix, feat, refactor, perf, etc.)
- Fichiers modifies avec stats
- **Resume fonctionnel**: Qu'est-ce que ca change pour l'utilisateur final?

## Phase 2: Analyse d'Impact

**Reference:** Consulter `references/testing-patterns.md` pour les zones critiques et patterns de test par repo.

### Identifier les zones impactees

**Questions a se poser:**
1. Quelles fonctionnalites sont directement modifiees?
2. Quelles fonctionnalites dependent du code modifie?
3. Y a-t-il des effets de bord potentiels?
4. Quels utilisateurs/roles sont concernes?

### Categoriser l'impact

| Niveau | Description | Exemple |
|--------|-------------|---------|
| **Direct** | Fonctionnalite modifiee | Bouton d'assignation inbox |
| **Indirect** | Depend du code modifie | Workflow utilisant l'inbox |
| **Lateral** | Meme domaine fonctionnel | Autres operations sur l'inbox |
| **Systeme** | Infrastructure/perf/securite | Gestion des erreurs, transactions |

### Analyser par type de PR

**Bug fix:**
- Quel etait le comportement avant?
- Quel est le comportement attendu apres?
- Dans quelles conditions le bug se manifestait?
- La correction peut-elle introduire des regressions?

**Feature:**
- Nouvelle fonctionnalite ou extension?
- Quels sont les pre-requis?
- Quelles sont les permissions necessaires?
- Integration avec l'existant?

**Refactoring:**
- Le comportement externe doit etre identique
- Focus sur les regressions potentielles
- Verifier les performances

**Performance:**
- Mesurer avant/apres
- Tester sous charge si applicable
- Verifier qu'aucune fonctionnalite n'est degradee

## Phase 3: Plan de Test

### Structure du plan

Generer un plan de test structure avec:

```markdown
## Plan de Test - PR #<ID>

### Resume
- **Fonctionnalite:** [description]
- **Type:** [fix/feat/refactor/perf]
- **Risque:** [faible/moyen/eleve]
- **Temps estime:** [X min]

### Pre-requis
- [ ] Environnement configure
- [ ] Donnees de test disponibles
- [ ] Permissions necessaires

### Happy Path
[Scenarios ou tout fonctionne normalement]

### Edge Cases
[Cas limites et situations exceptionnelles]

### Tests de Non-Regression
[Verifier que l'existant fonctionne toujours]
```

### Happy Path

Pour chaque scenario nominal:

```markdown
#### Scenario: [Nom descriptif]
**Contexte:** [Pre-conditions]
**Actions:**
1. [Etape 1]
2. [Etape 2]
3. ...
**Resultat attendu:** [Ce qui doit se passer]
```

### Edge Cases

Identifier systematiquement:

| Categorie | Questions |
|-----------|-----------|
| **Donnees** | Valeurs nulles? Vides? Tres grandes? Caracteres speciaux? |
| **Concurrence** | Plusieurs utilisateurs? Actions simultanees? Race conditions? |
| **Permissions** | Utilisateur sans droits? Role different? |
| **Etat** | Objet deja supprime? Deja traite? En cours de modification? |
| **Reseau** | Timeout? Deconnexion? Retry? |
| **Limites** | Pagination? Quotas? Limites de taille? |

Pour chaque edge case:

```markdown
#### Edge Case: [Nom]
**Condition:** [Comment reproduire]
**Comportement attendu:** [Message d'erreur, fallback, etc.]
```

### Tests de Non-Regression

Identifier les fonctionnalites adjacentes a verifier:
- Fonctionnalites utilisant le meme service/composant
- Workflows passant par le code modifie
- APIs consommant les memes donnees

## Exemple de Sortie

```markdown
## Plan de Test - PR #8023

### Resume
- **Fonctionnalite:** Gestion des erreurs d'assignation inbox en concurrence
- **Type:** fix
- **Risque:** moyen (modification du flow d'erreur)
- **Temps estime:** 15 min

### Pre-requis
- [ ] Acces a une inbox avec des records
- [ ] Deux sessions utilisateur (ou outil de requetes concurrentes)

### Happy Path

#### Scenario: Assignation simple d'un record
**Contexte:** Record non assigne, utilisateur avec permissions
**Actions:**
1. Ouvrir l'inbox
2. Selectionner un record
3. Cliquer sur "Assigner"
**Resultat attendu:** Record assigne, statut "Doing"

### Edge Cases

#### Edge Case: Assignation concurrente du meme record
**Condition:** Deux utilisateurs assignent le meme record simultanement
**Comportement attendu:** Un succes (200), un echec avec erreur "Already assigned" (409)

#### Edge Case: Re-assignation d'un record deja assigne
**Condition:** Tenter d'assigner un record deja assigne a quelqu'un
**Comportement attendu:** Erreur 409 "Already assigned"

### Tests de Non-Regression
- [ ] Assignation normale fonctionne toujours
- [ ] Desassignation fonctionne
- [ ] Changement de statut (doing -> done) fonctionne
- [ ] Activity log enregistre correctement les actions
```

## Regles de Sortie

1. **Actionable**: Chaque test doit etre executable sans ambiguite
2. **Priorise**: Happy path d'abord, puis edge cases par risque
3. **Mesurable**: Resultat attendu clair et verifiable
4. **Complet**: Couvrir direct + indirect + non-regression
5. **Realiste**: Temps estime coherent avec la complexite
