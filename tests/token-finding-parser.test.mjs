// tests/token-finding-parser.test.mjs — T8a AC3(e) parser fixtures.
// Run: bun test tests/token-finding-parser.test.mjs
//
// The positive block fixture IS the pinned pp-null-deref Frozen Canned Block
// (PLAN.md v18 § Frozen Canned Blocks) — no divergent block shape.
import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { parseFindings } from "../scripts/lib/token-finding-parser.mjs";

const FIXTURES = join(import.meta.dir, "fixtures/token-protocol");

// Byte-exact pinned pp-null-deref block (PLAN.md v18, R13-B1).
const PP_NULL_DEREF_BLOCK = [
  "severity: high",
  "file: users.js",
  "line: 3",
  "issue: null guard missing on getUser(id).name dereference",
  "impact: TypeError crash on null return",
  "review_comment: caller contract requires a null check",
  "suggested_fix: Add a null guard before dereferencing.",
].join("\n");

describe("template block", () => {
  test("pinned pp-null-deref block parses with file+line", () => {
    const r = parseFindings(PP_NULL_DEREF_BLOCK);
    expect(r.ok).toBe(true);
    expect(r.findings.length).toBe(1);
    expect(r.findings[0].file).toBe("users.js");
    expect(r.findings[0].line).toBe(3);
    expect(r.findings[0].severity).toBe("high");
  });

  test("trailing newline still parses", () => {
    const r = parseFindings(`${PP_NULL_DEREF_BLOCK}\n`);
    expect(r.ok).toBe(true);
    expect(r.findings.length).toBe(1);
  });
});

describe("No findings.", () => {
  test("exact marker yields zero findings", () => {
    const r = parseFindings("No findings.");
    expect(r.ok).toBe(true);
    expect(r.findings).toEqual([]);
  });

  test("marker with trailing newline yields zero findings", () => {
    const r = parseFindings("No findings.\n");
    expect(r.ok).toBe(true);
    expect(r.findings).toEqual([]);
  });
});

describe("unparseable output", () => {
  test("non-numeric line number fails", () => {
    const bad = PP_NULL_DEREF_BLOCK.replace("line: 3", "line: three");
    expect(parseFindings(bad).ok).toBe(false);
  });

  test("missing field fails", () => {
    const bad = PP_NULL_DEREF_BLOCK.split("\n").slice(0, 6).join("\n");
    expect(parseFindings(bad).ok).toBe(false);
  });

  test("wrong key order fails", () => {
    const lines = PP_NULL_DEREF_BLOCK.split("\n");
    const bad = [lines[1], lines[0], ...lines.slice(2)].join("\n");
    expect(parseFindings(bad).ok).toBe(false);
  });

  test("free prose fails", () => {
    expect(parseFindings("looks fine to me, ship it").ok).toBe(false);
  });

  test("empty output fails", () => {
    expect(parseFindings("").ok).toBe(false);
  });
});

describe("wrong-file / wrong-line localization", () => {
  test("wrong file parses but names another.js (rejected by the every-finding rule)", () => {
    const other = PP_NULL_DEREF_BLOCK.replace("file: users.js", "file: other.js");
    const r = parseFindings(other);
    expect(r.ok).toBe(true);
    expect(r.findings[0].file).toBe("other.js");
  });

  test("wrong line parses but localizes to 99 (rejected by the every-finding rule)", () => {
    const other = PP_NULL_DEREF_BLOCK.replace("line: 3", "line: 99");
    const r = parseFindings(other);
    expect(r.ok).toBe(true);
    expect(r.findings[0].line).toBe(99);
  });
});

describe("lead dossier BLOCKS fixture (blocks, never JSON)", () => {
  test("dossier-blocks.md parses to exactly F1+F2 with dossier.json fields", () => {
    const blocks = readFileSync(join(FIXTURES, "lead-archive-fixtures/dossier-blocks.md"), "utf8");
    const dossier = JSON.parse(readFileSync(join(FIXTURES, "lead-archive-fixtures/dossier.json"), "utf8"));
    const r = parseFindings(blocks);
    expect(r.ok).toBe(true);
    expect(r.findings.length).toBe(2);
    for (let i = 0; i < 2; i++) {
      expect(r.findings[i].file).toBe(dossier.findings[i].file);
      expect(r.findings[i].line).toBe(dossier.findings[i].line);
      expect(r.findings[i].severity).toBe(dossier.findings[i].severity);
      expect(r.findings[i].issue).toBe(dossier.findings[i].text);
    }
    expect(r.findings[0].line).toBe(3);
    expect(r.findings[1].line).toBe(1);
  });
});
