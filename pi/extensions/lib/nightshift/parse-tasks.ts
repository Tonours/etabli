import type { NightshiftTask } from "./types.ts";

const ID_RE = /^##\s+TASK\s+(.+?)\s*$/;
const KV_RE = /^([a-zA-Z][a-zA-Z0-9_-]*):\s*(.*?)\s*$/;

export function normalizeTaskId(raw: string): string {
  return raw
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9._-]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

export function parseTasks(content: string): NightshiftTask[] {
  const lines = content.split("\n");
  const tasks: NightshiftTask[] = [];

  let cur: Record<string, unknown> | null = null;
  let mode: "verify" | "prompt" | null = null;

  function finish(): void {
    if (!cur) return;

    cur.id = normalizeTaskId(cur.id as string);
    if (!cur.base) cur.base = "main";
    if (!cur.engine) cur.engine = "codex";
    if (!cur.verify) cur.verify = [];
    if (!cur.prompt) cur.prompt = "";
    if (!cur.branch) cur.branch = `night/${cur.id}`;

    tasks.push(cur as unknown as NightshiftTask);
    cur = null;
    mode = null;
  }

  for (const line of lines) {
    const idMatch = ID_RE.exec(line);
    if (idMatch) {
      finish();
      cur = { id: idMatch[1].trim() };
      continue;
    }

    if (cur === null) continue;

    if (mode === "prompt") {
      if (line.trim() === "ENDPROMPT") {
        mode = null;
      } else {
        cur.prompt = (cur.prompt as string) + line + "\n";
      }
      continue;
    }

    if (mode === "verify") {
      if (line.trimStart().startsWith("- ")) {
        const items = cur.verify as string[];
        items.push(line.trim().slice(2).trim());
        continue;
      }
      mode = null;
    }

    if (!line.trim()) continue;

    if (line.trim() === "verify:") {
      mode = "verify";
      if (!cur.verify) cur.verify = [];
      continue;
    }

    if (line.trim() === "prompt:") {
      mode = "prompt";
      cur.prompt = "";
      continue;
    }

    const kvMatch = KV_RE.exec(line);
    if (kvMatch) {
      const key = kvMatch[1];
      if (key !== "__proto__" && key !== "constructor" && key !== "prototype") {
        cur[key] = kvMatch[2];
      }
    }
  }

  finish();
  return tasks;
}
