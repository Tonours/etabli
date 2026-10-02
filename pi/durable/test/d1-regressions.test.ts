import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';
import { egress, redact } from '../egress.ts';
import { workspace } from './helpers.ts';

const execute = promisify(execFile);
const worker = fileURLToPath(new URL('../command-worker.py', import.meta.url));
const tree = fileURLToPath(new URL('../process_tree.py', import.meta.url));

test('nested JSON text with escaped internal quotes cannot leak a credential suffix', () => {
  const secret = 'prefix"sentinel-secret\\ending';
  let text = JSON.stringify({ password: secret });
  for (let layer = 0; layer < 4; layer++) {
    const result = redact(text);
    assert.equal(result.includes('sentinel-secret'), false, `serialized layer ${layer}`);
    assert.doesNotThrow(() => JSON.parse(result));
    const messages = egress('faux', ['faux'], [{ role: 'user', content: text, timestamp: 1 }]);
    assert.equal(JSON.stringify(messages).includes('sentinel-secret'), false);
    text = JSON.stringify(text);
  }
  assert.equal(redact(`saved config: ${text} trailing notes`).includes('sentinel-secret'), false);
});

test('cancellation drains a detached pipe holder without signalling a numeric process group', async () => {
  const w = await workspace(); const pidFile = join(w.cwd, 'descendant.pid'); const input = join(w.dir, 'worker.json'); const receipt = join(w.dir, 'receipt.json');
  const child = 'setTimeout(()=>{},5000)';
  const script = `const p=require('node:child_process').spawn(process.execPath,['-e',${JSON.stringify(child)}],{detached:true,stdio:'inherit'});require('node:fs').writeFileSync(${JSON.stringify(pidFile)},String(p.pid));p.unref();`;
  await writeFile(input, JSON.stringify({ taskId: 1, inputHash: 'fixture', cwd: w.cwd, argv: [process.execPath, '-e', script], timeoutMs: 400, receipt }));
  const harness = `import os,runpy,sys\nsys.dont_write_bytecode=True\nsys.path.insert(0,os.path.dirname(sys.argv[1]))\ndef refuse_group(*args): raise RuntimeError('unattributed numeric group signal')\nos.killpg=refuse_group\nsys.argv=sys.argv[1:]\nrunpy.run_path(sys.argv[0],run_name='__main__')`;
  try {
    await execute('python3', ['-c', harness, worker, input], { timeout: 6000 });
    assert.equal(JSON.parse(await readFile(receipt, 'utf8')).interrupted, true);
  } finally {
    try { const pid = Number(await readFile(pidFile, 'utf8')); if (Number.isInteger(pid) && pid > 0) process.kill(pid, 'SIGKILL'); }
    catch (error) { if (!['ESRCH', 'ENOENT'].includes((error as NodeJS.ErrnoException).code ?? '')) throw error; }
  }
});

test('an observed attribution gap stays uncertain after the unattributed process disappears', async () => {
  const script = `import importlib.util,sys\nsys.dont_write_bytecode=True\nspec=importlib.util.spec_from_file_location('process_tree',sys.argv[1]);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)\np=object.__new__(module.ProcessTree)\nroot={'pid':2,'id':2,'parent':1}\np.known={1:{'pid':1,'id':1,'parent':0},2:root};p.baseline={1:p.known[1]};p.owned={2};p.watched={2}\np.forked=True;p.uncertain=False;p.tracking_failed=False\nclass Queue:\n def control(self,*args): return []\np.queue=Queue()\nscans=iter([{2:root,99:{'pid':99,'id':99,'parent':98}},{2:root}]);p.scan=lambda:next(scans)\np.refresh();assert p.uncertain,'first attribution gap must be visible'\np.refresh();assert p.uncertain,'gap must survive descendant disappearance'`;
  await execute('python3', ['-c', script, tree]);
});
