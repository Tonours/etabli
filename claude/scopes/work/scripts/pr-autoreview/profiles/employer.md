# Profil de review — employer (employer/employer, frontend)

## Stack et commandes

- **yarn 1.22.19** (`package.json:39`), Node **22.12.0** (`.nvmrc:1`, `package.json:91`).
- **Ember** `ember-source: ~4.12.0`, édition **octane** (`package.json:238,94`).
- **React 18 côté host** (`package.json:292-293`), **React 19 côté MFE** `user-settings-mfe` (`apps/user-settings-mfe/package.json:29-30`). Coexistence délibérée via `nohoist` (`package.json:19-20`).
- **Tests host** : `EMBER_ENV=test ember exam` (`package.json:72`), filtrage `yarn ember exam --filter="..."`, coverage `yarn test:coverage` (`package.json:74`). QUnit + mirage + sinon.
- **Tests MFE** : `vitest run` (`apps/user-settings-mfe/package.json:16`) + Testing Library + msw (`:44-56`). Pas de Jest/QUnit dans ce workspace.
- **Lint host** : `yarn lint` agrège `lint:css` (stylelint sur `app/legacy/pods`, `app/features`, `app/shared`), `lint:hbs` (ember-template-lint), `lint:js` (`package.json:51-63`).
- **Lint MFE** : `eslint src --max-warnings 0` (`apps/user-settings-mfe/package.json:12`) — zéro warning toléré, plus strict que le host.
- **Typecheck** : `tsc --noEmit` avec heap étendu (`package.json:87`), multi-workspace `yarn typecheck:all` (`package.json:88`).
- MFE et packages pilotés par **Nx** : `nx start|build|typecheck|test|lint <projet>` (`package.json:60-79`).

## Architecture

- **Resolver custom à 5 niveaux**, ordre vérifié dans `app/resolver.ts:9-16` : `data → shared → features → routes → legacy`.
- 39 dossiers sous `app/features/` (`inbox`, `workflow-editor`, `workflow-visualizer`, `mcp-server`, `role`, `authentication`…).
- **Le legacy vit sous `app/legacy/pods/`** — pas `app/pods/` (ce chemin n'existe pas). `app/legacy` contient aussi `services/`, `mixins/`, `abstract-*`.
- MFE React sous `apps/`, packages partagés sous `packages/*` (`package.json:12-14`).
- ⚠️ Le détail des frontières (shared ne peut pas injecter de service, feature service seul mutateur d'état…) vient des skills, **non re-vérifié** sur une feature réelle au-delà du resolver et du lint. À traiter comme inféré.

## Conventions vérifiées

- **`employer-custom/dependency-rules`** en erreur (`eslint.config.mjs:97`), implémentation `eslint-custom-rules/dependency-rules.js:26-56` : interdit d'importer un service UI (`business/notification`, `services/toastr`, `services/ui/*`) depuis un `internal-business` ; interdit d'importer un `internal-business`/`internal-feature` hors du dossier `services` de sa feature.
- **`employer-custom/class-naming-based-on-path`** en erreur (`eslint.config.mjs:315-345`) : `components/[path]/component.ts` → suffixe `Component`, `services/internal-business/[name].ts` → `InternalBusinessService`, `services/feature.ts` → `FeatureService`, `app/services/business/[name]` → `BusinessService`.
  - ⚠️ **Écart réel** : les regex legacy ciblent `app/pods/...`, alors que le legacy vit sous `app/legacy/pods/...`. **La règle ne matche jamais un fichier legacy** — le nommage n'y est pas appliqué malgré la config apparente.
- **Imports absolus `client/...` imposés**, `allowSameFolder: false` (`eslint.config.mjs:100-107`).
- **`no-console`** autorise `debug|info|warn|error`, bloque `console.log` nu (`eslint.config.mjs:23-28`).
- **`prop-types` nu interdit**, passer par `client/utils/prop-types-utils` (`eslint.config.mjs:79-83`). **`inject` de `@ember/service` interdit** au profit de `service` (`:88-93`).
- **Template-lint** (`.template-lintrc.js`) : `no-action` et `no-action-modifiers` à `true` (`:32-33`), `no-implicit-this` avec allowlist nommée (`:46-60`), `template-length` max 250 lignes (`:79-82`). `no-route-action` en **`warn`** avec commentaire `// To clean up` (`:87`) — non bloquant.
- **Sélecteurs de test `data-test-*`** — inféré depuis les skills, pas depuis un test réel lu.
- ⚠️ Fichiers de test disproportionnés observés : `tests/features/inbox/services/feature-test.ts` **125 Ko**, `tests/features/inbox/components/creation-modal/component-test.ts` 39,8 Ko.

## Cas tricky

1. **Resolver à 5 niveaux** (`app/resolver.ts:9-16`) — un même nom peut se résoudre dans `data`, `shared`, `features`, `routes` ou `legacy`. Avant d'affirmer « quel fichier est utilisé », vérifier le pattern du type concerné (`app/resolver.ts:30-140`), pas un layout Ember classique.
2. **`class-naming-based-on-path` ne matche pas le legacy réel** — ne pas bloquer une PR legacy sur un nommage de classe qui n'est pas lint-enforced.
3. **Double instance React 18/19 en Module Federation** — isolation par `nohoist` (`package.json:19-20`). Un dédoublonnage ou hoist involontaire casse tout. (kb `mfe-dual-react-nohoist`, cité depuis `_index.md:50`, non relu en détail)
4. **Notes KB MFE à consulter avant de juger un changement** (index `~/work/brain/kb/_index.md:47-54`) : routing MFE avec `createBrowserRouter`+`basename` → page blanche (fix `memoryRouter`) ; sérialisation des props Ember→React sans cache ; isolation CSS build-time sans shadow DOM ; `theme.css` v4 fait foi sur les tokens Tailwind ; réutilisation d'instance de router v6 fuitant du state entre routes.
5. **`dependency-rules` casse silencieusement** si le chemin d'import ne matche pas exactement `/internal-business/` ou `/internal-feature/` (`eslint-custom-rules/dependency-rules.js:38-56`) — un renommage de dossier peut désactiver la règle sans erreur. À vérifier manuellement sur tout déplacement de service.

## Ce qu'on NE commente PAS

- **Nommage de classe non conforme sous `app/legacy/pods/...`** — la règle ne matche pas ce chemin, ce n'est ni une violation détectable ni un signal réel.
- **`no-route-action` et `require-presentational-children`** en `warn` avec `// To clean up` (`.template-lintrc.js:87-88`) — legacy accepté, ne pas exiger leur résolution dans une PR qui n'y touche pas.
- **Divergence de stack host (QUnit/mirage/sinon) vs MFE (Vitest/Testing Library/msw)** — délibérée, pas un défaut à uniformiser.
- ⚠️ Pas assez d'éléments vérifiés pour lister les zones générées ou les patterns Ember « datés mais corrects ». Ne pas remplir cette catégorie de généralités non sourcées.

## Signaux de review prioritaires

1. **Violation des frontières de couches contournée par un renommage/déplacement** qui échappe aux regex de `dependency-rules` (`eslint-custom-rules/dependency-rules.js:26-56`) — passe le lint, donc passe la CI, mais casse l'architecture en silence.
2. **Changements Module Federation / chargement MFE** (`apps/*`, host `app/components/micro-frontend/*`) sans respecter l'isolation React 18/19 — double instance React, hook call invalide : invisible en test unitaire, casse en prod.
3. **Modification de `app/resolver.ts` ou collision de nom entre `legacy` et un des 4 niveaux modernes** — silencieux à la compilation, visible seulement à l'exécution via le mauvais fichier résolu.
4. **Ajout dans `services/internal-business|internal-feature` absent du mapping `class-naming-based-on-path`** (`eslint.config.mjs:315-345` — `internal-feature` n'y est pas) : le lint ne l'attrape pas, vérification manuelle du nommage.
5. **Ajout dans un fichier de test déjà disproportionné** (125 Ko observé) — passe la CI mais dilue la couverture réelle. Vérifier que le test ajouté est ciblé, pas accolé à un fourre-tout.
6. **PR MFE** : `--max-warnings 0` (`apps/user-settings-mfe/package.json:12`) — un warning local non résolu bloque le lint CI de ce workspace, contrairement au host.

## Skills à mobiliser

| Zone touchée | Skill |
|---|---|
| Composant Ember (`.hbs`, component `.ts`, SCSS) | `ember-employer-components` |
| Route / controller Ember | `ember-employer-routes` |
| Service ou state (feature/shared/internal-business/internal-feature) | `ember-employer-services-state` |
| Modèle / adapter / serializer / GraphQL | `ember-employer-data` |
| Test QUnit / mirage / sinon | `ember-employer-testing` |
| Lint, typecheck, nommage de classe, SCSS | `ember-employer-lint-style` |
| `apps/*` ou `packages/*` (React 19, Module Federation) | `ember-employer-react-mfe` |
| Déplacement `app/legacy` → structure moderne | `ember-employer-migration` |
| `workflow-visualizer` | `ember-employer-workflow-visualizer` |
| Emplacement architectural ambigu (feature vs shared vs legacy) | `ember-employer-architecture` |
