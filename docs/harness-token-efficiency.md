# Économie de contexte des harness

État du 4 septembre 2026 : **verified** pour les surfaces de contexte ci-dessous.
Les tokens facturés, le coût total par tâche et la qualité du routage des modèles
restent **not verified**. Les fournisseurs factices des probes servent à observer
les requêtes natives ; leurs compteurs de tokens ne sont pas de la télémétrie.

## Résultats mesurés

| Surface et unité | Avant | Intermédiaire | Après | Variation |
| --- | ---: | ---: | ---: | ---: |
| Claude, index de descriptions en caractères | 6141 | 5250 | 4290 | -30,14 % |
| Pi, bloc de skills projeté en caractères | 8635 | 6838 | 6578 | -23,82 % |
| Pi, descriptions + schémas des outils actifs en caractères | 65101 | — | 31353 | -51,84 % |
| Codex CLI, catalogue rendu en octets UTF-8 | 19164 | — | 18691 | -2,47 % |

Ces populations sont distinctes : ne pas additionner leurs pourcentages.
Claude garde les mêmes **24 skills visibles et 84 réglages**. Le probe Codex
conserve **81 noms dans le même ordre**, mais exclut au moins **22 skills de
plugins configurés** que ce CLI avec fournisseur factice ne charge pas.
La ligne Pi skills conserve la convention du contrôle existant : soustraction
des entrées pstack lorsque son réglage les masque. C'est une projection, pas
une capture fournisseur finale ni un comptage de tokens.

Commandes de mesure figées : `scripts/claude-skill-load-check`,
`scripts/pi-skill-load-check` et probes natives locales conservées sous
`.workflow/token-economy/{pi-tools-probe,codex-probe}/`. Budget initial de quatre
candidats, étendu à cinq après découverte du coût des schémas Pi, dans la même
limite de 120 minutes. Les trois lignes de progression Claude et Pi proviennent
de fichiers `*-baseline.log`, `*-intermediate.log` et `*-final.log`.

## Fonctionnement retenu

**Pi charge les outils de workflow à la demande.**
`pi/extensions/workflow-tools.ts` conserve les outils courants et expose
`load_workflow_tools` : `tasks` active les sept outils Task, `delegation` active
les outils de workers disponibles. Le loader ajoute des outils déjà enregistrés,
sans les exécuter. Les contrôles de permission et de sortie restent ceux du
runtime et des extensions existantes.

Le registre réel passe de **30 à 22 outils au démarrage**. Les définitions des
**20 outils hors cible sont identiques**, hashes comparés. Neuf outils sont
effectivement différés : `subagent_supervisor` est enregistré après notre hook
par pi-subagents et reste disponible. Le loader respecte cette activation
tardive au lieu de modifier le choix d'une autre extension.

Le probe natif du registre installé observe **22 → 29 → 31 outils** après les
appels `tasks`, puis `delegation`. Les deux seuls appels d'outil exécutent le loader ;
aucun worker ni outil Task n'est lancé. Une fixture isolée confirme aussi
**6 → 13 → 16** outils sur trois requêtes. Les nouveaux schémas sont présents
avant la requête suivante, conformément au mécanisme Dynamic Tool Loading
documenté dans le SDK Pi installé.

Chaque événement `session_start` recalcule les outils éligibles depuis les outils
actifs et enregistrés à cet instant. Aucun état du profil n'est persisté. Un
groupe déjà actif ne provoque pas de nouvelle mutation ; un groupe indisponible
retourne un message explicite. Les politiques CLI explicites (`--tools`,
`--exclude-tools`, `--no-tools`, `--no-builtin-tools` et leurs formes courtes)
contournent entièrement le profil. Retour immédiat au chargement complet :

```bash
ETABLI_EAGER_TOOLS=1 pi
```

**Pi garde la suite Adonis visible** et masque ses cinq spécialistes dans
`pi/agent/settings.json`. Leurs fichiers restent consultables depuis les liens
de `adonisjs-suite`. L'accès direct peut être demandé avec
`pi --skill ~/.agents/skills/adonisjs-backend`.
Le contrôle lit désormais aussi les en-têtes des skills npm configurés :
`mcp-scripting` reste installé et explicitement invocable malgré son
`disable-model-invocation: true`. Les collisions d'identité, fichiers manquants,
en-têtes requis invalides et apparitions inattendues dans l'index échouent.
Le parseur `yaml` est celui déjà fourni par la dépendance SDK Pi du dépôt ;
les YAML invalides et les descriptions vides sont refusés avant l'exemption DMI.

**Les descriptions Claude et deux descriptions partagées avec Codex sont
raccourcies.** Noms et contenu hors description sont conservés octet pour octet.
Quatre fichiers CSS sous Claude sont des liens vers les sources Pi : six hashes
Pi changent au total. La limite Claude passe de **6510 à 4912 caractères**, avec
tests des frontières 4912/4913. Les intentions positives et négatives examinées
figurent dans `.workflow/token-economy/description-intents.json` ; elles ne
constituent pas une preuve d'équivalence de routage par un modèle.

**Le routeur Pi respecte l'effort choisi.** Il ne force plus `xhigh` lors de
quatre routes, réglage qui persistait ensuite. Les tests couvrent des choix
explicites `off/low/medium/high/xhigh`, les tours suivants et les continuations.
Cette correction supprime une modification non demandée ; son gain en tokens
de raisonnement n'a pas été mesuré.

## Candidats écartés et limites

Le plafond natif Codex `skills.max_context_tokens` n'est pas modifié. Sur la
population partielle de 81 skills, les budgets 3000 et 1500 raccourcissent le
catalogue, mais **750 supprime 32 noms**, dont `plan-implement`, `implement`,
`review` et `verify`. Les plugins absents du probe empêchent de valider un plafond
global préservant la découvrabilité. Sources officielles :
[configuration Codex](https://learn.chatgpt.com/docs/config-file/config-reference)
et [chargement des skills](https://learn.chatgpt.com/docs/build-skills).

Le mode `compact` de pi-subagents est également écarté : ses descriptions et
consignes mesurées occupent **8290 caractères**, contre **4606** avec le défaut
actuel. Aucun skill n'est supprimé, aucune limite de sortie n'est abaissée et
aucun effort sélectionné n'est réduit.

Les modèles qui ne prennent pas en charge les outils différés nativement
reçoivent la liste complète des outils désormais actifs au tour suivant. Ce
changement peut invalider une partie du cache de prompt. Après chargement de
tous les groupes, le loader ajoute 320 caractères de métadonnées : l'économie
concerne les tours où les groupes restent inutilisés. Le coût net par tâche,
incluant les appels au loader et les caches, doit être mesuré séparément.

## Validation et preuves

- `scripts/verify-agentic-infra core` : **18/18 contrôles**, dont **262/262 tests
  Pi** et **212/212 scénarios de routeur** sur le diff testé.
- `bash tests/pi-skill-load-check-smoke.sh` et
  `bash tests/claude-skill-load-check-smoke.sh` : succès ; régressions DMI,
  collisions, frontières et politique d'index couvertes.
- `bun run --cwd pi typecheck`, `bun run --cwd pi verify:skills`,
  `git diff --check` : succès.
- Pi : `.workflow/token-economy/pi-tools-probe/summary.json` et les captures
  `eager.json`, `lazy.json`, `installed-load.json`, `fixture.json`, `cli-*.json`.
- Codex : `.workflow/token-economy/codex-probe/after-fallback/comparison.json`
  et `configured/summary.json` ; serveur loopback, connexions distantes bloquées.

L'application locale utilise les liens existants pour les sources et une
modification limitée à cinq filtres dans `~/.pi/agent/settings.json`, avec
sauvegarde privée. Les autres réglages Pi, `claude/CLAUDE.md` et `pi/models.json`
préexistants sont préservés. Aucun plafond Codex, commit, push ou déploiement
externe n'est effectué. Les sessions déjà ouvertes chargent les changements au
prochain démarrage ou rechargement approprié.
