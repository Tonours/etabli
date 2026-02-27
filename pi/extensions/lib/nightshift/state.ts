import { existsSync, readFileSync, writeFileSync, renameSync } from "node:fs";
import { dirname, join } from "node:path";
import type { NightshiftState, NightshiftTaskState } from "./types.ts";

const EMPTY_STATE: NightshiftState = { version: 1, tasks: {} };

export function readState(stateFile: string): NightshiftState {
  if (!existsSync(stateFile)) return { ...EMPTY_STATE, tasks: {} };

  const raw = readFileSync(stateFile, "utf-8");
  const data = JSON.parse(raw) as NightshiftState;
  return data;
}

export function writeState(stateFile: string, state: NightshiftState): void {
  const tmpFile = join(dirname(stateFile), `.state-${process.pid}-${Date.now()}.tmp`);
  writeFileSync(tmpFile, JSON.stringify(state, null, 2) + "\n", "utf-8");
  renameSync(tmpFile, stateFile);
}

export function updateTaskState(
  stateFile: string,
  taskId: string,
  key: keyof NightshiftTaskState,
  value: string,
): void {
  let state: NightshiftState;
  try {
    state = readState(stateFile);
  } catch {
    state = { ...EMPTY_STATE, tasks: {} };
  }

  if (!state.tasks[taskId]) {
    state.tasks[taskId] = {};
  }
  state.tasks[taskId][key] = value;

  writeState(stateFile, state);
}
