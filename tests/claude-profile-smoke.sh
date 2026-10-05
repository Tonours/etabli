#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/claude-profile.XXXXXX")"
trap 'rm -rf "$FIXTURE_DIR"' EXIT
mkdir -p "$FIXTURE_DIR/tmp"
export TMPDIR="$FIXTURE_DIR/tmp" PROFILE_REPO="$ROOT_DIR" PROFILE_FIXTURE="$FIXTURE_DIR"
node --input-type=module <<'NODE'
import assert from 'node:assert/strict';
import { mkdirSync, writeFileSync, readFileSync, existsSync, statSync, readdirSync, rmSync, realpathSync } from 'node:fs';
import { execFileSync, spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
const repo = process.env.PROFILE_REPO, dir = realpathSync(process.env.PROFILE_FIXTURE);
const { buildLeanLaunch, renderMcpConfig } = await import(pathToFileURL(join(repo, 'scripts/lib/claude-profile.mjs')));
const home = join(dir, 'home with spaces'), cwd = join(dir, 'project');
mkdirSync(home); mkdirSync(cwd); delete process.env.OBVAULT_ROOT;
execFileSync('git', ['init', '-q', cwd]);
execFileSync('git', ['-C', cwd, 'remote', 'add', 'origin', 'git@github.com:Tonours/etabli.git']);
const launch = buildLeanLaunch({repoRoot:repo,home,cwd,strictMcp:false});
try {
  assert.ok(launch.args.includes('--mcp-config'), 'non-strict must still pass rendered MCP config');
  assert.ok(!launch.args.includes('--strict-mcp-config'));
} finally { launch.cleanup(); }
const profile = JSON.parse(readFileSync(join(repo, 'claude/profiles/lean.settings.json')));
assert.ok(!Object.hasOwn(profile.enabledPlugins, 'typescript-lsp@claude-plugins-official'), 'inherit native TypeScript LSP preference');
assert.ok(!Object.hasOwn(profile, 'effortLevel'), 'inherit machine effort');
for (const name of ['brain','obvault']) {
  const root = join(home,'work',name); mkdirSync(join(root,'_meta/mcp'),{recursive:true});
  writeFileSync(join(root,'_meta/obvault'),'#!/bin/sh\nexit 0\n');
  writeFileSync(join(root,'_meta/mcp/server.mjs'),'// fixture only\n');
}
writeFileSync(join(home,'.etabli-scope'),'work\n');
function checkVault(name, at=cwd) {
  const r=renderMcpConfig({repoRoot:repo,home,cwd:at});
  try {
    assert.equal(statSync(r.path).mode & 0o777,0o600);
    const body=JSON.parse(readFileSync(r.path));
    assert.deepEqual(Object.keys(body.mcpServers),['alambic-'+name]);
    assert.equal(body.mcpServers['alambic-'+name].env.OBVAULT_ROOT,join(home,'work',name));
    assert.equal(body.mcpServers['alambic-'+name].args[0],join(home,'work',name,'_meta/mcp/server.mjs'));
  } finally { r.cleanup(); }
  assert.ok(!existsSync(r.path));
}
checkVault('obvault');
execFileSync('git',['-C',cwd,'remote','set-url','origin','https://github.com/ForestAdmin/app.git']);
writeFileSync(join(home,'.etabli-scope'),'personal\n');
mkdirSync(join(cwd,'sub')); checkVault('brain',join(cwd,'sub'));
execFileSync('git',['-C',cwd,'remote','set-url','origin','https://github.com.evil.test/ForestAdmin/app.git']); checkVault('obvault');
process.env.OBVAULT_ROOT=join(home,'work/brain'); checkVault('brain');
process.env.OBVAULT_ROOT=join(home,'missing');
let r=renderMcpConfig({repoRoot:repo,home,cwd});
try { assert.deepEqual(JSON.parse(readFileSync(r.path)).mcpServers,{}); assert.ok(r.skipped.length); } finally {r.cleanup();}
delete process.env.OBVAULT_ROOT;
rmSync(join(home,'work/obvault/_meta/mcp/server.mjs'));
r=renderMcpConfig({repoRoot:repo,home,cwd});
try { assert.deepEqual(JSON.parse(readFileSync(r.path)).mcpServers,{}); } finally {r.cleanup();}
assert.throws(()=>buildLeanLaunch({repoRoot:join(dir,'absent'),home,cwd}),/lean profile missing/);
const fake=join(dir,'fake-claude');
writeFileSync(fake,'#!/bin/sh\nexit 23\n',{mode:0o755});
const invoked=spawnSync(join(repo,'scripts/claude-lean'),['-p','fixture'],{cwd,env:{...process.env,HOME:home,CLAUDE_CONFIG_DIR:'',ETABLI_CLAUDE_BIN:fake},encoding:'utf8'});
assert.equal(invoked.status,23,'native exit is preserved');
assert.deepEqual(readdirSync(process.env.TMPDIR),[],'owned render dirs removed on failure');
const inspected=spawnSync(join(repo,'scripts/claude-lean'),['--print-args','--no-strict-mcp'],{cwd,env:{...process.env,HOME:home,CLAUDE_CONFIG_DIR:'',ETABLI_CLAUDE_BIN:fake},encoding:'utf8'});
assert.equal(inspected.status,0); assert.match(inspected.stdout,/--mcp-config/);
assert.deepEqual(readdirSync(process.env.TMPDIR),[],'inspect also cleans owned renders');
console.log('claude-profile smoke: ok');
NODE
