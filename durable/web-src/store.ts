import { BLOCK_LIMIT, entryBlock, liveBlock, queued, type Block, type Frame } from "./activity.ts";
import { createApi, StaleReply, type Fetch, type Method, type Plan, type Run, type Schedule } from "./api.ts";
import { ended } from "../shared/runs-view.ts";

export type Panel = "overview" | "activity" | "plan" | "instructions";
export type Tab = "runs" | "schedules";
export type Notice = { text: string; tone: "error" | "notice" };
export type Send = { status: "idle" | "sending" | "queued" | "failed"; error: string; ended?: boolean; content?: string };
export type Activity = { blocks: Block[]; live?: Block; omitted: boolean; lastId: number; follow: boolean; offset: number; queued: string[]; turns: number; maxTurns: number };
export type Push = { text: string; available: boolean; subscribed: boolean };
export type State = {
  session: "checking" | "out" | "in";
  message?: Notice;
  tab: Tab;
  runs?: Run[];
  selected?: string;
  panel: Panel;
  connection: "" | "connecting" | "connected" | "reconnecting";
  activity: Activity;
  plan?: Plan;
  draft: string;
  send: Send;
  abort: { open: boolean; error: string };
  schedules?: Schedule[];
  form: { repo: string; prompt: string; cron: string };
  deleting: string[];
  busy: string[];
  push: Push;
};

type Socket = { addEventListener(name: string, listener: (event: { data?: unknown }) => void): void; close(): void };
type Subscription = { endpoint: string; options: { applicationServerKey: ArrayBuffer | null }; unsubscribe(): Promise<boolean> };
export type Registration = { pushManager: { getSubscription(): Promise<Subscription | null>; subscribe(options: { userVisibleOnly: boolean; applicationServerKey: Uint8Array<ArrayBuffer> }): Promise<Subscription> } };
export type Env = {
  fetch: Fetch;
  WebSocket: new (url: string) => Socket;
  origin: string;
  setTimeout(callback: () => void, ms: number): number;
  clearTimeout(id: number | undefined): void;
  uuid(): string;
  hidden(): boolean;
  hash(): string;
  push?: { register(): Promise<Registration>; requestPermission(): Promise<string> };
};

const PUSH_HELP = "Notifications contain no run content and stay enabled after sign-out. Use Disable notifications to stop them. On iPhone or iPad, use Share → Add to Home Screen, then open the app before enabling notifications.";
const RUN_ID = /^[a-f0-9-]{36}$/;
const idle = (): Send => ({ status: "idle", error: "" });
const emptyActivity = (): Activity => ({ blocks: [], omitted: false, lastId: -1, follow: true, offset: 0, queued: [], turns: 0, maxTurns: 0 });
const initial = (push: Push): State => ({
  session: "out", tab: "runs", panel: "overview", connection: "", activity: emptyActivity(), draft: "", send: idle(),
  abort: { open: false, error: "" }, form: { repo: "", prompt: "", cron: "" }, deleting: [], busy: [], push,
});

export function applicationKey(value: string): Uint8Array<ArrayBuffer> {
  return Uint8Array.from(atob(value.replace(/-/g, "+").replace(/_/g, "/")), (char) => char.charCodeAt(0));
}

/** Client state for the PWA. Every reply is matched on the session generation and, for run replies, on the visit counter of the selection. */
export class Store {
  private state: State;
  private readonly listeners = new Set<() => void>();
  private readonly env: Env;
  private generation = 0;
  /** Run-list requests sent and the newest one applied: an older reply never overwrites a newer list. */
  private listed = 0;
  private applied = 0;
  private visit = 0;
  private socket?: Socket;
  private retry?: number;
  private refreshing = false;
  private steerIntent?: { id: string; content: string; requestId: string };
  private scheduleIntent?: { input: string; requestId: string };
  private registration?: Registration;
  private publicKey?: string;
  readonly api: <T>(path: string, method?: Method, value?: unknown, authorization?: string) => Promise<T>;

  constructor(env: Env) {
    this.env = env;
    this.state = { ...initial({ text: PUSH_HELP, available: true, subscribed: false }), session: "checking" };
    this.api = createApi(env.fetch, () => this.generation, () => this.clearSession());
  }

  get = (): State => this.state;
  subscribe = (listener: () => void): (() => void) => { this.listeners.add(listener); return () => { this.listeners.delete(listener); }; };
  private replace(state: State): void { this.state = state; for (const listener of this.listeners) listener(); }
  private set(patch: Partial<State>): void { this.replace({ ...this.state, ...patch }); }
  private activity(patch: Partial<Activity>): void { this.set({ activity: { ...this.state.activity, ...patch } }); }
  selectedRun(): Run | undefined { return this.state.runs?.find((run) => run.id === this.state.selected); }

  message(text = "", tone: Notice["tone"] = "error"): void { this.set({ message: text ? { text, tone } : undefined }); }

  /** Shows a failure unless it is a reply of an earlier session. */
  private report(error: unknown): void {
    if (!(error instanceof StaleReply)) this.message((error as Error).message);
  }

  private async busy(name: string, action: () => Promise<void>): Promise<void> {
    if (this.state.busy.includes(name)) return;
    const generation = this.generation;
    this.set({ busy: [...this.state.busy, name], message: undefined });
    try { await action(); } catch (error) { this.report(error); }
    finally { if (generation === this.generation) this.set({ busy: this.state.busy.filter((item) => item !== name) }); }
  }

  private stopWatch(): void {
    const previous = this.socket; this.socket = undefined;
    this.env.clearTimeout(this.retry); this.retry = undefined;
    previous?.close();
  }

  clearSession(): void {
    this.generation++; this.visit++;
    this.stopWatch();
    this.steerIntent = undefined; this.scheduleIntent = undefined; this.publicKey = undefined;
    this.replace(initial(this.state.push));
  }

  async connected(): Promise<void> {
    await this.listRuns();
    this.set({ session: "in" });
    this.route(this.env.hash());
    await this.setupPush().catch((error: Error) => this.pushState({ text: error.message }));
  }

  start(): void {
    this.connected().catch((error: Error) => {
      if (this.state.session === "in") this.message(error.message);
      else if (this.state.session === "checking") this.set({ session: "out" });
    });
  }

  login(token: string): Promise<void> {
    return this.busy("login", async () => {
      try { await this.api("/v1/browser/session", "POST", undefined, token); } finally { token = ""; }
      await this.connected();
    });
  }

  logout(): Promise<void> {
    return this.busy("logout", async () => { await this.api("/v1/browser/session", "DELETE"); this.clearSession(); this.message("Signed out.", "notice"); });
  }

  async listRuns(): Promise<void> {
    const sequence = ++this.listed;
    const runs = await this.api<Run[]>("/v1/runs");
    if (sequence < this.applied) return;
    this.applied = sequence;
    const before = this.selectedRun();
    this.set({ runs });
    const run = this.selectedRun();
    if (run && before && !ended(before) && ended(run)) this.runEnded();
  }

  /** Transition g: the selected run ended; controls go, the draft and a pending outcome stay for Overview. */
  private runEnded(): void {
    this.set({
      panel: this.state.panel === "instructions" ? "overview" : this.state.panel,
      abort: { open: false, error: "" },
      send: this.state.send.status === "idle" ? this.state.send : { ...this.state.send, ended: true },
    });
  }

  refresh(): Promise<void> { return this.busy("refresh", () => this.listRuns()); }

  showTab(tab: Tab): Promise<void> {
    return this.busy(`tab-${tab}`, async () => {
      this.set({ tab });
      if (tab === "runs") await this.listRuns(); else await this.loadSchedules();
    });
  }

  route(hash: string): void {
    if (this.state.session !== "in") return;
    const id = hash.replace(/^#/, "");
    if (!id) { this.select(undefined); return; }
    if (!RUN_ID.test(id) || !this.state.runs?.some((run) => run.id === id)) { this.select(undefined); this.message("That run is no longer available."); return; }
    this.select(id);
  }

  select(id: string | undefined): void {
    if (id === this.state.selected && (!id || this.socket)) return;
    this.visit++;
    this.stopWatch();
    this.steerIntent = undefined;
    this.set({ selected: id, panel: "overview", connection: "", activity: emptyActivity(), plan: undefined, draft: "", send: idle(), abort: { open: false, error: "" } });
    if (id) this.watch(id);
  }

  online(): void {
    const id = this.state.selected;
    if (this.state.session !== "in" || !id) return;
    this.watch(id);
    void this.listRuns().catch((error: unknown) => this.report(error));
  }

  private watch(id: string): void {
    if (this.state.session !== "in" || this.state.selected !== id) return;
    this.stopWatch();
    const current = new this.env.WebSocket(`${this.env.origin.replace(/^http/, "ws")}/v1/runs/${id}/watch`);
    this.socket = current;
    this.set({ connection: "connecting" });
    current.addEventListener("open", () => { if (this.socket === current) this.set({ connection: "connected" }); });
    current.addEventListener("message", (event) => {
      if (this.socket !== current) return;
      let frame: { kind?: string; value?: Frame };
      try { frame = JSON.parse(String(event.data)); } catch { this.message("The live stream returned an unreadable frame."); return; }
      if (frame.kind === "value" && frame.value) this.applyFrame(frame.value);
    });
    current.addEventListener("close", () => {
      if (this.socket !== current || this.state.session !== "in" || this.state.selected !== id) return;
      this.set({ connection: "reconnecting" });
      this.env.clearTimeout(this.retry);
      this.retry = this.env.setTimeout(() => { this.retry = undefined; if (this.socket === current && this.state.selected === id) this.watch(id); }, 2000);
    });
  }

  applyFrame(frame: Frame): void {
    const previous = this.state.activity;
    const blocks = [...previous.blocks];
    let { lastId, omitted } = previous;
    if (frame.before !== undefined) {
      if (lastId < 0) omitted = true;
      else if (frame.before > lastId) blocks.push({ id: `gap-${frame.before}`, parts: [], gap: true });
    }
    for (const entry of [...frame.entries ?? []].sort((a, b) => a.id - b.id)) {
      if (entry.id <= lastId) continue;
      lastId = entry.id;
      const block = entryBlock(entry);
      if (block) blocks.push(block);
    }
    const kept = previous.follow && blocks.length > BLOCK_LIMIT ? blocks.slice(-BLOCK_LIMIT) : blocks;
    const docs = frame.docs;
    this.activity({
      blocks: kept, lastId, omitted: omitted || kept.length < blocks.length, live: liveBlock(frame), queued: queued(frame),
      turns: docs?.["pi.live"]?.run?.turns ?? previous.turns, maxTurns: docs?.["pi.agent"]?.maxTurns ?? previous.maxTurns,
    });
  }

  /** Saved by the Activity panel: whether it follows the newest block, and its offset while it does not. */
  follow(follow: boolean, offset: number): void {
    const { blocks } = this.state.activity;
    if (follow && blocks.length > BLOCK_LIMIT) this.activity({ follow, offset, blocks: blocks.slice(-BLOCK_LIMIT), omitted: true });
    else this.activity({ follow, offset });
  }

  setPanel(panel: Panel): void {
    if (panel === this.state.panel) return;
    this.set({ panel });
    if (panel === "plan") void this.loadPlan();
  }

  async loadPlan(): Promise<void> {
    const id = this.state.selected, visit = this.visit;
    if (!id || this.state.panel !== "plan") return;
    try {
      const plan = await this.api<Plan>(`/v1/runs/${id}/plan`);
      if (visit === this.visit) this.set({ plan });
    } catch (error) { if (visit === this.visit) this.message((error as Error).message); }
  }

  async poll(): Promise<void> {
    if (this.state.session !== "in" || this.env.hidden() || this.refreshing) return;
    this.refreshing = true;
    try {
      await this.listRuns();
      if (this.state.selected && this.state.panel === "plan") await this.loadPlan();
    } catch (error) { this.report(error); }
    finally { this.refreshing = false; }
  }

  setDraft(draft: string): void { this.set({ draft }); }

  steer(): Promise<void> {
    const id = this.state.selected, content = this.state.draft, visit = this.visit;
    if (!id || !content || this.state.send.status === "sending") return Promise.resolve();
    if (!this.steerIntent || this.steerIntent.content !== content || this.steerIntent.id !== id) this.steerIntent = { id, content, requestId: this.env.uuid() };
    const intent = this.steerIntent;
    this.set({ send: { status: "sending", error: "", content } });
    const settle = (send: Send) => { if (visit === this.visit) this.set({ send: { ...send, content, ended: this.state.send.ended } }); };
    return this.api(`/v1/runs/${id}/steer`, "POST", { content, requestId: intent.requestId }).then(() => {
      if (this.steerIntent === intent) this.steerIntent = undefined;
      if (visit !== this.visit) return;
      if (this.state.draft === content) this.set({ draft: "" });
      settle({ status: "queued", error: "" });
    }, (error: Error) => settle({ status: "failed", error: error.message }));
  }

  openAbort(open: boolean): void { this.set({ abort: { open, error: "" } }); }

  confirmAbort(): Promise<void> {
    const id = this.state.selected, visit = this.visit;
    if (!id) return Promise.resolve();
    return this.busy("abort", async () => {
      try { await this.api(`/v1/runs/${id}/abort`, "POST"); }
      catch (error) { if (visit === this.visit) this.set({ abort: { open: true, error: (error as Error).message } }); return; }
      if (visit === this.visit) this.set({ abort: { open: false, error: "" } });
      await this.listRuns();
    });
  }

  async loadSchedules(): Promise<void> { this.set({ schedules: await this.api<Schedule[]>("/v1/schedules"), deleting: [] }); }

  setForm(form: Partial<State["form"]>): void { this.set({ form: { ...this.state.form, ...form } }); }

  createSchedule(): Promise<void> {
    return this.busy("schedule", async () => {
      const value = { ...this.state.form };
      const input = JSON.stringify(value);
      if (this.scheduleIntent?.input !== input) this.scheduleIntent = { input, requestId: this.env.uuid() };
      await this.api("/v1/schedules", "POST", { ...value, requestId: this.scheduleIntent.requestId });
      this.scheduleIntent = undefined;
      this.setForm({ prompt: "" });
      await this.loadSchedules();
    });
  }

  async deleteSchedule(id: string): Promise<void> {
    if (this.state.deleting.includes(id)) return;
    this.set({ deleting: [...this.state.deleting, id] });
    try { await this.api(`/v1/schedules/${id}`, "DELETE"); await this.loadSchedules(); }
    catch (error) { this.report(error); this.set({ deleting: this.state.deleting.filter((item) => item !== id) }); }
  }

  private pushState(patch: Partial<Push>): void { this.set({ push: { ...this.state.push, ...patch } }); }

  async setupPush(): Promise<void> {
    const push = this.env.push;
    if (!push) { this.pushState({ available: false, text: "Push is unavailable here. On iPhone or iPad, add Etabli to the Home Screen and open it there first." }); return; }
    this.registration = await push.register();
    this.publicKey = (await this.api<{ publicKey: string }>("/v1/push/key")).publicKey;
    let subscription = await this.registration.pushManager.getSubscription();
    if (subscription) {
      const actual = new Uint8Array(subscription.options.applicationServerKey ?? []), expected = applicationKey(this.publicKey);
      if (actual.length !== expected.length || !actual.every((byte, index) => byte === expected[index])) {
        await subscription.unsubscribe();
        await this.api("/v1/push/subscriptions", "DELETE", { endpoint: subscription.endpoint });
        subscription = null;
        this.pushState({ text: "The daemon notification key changed. Enable notifications again for this device." });
      }
    }
    this.pushState({ subscribed: !!subscription });
    if (subscription) {
      await this.api("/v1/push/subscriptions", "POST", { endpoint: subscription.endpoint });
      this.pushState({ text: "Notifications enabled for this device. Run contents stay private." });
    }
  }

  /** Called from the click handler itself, so the permission request comes before any await. */
  enableNotifications(): Promise<void> {
    const registration = this.registration, publicKey = this.publicKey, push = this.env.push;
    if (!registration || !publicKey || !push) { this.message("Notification setup is unavailable. Reconnect to retry."); return Promise.resolve(); }
    const permission = push.requestPermission();
    return this.busy("subscribe", async () => {
      if (await permission !== "granted") throw new Error("Notifications were not allowed. Change the browser permission to enable them.");
      const subscription = await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: applicationKey(publicKey) });
      await this.api("/v1/push/subscriptions", "POST", { endpoint: subscription.endpoint });
      this.pushState({ subscribed: true, text: "Notifications enabled for this device." });
    });
  }

  disableNotifications(): Promise<void> {
    return this.busy("unsubscribe", async () => {
      const subscription = await this.registration?.pushManager.getSubscription();
      if (subscription) { await this.api("/v1/push/subscriptions", "DELETE", { endpoint: subscription.endpoint }); await subscription.unsubscribe(); }
      this.pushState({ subscribed: false, text: "Notifications disabled for this device." });
    });
  }

  offline(): void { this.message("You are offline. Reconnect to watch and control runs."); }
  pagehide(): void { this.stopWatch(); }
  pageshow(persisted: boolean): void {
    if (!persisted) return;
    this.clearSession();
    this.connected().catch((error: unknown) => this.report(error));
  }
}
