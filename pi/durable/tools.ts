import type { Context } from '@earendil-works/chord';
import { Type, type Static, type TSchema } from 'typebox';
import { createReadTool, createWriteTool, createEditTool } from '@earendil-works/pi-durable/tools';
import { defineExtension, defineTool, type ToolRegistration, type ToolExecutionApi } from '@earendil-works/pi-durable';
import { guard, verifyInputs, workspacePath, effectKey, fileHash } from './guards.ts';
import { State, Role, fingerprint } from './state.ts';
import { redact } from './egress.ts';
import type { Ledger } from './ledger.ts';
import { mutationRun, recordMutation, executionMission, missionGate } from './missions.ts';

function guarded<S extends TSchema>(tool: ToolRegistration<S>, mutation: boolean, ledger: () => Ledger): ToolRegistration<S> {
  return {
    ...tool, replay: mutation ? 'unsafe' : 'safe', executionMode: 'sequential',
    async execute(args: Static<S>, api: ToolExecutionApi, context: Context) {
      const agent = await api.agent(context);
      const state = await api.snapshot(State, context);
      const role = await api.snapshot(Role, api.conversationId, context);
      if (!state || agent.cwd !== state.cwd) throw new Error('Current tool cwd does not match the recorded workspace');
      if (mutation && role?.role !== 'writer') throw new Error('Reviewer tools are read-only');
      const record = args as Record<string, unknown>;
      const target = await workspacePath(state.cwd, String(record.path));
      await verifyInputs(state.cwd, role?.frozenInputs ?? {});
      guard(state.cwd, tool.name, { ...record, path: target });
      const scope = state.sessionId;
      const key = effectKey('file.write', target, scope);
      const writer = role?.attempt ? state.attempts[role.attempt]?.taskId : api.taskId;
      const beforeHash = mutation ? await fileHash(target) : null;
      const mission = mutation ? await executionMission(state.cwd, role?.mission, state.deadline) : null;
      const step = { name: 'native-write', kind: 'agent' as const, dependsOn: [], input: { key: `tool:${api.taskId}`, prompt: '', role: 'writer' as const, model: null, files: {}, review: false } };
      if (mutation && mission) await missionGate(mission, step, state.cwd);
      if (mutation) {
        await api.commit(async tx => {
          const draft = await tx.doc(State);
          if (draft.writerTaskId !== null && (await tx.task(draft.writerTaskId as Parameters<typeof tx.task>[0]))?.state.status === 'terminal') draft.writerTaskId = null;
          if (draft.writerTaskId !== null && draft.writerTaskId !== writer) throw new Error('Another owned writer is active; join it before mutating');
          const old = draft.effects[key];
          if (old?.status === 'uncertain' && (!('beforeHash' in old) || old.beforeHash !== beforeHash)) throw new Error('An earlier write to this target is unresolved; reconcile it before a new tool call');
          draft.writerTaskId = writer ?? api.taskId;
          draft.effects[key] = { action: 'file.write', target, scope, taskId: api.taskId, status: 'uncertain', receipt: null, beforeHash };
        }, context);
      }
      let successful = false;
      try {
        if (mutation) {
          const run = mutationRun(state.cwd, mission);
          await recordMutation(ledger(), `mutation:tool:${api.taskId}`, run, target, `Native ${tool.name} reserved before execution; task ${api.taskId}`);
          const currentAgent = await api.agent(context);
          const currentState = await api.snapshot(State, context);
          const currentRole = await api.snapshot(Role, api.conversationId, context);
          if (!currentState || currentState.cwd !== state.cwd || currentAgent.cwd !== currentState.cwd || currentRole?.role !== 'writer' || currentState.writerTaskId !== (writer ?? api.taskId)) throw new Error('Current writer authority changed during export; refresh the mission before a fresh action');
          if (currentRole.attempt !== role?.attempt || fingerprint(currentRole.mission) !== fingerprint(role?.mission)) throw new Error('Recorded writer mission changed during export; restore its original authority before a fresh action');
          if (await workspacePath(currentState.cwd, String(record.path)) !== target) throw new Error('Tool target changed during export; reconcile the original intent before a fresh action');
          await verifyInputs(currentState.cwd, currentRole.frozenInputs);
          guard(currentState.cwd, tool.name, { ...record, path: target });
          const currentMission = await executionMission(currentState.cwd, currentRole.mission, currentState.deadline);
          if (mutationRun(currentState.cwd, currentMission) !== run || currentMission?.route !== mission?.route) throw new Error('Selected mission changed during export; use a fresh action in its recorded run');
          if (await fileHash(target) !== beforeHash) throw new Error('Target changed during mutation export; reconcile this effect before a new write');
          if (currentMission) await missionGate(currentMission, step, currentState.cwd);
          mutationRun(currentState.cwd, currentMission);
        }
        const output = await tool.execute({ ...args, path: target }, api, context);
        successful = !output.isError;
        return { ...output, content: output.content?.map(part => part.type === 'text' ? { ...part, text: redact(part.text) } : part) };
      } finally {
        if (mutation) {
          const currentTarget = await workspacePath(state.cwd, String(record.path)).catch(() => null);
          const unchanged = currentTarget === target && await fileHash(target) === beforeHash;
          await api.commit(async tx => {
            const draft = await tx.doc(State);
            const effect = draft.effects[key];
            if (successful || unchanged) { effect.status = 'verified'; effect.receipt = `tool:${api.taskId}:${successful ? 'applied' : 'no-change'}`; }
            if (!role?.attempt && draft.writerTaskId === api.taskId) draft.writerTaskId = null;
          }, context);
        }
      }
    },
  };
}

export function tools(run: (grantId: string, api: ToolExecutionApi, context: Context) => Promise<string>, ledger: () => Ledger) {
  return defineExtension({
    name: 'etabli-tools',
    tools: [
      guarded(createReadTool(), false, ledger), guarded(createWriteTool(), true, ledger), guarded(createEditTool(), true, ledger),
      defineTool({
        name: 'run_granted_command', description: 'Run a human-granted exact command once as an owned durable task. Unresolved effects require human reconciliation.',
        parameters: Type.Object({ grantId: Type.String() }), replay: 'safe', executionMode: 'sequential',
        async execute({ grantId }, api, context) {
          const role = await api.snapshot(Role, api.conversationId, context);
          const agent = await api.agent(context);
          const state = await api.snapshot(State, context);
          if (role?.role !== 'writer' || !state || agent.cwd !== state.cwd) throw new Error('Only the current writer may execute a granted command');
          return { content: [{ type: 'text', text: redact(await run(grantId, api, context)) }] };
        },
      }),
    ],
  });
}
