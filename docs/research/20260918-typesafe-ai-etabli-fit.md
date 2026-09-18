# TypeSafe AI dans les workflows Etabli

Date de recherche : 2026-09-18. Statut : `verified` pour les capacités documentées et les surfaces locales inspectées ; `inference` pour l'architecture proposée ; `not verified` pour la qualité, la calibration, le coût et la latence sur des tâches Etabli. Aucun appel API, benchmark réel, secret ou envoi de données projet n'a été effectué.

## Décision

**Adopter TypeSafe comme candidat à un pilote shadow de jugement sémantique, sans en faire une dépendance du workflow ni une autorité de validation.**

TypeSafe est adapté aux décisions fermées et rapides qu'un code déterministe ne peut pas prendre seul : choisir une route parmi un ensemble connu, estimer si un écart est matériel, scorer une sévérité ou décider si un cas doit être escaladé. Il n'est pas adapté à la génération de `PLAN.md`, à l'implémentation, à la synthèse d'une recherche, à la preuve de correction ou aux gates qui peuvent être calculés exactement.

Le pilote doit rester optionnel, réversible et sans effet sur les décisions. Une promotion éventuelle exige une comparaison sur le corpus Etabli, avec mesures de calibration et de sécurité par type de tâche. Les données envoyées doivent être minimisées et nettoyées ; le mode zero-data-retention annoncé est une offre entreprise, pas le comportement par défaut démontré ici.

## Ce que TypeSafe fournit réellement

La [documentation d'introduction](https://docs.typesafe.ai/introduction) présente Jev comme un modèle « System One » : l'application envoie un état et des questions typées, puis reçoit des réponses structurées. Les trois primitives sont :

| Primitive | Usage | Sortie utile à Etabli |
| --- | --- | --- |
| `Choice` | choisir une option fermée | choix, distribution des probabilités, confiance |
| `Score` | positionner un cas sur des niveaux ordonnés décrits | score, distribution, confiance |
| `Noul` | estimer si une condition est vraie | probabilité de `yes` |

Les questions d'un même appel voient le même état et sont évaluées indépendamment. La [méthode recommandée](https://docs.typesafe.ai/concepts/how-to-build-with-system-one) consiste à décomposer un jugement complexe en questions étroites, puis à recomposer la décision dans le code. Le [fan-out spéculatif](https://docs.typesafe.ai/patterns/fan-out) permet de poser les questions indépendantes en parallèle et de n'utiliser que celles de la branche choisie.

La [confiance](https://docs.typesafe.ai/confidence) est dérivée de la concentration de la distribution de probabilités pour `Choice` et `Score`. Elle ne prouve ni la justesse de la réponse ni celle du workflow. Les seuils doivent dépendre du risque et être testés sur les données du domaine. `Noul` expose directement une probabilité, sans propriété de confiance séparée.

Le [SDK JavaScript officiel](https://github.com/typesafe-ai/typesafe-sdk-js) fournit des types inférés pour les réponses, requiert Node 20 ou plus et utilise `TYPESAFE_API_KEY`. Il s'agit d'un service distant. Le dépôt officiel propose aussi un [adaptateur System One](https://github.com/typesafe-ai/system-one-adapter-python) permettant de comparer la même interface à des modèles OpenAI ou Anthropic, avec usages, latence et retries observables.

## Correspondance avec les surfaces Etabli

| Surface locale | Jugement TypeSafe possible | Primitive | Autorité conservée dans Etabli |
| --- | --- | --- | --- |
| routeur de workflow | choisir `answer`, `verify`, `plan-loop`, `plan-implement` ou `implement` lorsque les règles sont ambiguës | `Choice` | règles explicites, garde READY et politique de mutation |
| exploration du plan | estimer si un trou entre demande, spec et code est matériel ; scorer sa sévérité | `Noul` + `Score` | table Requirement Trace, précédence des sources et décision écrite |
| revue | classer un finding et estimer s'il justifie blocage, correction ou note | `Choice` + `Score` | reviewer, tests et adversaire sur le patch gelé |
| self-improvement | scorer indépendamment qualité, fiabilité, coût potentiel et risque d'un candidat | `Score` en parallèle | manifestes gelés, corpus, seuils, non-régression et test final |
| suggestion de skill | choisir un skill connu puis vérifier si aucun n'est pertinent | `Choice` + `Noul` | catalogue installé, règles de déclenchement et invocation runtime |
| mémoire | estimer la pertinence de candidats déjà récupérés | `Score` | sources Markdown, statut, fraîcheur et citations Obvault |

Les meilleurs premiers candidats sont le routage ambigu et la suggestion de skill. Ils ont un espace de réponses fermé, un fallback sûr et des labels que l'on peut reconstruire depuis les décisions passées. La classification des findings peut suivre, mais elle est plus sensible au contexte et à la calibration de sévérité.

## Ce que TypeSafe ne doit pas remplacer

- `scripts/lib/plan-check-freeze.mjs`, les validateurs d'événements, les checks Git et les tests : le résultat est calculable exactement.
- La lecture de la demande, de la spec, des ADR, des tickets et du code : le modèle ne crée pas les preuves manquantes.
- La production du plan et du code : Jev renvoie des décisions typées, pas du texte ou un patch.
- Les revues sur le patch gelé : une sortie conforme au schéma ne prouve pas que le changement est correct.
- Les autorisations de mutation, publication, déploiement ou traitement de secrets.
- L'évaluateur final d'une boucle d'auto-amélioration : le candidat ne doit pas pouvoir redéfinir son succès.

Les [évaluations publiées par TypeSafe](https://evals.typesafe.ai/) comparent des modèles dans des workflows supposés corrects. Le billet de lancement précise que les références viennent de grands modèles externes, que les auteurs des workflows appartiennent à l'équipe capacités et que certaines accélérations publiées sont probablement dans le haut de la plage réelle. La garantie de schéma justifie une sortie bien formée ; elle ne fournit pas une preuve empirique de vérité. Ces résultats motivent un pilote, pas une promotion directe.

## Seam d'intégration proposé

Introduire seulement après un benchmark concluant une interface provider-neutral, par exemple `JudgmentProvider`, hors des gates existants :

```ts
type JudgmentRequest = {
  state: unknown
  questions: Record<string, ChoiceQuestion | ScoreQuestion | NoulQuestion>
}

type JudgmentReceipt = {
  provider: string
  model: string
  modelVersion: string | null
  requestSchemaVersion: number
  answers: Record<string, unknown>
  latencyMs: number
  inputTokens: number | null
  costUsd: number | null
  stateFingerprint: string
  questionFingerprint: string
}
```

Le provider reçoit un état minimal et nettoyé. Le receipt conserve les probabilités brutes, la version, les empreintes des questions et du corpus, la latence, le coût et l'erreur éventuelle. Il ne contient pas la spec ou le code complet. Un timeout, une erreur réseau, une version inconnue ou une confiance insuffisante produit `abstain` et rend la main à la logique actuelle.

Le résultat shadow peut être ajouté à une copie d'événement dédiée ou à un artefact d'évaluation. Il ne doit pas modifier `route_decided`, `review_completed`, `adversary_completed` ou une décision d'adoption pendant le pilote.

## Protocole de pilote

### Phase 0 — corpus et baseline

1. Extraire des événements historiques nettoyés pour deux tâches : route ambiguë et suggestion de skill.
2. Figer les exemples, labels, exclusions, split `held_in` / `held_out` / `safety`, version du routeur et évaluateur.
3. Mesurer la logique actuelle et, si utile, l'adaptateur System One sur le même corpus.
4. Conserver séparément les échecs de données, de modèle, de code et de service.

### Phase 1 — shadow distant

1. Envoyer uniquement les champs nécessaires, sans secret, diff complet, contenu privé ou chemin personnel.
2. Enregistrer réponse, distribution, confiance, abstention, latence, tokens, coût, modèle et fingerprints.
3. Interdire tout effet sur la route, la revue ou l'exécution.
4. Rejouer les cas après chaque changement de modèle, question, critères ou composition.

### Phase 2 — advisory

Afficher une suggestion seulement si les seuils gelés sont atteints. Une confiance moyenne demande confirmation ou fallback ; une confiance faible s'abstient. Les seuils sont distincts pour lecture seule, création de plan, mutation locale et action externe.

### Phase 3 — automatisation étroite

Automatiser au plus une décision réversible à faible impact, avec circuit breaker et fallback déterministe. Toute extension nécessite sa propre population, ses seuils et une nouvelle validation.

## Mesures et gate de promotion

| Axe | Mesure minimale |
| --- | --- |
| décision | exactitude par tâche et matrice de confusion |
| calibration | Brier score ou log loss ; ECE avec bins et effectifs publiés |
| escalade | couverture automatique, taux d'erreur sous seuil, faux `act` à haute confiance |
| sécurité | aucune régression par cas sur le split safety |
| stabilité | répétitions et comparaison par version de modèle/question |
| exploitation | p50/p95 de latence, erreurs, retries, disponibilité |
| coût | coût total et par décision utile, avec population identique |

Le gate doit comparer les mêmes tâches et fingerprints, exiger la non-régression par cas, puis réexécuter la combinaison finale des changements. Une baisse de tokens d'un appel isolé n'est pas un gain de productivité du workflow. La promotion reste `blocked` tant que les données locales ne démontrent pas une amélioration et une calibration suffisantes pour l'action visée.

## Risques et inconnues

- **Maturité :** Jev est en early access au 18 septembre 2026 ; l'API et les modèles peuvent évoluer rapidement.
- **Données :** la [page légale](https://docs.typesafe.ai/legal) annonce l'absence d'entraînement sur les données utilisateur et un ZDR entreprise. La rétention par défaut, les sous-traitants et les garanties contractuelles doivent être vérifiés avant un pilote contenant des données internes.
- **Verrou fournisseur :** conserver une interface neutre, des fixtures et un fallback local évite de lier les contrats Etabli au SDK.
- **Calibration transférée :** une probabilité utile sur leurs cookbooks peut être mal calibrée sur nos routes ou severities.
- **Dérive :** modèle, questions, critères, code de composition et population sont tous des composants versionnés de l'évaluateur.
- **Contexte incomplet :** une sortie très confiante peut rester fausse si l'état omet la spec, une décision ou un fait runtime.
- **Confusion type/vérité :** le schéma est garanti ; la correction sémantique doit rester mesurée.

## Verdict opérationnel

`WATCHLIST / PILOT CANDIDATE`. Le bénéfice plausible est un routage sémantique rapide, probabiliste et observable sur les cas que les règles ne tranchent pas. Le coût d'intégration reste raisonnable si Etabli commence par un harness de replay shadow sans dépendance de production. Aucune intégration runtime ne doit être fusionnée avant le corpus gelé, le contrôle des données et un benchmark comparatif.
