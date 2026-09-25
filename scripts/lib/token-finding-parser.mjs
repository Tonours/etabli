// scripts/lib/token-finding-parser.mjs — T8a AC3(e) real-format finding parser.
//
// Parses the REAL hunter output format: 7-line template blocks
// (severity/file/line/issue/impact/review_comment/suggested_fix, in that
// order, `key: value` per line, blocks separated by blank lines) or exactly
// `No findings.` for a clean verdict. Used by the economic linkage
// --check-parity path (report) and the parser unit test. No I/O, no network.
//
// API:
//   parseFindings(text) -> { ok: true, findings: [...] }
//                        | { ok: false, error: "..." }
// A finding is { severity, file, line, issue, impact, review_comment,
// suggested_fix } with line as a positive integer.

const TEMPLATE_KEYS = [
  "severity",
  "file",
  "line",
  "issue",
  "impact",
  "review_comment",
  "suggested_fix",
];

export function parseFindings(text) {
  if (typeof text !== "string") {
    return { ok: false, error: "output is not a string" };
  }
  if (text.trim() === "No findings.") {
    return { ok: true, findings: [] };
  }
  const blocks = text.split(/\n\s*\n/).map((b) => b.trim()).filter((b) => b !== "");
  if (blocks.length === 0) {
    return { ok: false, error: "empty output: neither a template block nor `No findings.`" };
  }
  const findings = [];
  for (let i = 0; i < blocks.length; i++) {
    const lines = blocks[i].split("\n").map((l) => l.trim()).filter((l) => l !== "");
    if (lines.length !== TEMPLATE_KEYS.length) {
      return { ok: false, error: `block ${i + 1}: want ${TEMPLATE_KEYS.length} lines, got ${lines.length}` };
    }
    const finding = {};
    for (let k = 0; k < TEMPLATE_KEYS.length; k++) {
      const want = TEMPLATE_KEYS[k];
      const colon = lines[k].indexOf(":");
      if (colon < 0) {
        return { ok: false, error: `block ${i + 1}: line ${k + 1} has no ':'` };
      }
      const key = lines[k].slice(0, colon).trim();
      const value = lines[k].slice(colon + 1).trim();
      if (key !== want) {
        return { ok: false, error: `block ${i + 1}: want key '${want}', got '${key}'` };
      }
      if (value === "") {
        return { ok: false, error: `block ${i + 1}: empty value for '${want}'` };
      }
      finding[want] = value;
    }
    if (!/^[1-9][0-9]*$/.test(finding.line)) {
      return { ok: false, error: `block ${i + 1}: unparseable line number ${JSON.stringify(finding.line)}` };
    }
    finding.line = Number(finding.line);
    findings.push(finding);
  }
  return { ok: true, findings };
}
