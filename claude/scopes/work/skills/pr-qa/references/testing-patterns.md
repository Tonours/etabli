# Testing Patterns par Repo

## Frontend (ForestAdmin/forestadmin)

### Comment tester

**Environnement:** https://app.development.forestadmin.com

**Types de tests manuels:**
- Navigation et interactions UI
- Etats visuels (loading, error, empty, filled)
- Responsive/mobile si applicable
- Permissions et roles

**Points d'attention:**
- Verifier les toasts/notifications
- Verifier les transitions de route
- Tester avec differents roles utilisateur
- Verifier le comportement offline/reseau lent

### Zones critiques

| Zone | Impact | Comment tester |
|------|--------|----------------|
| **Inbox** | Gestion des taches | Assignation, statuts, filtres |
| **Workflow Editor** | Automatisation | Creation, edition, execution |
| **Dashboard** | Visualisation | Widgets, filtres, export |
| **Data** | CRUD operations | Creation, edition, suppression, bulk |
| **Permissions** | Securite | Roles, scopes, teams |

### Module Federation / MFEs

Le frontend utilise Webpack Module Federation. Ember host charge des React MFEs au runtime.
- Si la PR touche un MFE React: tester dans le contexte Ember host aussi
- Si la PR touche le host: verifier que les MFEs chargent correctement
- MFEs utilisent React 19.2.0, host React 18.3.1

### Edge cases frontend typiques

- Composant avec liste vide
- Composant avec beaucoup d'elements (pagination, virtualisation)
- Double-clic sur bouton de soumission
- Navigation pendant une action async
- Rafraichissement de page pendant une operation
- Plusieurs onglets ouverts
- MFE qui ne charge pas (Module Federation failure)
- GraphQL query/mutation qui echoue

## Backend (ForestAdmin/forestadmin-server)

### Comment tester

**Environnement:** https://api.development.forestadmin.com

**Outils:**
- Postman/Insomnia pour API REST
- GraphQL Playground pour GraphQL
- Logs serveur pour debug
- BullMQ dashboard pour jobs async (Redis)

**Points d'attention:**
- Codes HTTP corrects (200, 201, 400, 401, 403, 404, 409, 422, 500)
- Format des erreurs (structure JSON-API)
- Headers de reponse
- Transactions et rollback

### Zones critiques

| Zone | Impact | Comment tester |
|------|--------|----------------|
| **Authentication** | Securite | JWT, refresh, logout |
| **Authorization** | Permissions | Scopes, roles, teams |
| **Inbox** | Workflow | Assignation, statuts, concurrence |
| **Rendering** | Data access | Filtres, recherche, pagination |
| **Webhooks** | Integration | Delivery, retry, timeout |

### Edge cases backend typiques

- Requetes concurrentes sur meme ressource
- Payload invalide (types, valeurs limites)
- Utilisateur sans permission
- Ressource inexistante
- Transaction timeout
- Contraintes d'unicite
- Soft-deleted records
- Elasticsearch index desynchronise
- Job BullMQ qui echoue / retry
- GraphQL N+1 queries

## Agent (ForestAdmin/agent-nodejs)

### Comment tester

**Environnement:** Agent local ou staging

**Outils:**
- Tests unitaires Jest
- Agent de test avec datasource mock
- Forest Admin UI connectee a l'agent

**Points d'attention:**
- Compatibilite avec differentes datasources
- Performance avec gros volumes
- Gestion memoire
- Erreurs de connexion

### Zones critiques

| Zone | Impact | Comment tester |
|------|--------|----------------|
| **Datasource** | Connexion DB | CRUD, relations, filtres |
| **Customization** | Extensions | Actions, hooks, computed |
| **Authentication** | Securite | Token validation |
| **Permissions** | Acces | Scopes dynamiques |
| **MCP Server** | Integration IA | Tools, JSON-RPC, SSE |

### Edge cases agent typiques

- Datasource deconnectee
- Schema change pendant l'execution
- Gros volume de donnees
- Requetes complexes (nested relations)
- Actions custom avec erreurs
- Hooks qui echouent

## Zendesk (ForestAdmin/forest-for-zendesk)

### Comment tester

**Environnement:** App Zendesk (sidebar) connectee a un projet Forest Admin

**Outils:**
- App Zendesk en mode dev (`yarn dev`)
- Console navigateur pour debug
- vitest pour tests unitaires

**Points d'attention:**
- Tester dans le contexte Zendesk (sidebar, pas standalone)
- Verifier le flow OAuth (connexion/deconnexion)
- Verifier les appels MCP (JSON-RPC 2.0, SSE responses)
- Tester avec differents etats du ticket Zendesk

### Zones critiques

| Zone | Impact | Comment tester |
|------|--------|----------------|
| **OAuth** | Authentification | Login, refresh token, logout, expiration |
| **MCP Client** | Communication agent | CRUD, search, relations, SSE parsing |
| **Search/Browse** | Navigation donnees | Collections, filtres, pagination |
| **Record Detail** | Affichage donnees | Champs, relations, popovers |
| **Actions** | Execution actions | Formulaires, execution, erreurs |
| **AI Query** | Requetes IA | Proxy, prompts, parsing reponses |
| **Settings** | Configuration | URL MCP, parametres installation |

### Edge cases zendesk typiques

- Token OAuth expire pendant une operation
- Agent MCP non disponible / URL incorrecte
- Reponse SSE incomplete ou malformee
- `isError: true` dans la reponse MCP
- Collection sans permissions (pas de colonnes visibles)
- Ticket Zendesk sans donnees exploitables
- Changement de ticket pendant une operation async
- Plusieurs onglets Zendesk ouverts simultanement
- Caracteres speciaux dans les valeurs de champs
- Relations circulaires ou profondement imbriquees
- HTML non sanitise dans les donnees affichees (XSS)

## Patterns de test communs

### Concurrence

```
1. Preparer l'etat initial
2. Lancer N requetes simultanees (Promise.all)
3. Verifier: exactement 1 succes, N-1 erreurs attendues
4. Verifier l'etat final coherent
```

### Idempotence

```
1. Executer l'operation une fois
2. Noter le resultat
3. Re-executer la meme operation
4. Verifier: meme resultat OU erreur appropriee
```

### Permissions

```
Pour chaque role:
1. Tenter l'operation
2. Verifier: succes si autorise, 403 sinon
```

### Donnees limites

```
Tester avec:
- null/undefined
- string vide ""
- string tres long (10000+ chars)
- nombres negatifs
- dates invalides
- caracteres speciaux (unicode, emoji, injection)
```
