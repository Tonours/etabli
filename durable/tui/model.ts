import { randomUUID } from "node:crypto";
import { replaceControlCharacters, stripTerminalSequences } from "@earendil-works/pi-tui";
import type { ConversationView, EntryRecord } from "@earendil-works/pi-durable";
import type { Message } from "@earendil-works/pi-ai";
import { active, type Run } from "../src/runs-doc.ts";
import { request, watchRun, type Remote } from "../src/client.ts";
import { age, describe, ended, GROUPS, order, pullRequest, summary, title, type Tone } from "../shared/runs-view.ts";

export type Part = { text: string; tone?: Tone };
export type ListView = { lines: Part[][]; selectedLine: number; detail: string[] };

export function safe(text: string): string {
  return replaceControlCharacters(stripTerminalSequences(text));
}

export function lines(text: string): string {
  return text.split(/\r?\n/).map(safe).join("\n");
}

const GLYPH: Record<Tone, string> = { alert: "!", ok: "✓", info: "·", muted: "·" };
const REPO_WIDTH = 28;
const record = (value: unknown): value is Record<string, unknown> => !!value && typeof value === "object" && !Array.isArray(value);

function toolSummary(args: unknown): string {
  const flat = JSON.stringify(args ?? {});
  return flat.length > 120 ? `${flat.slice(0, 120)}…` : flat;
}

function left(deadline: number, now: number): string {
  const minutes = Math.ceil((deadline - now) / 60_000);
  if (!deadline || minutes <= 0) return "";
  return minutes < 60 ? `${minutes}m left` : `${Math.floor(minutes / 60)}h ${minutes % 60}m left`;
}

function detailLines(run: Readonly<Run>, hint: string): string[] {
  return [hint, pullRequest(run.url)].filter(Boolean).map(safe);
}

/** Grouped, column-aligned rows in display order; `selectedLine` counts the summary and the headings. */
export function listView(runs: readonly Readonly<Run>[], selectedId: string, now: number): ListView {
  const { groups, counts } = order(runs, now);
  const since = (run: Readonly<Run>) => age(run.startedAt || run.createdAt, now);
  const labelWidth = Math.max(0, ...runs.map((run) => `${GLYPH[describe(run, now).tone]} ${safe(describe(run, now).label)}`.length)) + 2;
  const ageWidth = Math.max(0, ...runs.map((run) => since(run).length));
  const repo = (run: Readonly<Run>) => { const text = safe(run.repo); return text.length > REPO_WIDTH ? `${text.slice(0, REPO_WIDTH - 1)}…` : text; };
  const repoWidth = Math.max(0, ...runs.map((run) => repo(run).length));
  const lines: Part[][] = [];
  let selectedLine = 0;
  let detail: string[] = [];
  if (runs.length) lines.push([{ text: summary(counts), tone: "muted" }]);
  for (const { group, heading } of GROUPS) {
    if (!groups[group].length) continue;
    lines.push([{ text: `${heading} (${groups[group].length})` }]);
    for (const run of groups[group]) {
      const view = describe(run, now);
      const selected = run.id === selectedId;
      if (selected) { selectedLine = lines.length; detail = detailLines(run, view.hint); }
      lines.push([
        { text: `${selected ? ">" : " "} ` },
        { text: `${GLYPH[view.tone]} ${safe(view.label)}`.padEnd(labelWidth), tone: view.tone },
        { text: `${since(run).padStart(ageWidth)}  ` },
        { text: `${repo(run).padEnd(repoWidth)}  ` },
        { text: safe(title(run.prompt)) },
      ]);
    }
  }
  return { lines, selectedLine, detail };
}

function messageText(message: Message): string {
  if (message.role === "system") return "";
  const text = typeof message.content === "string" ? message.content : message.content.flatMap((part) => part.type === "text" ? [part.text] : part.type === "toolCall" ? [`[tool ${part.name} ${toolSummary(part.arguments)}]`] : []).join("\n");
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
  notice = "";
  keepInput = false;
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
  get mutable(): boolean { return !!this.selected && !ended(this.selected); }

  async refresh(): Promise<void> {
    if (this.closed || this.refreshing) return;
    this.refreshing = true;
    clearTimeout(this.poll);
    try {
      this.runs = order(await request(this.state, { op: "ls" }, this.remote, this.lifetime.signal) as Run[], Date.now()).runs;
      if (!this.selectedId) this.selectedId = this.runs[0]?.id ?? "";
      const run = this.selected;
      if (run && ended(run) && (this.mode === "steer" || this.mode === "abort")) { this.mode = "run"; this.actionError = ""; this.keepInput = true; }
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
    this.draft = this.notice = "";
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
    if (this.pending || !this.mutable || (mode === "steer" && (!this.selected || !active(this.selected)))) return;
    this.targetId = this.selectedId;
    this.mode = mode;
    this.actionError = this.notice = "";
    this.changed();
  }

  cancel(): void {
    if (this.pending || this.mode === "list") return;
    this.actionError = "";
    this.mode = this.mode === "run" ? "list" : "run";
    if (this.mode === "list") { this.draft = this.notice = ""; this.epoch++; this.follower?.abort(); clearTimeout(this.reconnect); }
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
      if (op === "steer") { this.draft = ""; this.intent = undefined; this.notice = this.endedTarget(id) ? "Instruction accepted before the run ended; the agent may not have read it." : "Instruction queued"; }
      this.mode = "run";
      void this.refresh();
    } catch { if (!this.closed) this.actionError = this.endedTarget(id) ? "Not delivered: the run ended. Your message is kept below." : "Request failed. Retry or cancel; the message has been kept."; }
    finally { this.pending = false; if (!this.closed) this.changed(); }
  }

  private endedTarget(id: string): boolean {
    const run = this.runs.find((item) => item.id === id);
    return !!run && ended(run);
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
    const queued = this.queued().map((text) => lines(`Instruction queued: ${text}`));
    const unsent = this.selected && ended(this.selected) && this.draft ? [lines(`Unsent instruction (the run ended): ${this.draft}`)] : [];
    const empty = this.selected && ended(this.selected) ? (this.status === "Live" ? "Nothing was recorded for this run." : "Loading…") : "Waiting for entries…";
    return [this.omitted ? "Earlier entries omitted (recent window only)." : "", this.gap ? "Entries missed while disconnected." : "", ...history, ...queued, ...unsent].filter(Boolean).join("\n\n") || empty;
  }

  /** Steer and follow-up items only; write items and a missing inbox show nothing. */
  queued(): string[] {
    const items = this.docs["pi.inbox"]?.items;
    if (!Array.isArray(items)) return [];
    return items.flatMap((item) => {
      if (!record(item) || (item.mode !== "steer" && item.mode !== "followUp")) return [];
      const content = item.content;
      return [typeof content === "string" ? content : Array.isArray(content) ? content.map((part) => record(part) && part.type === "text" && typeof part.text === "string" ? part.text : "").filter(Boolean).join("\n") : ""];
    }).filter(Boolean);
  }

  /** Run header: label, connection, turns, time left, then the sentence and the pull-request URL. */
  header(now = Date.now()): string[] {
    const run = this.selected;
    if (!run) return ["Run unavailable"];
    const view = describe(run, now);
    const connection = ended(run) && !this.status.startsWith("Disconnected") ? "Finished" : this.status;
    const live = this.docs["pi.live"];
    const turns = live && record(live.run) && typeof live.run.turns === "number" ? live.run.turns : 0;
    const agent = this.docs["pi.agent"];
    const maxTurns = agent && typeof agent.maxTurns === "number" ? agent.maxTurns : 0;
    const meta = [turns ? `Turn ${turns}${maxTurns ? ` of ${maxTurns}` : ""}` : "", ended(run) ? "" : left(run.deadline, now)].filter(Boolean).join(" · ");
    return [`${GLYPH[view.tone]} ${safe(view.label)} · ${safe(run.repo)} · ${run.id.slice(0, 8)} · ${connection}`, meta, ...detailLines(run, view.hint)].filter(Boolean);
  }

  /** Key hints for the current mode; ended runs offer no steer or abort. */
  hints(): string {
    if (this.mode === "list") return "↑/↓ select · Enter follow · r refresh · q quit";
    if (this.mode === "abort") return `Abort ${this.targetId.slice(0, 8)}? y confirm · Esc cancel`;
    if (this.mode === "steer") return "Enter send · Esc cancel";
    const run = this.selected;
    const actions = !run || ended(run) ? [] : [...(active(run) ? ["s steer"] : []), "a abort"];
    return [...actions, "Esc runs", "PgUp/PgDn scroll", "q quit"].join(" · ");
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
