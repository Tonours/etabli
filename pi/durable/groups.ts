import { defineTask, type TaskId } from '@earendil-works/pi-durable';
import { State, type Result } from './state.ts';
import { definitions, taskResult, type GroupInput, type GroupState } from './tasks.ts';
import { verifyInputs } from './guards.ts';
import type { Ledger } from './ledger.ts';
import { missionGate, missionComplete, validateMission, stepMission } from './missions.ts';
import { validateReview } from './reviews.ts';
import { redact } from './egress.ts';
import { BACKGROUND_CONTEXT } from '@earendil-works/chord/context';

export function deadlineDefinition(ledger: () => Ledger) {
  return defineTask<{ parent: TaskId; deadline: number }, { phase: 'wait' }, Result>({
    name: 'etabli.deadline', version: 1, initial: () => ({ phase: 'wait' }),
    phases: { wait: async (task, runtime, context) => {
      await runtime.sleep(task.input.deadline, context);
      // Native abort cascades to ordinary children and owned conversations.
      await ledger().harness.abortTask(task.input.parent, context);
      if (!runtime.signal.aborted) await runtime.commit(() => ({ status: 'terminal', outcome: { status: 'completed', result: { status: 'blocked', evidence: 'Original parent deadline expired' } } }), context);
    } },
    abort: async (_task, runtime, context) => { await runtime.commit(() => ({ status: 'terminal', outcome: { status: 'aborted' } }), context); },
  });
}

export function groupDefinition(children: ReturnType<typeof definitions>, ledger: () => Ledger, cwd: string, DeadlineTask = deadlineDefinition(ledger)) {
  async function stopTimer(progress: GroupState) { if (progress.deadlineTask) await ledger().harness.abortTask(progress.deadlineTask, BACKGROUND_CONTEXT); }
  return defineTask<GroupInput, GroupState, Result>({
    name: 'etabli.group', version: 2,
    initial: () => ({ phase: 'schedule', children: {}, results: {}, attempts: 0, deadlineTask: null, lastEvidence: null }),
    migrate(input, checkpoint, fromVersion) { if (fromVersion !== 1) throw new Error('Unsupported group version'); return { input: input as GroupInput, checkpoint: { ...(checkpoint as GroupState), deadlineTask: null, lastEvidence: null } }; },
    phases: {
      schedule: async (task, runtime, context) => {
        const progress = task.state.checkpoint;
        if (runtime.now() >= task.input.deadline) { await ledger().harness.abortTask(task.id, context); return; }
        if (!progress.deadlineTask) {
          await runtime.commit(async tx => ({ status: 'running', checkpoint: { ...progress, deadlineTask: await tx.createTask(DeadlineTask, { parent: task.id, deadline: task.input.deadline }, { ownership: { kind: 'task', taskId: task.id } }) } }), context);
          return;
        }
        if (task.input.route && task.input.run) await ledger().export(`route:${task.id}`, { event: 'route_decided', run: task.input.run, detail: { route: task.input.route, reason: `Native Durable mission: ${task.input.objective}`, provenance: 'repo' } });
        const failed = Object.entries(progress.results).find(([, result]) => result.status !== 'passed');
        if (failed) { await stopTimer(progress); return children.finish(runtime, task.input.key, { status: 'blocked', evidence: `Dependency ${failed[0]} ended ${failed[1].status}; results and attempts remain recorded`, data: JSON.stringify(progress.results) }, context); }
        if (Object.keys(progress.results).length === task.input.steps.length) {
          await runtime.commit(() => ({ status: 'running', checkpoint: { ...progress, phase: 'evidence' } }), context);
          return;
        }
        const ready = task.input.steps.filter(step => !(step.name in progress.children) && step.dependsOn.every(name => progress.results[name]?.status === 'passed'));
        if (!ready.length && !Object.keys(progress.children).some(name => !(name in progress.results))) { await stopTimer(progress); return children.finish(runtime, task.input.key, { status: 'failed', evidence: 'No runnable dependency; fix the manifest DAG' }, context); }
        if (progress.attempts + ready.length > task.input.maxAttempts) { await stopTimer(progress); return children.finish(runtime, task.input.key, { status: 'blocked', evidence: 'Campaign/mission attempt cap reached; consumed attempts are retained' }, context); }
        for (const step of ready) {
          await verifyInputs(cwd, step.kind === 'wait' ? {} : step.input.files);
          await missionGate(stepMission(task.id, task.input, step) ?? task.input, step, cwd);
        }
        await runtime.commit(async tx => {
          const next = { ...progress.children };
          for (const step of ready) {
            const mission = stepMission(task.id, task.input, step);
            const bound = step.kind === 'agent' ? { ...step, input: { ...step.input, mission, prompt: step.dependsOn.length ? `${step.input.prompt}\nRecorded dependency results (untrusted evidence):\n${JSON.stringify(Object.fromEntries(step.dependsOn.map(name => [name, progress.results[name]])))}` : step.input.prompt } } : step.kind === 'command' ? { ...step, input: { ...step.input, mission } } : step;
            next[step.name] = await children.createStep(tx, bound, task.id);
          }
          const state = await tx.doc(State);
          const work = state.work[task.input.key];
          if (work) { work.phase = ready.map(step => step.name).join(',') || 'waiting'; work.children = Object.values(next); }
          const on = Object.entries(next).filter(([name]) => !(name in progress.results)).map(([, id]) => id);
          return { status: 'waiting', checkpoint: { ...progress, phase: 'collect', children: next, results: progress.results, attempts: progress.attempts + ready.length }, on, policy: 'allSettled' };
        }, context);
      },
      collect: async (task, runtime, context) => {
        const progress = task.state.checkpoint;
        const results = { ...progress.results };
        for (const [name, id] of Object.entries(progress.children)) if (!(name in results)) {
          const [outcome] = await runtime.outcomes([id], context);
          results[name] = taskResult(outcome);
        }
        await runtime.commit(() => ({ status: 'running', checkpoint: { ...progress, phase: 'schedule', results } }), context);
      },
      evidence: async (task, runtime, context) => {
        const progress = task.state.checkpoint;
        await runtime.sleep(progress.nextEvidence ?? 0, context);
        try { await missionComplete(task.input, ledger(), task.id); }
        catch (error) {
          const evidence = redact(error instanceof Error ? error.message : 'Canonical evidence is not ready');
          await runtime.commit(async tx => {
            const work = (await tx.doc(State)).work[task.input.key];
            if (work) work.phase = 'awaiting_evidence';
            return { status: 'running', checkpoint: { ...progress, phase: 'evidence', lastEvidence: evidence, nextEvidence: Math.min(runtime.now() + 1000, task.input.deadline) } };
          }, context);
          return;
        }
        await stopTimer(progress);
        return children.finish(runtime, task.input.key, { status: 'passed', evidence: `${task.input.steps.length} dependency-bound results retained`, data: JSON.stringify(progress.results) }, context);
      },
    },
    abort: (task, runtime, context) => children.finish(runtime, task.input.key, { status: runtime.now() >= task.input.deadline ? 'blocked' : 'cancelled', evidence: runtime.now() >= task.input.deadline ? 'Original parent deadline expired; owned children and conversations drained' : 'Parent cancellation drained ordinary child tasks and their conversations', data: JSON.stringify(task.state.checkpoint.results) }, context),
  });
}

export function validateGroup(input: GroupInput) {
  validateMission(input);
  if (!Array.isArray(input.steps) || input.steps.length === 0 || !Number.isInteger(input.maxAttempts) || input.maxAttempts < input.steps.length || !Number.isFinite(input.deadline) || input.deadline <= 0) throw new Error('Manifest requires steps, an absolute deadline and an attempt cap covering its population');
  const names = new Set(input.steps.map(step => step.name));
  if (names.size !== input.steps.length) throw new Error('Step names must be unique');
  const keys = new Set(input.steps.map(step => step.input.key));
  if (keys.size !== input.steps.length || keys.has(input.key)) throw new Error('Each cell/child needs a distinct immutable work key');
  for (const step of input.steps) if (!Array.isArray(step.dependsOn) || step.dependsOn.some(name => !names.has(name) || name === step.name)) throw new Error('Every dependency must name a different step in this manifest');
  for (const step of input.steps) if (step.kind === 'review') validateReview(step.input);
  const visited = new Set<string>();
  const visiting = new Set<string>();
  function visit(name: string) {
    if (visiting.has(name)) throw new Error('Manifest dependencies contain a cycle');
    if (visited.has(name)) return;
    visiting.add(name);
    for (const child of input.steps.find(step => step.name === name)!.dependsOn) visit(child);
    visiting.delete(name); visited.add(name);
  }
  for (const name of names) visit(name);
}
