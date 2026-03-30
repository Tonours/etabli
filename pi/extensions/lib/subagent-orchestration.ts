export type SubagentRole = "scout" | "worker" | "reviewer";

export type MinimalSubagentState = {
  status: "running" | "done" | "error";
  role?: SubagentRole;
};

export function canSpawnRole(
  states: MinimalSubagentState[],
  role: SubagentRole | undefined,
  allowParallelWorkers = false,
): string | null {
  if (role !== "worker" || allowParallelWorkers) {
    return null;
  }

  const runningWorker = states.some((state) => state.status === "running" && state.role === "worker");
  if (!runningWorker) {
    return null;
  }

  return "Error: a worker subagent is already running. Finish it first or set allowParallelWorkers=true only when work is explicitly isolated.";
}
