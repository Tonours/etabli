# Maintenance goal fixtures

## Fixture 1 — Node dependency upgrade

Request: Mets toutes les dépendances Node à jour et assure-toi que tout est parfait.

Prompt:

/goal Bring the direct Node dependencies declared by the current workspace to
targets verified from the lockfile, package-manager output, versioned upstream
release notes, migration guides, and security advisories. Separate direct,
transitive, security, breaking-migration, deferred, blocked, and unknown items;
preserve the supported Node range and public behavior. Upgrade at most three
compatible batches, run package-focused tests after each batch, then the full
lint, typecheck, test, and build suite plus review/simplification. Do not deploy,
push, access secrets, or force incompatible resolutions. Stop with exact
evidence, rollback state, blocker, uncertainty, and next input if a safe target
cannot be proved.

## Fixture 2 — Framework maintenance

Request: Modernise le framework et ses plugins sans casser la production.

Prompt:

/goal Move the named framework and first-party plugins across the bounded
supported upgrade path, verified from the current manifest/lockfile and each
versioned primary changelog and migration guide. Inventory direct versus
transitive packages, required migrations, security fixes, deprecations,
compatibility constraints, and deferred or unknown items. Apply at most two
major-version steps; after each step run focused migration tests, then the full
relevant suite and a review/simplification pass. Preserve production data and
public contracts; do not deploy, mutate production, push, or bypass peer
constraints. Stop with validation evidence, rollback point, blocker,
uncertainty, and required input if the migration cannot be proved safe.
