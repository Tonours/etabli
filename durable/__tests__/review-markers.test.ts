import { expect, test } from "bun:test";
import { reviewVerdict } from "../src/review.ts";

const rows = "| Item | Result |\n| source:1 | checked |";
const logic = `### Lens table\n${rows}\n### Deciding-code table\n${rows}\n### Open questions\nNone.\n`;
const threatHeadings = ["Deciding inputs", "Entry-point inventory", "Reused guards", "Deferrals", "Rollout", "Attack tests"];
const threat = threatHeadings.map(heading => `### ${heading}\n${rows}\n`).join("");
const closing = "Verdict: GO\nSTATUS: complete";

test("multiline marker boundaries refuse CR and Unicode duplicates but leave indented quotes unselected", () => {
  for (const separator of ["\r", "\u2028", "\u2029"]) {
    expect(() => reviewVerdict(`Verdict: BLOCK${separator}${closing}`, "code", "adversary")).toThrow("ambiguous");
  }
  expect(reviewVerdict("Findings\n Verdict: GO\nVerdict: BLOCK\nSTATUS: complete", "code", "adversary")).toBe("BLOCK");
});

test("a lone-CR duplicate required heading is refused", () => {
  expect(reviewVerdict(threat + closing, "code", "threat")).toBe("GO");
  expect(() => reviewVerdict(`${threat}\r### Attack tests\r\n\n${closing}`, "code", "threat")).toThrow("ambiguous");
});

for (const [kind, first, last] of [
  ["code", "BLOCK", "GO"], ["code", "GO", "BLOCK"], ["code", "GO", "GO"],
  ["code", "UNKNOWN", "GO"], ["plan", "CHALLENGED", "READY"], ["plan", "READY", "CHALLENGED"],
] as const) {
  test(`${kind}: two verdict lines sharing a completion cannot select ${last} after ${first}`, () => {
    expect(reviewVerdict(`Verdict: ${last}\n\nSTATUS: complete`, kind, "adversary")).toBe(last);
    expect(() => reviewVerdict(`Verdict: ${first}\n\nVerdict: ${last}\nSTATUS: complete`, kind, "adversary")).toThrow("ambiguous");
  });
}

for (const [axis, headings, valid] of [
  ["logic", ["Open questions", "Lens table", "Deciding-code table"], logic],
  ["threat", threatHeadings, threat],
] as const) {
  for (const heading of headings) {
    const invalid = heading === "Open questions" ? "unresolved candidate" : axis === "logic" ? "| Item | Result |\n| not run | unknown |" : "";
    test(`${axis}: an earlier valid ${heading} cannot hide a later invalid duplicate`, () => {
      expect(reviewVerdict(valid + closing, "code", axis)).toBe("GO");
      expect(() => reviewVerdict(`${valid}### ${heading}\n${invalid}\n${closing}`, "code", axis)).toThrow("ambiguous");
    });
    test(`${axis}: an earlier invalid ${heading} stays refused before a valid duplicate`, () => {
      expect(() => reviewVerdict(`### ${heading}\n${invalid}\n${valid}${closing}`, "code", axis)).toThrow();
    });
  }
}

for (const quotedHeading of ["#### Open questions", "inline ### Open questions"]) {
  test(`${quotedHeading} cannot stand in for the actual unresolved section`, () => {
    const unresolved = logic.replace("None.", "unresolved candidate");
    expect(() => reviewVerdict(unresolved + closing, "code", "logic")).toThrow("unresolved");
    expect(() => reviewVerdict(`${quotedHeading}\nNone.\n${unresolved}${closing}`, "code", "logic")).toThrow("unresolved");
  });
}

for (const suffix of [" \t", "\r"]) {
  test(`heading whitespace ${JSON.stringify(suffix)} preserves the open-question refusal`, () => {
    const report = logic.replace("### Open questions", `### Open questions${suffix}`).replace("None.", "unresolved candidate");
    expect(() => reviewVerdict(report + closing, "code", "logic")).toThrow("unresolved");
  });
  test(`heading whitespace ${JSON.stringify(suffix)} cannot hide a duplicate`, () => {
    expect(() => reviewVerdict(`${logic}### Open questions${suffix}\nunresolved candidate\n${closing}`, "code", "logic")).toThrow("ambiguous");
  });
}

for (const [axis, report] of [["logic", logic], ["threat", threat]]) {
  test(`${axis}: single CRLF sections are recognized like their LF controls`, () => {
    expect(reviewVerdict(report + closing, "code", axis)).toBe("GO");
    expect(reviewVerdict((report + closing).replaceAll("\n", "\r\n"), "code", axis)).toBe("GO");
  });
}
