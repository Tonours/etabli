import { describe, expect, test } from "bun:test";
import { Task, validateTarget } from "../core.ts";

const fact = { kind: "command_executed" as const, hostname: "fixture-host", cwd: "/fixture", platform: "Linux", code: 0, killed: false, truncated: false };

describe("execution receipts", () => {
  test("rejects forged and old evidence", () => {
    const task = new Task("local"); task.startCall();
    expect(() => task.finish("done", [{ receipt_id: "invented", kind: "command_executed" }], "")).toThrow("unknown_receipt");
    const old = task.record(fact); const fresh = new Task("local"); fresh.startCall();
    expect(() => fresh.finish("done", [{ receipt_id: old.id, kind: "command_executed" }], "")).toThrow("unknown_receipt");
  });
  test("validates actual successful kind, never provider ID", () => {
    const task = new Task("remote-fixture"); task.startCall();
    const receipt = task.record({ ...fact, providerCallId: "call_0" });
    const second = task.record({ ...fact, providerCallId: "call_0" });
    expect(second.id).not.toBe(receipt.id);
    task.nextTurn(); task.startCall();
    expect(task.finish("done", [{ receipt_id: receipt.id, kind: "command_executed" }], "model note").actions[0]?.target).toBe("remote-fixture");
    expect(task.terminal).toBe("accepted");
  });
  test("failed and truncated results cannot prove success", () => {
    for (const change of [{ code: 127 }, { killed: true }, { truncated: true }]) {
      const task = new Task("local"); const r = task.record({ ...fact, ...change }); task.startCall();
      expect(() => task.finish("done", [{ receipt_id: r.id, kind: r.kind }], "")).toThrow("unsuccessful_receipt");
    }
  });
  test("wrong claim kind and empty done are refused", () => {
    const task = new Task("local"); const r = task.record(fact); task.startCall();
    expect(() => task.finish("done", [], "")).toThrow("evidence_required");
    expect(() => task.finish("done", [{ receipt_id: r.id, kind: "file_written" }], "")).toThrow("wrong_receipt_kind");
    expect(() => task.finish("done", [{ receipt_id: r.id, kind: "page_rendered" }], "")).toThrow();
  });
  test("finish must be first, including unknown and invalid predecessors", () => {
    const task = new Task("local"); const r = task.record(fact); task.startCall(); task.startCall();
    expect(() => task.finish("done", [{ receipt_id: r.id, kind: r.kind }], "")).toThrow("finish_alone");
  });
  test("eight calls include finish, then budget prevents continuation", () => {
    const task = new Task("local"); for (let i = 0; i < 8; i++) task.startCall();
    expect(task.terminal).toBeNull(); task.startCall(); expect(task.terminal).toBe("budget");
    expect(task.needsCorrection()).toBe(false);
  });
  test("one correction, no reset from another turn", () => {
    const task = new Task("local"); expect(task.needsCorrection()).toBe(true);
    task.nextTurn(); expect(task.needsCorrection()).toBe(false);
    task.interrupt("deadline"); expect(task.needsCorrection()).toBe(false);
  });
  test("blocked and answer attest no invented actions", () => {
    for (const status of ["answer", "blocked"] as const) {
      const task = new Task("local"); task.startCall();
      expect(task.finish(status, [], "plain model response").actions).toEqual([]);
    }
  });
  test("target is a frozen owner value, options are rejected", () => {
    for (const value of ["local", "gromarchy", "host.local", "owner@host"]) expect(validateTarget(value)).toBe(value);
    for (const value of ["-oProxyCommand=bad", "host;bad", "host\nother", "", "host name"]) expect(() => validateTarget(value)).toThrow();
    const task = new Task("gromarchy"); expect(task.target).toBe("gromarchy");
  });
});

test("inconsistent stored target or task cannot validate a receipt", () => {
  for (const change of [{ target: "different-host" }, { taskId: "different-task" }]) {
    const task = new Task("local"); const receipt = task.record(fact); task.startCall();
    task.receipts.set(receipt.id, { ...receipt, ...change });
    expect(() => task.finish("done", [{ receipt_id: receipt.id, kind: receipt.kind }], "")).toThrow("wrong_target");
  }
});

test("blocked can cite actual failure without claiming success", () => {
  const task = new Task("local"); const r = task.record({ ...fact, code: 1 }); task.startCall();
  expect(task.finish("blocked", [{ receipt_id: r.id, kind: r.kind }], "command failed").actions[0]?.code).toBe(1);
});
