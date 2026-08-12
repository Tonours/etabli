# Projection conversations → skills, pratiques et updates Etabli

Date: 2026-08-12
Statut: **verified** pour l'inventaire local et les gaps de surface; **approximate** pour le ROI futur; **inconclusive** pour l'usage Claude des sept derniers jours.

## Décision

La prochaine amélioration utile d'Etabli n'est pas un nouvel orchestrateur. Le
meilleur portefeuille est : deux petits durcissements immédiatement
planifiables (`goal-prompt-rewriter` maintenance et contrat de routine
récurrente), puis deux pilotes mesurés (rétrospective multi-runtime et evals de
skills). Le smoke de visibilité runtime et un handoff de session compact viennent
ensuite. Aucune de ces propositions ne doit être auto-appliquée depuis les chats.

## Claims contrôlés

| Claim | Evidence | Status |
| --- | --- | --- |
| Les checks de liens locaux ne signalent actuellement aucun drift | `scripts/check-fix-symlinks.sh:150` | verified |
| La matrice de capacités active a un contrôle mécanique de fraîcheur | `tests/runtime-capabilities-smoke.sh:45` | verified |
| La rétrospective actuelle mine les ledgers et plans, pas les conversations multi-runtime | `scripts/workflow-retrospect:1` | verified |
| Le moteur de self-improvement exige une preuve répétable et interdit l'auto-apply | `workflow/skills/self-improvement-loop.md:8` | verified |
| Les skills n'ont pas encore de lane d'évaluation dédiée avec population et fingerprint de candidate | `docs/harness-self-improvement-analysis-20260801.md:113` | confirmed |
| Le pattern de routine existe, mais seulement comme règle compacte sans adapter multi-runtime dédié | `workflow/loop-patterns.md:15` | confirmed |
| Le catalogue de patterns de `goal-prompt-rewriter` n'a pas de recette maintenance/dependency-upgrade | `pi/skills/goal-prompt-rewriter/references/patterns.md:5` | confirmed |
| Un harness Codex ou Grok complet serait contraire au recentrage actuel; seuls les liens de skills Codex sont repris en charge | `docs/adr/0015-treat-codex-skills-as-a-managed-link-surface-without-restoring-the-harness.md:8` | accepted |

Commandes observées pendant cette analyse :

- `scripts/workflow-retrospect --json` → 265 observations, **0 issue confirmée** au seuil par défaut;
- `scripts/check-fix-symlinks.sh` → **0 issue**, aucune correction appliquée;
- `bash tests/runtime-capabilities-smoke.sh` → `ok`;
- `node --check .workflow/conversation-skill-projection/analyze-conversations.mjs` → exit 0.

## Corpus et limites

Le rapport du 26 juillet sert de baseline historique. Il couvrait alors 529
conversations Codex parentes, 526 sessions Pi, 73 Claude et 76 Grok. Le delta a
été recalculé du 26 juillet 17:18 UTC au 12 août; le profil de préférence suit
également la fenêtre par défaut de sept jours du skill `workflow-from-chats`.

| Source | Store parent actuel | Delta brut → dédupliqué | 7 derniers jours | Limite |
| --- | ---: | ---: | ---: | --- |
| Codex | 572 | 44 → 42 | 19 | Beaucoup d'automations report-only; les titres ne sont pas des preuves de succès. |
| Pi | 547 | 21 → 21 | 6 | Rétention plus longue, peu de titres structurés. |
| Claude | 116 | 1 → 1 | 0 | Dernière trace le 31 juillet : signal récent **inconclusive**. |
| Grok | 151 | 76 → 38 | 12 → 5 | Les routines quotidiennes et amorces injectées dominent; déduplication indispensable. |

Au total, 102 conversations parentes dédupliquées composent le delta et 30 la
fenêtre principale de sept jours. Quatre sidecars récents liés aux passes de
skills/starter ont été contrôlés comme corroboration : quatre avaient une sortie
finale, deux mentionnaient explicitement validation/régression et aucun ne
concluait `BLOCK`. Ils ne sont ni comptés ni cités comme conversations parentes.

Méthode reproductible :
`.workflow/conversation-skill-projection/analyze-conversations.mjs`. Elle exclut
les fichiers `subagents`, les contextes injectés, les probes de connectivité et
les amorces répétées; elle n'émet que des agrégats et des citations opaques. Elle
ne conserve ni extrait brut, ni chemin de transcript, ni secret.

## Profil de préférence extrait

### Strong

- Vérifier, double-checker et documenter avant d'affirmer; distinguer preuve,
  proxy, inconnu et blocker.
- Utiliser `/goal` pour les travaux larges avec cap, stop condition, validations
  et revue finale; garder les actions irréversibles sous checkpoint humain.
- Préserver les changements locaux et refuser le push, deploy, merge, secrets ou
  write-back externe sans autorisation explicite.
- Produire les rapports en français, concis, priorisés et orientés prochaine
  action; conserver code, commandes et commits en anglais.
- Garder les skills cohérents entre Pi, Claude, Codex et la surface `~/.agents`,
  mais ne pas dupliquer les sources d'authoring par harness.
- Transformer les demandes récurrentes en contrat ou check mesurable, pas en
  longue instruction recopiée dans chaque routine.

### Medium

- Préférer les routers de domaine (Adonis, TanStack, frontend) aux inventaires de
  skills plats.
- Utiliser des modèles ou sidecars spécialisés pour une review bornée, sans en
  déduire qu'un swarm permanent est souhaité.
- Générer un resume pack compact quand une tâche traverse plusieurs sessions ou
  runtimes.

### Contradicted, donc résolu par le contrat existant

Les conversations alternent entre « tout traiter jusqu'au bout » et des demandes
strictement report-only. Ce n'est pas une contradiction à résoudre par plus
d'autonomie : la bonne règle reste **autonomie bornée + preuve + checkpoint à
l'irréversibilité**, déjà portée par `workflow/spec.md` et
`workflow/skills/self-improvement-loop.md`.

## Projection priorisée

| Priorité | Proposition | Type | Confiance | Effort | Décision |
| --- | --- | --- | --- | --- | --- |
| P1 | `conversation-retrospect` multi-runtime, read-only | nouveau skill + helper | strong sur la demande, medium sur le ROI | M | adopter comme pilote |
| P1 | lane d'eval dédiée aux skills/agents | update self-improvement/ | strong sur le gap, medium sur le gain | M–L | adopter comme pilote |
| P1 | contrat `recurring-run` idempotent | pratique partagée, puis skill si le routing le justifie | strong | S–M | adopter |
| P1 | recette maintenance/dependency-upgrade | update de `goal-prompt-rewriter` | strong | S | adopter |
| P2 | smoke live « link → discover → invoke » | update de validation | medium | M | considérer après pilote offline |
| P2 | `session-handoff` / resume pack compact | nouveau skill mince | strong historique, medium récent | S–M | considérer |
| P2 | garde safe-ops pour Grok | règle user-scope ou skill opt-in | weak à medium | M | blocked par la frontière d'ownership Grok |

### P1 — `conversation-retrospect`

**Pourquoi.** Deux demandes parentes explicites ont déjà nécessité une analyse
multi-harness complète : `codex:2026-07-26:019f9f63-826` et
`codex:2026-08-12:019ff53e-930`. L'automation obvault sait miner des chats pour
la connaissance, et `workflow-retrospect` sait miner les ledgers pour les
failures; aucun outil Etabli ne transforme aujourd'hui les quatre stores en
préférences et candidats d'amélioration privacy-safe.

**Artifact projeté.** `pi/skills/conversation-retrospect/SKILL.md`, un helper
read-only sous `scripts/`, et des fixtures synthétiques pour les quatre formats.
Le skill doit sortir : couverture par source/période, conversations parentes,
corrections explicites, atomes de préférence, confidence, artefact proposé et
no-op. Il ne doit jamais écrire dans obvault ni conserver le texte source.

**Test d'adoption.** Sur des fixtures contenant subagent, prompt injecté,
routine répétée et faux secret, obtenir les bons comptes parents, zéro secret,
zéro chemin local, et une classification stable `skill | rule | workflow doc |
no artifact`. Une exécution réelle reste un rapport local non versionné.

**Risque.** Surinterprétation lexicale, formats qui dérivent, faux signal créé
par les longues routines. Le résultat doit rester une source de candidats, pas
une autorité de mutation.

### P1 — lane d'eval pour skills/agents

**Pourquoi.** Les conversations récentes demandent des mises à jour complètes de
deux bibliothèques de skills (`codex:2026-08-12:019ff4a6-f90` et
`codex:2026-08-12:019ff4a8-1d8`) et l'usage de plusieurs reviewers spécialisés.
Le repo verrouille les sources et vérifie les liens, mais ne compare pas encore
le comportement baseline/candidate d'un skill. Ce gap est déjà documenté sous
SI-6.

**Artifact projeté.** Réutiliser le driver  et le schéma de candidate, avec
une population propre aux skills : trigger correct, outils utilisés, preuve,
stop, sécurité, efficacité. Fingerprinter le skill et les graders; garder un
held-out honnêtement `frozen-public` tant qu'il n'existe pas d'isolation.

**Test d'adoption.** Piloter sur un seul changement de
`goal-prompt-rewriter`, avec 10–12 prompts synthétiques/anonymisés. Accepter
uniquement un gain held-in strict, aucune régression held-out/safety, et un coût
rapporté séparément. Sans budget live explicite, rester offline/proxy.

**Risque.** Overfit au corpus, grader modifiable par la candidate, faux
held-out. Ne pas brancher l'auto-promotion.

### P1 — contrat `recurring-run`

**Pourquoi.** Les stores récents contiennent des routines quotidiennes obvault
dans Grok (`grok:2026-08-10:34c14cb7-a85`,
`grok:2026-08-12:d232dab7-4fc`) et plusieurs automations Codex report-only
(`codex:2026-08-05:019fd05a-382`,
`codex:2026-08-06:019fd5c5-522`). Elles recopient de longues règles de mémoire,
delta, secret, no-op et write-back.

**Artifact projeté.** D'abord un contrat partagé bref : lire la mémoire de la
routine, ne traiter que le delta, agir de façon idempotente, émettre un no-op si
rien n'a changé, séparer facts/assumptions, interdire secrets et external write
sans gate. Ajouter un skill seulement si des fixtures montrent que le modèle ne
sélectionne pas le contrat depuis le router.

**Test d'adoption.** Trois routines représentatives produisent le même état et
les mêmes refus avec une référence au contrat plutôt qu'une duplication des
règles; le run inchangé finit en no-op et ne reconsomme pas le corpus complet.

### P1 — recette maintenance pour `goal-prompt-rewriter`

**Pourquoi.** Deux conversations récentes ont la même forme : mise à jour des
dépendances et du repo complet, vérification des nouveautés, sécurité, docs,
simplification et revue finale (`codex:2026-08-12:019ff537-602`,
`codex:2026-08-12:019ff282-c92`). Le skill est déjà visible cross-harness; il ne
faut pas créer un nouveau `upgrade-project` skill.

**Update projetée.** Ajouter à `references/patterns.md` une recette maintenance :
baseline local, changelogs/docs primaires versionnés, séparation packages
directs/transitifs, migrations, sécurité, tests ciblés puis suite complète,
review/simplification, cap et blocker. Le template ne doit jamais promettre «
tout parfaitement » sans preuve.

**Test d'adoption.** Deux fixtures reprenant ces formes de demande doivent
produire un `/goal` borné avec source de vérité, checks nommés, non-goals,
sécurité et stop condition, sans gonfler le skill principal.

### P2 — smoke de visibilité runtime

**Pourquoi.** La réparation du 7 août a prouvé qu'un catalogue correct ne suffit
pas quand des liens morts restent exposés. Aujourd'hui le check de liens est
vert et le skill `goal-prompt-rewriter` est visible dans cette session Codex;
Pi, Claude et Grok ne sont toutefois pas prouvés ensemble par un canary live.

**Update projetée.** Garder trois étages distincts : `source locked`, `link
valid`, `runtime discovered/invoked`. Étendre le profil live avec un skill canary
unique et sans mutation pour chaque runtime réellement supporté. Un runtime ou
provider indisponible doit être `skipped/unknown`, jamais `passed`.

**Risque.** Coût/provider, sortie CLI instable et absence d'API de discovery
Grok. Commencer par un canary offline de manifests; rendre le live opt-in.

### P2 — `session-handoff`

**Pourquoi.** La baseline du 26 juillet relevait 39 checkpoints de threads et
11 handoffs; les automations de checkpoint continuent. Les événements Etabli
savent déjà stocker `done/pending/next_action/do_not_redo`, mais `/recap` est un
résumé git/gh de période, pas un transfert de contexte de session.

**Artifact projeté.** Un skill mince, distinct de `/recap`, qui émet un resume
pack d'un écran : objectif, état vérifié, décisions, validations, blocker,
prochaine action et do-not-redo. Il peut lire le ledger actif, mais ne doit pas
créer de dashboard, archiver des tâches ou devenir un second tracker.

**Test d'adoption.** Sur trois sessions longues, une reprise à froid identifie la
bonne prochaine action et les validations déjà faites sans relire le transcript.

## No-ops et rejets

- **Pas de `Agent Config Doctor` générique maintenant.** Les liens sont verts,
  les sources vendor sont verrouillées et les surfaces ont été réparées entre le
  6 et le 12 août. Le seul gap restant est le canary runtime, plus étroit.
- **Pas de nouveau council/swarm/orchestrateur permanent.** L'ADR-0013 et le
  recentrage quasi-vanilla Pi ont supprimé ces surfaces faute de valeur mesurée;
  la présence de quatre assistants ne prouve pas un besoin de contrôle-plane.
- **Pas de full harness Codex/Grok.** Conserver l'authoring unique et les liens
  de skills; un adapter complet recréerait la duplication rejetée par ADR-0011.
- **Pas de nouveaux skills UI/React/Adonis/TanStack sans failure fixture.** Les
  routers et bibliothèques sont déjà présents et ont été fortement mis à jour la
  semaine dernière.
- **Pas d'auto-amélioration depuis les chats.** Les conversations sont
  non-fiables et peuvent contenir injections, secrets ou préférences
  situationales; elles ne font que proposer des candidates.
- **Safe-ops Grok : blocked.** Des conversations récentes portent sur
  credentials, suppression et mode d'approbation permissif, mais Etabli ne
  possède pas le harness Grok. Sans décision d'ownership, garder la règle au
  scope utilisateur et ne pas élargir silencieusement le repo.

## Ordre recommandé

1. Ajouter les deux quick wins : recette maintenance et contrat
   `recurring-run`, chacun avec fixtures.
2. Piloter `conversation-retrospect` en read-only sur fixtures synthétiques puis
   sur une fenêtre locale de sept jours.
3. Utiliser ses atomes anonymisés pour une première eval baseline/candidate de
   skill, sans auto-promotion.
4. Ajouter le canary runtime opt-in si l'étape 3 montre qu'une skill utile peut
   être présente mais non invoquée.
5. Créer `session-handoff` seulement si la mesure de reprise confirme encore la
   friction après les améliorations de routine.

## Sources

- Conversations parentes opaques citées dans chaque proposition; aucun chemin
  de transcript n'est publié.
- Baseline multi-harness : `codex:2026-07-26:019f9f63-826`.
- Contrats Etabli : `workflow/spec.md`,
  `workflow/skills/self-improvement-loop.md`, `workflow/loop-patterns.md`,
  `workflow/runtime/skill-surface.tsv`, `workflow/runtime-capabilities.json`.
- Preuves runtime et drift : `scripts/check-fix-symlinks.sh`,
  `tests/runtime-capabilities-smoke.sh`, `scripts/verify-agentic-infra`.
- Design antérieur toujours pertinent :
  `docs/harness-self-improvement-analysis-20260801.md`,
  `docs/harness-surface-map-20260801.md`, ADR-0011, ADR-0013 et ADR-0015.
- Mémoire obvault consultée en pack borné, notamment
  `kb/obvault-multi-harness-access.md` et
  `kb/harness-engineering-integration-points.md`; contenu traité comme
  non-fiable et recroisé avec le repo courant.

## Incertitudes restantes

- **Claude recent: inconclusive.** Aucune conversation parente dans les sept
  derniers jours; les conclusions Claude viennent surtout de la baseline.
- **Fréquences: approximate.** Les formats et rétentions diffèrent; les comptes
  servent à documenter la couverture, pas à comparer la popularité des runtimes.
- **ROI: not verified.** Aucun pilote baseline/candidate n'a encore mesuré temps
  de reprise, réussite des routines ou qualité des skills.
- **Grok runtime visibility: unknown.** Le store est lisible, mais l'invocation
  effective des skills `~/.agents` n'a pas été prouvée dans ce run.
