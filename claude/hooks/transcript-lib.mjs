import { readFileSync } from "node:fs";

// Shared Claude transcript JSONL reading. Role matching stays per-hook:
// each hook's envelope assumptions are pinned by its own smoke test.
export function readJsonLines(transcriptPath) {
  if (!transcriptPath) return { lines: [], readable: true };
  try {
    const lines = readFileSync(transcriptPath, "utf8")
      .split("\n")
      .filter((l) => l.trim() !== "");
    return { lines, readable: true };
  } catch {
    return { lines: [], readable: false };
  }
}

export function parseJsonLine(line) {
  let entry;
  try {
    entry = JSON.parse(line);
  } catch {
    return null;
  }
  return typeof entry === "object" && entry !== null ? entry : null;
}
