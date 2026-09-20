# Traces des harness et boucle de self-improvement

Date de recherche : 2026-09-20. Statut : `verified` pour les formats, les
intégrations locales inspectées et le prototype offline sur fixtures
synthétiques ; `not verified` pour son bénéfice sur des traces privées réelles
ou sur la qualité d'une campagne de self-improvement.

## Conclusion

Les traces natives peuvent alimenter la faiblesse-mining d'Etabli, mais elles
ne doivent pas devenir directement des événements publics ni une autorité de
mutation.

- **Pi est la meilleure source de trajectoire.** Son JSONL contient une
  arborescence de session, des messages typés, les appels et résultats d'outils,
  les erreurs terminales, l'usage et les compactages. L'extension Etabli y
  ajoute déjà des décisions de route et reporte l'usage au moment
  `agent_settled`.
- **Claude est exploitable, mais plus fragile.** Les hooks reçoivent un
  `transcript_path`; le hook Stop relit le JSONL pour extraire l'usage et le
  PostToolUse transforme déjà certains échecs Bash en événements Etabli. Le
  format observé n'est cependant pas un contrat versionné dans ce dépôt et une
  fixture réelle documente explicitement le risque de dérive après upgrade.
- **Codex et Grok sont des sources batch, pas des surfaces Etabli pilotables.**
  Le rétrospecteur sait retrouver leurs stores, mais l'architecture courante ne
  possède pas de hooks Etabli sur ces harness.
- **Le rétrospecteur actuel ne suffit pas pour inférer une cause.** Il ne garde
  que les messages utilisateur parents, les classe par expressions régulières,
  puis publie des compteurs et citations opaques. Il exclut précisément les
  appels d'outils, sorties, verdicts et états terminaux nécessaires pour relier
  une faiblesse à un mécanisme du harness.

Le prototype implémenté est donc un **extracteur offline, borné et
déterministe** qui convertit une trace et un ledger explicitement sélectionnés
en observation non causale minimale. Il n'émet ni contenu brut, ni chemin, ni
identifiant ou empreinte dérivée des entrées. Les traces brutes restent dans
leur store natif et leur contenu n'est jamais envoyé à Jev par défaut.

## Unité d'analyse : un workflow Etabli terminé

La cible n'est pas une surveillance générale du harness. L'unité pertinente est
un **épisode Etabli délimité** : une route (`plan-loop`, `implement`,
`plan-implement`, etc.), son ledger, la tranche correspondante de la trace
native, puis son terminal réel. L'analyse commence seulement après ce terminal.

```text
route_decided + plan/ledger initial
    ↓ exécution dans Pi, Claude ou un autre harness
trace native privée + événements Etabli
    ↓ terminal Etabli et verifier du livrable
rétrospective déterministe du run
    ↓ comparaison à d'autres runs indépendants
no_op | recommendation | harness_failure_pattern vérifié
    ↓ nouveau PLAN.md READY, sur demande
correction du workflow ou du harness
```

Les questions diffèrent selon la route :

- après `plan-loop`, mesurer notamment les boucles de clarification/revue, les
  changements de statut, les objections répétées, les compactages et le verdict
  final `READY` ou `CHALLENGED` ;
- après `implement`, mesurer la dérive par rapport au plan, les échecs et
  reprises d'outils, les validations relancées, les corrections post-review et
  le verifier final du livrable ;
- après `plan-implement`, conserver les deux phases séparées afin qu'un bon
  résultat d'implémentation ne masque pas une planification inefficace, et
  inversement.

Un `Stop`, un `agent_settled` ou un `turn.completed` borne la trace du harness,
mais ne constitue pas le verdict du workflow. Le lien doit être explicite via
un identifiant de run, l'empreinte du plan et les bornes temporelles ; le
terminal du ledger et son verifier restent l'autorité sur le résultat produit.
La rétrospective peut alors proposer une amélioration, mais elle ne l'applique
pas : une modification de contrat, routeur, skill ou hook repasse par la route
self-improvement et par un plan `READY`.

## Sources et méthode

Cette recherche est limitée aux sources locales de première main : code et
contrats Etabli, fixtures capturées par Etabli et documentation/types du paquet
Pi installé. Aucun store privé réel n'a été ouvert et aucune trace utilisateur
n'a été copiée. Le contexte Obvault borné a seulement confirmé la frontière
mémoire existante ; les constats techniques ci-dessous viennent du dépôt.

Le contrat de self-improvement exige des causes terminales vérifiées, un statut
causal, le mécanisme exposé et des liens de trace ; il interdit de généraliser
depuis une anecdote. Il place aussi les traces brutes hors Git et réserve au
dépôt public des contrats assainis, fixtures synthétiques, empreintes et
agrégats ([workflow/skills/self-improvement-loop.md:10](../../workflow/skills/self-improvement-loop.md#L10),
[workflow/skills/self-improvement-loop.md:20](../../workflow/skills/self-improvement-loop.md#L20),
[workflow/skills/self-improvement-loop.md:42](../../workflow/skills/self-improvement-loop.md#L42)).

## Inventaire concret

| Harness / couche | Store et format observés | Champs et cycle utiles | Risques | Aptitude self-improvement |
| --- | --- | --- | --- | --- |
| Pi session | `~/.pi/agent/sessions/--<cwd>--/<timestamp>_<uuid>.jsonl`; header `session`, puis entrées reliées par `id` / `parentId` | `cwd`, parent de session, rôle, contenu, provider/model, usage et coût, `stopReason`, `errorMessage`, tool call/result + `isError`, bash exit/troncature, changement de modèle/effort, compaction et branche | prompts, raisonnement, commandes, sorties, images base64, chemins, coûts ; arbre avec branches abandonnées ; migrations automatiques v1→v3 | **Élevée**, à condition de reconstruire la branche/phase correcte et d'extraire sans contenu brut. Sources : [session-format.md:1](../../pi/node_modules/@earendil-works/pi-coding-agent/docs/session-format.md#L1), [session-format.md:72](../../pi/node_modules/@earendil-works/pi-coding-agent/docs/session-format.md#L72), [session-format.md:174](../../pi/node_modules/@earendil-works/pi-coding-agent/docs/session-format.md#L174), [session-format.md:189](../../pi/node_modules/@earendil-works/pi-coding-agent/docs/session-format.md#L189). |
| Pi événements live | API d'extension en mémoire ; persistance possible via `appendEntry` dans le JSONL | `session_start`, prompt/input, tour, message, tool execution/call/result, `agent_end`, puis `agent_settled`; switch/fork/compact/shutdown explicites | `message_update` est volumineux ; les outils parallèles peuvent finir hors ordre ; le système prompt et les context files sont sensibles | **Élevée pour le futur**, particulièrement au point `agent_settled`, qui garantit qu'aucun retry/compactage/follow-up automatique ne reste. Sources : [extensions.md:273](../../pi/node_modules/@earendil-works/pi-coding-agent/docs/extensions.md#L273), [extensions.md:392](../../pi/node_modules/@earendil-works/pi-coding-agent/docs/extensions.md#L392), [extensions.md:519](../../pi/node_modules/@earendil-works/pi-coding-agent/docs/extensions.md#L519). |
| Pi télémétrie typée | API de spans `pi.ai.*`, `pi.harness.*`, sans exporter configuré dans les réglages Etabli inspectés | requête provider/model/API/tokens/coût/TTFC ; run, checkpoint, turn, retry step, tool, hook, sleep, event handler et session write ; outcome et codes d'erreur à faible cardinalité | les identifiants session/lane/opération/appel sont haute cardinalité ; brancher un exporteur créerait une nouvelle surface de rétention/egress | **Prometteuse mais non disponible aujourd'hui** : le schéma existe dans le paquet, pas une preuve de collecte persistée par Etabli. Sources : [telemetry.d.ts:1](../../pi/node_modules/@earendil-works/pi-agent-core/dist/harness/telemetry.d.ts#L1), [telemetry.d.ts:121](../../pi/node_modules/@earendil-works/pi-agent-core/dist/harness/telemetry.d.ts#L121), [telemetry.d.ts:298](../../pi/node_modules/@earendil-works/pi-agent-core/dist/harness/telemetry.d.ts#L298), [telemetry.d.ts:411](../../pi/node_modules/@earendil-works/pi-agent-core/dist/harness/telemetry.d.ts#L411). |
| Pi + Etabli | custom entries dans la session et événements `.workflow` | décision déterministe/Jev et raison de fallback enregistrées ; les échecs/succès de validations Bash sont liés au ledger actif ; usage agrégé à `agent_end`, émission au `agent_settled` | une custom entry conserve potentiellement la décision dans une session privée ; `run_terminal` ne prouve pas la réussite fonctionnelle | **Déjà partiellement intégré** : exploitable pour route/guard/usage, insuffisant seul pour la causalité et la qualité. Sources : [pi/extensions/workflow-router.ts:119](../../pi/extensions/workflow-router.ts#L119), [pi/extensions/workflow-router.ts:215](../../pi/extensions/workflow-router.ts#L215), [pi/extensions/workflow-router.ts:258](../../pi/extensions/workflow-router.ts#L258). |
| Claude transcript | `~/.claude/projects/<cwd-slug>/<session-id>.jsonl` et `~/.claude/transcripts/*.jsonl` selon les lecteurs locaux | entrées `user` / `assistant`, `sessionId`, timestamp, `cwd`, sidechain/meta, contenu ; `requestId`/message id et usage ; tool-use/result et attachements de hook dans les formats déjà normalisés par Etabli | format susceptible de dériver ; transcript complet non borné dans certains hooks ; prompts, résultats d'outils, cwd et erreurs de hook sensibles | **Moyenne à élevée**, si un adaptateur versionne les formes acceptées, borne les lectures et fail-close en `unavailable` pour toute forme inconnue. Sources : [conversation-retrospect.mjs:414](../../scripts/lib/conversation-retrospect.mjs#L414), [conversation-retrospect.mjs:528](../../scripts/lib/conversation-retrospect.mjs#L528), [claude-usage-rollup.mjs:39](../../scripts/lib/claude-usage-rollup.mjs#L39). |
| Claude + Etabli | hooks `PreToolUse`, `PostToolUse` et `Stop` ; hook input contient `cwd`, outil/résultat et/ou `transcript_path` | garde avant mutation ; échec Bash après outil ; au Stop, extraction `input/output/cache` et émission d'un `outcome_metric` `run_terminal` | hooks limités à 5 s ; exceptions volontairement avalées pour ne pas bloquer la session ; Stop n'est pas un task grader | **Déjà partiellement intégré** pour échecs de validation et coût, pas pour prouver le résultat produit. Sources : [claude/settings.workflow-hooks.json:1](../../claude/settings.workflow-hooks.json#L1), [claude/hooks/outcome-metric-emit.mjs:1](../../claude/hooks/outcome-metric-emit.mjs#L1), [claude/hooks/outcome-metric-emit.mjs:82](../../claude/hooks/outcome-metric-emit.mjs#L82). |
| Codex | index `~/.codex/state_5.sqlite` lu en `mode=ro`, puis rollouts JSONL sous `~/.codex/sessions` et `archived_sessions` | thread id, rollout path, dates, titre ; `response_item` / payload message dans le lecteur actuel ; le normaliseur historique connaît aussi turn/item/tool/usage | aucun hook Etabli géré ; provenance provider/model incomplète dans le normaliseur ; store très sensible | **Moyenne en batch**, utile pour récurrence et mesures importées, pas pour une décision temps réel. Sources : [conversation-retrospect.mjs:429](../../scripts/lib/conversation-retrospect.mjs#L429), [harness-token-usage.mjs:110](../../scripts/lib/harness-token-usage.mjs#L110), [harness-token-usage.mjs:177](../../scripts/lib/harness-token-usage.mjs#L177). |
| Grok | `~/.grok/sessions/**/summary.json` + `chat_history.jsonl` | request id, dates et messages utilisateur dans le lecteur actuel | surface skills-only, sans hook ni garde Etabli ; détails opérationnels non normalisés ici | **Faible à moyenne**, limitée à la récurrence conversationnelle tant qu'aucun receipt structuré n'est disponible. Source : [conversation-retrospect.mjs:559](../../scripts/lib/conversation-retrospect.mjs#L559). |
| Ledger Etabli | `.workflow/<slug>/events.jsonl`, JSONL v2 append-only, local et gitignored | route, changements, validations, revues, no-progress, outcome, échecs/propositions/validation de harness, terminal `completed`/`blocked` | ne doit pas devenir une copie de transcript ; un événement présent ne prouve pas qu'il est à jour ; usage absent ≠ zéro | **Autorité de promotion**, mais seulement après normalisation/verifier. Sources : [workflow/events.md:1](../../workflow/events.md#L1), [workflow/events.md:37](../../workflow/events.md#L37), [workflow/events.md:80](../../workflow/events.md#L80). |

### Dérive Claude à traiter explicitement

La fixture `real-blocked-stop.jsonl` a été capturée sur Claude Code 2.1.247. Sa
provenance précise qu'une fixture committée peut continuer à passer alors que le
harness réel a changé, et demande une recapture après upgrade
([tests/fixtures/adr-hook/PROVENANCE.md:3](../../tests/fixtures/adr-hook/PROVENANCE.md#L3),
[tests/fixtures/adr-hook/PROVENANCE.md:20](../../tests/fixtures/adr-hook/PROVENANCE.md#L20)).
Un extracteur Claude doit donc publier `adapter_version` et un compteur
`unsupported_rows`. Une forme inconnue rend le résultat `unavailable`; seul un
type secondaire connu, validé et sans effet décisionnel peut produire
`partial`.

## Ce que fait réellement `conversation-retrospect`

Le lecteur commun supporte Codex, Pi, Claude et Grok avec des caps par source de
2 000 fichiers, 64 MiB et 20 000 messages. Il refuse les symlinks, borne les
lectures, filtre le temps, exclut sidechains/subagents, contexte injecté, probes
et doublons, puis émet uniquement compteurs, thèmes, pratiques et citations
opaques ([conversation-retrospect.mjs:15](../../scripts/lib/conversation-retrospect.mjs#L15),
[conversation-retrospect.mjs:189](../../scripts/lib/conversation-retrospect.mjs#L189),
[conversation-retrospect.mjs:683](../../scripts/lib/conversation-retrospect.mjs#L683)).

C'est une bonne frontière de confidentialité pour détecter des sujets
récurrents. En revanche :

1. Pi et Claude sont réduits aux messages utilisateur parents ; les réponses,
   tool calls/results, stop reasons et validations ne participent pas à la
   classification ([conversation-retrospect.mjs:495](../../scripts/lib/conversation-retrospect.mjs#L495),
   [conversation-retrospect.mjs:528](../../scripts/lib/conversation-retrospect.mjs#L528)).
2. Les catégories sont des regex sur le texte, pas des verdicts causaux
   ([conversation-retrospect.mjs:39](../../scripts/lib/conversation-retrospect.mjs#L39)).
3. Le hash d'ouverture déduplique des demandes proches mais ne relie pas une
   action, une mutation, un verifier et un résultat terminal.

Conclusion : conserver ce script comme **signal de récurrence/proposition**. Ne
pas lui attribuer `terminal_cause`, `causal_status` ou `verifier` sans une autre
source structurée.

## Trou actuel : les imports historiques ne sont plus rejouables

Le contrat documente encore un « recovery helper » qui relit les enveloppes de
session et affirme que l'agrégateur réexécute indépendamment l'extracteur avant
d'accepter un import
([workflow/events-validator.md:158](../../workflow/events-validator.md#L158)).
Ce n'est plus vrai dans l'arbre courant : l'historique Git montre que
`scripts/workflow-telemetry-recover` a été ajouté par `091bcac`, puis supprimé
par `a138294` comme artefact inutilisé.

Le validateur restant, `scripts/workflow-measurement-integrity`, contrôle :

- l'empreinte du manifest et des ledgers cibles ;
- la forme exhaustive de l'import et ses compteurs ;
- l'appartenance unique à la population ;
- l'ordre des bornes temporelles et le délai terminal.

Il n'ouvre aucun store Codex et ne recalcule pas les compteurs depuis une
session source
([scripts/workflow-measurement-integrity:36](../../scripts/workflow-measurement-integrity#L36),
[scripts/workflow-measurement-integrity:64](../../scripts/workflow-measurement-integrity#L64),
[scripts/workflow-measurement-integrity:88](../../scripts/workflow-measurement-integrity#L88)).

Le diagnostic agrégé courant de `scripts/workflow-retrospect --json` compte 63
événements `outcome_metric`, 12 runs avec usage natif, 37 imports valides selon
le validateur courant et 50 événements sans `runtime`; un agrégat direct des
ledgers compte seulement 3 événements `success_kind: task_grader`. Ces nombres
décrivent l'état local observé le 2026-09-20, pas une population de qualité.

Verdict : les 37 imports sont **structurellement valides et liés par empreinte
à leur ledger cible**, mais leur agrégat n'est **pas actuellement
source-replayable**. Ils ne doivent donc pas servir de baseline stricte pour un
candidat de self-improvement tant qu'un extracteur versionné n'a pas recalculé
le même résultat depuis les traces natives. La documentation des lignes
158–182 est stale sur ce point.

## Proposition d'intégration minimale

### 1. Extracteur privé distinct implémenté au niveau prototype

`scripts/harness-trace-retrospect` reste distinct de `conversation-retrospect`.
Il lit deux fichiers explicites, refuse les liens symboliques et fichiers
spéciaux, vérifie la stabilité du descripteur, puis applique des plafonds
d'octets et de lignes.

Sortie proposée, sans texte brut :

```json
{
  "schema_version": 1,
  "adapter": "pi",
  "adapter_version": "prototype-offline-1",
  "binding": "explicit_unverified",
  "observation_id": "random-uuid",
  "completeness": "complete",
  "lifecycle": {"terminal": true, "outcome": "completed"},
  "signals": {
    "tool_calls": 7,
    "tool_errors": 1,
    "validation_failures": 1,
    "compactions": 1,
    "verifier": true
  },
  "usage": {"input_tokens": 1200, "output_tokens": 300, "total_tokens": 1500},
  "decision": {"action": "recommendation", "category": "tool_failure", "target": "tooling", "causal_status": "unknown"}
}
```

Les valeurs `0` ne seraient permises que lorsqu'une population complète est
observée ; une information absente resterait `null` avec une raison. C'est
cohérent avec la règle du ledger qui interdit de transformer une télémétrie
indisponible en zéro ([workflow/events.md:95](../../workflow/events.md#L95)).

### 2. Séparer trois niveaux de preuve

```text
store natif privé
    ↓ extraction déterministe bornée, sans contenu
observation privée normalisée
    ↓ corrélation avec ledger + verifier indépendant
harness_failure_pattern public/local
    ↓ récurrence indépendante + PLAN READY + comparaison figée
candidat accepté ou rejeté
```

- Une erreur d'outil seule donne `causal_status: unknown`.
- Elle devient `contributing` seulement si un verifier établit le lien avec
  l'échec terminal.
- Elle devient `causal` seulement si la correction du mécanisme change le
  résultat sur une population comparable sans régression.
- Le succès du transport ou `agent_settled` n'est jamais assimilé à un succès
  de tâche ; le code actuel garde déjà cette distinction en utilisant
  `success_kind: "run_terminal"` au Stop Claude et au settled Pi.

### 3. Brancher d'abord Pi et Claude

Ordre recommandé :

1. **Pi offline** : sessions JSONL + custom entries Etabli + ledger. C'est le
   format le plus typé et le mieux lié au cycle d'exécution.
2. **Claude offline** : transcript + ledger, avec canary de forme et
   `unsupported_rows` obligatoire.
3. **Codex** : restaurer une extraction source-replayable avant de réutiliser
   les 37 imports historiques dans une comparaison stricte ; ne pas réintroduire
   automatiquement l'ancien helper sans nouveau plan et nouvelles fixtures.
4. **Grok** : seulement après avoir prouvé l'utilité des deux premiers ; son
   absence de hooks Etabli limite la corrélation temps réel.
5. **Pi telemetry** : ne pas ajouter d'exporteur avant de démontrer qu'un champ
   manque réellement aux sessions et événements existants.

### 4. Garder Jev en shadow facultatif

Le profil `self-improvement-candidate` peut recevoir, avec autorisation
d'egress explicite, un petit état déjà assaini. Il ne doit jamais recevoir le
transcript, les arguments/sorties d'outils, le cwd ou les chemins de stores. Son
résultat reste une classification shadow : la preuve, l'acceptation, le plan et
les permissions restent déterministes
([workflow/semantic-profiles.md:20](../../workflow/semantic-profiles.md#L20),
[workflow/semantic-profiles.md:48](../../workflow/semantic-profiles.md#L48)).

## Risques et contrôles nécessaires

| Risque | Contrôle proposé |
| --- | --- |
| Secret ou donnée privée dans prompt/tool output/image | ne jamais émettre le contenu ; allowlist de champs numériques/énumérés ; scanner secret avant écriture ; mode fichier `0600` pour toute observation privée |
| Chemin/cwd révélant client ou machine | aucun chemin brut et aucune empreinte dérivée des entrées dans l'observation |
| Double comptage après retry, branch ou compaction | identité native (`requestId`, message/tool id, Pi `id/parentId`) + type ; branche active explicitement choisie ; retries gardés comme coût mais pas comme nouvelles tâches |
| Confondre arrêt et réussite | `run_terminal` séparé de `task_grader`; joindre un verifier de résultat pour la qualité |
| Dérive du format Claude/Codex/Grok | canary de forme locale, forme inconnue `unavailable`, `partial` réservé aux lignes secondaires validées, recapture documentée après upgrade |
| Auto-amélioration qui apprend ses propres tests | évaluateur et manifest hors surfaces éditables ; baseline/candidat liés par empreintes ; test final renouvelé après ouverture |
| Rétention incontrôlée | raw laissé au store natif ; observation privée avec TTL ; agrégat/empreinte uniquement dans Etabli |
| Egress accidentel | extraction 100 % offline ; Jev seulement par commande `--live` distincte et opt-in explicite |

## Pilote recommandé et critères

Le prochain niveau doit repasser par un `PLAN.md` borné. Pilote proposé : 20
sessions Pi et 20 sessions Claude sur
une fenêtre explicite, sélectionnées sans regarder leur résultat, avec revue
humaine d'un échantillon assaini.

Objectif initial : **fiabilité de l'extraction**, pas amélioration du taux de
succès.

- 100 % des sessions reçoivent `complete`, `partial` ou `unavailable` ; aucune
  disparition silencieuse.
- 100 % des événements normalisés passent un scan anti-secret et ne contiennent
  aucun texte libre, chemin brut, prompt, commande ou sortie.
- Les comptes tool/error/retry/compaction et l'issue terminale correspondent à
  une revue manuelle sur l'échantillon.
- Zéro candidat n'est promu automatiquement ; les observations ne produisent
  que `no_op` ou `recommendation` pendant le pilote.
- Au moins deux initiatives indépendantes et un verifier doivent confirmer un
  motif avant de proposer un `harness_failure_pattern`.
- Une suite synthétique couvre les branches, compactages, tool results hors
  ordre, usage manquant, Claude shape inconnue, ligne JSONL corrompue, secret et
  cap atteint.

Le gain futur — moins d'incidents, meilleure qualité ou coût inférieur — reste
`not verified`. Le premier succès démontrable est plus modeste : transformer
des traces privées hétérogènes en observations bornées, reproductibles et assez
sûres pour éclairer une proposition sans autoriser une mutation.

## Validation de cette note

- Sources inspectées : contrats, adaptateurs et fixtures locales listés dans
  les citations ; documentation/types du paquet Pi installé.
- Non inspecté : contenu des stores privés réels, exporter de télémétrie live,
  effet sur une campagne de self-improvement.
- Limite vérifiée : les imports historiques présents passent les contrôles de
  forme/empreinte actuels, mais l'extracteur source mentionné par la
  documentation n'existe plus dans l'arbre courant.
- Modification : prototype offline et contrats associés ; aucun hook, store
  privé, appel provider ou secret n'a été utilisé.
- Commandes documentaires exécutées avec succès :
  `scripts/research-proof-check docs/research/20260920-harness-traces-self-improvement.md`
  et
  `scripts/answer-quality-check --mode research docs/research/20260920-harness-traces-self-improvement.md`.
