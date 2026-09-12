#!/usr/bin/env bash
# Exercise setup, vault routing and remote deployment with isolated homes/CLIs.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT_DIR" <<'PY'
import json, os, pathlib, shutil, subprocess, sys, tempfile
P=pathlib.Path
repo=P(sys.argv[1])
with tempfile.TemporaryDirectory(prefix='herdr setup ') as tmp:
    root=P(tmp); home=root/'home'; home.mkdir(); fake=root/'bin'; fake.mkdir()
    tree=root/'bundle with spaces'; shutil.copytree(repo/'herdr', tree)
    (tree/'runtime').mkdir(); shutil.copy2(repo/'workflow/runtime/obvault-topic-resolver.mjs', tree/'runtime')
    env={**os.environ, 'HOME':str(home), 'PATH':str(fake)+':'+os.environ['PATH']}
    for key in ('OBVAULT_ROOT','HERDR_SOCKET_PATH','HERDR_PLUGIN_STATE_DIR','HERDR_CLAUDE_RELAUNCH_STATE_DIR'):
        env.pop(key,None)
    def script(name, body):
        path=fake/name; path.write_text(body); path.chmod(0o755)
    def run(args, ok=True, extra=None):
        p=subprocess.run([str(a) for a in args],env={**env,**(extra or {})},text=True,capture_output=True)
        assert (p.returncode==0)==ok, (args,p.returncode,p.stdout,p.stderr)
        return p
    for name in ('pi','fzf','bun'): script(name,'#!/bin/sh\nexit 0\n')
    script('herdr', '''#!/usr/bin/env python3
import json,os,pathlib,sys
P=pathlib.Path; home=P.home(); args=sys.argv[1:]; db=home/'plugins.json'
with (home/'calls.jsonl').open('a') as f: f.write(json.dumps(args)+'\\n')
p=json.loads(db.read_text()) if db.exists() else []
if args==['--version']: print(os.environ.get('FAKE_VERSION','herdr 0.9.0'))
elif args[:2]==['plugin','list']: print(json.dumps({'result':{'plugins':p}}))
elif args[:2]==['plugin','install']:
    if os.environ.get('FAIL_PLUGIN'): sys.exit(17)
    ids={'andrewchng/herdr-sessionizer':'sessionizer','persiyanov/herdr-reviewr':'persiyanov.reviewr','smarzban/herdr-file-viewer':'herdr-file-viewer','nicosuave/memex':'nicosuave.memex'}
    ident=ids[args[2]]; path=home/'plugins'/ident
    if any(v['plugin_id']==ident and v.get('source',{}).get('kind')=='local' for v in p): sys.exit(18)
    (path/'dist').mkdir(parents=True,exist_ok=True)
    (path/'dist/sessionizer').write_text('#!/bin/sh\\n'); (path/'dist/sessionizer').chmod(0o755)
    p=[v for v in p if v['plugin_id']!=ident]+[{'plugin_id':ident,'enabled':True,'warnings':[],'plugin_root':str(path),'source':{'kind':'github','resolved_commit':args[args.index('--ref')+1]}}]
    db.write_text(json.dumps(p))
elif args[:2]==['plugin','unlink']:
    db.write_text(json.dumps([v for v in p if v['plugin_id']!=args[2]]))
elif args[:2]==['plugin','link']:
    ident={'etabli-obvault':'etabli.obvault','claude-relaunch':'etabli.claude-relaunch','sessionizer':'sessionizer'}[P(args[2]).name]
    p=[v for v in p if v['plugin_id']!=ident]+[{'plugin_id':ident,'enabled':True,'warnings':[],'plugin_root':args[2],'source':{'kind':'local'}}]
    db.write_text(json.dumps(p))
elif args==['integration','status']:
    for agent in ('pi','claude','codex','grok','opencode','devin','cursor'): print(agent+': '+('stale' if os.environ.get('STALE_INTEGRATION') else 'current (v8) (fixture)'))
elif args[:2]==['integration','install'] or args==['config','check']: pass
elif args==['server','reload-config']: sys.exit(19 if os.environ.get('FAIL_RELOAD') else 0)
else: raise RuntimeError(args)
''')
    setup=['bash',tree/'scripts/setup.sh']
    config=home/'.config/herdr/config.toml'; config.parent.mkdir(parents=True); config.write_text('original')
    run(setup+['--links']); run(setup+['--links'])
    assert config.resolve()==tree/'config.toml'
    backups=list(config.parent.glob('config.toml.bak.*')); assert len(backups)==1 and backups[0].read_text()=='original'
    assert (home/'.config/herdr/plugins/config/sessionizer/config.toml').resolve()==tree/'layouts/sessionizer.config.toml'
    assert not (home/'calls.jsonl').exists(), 'links must not invoke Herdr'
    run(setup+['--install'],False,{'FAKE_VERSION':'herdr 0.8.3'})
    run(setup+['--install'],False,{'FAIL_PLUGIN':'1'})
    run(setup+['--install']); before=json.loads((home/'plugins.json').read_text())
    (home/'calls.jsonl').write_text(''); run(setup+['--install'])
    calls=[json.loads(s) for s in (home/'calls.jsonl').read_text().splitlines()]
    assert not any(a[:2]==['plugin','install'] for a in calls), 'matching pins must be reused'
    (home/'calls.jsonl').write_text(''); run(setup+['--check'])
    calls=[json.loads(s) for s in (home/'calls.jsonl').read_text().splitlines()]
    assert all(a[0]=='--version' or a[:2] in (['plugin','list'],['config','check'],['integration','status']) for a in calls)
    run(setup+['--check'],False,{'STALE_INTEGRATION':'1'})
    wrong=[dict(p) for p in before]; next(p for p in wrong if p['plugin_id']=='etabli.obvault')['plugin_root']=str(home/'old-tree')
    (home/'plugins.json').write_text(json.dumps(wrong)); run(setup+['--check'],False)
    before[0]['enabled']=False; (home/'plugins.json').write_text(json.dumps(before)); run(setup+['--check'],False)
    (home/'plugins.json').write_text(json.dumps(before)); before[0]['enabled']=True; before[0]['source']={'kind':'local'}
    (home/'plugins.json').write_text(json.dumps(before)); (home/'calls.jsonl').write_text('')
    run(setup+['--install'],False,{'FAIL_PLUGIN':'1'})
    restored=next(p for p in json.loads((home/'plugins.json').read_text()) if p['plugin_id']=='sessionizer')
    assert restored['source']['kind']=='local' and restored['plugin_root']==before[0]['plugin_root']
    assert ['plugin','link',before[0]['plugin_root']] in [json.loads(s) for s in (home/'calls.jsonl').read_text().splitlines()]
    run(setup+['--install']); calls=[json.loads(s) for s in (home/'calls.jsonl').read_text().splitlines()]
    assert ['plugin','unlink','sessionizer'] in calls
    assert any(a[:2]==['plugin','install'] for a in calls)
    print('ok setup backup, repeat installation, pinned builds, read-only check and failures')
    # Scope precedence, argv boundaries, explicit-root exclusion and CLI errors.
    for name in ('brain','obvault'):
        vault=home/'work'/name; (vault/'_meta').mkdir(parents=True); (vault/'AGENTS.md').write_text('fixture')
        cli=vault/'_meta/obvault'; cli.write_text('#!/bin/sh\nprintf "%s\\n" "$OBVAULT_ROOT|$*" >> "$HOME/vault.log"\nexit "${VAULT_EXIT:-0}"\n'); cli.chmod(0o755)
    actions=tree/'plugins/etabli-obvault/scripts'
    for scope,want in [('work','brain'),('personal','obvault')]:
        (home/'.etabli-scope').write_text(scope); (home/'vault.log').write_text('')
        for action in ('session','status'): run(['bash',actions/f'obvault-{action}.sh'],extra={'HERDR_ACTIVE_PANE_CWD':"/project with spaces/$(touch INJECTED)"})
        lines=(home/'vault.log').read_text().splitlines(); assert len(lines)==3 and all(s.startswith(str(home/'work'/want)+'|') for s in lines)
    run(['bash',actions/'obvault-session.sh'],False,{'OBVAULT_ROOT':str(home/'missing')})
    run(['bash',actions/'obvault-status.sh'],False,{'VAULT_EXIT':'7'})
    print('ok bundled canonical resolver, both actions, work/personal and exclusive root')
    # Scheduler persistence is tested without touching real cron/launchd.
    script('uname', '#!/bin/sh\nprintf "%s\\n" "${FAKE_OS:-Linux}"\n')
    script('launchctl', '#!/bin/sh\nexit 0\n')
    script('crontab', """#!/usr/bin/env python3
import pathlib,sys
p=pathlib.Path.home()/'crontab.txt'
if sys.argv[1]=='-l':
    if not p.exists(): sys.exit(1)
    print(p.read_text(),end='')
else: p.write_text(sys.stdin.read())
""")
    state=home/"state & 'with spaces"; socket=home/'socket'
    sched={'HERDR_CLAUDE_RELAUNCH_STATE_DIR':str(state),'HERDR_BIN_PATH':str(fake/'herdr'),'HERDR_SOCKET_PATH':str(socket)}
    lib=tree/'plugins/claude-relaunch/scripts/lib.sh'
    for _ in range(2): run(['bash','-c','source "$1"; install_watcher','_',lib],extra=sched)
    line=(home/'crontab.txt').read_text(); assert line.count('# etabli.claude-relaunch')==1
    import shlex,plistlib
    words=shlex.split(line); assert 'HERDR_CLAUDE_RELAUNCH_STATE_DIR='+str(state) in words and 'HERDR_BIN_PATH='+str(fake/'herdr') in words
    run(['bash','-c','source "$1"; remove_watcher','_',lib],extra=sched)
    assert not (home/'crontab.txt').read_text().strip()
    run(['bash','-c','source "$1"; install_watcher','_',lib],extra={**sched,'FAKE_OS':'Darwin'})
    plist=plistlib.loads((home/'Library/LaunchAgents/com.etabli.herdr-claude-relaunch.plist').read_bytes())
    assert plist['EnvironmentVariables']['HERDR_CLAUDE_RELAUNCH_STATE_DIR']==str(state)
    assert plist['EnvironmentVariables']['HERDR_BIN_PATH']==str(fake/'herdr')
    assert (state/'socket').read_text().strip()==str(socket)
    print('ok cron idempotence, recorded environment/socket and valid escaped launchd plist')
    # Run SSH shell payloads in an isolated fake remote HOME, including spaces/apostrophes.
    remote=root/"remote home'"; remote.mkdir(); env['REMOTE_HOME']=str(remote)
    script('ssh', '''#!/usr/bin/env python3
import os,subprocess,sys
sys.exit(subprocess.run(['bash','-c',sys.argv[-1]],env={**os.environ,'HOME':os.environ['REMOTE_HOME']}).returncode)
''')
    script('rsync', '''#!/usr/bin/env python3
import pathlib,shlex,shutil,sys
assert sys.argv[1]=='-az' and len(sys.argv)==4
src=sys.argv[2]; dest=pathlib.Path(shlex.split(sys.argv[3].split(':',1)[1])[0])
dest.mkdir(parents=True,exist_ok=True)
if pathlib.Path(src).is_dir(): shutil.copytree(src,dest,dirs_exist_ok=True)
else: shutil.copy2(src,dest)
''')
    sync=['bash',repo/'scripts/herdr-sync-mini']
    run(sync,extra={'HERDR_MINI_TREE':"~/work/Herdr's setup"})
    deployed=remote/"work/Herdr's setup"; assert (deployed/'runtime/obvault-topic-resolver.mjs').exists()
    assert (remote/'.config/herdr/config.toml').resolve()==deployed/'config.toml'
    run(sync,False,{'HERDR_MINI_TREE':'~/work/../oops'})
    run(sync,False,{'HERDR_MINI_HOST':'-oProxyCommand=bad'})
    run(sync,False,{'HERDR_MINI_TREE':'~/work'})
    run(sync,False,{'HERDR_MINI_TREE':'~/work/.'})
    (remote/'work').rename(remote/'workspace-volume'); (remote/'work').symlink_to(remote/'workspace-volume',target_is_directory=True)
    run(sync,False,{'HERDR_MINI_TREE':'~/work/.'})
    run(sync,False,{'HERDR_MINI_TREE':"~/work/Herdr's setup",'FAIL_RELOAD':'1'})
    print('ok Mini sync remote quoting, source-only transfer, resolver, reload failure and unsafe inputs')
print('herdr setup smoke test: ok')
PY
