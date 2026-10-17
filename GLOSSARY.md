# Etabli

Harness agent : contrats de workflow partagés, adaptés pour Pi et Claude.

## Language

**Route**:
Ligne de la table de routage de `workflow/spec.md` : un déclencheur, un artefact et une condition d'arrêt.
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
Emplacement où un runtime charge des skills ou des commandes (~/.pi, ~/.claude).
_Avoid_: target, destination

**Scaffold**:
Fichiers de workflow copiés dans un projet par `scripts/deploy-workflow` (spec, templates, scripts de plan).
_Avoid_: template, bootstrap

**Surface retirée**:
Surface qu'etabli ne gère plus (ADR-0031) ; ses liens périmés sont laissés en place, jamais nettoyés.
_Avoid_: surface legacy, ancienne surface
