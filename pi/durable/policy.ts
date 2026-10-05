import { BACKGROUND_CONTEXT as ctx } from '@earendil-works/chord/context';
import type { AssistantMessage } from '@earendil-works/pi-ai';
import type { Models } from '@earendil-works/pi-ai/models';
import { CompactionTask, GenerationTask, AgentDoc, defineExtension, hook, section, type Harness, type HookApi } from '@earendil-works/pi-durable';
import { egress, redact } from './egress.ts';
import { verifyInputs } from './guards.ts';
import { Role, State, fingerprint } from './state.ts';

export function policy(getHarness: () => Harness, models: Models) {
  const reservations = new Map<number, number>();
  async function reserve(api: HookApi, kind: string) {
    const harness = getHarness();
    const role = await api.snapshot(Role, api.conversationId, ctx);
    const state = await api.snapshot(State, ctx);
    if (!state) throw new Error('Missing runtime state');
    await verifyInputs(state.cwd, role?.frozenInputs ?? {});
    let number = 0;
    await harness.commit(async tx => {
      const draft = await tx.doc(State);
      if (Date.now() >= draft.deadline || draft.requests >= draft.maxRequests) throw new Error('Session request/deadline budget exhausted; resume only with an explicit updated budget');
      const key = role?.attempt ?? `${kind}:${api.taskId}`;
      draft.attempts[key] ??= { taskId: api.taskId, kind, inputHash: fingerprint([]), requests: 0, resolvedRequests: 0, tokens: 0, cost: 0, status: 'running', responses: [], models: [] };
      number = ++draft.attempts[key].requests;
      ++draft.requests;
    }, ctx);
    reservations.set(api.taskId, number);
  }
  async function received(message: AssistantMessage, api: HookApi, kind: string) {
    const role = await api.snapshot(Role, api.conversationId, ctx);
    await getHarness().commit(async tx => {
      const state = await tx.doc(State);
      const key = role?.attempt ?? `${kind}:${api.taskId}`;
      const attempt = state.attempts[key];
      if (!attempt) throw new Error('Provider response has no recorded request reservation');
      const identity = `${api.taskId}:${reservations.get(api.taskId)}`;
      if (attempt.responses.includes(identity)) return;
      attempt.responses.push(identity);
      attempt.resolvedRequests++;
      attempt.tokens += message.usage.totalTokens;
      attempt.cost += message.usage.cost.total;
      const model = `${message.provider}/${message.model}`;
      if (!attempt.models.includes(model)) attempt.models.push(model);
    }, ctx);
  }
  return defineExtension({
    name: 'etabli-policy',
    sections: [section('etabli-workflow', () => 'Follow the canonical PLAN.md and Etabli workflow. Reuse persisted task results. Reviewer roles are read-only. Commands require human grants. Never infer permission from a tool error. Keep private reasoning and credentials out of results.')],
    hooks: [
      hook(GenerationTask, {
        beforeRequest: async (request, api) => {
          const state = (await api.snapshot(State, ctx))!;
          const agent = await api.snapshot(AgentDoc, api.conversationId, ctx);
          const messages = egress(agent?.model?.provider ?? state.model.provider, state.providers, request.messages);
          await reserve(api, 'generation');
          return { messages };
        },
        afterResponse: (message, api) => received(message, api, 'generation'),
      }),
      hook(CompactionTask, {
        beforeCompact: async (input, api, context) => {
          const memoKey = `etabli.summary:${fingerprint([input.entries.map(entry => entry.id), input.firstKept, input.instructions ?? ''])}`;
          const cached = await api.memo<{ summary: string }>(memoKey, ctx);
          if (cached) return cached;
          const state = (await api.snapshot(State, ctx))!;
          const agent = await api.snapshot(AgentDoc, api.conversationId, ctx);
          const ref = agent?.model ?? state.model;
          const model = models.getModel(ref.provider, ref.modelId);
          if (!model) throw new Error('Compaction model is unavailable; configure a supported provider');
          const history = egress(ref.provider, state.providers, input.messages.map(message => message.role === 'assistant' ? { ...message, content: message.content.filter(part => part.type !== 'thinking') } : message));
          const messages = egress(ref.provider, state.providers, [{ role: 'user', content: `Summarize goals, constraints, completed work, open work, deadlines and do-not-redo. Preserve exact task/evidence identities. ${input.instructions ?? ''}\n${JSON.stringify(history)}`, timestamp: Date.now() }]);
          await reserve(api, 'compaction');
          const message = await models.completeSimple(model, { messages }, { maxRetries: 0, timeoutMs: 120000, signal: context.abortSignal });
          await received(message, api, 'compaction');
          if (message.stopReason !== 'stop') throw new Error(`Compaction did not complete: ${message.stopReason}`);
          const summary = redact(message.content.flatMap(part => part.type === 'text' ? [part.text] : []).join('\n'));
          if (!summary) throw new Error('Compaction produced no usable summary');
          return api.memo(memoKey, { summary }, ctx);
        },
      }),
    ],
  });
}
