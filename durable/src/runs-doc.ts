import { defineDoc, type ConversationId, type SubmissionId } from "@earendil-works/pi-durable";

export const activeStatuses = ["planning", "implementing", "reviewing", "publishing"] as const;
export type Run = {
  id: string; requestId: string; repo: string; prompt: string; conversationId: ConversationId;
  branch: string; worktree: string; route: "legacy" | "answer" | "plan";
  admissionRoute?: Run["route"];
  status: "queued" | typeof activeStatuses[number] | "done" | "blocked" | "aborted";
  reason: string; url: string; createdAt: number; startedAt: number; deadline: number; maxTurns: number;
  submissionId: SubmissionId | ""; notified: boolean;
};

export const RunsDoc = defineDoc<{ runs: Run[] }>({
  kind: "etabli.runs", version: 2, scope: "session", initial: () => ({ runs: [] }), checkpointWhen: () => true,
  migrate(value, from) {
    if (from !== 1 || !Array.isArray(value.runs)) throw new Error("Unsupported run store version");
    return { runs: value.runs.map((row) => {
      if (!row || typeof row !== "object" || Array.isArray(row) || !["queued", "busy", "done", "blocked", "aborted"].includes(String(row.status))) throw new Error("Invalid legacy run");
      if (["id", "requestId", "repo", "prompt", "branch", "worktree", "reason", "url"].some((key) => typeof row[key] !== "string") || ["conversationId", "createdAt", "startedAt", "deadline", "maxTurns"].some((key) => typeof row[key] !== "number") || (row.submissionId !== "" && typeof row.submissionId !== "number") || typeof row.notified !== "boolean") throw new Error("Invalid legacy run fields");
      return { ...row, status: row.status === "busy" ? "implementing" : row.status, route: "legacy" } as Run;
    }) };
  },
});

export function active(run: Readonly<Run>): boolean { return (activeStatuses as readonly string[]).includes(run.status); }
