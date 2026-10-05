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
