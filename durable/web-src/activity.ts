import { toolSummary } from "../shared/runs-view.ts";

export const CLIP_AT = 20_000, CLIP_KEEP = 10_000, BLOCK_LIMIT = 300, EXCERPT = 280;

type Content = string | readonly { type?: string; text?: string; name?: string; arguments?: unknown }[] | undefined;
type ModelPart = { role?: string; content?: Content; toolName?: string; timestamp?: unknown };
export type Entry = { id: number; kind?: string; model?: readonly ModelPart[] };
type InboxItem = { id?: number; mode?: string; content?: Content };
type LiveTool = { callId?: string; name?: string; status?: string; output?: Content };
export type Frame = {
  entries?: readonly Entry[]; before?: number;
  docs?: Record<string, unknown> & {
    "pi.live"?: { run?: { turns?: number }; tools?: readonly LiveTool[]; generation?: { message?: { content?: Content } } };
    "pi.inbox"?: { items?: readonly InboxItem[] };
    "pi.agent"?: { maxTurns?: number };
  };
};
export type Part =
  | { kind: "text"; who: string; text: string }
  | { kind: "tool"; name: string; summary: string; body: string }
  | { kind: "result"; name: string; text: string };
export type Block = { id: string; parts: Part[]; time?: number; gap?: boolean };

export function clip(text: string): string {
  return text.length <= CLIP_AT ? text : `${text.slice(0, CLIP_KEEP)}\n… ${text.length - 2 * CLIP_KEEP} characters not shown …\n${text.slice(-CLIP_KEEP)}`;
}

export function contentText(content: Content): string {
  if (typeof content === "string") return content;
  return (content ?? []).map((part) => part.type === "text" ? part.text ?? "" : part.type === "image" ? "[image]" : "").filter(Boolean).join("\n");
}

function toolParts(content: Content): Part[] {
  if (typeof content === "string" || !content) return [];
  return content.filter((part) => part.type === "toolCall").map((part) => {
    const body = JSON.stringify(part.arguments ?? {}, null, 2);
    return { kind: "tool", name: part.name ?? "tool", summary: toolSummary(part.arguments), body: clip(body) };
  });
}

export function entryBlock(entry: Entry): Block | undefined {
  const parts: Part[] = [];
  let time: number | undefined;
  for (const part of entry.model ?? []) {
    if (typeof part.timestamp === "number") time = part.timestamp;
    const text = contentText(part.content);
    if (part.role === "assistant") {
      if (text) parts.push({ kind: "text", who: "Assistant", text: clip(text) });
      parts.push(...toolParts(part.content));
    } else if (part.role === "user") {
      if (text) parts.push({ kind: "text", who: "You", text: clip(text) });
    } else if (part.role === "toolResult") {
      parts.push({ kind: "result", name: part.toolName ?? "tool", text: clip(text) });
    }
  }
  return parts.length ? { id: `entry-${entry.id}`, parts, time } : undefined;
}

export function liveBlock(frame: Frame): Block | undefined {
  const live = frame.docs?.["pi.live"];
  const parts: Part[] = [];
  const streaming = contentText(live?.generation?.message?.content);
  if (streaming) parts.push({ kind: "text", who: "Assistant (streaming)", text: clip(streaming) });
  for (const tool of live?.tools ?? []) {
    const output = contentText(tool.output);
    parts.push({ kind: "result", name: `${tool.name ?? "tool"} (running)`, text: clip(output) });
  }
  return parts.length ? { id: "live", parts } : undefined;
}

/** Only steer and follow-up items are instructions; write items and a missing inbox show nothing. */
export function queued(frame: Frame): string[] {
  const items = frame.docs?.["pi.inbox"]?.items;
  if (!Array.isArray(items)) return [];
  return items.filter((item) => item.mode === "steer" || item.mode === "followUp").map((item) => contentText(item.content)).filter(Boolean);
}

export function excerpt(block: Block | undefined): string {
  const part = block?.parts.at(-1);
  const text = !part ? "" : part.kind === "tool" ? `${part.name} ${part.summary}` : part.kind === "result" ? `${part.name}: ${part.text}` : part.text;
  return text.length > EXCERPT ? `${text.slice(0, EXCERPT)}…` : text;
}
