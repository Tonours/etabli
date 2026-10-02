import { BACKGROUND_CONTEXT as ctx } from '@earendil-works/chord/context';
import { LiveDoc, defineDoc, type Harness, type ConversationId, type Tx, type TaskId } from '@earendil-works/pi-durable';
import { State, fingerprint, type Result } from './state.ts';
import { redact } from './egress.ts';

const Public = defineDoc<{ seq: number; hash: string }>({ kind: 'etabli.public', version: 1, scope: 'session', initial: () => ({ seq: 0, hash: '' }) });

export async function reconcileWork(tx: Tx) {
  const state = await tx.doc(State);
  for (const work of Object.values(state.work)) {
    const task = await tx.task(work.taskId);
    if (task?.state.status !== 'terminal') continue;
    const outcome = task.state.outcome;
    if (!work.result) {
      const result = outcome.status === 'completed' ? outcome.result as Result : { status: outcome.status === 'aborted' ? 'cancelled' as const : 'failed' as const, evidence: `Native ${outcome.status}; inspect task ${task.id}` };
      work.result = result; work.phase = result.status;
    }
    if (state.writerTaskId === task.id) state.writerTaskId = null;
    for (const attempt of Object.values(state.attempts)) if (attempt.taskId === task.id) attempt.status = work.result.status;
  }
  if (state.writerTaskId !== null && (await tx.task(state.writerTaskId as TaskId))?.state.status === 'terminal') state.writerTaskId = null;
}

async function view(tx: Tx, root: ConversationId) {
  await reconcileWork(tx);
  const entries = await tx.scanEntries({ conversationId: root }, 200);
  const tasks = await tx.scanTasks({}, 1000);
  let next = tasks.next;
  const allTasks = [...tasks.items];
  while (next) { const page = await tx.scanTasks({}, 1000, next); allTasks.push(...page.items); next = page.next; }
  const state = await tx.doc(State);
  const live = await tx.doc(LiveDoc, root);
  const messages = entries.items.toReversed().flatMap(entry => (entry.model ?? []).flatMap(message => {
    if (message.role !== 'user' && message.role !== 'assistant') return [];
    const text = typeof message.content === 'string' ? message.content : message.content.flatMap(part => part.type === 'text' ? [part.text] : []).join('\n');
    return text ? [{ id: String(entry.id), role: message.role, text: redact(text), toolName: null, isError: false }] : [];
  }));
  const attempts = Object.values(state.attempts);
  const workRows = Object.entries(state.work).map(([key, work]) => {
    const result = work.result?.status ?? null;
    return { key: redact(key), taskId: work.taskId, kind: work.kind, phase: result ?? work.phase, result, children: work.children };
  });
  const workflow = {
    budget: { requests: state.requests, limit: state.maxRequests, unknownRequests: attempts.reduce((total, attempt) => total + attempt.requests - attempt.resolvedRequests, 0), tokens: attempts.reduce((total, attempt) => total + attempt.tokens, 0), cost: attempts.reduce((total, attempt) => total + attempt.cost, 0), deadline: state.deadline },
    work: workRows,
    tasks: allTasks.map(task => ({ taskId: task.id, kind: task.kind, conversation: task.conversationId, parent: task.owner ?? null, status: task.state.status, phase: 'checkpoint' in task.state ? String((task.state.checkpoint as { phase?: string }).phase ?? '') : null, dependencies: task.state.status === 'waiting' ? task.state.on : [], abortRequested: task.abortRequested ?? false })),
    unresolvedEffects: Object.values(state.effects).filter(effect => effect.status === 'uncertain').map(effect => ({ taskId: effect.taskId, action: effect.action })),
    compactions: allTasks.filter(task => task.kind === 'pi.compaction').map(task => ({ taskId: task.id, status: task.state.status })),
    doNotRedo: Object.entries(state.work).filter(([, work]) => work.result?.status === 'passed').map(([key]) => redact(key)),
  };
  const snapshot = { sessionId: state.sessionId, conversationId: root, leafId: entries.items[0] ? String(entries.items[0].id) : null, messages, state: { model: { ...state.model, name: state.model.modelId }, streaming: Boolean(live.run), sessionFile: null, sessionName: 'Etabli Durable', cwd: state.cwd, durableAdmission: true, workflow } };
  const publicState = await tx.doc(Public);
  const hash = fingerprint(snapshot);
  if (publicState.hash !== hash) { publicState.hash = hash; publicState.seq++; }
  return { state, snapshot: { seq: publicState.seq, ...snapshot } };
}

export async function projection(harness: Harness, root: ConversationId) {
  return harness.commit(async tx => {
    const { snapshot } = await view(tx, root);
    return JSON.parse(JSON.stringify(snapshot)) as typeof snapshot;
  }, ctx);
}

export async function handoffProjection(harness: Harness, root: ConversationId) {
  return harness.commit(async tx => {
    const { state, snapshot } = await view(tx, root);
    const handoff = { ...snapshot, recovery: { cwd: state.cwd, work: Object.entries(state.work).map(([key, work]) => ({ key, ...work })), attempts: state.attempts, budgetChanges: state.budgetChanges ?? [], effects: state.effects, exports: state.exports } };
    return JSON.parse(JSON.stringify(handoff)) as typeof handoff;
  }, ctx);
}
