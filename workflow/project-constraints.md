# Project Constraints

Open when the same agent mistake on a project's code recurs (third occurrence,
or an `escaped-defect` with `action: project_constraint`).

The project's code is the agents' memory: a mistake that only lives in prose
keeps coming back. Turn it into a constraint in the subject project's own
tooling. Etabli owns this loop, never framework-specific rules.

## Where it goes

Find where rules already live: the project's type-check, lint and test config.
Presence alone does not prove that a tool runs or is strict.

Take the first rung that can express the rule:

1. type: make the wrong state unrepresentable;
2. a rule in the project's existing linter;
3. a structural test in the existing suite;
4. a CI check;
5. prose (`AGENTS.md`, project memory) only when none of the above can.

## Rules

- Ship the constraint with a case that fails before the change and passes after,
  through a command the project already runs (its lint, test or CI command). A
  config file that no such command runs is not a constraint.
- Scope the rule to the mistake: the project's full check stays green, or every
  existing hit is fixed in the same change.
- Its failure message names the remediation.
- Remove the prose the constraint replaces.
- Recommendations are reviewed, never auto-applied; the user decides on rules
  that change the project's conventions.
