import { expect, test } from "bun:test";
import { readFile } from "node:fs/promises";
import { runInNewContext } from "node:vm";

type Reply = { status: number; ok: boolean; json(): Promise<unknown> };
type Element = { value: string; hidden: boolean; disabled: boolean; textContent: string; addEventListener(): void; setAttribute(): void; replaceChildren(): void; append(): void; querySelector(): Element };
type UI = { openRun(id: string): Promise<void>; api(path: string): Promise<unknown>; setupPush(): Promise<void>; start(): void };

async function browserClient() {
  const elements = new Map<string, Element>();
  const element = (): Element => ({ value: "", hidden: false, disabled: false, textContent: "", addEventListener() {}, setAttribute() {}, replaceChildren() { this.textContent = ""; }, append() {}, querySelector: element });
  const node = (id: string) => { if (!elements.has(id)) elements.set(id, element()); return elements.get(id)!; };
  const timers = new Map<number, () => unknown>();
  let sequence = 0;
  const sockets: Socket[] = [];
  class Socket {
    closed = false;
    listeners = new Map<string, (() => void)[]>();
    constructor(_url: string) { sockets.push(this); }
    addEventListener(name: string, listener: () => void) { this.listeners.set(name, [...this.listeners.get(name) ?? [], listener]); }
    close() { if (this.closed) return; this.closed = true; queueMicrotask(() => this.listeners.get("close")?.forEach((listener) => listener())); }
  }
  let fetcher = async (_path: string, _method: string): Promise<Reply> => ({ status: 401, ok: false, json: async () => ({}) });
  const navigator: Record<string, unknown> = {}, window: Record<string, unknown> = { addEventListener() {} };
  const realm: Record<string, unknown> = {
    document: { getElementById: node, createElement: element, hidden: false }, window, navigator,
    location: { origin: "https://fixture.invalid" }, WebSocket: Socket, atob, Uint8Array,
    fetch: (path: string, options: { method?: string }) => fetcher(path, options?.method ?? "GET"),
    setInterval: () => 1, setTimeout: (callback: () => unknown) => { const id = ++sequence; timers.set(id, callback); return id; }, clearTimeout: (id: number) => timers.delete(id),
  };
  const source = await readFile(new URL("../web/app.js", import.meta.url), "utf8");
  runInNewContext(`${source}\nglobalThis.ui = { openRun, api, setupPush, start() { signedIn = true; } };`, realm);
  await new Promise<void>((resolve) => setImmediate(resolve));
  return { ui: realm.ui as UI, node, timers, sockets, navigator, window, fetch: (value: typeof fetcher) => { fetcher = value; } };
}

const run = { id: "11111111-1111-4111-8111-111111111111", status: "implementing", repo: "Tonours/fixture", prompt: "watch fixture", createdAt: 1000 };
const success = (value: unknown): Reply => ({ status: 200, ok: true, json: async () => ({ ok: true, value }) });
const runsReply = async (path: string) => success(path === "/v1/runs" ? [run] : path.endsWith("/plan") ? null : { run, entries: [] });

test("reopening the same run never schedules a stale retry or leaves an orphan watch", async () => {
  const b = await browserClient(); b.fetch(runsReply); b.ui.start();
  await b.ui.openRun(run.id); await b.ui.openRun(run.id);
  expect(b.timers.size).toBe(0);
  expect(b.sockets.filter((socket) => !socket.closed)).toHaveLength(1);
  await Promise.all([b.ui.openRun(run.id), b.ui.openRun(run.id)]);
  await Promise.resolve();
  expect(b.timers.size).toBe(0);
  expect(b.sockets.filter((socket) => !socket.closed)).toHaveLength(1);
});

test("an unexpected watch drop schedules exactly one reconnect, while changing runs cancels it", async () => {
  const b = await browserClient(); b.fetch(runsReply); b.ui.start();
  await b.ui.openRun(run.id); b.sockets.at(-1)!.close(); await Promise.resolve();
  expect(b.timers.size).toBe(1);
  const callback = [...b.timers.values()][0]; b.timers.clear(); await callback();
  expect(b.sockets.filter((socket) => !socket.closed)).toHaveLength(1);
  b.sockets.at(-1)!.close(); await Promise.resolve();
  await b.ui.openRun("22222222-2222-4222-8222-222222222222");
  expect(b.timers.size).toBe(0);
  expect(b.sockets.filter((socket) => !socket.closed)).toHaveLength(1);
});

test("non-JSON proxy failures show connection guidance and successful JSON remains readable", async () => {
  const b = await browserClient();
  b.fetch(async () => ({ status: 502, ok: false, json: async () => { throw new SyntaxError("Unexpected end of JSON input"); } }));
  await expect(b.ui.api("/v1/runs")).rejects.toThrow("Daemon unavailable");
  b.fetch(async () => success(["readable"]));
  expect(await b.ui.api("/v1/runs")).toEqual(["readable"]);
});

test("non-JSON authorization refusals still clear the private displayed run data", async () => {
  const b = await browserClient(); b.ui.start(); b.node("stream").textContent = "private run fixture"; b.node("workspace").hidden = false;
  b.fetch(async () => ({ status: 403, ok: false, json: async () => { throw new SyntaxError("HTML refusal"); } }));
  await expect(b.ui.api("/v1/runs")).rejects.toThrow("Session unavailable");
  expect(b.node("stream").textContent).toBe(""); expect(b.node("workspace").hidden).toBe(true);
});

test("push setup discards a subscription bound to an old VAPID key but reuses a current one", async () => {
  for (const matches of [false, true]) {
    const b = await browserClient(); b.ui.start();
    const expected = Uint8Array.from([4, ...Array<number>(64).fill(1)]);
    const actual = matches ? expected : Uint8Array.from([4, ...Array<number>(64).fill(2)]);
    let removed = 0;
    const methods: string[] = [];
    b.navigator.serviceWorker = { register: async () => ({ pushManager: { getSubscription: async () => ({ endpoint: "https://fcm.googleapis.com/fcm/send/fixture", options: { applicationServerKey: actual.buffer }, unsubscribe: async () => { removed++; return true; } }) } }), ready: Promise.resolve() };
    b.window.PushManager = class {};
    b.fetch(async (path, method) => { if (path.endsWith("/key")) return success({ publicKey: Buffer.from(expected).toString("base64url") }); methods.push(method); return success({ deleted: true }); });
    await b.ui.setupPush();
    expect(removed).toBe(matches ? 0 : 1);
    expect(methods).toEqual([matches ? "POST" : "DELETE"]);
    expect(b.node("subscribe").hidden).toBe(matches);
    expect(b.node("unsubscribe").hidden).toBe(!matches);
  }
});
