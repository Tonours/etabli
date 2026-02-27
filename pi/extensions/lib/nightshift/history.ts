import { existsSync, readFileSync, writeFileSync, renameSync } from "node:fs";
import { dirname, join } from "node:path";
import type { NightshiftHistoryEntry } from "./types.ts";

export function appendHistory(historyFile: string, entry: NightshiftHistoryEntry): void {
  writeFileSync(historyFile, JSON.stringify(entry) + "\n", { encoding: "utf-8", flag: "a" });
}

export function readHistory(historyFile: string): NightshiftHistoryEntry[] {
  if (!existsSync(historyFile)) return [];

  const lines = readFileSync(historyFile, "utf-8")
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l.length > 0);

  const entries: NightshiftHistoryEntry[] = [];
  for (const line of lines) {
    try {
      entries.push(JSON.parse(line) as NightshiftHistoryEntry);
    } catch {
      // skip malformed lines
    }
  }
  return entries;
}

export function pruneHistory(historyFile: string, maxEntries: number = 1000): void {
  if (!existsSync(historyFile)) return;

  const entries = readHistory(historyFile);
  if (entries.length <= maxEntries) return;

  const kept = entries.slice(-maxEntries);
  const content = kept.map((e) => JSON.stringify(e)).join("\n") + "\n";

  const tmpFile = join(dirname(historyFile), `.history-${process.pid}-${Date.now()}.tmp`);
  writeFileSync(tmpFile, content, "utf-8");
  renameSync(tmpFile, historyFile);
}
