# Claude Code — reprise sans crédits

Statut: **PARTIAL** au 2026-10-02. Les corrections sont préparées et testées dans
`/Users/tonours/.codex/worktrees/claude-efficiency-audit/etabli`, base
`1e79c3caa36ed634fcc2099285e00c253df065eb`. **0/42 appels Claude**; aucune campagne d’inférence exécutée. Le code et les
reviews hors ligne sont réalisés avec Codex. Le goal intégral et le PLAN restent ouverts.

## Disposition des huit actions

| Action | Résultat hors ligne | Validation restante |
| --- | --- | --- |
| A1 profil | LSP/effort hérités; vault canonique; MCP strict/non strict corrigé;0600/cleanup | Vault/navigation natifs dans une session réelle |
| A2 lanceurs | daily/deep/lean inspectables; store/binaire explicites; overrides invalides refusés; full conservé | Modèle/effort et parcours terminal/Herdr natifs |
| A3 teams |0 par défaut, opt-in explicite; agents non modifiés | Agents nommés et teams avec le CLI réel |
| A4 visibilité | Effort, parent/cache et quotas natifs; inconnu≠0; Git/contexte conservés | Activation/affichage natifs; Team peut ne pas fournir les quotas |
| A5 reprise | Handoff avec fichiers/PLAN/ledger; nouvelle session pour travail indépendant; aucune remise à zéro automatique | Reprise dans Claude après retour du quota |
| A6 lectures | Contrat de recherche ciblée/réemploi/refresh; budgets respectés; RTK et lean-ctx conservés | Dogfood professionnel distant différé |
| A7 instructions MacBook | Audit et proposition de répartition conservatrice disponibles; contenu privé non exporté | Répartition sémantique privée, diff/backup/rollback concrets puis approbation; pas appliqué |
| A8 plugins | Usages observés documentés; baseline distante conservée, aucun retrait des11plugins | Attribution native des chargements et tests projet/à la demande; pas retenu comme optimisation |

## Preuves techniques

Les fixtures reproduisent le bug MCP non strict et l'absence effort/quota, puis
passent avec les corrections. Les tests couvrent aussi espaces dans les paths,
alias de worktree, imports depuis stdin, binaire invalide, exit natif, signaux et
nettoyage propre à chaque session. Le handoff préserve son ledger, y compris un
répertoire de workflow extérieur au dépôt.

C1–C5 et agents/cockpit sont vérifiés avec les commandes du PLAN; cockpit57/57
et protocole13/13 sont verts. Le protocole
C6 possède six fixtures et des oracles extérieurs au repo candidat: normaliseur
et reprise comparés dans le parent, review avec ancrages/reproductions et contrôle
des faux positifs, MCP synthétique avec preuve d'appels. Un exit0 prématuré et
une écriture hors scope pendant l'import sont refusés. Les réponses JSON sont
comparées sans exiger l'ordre des clés. Les tests gardent zéro distinct d'absence.

Ces oracles restent une préparation, pas une frontière de sécurité face à du
code arbitraire sous le même utilisateur. T2 conserve un sous-processus à
assertions; le marker empêche un exit0 accidentel, pas une falsification hostile.
Le futur runner doit figer/protéger les oracles, vérifier leur intégrité avant et
après chaque mission, collecter le vrai journal MCP et arrêter tout le groupe
de processus sur timeout. La primitive de scope inclut les fichiers non suivis
et ignorés; `.git` est exclu. Aucun runtime Claude n'est déclaré vérifié.

Le core C7 est exécuté séparément. Le premier passage a trouvé des dépendances
absentes dans le worktree (4/30 checks rouges). Des dépendances conformes au
lockfile ont ensuite été installées uniquement dans ce worktree pour revalidation;
la configuration Claude et les dépendances du checkout principal sont préservées.
Le second passage est vert: **30/30 checks**. Son résultat figure dans le
ledger et le log local `core-check.log`.

## Campagne prête à finaliser

Six tâches×deux efforts×trois répétitions =36 missions comparatives, plus6
auxiliaires réservés. Ordre seed20261002, paires AB/BA alternées;42 invocations et
120 minutes maximum au live. T5 reprise et T6 MCP sont nouveaux face au benchmark
historique, sans ajustement de l'effort candidat sur des résultats Claude.

`--dry-run` imprime tous les slots `not_run`, les hashes des prompts/fichiers/
oracles et les prérequis. Il ne contacte ni Claude, ni auth, ni réseau. `--run`
refuse tout lancement. Le runner sérialisé live, les contrôles de groupe de
processus et les fingerprints natifs restent à finaliser avant la campagne.
Compte/store/modèle exact communs, usage inclus établi, crédits supplémentaires
désactivés et quota disponible sont des prérequis, sans fallback API.

Livraisons acceptées: **non mesurées**. Tokens, latence et delta du quota:
**null**. Économie d'abonnement: **INCONCLUSIVE**. Les tests Codex, hashes et
tailles de contexte ne prouvent pas un gain de subscription.

## Application et rollback

Les fichiers versionables restent dans le worktree. Trois liens locaux
`~/.local/bin/claude-daily`, `claude-deep`, `claude-lean` sont installés et vérifiés
par `--inspect`, sans installer global ni mutation des stores. Ils ciblent ce
worktree: le conserver jusqu'à intégration ou rollback. Le reçu/rollback privé est sous
`.workflow/claude-efficiency-offline/local-apply/`. Les settings natifs et les
liens statusline existants ne sont pas modifiés tant que l'affichage natif n'est
pas vérifié. La documentation donne aussi les commandes `scripts/...` utilisables
directement, sans PATH installé.

Aucune écriture SSH sur macbook-work. Ses settings ont changé pendant l'audit:
préserver les préférences nouvelles et revalider les hashes avant toute proposition.
Les dix sections ambiguës de l'ancêtre `~/work/CLAUDE.md` restent conservées;
aucune migration métier n'est approuvable tant que couverture et disponibilité
ne sont pas démontrées. Pas de demande d'approbation distante prématurée.

## Reviews et prochaine action

Deux reviews Codex fraîches et indépendantes (Logic/Spec) portent l'exception
hors ligne demandée par l'utilisateur. Elles restent **same-family**. Leurs
findings corrigés et verdicts sont tracés dans le run offline; aucune review
Anthropic/cross-family n'est revendiquée. Le ledger terminal précédent est intact.

Le runner peut encore être finalisé avec Codex. Le retour du quota permettra
ensuite de vérifier le modèle, l'effort, le LSP et la reprise dans une vraie
session Claude (C8), puis de mesurer la qualité et la consommation (C10).
Le « store » est le dossier de configuration Claude. Les six appels auxiliaires
réservés servent aux vérifications, dans le plafond total de42 appels.

Sur le MacBook, la répartition privée des règles et les plugins attendent leur
diff, sauvegarde et rollback, puis ton accord avant application (C9). Une review
Claude complétera les reviews Codex (« cross-family ») avant de clôturer le goal.
Ces points n'empêchent pas de publier les corrections hors ligne; ils empêchent
de présenter l'économie d'abonnement comme démontrée. Le PLAN reste conservé.

Sources: [schema statusline natif](https://code.claude.com/docs/en/statusline),
[gestion des Usage credits Team](https://support.claude.com/en/articles/12005970-manage-usage-credits-for-team-and-seat-based-enterprise-plans),
[audit local](research/20261002-claude-code-configuration-efficiency-audit.md).
