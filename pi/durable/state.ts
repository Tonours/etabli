import { defineDoc, type ConversationId, type TaskId } from '@earendil-works/pi-durable';
import { createHash } from 'node:crypto';

export const fingerprint = (value: unknown) => createHash('sha256').update(JSON.stringify(value, (_key, part) => part && typeof part === 'object' && !Array.isArray(part) ? Object.fromEntries(Object.entries(part).sort(([a], [b]) => a.localeCompare(b))) : part)).digest('hex');
export type Json = string | number | boolean | null | Json[] | { [key: string]: Json };
export type Result = { status: 'passed' | 'failed' | 'blocked' | 'cancelled'; evidence: string; data?: string };
export type Model = { provider: string; modelId: string };
export type MissionContext = { route: 'goal' | 'plan-implement' | 'ship'; run: string; deadline: number; parent?: number; step?: string; waits?: { key: string; repo: string; pr: number; head: string; deadline: number; intervalMs: number; fixture: string | null }[] };
export type Grant = { action: string; target: string; argv: string[]; cwd: string; expiresAt: number; evidence: string; usedBy: number | null; consumer?: string | null };
export type Effect = { action: string; target: string; scope: string; taskId: number; status: 'uncertain' | 'verified'; receipt: string | null; beforeHash?: string | null };
export type Work = { taskId: TaskId<Result>; kind: string; inputHash: string; phase: string; result: Result | null; children: number[] };
export type Attempt = { taskId: number; kind: string; inputHash: string; requests: number; resolvedRequests: number; tokens: number; cost: number; status: string; responses: string[]; models: string[] };
export type Admission = { session: string; conversation: ConversationId; text: string; deliverAs: 'steer' | 'followUp' | null; submissionId: number | null };
export type Export = { event: string; run: string; detail: Record<string, Json>; acknowledged: boolean; error?: string | null; precondition?: string | null; abandoned?: string | null };
export type RuntimeState = {
  sessionId: string;
  cwd: string;
  model: Model;
  providers: string[];
  maxRequests: number;
  requests: number;
  deadline: number;
  writerTaskId: number | null;
  work: Record<string, Work>;
  attempts: Record<string, Attempt>;
  grants: Record<string, Grant>;
  effects: Record<string, Effect>;
  admissions: Record<string, Admission>;
  exports: Record<string, Export>;
  compactions: Record<string, { taskId: number; status: string }>;
  budgetChanges?: { maxRequests: number; deadline: number; evidence: string; at: number; consumed: number }[];
};

export const State = defineDoc<RuntimeState>({
  kind: 'etabli.runtime', version: 1, scope: 'session',
  initial: () => ({ sessionId: '', cwd: '', model: { provider: '', modelId: '' }, providers: [], maxRequests: 200, requests: 0, deadline: 0, writerTaskId: null, work: {}, attempts: {}, grants: {}, effects: {}, admissions: {}, exports: {}, compactions: {} }),
});

type RuntimeRole = { role: 'writer' | 'reviewer'; attempt: string | null; frozenInputs: Record<string, string>; mission: MissionContext | null };
export const Role = defineDoc<RuntimeRole>({
  kind: 'etabli.role', version: 2, scope: 'conversation', history: 'latest', fork: 'initial',
  initial: () => ({ role: 'writer', attempt: null, frozenInputs: {}, mission: null }),
  migrate(value, fromVersion): RuntimeRole { if (fromVersion !== 1) throw new Error('Unsupported role version'); return { ...value, mission: null } as RuntimeRole; },
});

export function requireKey(value: unknown): asserts value is string {
  if (typeof value !== 'string' || !/^[a-zA-Z0-9][a-zA-Z0-9._:-]{0,159}$/.test(value)) throw new Error('Expected a stable key of 1–160 letters, digits, dots, underscores, colons or hyphens');
}

export function requireModel(value: unknown): asserts value is Model {
  if (!value || typeof value !== 'object' || !('provider' in value) || !('modelId' in value) || typeof value.provider !== 'string' || typeof value.modelId !== 'string' || !value.provider || !value.modelId) throw new Error('Expected provider and modelId');
}
