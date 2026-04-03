/**
 * TillDone — Task-driven discipline gate.
 *
 * Forces the agent to define tasks before using any tools, and nudges it to
 * continue when incomplete tasks remain. Three-state lifecycle: idle → inprogress → done.
 *
 * Gate rules:
 *   - No tasks exist        → block (must add tasks first)
 *   - All tasks done        → block (must add new tasks or start new list)
 *   - No task in progress   → block (must toggle one to inprogress)
 *
 * UI surfaces:
 *   - Widget:   full task list (above editor)
 *   - Status:   compact summary
 *   - /tilldone: interactive overlay with task management
 *
 * Usage: `pi -e extensions/tilldone.ts`
 */

import { StringEnum } from "@mariozechner/pi-ai";
import type { ExtensionAPI, ExtensionContext, Theme } from "@mariozechner/pi-coding-agent";
import { DynamicBorder } from "@mariozechner/pi-coding-agent";
import { Container, matchesKey, Text, truncateToWidth } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";
import { compileTodoIntent } from "./lib/intent-compiler.ts";

// ── Types ──────────────────────────────────────────────────────────────

export type TaskStatus = "idle" | "inprogress" | "done";

export interface Task {
  id: number;
  text: string;
  status: TaskStatus;
}

interface TillDoneState {
  tasks: Task[];
  nextId: number;
  listTitle?: string;
  listDescription?: string;
  undoState?: TillDoneState;
}

interface TillDoneDetails {
  action: string;
  tasks: Task[];
  nextId: number;
  listTitle?: string;
  listDescription?: string;
  undoState?: TillDoneState;
  error?: string;
}

const TillDoneParams = Type.Object({
  action: StringEnum([
    "new-list",
    "add",
    "toggle",
    "remove",
    "update",
    "list",
    "clear",
    "undo",
  ] as const),
  text: Type.Optional(
    Type.String({ description: "Task text (for add/update) or list title (for new-list)" }),
  ),
  texts: Type.Optional(
    Type.Array(Type.String(), { description: "Multiple task texts (for batch add or seeded new-list tasks)" }),
  ),
  description: Type.Optional(
    Type.String({ description: "List description (for new-list)" }),
  ),
  id: Type.Optional(
    Type.Number({ description: "Task ID (for toggle/remove/update)" }),
  ),
});

// ── Constants ──────────────────────────────────────────────────────────

const STATUS_ICON: Record<TaskStatus, string> = {
  idle: "○",
  inprogress: "●",
  done: "✓",
};

const STATUS_LABEL: Record<TaskStatus, string> = {
  idle: "idle",
  inprogress: "in progress",
  done: "done",
};

const MAX_TASKS = 7;

const LOW_SIGNAL_TASK_TOKENS = new Set([
  "a",
  "an",
  "the",
  "and",
  "app",
  "bug",
  "bugs",
  "check",
  "clean",
  "cleanup",
  "code",
  "do",
  "docs",
  "documentation",
  "file",
  "files",
  "fix",
  "flow",
  "flows",
  "handle",
  "improve",
  "in",
  "investigate",
  "issue",
  "issues",
  "item",
  "items",
  "logic",
  "misc",
  "of",
  "on",
  "our",
  "polish",
  "problem",
  "problems",
  "refactor",
  "review",
  "some",
  "stuff",
  "task",
  "tasks",
  "thing",
  "things",
  "to",
  "todo",
  "ui",
  "update",
  "up",
  "ux",
  "with",
  "work",
]);

const VAGUE_TASK_START_PHRASES = [
  ["clean", "up"],
  ["work", "on"],
  ["fix"],
  ["improve"],
  ["handle"],
  ["check"],
  ["review"],
  ["update"],
  ["do"],
  ["investigate"],
  ["cleanup"],
  ["refactor"],
  ["polish"],
];

function cloneTasks(tasks: Task[]): Task[] {
  return tasks.map((task) => ({ ...task }));
}

export function normalizeTaskText(text: string): string {
  return text.trim().replace(/\s+/g, " ");
}

function tokenizeTaskText(text: string): string[] {
  return normalizeTaskText(text)
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter(Boolean);
}

function startsWithPhrase(tokens: string[], phrase: string[]): boolean {
  return phrase.every((part, index) => tokens[index] === part);
}

export function validateTaskText(text: string): string | null {
  const normalized = normalizeTaskText(text);
  if (normalized.length === 0) return "empty task";
  if (normalized.length < 5) return "task too short";

  const tokens = tokenizeTaskText(normalized);
  const allLowSignal = tokens.length > 0 && tokens.every((token) => LOW_SIGNAL_TASK_TOKENS.has(token));
  if (allLowSignal && tokens.length <= 5) {
    return "task too vague";
  }

  const hasLowSignalStart = VAGUE_TASK_START_PHRASES.some((phrase) => {
    if (!startsWithPhrase(tokens, phrase)) return false;
    const tail = tokens.slice(phrase.length);
    return tail.length === 0 || tail.every((token) => LOW_SIGNAL_TASK_TOKENS.has(token));
  });
  if (hasLowSignalStart) {
    return "task too vague";
  }

  return null;
}

function buildTaskTextKey(text: string): string {
  return normalizeTaskText(text).toLowerCase();
}

export function prepareTaskTexts(
  items: string[],
  existingTasks: Task[],
): {
  accepted: string[];
  duplicates: string[];
  invalid: string[];
  error?: string;
} {
  const accepted: string[] = [];
  const duplicates: string[] = [];
  const invalid: string[] = [];
  const seen = new Set(existingTasks.map((task) => buildTaskTextKey(task.text)));

  for (const item of items) {
    const normalized = normalizeTaskText(compileTodoIntent(item));
    const invalidReason = validateTaskText(normalized);
    if (invalidReason) {
      invalid.push(normalized || item);
      continue;
    }

    const key = buildTaskTextKey(normalized);
    if (seen.has(key)) {
      duplicates.push(normalized);
      continue;
    }

    seen.add(key);
    accepted.push(normalized);
  }

  if (accepted.length === 0 && (duplicates.length > 0 || invalid.length > 0)) {
    return { accepted, duplicates, invalid, error: "no valid tasks" };
  }

  if (existingTasks.length + accepted.length > MAX_TASKS) {
    return { accepted: [], duplicates, invalid, error: "too many tasks" };
  }

  return { accepted, duplicates, invalid };
}

function appendPreparationNotes(
  message: string,
  details: { duplicates: string[]; invalid: string[] },
): string {
  let next = message;
  if (details.duplicates.length > 0) {
    next += `\n(Skipped duplicates: ${details.duplicates.map((item) => `"${item}"`).join(", ")})`;
  }
  if (details.invalid.length > 0) {
    next += `\n(Skipped vague/invalid tasks: ${details.invalid.map((item) => `"${item}"`).join(", ")})`;
  }
  return next;
}

function cloneState(state: TillDoneState): TillDoneState {
  return {
    tasks: cloneTasks(state.tasks),
    nextId: state.nextId,
    listTitle: state.listTitle,
    listDescription: state.listDescription,
    undoState: state.undoState ? cloneState(state.undoState) : undefined,
  };
}

export function nextToggleStatus(status: TaskStatus): TaskStatus | null {
  switch (status) {
    case "idle":
      return "inprogress";
    case "inprogress":
      return "done";
    case "done":
      return null;
  }
}

export function setExclusiveInProgress(
  tasks: Task[],
  activeId: number,
): { tasks: Task[]; demotedIds: number[] } {
  const demotedIds: number[] = [];
  const nextTasks = cloneTasks(tasks).map((task) => {
    if (task.id === activeId) return { ...task, status: "inprogress" as const };
    if (task.status === "inprogress") {
      demotedIds.push(task.id);
      return { ...task, status: "idle" as const };
    }
    return task;
  });

  return { tasks: nextTasks, demotedIds };
}

export function autoActivateTask(
  tasks: Task[],
  preferredTaskId?: number,
): { tasks: Task[]; activatedId?: number } {
  if (tasks.some((task) => task.status === "inprogress")) {
    return { tasks: cloneTasks(tasks) };
  }

  const preferredTask =
    preferredTaskId !== undefined
      ? tasks.find((task) => task.id === preferredTaskId && task.status !== "done")
      : undefined;
  const fallbackTask = tasks.find((task) => task.status !== "done");
  const toActivate = preferredTask ?? fallbackTask;

  if (!toActivate) return { tasks: cloneTasks(tasks) };

  const nextTasks = cloneTasks(tasks).map((task) =>
    task.id === toActivate.id ? { ...task, status: "inprogress" as const } : task,
  );

  return { tasks: nextTasks, activatedId: toActivate.id };
}

export function normalizeTasks(
  tasks: Task[],
  options?: { autoActivatePending?: boolean },
): { tasks: Task[]; activatedId?: number; demotedIds: number[] } {
  const nextTasks = cloneTasks(tasks);
  const activeTasks = nextTasks.filter((task) => task.status === "inprogress");
  const demotedIds: number[] = [];

  if (activeTasks.length > 1) {
    const [keeper, ...rest] = activeTasks;
    for (const task of nextTasks) {
      if (rest.some((entry) => entry.id === task.id)) {
        task.status = "idle";
        demotedIds.push(task.id);
      }
      if (task.id === keeper.id) {
        task.status = "inprogress";
      }
    }
  }

  if (!options?.autoActivatePending || nextTasks.some((task) => task.status === "inprogress")) {
    return { tasks: nextTasks, demotedIds };
  }

  const activated = autoActivateTask(nextTasks);
  return {
    tasks: activated.tasks,
    activatedId: activated.activatedId,
    demotedIds,
  };
}

// ── Overlay component ──────────────────────────────────────────────────

class TillDoneListComponent {
  private tasks: Task[];
  private title: string | undefined;
  private desc: string | undefined;
  private theme: Theme;
  private onClose: () => void;
  private cachedWidth?: number;
  private cachedLines?: string[];

  constructor(
    tasks: Task[],
    title: string | undefined,
    desc: string | undefined,
    theme: Theme,
    onClose: () => void,
  ) {
    this.tasks = tasks;
    this.title = title;
    this.desc = desc;
    this.theme = theme;
    this.onClose = onClose;
  }

  handleInput(data: string): void {
    if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c")) {
      this.onClose();
    }
  }

  render(width: number): string[] {
    if (this.cachedLines && this.cachedWidth === width) return this.cachedLines;

    const th = this.theme;
    const lines: string[] = [""];

    const heading = this.title
      ? th.fg("accent", ` ${this.title} `)
      : th.fg("accent", " TillDone ");
    const headingLen = (this.title?.length ?? 8) + 2;
    lines.push(
      truncateToWidth(
        th.fg("dim", "─".repeat(3)) +
          heading +
          th.fg("dim", "─".repeat(Math.max(0, width - 3 - headingLen))),
        width,
      ),
    );

    if (this.desc) {
      lines.push(truncateToWidth(`  ${th.fg("muted", this.desc)}`, width));
    }
    lines.push("");

    if (this.tasks.length === 0) {
      lines.push(
        truncateToWidth(`  ${th.fg("dim", "No tasks yet. Ask the agent to add some!")}`, width),
      );
    } else {
      const done = this.tasks.filter((t) => t.status === "done").length;
      const active = this.tasks.filter((t) => t.status === "inprogress").length;
      const idle = this.tasks.filter((t) => t.status === "idle").length;

      lines.push(
        truncateToWidth(
          "  " +
            th.fg("success", `${done} done`) +
            th.fg("dim", "  ") +
            th.fg("accent", `${active} active`) +
            th.fg("dim", "  ") +
            th.fg("muted", `${idle} idle`),
          width,
        ),
      );
      lines.push("");

      for (const task of this.tasks) {
        const icon =
          task.status === "done"
            ? th.fg("success", STATUS_ICON.done)
            : task.status === "inprogress"
              ? th.fg("accent", STATUS_ICON.inprogress)
              : th.fg("dim", STATUS_ICON.idle);
        const id = th.fg("accent", `#${task.id}`);
        const text =
          task.status === "done"
            ? th.fg("dim", task.text)
            : task.status === "inprogress"
              ? th.fg("success", task.text)
              : th.fg("muted", task.text);
        lines.push(truncateToWidth(`  ${icon} ${id} ${text}`, width));
      }
    }

    lines.push("");
    lines.push(truncateToWidth(`  ${th.fg("dim", "Press Escape to close")}`, width));
    lines.push("");

    this.cachedWidth = width;
    this.cachedLines = lines;
    return lines;
  }

  invalidate(): void {
    this.cachedWidth = undefined;
    this.cachedLines = undefined;
  }
}

// ── Extension entry point ──────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
  let tasks: Task[] = [];
  let nextId = 1;
  let listTitle: string | undefined;
  let listDescription: string | undefined;
  let undoState: TillDoneState | undefined;
  let nudgedThisCycle = false;

  // ── Snapshot for details ─────────────────────────────────────────────

  function snapshotState(): TillDoneState {
    return {
      tasks: cloneTasks(tasks),
      nextId,
      listTitle,
      listDescription,
      undoState: undoState ? cloneState(undoState) : undefined,
    };
  }

  function applyState(state: TillDoneState): void {
    const normalized = normalizeTasks(state.tasks, { autoActivatePending: true });
    tasks = normalized.tasks;
    nextId = state.nextId;
    listTitle = state.listTitle;
    listDescription = state.listDescription;
    undoState = state.undoState ? cloneState(state.undoState) : undefined;
  }

  function rememberUndo(): void {
    undoState = snapshotState();
  }

  function makeDetails(action: string, error?: string): TillDoneDetails {
    return {
      action,
      tasks: cloneTasks(tasks),
      nextId,
      listTitle,
      listDescription,
      undoState: undoState ? cloneState(undoState) : undefined,
      ...(error ? { error } : {}),
    };
  }

  // ── UI refresh ───────────────────────────────────────────────────────

  function refreshWidget(ctx: ExtensionContext): void {
    if (tasks.length === 0) {
      ctx.ui.setWidget("tilldone-tasks", undefined);
      return;
    }

    ctx.ui.setWidget(
      "tilldone-tasks",
      (_tui, theme) => {
        const container = new Container();
        const borderFn = (s: string) => theme.fg("dim", s);
        container.addChild(new DynamicBorder(borderFn));
        const body = new Text("", 1, 0);
        container.addChild(body);
        container.addChild(new DynamicBorder(borderFn));

        return {
          render(width: number): string[] {
            if (tasks.length === 0) return [];
            const inner = width - 4;
            const done = tasks.filter((t) => t.status === "done").length;
            const title = listTitle ?? "TillDone";

            const header =
              theme.fg("accent", title) + theme.fg("dim", ` ${done}/${tasks.length}`);

            const STATUS_ORDER: Record<TaskStatus, number> = { inprogress: 0, idle: 1, done: 2 };
            const sorted = [...tasks].sort((a, b) => STATUS_ORDER[a.status] - STATUS_ORDER[b.status]);

            const allRows = sorted.map((t) => {
              const icon =
                t.status === "done"
                  ? theme.fg("success", STATUS_ICON.done)
                  : t.status === "inprogress"
                    ? theme.fg("accent", STATUS_ICON.inprogress)
                    : theme.fg("dim", STATUS_ICON.idle);
              const text =
                t.status === "done"
                  ? theme.fg("dim", t.text)
                  : t.status === "inprogress"
                    ? theme.fg("text", t.text)
                    : theme.fg("muted", t.text);
              return truncateToWidth(` ${icon} ${text}`, inner);
            });

            // Cap widget height at ~33% of terminal (minus chrome: header + borders + spacer)
            const termRows = process.stdout.rows ?? 24;
            const maxWidgetRows = Math.max(3, Math.floor(termRows / 3) - 4);
            let rows: string[];
            if (allRows.length > maxWidgetRows) {
              const hidden = allRows.length - maxWidgetRows + 1;
              rows = allRows.slice(0, maxWidgetRows - 1);
              rows.push(truncateToWidth(` ${theme.fg("dim", `↓ ${hidden} more… (/tilldone)`)}`, inner));
            } else {
              rows = allRows;
            }

            body.setText([header, ...rows].join("\n"));
            return container.render(width);
          },
          invalidate() {
            container.invalidate();
          },
        };
      },
      { placement: "aboveEditor" },
    );
  }

  function refreshUI(ctx: ExtensionContext): void {
    const remaining = tasks.filter((t) => t.status !== "done").length;
    const label = listTitle ? `${listTitle}` : "TillDone";

    if (tasks.length === 0) {
      ctx.ui.setStatus("tilldone", `${label}: no tasks`);
    } else {
      ctx.ui.setStatus("tilldone", `${label}: ${tasks.length} tasks (${remaining} remaining)`);
    }

    refreshWidget(ctx);
  }

  // ── State reconstruction from session ────────────────────────────────

  function reconstructState(ctx: ExtensionContext): void {
    tasks = [];
    nextId = 1;
    listTitle = undefined;
    listDescription = undefined;
    undoState = undefined;

    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type !== "message") continue;
      const msg = entry.message;
      if (msg.role !== "toolResult" || msg.toolName !== "tilldone") continue;

      const details = msg.details as TillDoneDetails | undefined;
      if (details) {
        applyState({
          tasks: details.tasks,
          nextId: details.nextId,
          listTitle: details.listTitle,
          listDescription: details.listDescription,
          undoState: details.undoState,
        });
      }
    }

    refreshUI(ctx);
  }

  pi.on("session_start", async (_event, ctx) => {
    nudgedThisCycle = false;
    reconstructState(ctx);
  });
  pi.on("session_switch", async (_event, ctx) => {
    nudgedThisCycle = false;
    reconstructState(ctx);
  });
  pi.on("session_fork", async (_event, ctx) => {
    nudgedThisCycle = false;
    reconstructState(ctx);
  });
  pi.on("session_tree", async (_event, ctx) => {
    nudgedThisCycle = false;
    reconstructState(ctx);
  });

  // ── Blocking gate ────────────────────────────────────────────────────

  pi.on("tool_call", async (event) => {
    if (event.toolName === "tilldone") return { block: false };

    const pending = tasks.filter((t) => t.status !== "done");
    const active = tasks.filter((t) => t.status === "inprogress");

    if (tasks.length === 0) {
      return {
        block: true,
        reason:
          "No TillDone tasks defined. You MUST use `tilldone new-list` or `tilldone add` to define your tasks before using any other tools. Plan your work first!",
      };
    }
    if (pending.length === 0) {
      return {
        block: true,
        reason:
          "All TillDone tasks are done. You MUST use `tilldone add` for new tasks or `tilldone new-list` to start a fresh list before using any other tools.",
      };
    }
    if (active.length === 0) {
      return {
        block: true,
        reason:
          "No task is in progress. You MUST use `tilldone toggle` to mark a task as inprogress before doing any work.",
      };
    }

    return { block: false };
  });

  // ── Auto-nudge on agent_end ──────────────────────────────────────────

  pi.on("agent_end", async () => {
    const incomplete = tasks.filter((t) => t.status !== "done");
    if (incomplete.length === 0 || nudgedThisCycle) return;

    nudgedThisCycle = true;

    const taskList = incomplete
      .map((t) => `  ${STATUS_ICON[t.status]} #${t.id} [${STATUS_LABEL[t.status]}]: ${t.text}`)
      .join("\n");

    pi.sendMessage(
      {
        customType: "tilldone-nudge",
        content:
          `You still have ${incomplete.length} incomplete task(s):\n\n${taskList}\n\n` +
          "Either continue working on them or mark them done with `tilldone toggle`. Don't stop until it's done!",
        display: true,
      },
      { triggerTurn: true },
    );
  });

  pi.on("input", async () => {
    nudgedThisCycle = false;
    return { action: "continue" as const };
  });

  // ── Register tilldone tool ───────────────────────────────────────────

  pi.registerTool({
    name: "tilldone",
    label: "TillDone",
    description:
      "Manage your task list. You MUST add tasks before using any other tools. " +
      "Actions: new-list (text=title, description, optional texts[] seed tasks), add (text or texts[] for batch), " +
      "toggle (id) — cycles idle→inprogress→done, remove (id), update (id + text), list, clear, undo. " +
      "Task text is normalized, vague/duplicate tasks are skipped, and lists are capped at 7 tasks. " +
      "Always toggle a task to inprogress before starting work on it, and to done when finished. " +
      "Use new-list to start a themed list with a title and description. " +
      "If the user's new request does not fit the current list's theme, use clear then new-list.",
    parameters: TillDoneParams,

    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      switch (params.action) {
        case "new-list": {
          const title = params.text ? normalizeTaskText(params.text) : "";
          if (!title) {
            return {
              content: [{ type: "text" as const, text: "Error: text (title) required for new-list" }],
              details: makeDetails("new-list", "text required"),
            };
          }

          const seededTexts = params.texts ?? [];
          const prepared = prepareTaskTexts(seededTexts, []);
          if (prepared.error === "too many tasks") {
            const errorText =
              `Error: Too many tasks. Keep the list at ${MAX_TASKS} tasks or fewer.`;
            return {
              content: [{ type: "text" as const, text: appendPreparationNotes(errorText, prepared) }],
              details: makeDetails("new-list", "too many tasks"),
            };
          }

          rememberUndo();

          nextId = 1;
          tasks = prepared.accepted.map((item) => ({
            id: nextId++,
            text: item,
            status: "idle" as const,
          }));
          listTitle = title;
          listDescription = params.description ? normalizeTaskText(params.description) : undefined;

          const activated = autoActivateTask(tasks, tasks[0]?.id);
          tasks = activated.tasks;

          if (tasks.length === 0) {
            nextId = 1;
          }
          refreshUI(ctx);

          let text = `New list: "${listTitle}"${listDescription ? ` — ${listDescription}` : ""}`;
          if (tasks.length > 0) {
            text += ` (${tasks.length} task(s)`;
            if (activated.activatedId !== undefined) {
              text += `, auto-started #${activated.activatedId}`;
            }
            text += ")";
          }
          text = appendPreparationNotes(text, prepared);

          return {
            content: [
              {
                type: "text" as const,
                text,
              },
            ],
            details: makeDetails("new-list"),
          };
        }

        case "list": {
          const header = listTitle ? `${listTitle}:` : "";
          refreshUI(ctx);
          return {
            content: [
              {
                type: "text" as const,
                text: tasks.length
                  ? (header ? header + "\n" : "") +
                    tasks
                      .map((t) => `[${STATUS_ICON[t.status]}] #${t.id} (${t.status}): ${t.text}`)
                      .join("\n")
                  : "No tasks defined yet.",
              },
            ],
            details: makeDetails("list"),
          };
        }

        case "add": {
          const items = params.texts?.length ? params.texts : params.text ? [params.text] : [];
          if (items.length === 0) {
            return {
              content: [{ type: "text" as const, text: "Error: text or texts required for add" }],
              details: makeDetails("add", "text required"),
            };
          }

          const prepared = prepareTaskTexts(items, tasks);
          if (prepared.error) {
            const errorText =
              prepared.error === "too many tasks"
                ? `Error: Too many tasks. Keep the list at ${MAX_TASKS} tasks or fewer.`
                : "Error: no valid tasks to add.";
            return {
              content: [{ type: "text" as const, text: appendPreparationNotes(errorText, prepared) }],
              details: makeDetails("add", prepared.error),
            };
          }

          rememberUndo();

          const added: Task[] = [];
          for (const item of prepared.accepted) {
            const t: Task = { id: nextId++, text: item, status: "idle" };
            tasks.push(t);
            added.push(t);
          }

          const activated = autoActivateTask(tasks, added[0]?.id);
          tasks = activated.tasks;
          refreshUI(ctx);

          const msg =
            added.length === 1
              ? `Added task #${added[0].id}: ${added[0].text}`
              : `Added ${added.length} tasks: ${added.map((t) => `#${t.id}`).join(", ")}`;

          return {
            content: [
              {
                type: "text" as const,
                text: appendPreparationNotes(
                  activated.activatedId !== undefined
                    ? `${msg}\n(Auto-started #${activated.activatedId}.)`
                    : msg,
                  prepared,
                ),
              },
            ],
            details: makeDetails("add"),
          };
        }

        case "toggle": {
          if (params.id === undefined) {
            return {
              content: [{ type: "text" as const, text: "Error: id required for toggle" }],
              details: makeDetails("toggle", "id required"),
            };
          }
          const task = tasks.find((t) => t.id === params.id);
          if (!task) {
            return {
              content: [{ type: "text" as const, text: `Task #${params.id} not found` }],
              details: makeDetails("toggle", `#${params.id} not found`),
            };
          }

          const nextStatus = nextToggleStatus(task.status);
          if (!nextStatus) {
            return {
              content: [
                {
                  type: "text" as const,
                  text: `Task #${task.id} is already done. Done tasks do not reopen via toggle.`,
                },
              ],
              details: makeDetails("toggle"),
            };
          }

          rememberUndo();

          const prev = task.status;
          let demotedIds: number[] = [];
          if (nextStatus === "inprogress") {
            const nextTasks = setExclusiveInProgress(tasks, task.id);
            tasks = nextTasks.tasks;
            demotedIds = nextTasks.demotedIds;
          } else {
            tasks = tasks.map((entry) =>
              entry.id === task.id ? { ...entry, status: nextStatus } : { ...entry },
            );
          }

          refreshUI(ctx);

          let msg = `Task #${task.id}: ${prev} → ${nextStatus}`;
          if (demotedIds.length > 0) {
            msg += `\n(Auto-paused ${demotedIds.map((id) => `#${id}`).join(", ")} → idle. Only one task can be in progress at a time.)`;
          }
          return {
            content: [{ type: "text" as const, text: msg }],
            details: makeDetails("toggle"),
          };
        }

        case "remove": {
          if (params.id === undefined) {
            return {
              content: [{ type: "text" as const, text: "Error: id required for remove" }],
              details: makeDetails("remove", "id required"),
            };
          }
          const idx = tasks.findIndex((t) => t.id === params.id);
          if (idx === -1) {
            return {
              content: [{ type: "text" as const, text: `Task #${params.id} not found` }],
              details: makeDetails("remove", `#${params.id} not found`),
            };
          }
          rememberUndo();
          const removed = tasks.splice(idx, 1)[0];
          const normalized = normalizeTasks(tasks, { autoActivatePending: true });
          tasks = normalized.tasks;
          refreshUI(ctx);

          let text = `Removed task #${removed.id}: ${removed.text}`;
          if (normalized.activatedId !== undefined) {
            text += `\n(Auto-started #${normalized.activatedId}.)`;
          }
          return {
            content: [{ type: "text" as const, text }],
            details: makeDetails("remove"),
          };
        }

        case "update": {
          if (params.id === undefined) {
            return {
              content: [{ type: "text" as const, text: "Error: id required for update" }],
              details: makeDetails("update", "id required"),
            };
          }
          if (!params.text) {
            return {
              content: [{ type: "text" as const, text: "Error: text required for update" }],
              details: makeDetails("update", "text required"),
            };
          }
          const toUpdate = tasks.find((t) => t.id === params.id);
          if (!toUpdate) {
            return {
              content: [{ type: "text" as const, text: `Task #${params.id} not found` }],
              details: makeDetails("update", `#${params.id} not found`),
            };
          }

          const nextText = normalizeTaskText(compileTodoIntent(params.text));
          const invalidReason = validateTaskText(nextText);
          if (invalidReason) {
            return {
              content: [{ type: "text" as const, text: `Error: ${invalidReason}.` }],
              details: makeDetails("update", invalidReason),
            };
          }

          const isDuplicate = tasks.some(
            (task) => task.id !== toUpdate.id && buildTaskTextKey(task.text) === buildTaskTextKey(nextText),
          );
          if (isDuplicate) {
            return {
              content: [{ type: "text" as const, text: `Error: duplicate task text "${nextText}".` }],
              details: makeDetails("update", "duplicate task"),
            };
          }

          if (toUpdate.text === nextText) {
            return {
              content: [{ type: "text" as const, text: `No change for #${toUpdate.id}` }],
              details: makeDetails("update"),
            };
          }

          rememberUndo();
          const oldText = toUpdate.text;
          toUpdate.text = nextText;
          refreshUI(ctx);
          return {
            content: [
              { type: "text" as const, text: `Updated #${toUpdate.id}: "${oldText}" → "${toUpdate.text}"` },
            ],
            details: makeDetails("update"),
          };
        }

        case "clear": {
          rememberUndo();
          const count = tasks.length;
          tasks = [];
          nextId = 1;
          listTitle = undefined;
          listDescription = undefined;
          refreshUI(ctx);

          return {
            content: [{ type: "text" as const, text: `Cleared ${count} task(s)` }],
            details: makeDetails("clear"),
          };
        }

        case "undo": {
          if (!undoState) {
            return {
              content: [{ type: "text" as const, text: "Nothing to undo" }],
              details: makeDetails("undo"),
            };
          }

          applyState(undoState);
          refreshUI(ctx);

          return {
            content: [{ type: "text" as const, text: "Undid last TillDone change" }],
            details: makeDetails("undo"),
          };
        }

        default:
          return {
            content: [{ type: "text" as const, text: `Unknown action: ${params.action}` }],
            details: makeDetails("list", `unknown action: ${params.action}`),
          };
      }
    },

    renderCall(args, theme) {
      let text = theme.fg("accent", theme.bold("tilldone ")) + theme.fg("muted", args.action);
      if (args.texts?.length) text += ` ${theme.fg("dim", `${args.texts.length} tasks`)}`;
      else if (args.text) text += ` ${theme.fg("dim", `"${args.text}"`)}`;
      if (args.description) text += ` ${theme.fg("dim", `— ${args.description}`)}`;
      if (args.id !== undefined) text += ` ${theme.fg("accent", `#${args.id}`)}`;
      return new Text(text, 0, 0);
    },

    renderResult(result, { expanded }, theme) {
      const details = result.details as TillDoneDetails | undefined;
      if (!details) {
        const text = result.content[0];
        return new Text(text?.type === "text" ? text.text : "", 0, 0);
      }

      if (details.error) {
        return new Text(theme.fg("error", `Error: ${details.error}`), 0, 0);
      }

      const taskList = details.tasks;

      switch (details.action) {
        case "new-list": {
          let msg = theme.fg("success", "✓ New list ") + theme.fg("accent", `"${details.listTitle}"`);
          if (details.listDescription) {
            msg += theme.fg("dim", ` — ${details.listDescription}`);
          }
          return new Text(msg, 0, 0);
        }

        case "list": {
          if (taskList.length === 0) return new Text(theme.fg("dim", "No tasks"), 0, 0);
          let listText = "";
          if (details.listTitle) {
            listText += theme.fg("accent", details.listTitle) + theme.fg("dim", "  ");
          }
          listText += theme.fg("muted", `${taskList.length} task(s):`);
          const display = expanded ? taskList : taskList.slice(0, 5);
          for (const t of display) {
            const icon =
              t.status === "done"
                ? theme.fg("success", STATUS_ICON.done)
                : t.status === "inprogress"
                  ? theme.fg("accent", STATUS_ICON.inprogress)
                  : theme.fg("dim", STATUS_ICON.idle);
            const itemText =
              t.status === "done"
                ? theme.fg("dim", t.text)
                : t.status === "inprogress"
                  ? theme.fg("success", t.text)
                  : theme.fg("muted", t.text);
            listText += `\n${icon} ${theme.fg("accent", `#${t.id}`)} ${itemText}`;
          }
          if (!expanded && taskList.length > 5) {
            listText += `\n${theme.fg("dim", `... ${taskList.length - 5} more`)}`;
          }
          return new Text(listText, 0, 0);
        }

        case "add":
        case "update": {
          const text = result.content[0];
          return new Text(
            theme.fg("success", "✓ ") + theme.fg("muted", text?.type === "text" ? text.text : ""),
            0,
            0,
          );
        }

        case "toggle": {
          const text = result.content[0];
          return new Text(
            theme.fg("accent", "⟳ ") + theme.fg("muted", text?.type === "text" ? text.text : ""),
            0,
            0,
          );
        }

        case "remove": {
          const text = result.content[0];
          return new Text(
            theme.fg("warning", "✕ ") + theme.fg("muted", text?.type === "text" ? text.text : ""),
            0,
            0,
          );
        }

        case "clear":
          return new Text(theme.fg("success", "✓ ") + theme.fg("muted", "Cleared all tasks"), 0, 0);

        case "undo": {
          const text = result.content[0];
          return new Text(
            theme.fg("accent", "↶ ") + theme.fg("muted", text?.type === "text" ? text.text : ""),
            0,
            0,
          );
        }

        default:
          return new Text(theme.fg("dim", "done"), 0, 0);
      }
    },
  });

  // ── /tilldone command ────────────────────────────────────────────────

  pi.registerCommand("tilldone", {
    description: "Show all TillDone tasks in an interactive overlay",
    handler: async (_args, ctx) => {
      if (!ctx.hasUI) {
        ctx.ui.notify("/tilldone requires interactive mode", "error");
        return;
      }

      await ctx.ui.custom<void>((_tui, theme, _kb, done) => {
        return new TillDoneListComponent(tasks, listTitle, listDescription, theme, () => done());
      });
    },
  });
}
