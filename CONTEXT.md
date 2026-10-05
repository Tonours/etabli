# Etabli

Harness agent : contrats de workflow partagés, adaptés pour Pi et Claude.

## Language

**Route**:
Résultat du routeur pour un prompt, avec un artefact et une condition d'arrêt.
_Avoid_: workflow, mode

**Cœur**:
Routes et contrats dont dépend le gate READY.
_Avoid_: core skills, essentiels

**Commande explicite**:
Skill ou commande invoquée par son nom, jamais choisie par le routeur.
_Avoid_: opt-in, route secondaire

**Scope**:
Partition de déploiement (shared, work, personal) qui décide quelles surfaces reçoivent une skill.
_Avoid_: profil, environnement

**Étagère**:
Skills suivies dans git mais jamais déployées (extras/) ; on les promeut en les déplaçant.
_Avoid_: opt-in, vendor, archive

**Surface**:
Emplacement où un runtime charge des skills ou des commandes (~/.pi, ~/.claude, ~/.agents).
_Avoid_: target, destination
