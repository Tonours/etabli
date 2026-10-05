import assert from "node:assert/strict";
import { test } from "node:test";
import {
  assertJsonExpectations,
  assertCommandReceipt,
  assertionProtocol,
  jsonPointer,
} from "../scripts/lib/project-verification-assertions.mjs";

test("RFC6901 selects own values, escaped keys, array indices and the whole document", () => {
  const value = {
    "a/b": { "~key": [null, false, 0] },
    "~1": "one escape pass",
  };
  assert.equal(jsonPointer(value, "/a~1b/~0key/1"), false);
  assert.equal(jsonPointer(value, "/~01"), "one escape pass");
  assert.equal(jsonPointer(value, ""), value);
  assert.equal(
    assertJsonExpectations(value, [
      { pointer: "/a~1b/~0key/0", expected: null },
      { pointer: "/a~1b/~0key/2", expected: 0 },
    ]),
    true,
  );
});

test("absent values cannot equal null and inherited values are unavailable", () => {
  assert.throws(
    () => assertJsonExpectations({}, [{ pointer: "/missing", expected: null }]),
    /Missing observation/,
  );
  assert.throws(
    () => jsonPointer(Object.create({ inherited: true }), "/inherited"),
    /Missing observation/,
  );
  assert.throws(() => jsonPointer({}, "/constructor"), /Missing observation/);
});

for (const pointer of ["missing-slash", "/~2", "/trailing~", "/~"]) {
  test(`invalid pointer ${pointer} is rejected`, () =>
    assert.throws(() => jsonPointer({}, pointer), /RFC6901/));
}

test("array pointers reject leading zeros, the append token and non-index properties", () => {
  for (const pointer of ["/01", "/-", "/length"])
    assert.throws(() => jsonPointer([1, 2], pointer));
});

test("expectations use typed deep equality rather than string coercion or key order", () => {
  assert.throws(
    () =>
      assertJsonExpectations({ value: "1" }, [
        { pointer: "/value", expected: 1 },
      ]),
    /frozen expectation/,
  );
  assertJsonExpectations({ value: { a: 1, b: true } }, [
    { pointer: "/value", expected: { b: true, a: 1 } },
  ]);
});

test("missing or malformed assertions cannot provide a vacuum pass", () => {
  for (const assertions of [
    [],
    undefined,
    [{ pointer: "" }],
    [{ pointer: "", expected: true, passed: true }],
  ])
    assert.throws(() => assertJsonExpectations(true, assertions));
});


for (const allowOwnedShutdown of [false,true]) {
  test(`forced receipt marker is strict and legacy-compatible: owned shutdown ${allowOwnedShutdown}`, () => {
    const command = {argv:["node","app.mjs"],timeout_ms:1000};
    const receipt = {
      protocol:assertionProtocol,argv:command.argv,timeout_ms:1000,pid:123,
      started_at:"2026-10-03T00:00:00Z",ended_at:"2026-10-03T00:00:01Z",
      exit_code:0,signal:null,timed_out:false,stdout_sha256:"a".repeat(64),
      owned_shutdown:true,ready_observed:true,unexpected_exit:false,
    };
    assertCommandReceipt(receipt,command,{}, {allowOwnedShutdown});
    assertCommandReceipt({...receipt,completion_forced:false},command,{}, {allowOwnedShutdown});
    for (const marker of [true,null,undefined,"false",0])
      assert.throws(() => assertCommandReceipt({...receipt,completion_forced:marker},command,{}, {allowOwnedShutdown}),/forced/i);
  });
}
