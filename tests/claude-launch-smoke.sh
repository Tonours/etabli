#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export LAUNCH_TEST_REPO="$ROOT_DIR"
node --input-type=module <<'NODE'
import assert from 'node:assert/strict';
import { mkdtempSync,mkdirSync,readFileSync,writeFileSync,rmSync,symlinkSync,realpathSync,readdirSync,existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawn,spawnSync } from 'node:child_process';
const repo=process.env.LAUNCH_TEST_REPO, dir=realpathSync(mkdtempSync(join(tmpdir(),'claude-launch-')));
const routing=JSON.parse(readFileSync(join(repo,'workflow/runtime/model-routing.json'),'utf8'));
const assertDeepRouting=(record)=>{assert.deepEqual(record.args,['--model',routing.models.opusplan.model]);assert.equal(record.opus,routing.models.opus.model);assert.equal(record.sonnet,routing.models.sonnet.model);};
try {
 const home=join(dir,'home'),store=join(dir,'store with spaces'),binary=join(dir,'fake cli');
 mkdirSync(home);mkdirSync(store);
 writeFileSync(binary,'#!/usr/bin/env node\nconsole.log(JSON.stringify({args:process.argv.slice(2),store:process.env.CLAUDE_CONFIG_DIR??null,teams:process.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS,model:process.env.ANTHROPIC_MODEL??null,opus:process.env.ANTHROPIC_DEFAULT_OPUS_MODEL??null,sonnet:process.env.ANTHROPIC_DEFAULT_SONNET_MODEL??null}));\n',{mode:0o755});
 const env={...process.env,HOME:home,ETABLI_CLAUDE_BIN:binary,CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:'1'}; delete env.CLAUDE_CONFIG_DIR; delete env.ANTHROPIC_MODEL; delete env.ANTHROPIC_DEFAULT_OPUS_MODEL; delete env.ANTHROPIC_DEFAULT_SONNET_MODEL;
 const run=(name,args=[],extra={})=>spawnSync(join(repo,'scripts/claude-'+name),args,{env:{...env,...extra},encoding:'utf8'});
 const parse=(r)=>{assert.equal(r.status,0,r.stderr);return JSON.parse(r.stdout);};
 let r=parse(run('daily',['--model=sonnet','--effort','low','-p','literal $() prompt']));
 assert.equal(r.teams,'0');assert.equal(r.store,null);assert.deepEqual(r.args,['--model=sonnet','--effort','low','-p','literal $() prompt']);
 r=parse(run('daily',['--teams','--store',store]));assert.equal(r.teams,'1');assert.equal(r.store,store);
 r=parse(run('deep'));assert.deepEqual(r.args,['--model','opusplan']);assert.equal(r.teams,'0');assert.equal(r.opus,'claude-opus-5-5');assert.equal(r.sonnet,'claude-sonnet-5-5');assertDeepRouting(r);assert.throws(()=>assertDeepRouting({...r,opus:'claude-opus-4-6'}));assert.throws(()=>assertDeepRouting({...r,args:['--model','opus']}));
 r=parse(run('deep',['--model=claude-sonnet-5-5','--effort=low']));assert.deepEqual(r.args,['--model=claude-sonnet-5-5','--effort=low']);assert.equal(r.opus,'claude-opus-5-5');assert.equal(r.sonnet,'claude-sonnet-5-5');
 r=parse(run('deep',['--model','claude-opus-4-6']));assert.deepEqual(r.args,['--model','claude-opus-4-6']);assert.equal(r.opus,'claude-opus-5-5');assert.equal(r.sonnet,'claude-sonnet-5-5');
 r=parse(run('deep',[],{ANTHROPIC_MODEL:'claude-sonnet-5-5'}));assert.deepEqual(r.args,[]);assert.equal(r.model,'claude-sonnet-5-5');assert.equal(r.sonnet,'claude-sonnet-5-5');
 r=parse(run('deep',[],{ANTHROPIC_DEFAULT_OPUS_MODEL:'custom-opus',ANTHROPIC_DEFAULT_SONNET_MODEL:'custom-sonnet'}));assert.equal(r.opus,'custom-opus');assert.equal(r.sonnet,'custom-sonnet');
 r=parse(run('deep',[],{ANTHROPIC_MODEL:'',ANTHROPIC_DEFAULT_OPUS_MODEL:'',ANTHROPIC_DEFAULT_SONNET_MODEL:''}));assert.deepEqual(r.args,['--model','opusplan']);assert.equal(r.opus,'claude-opus-5-5');assert.equal(r.sonnet,'claude-sonnet-5-5');
 r=parse(run('daily'));assert.deepEqual(r.args,[]);assert.equal(r.opus,null);assert.equal(r.sonnet,null);
 r=parse(run('daily',['--inspect','--store='+store]));assert.equal(r.effective_model,null);assert.equal(r.effective_effort,null);assert.equal(r.store_source,'explicit');
 assert.equal(run('daily',['--store',join(dir,'missing')]).status,2);
 assert.equal(run('daily',[],{CLAUDE_CONFIG_DIR:join(dir,'missing')}).status,2);
 assert.equal(run('daily',['--claude-bin',join(dir,'missing')]).status,2);
 assert.equal(run('daily',['--store']).status,2);
 assert.equal(run('daily',[],{ETABLI_CLAUDE_BIN:join(repo,'scripts/claude-lean')}).status,2);
 const broken=join(dir,'bad-interpreter');writeFileSync(broken,'#!/does-not-exist\n',{mode:0o755});
 assert.equal(run('daily',[],{ETABLI_CLAUDE_BIN:broken}).status,2);
 const linked=join(dir,'daily-link');symlinkSync(join(repo,'scripts/claude-daily'),linked);
 assert.equal(spawnSync(linked,['--inspect'],{env,encoding:'utf8'}).status,0);
 const alias=join(dir,'repo-alias');symlinkSync(repo,alias);
 const aliasResult=spawnSync(join(alias,'scripts/claude-daily'),['--inspect'],{env,encoding:'utf8'});assert.equal(parse(aliasResult).mode,'daily');
 // Full is deliberately unchanged; it passes native flags and ambient teams.
 const bin=join(dir,'bin');mkdirSync(bin);symlinkSync(binary,join(bin,'claude'));
 r=parse(run('full',['--version'],{PATH:bin+':'+process.env.PATH}));assert.deepEqual(r.args,['--version']);assert.equal(r.teams,'1');
 // A terminated launch cleans only its own render, keeping another session intact.
 const temp=join(dir,'temps');mkdirSync(temp);
 const sentinel=join(temp,'claude-lean-mcp-other');mkdirSync(sentinel);
 const ready=join(dir,'ready'),hanging=join(dir,'hanging-cli');
 writeFileSync(hanging,`#!/usr/bin/env node\nimport {writeFileSync} from 'node:fs';\nwriteFileSync(process.env.LAUNCH_READY,'ready'); setInterval(()=>{},1000);\n`,{mode:0o755});
 for (const signal of ['SIGTERM','SIGHUP','SIGINT']) {
  if(existsSync(ready))rmSync(ready);
  const child=spawn(join(repo,'scripts/claude-lean'),[],{env:{...env,TMPDIR:temp,ETABLI_CLAUDE_BIN:hanging,LAUNCH_READY:ready},stdio:'ignore'});
  const exited=new Promise((done)=>child.on('exit',(code,sig)=>done({code,sig})));
  const until=Date.now()+5000;
  while(!existsSync(ready)&&Date.now()<until)await new Promise((done)=>setTimeout(done,20));
  if(!existsSync(ready)){child.kill('SIGKILL');await exited;assert.fail('fake CLI did not start');}
  child.kill(signal);
  const timer=setTimeout(()=>child.kill('SIGKILL'),5000);
  const result=await exited;clearTimeout(timer);
  assert.equal(result.sig,null,'wrapper should observe native exit and clean up');
  assert.equal(result.code,128+({SIGTERM:15,SIGHUP:1,SIGINT:2}[signal]));
  assert.deepEqual(readdirSync(temp),['claude-lean-mcp-other']);
 }
 const imported=spawnSync(process.execPath,['--input-type=module','-'],{input:`await import(${JSON.stringify(join(repo,'scripts/lib/claude-launch.mjs'))});await import(${JSON.stringify(join(repo,'claude/statusline.mjs'))});console.log('import-ok');`,encoding:'utf8'});assert.equal(imported.status,0,imported.stderr);assert.match(imported.stdout,/import-ok/);
 console.log('claude-launch smoke: ok');
} finally { rmSync(dir,{recursive:true,force:true}); }
NODE
