import { realpath, readFile } from 'node:fs/promises';
import { basename, dirname, join, relative, resolve } from 'node:path';
import { createHash } from 'node:crypto';
import { planCommitGuardDecision, planMutationGuardDecision } from '../../workflow/runtime/workflow-router-core.mjs';
import { noCommentsGuardDecision } from '../../workflow/runtime/no-comments-guard.mjs';
import { assertReadable } from './egress.ts';
import { fingerprint, type Grant, type RuntimeState } from './state.ts';

export async function workspacePath(cwd: string, target: string): Promise<string> {
  const path = resolve(cwd, target);
  assertReadable(path, cwd);
  try {
    const actual = await realpath(path);
    assertReadable(actual, cwd);
    return actual;
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
    let ancestor = dirname(path);
    for (;;) {
      try {
        const parent = await realpath(ancestor);
        assertReadable(parent, cwd);
        const actual = resolve(parent, relative(ancestor, path));
        assertReadable(actual, cwd);
        return actual;
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code !== 'ENOENT' || ancestor === dirname(ancestor)) throw error;
        ancestor = dirname(ancestor);
      }
    }
  }
}

export function guard(cwd: string, toolName: string, input: Record<string, unknown>) {
  const event = { cwd, toolName, input };
  for (const check of [planCommitGuardDecision, planMutationGuardDecision, noCommentsGuardDecision]) {
    const decision = check(event);
    if (decision) throw new Error(decision.hookSpecificOutput.permissionDecisionReason);
  }
}

export async function verifyInputs(cwd: string, files: Record<string, string>) {
  for (const [path, hash] of Object.entries(files)) {
    const actual = createHash('sha256').update(await readFile(await workspacePath(cwd, path))).digest('hex');
    if (actual !== hash) throw new Error(`Frozen input changed: ${path}; start a new input identity instead of reusing this result`);
  }
}

export function commandEffect(argv: string[], cwd: string): { action: string; target: string } {
  const executable = basename(argv[0] ?? '');
  let index = 1;
  if (executable === 'git') {
    while (argv[index]?.startsWith('-')) {
      const option = argv[index++];
      if (option === '-C' && resolve(cwd, argv[index] ?? '') !== cwd) throw new Error('Git workspace redirect differs from the recorded cwd; open a session in that workspace');
      if (/^--(?:git-dir|work-tree|namespace)(?:=|$)/.test(option)) throw new Error('Git repository overrides need a session bound to their actual workspace');
      if (['-C', '-c', '--git-dir', '--work-tree', '--namespace', '--config-env'].includes(option)) index++;
    }
    if (argv[index] === 'commit') return { action: 'git.commit', target: cwd };
    if (argv[index] === 'push') return { action: 'git.push', target: `${cwd}:${argv.slice(index + 1).join(' ')}` };
  }
  if (executable === 'gh') {
    while (argv[index]?.startsWith('-')) { const option = argv[index++]; if (['-R', '--repo', '--hostname'].includes(option)) index++; }
    if (argv[index] === 'pr' && argv[index + 1] === 'create') return { action: 'github.pr.create', target: cwd };
  }
  return { action: 'command', target: fingerprint([cwd, argv]) };
}

export function publication(action: string) { return ['git.push', 'github.pr.create'].includes(action); }

export function effectKey(action: string, target: string, scope: string) { return fingerprint([action, target, scope]); }

export function commandGrant(state: Readonly<RuntimeState>, grantId: string, argv: string[], cwd: string, now: number, consumer?: string): Grant {
  const grant = state.grants[grantId];
  const effect = commandEffect(argv, cwd);
  if (!grant || now >= grant.expiresAt || grant.cwd !== cwd || grant.action !== effect.action || grant.target !== effect.target || fingerprint(grant.argv) !== fingerprint(argv)) {
    throw new Error('Command needs a current human grant bound to its exact argv, cwd, action and target');
  }
  if ((grant.consumer && grant.consumer !== consumer) || (publication(effect.action) && (!grant.consumer || grant.consumer !== consumer))) throw new Error('Human grant is bound to another work consumer');
  guard(cwd, 'bash', { command: argv.join(' ') });
  return grant;
}

export async function fileHash(path: string): Promise<string | null> {
  try { return createHash('sha256').update(await readFile(path)).digest('hex'); }
  catch (error) { if ((error as NodeJS.ErrnoException).code === 'ENOENT') return null; throw error; }
}

export async function planReady(cwd: string) {
  guard(cwd, 'write', { path: join(cwd, '__durable_implementation_gate__'), content: '' });
  const plan = await readFile(join(cwd, 'PLAN.md'), 'utf8');
  if (!/^\s*-?\s*Status:\s*READY\s*$/m.test(plan)) throw new Error('Mission implementation requires the canonical root PLAN.md to be READY');
}
