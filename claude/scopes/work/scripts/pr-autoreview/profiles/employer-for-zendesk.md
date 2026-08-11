# Profil de review — employer-for-zendesk (employer/employer-for-zendesk)

## Stack et commandes

- **Package manager** : yarn (implicite, `package.json:20`). Pas de champ `packageManager`, pas de `.nvmrc`.
- **Test** : **vitest** — `"test": "vitest"`, `"test:run": "vitest run"`, `"test:coverage": "vitest run --coverage"` (`package.json:16-18`), `vitest@^4.1.0` (`package.json:71`). Seul repo employer sur vitest, confirmé par le code.
- **Lint** : `eslint src --ext ts,tsx --report-unused-disable-directives` (`package.json:9`), config legacy `.eslintrc.cjs` (pas flat config), `eslint@^8.45.0`.
- **Typecheck** : `tsc --noEmit` (`package.json:15`), `strict: true`, `noUnusedLocals`, `noUnusedParameters`, `noFallthroughCasesInSwitch` (`tsconfig.json:14-17`).
- **Build** : `tsc && vite build` (`package.json:8`), Vite `^6.4.3`, **React `^18.3.0`** (`package.json:37`) — pas React 19.
- **Gate pre-submission** : `node scripts/pre-submission-checks.js && yarn typecheck && yarn lint && yarn test:run && yarn build` (`package.json:20`).
- **Zendesk tooling** : `zcli apps:server dist` (`package.json:7,14`), `zcli apps:validate dist` (`package.json:19`), `yarn package` = build + zip (`package.json:22`). Manifest : app ZAF `support:ticket_sidebar`, `frameworkVersion: 2.0`, un seul paramètre `employerAgentUrl` (`manifest.json:1-34`).
- `dist/` est buildé et zippé pour la marketplace Zendesk, pas déployé en continu.

## Architecture

Onion architecture stricte.

- **Entrée ZAF** : `src/main.tsx:14-28` — `ThemeProvider` (Garden) > `QueryProvider` > `ZAFProvider` > `AuthProvider` > `AppErrorBoundary` > `App`. `initMonitoring()` avant le render (`main.tsx:12`).
- **UI** (`components/`) : rendu pur, pas d'appel service direct. Dossiers `actions/`, `common/`, `layout/`, `records/`, `screens/`, `search/`.
- **Hooks** (`hooks/`) : orchestration React Query + services.
- **Services** (`services/`, `utils/`) : fonctions pures, zéro dépendance React. `employer-client.ts:200-229` = client MCP JSON-RPC bas niveau, POST `{baseUrl}/mcp`.
- **Deux bases API distinctes** : `employerApiService` → `VITE_employer_API_URL` (SaaS, OAuth/metadata/AI proxy) ; `employerService`/`employerClient` → agent URL des settings, `/mcp` (data ops, actions).
- **Auth** : PKCE S256, DCR sur le SaaS (`/oauth/register`), authorize/token sur l'agent (`oauth-service.ts:120-289`). Tokens en localStorage namespacé par agent URL (`scoped-storage.ts`), PKCE verifier/state en sessionStorage.

Frontières à surveiller : un appel service direct depuis un composant est une violation ; de la logique de fetch/parsing dans un hook aussi. Le typage strict de `ZendeskTicket` (`src/types/index.ts:1-21`, `requester` non optionnel) contre un cast non validé du SDK ZAF (`ZAFContext.tsx:99`) est une frontière fragile.

## Conventions vérifiées

- **TypeScript strict** (`tsconfig.json:14`), mais **`no-explicit-any` est en `warn`, pas `error`** (`.eslintrc.cjs:36`). Le `CLAUDE.md` du repo affirme « no `any` » — écart réel entre convention déclarée et règle appliquée. Le lint ne bloque pas.
- **`no-console` : `error`** (`.eslintrc.cjs:38`) — `console.log`/`console.warn` fait échouer le lint sauf `eslint-disable` explicite.
- **Unused vars/args** : error, échappement `^_` (`.eslintrc.cjs:32-35`).
- **Composants Garden obligatoires** : `@zendeskgarden/react-*` (`package.json:26-35`).
- **Sanitisation HTML** : `stripHtmlTags` isolé dans `src/utils/sanitize.ts:1-5`, `DOMPurify.sanitize(html, { ALLOWED_TAGS: [] })` — strip total, point d'entrée unique.
- **Pas de secret côté client** : `employer-client.ts:213-229` ne porte que le bearer OAuth utilisateur.
- **Tests** : vitest + jsdom + testing-library + MSW (`package.json:44-47,64-67`). ⚠️ La convention de colocation et de factories n'a **pas** été vérifiée sur du code de test réel — affirmée par le `CLAUDE.md` du repo seulement. Ne pas s'appuyer dessus pour juger une PR de test sans vérifier.

## Cas tricky

1. **Gating refresh/logout** (kb `zendesk-refresh-logout-gating`, verified) — un `catch` trop large détruisait le refresh token sur un blip réseau. Le logout n'est déclenché que si `isSessionRejected`, ce qui exige un **code d'erreur OAuth explicite**, pas juste un 401. Un 401 de proxy sans corps OAuth ne doit jamais déclencher `logout()`/`clearAll()`. Sources : `AuthContext.tsx:287-311,338-340`, `oauth-service.ts:64-85,267-275`, `oauth-session.ts:130-137`.
2. **Scoping des erreurs par ticket** (kb `zendesk-error-ticket-scoping`) — la sidebar est réutilisée entre tickets. `ticketEpochRef` incrémenté en `useLayoutEffect` (pas `useEffect`) ; une erreur n'est publiée que si l'epoch n'a pas bougé (`employerContext.tsx:103-109,166-206`). Purge du cache d'analyse IA **par préfixe**, jamais `exact: true` : la clé réelle a un 4e élément `aiScopeKey` absent du helper (`useAIQuery.ts:14-40`, `DataTab.tsx:119-154`).
3. **Header de version d'app** (kb `zendesk-app-version-header`) — un header custom passe côté MCP (`origin: '*'`) mais casse silencieusement côté BFF tant que `ALLOWED_HEADERS` n'est pas mis à jour dans `agent-nodejs` : preflight CORS bloqué avant l'envoi.
4. **Cache de leçons d'opérateur** (kb `zendesk-operator-lesson-cache`, ADR accepted) — les trois modes `strict|exact|fuzzy` doivent rester disjoints dans la clé (`collection:field:mode`). Revenir à 2 buckets referait fuiter une leçon `Contains` apprise en fuzzy vers un appel `exact: true`. `employer-service.ts:55-67,116,205-220`.
5. **Heuristique `externalId`** (kb `zendesk-external-user-id-heuristic`, `zendesk-external-id-role`) — détection par **tokens**, pas `endsWith` : trois contraintes cumulatives + denylist `super|power|admin|multi`. Toute modif de `isExternalUserIdFieldName` (`schema-profiles.ts:27-45`) doit re-tester le faux positif `superuser`.
6. **Mapping contextField déclaratif** (kb `zendesk-context-field-mapping`, ADR accepted) — le `manifest.json` actuel ne porte qu'un paramètre (`manifest.json:25-33`). Ne pas assumer la présence du mécanisme `contextFields` ; vérifier si la PR l'introduit ou travaille sans lui.
7. ⚠️ **Note KB manquante** : `zendesk-qa-environment` est indexée (`kb/_index.md:87`) mais **introuvable** sur disque. Ne pas s'appuyer sur son contenu supposé.
8. ⚠️ **Note KB stale** : `zendesk-requester-id-matching` est `status: stale` — décrit l'état *avant* le fix PRD-834. Ne pas la citer comme décrivant le comportement actuel.

## Ce qu'on NE commente PAS

- **`fail-open` sur 403 dans `probeAccessibleActions`** (`action-permissions.ts:20-36`) : choix optimiste assumé, sauf si la PR touche ce fichier.
- **Fallback prod dur sur `VITE_employer_API_URL`/`VITE_employer_APP_URL`** (`oauth-service.ts:105,280`) : piège de config dev documenté, pas un défaut de code.
- **`X-Request-Id` déclaré mais jamais lu côté BFF** : problème dans `agent-nodejs`, hors scope ici.
- **Contraintes plateforme ZAF** : `dist/` généré (ne pas review), `manifest.json` en JSON strict imposé par `zcli` (types de paramètre limités), `client.request()` pour tout appel sortant (contournement CSP obligatoire, pas un anti-pattern).
- **`transport === null` dans `monitoring.ts`** : code quasi-mort documenté.
- **`popupRef.current.close()` dans un `try/catch` vide** (`AuthContext.tsx:308-313`) : throw silencieux cross-browser volontaire, commenté `/* browser-dependent */`.

## Signaux de review prioritaires

L'environnement ZAF réel (iframe, CSP, proxy Zendesk, sidebar réutilisée) diverge fortement des tests jsdom/MSW.

1. **Refresh OAuth / détection de session rejetée** — risque concret : destruction du refresh token sur faux positif, forçant un popup complet chez le client. Les tests ne simulent pas l'iframe qui remonte à chaque navigation de ticket. Vérifier que `isSessionRejected` reste le seul discriminant et exige un `oauthError` non vide.
2. **State partagé sans scoping par ticket** — la sidebar est une instance unique réutilisée ; un état non scopé fuit d'un ticket à l'autre en prod, invisible dans un test qui ne monte qu'un ticket. Tout nouvel état a-t-il besoin d'un epoch ou d'une clé scopée par `ticket.id` ?
3. **Matching déterministe** (`schema-profiles.ts`, `deterministic-matcher.ts`, `record-search.ts`) — compromis faux positif/négatif documenté, préférence explicite pour le faux négatif : un faux positif expose le record d'un autre client à un agent support. Le vrai risque est la collision (id générique, `external_id` sans namespace) chez un client au schéma divergent.
4. **Nouveau header ou appel réseau sortant** — CSP de l'iframe + CORS fermé côté BFF (`ALLOWED_HEADERS` statique). Un header ajouté côté client sans changement backend casse en prod ; MSW ne simule pas de preflight réel.
5. **`any` passe le lint** (`warn` seulement) alors que le `CLAUDE.md` du repo l'interdit — vigilance manuelle, le tooling ne bloque pas.
