import { randomBytes } from "node:crypto";

export type Kind = "command_executed" | "file_read" | "file_written" | "open_requested";
export type Status = "done" | "blocked" | "answer";
export interface Fact {
  kind: Kind;
  hostname: string;
  cwd: string;
  platform: string;
  code: number;
  killed: boolean;
  truncated: boolean;
  providerCallId?: string;
  path?: string;
  stdout?: string;
  stderr?: string;
}
export interface Receipt extends Fact { id: string; taskId: string; target: string }
export interface Claim { receipt_id: string; kind: string }
export interface Completion {
  status: Status;
  taskId: string;
  target: string;
  actions: Receipt[];
  model_note: string;
  note_is_verified: false;
}

export function validateTarget(value: string): string {
  if (!/^[a-zA-Z0-9][a-zA-Z0-9_.@-]{0,127}$/.test(value)) throw new Error("invalid_target");
  return value;
}

export class Task {
  readonly id = randomBytes(6).toString("hex");
  readonly target: string;
  readonly receipts = new Map<string, Receipt>();
  position = 0;
  calls = 0;
  retried = false;
  terminal: "accepted" | "budget" | "deadline" | "aborted" | "unvalidated" | null = null;
  completion: Completion | null = null;

  constructor(target: string) { this.target = validateTarget(target); }
  nextTurn() { this.position = 0; }
  startCall() {
    this.position++;
    this.calls++;
    if (!this.terminal && this.calls > 8) this.terminal = "budget";
  }
  interrupt(reason: "deadline" | "aborted" | "unvalidated") {
    if (!this.terminal) this.terminal = reason;
  }
  record(fact: Fact): Receipt {
    if (this.terminal) throw new Error("task_terminal");
    const receipt = { ...fact, id: `${this.id}-R${this.receipts.size + 1}`, taskId: this.id, target: this.target };
    this.receipts.set(receipt.id, Object.freeze(receipt));
    return receipt;
  }
  finish(status: Status, claims: Claim[], note: string): Completion {
    if (this.terminal) throw new Error("task_terminal");
    if (this.position !== 1) throw new Error("finish_alone: call finish_task first, in its own message");
    if (!["done", "blocked", "answer"].includes(status)) throw new Error("invalid_status");
    if (status === "done" && claims.length === 0) throw new Error("evidence_required");
    const seen = new Set<string>();
    const actions = claims.map((claim) => {
      const receipt = this.receipts.get(claim.receipt_id);
      if (!receipt || seen.has(claim.receipt_id)) throw new Error("unknown_receipt");
      seen.add(claim.receipt_id);
      if (claim.kind !== receipt.kind) throw new Error("wrong_receipt_kind");
      if (receipt.target !== this.target || receipt.taskId !== this.id) throw new Error("wrong_target");
      if (status === "done" && (receipt.code !== 0 || receipt.killed || receipt.truncated)) throw new Error("unsuccessful_receipt");
      return receipt;
    });
    this.completion = { status, taskId: this.id, target: this.target, actions, model_note: note, note_is_verified: false };
    this.terminal = "accepted";
    return this.completion;
  }
  needsCorrection(): boolean {
    if (this.terminal || this.retried) return false;
    this.retried = true;
    return true;
  }
}
