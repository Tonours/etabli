import assert from "node:assert/strict";
import { test } from "node:test";
import {
  assertJsonExpectations,
  assertCommandReceipt,
  assertionProtocol,
  jsonPointer,
} from "../scripts/lib/project-verification-assertions.mjs";
import { observedUiEvidence, pendingUiEvidence, validateUiDeclaration } from "../scripts/lib/project-verification-ui.mjs";

const uiScope = {
  responsive_in_scope: true,
  motion_in_scope: false,
  reference_in_scope: false,
  not_applicable_reasons: { reduced_motion: "No animation", reference: "No supplied reference" },
  observation: { argv: ["node", "ui.mjs"], timeout_ms: 1000, assertions: [{ pointer: "/checks/focus", expected: true }] },
};
const uiObservation = {
  checks: { keyboard: true, focus: true, accessibility: true, console: true, network: true, responsive: true },
  viewports: [{ label: "desktop", width: 1280, height: 800 }, { label: "mobile", width: 390, height: 844 }],
};

test("UI derives evidence from observed checks and frozen scope; unscoped checks retain reasons", () => {
  validateUiDeclaration({ mode: "ui", ui: uiScope });
  validateUiDeclaration({});
  validateUiDeclaration({ mode: "product" });
  const evidence = observedUiEvidence(uiScope, uiObservation, "actual-ui");
  assert.deepEqual(evidence.checks.focus, { status: "passed", evidence: ["actual-ui"] });
  assert.deepEqual(evidence.checks.reference, { status: "not_applicable", evidence: [], reason: "No supplied reference" });
  assert.deepEqual(evidence.viewports[1], { ...uiObservation.viewports[1], evidence: ["actual-ui"] });
  assert.equal(pendingUiEvidence(uiScope).checks.focus.status, "blocked");
});

for (const check of ["keyboard", "focus", "accessibility", "console", "network", "responsive"])
  for (const value of [false, undefined, "true"])
    test(`UI rejects ${check} observation ${String(value)} independently of selected assertions`, () => {
      const observation = structuredClone(uiObservation);
      observation.checks[check] = value;
      assert.throws(() => observedUiEvidence(uiScope, observation, "raw"), /true observed check/);
    });

for (const check of ["reduced_motion", "reference"])
  test(`UI requires actually observed ${check} when scoped`, () => {
    const scope = { ...uiScope, [check === "reduced_motion" ? "motion_in_scope" : "reference_in_scope"]: true };
    assert.throws(() => observedUiEvidence(scope, uiObservation, "raw"));
    observedUiEvidence(scope, { ...uiObservation, checks: { ...uiObservation.checks, [check]: true } }, "raw");
  });

for (const viewports of [[], [{ label: "bad", width: 0, height: 800 }], [{ label: "one", width: 390, height: 844 }, { label: "renamed", width: 390, height: 844 }]])
  test(`UI rejects missing, invalid or duplicate responsive viewport ${JSON.stringify(viewports)}`, () =>
    assert.throws(() => observedUiEvidence(uiScope, { ...uiObservation, viewports }, "raw")));

test("a single viewport is valid only with responsive explicitly out of scope", () => {
  const scope = { ...uiScope, responsive_in_scope: false, not_applicable_reasons: { ...uiScope.not_applicable_reasons, responsive: "Fixed kiosk viewport" } };
  validateUiDeclaration({ mode: "ui", ui: scope });
  assert.equal(observedUiEvidence(scope, { ...uiObservation, viewports: uiObservation.viewports.slice(0, 1) }, "raw").checks.responsive.status, "not_applicable");
});

for (const recipe of [
  { mode: "ui" }, { mode: null }, { mode: "browser", ui: uiScope }, { ui: uiScope }, { mode: "product", ui: uiScope },
  { mode: "ui", ui: { ...uiScope, motion_in_scope: undefined } },
  { mode: "ui", ui: { ...uiScope, not_applicable_reasons: { reduced_motion: " " } } },
])
  test(`UI rejects incomplete declaration ${JSON.stringify(recipe)}`, () => assert.throws(() => validateUiDeclaration(recipe)));

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
