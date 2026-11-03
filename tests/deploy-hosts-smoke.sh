#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
	printf 'deploy-hosts smoke: %s\n' "$1" >&2
	exit 1
}

URL="git@github.com:acme/etabli.git"
export GIT_CONFIG_GLOBAL="$TMP_DIR/gitconfig"
git config --global url."$TMP_DIR/origin.git".insteadOf "$URL"
git config --global --add url."$TMP_DIR/origin.git".insteadOf ssh://git@github.com:22/acme/etabli.git
git config --global user.name smoke
git config --global user.email smoke@example.test
git config --global init.defaultBranch main

git init -q --bare "$TMP_DIR/origin.git"
git clone -q "$URL" "$TMP_DIR/local" 2>/dev/null
mkdir -p "$TMP_DIR/local/scripts"
cp "$ROOT_DIR/scripts/deploy-hosts" "$TMP_DIR/local/scripts/deploy-hosts"
cat >"$TMP_DIR/local/scripts/deploy-agent-workflow" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$1" >>.deploy-calls
[ "$1" != --check ] || [ ! -e .fail-check ]
SH
chmod +x "$TMP_DIR/local/scripts/deploy-agent-workflow"
printf '.deploy-calls\n.fail-check\n' >"$TMP_DIR/local/.gitignore"
git -C "$TMP_DIR/local" add -A
git -C "$TMP_DIR/local" commit -q -m "chore: seed"
git -C "$TMP_DIR/local" push -q origin main

for host in ok wrong dirty ahead branch checkfail relative port pathlike; do
	git clone -q "$URL" "$TMP_DIR/$host" 2>/dev/null
done
git -C "$TMP_DIR/relative" remote set-url origin acme/etabli
git -C "$TMP_DIR/port" remote set-url origin ssh://git@github.com:22/acme/etabli.git
git -C "$TMP_DIR/pathlike" remote set-url origin github.com/acme/etabli
git -C "$TMP_DIR/wrong" remote set-url origin git@github.com:other/etabli.git
printf 'x\n' >"$TMP_DIR/dirty/stray.txt"
git -C "$TMP_DIR/ahead" commit -q --allow-empty -m "chore: local only"
git -C "$TMP_DIR/branch" checkout -q -b feature
touch "$TMP_DIR/checkfail/.fail-check"

git -C "$TMP_DIR/local" commit -q --allow-empty -m "feat: new"
git -C "$TMP_DIR/local" push -q origin main
SHA=$(git -C "$TMP_DIR/local" rev-parse HEAD)
! git -C "$TMP_DIR/ok" cat-file -e "$SHA^{commit}" 2>/dev/null || fail "ok fixture must lack the approved SHA before the fetch"

mkdir -p "$TMP_DIR/bin"
cat >"$TMP_DIR/bin/ssh" <<'SH'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do
	case $1 in
		-o) shift 2 ;;
		-*) shift ;;
		*) break ;;
	esac
done
host=$1
shift
printf '%s\n' "$host" >>"$SSH_LOG"
if [ "$host" = forged ]; then
	printf 'ok forged\n'
	exit 1
fi
if [ "$host" = down ]; then
	printf 'ssh: connect to host down port 22: Connection refused\n' >&2
	exit 255
fi
eval "$*"
SH
chmod +x "$TMP_DIR/bin/ssh"
export PATH="$TMP_DIR/bin:$PATH" SSH_LOG="$TMP_DIR/ssh.log"

hosts="$TMP_DIR/hosts"
{
	printf '# fixture hosts\n\n'
	for host in ok wrong dirty ahead branch checkfail relative port pathlike; do printf '%s %s\n' "$host" "$TMP_DIR/$host"; done
	printf 'down %s\n' "$TMP_DIR/nowhere"
} >"$hosts"

status=0
out=$("$TMP_DIR/local/scripts/deploy-hosts" --hosts "$hosts") || status=$?
[ "$status" -eq 1 ] || fail "a failing host must exit 1, got $status: $out"
expect() {
	printf '%s\n' "$out" | grep -E "^$1 +$2" >/dev/null || fail "host $1 should print '$2', got: $out"
}
expect ok "ok ${SHA:0:12}"
expect wrong "refused: origin git@github.com:other/etabli.git"
expect dirty "refused: checkout has uncommitted changes"
expect ahead "refused: checkout HEAD is ahead of or diverged"
expect branch "refused: checkout is on feature"
expect checkfail "failed: deploy-agent-workflow --check"
expect down "unreachable: ssh: connect to host down"
expect relative "refused: origin acme/etabli is not a github.com URL"
expect port "ok ${SHA:0:12}"
expect pathlike "refused: origin github.com/acme/etabli is not a github.com URL"
[ "$(git -C "$TMP_DIR/ok" rev-parse HEAD)" = "$SHA" ] || fail "ok host must sit on the approved SHA"
[ "$(cat "$TMP_DIR/ok/.deploy-calls")" = "$(printf -- '--apply\n--check')" ] || fail "ok host must run --apply then --check"
for host in wrong dirty ahead branch relative pathlike; do
	[ ! -e "$TMP_DIR/$host/.deploy-calls" ] || fail "refused host $host must not run deploy-agent-workflow"
done

printf 'ok %s\n' "$TMP_DIR/ok" >"$TMP_DIR/one-host"
out=$("$TMP_DIR/local/scripts/deploy-hosts" --hosts "$TMP_DIR/one-host") || fail "an all-ok run must exit 0: $out"
printf 'forged %s\n' "$TMP_DIR/ok" >"$TMP_DIR/forged-host"
status=0
out=$("$TMP_DIR/local/scripts/deploy-hosts" --hosts "$TMP_DIR/forged-host") || status=$?
[ "$status" -eq 1 ] || fail "a nonzero ssh exit must fail the run even when stdout says ok: $out"

: >"$SSH_LOG"
git -C "$TMP_DIR/local" commit -q --allow-empty -m "feat: unpushed"
status=0
err=$("$TMP_DIR/local/scripts/deploy-hosts" --hosts "$hosts" 2>&1) || status=$?
[ "$status" -eq 1 ] || fail "unpushed local main must exit 1, got $status"
printf '%s' "$err" | grep -q "is not pushed" || fail "unpushed refusal must say so: $err"
[ ! -s "$SSH_LOG" ] || fail "unpushed local main must not reach any host"

printf 'deploy-hosts smoke test: ok\n'
