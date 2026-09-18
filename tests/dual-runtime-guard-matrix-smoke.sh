#!/usr/bin/env bash
# C8: honest dual-runtime matrix for READY guard + ops-stop + capability labels.
# Does not promote unknown/proxy_supported to confirmed.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
MATRIX="$ROOT_DIR/workflow/runtime-capabilities.json"
CORE="$ROOT_DIR/workflow/runtime/workflow-router-core.mjs"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
	printf 'dual-runtime guard matrix smoke: %s\n' "$1" >&2
	exit 1
}

[ -f "$MATRIX" ] || fail "missing capabilities matrix"
[ -f "$CORE" ] || fail "missing router core"

# Capability labels stay honest (no silent confirmed promotion)
bad="$(jq -r '
  .runtimes | to_entries[] as $r |
  $r.value | to_entries[] |
  select((.value | type) == "object") |
  select(.value.label != "confirmed" and .value.label != "proxy_supported" and .value.label != "blocked" and .value.label != "unknown") |
  "\($r.key).\(.key)=\(.value.label)"
' "$MATRIX")"
[ -z "$bad" ] || fail "invalid capability labels: $bad"

# Print matrix (inspectable)
printf 'runtime_capability_matrix:\n'
jq -r '
  .runtimes | to_entries[] as $r |
  $r.value | to_entries[] |
  select((.value | type) == "object") |
  "  \($r.key).\(.key)\t\(.value.label)"
' "$MATRIX"

# Shared planMutationGuardDecision works for Claude-style and Pi-style tool names
node --input-type=module <<EOF
import { pathToFileURL } from "node:url";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { join } from "node:path";
import { evaluateReadyPlan } from "$ROOT_DIR/scripts/lib/plan-check-freeze.mjs";

const mod = await import(pathToFileURL("$CORE").href);
const tmp = "$TMP";

const commonmarkBundle = readFileSync(join("$ROOT_DIR", "scripts/vendor/commonmark/commonmark.cjs"));
const commonmarkDigest = createHash("sha256").update(commonmarkBundle).digest("hex");
if (commonmarkDigest !== "2de0f8ecbca0a6470da57c8b2ad043777ae999c5132f9abf12e8c332d4e46164") {
  console.error("vendored commonmark@0.31.2 digest mismatch: " + commonmarkDigest);
  process.exit(1);
}

if (mod.isMutationRelevantTool("TaskList") !== false || mod.isMutationRelevantTool("read") !== false) {
  console.error("non-mutating tools must be rejected before filesystem guard work");
  process.exit(1);
}
if (mod.isMutationRelevantTool("Write") !== true || mod.isMutationRelevantTool("Bash") !== true) {
  console.error("mutation-relevant tools must remain guarded");
  process.exit(1);
}

writeFileSync(join(tmp, "PLAN.md"), "# PLAN\\n\\n## Meta\\n- Status: DRAFT\\n");

const claudeDeny = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Write",
  tool_input: { file_path: join(tmp, "x.ts"), content: "x" },
});
if (claudeDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("Claude Write under DRAFT must deny");
  process.exit(1);
}

const piDeny = mod.planMutationGuardDecision({
  cwd: tmp,
  toolName: "write",
  input: { path: join(tmp, "y.ts"), content: "y" },
});
if (piDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("Pi write under DRAFT must deny via normalizeToolName");
  process.exit(1);
}

const planEditAllowed = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Edit",
  tool_input: { file_path: join(tmp, "PLAN.md"), old_string: "DRAFT", new_string: "READY" },
});
if (planEditAllowed != null) {
  console.error("PLAN.md edit under DRAFT must be allowed");
  process.exit(1);
}

const relativePlanEditAllowed = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Edit",
  tool_input: { file_path: "PLAN.md", old_string: "DRAFT", new_string: "READY" },
});
if (relativePlanEditAllowed != null) {
  console.error("relative root PLAN.md edit under DRAFT must resolve against event cwd");
  process.exit(1);
}

for (const command of [
  "cd " + tmp + " && ls -la",
  "test -f PLAN.md",
  "git -C . status --short",
  "git branch --show-current",
  "git remote -v",
  "git tag --list",
  "git worktree list",
]) {
  const readOnlyAllowed = mod.planMutationGuardDecision({
    cwd: tmp,
    toolName: "bash",
    input: { command },
  });
  if (readOnlyAllowed != null) {
    console.error("proven read-only Bash must be allowed under DRAFT: " + command);
    process.exit(1);
  }
}

for (const command of [
  "cd " + tmp + " && touch escaped",
  "git branch stale-branch",
  "git branch -D stale-branch",
  "git remote remove origin",
  "git tag -d v0",
  "git worktree remove ../stale",
  "node -p \"require('node:fs').writeFileSync('escaped', 'x')\"",
  "sort -o escaped input.txt",
  "sort -ro escaped input.txt",
  "sort --compress-program=sh input.txt",
  "diff --output=escaped a b",
  "sed -ni '' 's/x/y/' input.txt",
  "sed -n 'w escaped' input.txt",
  "find . -fprintf escaped x",
  "find . '-exec' touch escaped ';'",
  "find . -fprint0 escaped",
]) {
  const mutationDeny = mod.planMutationGuardDecision({
    cwd: tmp,
    toolName: "bash",
    input: { command },
  });
  if (mutationDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
    console.error("write-capable command must be denied under DRAFT: " + command);
    process.exit(1);
  }
}

const quotedSubstitution = "rg \"" + String.fromCharCode(36) + "(touch escaped)\" docs";
const quotedSubstitutionDeny = mod.planMutationGuardDecision({
  cwd: tmp,
  toolName: "bash",
  input: { command: quotedSubstitution },
});
if (quotedSubstitutionDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("quoted command substitution must be denied under DRAFT");
  process.exit(1);
}

const bashDeny = mod.planMutationGuardDecision({
  cwd: tmp,
  toolName: "bash",
  input: { command: "echo hi > out.txt" },
});
if (bashDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("mutating bash under DRAFT must deny");
  process.exit(1);
}

const validReadyPlan = [
  "# PLAN",
  "",
  "## Meta",
  "- Status: READY",
  "",
  "## Goal",
  "- Exercise the guard.",
  "## Workflow Contract",
  "- Route: implement",
  "- Role: implementer",
  "- Stop condition: fixture passes",
  "- Required evidence: smoke output",
  "## Acceptance Criteria",
  "- Guard permits valid READY work.",
  "## Scope",
  "- In: guard",
  "- Out: product",
  "## Facts And Assumptions",
  "- Observed: fixture",
  "- Assumptions: none",
  "## Requirement Trace",
  "- Request -> fixture state -> no material gap -> guard output",
  "## Steps",
  "1. Exercise the guard.",
  "## Checks",
  "- command: bash tests/a.sh",
  "- command: bash tests/b.sh",
  "## Risks",
  "- None.",
  "## Decision Log",
  "- 2026-09-17: use the documented no-template fallback shape.",
  "## Open Questions",
  "- None",
  "## Notes / Handoff",
  "- fallback fixture",
  "",
].join("\\n");
writeFileSync(join(tmp, "PLAN.md"), validReadyPlan);

for (const [slug, label, checks] of [
  ["manual", "plural Manual checks", "- Manual checks: inspect the rendered flow"],
  ["ui-browser", "plural UI/browser checks", "- UI/browser checks: exercise the browser flow"],
  ["colon-command", "plain command containing a colon", "npm run test:unit"],
  ["url-command", "plain URL check containing a colon", "curl https://example.test/health"],
  ["quoted-colon-command", "plain command containing colon text", "node -e 'console.log(\"Status: ok\")'"],
  ["header-colon-command", "listed command containing a header colon", "- curl -H 'Accept: application/json' https://example.test/health"],
  ["action-table", "Check and Expected action table", "| Check | Expected |\n| --- | --- |\n| npm test | exit 0 |"],
  ["action-table-no-outer-pipes", "Check and Expected action table without outer pipes", "Check | Expected\n--- | ---\nnpm test | exit 0"],
  ["successive-action-tables", "successive action tables recalculate Expected", "Owner | Notes\n--- | ---\nAlice | fixture\n\nID | Command | Expected\n--- | --- | ---\nC1 | npm test | exit 0"],
  ["id-action-table", "ID then Command action table", "| ID | Command | Expected |\n| --- | --- | --- |\n| C1 | npm run test:unit | exit 0 |"],
  ["env-colon-command", "environment-prefixed command containing a colon", "CI=1 npm run test:unit"],
  ["env-wrapper-command", "env-wrapped command", "env CI=1 npm run test:unit"],
  ["rtk-wrapper-command", "RTK-wrapped command", "rtk proxy npm run test:unit"],
  ["pipeline-command", "explicit command with a shell pipeline", "- command: npm run test:unit | tee unit.log"],
  ["plain-pipeline-command", "plain shell pipeline", "npm run test:unit | tee unit.log"],
  ["listed-pipeline-command", "listed shell pipeline", "- npm run test:unit | tee unit.log"],
  ["quoted-pipe-command", "explicit command with a quoted pipe", "- command: node -e 'console.log(\"a|b\")'"],
  ["escaped-pipe-table", "action table with an escaped pipe", "| Check | Expected |\n| --- | --- |\n| printf 'a\\\\|b' | exit 0 |"],
  ["fenced-literal-expected", "fenced check containing literal expected metadata", String.fromCharCode(96).repeat(3) + "sh\npython3 - <<'PY'\nrecord = '- expected: pending'\nassert record\nPY\n" + String.fromCharCode(96).repeat(3)],
  ["indented-literal-expected", "indented check containing literal expected metadata", "    python3 - <<'PY'\n    record = '- expected: pending'\n    assert record\n    PY"],
  ["balanced-link-command", "linked command with balanced destination", "[npm test](https://example.test/a_(b))"],
  ["inline-html-expected", "inline code expected value resembling HTML", "- command: printf '<ok/>" + String.fromCharCode(92) + "n'\n  - expected: " + String.fromCharCode(96) + "<ok/>" + String.fromCharCode(96)],
  ["command-html-text-continuation", "raw HTML-like command text followed by prose", "- command: printf '<span>'\n  Expected: pass"],
  ["compact-nested-command-html", "compact nested command with HTML-like shell text", "- - command: printf '<span>'"],
  ["compact-nested-command-html-crlf", "compact nested command with HTML-like shell text under CRLF", "- - command: printf '<span>'\r\n"],
  ["compact-quoted-command-html", "compact quoted command with HTML-like shell text", "> - command: printf '<span>'"],
]) {
  const supportedCheckRoot = join(tmp, slug);
  mkdirSync(supportedCheckRoot);
  const supportedCheckPlan = validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", checks);
  writeFileSync(join(supportedCheckRoot, "PLAN.md"), supportedCheckPlan);
  const supportedCheckAllow = mod.planMutationGuardDecision({
    cwd: supportedCheckRoot,
    tool_name: "Write",
    tool_input: { file_path: join(supportedCheckRoot, "supported-check.ts"), content: "x" },
  });
  if (supportedCheckAllow != null) {
    console.error(label + " must be accepted as a sole actionable validation check: " + JSON.stringify({ supportedCheckAllow, readiness: evaluateReadyPlan(supportedCheckPlan) }));
    process.exit(1);
  }
}
for (const [slug, label, plan] of [
  ["risk-none", "full-template Risk: None", validReadyPlan.replace("- None.\n## Decision Log", "- Risk: None\n## Decision Log")],
  ["gap-none", "Requirement Trace Gap: None", validReadyPlan.replace(
    "- Request -> fixture state -> no material gap -> guard output",
    "| Requirement / source | Observed state | Gap / ambiguity | Decision | Step / expected evidence |\n|---|---|---|---|---|\n| User requirement | Existing guard implements requirement | None | Preserve existing behavior | npm test |",
  )],
  ["visible-balanced-link-goal", "balanced link with visible goal text", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard](https://example.test/a_(b))")],
  ["link-title-html-text", "HTML-like text in a link title is not active HTML", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard](https://example.test \"<span>\")")],
  ["leading-space-link-title-html-text", "leading space before a destination remains valid", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard]( https://example.test \"title <span>literal</span>\")")],
  ["leading-newline-link-title-html-text", "leading newline before a destination remains valid", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard](\n  https://example.test \"title <span>literal</span>\")")],
  ["leading-space-angle-link-title-html-text", "leading space before an angle destination remains valid", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard]( <https://example.test> \"title <span>literal</span>\")")],
  ["leading-crlf-angle-link-title-html-text", "leading CRLF before an angle destination remains valid", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard](\r\n  <https://example.test> \"title <span>literal</span>\")")],
  ["escaped-parenthesized-link-title", "escaped parentheses in a parenthesized title remain valid", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard](https://example.test (title " + String.fromCharCode(92) + "(escaped" + String.fromCharCode(92) + ") <span>literal</span>))")],
  ["bare-destination-angle-text", "angle-like text in a bare destination remains valid", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard](https://example.test<span>)")],
  ["resolved-html-reference-label", "HTML-like text in a resolved reference label is not active HTML", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][<span>]\n\n[<span>]: https://example.test \"title\"")],
  ["heading-adjacent-reference-definition", "a definition may start after an ATX heading", validReadyPlan.replace("- Exercise the guard.", "[<span>]: https://example.test\n[Exercise guard][<span>]")],
  ["reference-label-999-lf", "a 999-character reference label remains a valid invisible definition", validReadyPlan.replace("- Exercise the guard.", "[" + "a".repeat(993) + "<span>]: /url\n- Exercise the guard.")],
  ["reference-label-999-crlf", "a 999-character reference label remains valid with CRLF", validReadyPlan.replace("- Exercise the guard.", "[" + "a".repeat(993) + "<span>]: /url\n- Exercise the guard.").replace(/\n/g, "\r\n")],
  ["blockquote-reference-definition-lf", "a blockquote-contained reference definition resolves globally", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][<span>]\n\n> [<span>]: /url")],
  ["blockquote-reference-definition-crlf", "a blockquote-contained reference definition resolves with CRLF", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][<span>]\n\n> [<span>]: /url").replace(/\n/g, "\r\n")],
  ["list-reference-definition-lf", "a list-contained reference definition resolves globally", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][<span>]\n\n- [<span>]: /url")],
  ["list-reference-definition-crlf", "a list-contained reference definition resolves with CRLF", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][<span>]\n\n- [<span>]: /url").replace(/\n/g, "\r\n")],
  ["unicode-fold-sharp-s", "reference labels apply Unicode folding for sharp s", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][<span>STRASSE</span>]\n\n[<span>straße</span>]: /url")],
  ["unicode-fold-final-sigma", "reference labels apply Unicode folding for final sigma", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][<span>Σ</span>]\n\n[<span>ς</span>]: /url")],
  ["unicode-fold-kelvin", "reference labels apply Unicode folding for Kelvin sign", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][<span>K</span>]\n\n[<span>k</span>]: /url")],
  ["unicode-fold-capital-sharp-s", "reference labels apply full Unicode folding for capital sharp s", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][<span>ẞ</span>]\n\n[<span>ss</span>]: /url")],
  ["blockquote-multiline-destination-lf", "a blockquote definition may continue its destination", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][<span>]\n\n> [<span>]:\n> /url")],
  ["blockquote-multiline-destination-crlf", "a blockquote definition may continue its destination with CRLF", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][<span>]\n\n> [<span>]:\n> /url").replace(/\n/g, "\r\n")],
  ["list-multiline-destination-lf", "a list definition may continue its destination", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][<span>]\n\n- [<span>]:\n  /url")],
  ["list-multiline-title-crlf", "a list definition may continue its title with CRLF", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][<span>]\n\n- [<span>]: /url\n  \"title\"").replace(/\n/g, "\r\n")],
  ["blockquote-empty-boundary-definition", "a definition may follow an empty blockquote line", validReadyPlan.replace("- Exercise the guard.", ">\n> [<span>]: /url\n\n[Exercise guard][<span>]")],
  ["blockquote-heading-boundary-definition", "a definition may follow a blockquote heading", validReadyPlan.replace("- Exercise the guard.", "> # heading\n> [<span>]: /url\n\n[Exercise guard][<span>]")],
  ["blockquote-heading-boundary-definition-crlf", "a definition may follow a blockquote heading with CRLF", validReadyPlan.replace("- Exercise the guard.", "> # heading\n> [<span>]: /url\n\n[Exercise guard][<span>]").replace(/\n/g, "\r\n")],
  ["tab-indented-list-definition", "a tab after a bullet starts valid list content", validReadyPlan.replace("- Exercise the guard.", "-\t[<span>]: /url\n\n[Exercise guard][<span>]")],
  ["ordered-following-item-definition", "a later ordered item may contain a definition", validReadyPlan.replace("- Exercise the guard.", "1. prefix\n2. [<span>]: /url\n\n[Exercise guard][<span>]")],
  ["ordered-item-after-lazy-continuation", "an active ordered list survives a lazy continuation", validReadyPlan.replace("- Exercise the guard.", "1. prefix\n   continued\n2. [<span>]: /url\n\n[Exercise guard][<span>]")],
  ["nested-ordered-definition-same-parent", "a nested ordered list remains active within one parent item", validReadyPlan.replace("- Exercise the guard.", "1. prefix\n   1. nested\n   2. [<span>]: /url\n\n[Exercise guard][<span>]")],
  ["wide-parent-nested-ordered-definition-lf", "a nested definition follows the five-column content indent of a wide parent marker", validReadyPlan.replace("- Exercise the guard.", "100. parent\n     1. [<span>]: /url\n\n[Exercise guard][<span>]")],
  ["wide-parent-nested-ordered-definition-crlf", "a nested definition follows the five-column content indent of a wide parent marker with CRLF", validReadyPlan.replace("- Exercise the guard.", "100. parent\n     1. [<span>]: /url\n\n[Exercise guard][<span>]").replace(/\n/g, "\r\n")],
  ["tab-parent-nested-ordered-definition-lf", "a tab-indented nested definition remains inside its parent list item", validReadyPlan.replace("- Exercise the guard.", "1. parent\n\t1. [<span>]: /url\n\n[Exercise guard][<span>]")],
  ["tab-parent-nested-ordered-definition-crlf", "a tab-indented nested definition remains inside its parent list item with CRLF", validReadyPlan.replace("- Exercise the guard.", "1. parent\n\t1. [<span>]: /url\n\n[Exercise guard][<span>]").replace(/\n/g, "\r\n")],
  ["comment-before-reference-definition-lf", "a closed HTML comment does not block the following active definition", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][<span>]\n\n<!-- note -->\n[<span>]: /url")],
  ["comment-before-reference-definition-crlf", "a closed HTML comment does not block the following active definition with CRLF", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][<span>]\n\n<!-- note -->\n[<span>]: /url").replace(/\n/g, "\r\n")],
  ["quote-list-lazy-continuation-definition-lf", "a blockquote list survives a simple quote continuation", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][<span>]\n\n> 1. item\n> continued\n> 2. [<span>]: /url")],
  ["quote-list-lazy-continuation-definition-crlf", "a blockquote list survives a simple quote continuation with CRLF", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][<span>]\n\n> 1. item\n> continued\n> 2. [<span>]: /url").replace(/\n/g, "\r\n")],
  ["quote-list-indented-continuation-definition-lf", "a blockquote list survives an indented quote continuation", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][<span>]\n\n> 1. item\n>   continued\n> 2. [<span>]: /url")],
  ["quote-list-indented-continuation-definition-crlf", "a blockquote list survives an indented quote continuation with CRLF", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][<span>]\n\n> 1. item\n>   continued\n> 2. [<span>]: /url").replace(/\n/g, "\r\n")],
  ["quote-list-tab-continuation-definition-lf", "a blockquote list survives a tabbed quote continuation", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][<span>]\n\n> 1. item\n>\tcontinued\n> 2. [<span>]: /url")],
  ["quote-list-tab-continuation-definition-crlf", "a blockquote list survives a tabbed quote continuation with CRLF", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][<span>]\n\n> 1. item\n>\tcontinued\n> 2. [<span>]: /url").replace(/\n/g, "\r\n")],
  ["list-nested-quote-preserves-parent-lf", "a quote nested inside a list preserves its parent ordered context", validReadyPlan.replace("- Exercise the guard.", "1. parent\n   > quote\n   2. [<span>]: /url\n\n[Exercise guard][<span>]")],
  ["list-nested-quote-preserves-parent-crlf", "a quote nested inside a list preserves its parent ordered context with CRLF", validReadyPlan.replace("- Exercise the guard.", "1. parent\n   > quote\n   2. [<span>]: /url\n\n[Exercise guard][<span>]").replace(/\n/g, "\r\n")],
  ["compact-list-quote-preserves-parent-lf", "a compact quote inside a list preserves its parent ordered context", validReadyPlan.replace("- Exercise the guard.", "1. > quote\n   2. [<span>]: /url\n\n[Exercise guard][<span>]")],
  ["compact-list-quote-preserves-parent-crlf", "a compact quote inside a list preserves its parent ordered context with CRLF", validReadyPlan.replace("- Exercise the guard.", "1. > quote\n   2. [<span>]: /url\n\n[Exercise guard][<span>]").replace(/\n/g, "\r\n")],
  ["root-quote-boundary-opens-ordered-two-lf", "a root blockquote boundary permits a following ordered list starting at two", validReadyPlan.replace("- Exercise the guard.", "1. item\n> quote\n2. [<span>]: /url\n\n[Exercise guard][<span>]")],
  ["root-quote-boundary-opens-ordered-two-crlf", "a root blockquote boundary permits a following ordered list starting at two with CRLF", validReadyPlan.replace("- Exercise the guard.", "1. item\n> quote\n2. [<span>]: /url\n\n[Exercise guard][<span>]").replace(/\n/g, "\r\n")],
  ["nested-quote-boundary-opens-ordered-two-lf", "a nested blockquote boundary permits the parent quote list to resume at two", validReadyPlan.replace("- Exercise the guard.", "> 1. item\n>> quote\n> 2. [<span>]: /url\n\n[Exercise guard][<span>]")],
  ["nested-quote-boundary-opens-ordered-two-crlf", "a nested blockquote boundary permits the parent quote list to resume at two with CRLF", validReadyPlan.replace("- Exercise the guard.", "> 1. item\n>> quote\n> 2. [<span>]: /url\n\n[Exercise guard][<span>]").replace(/\n/g, "\r\n")],
  ["multiline-link-title-html-text", "HTML-like text in a multiline link title is not active HTML", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard](https://example.test\n  \"<span>\")")],
  ["reference-title-html-text", "HTML-like text in a reference title is not active HTML", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][doc]\n\n[doc]: https://example.test \"<span>\"")],
  ["multiline-reference-title-html-text", "HTML-like text in a multiline reference title is not active HTML", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][doc]\n\n[doc]: https://example.test\n  \"<span>\"")],
  ["wrapped-reference-title-html-text", "HTML-like text in a wrapped reference title is not active HTML", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][doc]\n\n[doc]: https://example.test \"title\n  <span>\n  rest\"")],
  ["next-line-reference-destination-html-text", "HTML-like text after a next-line reference destination is not active HTML", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard][doc]\n\n[doc]:\n  https://example.test \"<span>\"")],
  ["visible-autolink-goal", "URI autolink with visible goal text", validReadyPlan.replace("- Exercise the guard.", "<https://example.test/issue/42>")],
  ["visible-autolink-trace", "URI autolink in Requirement Trace", validReadyPlan.replace("- Request -> fixture state -> no material gap -> guard output", "<https://example.test/issue/42> -> observed state -> no material gap -> evidence")],
  ["documentary-status-entity", "documentary Status entity in Observed value", validReadyPlan.replace("- Observed: fixture", "- Observed: Status&nbsp;: is the previous metadata spelling")],
  ["no-material-gap", "standalone no-material-gap disposition", validReadyPlan.replace(
    "- Request -> fixture state -> no material gap -> guard output",
    "- No material gaps.",
  )],
  ["custom-trace-header", "custom Requirement Trace headers with a data row", validReadyPlan.replace(
    "- Request -> fixture state -> no material gap -> guard output",
    "| Requirement | Actual behavior | Gap | Choice | Proof |\n|---|---|---|---|---|\n| User request | Guard exists | None | Preserve | npm test |",
  )],
  ["trace-data-header-words", "Requirement Trace data containing header words", validReadyPlan.replace(
    "- Request -> fixture state -> no material gap -> guard output",
    "| Source | Observed | Gap | Decision | Evidence |\n|---|---|---|---|---|\n| User requirement | Actual state misses validation | Gap: missing negative fixture | Decision: add regression | Evidence: npm test |",
  )],
  ["titled-risk", "titled risk description", validReadyPlan.replace(
    "- None.\n## Decision Log",
    "- Race condition: concurrent writers may overwrite the snapshot.\n## Decision Log",
  )],
  ["double-escaped-colon-label", "a doubly escaped colon remains literal text", validReadyPlan.replace(
    "- Status: READY",
    "- Status" + String.fromCharCode(92).repeat(2) + ": literal label\n- Status: READY",
  )],
  ["encoded-entity-name-label", "an encoded entity name is decoded only once", validReadyPlan.replace(
    "- Status: READY",
    "- Status&amp;colon; literal label\n- Status: READY",
  )],
  ["encoded-numeric-entity-label", "a doubly encoded numeric entity is decoded only once", validReadyPlan.replace(
    "- Status: READY",
    "- Status&amp;#58; literal label\n- Status: READY",
  )],
  ["unresolved-commonmark-entity-label", "an entity unknown to CommonMark remains literal text", validReadyPlan.replace(
    "- Status: READY",
    "- Status&FourPerEmSpace;&colon; literal label\n- Status: READY",
  )],
]) {
  const supportedPlanRoot = join(tmp, slug);
  mkdirSync(supportedPlanRoot);
  writeFileSync(join(supportedPlanRoot, "PLAN.md"), plan);
  const supportedPlanAllow = mod.planMutationGuardDecision({
    cwd: supportedPlanRoot,
    tool_name: "Write",
    tool_input: { file_path: join(supportedPlanRoot, "supported-plan.ts"), content: "x" },
  });
  if (supportedPlanAllow != null) {
    console.error(label + " must satisfy the READY contract: " + JSON.stringify({ supportedPlanAllow, readiness: evaluateReadyPlan(plan) }));
    process.exit(1);
  }
}
writeFileSync(join(tmp, "PLAN.md"), validReadyPlan);

const tick = String.fromCharCode(96);
const commentedRequiredPlan = validReadyPlan
  .replace("- Exercise the guard.", "<!--\n- Exercise the guard.\n-->")
  .replace(
    "- Route: implement\n- Role: implementer\n- Stop condition: fixture passes\n- Required evidence: smoke output",
    "<!--\n- Route: implement\n- Role: implementer\n- Stop condition: fixture passes\n- Required evidence: smoke output\n-->",
  )
  .replace("- Guard permits valid READY work.", "<!--\n- Guard permits valid READY work.\n-->")
  .replace("- In: guard\n- Out: product", "<!--\n- In: guard\n- Out: product\n-->")
  .replace("- Observed: fixture\n- Assumptions: none", "<!--\n- Observed: fixture\n- Assumptions: none\n-->")
  .replace("- Request -> fixture state -> no material gap -> guard output", "<!--\n- Request -> fixture state -> no material gap -> guard output\n-->")
  .replace("1. Exercise the guard.", "<!--\n1. Exercise the guard.\n-->")
  .replace("- None.\n## Decision Log", "<!--\n- None.\n-->\n## Decision Log")
  .replace("## Open Questions\n- None", "## Open Questions\n<!--\n- None\n-->");

const fencedRequiredPlan = validReadyPlan
  .replace("- Exercise the guard.", tick.repeat(3) + "text\n- Exercise the guard.\n" + tick.repeat(3))
  .replace(
    "- Route: implement\n- Role: implementer\n- Stop condition: fixture passes\n- Required evidence: smoke output",
    tick.repeat(3) + "text\n- Route: implement\n- Role: implementer\n- Stop condition: fixture passes\n- Required evidence: smoke output\n" + tick.repeat(3),
  )
  .replace("- Guard permits valid READY work.", tick.repeat(3) + "text\n- Guard permits valid READY work.\n" + tick.repeat(3))
  .replace("- In: guard\n- Out: product", tick.repeat(3) + "text\n- In: guard\n- Out: product\n" + tick.repeat(3))
  .replace("- Observed: fixture\n- Assumptions: none", tick.repeat(3) + "text\n- Observed: fixture\n- Assumptions: none\n" + tick.repeat(3))
  .replace("- Request -> fixture state -> no material gap -> guard output", tick.repeat(3) + "text\n- Request -> fixture state -> no material gap -> guard output\n" + tick.repeat(3))
  .replace("1. Exercise the guard.", tick.repeat(3) + "text\n1. Exercise the guard.\n" + tick.repeat(3))
  .replace("- None.\n## Decision Log", tick.repeat(3) + "text\n- None.\n" + tick.repeat(3) + "\n## Decision Log")
  .replace("## Open Questions\n- None", "## Open Questions\n" + tick.repeat(3) + "text\n- None\n" + tick.repeat(3));

for (const [literalIndex, literalPlan] of [
  validReadyPlan.replace("- Exercise the guard.", "- Handle literal " + tick + "<!--" + tick + " markers correctly."),
  validReadyPlan.replace("- Exercise the guard.", "- Document " + tick + "- Status: CHALLENGED" + tick + " examples."),
  validReadyPlan.replace("- Route: implement", "- Route: " + tick + "implement" + tick),
  validReadyPlan
    .replace("- Route: implement", "+ Route: implement")
    .replace("- Role: implementer", "1. Role: implementer")
    .replace("- Stop condition: fixture passes", "* Stop condition: fixture passes")
    .replace("- Required evidence: smoke output", "2) Required evidence: smoke output"),
  validReadyPlan.replace("- command: bash tests/a.sh", "- command: " + tick + "rg -n '<!--' README.md" + tick),
  validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- command: " + tick + "npm test" + tick),
  validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", tick.repeat(3) + "bash\nnpm test\n" + tick.repeat(3)),
  validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "    npm test"),
  validReadyPlan.replace("- command: bash tests/a.sh", tick.repeat(3) + "bash\nrg -n '<!--' README.md\n" + tick.repeat(3)),
  validReadyPlan.replace("- command: bash tests/a.sh", tick.repeat(3) + "bash\n" + tick.repeat(3) + "not-a-close\nrg -n '<!--' README.md\n" + tick.repeat(3)),
  validReadyPlan.replace("## Scope\n- In: guard", "## Scope\n" + tick.repeat(3) + "markdown\n## Risks\n" + tick.repeat(3) + "\n- In: guard"),
].entries()) {
  writeFileSync(join(tmp, "PLAN.md"), literalPlan);
  const literalAllow = mod.planMutationGuardDecision({
    cwd: tmp,
    tool_name: "Write",
    tool_input: { file_path: join(tmp, "literal.ts"), content: "x" },
  });
  if (literalAllow != null) {
    console.error("literal HTML comment markers inside Markdown code must remain valid READY content: fixture " + literalIndex);
    process.exit(1);
  }
}
writeFileSync(join(tmp, "PLAN.md"), validReadyPlan);

const fallbackReadyAllow = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Write",
  tool_input: { file_path: join(tmp, "fallback-ready.ts"), content: "x" },
});
if (fallbackReadyAllow != null) {
  console.error("documented no-template fallback with Requirement Trace must satisfy the READY guard");
  process.exit(1);
}

writeFileSync(join(tmp, "PLAN.md"), validReadyPlan.replace(/## Requirement Trace[\s\S]*?(?=## Steps)/, ""));
const missingTraceDeny = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Write",
  tool_input: { file_path: join(tmp, "trace-missing.ts"), content: "x" },
});
if (missingTraceDeny?.hookSpecificOutput?.permissionDecision !== "deny" || !/Requirement Trace/.test(missingTraceDeny.hookSpecificOutput.permissionDecisionReason)) {
  console.error("READY plan without requirement trace must deny implementation writes");
  process.exit(1);
}
writeFileSync(join(tmp, "PLAN.md"), validReadyPlan);

const emptyTracePlan = validReadyPlan.replace(
  "- Request -> fixture state -> no material gap -> guard output",
  "| Requirement / source | Observed state | Gap / ambiguity | Decision | Step / expected evidence |\\n|---|---|---|---|---|\\n| | | | | |",
);
writeFileSync(join(tmp, "PLAN.md"), emptyTracePlan);
const emptyTraceDeny = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Write",
  tool_input: { file_path: join(tmp, "trace-empty.ts"), content: "x" },
});
if (emptyTraceDeny?.hookSpecificOutput?.permissionDecision !== "deny" || !/populated row/.test(emptyTraceDeny.hookSpecificOutput.permissionDecisionReason)) {
  console.error("READY plan with only the Requirement Trace table header must deny implementation writes");
  process.exit(1);
}

writeFileSync(join(tmp, "PLAN.md"), validReadyPlan.replace("## Open Questions\\n- None\\n", "## Open Questions\\n- None\\n- Which source wins?\\n"));
const contradictoryQuestionsDeny = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Write",
  tool_input: { file_path: join(tmp, "question-open.ts"), content: "x" },
});
if (contradictoryQuestionsDeny?.hookSpecificOutput?.permissionDecision !== "deny" || !/Open Questions/.test(contradictoryQuestionsDeny.hookSpecificOutput.permissionDecisionReason)) {
  console.error("READY plan with None plus an unresolved question must deny implementation writes");
  process.exit(1);
}
writeFileSync(join(tmp, "PLAN.md"), validReadyPlan);

for (const [label, brokenPlan] of [
  ["Route", validReadyPlan.replace("- Route: implement", "- Route:")],
  ["Role", validReadyPlan.replace("- Role: implementer", "- Role:")],
  ["Stop condition", validReadyPlan.replace("- Stop condition: fixture passes", "- Stop condition:")],
  ["Checks", validReadyPlan.replace(/- command: bash tests\/[ab]\.sh/g, "- command:")],
  ["Acceptance Criteria placeholder", validReadyPlan.replace("- Guard permits valid READY work.", "- [ ] ...")],
  ["Goal instructional placeholder", validReadyPlan.replace("- Exercise the guard.", "Describe in 1-3 sentences what will change and why it matters.")],
  ["Steps numbered placeholders", validReadyPlan.replace("1. Exercise the guard.", "1.\n2.\n3.")],
  ["Shortcut reference contradictory status", validReadyPlan.replace(
    "- Status: READY",
    "- [Status: CHALLENGED]\n\n[Status: CHALLENGED]: /url\n\n- Status: READY",
  )],
  ["Collapsed reference contradictory status", validReadyPlan.replace(
    "- Status: READY",
    "- [Status: CHALLENGED][]\n\n[Status: CHALLENGED]: /url\n\n- Status: READY",
  )],
  ["Unicode shortcut reference contradictory status", validReadyPlan.replace(
    "- Status: READY",
    "- [Status: CHALLENGED Σ]\n\n[status: challenged ς]: /url\n\n- Status: READY",
  )],
  ["Unicode collapsed reference contradictory status", validReadyPlan.replace(
    "- Status: READY",
    "- [Status: CHALLENGED Σ][]\n\n[status: challenged ς]: /url\n\n- Status: READY",
  )],
  ["Quoted canonical status", validReadyPlan.replace("- Status: READY", "> - Status: READY")],
  ["Nested-list canonical status", validReadyPlan.replace("- Status: READY", "1. - Status: READY")],
  ["Quoted nested-list canonical status", validReadyPlan.replace("- Status: READY", "- > - Status: READY")],
  ["Active HTML after a same-line comment", validReadyPlan.replace(
    "- Exercise the guard.",
    "<!-- note --><div hidden>\nExercise guard.",
  )],
  ["Active HTML after a comment in Status", validReadyPlan.replace(
    "- Status: READY",
    "<!-- note --><span>Status: READY</span>",
  )],
  ["Active HTML after a comment in Checks", validReadyPlan.replace(
    "- command: bash tests/a.sh",
    "- <!-- note --><span>npm test</span>",
  )],
  ["Active HTML after a comment in Expected", validReadyPlan.replace(
    "- command: bash tests/a.sh",
    "- command: bash tests/a.sh\n  - expected: <!-- note --><span>exit 0</span>",
  )],
  ["Active HTML below a command item", validReadyPlan.replace(
    "- command: bash tests/a.sh",
    "- command: bash tests/a.sh\n\n  <div hidden>",
  )],
  ["Active inline HTML on a command continuation", validReadyPlan.replace(
    "- command: bash tests/a.sh",
    "- command: printf '<span>'\n  Expected: <span>active</span>",
  )],
  ["Active HTML after multiline command code", validReadyPlan.replace(
    "- command: bash tests/a.sh",
    "- command: printf " + tick + "prefix <span>\n  close" + tick + "\n  <span>",
  )],
  ["Active HTML after multiline command code CRLF", validReadyPlan.replace(
    "- command: bash tests/a.sh",
    "- command: printf " + tick + "prefix <span>\n  close" + tick + "\n  <span>",
  ).replace(/\n/g, "\r\n")],
  ["Active HTML after multiline command link title", validReadyPlan.replace(
    "- command: bash tests/a.sh",
    "- command: echo [doc](https://example.test \"title <span>\n  end\")\n  <span>",
  )],
  ["Active HTML after multiline command link title CRLF", validReadyPlan.replace(
    "- command: bash tests/a.sh",
    "- command: echo [doc](https://example.test \"title <span>\n  end\")\n  <span>",
  ).replace(/\n/g, "\r\n")],
  ["Active HTML beside multiline command code close", validReadyPlan.replace(
    "- command: bash tests/a.sh",
    "- command: " + tick + "printf '<br>'\n  closes" + tick + " Expected: <br>",
  )],
  ["Active HTML beside multiline command code close CRLF", validReadyPlan.replace(
    "- command: bash tests/a.sh",
    "- command: " + tick + "printf '<br>'\n  closes" + tick + " Expected: <br>",
  ).replace(/\n/g, "\r\n")],
  ["Active HTML beside multiline command title close", validReadyPlan.replace(
    "- command: bash tests/a.sh",
    "- command: echo [doc](https://example.test 'title\n  closes') Expected: <br>",
  )],
  ["Active HTML beside multiline command title close CRLF", validReadyPlan.replace(
    "- command: bash tests/a.sh",
    "- command: echo [doc](https://example.test 'title\n  closes') Expected: <br>",
  ).replace(/\n/g, "\r\n")],
  ["Active HTML beside multiline command destination close", validReadyPlan.replace(
    "- command: bash tests/a.sh",
    "- command: echo [doc](\n  https://example.test)<span>",
  )],
  ["Active HTML after multiline command comment", validReadyPlan.replace(
    "- command: bash tests/a.sh",
    "- command: echo <!-- title\n  end --><span>",
  )],
  ["Non-interrupting ordered command text", validReadyPlan.replace(
    "- Exercise the guard.",
    "prefix\n22. command: <span>active</span>",
  )],
  ["Non-interrupting ordered command text CRLF", validReadyPlan.replace(
    "- Exercise the guard.",
    "prefix\n22. command: <span>active</span>",
  ).replace(/\n/g, "\r\n")],
  ["Non-interrupting nested ordered command text", validReadyPlan.replace(
    "- Exercise the guard.",
    "prefix\n22. - command: <span>active</span>",
  )],
  ["Non-interrupting nested ordered command text CRLF", validReadyPlan.replace(
    "- Exercise the guard.",
    "prefix\n22. - command: <span>active</span>",
  ).replace(/\n/g, "\r\n")],
  ["Comment opener interrupts a multiline code span", validReadyPlan.replace(
    "- Exercise the guard.",
    "- Handle " + tick + "code\n<!-- active comment\ncode" + tick + " correctly.",
  )],
  ["Required content inside comments", commentedRequiredPlan],
  ["Required content inside unterminated comment", validReadyPlan.replace("- Exercise the guard.", "<!--\n- Exercise the guard.")],
  ["Status inside comment", validReadyPlan.replace("- Status: READY", "<!--\n- Status: READY\n-->")],
  ["Status inside unterminated comment", validReadyPlan.replace("- Status: READY", "<!--\n- Status: READY")],
  ["Status after singly escaped comment opener", validReadyPlan.replace("- Status: READY", String.fromCharCode(92) + "<!--\n- **Status: CHALLENGED**\n-->\n- Status: READY")],
  ["Status after triply escaped comment opener", validReadyPlan.replace("- Status: READY", String.fromCharCode(92).repeat(3) + "<!--\n- **Status: CHALLENGED**\n-->\n- Status: READY")],
  ["Status inside fence", validReadyPlan.replace("- Status: READY", tick.repeat(3) + "markdown\n- Status: READY\n" + tick.repeat(3))],
  ["Fenced READY before real CHALLENGED", validReadyPlan.replace("- Status: READY", tick.repeat(3) + "markdown\n- Status: READY\n" + tick.repeat(3) + "\n- Status: CHALLENGED")],
  ["Entire plan inside fence", tick.repeat(3) + "markdown\n" + validReadyPlan + "\n" + tick.repeat(3)],
  ["Status inside multiline code span", validReadyPlan.replace("- Status: READY", tick + "\n- Status: READY\n" + tick)],
  ["Entire plan inside multiline code span", tick + "\n" + validReadyPlan + "\n" + tick],
  ["Status inside indented code block", validReadyPlan.replace("- Status: READY", "    - Status: READY\n- Status: CHALLENGED")],
  ["Status inside tab-indented code block", validReadyPlan.replace("- Status: READY", "\t- Status: READY\n- Status: CHALLENGED")],
  ["Unmatched backtick in prior paragraph", validReadyPlan.replace("- Status: READY", tick + " unmatched\n\n<!--\n- Status: READY\n-->\n- Status: CHALLENGED").replace("- Exercise the guard.", "- Exercise " + tick + "the guard" + tick + ".")],
  ["Standalone backticks across paragraphs", validReadyPlan.replace("- Status: READY", tick + "\n\n- Status: CHALLENGED\n\n" + tick + "\n\n- Status: READY")],
  ["Status with trailing inline code", validReadyPlan.replace("- Status: READY", "- Status: READY " + tick + "not approved" + tick)],
  ["Status value split by inline code", validReadyPlan.replace("- Status: READY", "- Status: " + tick + "NOT" + tick + " READY")],
  ["Status key split by inline code", validReadyPlan.replace("- Status: READY", "- Sta" + tick + "ignored" + tick + "tus: READY")],
  ["Malformed CHALLENGED before READY", validReadyPlan.replace("- Status: READY", "- Status: CHALLENGED (needs approval)\n- Status: READY")],
  ["Inline CHALLENGED before READY", validReadyPlan.replace("- Status: READY", "- Status: " + tick + "CHALLENGED" + tick + "\n- Status: READY")],
  ["Inline status key before READY", validReadyPlan.replace("- Status: READY", "- " + tick + "Status" + tick + ": CHALLENGED\n- Status: READY")],
  ["Plus CHALLENGED before READY", validReadyPlan.replace("- Status: READY", "+ Status: CHALLENGED\n- Status: READY")],
  ["Star CHALLENGED before READY", validReadyPlan.replace("- Status: READY", "* Status: CHALLENGED\n- Status: READY")],
  ["Ordered CHALLENGED before READY", validReadyPlan.replace("- Status: READY", "1. Status: CHALLENGED\n- Status: READY")],
  ["Task-list CHALLENGED before READY", validReadyPlan.replace("- Status: READY", "- [x] Status: CHALLENGED\n- Status: READY")],
  ["Emphasized CHALLENGED before READY", validReadyPlan.replace("- Status: READY", "- **Status:** CHALLENGED\n- Status: READY")],
  ["Fully bold CHALLENGED before READY", validReadyPlan.replace("- Status: READY", "- **Status: CHALLENGED**\n- Status: READY")],
  ["Fully italic CHALLENGED before READY", validReadyPlan.replace("- Status: READY", "- *Status: CHALLENGED*\n- Status: READY")],
  ["Combined-emphasis CHALLENGED before READY", validReadyPlan.replace("- Status: READY", "- ***Status:*** CHALLENGED\n- Status: READY")],
  ["Checks inline placeholder", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- command: " + tick + "<command>" + tick)],
  ["Checks inline empty placeholder", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- command: " + tick + " " + tick)],
  ["Checks multiline inline placeholder", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", tick + "\n<command>\n" + tick)],
  ["Checks multiline inline empty", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", tick + "\n \n" + tick)],
  ["Checks plus expected only", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "+ expected: exit 0")],
  ["Checks None placeholder", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- None")],
  ["Checks command placeholder prose", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- command: None / ...")],
  ["Checks TBD placeholder", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "TBD")],
  ["Checks TODO placeholder", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "TODO")],
  ["Checks pending command", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- command: pending")],
  ["Checks punctuated pending command", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- command: pending.")],
  ["Checks not-run command", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- command: not run")],
  ["Checks pending notes", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- Notes: pending")],
  ["Checks compact owner metadata", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- Owner:Alice")],
  ["Checks command-name metadata", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- npm: pending")],
  ["Checks review-owner metadata", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- Review owner: Alice")],
  ["Checks expected-output metadata", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- Expected output: exit 0")],
  ["Checks metadata table", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "| Owner | Evidence |\n| --- | --- |\n| Alice | report.md |")],
  ["Checks metadata table without outer pipes", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "Owner | Evidence\n--- | ---\nAlice | report.md")],
  ["Checks leaked table state", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "| Check | Expected |\n| --- | --- |\n- expected: exit 0\n| Owner | Evidence |")],
  ["Steps parenthesized placeholders", validReadyPlan.replace("1. Exercise the guard.", "1)\n2)\n3)")],
  ["Goal TBD placeholder", validReadyPlan.replace("- Exercise the guard.", "TBD")],
  ["Goal escaped TBD placeholder", validReadyPlan.replace("- Exercise the guard.", "TBD" + String.fromCharCode(92) + ".")],
  ["Goal zero-width placeholder", validReadyPlan.replace("- Exercise the guard.", "&#8203;")],
  ["Goal soft-hyphen placeholder", validReadyPlan.replace("- Exercise the guard.", "&#173;")],
  ["Goal named soft-hyphen placeholder", validReadyPlan.replace("- Exercise the guard.", "&shy;")],
  ["Goal named zero-width placeholder", validReadyPlan.replace("- Exercise the guard.", "&ZeroWidthSpace;")],
  ["Goal named no-break placeholder", validReadyPlan.replace("- Exercise the guard.", "&NoBreak;")],
  ["Goal template placeholder", validReadyPlan.replace("- Exercise the guard.", "<template>placeholder</template>")],
  ["Goal script placeholder", validReadyPlan.replace("- Exercise the guard.", "<script>placeholder</script>")],
  ["Goal hidden placeholder", validReadyPlan.replace("- Exercise the guard.", "<span hidden>placeholder</span>")],
  ["Goal title placeholder", validReadyPlan.replace("- Exercise the guard.", "<title>placeholder</title>")],
  ["Goal title slash placeholder", validReadyPlan.replace("- Exercise the guard.", "<title/>placeholder</title>")],
  ["Goal closed-dialog placeholder", validReadyPlan.replace("- Exercise the guard.", "<dialog>placeholder</dialog>")],
  ["Goal datalist placeholder", validReadyPlan.replace("- Exercise the guard.", "<datalist>placeholder</datalist>")],
  ["Goal hidden non-void slash placeholder", validReadyPlan.replace("- Exercise the guard.", "<span hidden/>placeholder</span>")],
  ["Goal hidden script child", validReadyPlan.replace("- Exercise the guard.", "<span hidden><script>\"</span>\"</script>hidden goal</span>")],
  ["Goal hidden style child", validReadyPlan.replace("- Exercise the guard.", "<span hidden><style>\"</span>\"</style>hidden goal</span>")],
  ["Goal hidden title child", validReadyPlan.replace("- Exercise the guard.", "<span hidden><title>\"</span>\"</title>hidden goal</span>")],
  ["Goal hidden textarea child", validReadyPlan.replace("- Exercise the guard.", "<span hidden><textarea></span></textarea>hidden goal</span>")],
  ["Goal processing instruction", validReadyPlan.replace("- Exercise the guard.", "<?ignored?>")],
  ["Goal declaration", validReadyPlan.replace("- Exercise the guard.", "<!DOCTYPE html>")],
  ["Goal CDATA", validReadyPlan.replace("- Exercise the guard.", "<![CDATA[placeholder]]>")],
  ["Goal labeled TBD placeholder", validReadyPlan.replace("- Exercise the guard.", "- Goal: TBD")],
  ["Goal emphasized TBD placeholder", validReadyPlan.replace("- Exercise the guard.", "- Goal: **TBD**")],
  ["Goal None placeholder", validReadyPlan.replace("- Exercise the guard.", "- None")],
  ["Goal empty block quote", validReadyPlan.replace("- Exercise the guard.", ">")],
  ["Goal compact nested block quote", validReadyPlan.replace("- Exercise the guard.", ">>")],
  ["Goal spaced nested block quote", validReadyPlan.replace("- Exercise the guard.", "> >")],
  ["Goal list-wrapped empty quote", validReadyPlan.replace("- Exercise the guard.", "- >")],
  ["Goal ordered-list-wrapped empty quote", validReadyPlan.replace("- Exercise the guard.", "1. >")],
  ["Goal quoted thematic break", validReadyPlan.replace("- Exercise the guard.", "> - - -")],
  ["Goal nested empty list", validReadyPlan.replace("- Exercise the guard.", "- -")],
  ["Goal empty inline-link label", validReadyPlan.replace("- Exercise the guard.", "[](#)")],
  ["Goal blank inline-link label", validReadyPlan.replace("- Exercise the guard.", "[ ](https://example.test)")],
  ["Goal empty reference-link label", validReadyPlan.replace("- Exercise the guard.", "[][empty-ref]").replace("## Notes / Handoff", "\n[empty-ref]: https://example.test\n\n## Notes / Handoff")],
  ["Goal empty balanced-destination link", validReadyPlan.replace("- Exercise the guard.", "[](https://example.test/a_(b))")],
  ["Goal emphasized empty link", validReadyPlan.replace("- Exercise the guard.", "*[](#)*")],
  ["Goal bold empty link", validReadyPlan.replace("- Exercise the guard.", "**[](#)**")],
  ["Goal empty angle-destination link", validReadyPlan.replace("- Exercise the guard.", "[](<https://example.test/a)>)")],
  ["Goal empty titled link", validReadyPlan.replace("- Exercise the guard.", "[](# \"title ) text\")")],
  ["Goal link definition only", validReadyPlan.replace("- Exercise the guard.", "[goal]: https://example.test")],
  ["Goal list-wrapped link definition", validReadyPlan.replace("- Exercise the guard.", "- [goal]: https://example.test")],
  ["Goal escaped-label link definition", validReadyPlan.replace("- Exercise the guard.", "[go\\\\]al]: https://example.test")],
  ["Goal empty HTML element", validReadyPlan.replace("- Exercise the guard.", "<span></span>")],
  ["Goal spaced dash thematic break", validReadyPlan.replace("- Exercise the guard.", "- - -")],
  ["Goal spaced star thematic break", validReadyPlan.replace("- Exercise the guard.", "* * *")],
  ["Goal spaced underscore thematic break", validReadyPlan.replace("- Exercise the guard.", "_ _ _")],
  ["Acceptance N/A placeholder", validReadyPlan.replace("- Guard permits valid READY work.", "- N/A")],
  ["Goal whole inline literal", validReadyPlan.replace("- Exercise the guard.", tick + "implement later" + tick)],
  ["Steps TODO placeholder", validReadyPlan.replace("1. Exercise the guard.", "TODO")],
  ["Steps None placeholder", validReadyPlan.replace("1. Exercise the guard.", "1. None")],
  ["Steps labeled pending placeholder", validReadyPlan.replace("1. Exercise the guard.", "1. Action: pending")],
  ["Scope labeled TODO placeholder", validReadyPlan.replace("- In: guard\n- Out: product", "- In: TODO")],
  ["Facts labeled not-set placeholder", validReadyPlan.replace("- Observed: fixture\n- Assumptions: none", "- Observed: not set")],
  ["Risks labeled pending placeholder", validReadyPlan.replace("- None.", "- Risk: pending")],
  ["Risks N/A placeholder", validReadyPlan.replace("- None.", "- N/A")],
  ["Risks arbitrary None field", validReadyPlan.replace("- None.", "- Owner: None")],
  ["Risks contradictory sentinel and pending", validReadyPlan.replace("- None.", "- Risk: None\n- Risk: pending")],
  ["Risks impact without description", validReadyPlan.replace("- None.", "- Risk:\n  - Impact: outage\n  - Mitigation: rollback")],
  ["Risks impact-area without description", validReadyPlan.replace("- None.", "- Impact area: all users")],
  ["Risks mitigation-plan without description", validReadyPlan.replace("- None.", "- Mitigation plan: rollback")],
  ["Risks risk-owner without description", validReadyPlan.replace("- None.", "- Risk owner: Alice")],
  ["Risks link definition only", validReadyPlan.replace("- None.", "[risk]: https://example.test")],
  ["Risks escaped-label link definition", validReadyPlan.replace("- None.", "[ri\\\\]sk]: https://example.test")],
  ["Route TBD placeholder", validReadyPlan.replace("- Route: implement", "- Route: TBD")],
  ["Route punctuated TBD placeholder", validReadyPlan.replace("- Route: implement", "- Route: TBD.")],
  ["Role TODO placeholder", validReadyPlan.replace("- Role: implementer", "- Role: TODO")],
  ["Stop condition pending placeholder", validReadyPlan.replace("- Stop condition: fixture passes", "- Stop condition: pending")],
  ["Required evidence not-set placeholder", validReadyPlan.replace("- Required evidence: smoke output", "- Required evidence: not set")],
  ["Route whole inline literal", validReadyPlan.replace("- Route: implement", tick + "- Route: implement" + tick)],
  ["Trace arrow placeholders", validReadyPlan.replace("- Request -> fixture state -> no material gap -> guard output", "TBD -> TODO -> pending -> not set")],
  ["Trace title-only content", validReadyPlan.replace("- Request -> fixture state -> no material gap -> guard output", "<title>Request -> observed -> no material gap -> evidence</title>")],
  ["Trace title-slash-only content", validReadyPlan.replace("- Request -> fixture state -> no material gap -> guard output", "<title/>Request -> observed -> no material gap -> evidence</title>")],
  ["Trace datalist-only content", validReadyPlan.replace("- Request -> fixture state -> no material gap -> guard output", "<datalist>Request -> observed -> no material gap -> evidence</datalist>")],
  ["Trace processing-instruction content", validReadyPlan.replace("- Request -> fixture state -> no material gap -> guard output", "<?ignored?>Request -> observed -> no material gap -> evidence")],
  ["Trace mixed placeholders with no-gap text", validReadyPlan.replace("- Request -> fixture state -> no material gap -> guard output", "TBD -> TODO -> no material gap -> pending")],
  ["Trace four arrow headers", validReadyPlan.replace("- Request -> fixture state -> no material gap -> guard output", "Requirement -> Observed -> Gap -> Evidence")],
  ["Trace five arrow headers", validReadyPlan.replace("- Request -> fixture state -> no material gap -> guard output", "Requirement -> Observed -> Gap -> Decision -> Evidence")],
  ["Trace interrogative no-gap text", validReadyPlan.replace("- Request -> fixture state -> no material gap -> guard output", "Are there no material gaps?")],
  ["Trace arrow None placeholders", validReadyPlan.replace("- Request -> fixture state -> no material gap -> guard output", "None -> None -> None -> None")],
  ["Trace table placeholders", validReadyPlan.replace("- Request -> fixture state -> no material gap -> guard output", "| Requirement / source | Observed state | Gap / ambiguity | Decision | Step / expected evidence |\n|---|---|---|---|---|\n| TBD | TBD | TBD | TBD | TBD |")],
  ["Trace table None placeholders", validReadyPlan.replace("- Request -> fixture state -> no material gap -> guard output", "| Requirement / source | Observed state | Gap / ambiguity | Decision | Step / expected evidence |\n|---|---|---|---|---|\n| None | None | None | None | None |")],
  ["Trace decorated header only", validReadyPlan.replace("- Request -> fixture state -> no material gap -> guard output", "| **Source** | **Observed state** | **Gap** | **Decision** | **Evidence** |\n| --- | --- | --- | --- | --- |")],
  ["Trace renamed header only", validReadyPlan.replace("- Request -> fixture state -> no material gap -> guard output", "| Requirement | Actual behavior | Gap | Choice | Proof |\n| --- | --- | --- | --- | --- |")],
  ["Trace canonical header without delimiter", validReadyPlan.replace("- Request -> fixture state -> no material gap -> guard output", "| Requirement / source | Observed state | Gap / ambiguity | Decision | Step / expected evidence |")],
  ["Trace common header without delimiter", validReadyPlan.replace("- Request -> fixture state -> no material gap -> guard output", "| Source | Current state | Gap | Decision | Evidence |")],
  ["Trace short header without delimiter", validReadyPlan.replace("- Request -> fixture state -> no material gap -> guard output", "| Requirement | Observed | Gap | Decision | Evidence |")],
  ["Trace repeated header as data", validReadyPlan.replace("- Request -> fixture state -> no material gap -> guard output", "| Source | Observed | Gap | Decision | Evidence |\n| --- | --- | --- | --- | --- |\n| Source | Observed | Gap | Decision | Evidence |")],
  ["Trace recased header as data", validReadyPlan.replace("- Request -> fixture state -> no material gap -> guard output", "| Source | Observed | Gap | Decision | Evidence |\n| --- | --- | --- | --- | --- |\n| source | observed | gap | decision | evidence |")],
  ["Trace synonymous header as data", validReadyPlan.replace("- Request -> fixture state -> no material gap -> guard output", "| Source | Observed | Gap | Decision | Evidence |\n| --- | --- | --- | --- | --- |\n| Requirement | Current state | Gap | Choice | Proof |")],
  ["Trace linked header as data", validReadyPlan.replace("- Request -> fixture state -> no material gap -> guard output", "| Source | Observed | Gap | Decision | Evidence |\n| --- | --- | --- | --- | --- |\n| [Requirement](#) | [Current state](#) | [Gap](#) | [Choice](#) | [Proof](#) |")],
  ["Trace escaped-pipe placeholders", validReadyPlan.replace("- Request -> fixture state -> no material gap -> guard output", "| Source | Observed state | Gap | Decision | Evidence |\n| --- | --- | --- | --- | --- |\n| User \\\\| issue | None | no material gap | implement | TBD |")],
  ["Status hidden across list items", validReadyPlan.replace("- Status: READY", "- Subject: Fix " + tick + " parser\n- Status: CHALLENGED\n- Source: " + tick + "ticket" + tick + "\n- Status: READY")],
  ["Linked contradictory status", validReadyPlan.replace("- Status: READY", "- [Status](#): CHALLENGED\n- Status: READY")],
  ["Escaped-colon contradictory status", validReadyPlan.replace("- Status: READY", "- Status" + String.fromCharCode(92) + ": CHALLENGED\n- Status: READY")],
  ["Bold zero-width contradictory status", validReadyPlan.replace("- Status: READY", "- **Status**&#8203;: CHALLENGED\n- Status: READY")],
  ["HTML zero-width contradictory status", validReadyPlan.replace("- Status: READY", "- <b>Status</b>&#8203;: CHALLENGED\n- Status: READY")],
  ["Linked zero-width contradictory status", validReadyPlan.replace("- Status: READY", "- [Status](#)&#8203;: CHALLENGED\n- Status: READY")],
  ["Task-list zero-width contradictory status", validReadyPlan.replace("- Status: READY", "- [x] Status&#8203;: CHALLENGED\n- Status: READY")],
  ["Encoded-letter zero-width contradictory status", validReadyPlan.replace("- Status: READY", "- Sta&#116;us&#8203;: CHALLENGED\n- Status: READY")],
  ["Numeric soft-hyphen contradictory status", validReadyPlan.replace("- Status: READY", "- Status&#173;: CHALLENGED\n- Status: READY")],
  ["Raw soft-hyphen contradictory status", validReadyPlan.replace("- Status: READY", "- Status" + String.fromCodePoint(0xad) + ": CHALLENGED\n- Status: READY")],
  ["Hex combining-grapheme contradictory status", validReadyPlan.replace("- Status: READY", "- Status&#x34F;: CHALLENGED\n- Status: READY")],
  ["Arabic-letter-mark contradictory status", validReadyPlan.replace("- Status: READY", "- Status&#1564;: CHALLENGED\n- Status: READY")],
  ["Named soft-hyphen contradictory status", validReadyPlan.replace("- Status: READY", "- Status&shy;: CHALLENGED\n- Status: READY")],
  ["Task-list soft-hyphen contradictory status", validReadyPlan.replace("- Status: READY", "- [x] Status&#173;: CHALLENGED\n- Status: READY")],
  ["Linked soft-hyphen contradictory status", validReadyPlan.replace("- Status: READY", "- [Status](#)&#173;: CHALLENGED\n- Status: READY")],
  ["HTML soft-hyphen contradictory status", validReadyPlan.replace("- Status: READY", "- <b>Status</b>&shy;: CHALLENGED\n- Status: READY")],
  ["Named zero-width contradictory status", validReadyPlan.replace("- Status: READY", "- Sta&ZeroWidthSpace;tus: CHALLENGED\n- Status: READY")],
  ["Task-list named zero-width contradictory status", validReadyPlan.replace("- Status: READY", "- [x] Sta&ZeroWidthSpace;tus: CHALLENGED\n- Status: READY")],
  ["Linked named zero-width contradictory status", validReadyPlan.replace("- Status: READY", "- [Sta&ZeroWidthSpace;tus](#): CHALLENGED\n- Status: READY")],
  ["HTML named zero-width contradictory status", validReadyPlan.replace("- Status: READY", "- <b>Sta&ZeroWidthSpace;tus</b>: CHALLENGED\n- Status: READY")],
  ["Named negative-space contradictory status", validReadyPlan.replace("- Status: READY", "- Sta&NegativeThinSpace;tus: CHALLENGED\n- Status: READY")],
  ["Template-prefixed contradictory status", validReadyPlan.replace("- Status: READY", "- <template>ignored</template>Status: CHALLENGED\n- Status: READY")],
  ["Hidden-prefixed contradictory status", validReadyPlan.replace("- Status: READY", "- <span hidden>ignored</span>Status: CHALLENGED\n- Status: READY")],
  ["Title-prefixed contradictory status", validReadyPlan.replace("- Status: READY", "- <title>ignored</title>Status: CHALLENGED\n- Status: READY")],
  ["Singly escaped hidden opener", validReadyPlan.replace("- Status: READY", String.fromCharCode(92) + "<span hidden>\n- **Status: CHALLENGED**\n</span>\n- Status: READY")],
  ["Singly escaped template opener", validReadyPlan.replace("- Status: READY", String.fromCharCode(92) + "<template>\n- **Status: CHALLENGED**\n</template>\n- Status: READY")],
  ["Hidden word in attribute value", validReadyPlan.replace("- Status: READY", "- <span title=\" hidden \">Status</span>: CHALLENGED\n- Status: READY")],
  ["Title slash-prefixed contradictory status", validReadyPlan.replace("- Status: READY", "- <title/>ignored</title>Status: CHALLENGED\n- Status: READY")],
  ["Closed-dialog-prefixed contradictory status", validReadyPlan.replace("- Status: READY", "- <dialog>ignored</dialog>Status: CHALLENGED\n- Status: READY")],
  ["Datalist-prefixed contradictory status", validReadyPlan.replace("- Status: READY", "- <datalist>ignored</datalist>Status: CHALLENGED\n- Status: READY")],
  ["Hidden input before contradictory status", validReadyPlan.replace("- Status: READY", "<input hidden>\n- **Status: CHALLENGED**\n</input>\n- Status: READY")],
  ["Script backslash-closing boundary", validReadyPlan.replace("- Status: READY", "<script>" + String.fromCharCode(92) + "</script>\n- **Status: CHALLENGED**\n</script>\n- Status: READY")],
  ["Script nested-text closing boundary", validReadyPlan.replace("- Status: READY", "<script>\"<script>\"</script>\n- **Status: CHALLENGED**\n</script>\n- Status: READY")],
  ["Hidden parent script child boundary", validReadyPlan.replace("- Status: READY", "<span hidden><script>\"<span>\"</script></span>\n- **Status: CHALLENGED**\n</span>\n- Status: READY")],
  ["Hidden parent style child boundary", validReadyPlan.replace("- Status: READY", "<span hidden><style>\"<span>\"</style></span>\n- **Status: CHALLENGED**\n</span>\n- Status: READY")],
  ["Hidden parent title child boundary", validReadyPlan.replace("- Status: READY", "<span hidden><title>\"<span>\"</title></span>\n- **Status: CHALLENGED**\n</span>\n- Status: READY")],
  ["Hidden parent textarea child boundary", validReadyPlan.replace("- Status: READY", "<span hidden><textarea><span></textarea></span>\n- **Status: CHALLENGED**\n</span>\n- Status: READY")],
  ["Processing-instruction contradictory status", validReadyPlan.replace("- Status: READY", "- <?ignored?>Status: CHALLENGED\n- Status: READY")],
  ["Declaration contradictory status", validReadyPlan.replace("- Status: READY", "- <!DOCTYPE html>Status: CHALLENGED\n- Status: READY")],
  ["CDATA contradictory status", validReadyPlan.replace("- Status: READY", "- <![CDATA[ignored]]>Status: CHALLENGED\n- Status: READY")],
  ["Command literal comment boundary", validReadyPlan.replace("- Status: READY", "- command: printf '<style>\"<!--\"</style>'\n- **Status: CHALLENGED**\n-->\n- Status: READY")],
  ["Commented command key literal boundary", validReadyPlan.replace("- Status: READY", "- com<!-- label -->mand: printf '<style>\"<!--\"</style>'\n- **Status: CHALLENGED**\n-->\n- Status: READY")],
  ["Comment before command literal boundary", validReadyPlan.replace("- Status: READY", "<!-- label -->- command: printf '<style>\"<!--\"</style>'\n- **Status: CHALLENGED**\n-->\n- Status: READY")],
  ["Link-title comment boundary", validReadyPlan.replace("- Status: READY", "- [doc](https://example.test \"<!--\")\n- Status: CHALLENGED\n-->\n- Status: READY")],
  ["Multiline link-title comment boundary", validReadyPlan.replace("- Status: READY", "- [doc](https://example.test\n  \"<!--\")\n- Status: CHALLENGED\n-->\n- Status: READY")],
  ["Reference-title comment boundary", validReadyPlan.replace("- Status: READY", "[doc]: https://example.test \"<!--\"\n- Status: CHALLENGED\n-->\n- Status: READY")],
  ["Multiline reference-title comment boundary", validReadyPlan.replace("- Status: READY", "[doc]: https://example.test\n  \"<!--\"\n- Status: CHALLENGED\n-->\n- Status: READY")],
  ["Two-line reference-title comment boundary", validReadyPlan.replace("- Status: READY", "[doc]: https://example.test \"title\nline <!--\"\n\n[doc]\n\n- Status: CHALLENGED\n-->\n- Status: READY")],
  ["Next-line reference destination comment boundary", validReadyPlan.replace("- Status: READY", "[doc]:\n  https://example.test \"<!--\"\n- Status: CHALLENGED\n-->\n- Status: READY")],
  ["Escaped reference-title block boundary", validReadyPlan.replace("- Status: READY", "[doc]: https://example.test \"title" + String.fromCharCode(92) + "\n- <span hidden>ignored</span>Status: CHALLENGED\nend\"\n- Status: READY")],
  ["CRLF escaped reference-title block boundary", validReadyPlan.replace("- Status: READY", "[doc]: https://example.test \"title" + String.fromCharCode(92) + "\r\n- <span hidden>ignored</span>Status: CHALLENGED\r\nend\"\r\n- Status: READY")],
  ["Escaped reference-title paragraph boundary", validReadyPlan.replace("- Status: READY", "[doc]: https://example.test \"title" + String.fromCharCode(92) + "\n\n<span hidden>ignored</span>Status: CHALLENGED\nend\"\n- Status: READY")],
  ["Separated link destination HTML", validReadyPlan.replace("- Exercise the guard.", "[Exercise guard]\n\n(https://example.test \"<template>hidden</template>\")")],
  ["Reference title thematic boundary HTML", validReadyPlan.replace("- Exercise the guard.", "[doc]: https://example.test \"title\n---\n<span>active</span>\"")],
  ["Reference title setext boundary HTML", validReadyPlan.replace("- Exercise the guard.", "[doc]: https://example.test \"title\n===\n<span>active</span>\"")],
  ["Reference title minimal dash setext boundary HTML", validReadyPlan.replace("- Exercise the guard.", "[doc]: https://example.test \"title\n-\n<span>active</span>\"")],
  ["Reference title double dash setext boundary HTML", validReadyPlan.replace("- Exercise the guard.", "[doc]: https://example.test \"title\n--\n<span>active</span>\"")],
  ["Reference title minimal equals setext boundary HTML", validReadyPlan.replace("- Exercise the guard.", "[doc]: https://example.test \"title\n=\n<span>active</span>\"")],
  ["CRLF reference title minimal dash setext boundary HTML", validReadyPlan.replace("- Exercise the guard.", "[doc]: https://example.test \"title\r\n-\r\n<span>active</span>\"")],
  ["CRLF reference title double dash setext boundary HTML", validReadyPlan.replace("- Exercise the guard.", "[doc]: https://example.test \"title\r\n--\r\n<span>active</span>\"")],
  ["CRLF reference title minimal equals setext boundary HTML", validReadyPlan.replace("- Exercise the guard.", "[doc]: https://example.test \"title\r\n=\r\n<span>active</span>\"")],
  ["Reference masking ASCII index parity", validReadyPlan.replace("- Status: READY", "ASCII prefix\n[doc]: https://example.test \"title\"\n- <i hidden>x</i>Status: CHALLENGED\n- Status: READY")],
  ["Reference masking UTF-16 index parity", validReadyPlan.replace("- Status: READY", "😀".repeat(15) + "\n[doc]: https://example.test \"title\"\n- <i hidden>x</i>Status: CHALLENGED\n- Status: READY")],
  ["Reference title empty ATX boundary in Goal", validReadyPlan.replace("- Exercise the guard.", "[doc]: https://example.test \"title\n#\n<span>active</span>\"")],
  ["CRLF reference title empty ATX boundary in Goal", validReadyPlan.replace("- Exercise the guard.", "[doc]: https://example.test \"title\r\n#\r\n<span>active</span>\"")],
  ["Reference title empty ATX boundary in Checks", validReadyPlan.replace("- command: bash tests/a.sh", "[doc]: https://example.test \"title\n##\n<span>active</span>\"\n- command: bash tests/a.sh")],
  ["Reference title empty ATX boundary in Expected", validReadyPlan.replace("- command: bash tests/a.sh", "- command: bash tests/a.sh\n  - expected: [doc]: https://example.test \"title\n###\n<span>active</span>\"")],
  ["Reference title empty ATX boundary before Status", validReadyPlan.replace("- Status: READY", "[doc]: https://example.test \"title\n######\n<span>active</span>\"\n- Status: READY")],
  ["Invalid reference title trailing HTML", validReadyPlan.replace("- Exercise the guard.", "[doc]: https://example.test \"title\" <span>active</span> \"tail\"")],
  ["Invalid inline title trailing HTML in Goal", validReadyPlan.replace("- Exercise the guard.", "[doc](https://example.test \"title\" <span>active</span> \"tail\")")],
  ["CRLF invalid inline title trailing HTML in Goal", validReadyPlan.replace("- Exercise the guard.", "[doc](https://example.test \"title\"\r\n<span>active</span> \"tail\")")],
  ["Invalid inline title trailing HTML in Checks", validReadyPlan.replace("- command: bash tests/a.sh", "[doc](https://example.test \"title\" <span>active</span> \"tail\")\n- command: bash tests/a.sh")],
  ["Invalid inline title trailing HTML in Expected", validReadyPlan.replace("- command: bash tests/a.sh", "- command: bash tests/a.sh\n  - expected: [doc](https://example.test \"title\" <span>active</span> \"tail\")")],
  ["Invalid inline title trailing HTML before Status", validReadyPlan.replace("- Status: READY", "[doc](https://example.test \"title\" <span>active</span> \"tail\")\n- Status: READY")],
  ["Invalid nested parenthesized inline title HTML", validReadyPlan.replace("- Exercise the guard.", "[doc](https://example.test (title (inner) <span>active</span>))")],
  ["Invalid directly nested parenthesized inline title HTML", validReadyPlan.replace("- Exercise the guard.", "[doc](https://example.test ((<span>active</span>)))")],
  ["CRLF invalid nested parenthesized inline title HTML", validReadyPlan.replace("- Exercise the guard.", "[doc](https://example.test (title\r\n(inner) <span>active</span>))")],
  ["Invalid multiline angle destination HTML", validReadyPlan.replace("- Exercise the guard.", "[doc](<https://example.test\n<span>)")],
  ["Invalid whitespace in balanced destination HTML", validReadyPlan.replace("- Exercise the guard.", "[doc](https://example.test/(a b<span>))")],
  ["Invalid escaped LF in bare destination HTML", validReadyPlan.replace("- Exercise the guard.", "[doc](https://example.test" + String.fromCharCode(92) + "\n<span>active</span>)")],
  ["Invalid escaped CRLF in bare destination HTML", validReadyPlan.replace("- Exercise the guard.", "[doc](https://example.test" + String.fromCharCode(92) + "\r\n<span>active</span>)")],
  ["Space-separated inline link HTML", validReadyPlan.replace("- Exercise the guard.", "[doc] (https://example.test \"<span>active</span>\")")],
  ["Newline-separated inline link HTML", validReadyPlan.replace("- Exercise the guard.", "[doc]\n(https://example.test \"<span>active</span>\")")],
  ["Unresolved adjacent reference HTML in Goal", validReadyPlan.replace("- Exercise the guard.", "[doc][<span>active</span>]")],
  ["Space-separated reference HTML in Goal", validReadyPlan.replace("- Exercise the guard.", "[doc] [<span>active</span>]")],
  ["LF-separated reference HTML in Goal", validReadyPlan.replace("- Exercise the guard.", "[doc]\n[<span>active</span>]")],
  ["CRLF-separated reference HTML in Goal", validReadyPlan.replace("- Exercise the guard.", "[doc]\r\n[<span>active</span>]")],
  ["Unresolved reference HTML in Checks", validReadyPlan.replace("- command: bash tests/a.sh", "[doc][<span>active</span>]\n- command: bash tests/a.sh")],
  ["Unresolved reference HTML in Expected", validReadyPlan.replace("- command: bash tests/a.sh", "- command: bash tests/a.sh\n  - expected: [doc][<span>active</span>]")],
  ["Unresolved reference HTML before Status", validReadyPlan.replace("- Status: READY", "[doc][<span>active</span>]\n- Status: READY")],
  ["Unresolved reference template bypass", validReadyPlan.replace("## Goal", "[open][<template>]\n## Goal").replace("## Appendix", "## Appendix\n[close][</template>]")],
  ["Entity-colliding unresolved reference HTML", validReadyPlan.replace("- Exercise the guard.", "[doc][<span>active</span>]\n\n[&lt;span&gt;active&lt;/span&gt;]: /url")],
  ["Escape-colliding unresolved reference HTML", validReadyPlan.replace("- Exercise the guard.", "[doc][<span>active</span>]\n\n[" + String.fromCharCode(92) + "<span" + String.fromCharCode(92) + ">active" + String.fromCharCode(92) + "</span" + String.fromCharCode(92) + ">]: /url")],
  ["Paragraph-interrupting pseudo-definition LF", validReadyPlan.replace("- Exercise the guard.", "prefix\n[<span>active</span>]: /url\n[doc][<span>active</span>]")],
  ["Paragraph-interrupting pseudo-definition CRLF", validReadyPlan.replace("- Exercise the guard.", "prefix\r\n[<span>active</span>]: /url\r\n[doc][<span>active</span>]")],
  ["Paragraph-interrupting pseudo-definition in Checks", validReadyPlan.replace("- command: bash tests/a.sh", "prefix\n[<span>active</span>]: /url\n- command: bash tests/a.sh")],
  ["Paragraph-interrupting pseudo-definition in Expected", validReadyPlan.replace("- command: bash tests/a.sh", "- command: bash tests/a.sh\n  - expected: prefix\n  continuation\n  [<span>active</span>]: /url")],
  ["Paragraph-interrupting pseudo-definition before Status", validReadyPlan.replace("- Status: READY", "prefix\n[<span>active</span>]: /url\n- Status: READY")],
  ["Reference title without separator", validReadyPlan.replace("- Exercise the guard.", "[<span>]: <https://example.test>\"title\"\n[doc][<span>]")],
  ["Reference label 1000 LF", validReadyPlan.replace("- Exercise the guard.", "[" + "a".repeat(994) + "<span>]: /url\n- Exercise the guard.")],
  ["Reference label 1000 CRLF", validReadyPlan.replace("- Exercise the guard.", "[" + "a".repeat(994) + "<span>]: /url\r\n- Exercise the guard.")],
  ["Lazy blockquote pseudo-definition LF", validReadyPlan.replace("- Exercise the guard.", "> prefix\n[<span>active</span>]: /url\n[doc][<span>active</span>]")],
  ["Lazy blockquote pseudo-definition CRLF", validReadyPlan.replace("- Exercise the guard.", "> prefix\r\n[<span>active</span>]: /url\r\n[doc][<span>active</span>]")],
  ["Lazy unordered-list pseudo-definition LF", validReadyPlan.replace("- Exercise the guard.", "- prefix\n[<span>active</span>]: /url\n[doc][<span>active</span>]")],
  ["Lazy unordered-list pseudo-definition CRLF", validReadyPlan.replace("- Exercise the guard.", "- prefix\r\n[<span>active</span>]: /url\r\n[doc][<span>active</span>]")],
  ["Lazy ordered-list pseudo-definition LF", validReadyPlan.replace("- Exercise the guard.", "1. prefix\n[<span>active</span>]: /url\n[doc][<span>active</span>]")],
  ["Lazy ordered-list pseudo-definition CRLF", validReadyPlan.replace("- Exercise the guard.", "1. prefix\r\n[<span>active</span>]: /url\r\n[doc][<span>active</span>]")],
  ["Explicit blockquote paragraph pseudo-definition LF", validReadyPlan.replace("- Exercise the guard.", "> prefix\n> [<span>active</span>]: /url\n> [doc][<span>active</span>]")],
  ["Explicit blockquote paragraph pseudo-definition CRLF", validReadyPlan.replace("- Exercise the guard.", "> prefix\r\n> [<span>active</span>]: /url\r\n> [doc][<span>active</span>]")],
  ["Noninterrupting ordered-two pseudo-definition LF", validReadyPlan.replace("- Exercise the guard.", "prefix\n2. [<span>active</span>]: /url\n[doc][<span>active</span>]")],
  ["Noninterrupting ordered-two pseudo-definition CRLF", validReadyPlan.replace("- Exercise the guard.", "prefix\r\n2. [<span>active</span>]: /url\r\n[doc][<span>active</span>]")],
  ["Invalid ten-digit ordered marker LF", validReadyPlan.replace("- Exercise the guard.", "1234567890. [<span>active</span>]: /url\n[doc][<span>active</span>]")],
  ["Invalid ten-digit ordered marker CRLF", validReadyPlan.replace("- Exercise the guard.", "1234567890. [<span>active</span>]: /url\r\n[doc][<span>active</span>]")],
  ["Invalid five-space bullet indent LF", validReadyPlan.replace("- Exercise the guard.", "-     [<span>active</span>]: /url\n[doc][<span>active</span>]")],
  ["Invalid five-space bullet indent CRLF", validReadyPlan.replace("- Exercise the guard.", "-     [<span>active</span>]: /url\r\n[doc][<span>active</span>]")],
  ["Dotless-i reference collision LF", validReadyPlan.replace("- Exercise the guard.", "[doc][<span>ı</span>]\n\n[<span>i</span>]: /url")],
  ["Dotless-i reference collision CRLF", validReadyPlan.replace("- Exercise the guard.", "[doc][<span>ı</span>]\r\n\r\n[<span>i</span>]: /url")],
  ["Blockquote title crosses empty quote line LF", validReadyPlan.replace("- Exercise the guard.", "> [doc]: /url \"title\n>\n> <span>active</span>\"")],
  ["Blockquote title crosses empty quote line CRLF", validReadyPlan.replace("- Exercise the guard.", "> [doc]: /url \"title\r\n>\r\n> <span>active</span>\"")],
  ["Blockquote title crosses quote depth LF", validReadyPlan.replace("- Exercise the guard.", "> [doc]: /url \"title\n>> <span>active</span>\"")],
  ["Blockquote lazy continuation before definition LF", validReadyPlan.replace("- Exercise the guard.", "> prefix\nlazy continuation\n> [<span>active</span>]: /url\n> [doc][<span>active</span>]")],
  ["Blockquote lazy continuation before definition CRLF", validReadyPlan.replace("- Exercise the guard.", "> prefix\r\nlazy continuation\r\n> [<span>active</span>]: /url\r\n> [doc][<span>active</span>]")],
  ["Root definition enters blockquote destination LF", validReadyPlan.replace("- Exercise the guard.", "[doc][<span>active</span>]\n\n[<span>active</span>]:\n> /url")],
  ["Root definition enters blockquote destination CRLF", validReadyPlan.replace("- Exercise the guard.", "[doc][<span>active</span>]\r\n\r\n[<span>active</span>]:\r\n> /url")],
  ["Root definition enters list destination", validReadyPlan.replace("- Exercise the guard.", "[doc][<span>active</span>]\n\n[<span>active</span>]:\n- /url")],
  ["Indented ordered pseudo-definition", validReadyPlan.replace("- Exercise the guard.", "1. prefix\n   2. [<span>active</span>]: /url\n\n[doc][<span>active</span>]")],
  ["False ordered chain LF", validReadyPlan.replace("- Exercise the guard.", "prefix\n2. filler\n3. [<span>active</span>]: /url\n[doc][<span>active</span>]")],
  ["False ordered chain CRLF", validReadyPlan.replace("- Exercise the guard.", "prefix\r\n2. filler\r\n3. [<span>active</span>]: /url\r\n[doc][<span>active</span>]")],
  ["False ordered chain under blockquote", validReadyPlan.replace("- Exercise the guard.", "> prefix\n> 2. filler\n> 3. [<span>active</span>]: /url\n> [doc][<span>active</span>]")],
  ["Invalid ordered parent cannot open child definition LF", validReadyPlan.replace("- Exercise the guard.", "prefix\n22. pseudo\n    1. [<span>active</span>]: /url\n[doc][<span>active</span>]")],
  ["Invalid ordered parent cannot open child definition CRLF", validReadyPlan.replace("- Exercise the guard.", "prefix\r\n22. pseudo\r\n    1. [<span>active</span>]: /url\r\n[doc][<span>active</span>]")],
  ["Reference definition hidden in closed comment LF", validReadyPlan.replace("- Exercise the guard.", "[doc][<span>active</span>]\n\n<!--\n\n[<span>active</span>]: /url\n\n-->")],
  ["Reference definition hidden in closed comment CRLF", validReadyPlan.replace("- Exercise the guard.", "[doc][<span>active</span>]\n\n<!--\n\n[<span>active</span>]: /url\n\n-->").replace(/\n/g, "\r\n")],
  ["Reference definition hidden in open comment LF", validReadyPlan.replace("- Exercise the guard.", "[doc][<span>active</span>]\n\n<!--\n\n[<span>active</span>]: /url")],
  ["Reference definition hidden in open comment CRLF", validReadyPlan.replace("- Exercise the guard.", "[doc][<span>active</span>]\n\n<!--\n\n[<span>active</span>]: /url").replace(/\n/g, "\r\n")],
  ["Wide-list reference definition hidden in comment LF", validReadyPlan.replace("- Exercise the guard.", "100. parent\n     <!--\n     1. [<span>active</span>]: /url\n     -->\n[doc][<span>active</span>]")],
  ["Wide-list reference definition hidden in comment CRLF", validReadyPlan.replace("- Exercise the guard.", "100. parent\n     <!--\n     1. [<span>active</span>]: /url\n     -->\n[doc][<span>active</span>]").replace(/\n/g, "\r\n")],
  ["Indented pseudo-heading cannot open ordered definition LF", validReadyPlan.replace("- Exercise the guard.", "prefix\n    # not heading\n2. [<span>active</span>]: /url\n[doc][<span>active</span>]")],
  ["Indented pseudo-heading cannot open ordered definition CRLF", validReadyPlan.replace("- Exercise the guard.", "prefix\n    # not heading\n2. [<span>active</span>]: /url\n[doc][<span>active</span>]").replace(/\n/g, "\r\n")],
  ["Indented pseudo-fence cannot open ordered definition LF", validReadyPlan.replace("- Exercise the guard.", "prefix\n    " + String.fromCharCode(96).repeat(3) + "not fence\n2. [<span>active</span>]: /url\n[doc][<span>active</span>]")],
  ["Indented pseudo-fence cannot open ordered definition CRLF", validReadyPlan.replace("- Exercise the guard.", "prefix\n    " + String.fromCharCode(96).repeat(3) + "not fence\n2. [<span>active</span>]: /url\n[doc][<span>active</span>]").replace(/\n/g, "\r\n")],
  ["Indented pseudo-HTML block cannot open ordered definition LF", validReadyPlan.replace("- Exercise the guard.", "prefix\n    <div>not block</div>\n2. [<span>active</span>]: /url\n[doc][<span>active</span>]")],
  ["Indented pseudo-HTML block cannot open ordered definition CRLF", validReadyPlan.replace("- Exercise the guard.", "prefix\n    <div>not block</div>\n2. [<span>active</span>]: /url\n[doc][<span>active</span>]").replace(/\n/g, "\r\n")],
  ["Inline code occupancy blocks paragraph definition LF", validReadyPlan.replace("- Exercise the guard.", String.fromCharCode(96) + "prefix" + String.fromCharCode(96) + "\n[<span>active</span>]: /url\n\n[doc][<span>active</span>]")],
  ["Inline code occupancy blocks paragraph definition CRLF", validReadyPlan.replace("- Exercise the guard.", String.fromCharCode(96) + "prefix" + String.fromCharCode(96) + "\n[<span>active</span>]: /url\n\n[doc][<span>active</span>]").replace(/\n/g, "\r\n")],
  ["Space-indented code comment cannot hide Status LF", validReadyPlan.replace("- Status: READY", "    <!--\n- Status: CHALLENGED\n-->\n- Status: READY")],
  ["Space-indented code comment cannot hide Status CRLF", validReadyPlan.replace("- Status: READY", "    <!--\n- Status: CHALLENGED\n-->\n- Status: READY").replace(/\n/g, "\r\n")],
  ["Tab-indented code comment cannot hide Status LF", validReadyPlan.replace("- Status: READY", "\t<!--\n- Status: CHALLENGED\n-->\n- Status: READY")],
  ["Tab-indented code comment cannot hide Status CRLF", validReadyPlan.replace("- Status: READY", "\t<!--\n- Status: CHALLENGED\n-->\n- Status: READY").replace(/\n/g, "\r\n")],
  ["Space-indented unmatched backtick cannot hide Status LF", validReadyPlan.replace("- Status: READY", "    " + String.fromCharCode(96) + "\n- Status: CHALLENGED\n" + String.fromCharCode(96) + "\n- Status: READY")],
  ["Space-indented unmatched backtick cannot hide Status CRLF", validReadyPlan.replace("- Status: READY", "    " + String.fromCharCode(96) + "\n- Status: CHALLENGED\n" + String.fromCharCode(96) + "\n- Status: READY").replace(/\n/g, "\r\n")],
  ["Tab-indented unmatched backtick cannot hide Status LF", validReadyPlan.replace("- Status: READY", "\t" + String.fromCharCode(96) + "\n- Status: CHALLENGED\n" + String.fromCharCode(96) + "\n- Status: READY")],
  ["Tab-indented unmatched backtick cannot hide Status CRLF", validReadyPlan.replace("- Status: READY", "\t" + String.fromCharCode(96) + "\n- Status: CHALLENGED\n" + String.fromCharCode(96) + "\n- Status: READY").replace(/\n/g, "\r\n")],
  ["List indentation plus four cannot open comment LF", validReadyPlan.replace("- Status: READY", "1. item\n       <!--\n- Status: CHALLENGED\n-->\n- Status: READY")],
  ["List indentation plus four cannot open comment CRLF", validReadyPlan.replace("- Status: READY", "1. item\n       <!--\n- Status: CHALLENGED\n-->\n- Status: READY").replace(/\n/g, "\r\n")],
  ["List tab plus spaces cannot open comment LF", validReadyPlan.replace("- Status: READY", "1. item\n\t   <!--\n- Status: CHALLENGED\n-->\n- Status: READY")],
  ["List tab plus spaces cannot open comment CRLF", validReadyPlan.replace("- Status: READY", "1. item\n\t   <!--\n- Status: CHALLENGED\n-->\n- Status: READY").replace(/\n/g, "\r\n")],
  ["Root quote closes list before space-indented comment LF", validReadyPlan.replace("- Status: READY", "1. item\n> quote\n    <!--\n- Status: CHALLENGED\n-->\n- Status: READY")],
  ["Root quote closes list before space-indented comment CRLF", validReadyPlan.replace("- Status: READY", "1. item\n> quote\n    <!--\n- Status: CHALLENGED\n-->\n- Status: READY").replace(/\n/g, "\r\n")],
  ["Root quote closes list before tab-indented comment LF", validReadyPlan.replace("- Status: READY", "1. item\n> quote\n\t<!--\n- Status: CHALLENGED\n-->\n- Status: READY")],
  ["Root quote closes list before tab-indented comment CRLF", validReadyPlan.replace("- Status: READY", "1. item\n> quote\n\t<!--\n- Status: CHALLENGED\n-->\n- Status: READY").replace(/\n/g, "\r\n")],
  ["List marker hidden in comment cannot activate space continuation LF", validReadyPlan.replace("- Status: READY", "<!--\n- prefix\n-->\n    <!--\n- Status: CHALLENGED\n-->\n- Status: READY")],
  ["List marker hidden in comment cannot activate space continuation CRLF", validReadyPlan.replace("- Status: READY", "<!--\n- prefix\n-->\n    <!--\n- Status: CHALLENGED\n-->\n- Status: READY").replace(/\n/g, "\r\n")],
  ["List marker hidden in comment cannot activate tab continuation LF", validReadyPlan.replace("- Status: READY", "<!--\n- prefix\n-->\n\t<!--\n- Status: CHALLENGED\n-->\n- Status: READY")],
  ["List marker hidden in comment cannot activate tab continuation CRLF", validReadyPlan.replace("- Status: READY", "<!--\n- prefix\n-->\n\t<!--\n- Status: CHALLENGED\n-->\n- Status: READY").replace(/\n/g, "\r\n")],
  ["Even-escaped comment opener leaves Status active", validReadyPlan.replace("- Status: READY", String.fromCharCode(92).repeat(2) + "<!--\n- Status: CHALLENGED\n-->\n- Status: READY")],
  ["Source control marker one collision", validReadyPlan.replace("- Exercise the guard.", String.fromCharCode(1) + "[<span>active</span>]: /url\n[doc][<span>active</span>]")],
  ["Source control marker two collision", validReadyPlan.replace("- Exercise the guard.", String.fromCharCode(2) + "[<span>active</span>]: /url\n[doc][<span>active</span>]")],
  ["Ordered state crosses thematic break LF", validReadyPlan.replace("- Exercise the guard.", "1. first\n---\nprefix\n2. [<span>active</span>]: /url\n[doc][<span>active</span>]")],
  ["Ordered state crosses thematic break CRLF", validReadyPlan.replace("- Exercise the guard.", "1. first\r\n---\r\nprefix\r\n2. [<span>active</span>]: /url\r\n[doc][<span>active</span>]")],
  ["Ordered state crosses quote thematic break", validReadyPlan.replace("- Exercise the guard.", "> 1. first\n> ---\n> prefix\n> 2. [<span>active</span>]: /url\n> [doc][<span>active</span>]")],
  ["Nested ordered state leaks to next parent", validReadyPlan.replace("- Exercise the guard.", "1. prefix\n   1. nested\n2. next\n   2. [<span>active</span>]: /url\n\n[doc][<span>active</span>]")],
  ["Empty ordered pseudo-list LF", validReadyPlan.replace("- Exercise the guard.", "prefix\n2. \n3. [<span>active</span>]: /url\n[doc][<span>active</span>]")],
  ["Empty ordered pseudo-list CRLF", validReadyPlan.replace("- Exercise the guard.", "prefix\r\n2. \r\n3. [<span>active</span>]: /url\r\n[doc][<span>active</span>]")],
  ["Empty ordered marker before root definition LF", validReadyPlan.replace("- Exercise the guard.", "prefix\n2. \n[<span>active</span>]: /url\n\n[doc][<span>active</span>]")],
  ["Empty ordered marker before root definition CRLF", validReadyPlan.replace("- Exercise the guard.", "prefix\r\n2. \r\n[<span>active</span>]: /url\r\n\r\n[doc][<span>active</span>]")],
  ["Empty plus pseudo-list", validReadyPlan.replace("- Exercise the guard.", "prefix\n+ \n2. [<span>active</span>]: /url\n[doc][<span>active</span>]")],
  ["Empty star pseudo-list", validReadyPlan.replace("- Exercise the guard.", "prefix\n* \n2. [<span>active</span>]: /url\n[doc][<span>active</span>]")],
  ["Plus list replaces ordered state LF", validReadyPlan.replace("- Exercise the guard.", "1. first\n+ \nprefix\n2. [<span>active</span>]: /url\n[doc][<span>active</span>]")],
  ["Plus list replaces ordered state CRLF", validReadyPlan.replace("- Exercise the guard.", "1. first\r\n+ \r\nprefix\r\n2. [<span>active</span>]: /url\r\n[doc][<span>active</span>]")],
  ["Star list replaces ordered state LF", validReadyPlan.replace("- Exercise the guard.", "1. first\n* \nprefix\n2. [<span>active</span>]: /url\n[doc][<span>active</span>]")],
  ["Star list replaces ordered state CRLF", validReadyPlan.replace("- Exercise the guard.", "1. first\r\n* \r\nprefix\r\n2. [<span>active</span>]: /url\r\n[doc][<span>active</span>]")],
  ["Nested plus list replaces nested ordered state", validReadyPlan.replace("- Exercise the guard.", "1. parent\n   1. nested\n   + \n   prefix\n   2. [<span>active</span>]: /url\n\n[doc][<span>active</span>]")],
  ["Nested star list replaces nested ordered state CRLF", validReadyPlan.replace("- Exercise the guard.", "1. parent\n   1. nested\n   * \n   prefix\n   2. [<span>active</span>]: /url\n\n[doc][<span>active</span>]").replace(/\n/g, "\r\n")],
  ["Reference title HTML block boundary", validReadyPlan.replace("- Exercise the guard.", "[doc]: https://example.test \"title\n<div>\nactive\n</div>\"")],
  ["CRLF reference title HTML block boundary", validReadyPlan.replace("- Exercise the guard.", "[doc]: https://example.test \"title\r\n<div>\r\nactive\r\n</div>\"")],
  ["Reference title HTML block boundary in Checks", validReadyPlan.replace("- command: bash tests/a.sh", "[doc]: https://example.test \"title\n<div>active</div>\"\n- command: bash tests/a.sh")],
  ["Reference title HTML block boundary in Expected", validReadyPlan.replace("- command: bash tests/a.sh", "- command: bash tests/a.sh\n  - expected: [doc]: https://example.test \"title\n<div>active</div>\"")],
  ["Reference title HTML block boundary before Status", validReadyPlan.replace("- Status: READY", "[doc]: https://example.test \"title\n<div>active</div>\"\n- Status: READY")],
  ["Reference title comment block boundary", validReadyPlan.replace("- Exercise the guard.", "[doc]: https://example.test \"title\n<!-- active -->\n<span>active</span>\"")],
  ["Reference title processing block boundary", validReadyPlan.replace("- Exercise the guard.", "[doc]: https://example.test \"title\n<?active?>\"")],
  ["Reference title declaration block boundary", validReadyPlan.replace("- Exercise the guard.", "[doc]: https://example.test \"title\n<!DOCTYPE html>\"")],
  ["Reference title CDATA block boundary", validReadyPlan.replace("- Exercise the guard.", "[doc]: https://example.test \"title\n<![CDATA[active]]>\"")],
  ["Reference title raw-text block boundary", validReadyPlan.replace("- Exercise the guard.", "[doc]: https://example.test \"title\n<script>active</script>\"")],
  ["Linked multiline contradictory status", validReadyPlan.replace("- Status: READY", "- [Status:\n  CHALLENGED](#)\n- Status: READY")],
  ["Linked titled contradictory status", validReadyPlan.replace("- Status: READY", "- [Status](# \"title ) text\"): CHALLENGED\n- Status: READY")],
  ["Unknown status before READY", validReadyPlan.replace("- Status: READY", "- Status: WAITING\n- Status: READY")],
  ["Empty status before READY", validReadyPlan.replace("- Status: READY", "- Status:\n- Status: READY")],
  ["HTML-wrapped contradictory status", validReadyPlan.replace("- Status: READY", "- <span>Status</span>: CHALLENGED\n- Status: READY")],
  ["Autolink contradictory status", validReadyPlan.replace("- Status: READY", "- <Status:CHALLENGED>\n- Status: READY")],
  ["Numeric-entity contradictory status", validReadyPlan.replace("- Status: READY", "- Sta&#x74;us: CHALLENGED\n- Status: READY")],
  ["Uppercase-hex entity contradictory status", validReadyPlan.replace("- Status: READY", "- Sta&#X74;us: CHALLENGED\n- Status: READY")],
  ["Named-entity contradictory status", validReadyPlan.replace("- Status: READY", "- Status&colon; CHALLENGED\n- Status: READY")],
  ["Named-space entity contradictory status", validReadyPlan.replace("- Status: READY", "- Status&ensp;: CHALLENGED\n- Status: READY")],
  ["Named ThinSpace entity contradictory status", validReadyPlan.replace("- Status: READY", "- Status&ThinSpace;: CHALLENGED\n- Status: READY")],
  ["Numeric zero-width entity contradictory status", validReadyPlan.replace("- Status: READY", "- Status&#8203;: CHALLENGED\n- Status: READY")],
  ["Hex zero-width entity contradictory status", validReadyPlan.replace("- Status: READY", "- Status&#x200B;: CHALLENGED\n- Status: READY")],
  ["Named-newline entity contradictory status", validReadyPlan.replace("- Status: READY", "- Status&NewLine;: CHALLENGED\n- Status: READY")],
  ["Numeric-newline entity contradictory status", validReadyPlan.replace("- Status: READY", "- Status&#10;: CHALLENGED\n- Status: READY")],
  ["Hex-newline entity contradictory status", validReadyPlan.replace("- Status: READY", "- Status&#xA;: CHALLENGED\n- Status: READY")],
  ["Invalid multiline HTML around contradictory status", validReadyPlan.replace("- Status: READY", "<a\n- **Status: CHALLENGED**\n>\n- Status: READY")],
  ["Valid multiline HTML around contradictory status", validReadyPlan.replace("- Status: READY", "- <span\n  title=\"x\">Status</span>: CHALLENGED\n- Status: READY")],
  ["Valid unindented multiline HTML around contradictory status", validReadyPlan.replace("- Status: READY", "- <span\ntitle=\"x\">Status</span>: CHALLENGED\n- Status: READY")],
  ["Invalid multiline link around contradictory status", validReadyPlan.replace("- Status: READY", "[example](\n\n- **Status: CHALLENGED**\n\n)\n- Status: READY")],
  ["Invalid link crossing list boundary", validReadyPlan.replace("- Status: READY", "[example](\n- **Status: CHALLENGED**\n)\n- Status: READY")],
  ["Invalid escaped-newline link crossing list boundary", validReadyPlan.replace("- Status: READY", "[example](\\\\\n- **Status: CHALLENGED**\n)\n- Status: READY")],
  ["Invalid reference crossing list boundary", validReadyPlan.replace("- Status: READY", "[example][\n- **Status: CHALLENGED**\n]\n- Status: READY")],
  ["Invalid named reference crossing list boundary", validReadyPlan.replace("- Status: READY", "[example][ref\n\n- **Status: CHALLENGED**\n]\n- Status: READY")],
  ["Invalid separated link destination", validReadyPlan.replace("- Status: READY", "[example]\n\n(\n- **Status: CHALLENGED**\n)\n- Status: READY")],
  ["Invalid separated reference destination", validReadyPlan.replace("- Status: READY", "[example]\n\n[ref]\n- **Status: CHALLENGED**\n- Status: READY")],
  ["Required bodies only inside fences", fencedRequiredPlan],
  ["Inline pending open question", validReadyPlan.replace("## Open Questions\n- None", "## Open Questions\n- None " + tick + "but approval is pending" + tick)],
  ["Inline question before None", validReadyPlan.replace("## Open Questions\n- None", "## Open Questions\n- " + tick + "Which source wins?" + tick + "\n- None")],
  ["Multiline inline pending question", validReadyPlan.replace("## Open Questions\n- None", "## Open Questions\n- None " + tick + "but approval\nis pending" + tick)],
  ["Multiline inline question before None", validReadyPlan.replace("## Open Questions\n- None", "## Open Questions\n- " + tick + "Which source\nwins?" + tick + "\n- None")],
  ["Whole inline None question", validReadyPlan.replace("## Open Questions\n- None", "## Open Questions\n" + tick + "- None" + tick)],
  ["Checks owner metadata", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- Owner: Alice")],
  ["Checks evidence metadata", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- Evidence: report.md")],
  ["Checks rationale metadata", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- Rationale: documented elsewhere")],
  ["Checks heading placeholder", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "### Automated\n- command:")],
  ["Checks expected-only placeholder", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- command:\n  - expected: exit 0")],
  ["Checks pending expected", validReadyPlan.replace("- command: bash tests/a.sh", "- command: bash tests/a.sh\n  - expected: pending")],
  ["Checks zero-width command", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- command: &#8203;")],
  ["Checks soft-hyphen action", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- &#173;")],
  ["Checks named zero-width action", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- &ZeroWidthSpace;")],
  ["Checks template action", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- <template>npm test</template>")],
  ["Checks title action", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- <title>npm test</title>")],
  ["Checks title-slash action", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- <title/>npm test</title>")],
  ["Checks closed-dialog action", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- <dialog>npm test</dialog>")],
  ["Checks datalist action", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- <datalist>npm test</datalist>")],
  ["Checks hidden textarea child action", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- <span hidden><textarea></span></textarea>npm test</span>")],
  ["Checks processing instruction", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- <?ignored?>npm test")],
  ["Checks escaped TBD expected", validReadyPlan.replace("- command: bash tests/a.sh", "- command: bash tests/a.sh\n  - expected: TBD" + String.fromCharCode(92) + ".")],
  ["Checks zero-width TBD expected", validReadyPlan.replace("- command: bash tests/a.sh", "- command: bash tests/a.sh\n  - expected: TBD&#8203;")],
  ["Checks soft-hyphen expected", validReadyPlan.replace("- command: bash tests/a.sh", "- command: bash tests/a.sh\n  - expected: &#173;")],
  ["Checks named zero-width expected", validReadyPlan.replace("- command: bash tests/a.sh", "- command: bash tests/a.sh\n  - expected: &ZeroWidthSpace;")],
  ["Checks template expected", validReadyPlan.replace("- command: bash tests/a.sh", "- command: bash tests/a.sh\n  - expected: <template>exit 0</template>")],
  ["Checks title expected", validReadyPlan.replace("- command: bash tests/a.sh", "- command: bash tests/a.sh\n  - expected: <title>exit 0</title>")],
  ["Checks title-slash expected", validReadyPlan.replace("- command: bash tests/a.sh", "- command: bash tests/a.sh\n  - expected: <title/>exit 0</title>")],
  ["Checks closed-dialog expected", validReadyPlan.replace("- command: bash tests/a.sh", "- command: bash tests/a.sh\n  - expected: <dialog>exit 0</dialog>")],
  ["Checks datalist expected", validReadyPlan.replace("- command: bash tests/a.sh", "- command: bash tests/a.sh\n  - expected: <datalist>exit 0</datalist>")],
  ["Checks hidden textarea child expected", validReadyPlan.replace("- command: bash tests/a.sh", "- command: bash tests/a.sh\n  - expected: <span hidden><textarea></span></textarea>exit 0</span>")],
  ["Checks processing-instruction expected", validReadyPlan.replace("- command: bash tests/a.sh", "- command: bash tests/a.sh\n  - expected: <?ignored?>exit 0")],
  ["Checks four-space pending expected", validReadyPlan.replace("- command: bash tests/a.sh", "- command: bash tests/a.sh\n    - expected: pending")],
  ["Checks tab pending expected", validReadyPlan.replace("- command: bash tests/a.sh", "- command: bash tests/a.sh\n\t- expected: pending")],
  ["Checks blank then two-space pending expected", validReadyPlan.replace("- command: bash tests/a.sh", "- command: bash tests/a.sh\n\n  - expected: pending")],
  ["Checks blank then four-space pending expected", validReadyPlan.replace("- command: bash tests/a.sh", "- command: bash tests/a.sh\n\n    - expected: pending")],
  ["Checks blank then tab pending expected", validReadyPlan.replace("- command: bash tests/a.sh", "- command: bash tests/a.sh\n\n\t- expected: pending")],
  ["Checks pipeline pending expected", validReadyPlan.replace("- command: bash tests/a.sh", "- command: npm test | tee test.log\n    - expected: pending")],
  ["Checks listed pipeline pending expected", validReadyPlan.replace("- command: bash tests/a.sh", "- npm test | tee test.log\n    - expected: pending")],
  ["Checks table pending expected", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "| Check | Expected |\n| --- | --- |\n| npm test | pending |")],
  ["Checks table pending expected without outer pipes", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "Check | Expected\n--- | ---\nnpm test | pending")],
  ["Checks second table pending after metadata table", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "Owner | Notes\n--- | ---\nAlice | fixture\n\nCheck | Expected\n--- | ---\nnpm test | pending")],
  ["Checks shifted Expected in second table", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "Check | Expected\n--- | ---\nnpm test | exit 0\n\nID | Command | Expected\n--- | --- | ---\nC1 | npm run test:unit | pending")],
  ["Checks pipeline table pending expected without outer pipes", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "Check | Expected\n--- | ---\nnpm test \\\\| tee test.log | pending")],
  ["Checks escaped-pipe pending expected", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "| Check | Expected |\n| --- | --- |\n| printf 'a\\\\|b' | pending |")],
  ["Checks linked Expected header with pending", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "| Check | [Expected](#) |\n| --- | --- |\n| npm test | pending |")],
  ["Checks empty fence", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", String.fromCharCode(96).repeat(3) + "bash\n" + String.fromCharCode(96).repeat(3))],
  ["Checks header-only table", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "| Check | Expected |\n| --- | --- |")],
  ["Checks composite header-only table", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "| Command | Expected result |\n| --- | --- |")],
  ["Checks header-only table without outer pipes", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "Check | Expected\n--- | ---")],
  ["Checks expected-only table row", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "| Check | Expected |\n| --- | --- |\n| | exit 0 |")],
  ["Checks horizontal rule", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "---")],
  ["Checks empty block quote", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", ">")],
  ["Checks compact nested block quote", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", ">>")],
  ["Checks spaced nested block quote", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "> >")],
  ["Checks list-wrapped empty quote", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- >")],
  ["Checks ordered-list-wrapped empty quote", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "1. >")],
  ["Checks quoted thematic break", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "> - - -")],
  ["Checks nested empty list", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- -")],
  ["Checks empty inline-link label", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "[](#)")],
  ["Checks blank inline-link label", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "[ ](https://example.test)")],
  ["Checks empty reference-link label", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "[][empty-ref]").replace("## Notes / Handoff", "\n[empty-ref]: https://example.test\n\n## Notes / Handoff")],
  ["Checks empty balanced-destination link", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "[](https://example.test/a_(b))")],
  ["Checks emphasized empty link", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "*[](#)*")],
  ["Checks bold empty link", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "**[](#)**")],
  ["Checks empty angle-destination link", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "[](<https://example.test/a)>)")],
  ["Checks empty titled link", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "[](# \"title ) text\")")],
  ["Checks escaped-label link definition", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "[ch\\\\]eck]: https://example.test")],
  ["Checks empty HTML element", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "<span></span>")],
  ["Checks spaced dash thematic break", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "- - -")],
  ["Checks spaced star thematic break", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "* * *")],
  ["Checks spaced underscore thematic break", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "_ _ _")],
  ["Checks multiline comment", validReadyPlan.replace("- command: bash tests/a.sh\n- command: bash tests/b.sh", "<!--\nChoose a command before READY.\n-->")],
]) {
  writeFileSync(join(tmp, "PLAN.md"), brokenPlan);
  const emptyFieldDeny = mod.planMutationGuardDecision({
    cwd: tmp,
    tool_name: "Write",
    tool_input: { file_path: join(tmp, "empty-field.ts"), content: "x" },
  });
  if (emptyFieldDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
    console.error("READY plan with empty " + label + " must deny implementation writes");
    process.exit(1);
  }
}
writeFileSync(join(tmp, "PLAN.md"), validReadyPlan);

const readyAllow = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Write",
  tool_input: { file_path: join(tmp, "z.ts"), content: "z" },
});
if (readyAllow != null) {
  console.error("READY must allow Write to non-plan files");
  process.exit(1);
}

writeFileSync(join(tmp, "PLAN.md"), "# PLAN\\n## Meta\\n- Status: READY\\n");
const incompleteReadyDeny = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Write",
  tool_input: { file_path: join(tmp, "z.ts"), content: "z" },
});
if (incompleteReadyDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("status-only READY must deny implementation writes");
  process.exit(1);
}
for (const command of [
  "git status --short",
  "cat PLAN.md",
  "scripts/plan-cleanup --discard stale-plan",
  "scripts/workflow-event append incomplete-ready blocked '{}'",
]) {
  const recoveryAllow = mod.planMutationGuardDecision({
    cwd: tmp,
    tool_name: "Bash",
    tool_input: { command },
  });
  if (recoveryAllow != null) {
    console.error("incomplete READY must allow diagnostic/recovery command: " + command);
    process.exit(1);
  }
}
const incompleteReadyBashDeny = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Bash",
  tool_input: { command: "printf changed > src.ts" },
});
if (incompleteReadyBashDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("incomplete READY must still deny implementation Bash mutations");
  process.exit(1);
}
writeFileSync(join(tmp, "PLAN.md"), "# PLAN\\n## Meta\\n- Status: DRAFT — needs review\\n");
const malformedStatusDeny = mod.planMutationGuardDecision({
  cwd: tmp,
  toolName: "write",
  input: { path: join(tmp, "z.ts"), content: "z" },
});
if (malformedStatusDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("malformed present PLAN status must deny implementation writes");
  process.exit(1);
}

writeFileSync(join(tmp, "PLAN.md"), validReadyPlan);

const weakenDeny = mod.planMutationGuardDecision({
  cwd: tmp,
  toolName: "write",
  input: {
    path: join(tmp, "PLAN.md"),
    content: [
      "# PLAN",
      "",
      "## Meta",
      "- Status: READY",
      "",
      "## Checks",
      "- command: bash tests/a.sh",
      "",
    ].join("\\n"),
  },
});
if (weakenDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("READY check-freeze weaken must deny");
  process.exit(1);
}
if (!String(weakenDeny?.hookSpecificOutput?.permissionDecisionReason || "").includes("check-freeze")) {
  console.error("weaken deny reason must mention check-freeze");
  process.exit(1);
}

const strengthenOk = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Write",
  tool_input: {
    file_path: join(tmp, "PLAN.md"),
    content: [
      "# PLAN",
      "",
      "## Meta",
      "- Status: READY",
      "",
      "## Checks",
      "- command: bash tests/a.sh",
      "- command: bash tests/b.sh",
      "- command: bash tests/c.sh",
      "## Acceptance Criteria",
      "- Guard permits valid READY work.",
      "",
    ].join("\\n"),
  },
});
if (strengthenOk != null) {
  console.error("READY strengthen must allow");
  process.exit(1);
}

const challengedOk = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Write",
  tool_input: {
    file_path: join(tmp, "PLAN.md"),
    content: [
      "# PLAN",
      "",
      "## Meta",
      "- Status: CHALLENGED",
      "",
      "## Checks",
      "- command: bash tests/a.sh",
      "",
      "## Decision Log",
      "- check-freeze demote: removed b",
      "",
    ].join("\\n"),
  },
});
if (challengedOk != null) {
  console.error("CHALLENGED weaken with rationale must allow");
  process.exit(1);
}

const demoteNoRationale = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Write",
  tool_input: {
    file_path: join(tmp, "PLAN.md"),
    content: [
      "# PLAN",
      "",
      "## Meta",
      "- Status: CHALLENGED",
      "",
      "## Checks",
      "- command: bash tests/a.sh",
      "",
      "## Decision Log",
      "- scope discussion only",
      "",
    ].join("\\n"),
  },
});
if (demoteNoRationale?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("CHALLENGED weaken without freeze rationale must deny");
  process.exit(1);
}

const bashPlanDeny = mod.planMutationGuardDecision({
  cwd: tmp,
  toolName: "bash",
  input: { command: "sed -i '' '/agent-scenarios/d' PLAN.md" },
});
if (bashPlanDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("READY mutating bash targeting PLAN.md must deny");
  process.exit(1);
}

// Restore full READY baseline on disk for Edit/MultiEdit/AC cases
writeFileSync(join(tmp, "PLAN.md"), [
  "# PLAN",
  "",
  "## Meta",
  "- Status: READY",
  "",
  "## Checks",
  "- command: bash tests/a.sh",
  "- command: bash tests/b.sh",
  "",
  "## Acceptance Criteria",
  "- Given x, when y, then z",
  "- Given a, when b, then c",
  "",
].join("\\n"));

const piSchemaNeutralEdit = mod.planMutationGuardDecision({
  cwd: tmp,
  toolName: "edit",
  input: {
    path: join(tmp, "PLAN.md"),
    edits: [{ oldText: "# PLAN\n", newText: "# PLAN updated\n" }],
  },
});
if (piSchemaNeutralEdit != null) {
  console.error("Pi edits[].oldText/newText schema must reconstruct a neutral READY edit");
  process.exit(1);
}

const piSchemaWeaken = mod.planMutationGuardDecision({
  cwd: tmp,
  toolName: "edit",
  input: {
    path: join(tmp, "PLAN.md"),
    edits: [{ oldText: "- command: bash tests/b.sh\n", newText: "" }],
  },
});
if (piSchemaWeaken?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("Pi edits[].oldText/newText weaken must remain denied");
  process.exit(1);
}

const relativePiSchemaWeaken = mod.planMutationGuardDecision({
  cwd: tmp,
  toolName: "edit",
  input: {
    path: "PLAN.md",
    edits: [{ oldText: "- command: bash tests/b.sh\n", newText: "" }],
  },
});
if (relativePiSchemaWeaken?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("relative Pi PLAN.md weaken must remain guarded");
  process.exit(1);
}

const piSchemaUnmatched = mod.planMutationGuardDecision({
  cwd: tmp,
  toolName: "edit",
  input: {
    path: join(tmp, "PLAN.md"),
    edits: [{ oldText: "not present in plan", newText: "replacement" }],
  },
});
if (piSchemaUnmatched?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("Pi unmatched edit schema must fail closed");
  process.exit(1);
}

const editWeaken = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Edit",
  tool_input: {
    file_path: join(tmp, "PLAN.md"),
    old_string: "- command: bash tests/b.sh\\n",
    new_string: "",
  },
});
if (editWeaken?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("READY Edit weaken must deny");
  process.exit(1);
}

const multiEditWeaken = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "MultiEdit",
  tool_input: {
    file_path: join(tmp, "PLAN.md"),
    edits: [{ old_string: "- command: bash tests/b.sh\\n", new_string: "" }],
  },
});
if (multiEditWeaken?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("READY MultiEdit weaken must deny");
  process.exit(1);
}

const acWeaken = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Write",
  tool_input: {
    file_path: join(tmp, "PLAN.md"),
    content: [
      "# PLAN",
      "",
      "## Meta",
      "- Status: READY",
      "",
      "## Checks",
      "- command: bash tests/a.sh",
      "- command: bash tests/b.sh",
      "",
      "## Acceptance Criteria",
      "- Given x, when y, then z",
      "",
    ].join("\\n"),
  },
});
if (acWeaken?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("READY Acceptance Criteria weaken must deny");
  process.exit(1);
}

// Commit guard parity: session PLAN.md is never a commit target, for
// Claude-style and Pi-style events, named or already staged.
const addPlanDeny = mod.planCommitGuardDecision({
  cwd: tmp,
  tool_name: "Bash",
  tool_input: { command: "git add PLAN.md" },
});
if (addPlanDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("git add PLAN.md must deny");
  process.exit(1);
}

const piNamedCommitDeny = mod.planCommitGuardDecision({
  cwd: tmp,
  toolName: "bash",
  input: { command: "git commit -m wip PLAN.md" },
});
if (piNamedCommitDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("Pi-style git commit naming PLAN.md must deny");
  process.exit(1);
}

// Commit guard is status-independent: DRAFT still denies.
writeFileSync(join(tmp, "PLAN.md"), "# PLAN\n\n## Meta\n- Status: DRAFT\n");
const draftCommitDeny = mod.planCommitGuardDecision({
  cwd: tmp,
  toolName: "bash",
  input: { command: "git add PLAN.md" },
});
if (draftCommitDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("DRAFT PLAN.md add must deny via commit guard");
  process.exit(1);
}
writeFileSync(join(tmp, "PLAN.md"), [
  "# PLAN",
  "",
  "## Meta",
  "- Status: READY",
  "",
  "## Checks",
  "- command: bash tests/a.sh",
  "- command: bash tests/b.sh",
  "",
].join("\\n"));

execFileSync("git", ["-C", tmp, "init", "-q"]);
execFileSync("git", ["-C", tmp, "add", "PLAN.md"]);
const piStagedCommitDeny = mod.planCommitGuardDecision({
  cwd: tmp,
  toolName: "bash",
  input: { command: "git commit -m wip" },
});
if (piStagedCommitDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("Pi-style git commit with staged PLAN.md must deny");
  process.exit(1);
}

const addUnrelatedAllowed = mod.planCommitGuardDecision({
  cwd: tmp,
  toolName: "bash",
  input: { command: "git add README.md" },
});
if (addUnrelatedAllowed != null) {
  console.error("git add of a non-plan file must be allowed");
  process.exit(1);
}

const ops = mod.classifyWorkflowRoute("supprime ce dossier et force-push la branche", {
  planStatus: "missing",
});
if (ops.route !== "ops-stop") {
  console.error("ops-stop expected, got", ops.route);
  process.exit(1);
}

console.log("dual-runtime guard matrix smoke test: ok");
console.log("claude.plan_ready_guard: deny_on_draft confirmed");
console.log("pi.plan_ready_guard: deny_on_draft confirmed (shared helper)");
console.log("check_freeze: deny_weaken_allow_strengthen confirmed");
console.log("check_freeze: edit_multiedit_ac_weaken deny confirmed");
console.log("plan_commit_guard: named and staged PLAN.md deny confirmed (Claude + Pi schemas)");
console.log("ops_stop.route: confirmed via classifier");
EOF
