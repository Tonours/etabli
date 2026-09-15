#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
LIB="$ROOT_DIR/scripts/lib/claude-profile.mjs"
LEAN="$ROOT_DIR/scripts/claude-lean"
FULL="$ROOT_DIR/scripts/claude-full"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/claude-profile.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

fail() {
	printf 'claude-profile smoke: %s\n' "$1" >&2
	exit 1
}

chmod +x "$LEAN" "$FULL"

rm -f "${TMPDIR:-/tmp}"/claude-lean-mcp-*.json 2>/dev/null || true

node --input-type=module <<NODE
import { pathToFileURL } from "node:url";
import { existsSync, readFileSync, rmSync, writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";
const lib = await import(pathToFileURL("$LIB").href);
const assert = (cond, msg) => { if (!cond) throw new Error(msg); };

const home = "$TMP/home";
const env = {};

mkdirSync(home, { recursive: true });
assert(lib.loadScope(home) === "personal", "missing scope file defaults to personal");
writeFileSync(join(home, ".etabli-scope"), "work\n");
assert(lib.loadScope(home) === "work", "work scope read");
writeFileSync(join(home, ".etabli-scope"), "chaos\n");
assert(lib.loadScope(home) === "personal", "invalid scope falls back to personal");
writeFileSync(join(home, ".etabli-scope"), "work\n");

mkdirSync(join(home, "work/brain"), { recursive: true });

const rendered = lib.renderMcpConfig({
	repoRoot: "$ROOT_DIR",
	home,
	scope: "work",
	env,
});
assert(rendered.skipped.length === 0, "work scope with brain present renders brain");
const stat = (await import("node:fs")).statSync(rendered.path);
assert((stat.mode & 0o777) === 0o600, "rendered MCP config is 0600");
const body = JSON.parse(readFileSync(rendered.path, "utf8"));
assert(body.mcpServers.brain.args[0] === home + "/work/brain/_meta/mcp/server.mjs", "brain path substituted");
assert(!("require_scope" in body.mcpServers.brain), "renderer metadata stripped");
rmSync(rendered.path);
assert(!existsSync(rendered.path), "cleanup removes the temp render");

const noBrain = lib.renderMcpConfig({
	repoRoot: "$ROOT_DIR",
	home: "$TMP/home-no-brain",
	scope: "work",
	env,
});
assert(noBrain.skipped.includes("brain"), "work scope without brain root skips brain");
const noBrainBody = JSON.parse(readFileSync(noBrain.path, "utf8"));
assert(!noBrainBody.mcpServers.brain, "brain absent from render");
assert(Object.keys(noBrainBody.mcpServers).length === 0, "no servers left once brain is skipped");
rmSync(noBrain.path);

const personal = lib.renderMcpConfig({
	repoRoot: "$ROOT_DIR",
	home,
	scope: "personal",
	env,
});
assert(personal.skipped.includes("brain"), "personal scope skips brain");
rmSync(personal.path);


const launch = lib.buildLeanLaunch({ repoRoot: "$ROOT_DIR", home, env, extraArgs: ["-p", "hi"] });
assert(launch.args[0] === "--settings" && launch.args[1] === "$ROOT_DIR/claude/profiles/lean.settings.json", "profile passed via --settings");
assert(launch.args.includes("--strict-mcp-config"), "strict mcp on by default");
assert(launch.args.at(-2) === "-p" && launch.args.at(-1) === "hi", "extra args passed through");
launch.cleanup();

const noStrict = lib.buildLeanLaunch({ repoRoot: "$ROOT_DIR", home, env, strictMcp: false });
assert(!noStrict.args.includes("--strict-mcp-config"), "--no-strict-mcp drops the strict flags");
noStrict.cleanup();
let missing = null;
try {
	lib.buildLeanLaunch({ repoRoot: "$TMP/empty-repo", home, env });
} catch (error) {
	missing = error;
}
assert(missing && missing.message.includes("lean profile missing"), "missing profile error names the remediation");
console.log("claude-profile lib units ok");
NODE

mkdir -p "$TMP/h-launch/.claude" "$TMP/h-launch/work/brain"
printf 'work\n' >"$TMP/h-launch/.etabli-scope"
OUT="$(HOME="$TMP/h-launch" "$LEAN" --print-args)"
printf '%s\n' "$OUT" | grep -q "scope=work" || fail "launcher did not resolve work scope: $OUT"
printf '%s\n' "$OUT" | grep -q -- "--strict-mcp-config" || fail "launcher args missing strict mcp"
printf '%s\n' "$OUT" | grep -q "lean.settings.json" || fail "launcher args missing profile"

LEFTOVERS="$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'claude-lean-mcp-*.json' 2>/dev/null | wc -l | tr -d ' ')"
[ "$LEFTOVERS" -eq 0 ] || fail "temp MCP renders leaked: $LEFTOVERS"

FAKEBIN="$TMP/bin"
mkdir -p "$FAKEBIN"
ln -s "$LEAN" "$FAKEBIN/claude"
OUT="$(PATH="$FAKEBIN:$PATH" "$LEAN" -p hello 2>&1)" && fail "alias recursion not detected"
printf '%s\n' "$OUT" | grep -qE "recur\w+" || fail "recursion error not named: $OUT"

FAKECLAUDE="$FAKEBIN/fake-claude"
cat >"$FAKECLAUDE" <<'FAKE'
#!/usr/bin/env sh
printf 'fake-claude'
for a in "$@"; do printf ' %s' "$a"; done
printf '\n'
FAKE
chmod +x "$FAKECLAUDE"
ln -sf "$FAKECLAUDE" "$FAKEBIN/claude2"
OUT="$(PATH="$FAKEBIN" sh -c 'command -v claude2 >/dev/null && exec "$0"' "$FAKECLAUDE" 2>/dev/null || true)"
mkdir -p "$TMP/bin2"
ln -sf "$FAKECLAUDE" "$TMP/bin2/claude"
OUT="$(PATH="$TMP/bin2:$PATH" HOME="$TMP/h-launch" /bin/bash "$LEAN" 2>&1)" ||
  fail "claude-lean no-argument invocation failed: $OUT"
printf '%s\n' "$OUT" | grep -q "fake-claude --settings" ||
  fail "claude-lean no-argument invocation did not reach Claude: $OUT"
LEFTOVERS="$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'claude-lean-mcp-*.json' 2>/dev/null | wc -l | tr -d ' ')"
[ "$LEFTOVERS" -eq 0 ] || fail "no-argument launch leaked temp MCP renders: $LEFTOVERS"
OUT="$(PATH="$TMP/bin2:/usr/bin:/bin" HOME="$TMP/h-launch" "$FULL" --version)"
[ "$OUT" = "fake-claude --version" ] || fail "claude-full passthrough broken: $OUT"

printf 'claude-profile smoke test: ok\n'
