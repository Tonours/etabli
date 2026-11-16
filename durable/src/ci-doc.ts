import { defineDoc } from "@earendil-works/pi-durable";
import type { Run } from "./runs-doc.ts";

export type Check = { name: string; conclusion: string; url: string };
export type CiAttempt = { number: number; triggerHead: string; checks: Check[]; input: string; requestId: string; state: "reserved" | "submitted" | "cancelled" };
export type CiRun = { runId: string; url: string; head: string; originalStartedAt: number; nextPollAt: number; backoff: number; retired: string; attempts: CiAttempt[] };
export const CiDoc = defineDoc<{ runs: CiRun[] }>({ kind: "etabli.ci", version: 1, scope: "session", initial: () => ({ runs: [] }), checkpointWhen: () => true });
export function terminalGeneration(run: Readonly<Run>, ci?: Readonly<CiRun>): string {
  if (run.reason === "ci_attempts_exhausted") return "ci-exhausted";
  const attempt = ci?.attempts.filter((attempt) => attempt.state === "submitted").at(-1);
  return attempt ? `ci-${attempt.number}` : "";
}
