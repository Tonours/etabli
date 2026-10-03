import assert from "node:assert/strict";
import { test } from "node:test";
import {
  assertJsonExpectations,
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
