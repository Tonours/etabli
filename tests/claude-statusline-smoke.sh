#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export STATUSLINE_REPO="$ROOT_DIR"
node --input-type=module <<'NODE'
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
const command=join(process.env.STATUSLINE_REPO,'claude/statusline-command.sh');
const run=(data)=>spawnSync('bash',[command],{input:JSON.stringify(data),encoding:'utf8'});
const full={cwd:'/tmp',model:{display_name:'Opus'},effort:{level:'low'},context_window:{current_usage:{input_tokens:10,output_tokens:2,cache_creation_input_tokens:3,cache_read_input_tokens:7}},prompt_cache:{warm:true,hit_ratio:0.9,misses:2},rate_limits:{five_hour:{used_percentage:0},seven_day:{used_percentage:25.5}}};
let r=run(full);assert.equal(r.status,0);assert.match(r.stdout,/effort:low/);assert.match(r.stdout,/in:10/);assert.match(r.stdout,/out:2/);assert.match(r.stdout,/write:3/);assert.match(r.stdout,/read:7/);assert.match(r.stdout,/parent/);assert.match(r.stdout,/5h:0%/);assert.match(r.stdout,/7j:25.5%/);assert.match(r.stdout,/cache:90%/);
r=run({cwd:'/tmp'});assert.equal(r.status,0);assert.match(r.stdout,/effort:inconnu/);assert.match(r.stdout,/ctx:inconnu/);assert.match(r.stdout,/5h:inconnu/);assert.match(r.stdout,/in:inconnu/);
r=run({cwd:'/tmp',context_window:{current_usage:{input_tokens:0,output_tokens:0,cache_creation_input_tokens:0,cache_read_input_tokens:0}},prompt_cache:{warm:false,hit_ratio:0,misses:0}});assert.equal(r.status,0);assert.match(r.stdout,/ctx:0t/);assert.match(r.stdout,/in:0/);assert.match(r.stdout,/cache:0%/);assert.match(r.stdout,/miss:0/);
r=run({context_window:{current_usage:null,total_input_tokens:20},effort:{level:4},rate_limits:{five_hour:{used_percentage:'0'},seven_day:{used_percentage:-1}}});assert.equal(r.status,0);assert.match(r.stdout,/ctx:20t/);assert.match(r.stdout,/5h:inconnu/);assert.match(r.stdout,/7j:inconnu/);
r=spawnSync('bash',[command],{input:'{bad',encoding:'utf8'});assert.notEqual(r.status,0);assert.match(r.stderr,/invalid statusline JSON/);
console.log('claude-statusline smoke: ok');
NODE

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
real_git="$(command -v git)"
mkdir -p "$TMP_DIR/bin" "$TMP_DIR/repo"
printf '#!/bin/sh\nprintf "x\\n" >>"$STATUSLINE_GIT_LOG"\nexec "%s" "$@"\n' "$real_git" >"$TMP_DIR/bin/git"
chmod +x "$TMP_DIR/bin/git"
git -C "$TMP_DIR/repo" init -q -b main
printf 'a\n' >"$TMP_DIR/repo/tracked.txt"
git -C "$TMP_DIR/repo" add tracked.txt
git -C "$TMP_DIR/repo" -c user.name=t -c user.email=t@example.test commit -q -m init
render() {
	: >"$TMP_DIR/git.log"
	printf '{"cwd":"%s"}' "$1" | PATH="$TMP_DIR/bin:$PATH" STATUSLINE_GIT_LOG="$TMP_DIR/git.log" bash "$ROOT_DIR/claude/statusline-command.sh" | head -1
}
expect_render() {
	local label="$1" cwd="$2" want="$3" calls="${4:-1}" line spawns
	line="$(render "$cwd" | sed 's/\x1b\[[0-9;]*m//g')"
	spawns="$(wc -l <"$TMP_DIR/git.log" | tr -d ' ')"
	case "$line" in
	"$want"*) ;;
	*)
		printf 'statusline %s: got "%s", want prefix "%s"\n' "$label" "$line" "$want" >&2
		exit 1
		;;
	esac
	[ "$spawns" -eq "$calls" ] || {
		printf 'statusline %s: %s git spawns, want %s\n' "$label" "$spawns" "$calls" >&2
		exit 1
	}
}
expect_render clean "$TMP_DIR/repo" "repo git:(main) inconnu"
printf 'b\n' >>"$TMP_DIR/repo/tracked.txt"
expect_render modified "$TMP_DIR/repo" "repo git:(main) x inconnu"
git -C "$TMP_DIR/repo" checkout -q tracked.txt
printf 'u\n' >"$TMP_DIR/repo/untracked.txt"
expect_render "untracked only" "$TMP_DIR/repo" "repo git:(main) x inconnu"
rm "$TMP_DIR/repo/untracked.txt"
git -C "$TMP_DIR/repo" checkout -q --detach
expect_render detached "$TMP_DIR/repo" "repo inconnu"
mkdir -p "$TMP_DIR/plain"
expect_render "not a repo" "$TMP_DIR/plain" "plain inconnu"
printf '#!/bin/sh\nprintf "x\\n" >>"$STATUSLINE_GIT_LOG"\nfor arg in "$@"; do [ "$arg" = status ] && exec sleep 3; done\nexec "%s" "$@"\n' "$real_git" >"$TMP_DIR/bin/git"
git -C "$TMP_DIR/repo" checkout -q main
expect_render "status timeout" "$TMP_DIR/repo" "repo git:(main) inconnu" 2
printf 'claude-statusline git smoke: ok\n'
