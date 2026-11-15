import { randomUUID } from "node:crypto";
import { replaceControlCharacters, stripTerminalSequences } from "@earendil-works/pi-tui";
import type { ConversationView, EntryRecord } from "@earendil-works/pi-durable";
import type { Message } from "@earendil-works/pi-ai";
import type { Run } from "../src/runs-doc.ts";
import { request, watchRun, type Remote } from "../src/client.ts";

export function safe(text: string): string {
  return replaceControlCharacters(stripTerminalSequences(text));
}

export function lines(text: string): string {
  return text.split(/\r?\n/).map(safe).join("\n");
}

export function age(created: number, now = Date.now()): string {
  const seconds = Math.max(0, Math.floor((now - created) / 1000));
  return seconds < 60 ? `${seconds}s` : seconds < 3600 ? `${Math.floor(seconds / 60)}m` : `${Math.floor(seconds / 3600)}h`;
}

function messageText(message: Message): string {
  if (message.role === "system") return "";
  const text = typeof message.content === "string" ? message.content : message.content.flatMap((part) => part.type === "text" ? [part.text] : part.type === "toolCall" ? [`[tool ${part.name}]`] : []).join("\n");
  return text ? lines(`${message.role === "toolResult" ? `tool ${message.toolName}` : message.role}: ${text}`) : "";
}

export class TuiModel {
  runs: Readonly<Run>[] = [];
  selectedId = "";
  mode: "list" | "run" | "steer" | "abort" = "list";
  entries: readonly EntryRecord[] = [];
  docs: ConversationView["docs"] = {};
  omitted = false;
  gap = false;
  status = "Connecting";
  actionError = "";
  refreshError = "";
  draft = "";
  targetId = "";
  pending = false;
  private intent?: { id: string; text: string; requestId: string };
  private epoch = 0;
  private closed = false;
  private refreshing = false;
  private readonly lifetime = new AbortController();
  private follower?: AbortController;
  private poll?: ReturnType<typeof setTimeout>;
  private reconnect?: ReturnType<typeof setTimeout>;
  private retryMs = 500;

  readonly state: string;
  readonly remote: Remote | undefined;
  readonly changed: () => void;

  constructor(state: string, remote: Remote | undefined, changed: () => void) {
    this.state = state;
    this.remote = remote;
    this.changed = changed;
  }

  get selected(): Readonly<Run> | undefined { return this.runs.find((run) => run.id === this.selectedId); }
  get error(): string { return this.actionError || this.refreshError; }
  get mutable(): boolean { return !!this.selected && !["done", "blocked", "aborted"].includes(this.selected.status); }

  async refresh(): Promise<void> {
    if (this.closed || this.refreshing) return;
    this.refreshing = true;
    clearTimeout(this.poll);
    try {
      this.runs = (await request(this.state, { op: "ls" }, this.remote, this.lifetime.signal) as Run[]).sort((a, b) => b.createdAt - a.createdAt);
      if (!this.selectedId) this.selectedId = this.runs[0]?.id ?? "";
      this.refreshError = "";
    } catch { if (!this.closed) this.refreshError = "Cannot refresh runs. Retrying; check the daemon or remote credentials."; }
    finally {
      this.refreshing = false;
      if (!this.closed) { this.changed(); this.poll = setTimeout(() => { void this.refresh(); }, 2000); }
    }
  }

  move(delta: number): void {
    if (this.mode !== "list" || !this.runs.length) return;
    const index = this.runs.findIndex((run) => run.id === this.selectedId);
    this.selectedId = this.runs[Math.max(0, Math.min(this.runs.length - 1, index + delta))].id;
    this.changed();
  }

  select(id = this.selectedId): void {
    if (this.closed || !this.runs.some((run) => run.id === id)) return;
    this.follower?.abort();
    clearTimeout(this.reconnect);
    this.epoch++;
    this.selectedId = id;
    this.entries = [];
    this.docs = {};
    this.omitted = this.gap = false;
    this.mode = "run";
    this.retryMs = 500;
    void this.follow(this.epoch);
    this.changed();
  }

  private async follow(epoch: number): Promise<void> {
    if (this.closed || epoch !== this.epoch) return;
    const controller = new AbortController();
    this.follower = controller;
    this.status = "Connecting";
    this.changed();
    const disconnected = () => {
      if (this.closed || epoch !== this.epoch || controller.signal.aborted) return;
      controller.abort();
      this.status = "Disconnected; reconnecting (check daemon or credentials)";
      this.changed();
      this.reconnect = setTimeout(() => { void this.follow(epoch); }, this.retryMs);
      this.retryMs = Math.min(10_000, this.retryMs * 2);
    };
    try {
      const newest = this.entries.at(-1)?.id;
      await watchRun(this.state, this.selectedId, newest === undefined ? undefined : newest + 1, this.remote, controller.signal, (view) => {
        if (this.closed || epoch !== this.epoch || controller.signal.aborted) return;
        this.merge(view);
        this.status = "Live";
        this.retryMs = 500;
        this.changed();
      }, disconnected);
    } catch { disconnected(); }
  }

  merge(view: ConversationView): void {
    const newest = this.entries.at(-1)?.id;
    if (newest !== undefined && view.before !== undefined && view.before > newest) this.gap = true;
    const entries = new Map(this.entries.map((entry) => [entry.id, entry]));
    for (const entry of view.entries) entries.set(entry.id, entry);
    this.omitted ||= (newest === undefined && view.before !== undefined) || entries.size > 100;
    this.entries = [...entries.values()].sort((a, b) => a.id - b.id).slice(-100);
    this.docs = view.docs;
  }

  begin(mode: "steer" | "abort"): void {
    if (this.pending || !this.mutable) return;
    this.targetId = this.selectedId;
    this.mode = mode;
    this.actionError = "";
    this.changed();
  }

  cancel(): void {
    if (this.pending || this.mode === "list") return;
    this.actionError = "";
    this.mode = this.mode === "run" ? "list" : "run";
    if (this.mode === "list") { this.epoch++; this.follower?.abort(); clearTimeout(this.reconnect); }
    this.changed();
  }

  async send(): Promise<void> {
    if (this.closed || this.pending || !["steer", "abort"].includes(this.mode)) return;
    const op = this.mode;
    const id = this.targetId;
    const content = safe(this.draft);
    if (op === "steer" && (!content.trim() || content.length > 64_000)) { this.actionError = "Enter a message of 1 to 64000 characters."; this.changed(); return; }
    if (op === "steer" && (!this.intent || this.intent.id !== id || this.intent.text !== content)) this.intent = { id, text: content, requestId: randomUUID() };
    this.pending = true;
    this.actionError = "";
    this.changed();
    try {
      await request(this.state, op === "steer" ? { op, id, content, requestId: this.intent!.requestId } : { op, id }, this.remote, this.lifetime.signal);
      if (op === "steer") { this.draft = ""; this.intent = undefined; }
      this.mode = "run";
      void this.refresh();
    } catch { if (!this.closed) this.actionError = "Request failed. Retry or cancel; the message has been kept."; }
    finally { this.pending = false; if (!this.closed) this.changed(); }
  }

  transcript(): string {
    const history = this.entries.flatMap((entry) => entry.model?.map(messageText).filter(Boolean) ?? []);
    const live = this.docs["pi.live"];
    if (live && typeof live.generation === "object" && live.generation && !Array.isArray(live.generation)) {
      const message = live.generation.message;
      if (message && typeof message === "object" && !Array.isArray(message) && message.role === "assistant" && Array.isArray(message.content)) history.push(messageText(message as unknown as Message));
    }
    if (live && Array.isArray(live.tools)) for (const tool of live.tools) {
      if (tool && typeof tool === "object" && !Array.isArray(tool) && typeof tool.name === "string" && typeof tool.status === "string") history.push(lines(`tool ${tool.name}: ${tool.status}${typeof tool.output === "string" ? `\n${tool.output}` : ""}`));
    }
    return [this.omitted ? "Earlier entries omitted (recent window only)." : "", this.gap ? "Entries missed while disconnected." : "", ...history].filter(Boolean).join("\n\n") || "Waiting for entries…";
  }

  close(): void {
    this.closed = true;
    this.epoch++;
    clearTimeout(this.poll);
    clearTimeout(this.reconnect);
    this.follower?.abort();
    this.lifetime.abort();
  }
}
