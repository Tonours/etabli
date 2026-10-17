#!/usr/bin/env bash
# Skill surface policy: one source of truth for which surfaces receive a
# catalog record (Claude for every active-scope record; Pi only when pi_core),
# and one record stream for first-party and vendor skills.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
. "$ROOT_DIR/scripts/lib/skill-catalog.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf 'skill surface policy smoke: %s\n' "$1" >&2
  exit 1
}

# Predicate contract.
if skill_surface_expected .claude/skills "" 1 shared; then
  fail "empty scope must fail closed"
fi
skill_surface_expected .pi/agent/skills shared 0 shared && fail "pi_core=0 on Pi surface must not be expected"
skill_surface_expected .pi/agent/skills shared 1 shared || fail "pi_core=1 on Pi surface must be expected"
skill_surface_expected .claude/skills shared 0 shared || fail "every active-scope record must be expected on Claude"
if skill_surface_expected .claude/skills work 1 "shared personal"; then
  fail "inactive scope must not be expected on Claude"
fi
if skill_surface_expected .pi/agent/skills work 1 shared; then
  fail "inactive scope must not be expected on Pi"
fi

# Record stream: first-party scope from the path, vendor scope from sources.tsv,
# declared names as link names, shelf rows omitted.
REPO="$TMP_DIR/repo"
mkdir -p "$REPO/skills/shared/core" "$REPO/skills/work/ticket" "$REPO/vendor/suite/skills/group/tool" \
  "$REPO/extras/skills/shelved"
printf -- '---\nname: core\ndescription: x\n---\n' >"$REPO/skills/shared/core/SKILL.md"
printf -- '---\nname: ticket\ndescription: x\n---\n' >"$REPO/skills/work/ticket/SKILL.md"
printf -- '---\nname: tool-renamed\ndescription: x\n---\n' >"$REPO/vendor/suite/skills/group/tool/SKILL.md"
printf 'suite\thttps://example.invalid/s.git\tmain\tpersonal\tgroup/tool\n' >"$REPO/vendor/sources.tsv"
printf 'shared/core\tetabli\t1\t1\nwork/ticket\tetabli\t0\t1\ngroup/tool\tsuite\t1\t1\nshelved\textras\t0\t1\n' >"$TMP_DIR/catalog.tsv"

skill_catalog_records "$TMP_DIR/catalog.tsv" "$REPO" >"$TMP_DIR/records"
expected="$(printf 'shared\tcore\t%s\t1\tetabli\nwork\tticket\t%s\t0\tetabli\npersonal\ttool-renamed\t%s\t1\tsuite\n' \
  "$REPO/skills/shared/core" "$REPO/skills/work/ticket" "$REPO/vendor/suite/skills/group/tool")"
[ "$(cat "$TMP_DIR/records")" = "$expected" ] || {
  diff <(printf '%s\n' "$expected") "$TMP_DIR/records" >&2 || true
  fail "record stream drifted"
}

printf 'skill surface policy smoke test: ok\n'
