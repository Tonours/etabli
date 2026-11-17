import type { Frame } from "../web-src/activity.ts";
import type { Run } from "../web-src/api.ts";
import { Store, type Env } from "../web-src/store.ts";

export type Call = { path: string; method: string; body?: unknown; authorization?: string };
export type Reply = { status: number; body?: unknown; raw?: string };
export type Handler = (call: Call) => Reply | Promise<Reply>;
export const A = "aaaaaaaa-1111-4111-8111-111111111111", B = "22222222-2222-4222-8222-222222222222";
export const listed = (id: string, status = "implementing", extra: Partial<Run> = {}): Run => ({ id, status, reason: "", url: "", prompt: `task ${id}`, repo: "Tonours/fixture", route: "answer", createdAt: 1000, startedAt: 2000, deadline: 0, maxTurns: 64, ...extra });
export const ok = (value: unknown): Reply => ({ status: 200, body: { ok: true, value } });

export class FakeSocket {
  static all: FakeSocket[] = [];
  closed = false;
  readonly url: string;
  private readonly listeners = new Map<string, ((event: { data?: unknown }) => void)[]>();
  constructor(url: string) { this.url = url; FakeSocket.all.push(this); }
  addEventListener(name: string, listener: (event: { data?: unknown }) => void) { this.listeners.set(name, [...this.listeners.get(name) ?? [], listener]); }
  emit(name: string, data?: unknown) { for (const listener of this.listeners.get(name) ?? []) listener({ data }); }
  frame(value: Frame) { this.emit("message", JSON.stringify({ kind: "value", value })); }
  close() { if (this.closed) return; this.closed = true; this.emit("close"); }
  drop() { this.closed = true; this.emit("close"); }
}

export function harness(initialRuns: Run[] = [listed(A), listed(B)]) {
  FakeSocket.all = [];
  const calls: Call[] = [];
  const timers = new Map<number, () => void>();
  let sequence = 0, uuid = 0;
  let runs = initialRuns, hash = "";
  const routes: Handler[] = [];
  const fallback: Handler = ({ path }) => path === "/v1/runs" ? ok(runs) : path.endsWith("/plan") ? ok({ enabled: true, status: "DRAFT", sections: { Goal: "goal" } }) : path === "/v1/schedules" ? ok([]) : ok({});
  const env: Env = {
    fetch: async (path, init) => {
      const headers = init.headers as Record<string, string>;
      const call: Call = { path, method: init.method ?? "GET", body: init.body ? JSON.parse(String(init.body)) : undefined, authorization: headers.Authorization };
      calls.push(call);
      const reply = await (routes.find(() => true) ?? fallback)(call);
      return new Response(reply.raw ?? JSON.stringify(reply.body ?? null), { status: reply.status });
    },
    WebSocket: FakeSocket, origin: "https://fixture.invalid",
    setTimeout: (callback) => { const id = ++sequence; timers.set(id, callback); return id; },
    clearTimeout: (id) => { if (id !== undefined) timers.delete(id); },
    uuid: () => `request-${++uuid}`, hidden: () => false, hash: () => hash,
  };
  const store = new Store(env);
  return {
    store, env, calls, timers, fallback,
    use(handler: Handler) { routes.unshift(handler); return () => { routes.splice(routes.indexOf(handler), 1); }; },
    setRuns(next: Run[]) { runs = next; },
    setHash(next: string) { hash = next; },
    open: () => FakeSocket.all.filter((socket) => !socket.closed),
    async signIn() { await store.login("F".repeat(43)); },
  };
}
export const settle = () => new Promise<void>((resolve) => setTimeout(resolve, 0));
export function deferred<T>() { let resolve!: (value: T) => void; const promise = new Promise<T>((done) => { resolve = done; }); return { promise, resolve }; }
