#!/usr/bin/env node
/**
 * Mechanical check-freeze for READY plans.
 * Once READY, Checks may only be strengthened (added) unless demoted to
 * CHALLENGED with a Decision Log rationale mentioning check-freeze or weaken.
 */
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { unicodeCaseFold } from "./unicode-case-fold.mjs";
import commonmark from "../vendor/commonmark/commonmark.cjs";

const LIST_MARKER = String.raw`(?:[-+*]|\d+[.)])`;
const COMMAND_ITEM = new RegExp(`^(\\s*)${LIST_MARKER}\\s+command:\\s*(.+?)\\s*$`, "i");
const COMMAND_PREFIX = new RegExp(`^\\s*${LIST_MARKER}\\s+command:\\s*`, "i");
const EXPECTED_ITEM = new RegExp(`^\\s*${LIST_MARKER}\\s+expected\\s*:\\s*(.*?)\\s*$`, "i");
const LIST_ITEM = new RegExp(`^(\\s*)${LIST_MARKER}\\s+(?:\\[[ xX]\\]\\s+)?(.+?)\\s*$`);

export function parsePlanStatus(text) {
  const source = String(text);
  const scanned = scanMarkdown(source);
  if (
    scanned.some((line) => line.ambiguousInline) ||
    scanned.some((line) => line.multilineInline && /\bStatus\s*:/i.test(line.raw))
  ) return "unknown";
  let document;
  let htmlDocument;
  let originalDocument;
  try {
    const canonicalSource = canonicalizeReferenceLabelsForCommonmark(source, scanned);
    originalDocument = new commonmark.Parser().parse(source);
    document = new commonmark.Parser().parse(canonicalSource);
    htmlDocument = new commonmark.Parser().parse(maskCommandLineHtml(canonicalSource, document));
  } catch {
    return "unknown";
  }
  const sourceLines = source.split(/\r?\n/);
  if (containsUnsupportedCommonmarkHtml(htmlDocument)) return "unknown";
  const declarations = new Map();
  const canonical = new Set();
  for (const parsed of new Set([originalDocument, document])) {
    const walker = parsed.walker();
    let event;
    while ((event = walker.next())) {
      const item = event.node;
      if (!event.entering || item.type !== "item") continue;
      const variants = ["include", "omit"].map((mode) =>
        normalizeCommonmarkText(commonmarkItemText(item, mode))
          .trim()
          .replace(/^\[[ xX]\]\s+/, ""));
      const candidates = variants.flatMap((value) => {
        const unresolvedReference = value.match(/^\[([^\]\r\n]+)\](?:\[[^\]\r\n]*\])?/);
        return unresolvedReference ? [value, unresolvedReference[1]] : [value];
      });
      if (!candidates.some((value) => /^Status\s*:/i.test(value))) continue;
      const statuses = candidates
        .map((value) => value.match(/^Status\s*:\s*(DRAFT|CHALLENGED|READY)\b/i)?.[1]?.toLowerCase())
        .filter(Boolean);
      const [line, column] = item.sourcepos?.[0] || [0, 0];
      const key = `${line}:${column}`;
      const status = statuses[0] || "invalid";
      const previous = declarations.get(key);
      declarations.set(key, previous && previous !== status ? "invalid" : status);
      const raw = line > 0 ? sourceLines[line - 1].trimEnd() : "";
      const canonicalMatch = raw.match(/^- Status: (DRAFT|CHALLENGED|READY)$/i);
      const rootItem = item.parent?.type === "list" && item.parent.parent?.type === "document";
      if (rootItem && canonicalMatch) canonical.add(`${line}:${canonicalMatch[1].toLowerCase()}`);
    }
  }
  if (declarations.size !== 1 || canonical.size !== 1) return "unknown";
  const declaration = declarations.values().next().value;
  const canonicalStatus = canonical.values().next().value.split(":").at(-1);
  return declaration === canonicalStatus ? canonicalStatus : "unknown";
}

function canonicalizeReferenceLabelsForCommonmark(text, scanned) {
  const aliases = new Map();
  let masked = "";
  let sourceOffset = 0;
  for (const line of scanned) {
    masked += line.reference.padEnd(line.raw.length, " ").slice(0, line.raw.length);
    sourceOffset += line.raw.length;
    if (text.slice(sourceOffset, sourceOffset + 2) === "\r\n") {
      masked += "\r\n";
      sourceOffset += 2;
    } else if (text[sourceOffset] === "\n") {
      masked += "\n";
      sourceOffset += 1;
    }
  }
  const validLabels = markdownReferenceLabels(masked);
  const definitionOffsets = new Set();
  let nextAlias = 1;
  const pattern = /^([ \t>*+\-\d.)]*)\[((?:\\.|[^\]\\\r\n])+)\](:[ \t]*)/gm;
  for (const match of masked.matchAll(pattern)) {
    const [, prefix, label] = match;
    if (!/^(?:[ \t]*>[ \t]*)*(?:[ \t]*(?:[-+*]|\d+[.)])[ \t]+)*[ \t]*$/.test(prefix)) continue;
    const normalized = normalizeReferenceLabel(label);
    if (!validLabels.has(normalized)) continue;
    definitionOffsets.add(match.index);
    if (!aliases.has(normalized)) aliases.set(normalized, `etabli-ref-${nextAlias++}`);
  }
  const withDefinitions = text.replace(
    pattern,
    (whole, prefix, label, suffix, offset) => {
      if (!definitionOffsets.has(offset)) return whole;
      if (!/^(?:[ \t]*>[ \t]*)*(?:[ \t]*(?:[-+*]|\d+[.)])[ \t]+)*[ \t]*$/.test(prefix)) return whole;
      const normalized = normalizeReferenceLabel(label);
      return `${prefix}[${aliases.get(normalized)}]${suffix}`;
    },
  );
  if (aliases.size === 0) return text;
  return withDefinitions.replace(/\]\[((?:\\.|[^\]\\\r\n])*)\]/g, (whole, label) => {
    const alias = aliases.get(normalizeReferenceLabel(label));
    return alias ? `][${alias}]` : whole;
  });
}

function commonmarkItemText(item, codeMode) {
  let text = "";
  const visit = (node) => {
    if (node !== item && (node.type === "item" || node.type === "list")) return;
    if (node.type === "text") text += node.literal || "";
    else if (node.type === "code") text += codeMode === "include" ? node.literal || "" : "";
    else if (node.type === "softbreak" || node.type === "linebreak") text += "\n";
    else if (node.type === "html_inline") {
      if (!String(node.literal || "").trimStart().startsWith("<!--")) text += "\u0000";
    }
    for (let child = node.firstChild; child; child = child.next) visit(child);
  };
  visit(item);
  return text;
}

function normalizeCommonmarkText(value) {
  // CommonMark has already resolved escapes and entities exactly once. Only
  // remove characters that could visually split a metadata key; decoding or
  // unescaping again would turn literal `\\:` / `&colon;` text into syntax.
  return value.replace(/\p{Default_Ignorable_Code_Point}/gu, "");
}

function isOnlyHtmlComments(value) {
  const literal = String(value || "");
  let offset = 0;
  while (offset < literal.length) {
    const whitespace = literal.slice(offset).match(/^\s*/)?.[0].length || 0;
    offset += whitespace;
    if (offset === literal.length) return true;
    if (!literal.startsWith("<!--", offset)) return false;
    const end = literal.indexOf("-->", offset + 4);
    if (end < 0) return false;
    offset = end + 3;
  }
  return true;
}

function maskCommandLineHtml(source, document) {
  const sourceLines = source.split(/\r?\n/);
  const maskStarts = new Map();
  const walker = document.walker();
  let event;
  while ((event = walker.next())) {
    const item = event.node;
    if (!event.entering || item.type !== "item") continue;
    const [line, column] = item.sourcepos?.[0] || [0, 0];
    if (line <= 0 || column <= 0) continue;
    const command = sourceLines[line - 1].slice(column - 1).match(COMMAND_PREFIX);
    if (!command) continue;
    const start = column - 1 + command[0].length;
    maskStarts.set(line, Math.min(maskStarts.get(line) ?? start, start));
  }
  let lineNumber = 0;
  return source.replace(/[^\r\n]*(?:\r?\n|$)/g, (chunk) => {
    lineNumber += 1;
    const newline = chunk.endsWith("\r\n") ? "\r\n" : chunk.endsWith("\n") ? "\n" : "";
    const line = newline ? chunk.slice(0, -newline.length) : chunk;
    const start = maskStarts.get(lineNumber);
    if (start == null) return chunk;
    return line.slice(0, start) + line.slice(start).replaceAll("<", "＜") + newline;
  });
}

function containsUnsupportedCommonmarkHtml(document) {
  const walker = document.walker();
  let event;
  while ((event = walker.next())) {
    const node = event.node;
    if (!event.entering || (node.type !== "html_inline" && node.type !== "html_block")) continue;
    if (isOnlyHtmlComments(node.literal)) continue;
    return true;
  }
  return false;
}

/**
 * Extract frozen items under ## Checks, ## Acceptance Criteria and
 * ## Validation Plan. Nested expected results are tied to their parent check
 * so moving the same prose under another command cannot hide a weakening.
 */
let pcKeyA;
let pcValA;
let pcKeyB;
let pcValB;

function parseChecksUncached(text) {
  const lines = scanMarkdown(text);
  const referenceLabels = markdownReferenceLabels(text);
  const checks = [];
  let inFreezeSection = false;
  let section = "";
  let parent = "";
  let freezeFence = null;
  let freezeFenceLines = [];
  let tableActionColumn = null;
  let tableExpectedColumn = null;
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    const sectionMatch = line.structural.match(
      /^##\s+(Checks|Acceptance Criteria|Validation Plan)\b/i,
    );
    if (sectionMatch) {
      inFreezeSection = true;
      section = sectionMatch[1].toLowerCase().replace(/\s+/g, "-");
      parent = "";
      freezeFence = null;
      freezeFenceLines = [];
      tableActionColumn = null;
      tableExpectedColumn = null;
      continue;
    }
    if (inFreezeSection && /^##\s+/.test(line.structural)) {
      inFreezeSection = false;
      section = "";
      parent = "";
      continue;
    }
    if (!inFreezeSection) continue;
    if (freezeFence) {
      tableActionColumn = null;
      tableExpectedColumn = null;
      if (closesFence(line.text, freezeFence)) {
        if (freezeFenceLines.some((line) => executableValue(line, referenceLabels))) {
          parent = encodeAction(section, "code-block", freezeFenceLines.join("\n"));
          checks.push(parent);
        }
        freezeFence = null;
        freezeFenceLines = [];
      } else {
        freezeFenceLines.push(line.text);
      }
      continue;
    }
    const openedFence = line.fenced ? openingFence(line.text) : null;
    if (openedFence) {
      tableActionColumn = null;
      tableExpectedColumn = null;
      freezeFence = openedFence;
      freezeFenceLines = [];
      continue;
    }
    const cmd = line.text.match(COMMAND_ITEM);
    if (cmd) {
      tableActionColumn = null;
      tableExpectedColumn = null;
      const action = executableValue(cmd[2], referenceLabels);
      parent = action ? encodeAction(section, "command", line.raw) : "";
      if (parent) checks.push(parent);
      continue;
    }
    const expected = line.text.match(EXPECTED_ITEM);
    if (expected) {
      tableActionColumn = null;
      tableExpectedColumn = null;
      if (executableValue(expected[1], referenceLabels)) {
        checks.push(encodeExact(section, "expected", `${parent}\n${line.raw}`));
      }
      continue;
    }
    if (line.indented) {
      tableActionColumn = null;
      tableExpectedColumn = null;
      const blockLines = [line.text];
      while (index + 1 < lines.length) {
        if (lines[index + 1].indented && !EXPECTED_ITEM.test(lines[index + 1].text)) {
          index += 1;
          blockLines.push(lines[index].text);
          continue;
        }
        if (lines[index + 1].text.trim() === "") {
          let next = index + 2;
          while (next < lines.length && lines[next].text.trim() === "") next += 1;
          if (next < lines.length && lines[next].indented && !EXPECTED_ITEM.test(lines[next].text)) {
            while (index + 1 < next) {
              index += 1;
              blockLines.push(lines[index].text);
            }
            continue;
          }
        }
        break;
      }
      if (blockLines.some((line) => executableValue(line, referenceLabels))) {
        parent = encodeAction(section, "indented-block", blockLines.join("\n"));
        checks.push(parent);
      }
      continue;
    }
    const cells = tableCells(line.text);
    const rawCells = tableCells(line.raw);
    if (cells) {
      const nextCells = index + 1 < lines.length ? tableCells(lines[index + 1].text) : null;
      if (isTableDelimiter(nextCells)) {
        tableActionColumn = cells.findIndex((cell) =>
          /^(?:automated checks?|manual(?: checks?)?|ui\/browser(?: checks?)?|checks?|commands?|tests?|validation|verify|run)$/i.test(
            normalizePlaceholder(cell),
          ));
        tableExpectedColumn = cells.findIndex((cell) =>
          /^expected(?: result| output)?$/i.test(normalizePlaceholder(cell)),
        );
        continue;
      }
      if (isTableDelimiter(cells) && tableActionColumn != null) continue;
      if (!isTableDelimiter(cells) && tableActionColumn != null) {
        if (tableActionColumn >= 0) {
          const actionSemantic = (cells[tableActionColumn] || "").trim();
          const actionCell = executableValue(actionSemantic, referenceLabels);
          if (actionCell) {
            const alignedRawCells = rawCells?.length === cells.length ? rawCells : null;
            const actionRaw = alignedRawCells?.[tableActionColumn]?.trim() || line.raw;
            parent = encodeAction(section, "table", actionRaw);
            checks.push(parent);
            const expectedSemantic = tableExpectedColumn != null && tableExpectedColumn >= 0
              ? (cells[tableExpectedColumn] || "").trim()
              : "";
            if (executableValue(expectedSemantic, referenceLabels)) {
              const expectedRaw = alignedRawCells?.[tableExpectedColumn]?.trim() || line.raw;
              checks.push(encodeExact(section, "expected", `${parent}\n${expectedRaw}`));
            }
          }
        }
        continue;
      }
      if (/^\s*\|.*\|\s*$/.test(line.text)) continue;
    }
    tableActionColumn = null;
    tableExpectedColumn = null;
    const bullet = line.text.match(LIST_ITEM);
    if (bullet) {
      const value = bullet[2].replace(/\s+/g, " ").trim();
      if (!value || /^last run:/i.test(value)) continue;
      if (section !== "acceptance-criteria") {
        const action = actionableValue(bullet[2], referenceLabels);
        if (action) {
          parent = encodeAction(section, "bullet", line.raw);
          checks.push(parent);
          continue;
        }
      }
      const nested = bullet[1].length > 0 && parent ? `${parent}>` : "";
      checks.push(`${section}:${nested}${value}`);
      if (bullet[1].length === 0) parent = value;
      continue;
    }
    if (
      section !== "acceptance-criteria" &&
      !line.inlineCode &&
      actionableValue(line.text, referenceLabels)
    ) {
      parent = encodeAction(section, "plain", line.raw);
      checks.push(parent);
    }
  }
  return checks;
}

function encodeAction(section, kind, value) {
  return `${section}:action:${kind}:${Buffer.from(String(value), "utf8").toString("hex")}`;
}

function encodeExact(section, kind, value) {
  return `${section}:exact:${kind}:${Buffer.from(String(value), "utf8").toString("hex")}`;
}

function openingFence(line) {
  const match = line.match(/^ {0,3}(`{3,}|~{3,})(.*)$/);
  if (!match || (match[1][0] === "`" && match[2].includes("`"))) return null;
  return { character: match[1][0], length: match[1].length };
}

function closesFence(line, fence) {
  const match = line.match(/^ {0,3}(`{3,}|~{3,})[ \t]*$/);
  return Boolean(
    match && match[1][0] === fence.character && match[1].length >= fence.length,
  );
}

function findClosingBacktickRun(lines, lineIndex, start, size) {
  for (let row = lineIndex; row < lines.length; row += 1) {
    if (row > lineIndex && lines[row].trim() === "") break;
    if (
      row > lineIndex &&
      /^ {0,3}(?:[-+*]\s+|\d+[.)]\s+|#{1,6}(?:\s|$)|>|`{3,}|~{3,})/.test(lines[row])
    ) break;
    let index = row === lineIndex ? start : 0;
    while (index < lines[row].length) {
      const found = lines[row].indexOf("`", index);
      if (found < 0) break;
      let end = found + 1;
      while (lines[row][end] === "`") end += 1;
      if (end - found === size) return { row, end };
      index = end;
    }
  }
  return null;
}

function scanMarkdown(text, continuationHint = null) {
  const source = String(text);
  const lines = source.split(/\r?\n/);
  if (continuationHint === null) {
    const initial = referenceContainerProjection(source).continuationLines;
    const preliminary = scanMarkdown(source, initial);
    let syntax = "";
    let offset = 0;
    for (const line of preliminary) {
      syntax += line.container.padEnd(line.raw.length, " ").slice(0, line.raw.length);
      offset += line.raw.length;
      if (source.slice(offset, offset + 2) === "\r\n") {
        syntax += "\r\n";
        offset += 2;
      } else if (source[offset] === "\n") {
        syntax += "\n";
        offset += 1;
      }
    }
    return scanMarkdown(source, referenceContainerProjection(syntax).continuationLines);
  }
  const listContinuationOffsets = continuationHint;
  const lineStarts = [];
  const destinationRanges = markdownDestinationRanges(source);
  let sourceOffset = 0;
  for (const line of lines) {
    lineStarts.push(sourceOffset);
    sourceOffset += line.length;
    if (source.slice(sourceOffset, sourceOffset + 2) === "\r\n") sourceOffset += 2;
    else if (source[sourceOffset] === "\n") sourceOffset += 1;
  }
  const output = [];
  let fence = null;
  let inComment = false;
  let inlineTicks = 0;
  let inlineMultiline = false;

  for (let lineIndex = 0; lineIndex < lines.length; lineIndex += 1) {
    const line = lines[lineIndex];
    if (fence) {
      output.push({ raw: line, text: line, rendered: "", content: "", semantic: "", outside: "", reference: "", container: "", structural: "", fenced: true, indented: false, inlineCode: false, multilineInline: false });
      if (closesFence(line, fence)) fence = null;
      continue;
    }
    const openedFence = !inComment && inlineTicks === 0 ? openingFence(line) : null;
    if (openedFence) {
      fence = openedFence;
      output.push({ raw: line, text: line, rendered: "", content: "", semantic: "", outside: "", reference: "", container: "", structural: "", fenced: true, indented: false, inlineCode: false, multilineInline: false });
      continue;
    }
    const indented = !inComment && inlineTicks === 0 && /^(?: {4}|\t)/.test(line);
    if (indented && !listContinuationOffsets.has(lineStarts[lineIndex])) {
      const reference = line.replace(/[^ \t]/g, "\u0003");
      output.push({ raw: line, text: line, rendered: "", content: "", semantic: "", outside: "", reference, container: reference, structural: "", fenced: true, indented: true, inlineCode: false, multilineInline: false });
      continue;
    }

    let clean = "";
    let rendered = "";
    let content = "";
    let structural = "";
    let reference = "";
    let container = "";
    let structuralBlocked = inlineTicks !== 0;
    let multilineInlineLine = inlineTicks !== 0;
    let ambiguousInline = false;
    const lineStart = lineStarts[lineIndex];
    let index = 0;
    while (index < line.length) {
      if (inComment) {
        const close = line.indexOf("-->", index);
        if (close < 0) {
          reference += " ".repeat(line.length - index);
          container += line.slice(index).replace(/[^ \t]/g, "\u0003");
          index = line.length;
          continue;
        }
        inComment = false;
        reference += " ".repeat(close + 3 - index);
        container += line.slice(index, close + 3).replace(/[^ \t]/g, "\u0003");
        index = close + 3;
        continue;
      }
      if (line[index] === "`") {
        let end = index + 1;
        while (line[end] === "`") end += 1;
        const ticks = end - index;
        const previousInlineTicks = inlineTicks;
        const closingRun = previousInlineTicks === 0
          ? findClosingBacktickRun(
            lines,
            lineIndex,
            end,
            ticks,
          )
          : null;
        const opensInlineCode = Boolean(closingRun);
        if (opensInlineCode) {
          inlineTicks = ticks;
          inlineMultiline = closingRun.row > lineIndex;
          if (inlineMultiline) multilineInlineLine = true;
        } else if (previousInlineTicks === ticks) {
          inlineTicks = 0;
          inlineMultiline = false;
        }
        if (opensInlineCode || previousInlineTicks !== 0) structuralBlocked = true;
        if (
          previousInlineTicks === 0 &&
          !opensInlineCode &&
          line.trim() === "`".repeat(ticks)
        ) ambiguousInline = true;
        clean += line.slice(index, end);
        const codeProjection = (opensInlineCode || previousInlineTicks !== 0 ? "\u0003" : "`").repeat(ticks);
        reference += codeProjection;
        container += codeProjection;
        if (previousInlineTicks === 0 && !opensInlineCode) {
          structural += line.slice(index, end);
        }
        index = end;
        continue;
      }
      if (
        inlineTicks === 0 &&
        !COMMAND_PREFIX.test(clean) &&
        !destinationRanges.some(([start, end]) => lineStart + index >= start && lineStart + index <= end) &&
        line.startsWith("<!--", index) &&
        !isEscapedByOddBackslashes(line, index)
      ) {
        inComment = true;
        reference += "    ";
        container += "\u0003".repeat(4);
        index += 4;
        continue;
      }
      clean += line[index];
      rendered += line[index];
      if (inlineTicks === 0 || !inlineMultiline) content += line[index];
      if (inlineTicks === 0) structural += line[index];
      reference += inlineTicks === 0 ? line[index] : "\u0003";
      container += inlineTicks === 0 ? line[index] : "\u0003";
      index += 1;
    }
    output.push({
      raw: line,
      text: clean,
      rendered,
      content,
      semantic: structural.trim() ? content : "",
      outside: structural,
      reference,
      container,
      structural: structuralBlocked ? "" : structural,
      fenced: indented,
      indented,
      inlineCode: structuralBlocked,
      multilineInline: multilineInlineLine,
      ambiguousInline,
    });
  }
  return output;
}

function sectionRecords(text, heading) {
  const lines = scanMarkdown(text);
  const start = lines.findIndex((line) => heading.test(line.structural));
  if (start < 0) return [];
  const records = [];
  for (let index = start + 1; index < lines.length; index += 1) {
    if (/^##\s+/.test(lines[index].structural)) break;
    records.push(lines[index]);
  }
  return records;
}

function sectionBody(text, heading, projection = "semantic") {
  return sectionRecords(text, heading)
    .map((line) => line[projection])
    .join("\n")
    .trim();
}

function hasMeaningfulValue(body, referenceLabels = null) {
  return body
    .split(/\r?\n/)
    .map((line) => meaningfulSemanticValue(line, referenceLabels))
    .some(Boolean);
}

function semanticFieldValue(entry) {
  const field = String(entry).match(/^[^:]+:[ \t]*(.*)$/);
  return (field ? field[1] : entry).trim();
}

function meaningfulSemanticValue(line, referenceLabels = null) {
  const entry = meaningfulEntry(line, referenceLabels);
  if (!entry) return "";
  return isPlaceholder(semanticFieldValue(entry), true) ? "" : entry;
}

function isPlaceholder(value, rejectNone = false, literal = false) {
  const normalized = normalizePlaceholder(value, literal);
  if (!normalized) return true;
  if (/^(?:\.\.\.|yyyy-mm-dd:?|tbd|todo|not set|pending|not run)$/i.test(normalized)) {
    return true;
  }
  if (literal && /^<[A-Za-z][^/>]*>$/.test(normalized)) return true;
  if (/^none\s*\//i.test(normalized)) return true;
  return rejectNone && /^(?:none\.?|n\/?a)$/i.test(normalized);
}

function normalizePlaceholder(value, literal = false) {
  const raw = String(value).trim();
  const inline = raw.match(/^(`+)([\s\S]*)\1$/);
  let normalized = (inline ? inline[2] : literal ? raw : visibleMarkdownText(raw))
    .trim().replace(/[.!?;:]+$/g, "").trim();
  for (;;) {
    const backticks = normalized.match(/^(`+)([\s\S]*)\1$/);
    const emphasis = [["**", "**"], ["__", "__"], ["~~", "~~"], ["*", "*"], ["_", "_"]]
      .find(([open, close]) => normalized.length > open.length + close.length && normalized.startsWith(open) && normalized.endsWith(close));
    const next = backticks
      ? backticks[2].trim()
      : emphasis
        ? normalized.slice(emphasis[0].length, -emphasis[1].length).trim()
        : null;
    if (next == null) break;
    if (next === normalized) break;
    normalized = next.replace(/[.!?;:]+$/g, "").trim();
  }
  return normalized;
}

function isMarkdownBlockBoundary(value, index) {
  if (value[index] !== "\n") return false;
  if (/^\n[ \t]*\r?\n/.test(value.slice(index))) return true;
  const nextLine = value.slice(index + 1).match(/^([^\r\n]*)/)?.[1] || "";
  if (/^[\u0001\u0002]*\u0002/.test(nextLine)) return true;
  const structuralLine = nextLine.replace(/^[\u0001\u0002]+/, "");
  if (!structuralLine.trim()) return true;
  return /^\s*(?:[-+*](?:[ \t]|$)|\d+[.)](?:[ \t]|$)|#{1,6}(?:[ \t]|$)|>|```|~~~)/.test(structuralLine) ||
    /^ {0,3}(?:(?:\*[ \t]*){3,}|(?:-[ \t]*){3,}|(?:_[ \t]*){3,}|-+[ \t]*|=+[ \t]*)$/.test(structuralLine) ||
    isMarkdownHtmlBlockStart(structuralLine);
}

function isMarkdownHtmlBlockStart(line) {
  if (/^ {0,3}(?:<!--|<\?|<![A-Z]|<!\[CDATA\[)/.test(line)) return true;
  return /^ {0,3}<\/?(?:address|article|aside|base|basefont|blockquote|body|caption|center|col|colgroup|dd|details|dialog|dir|div|dl|dt|fieldset|figcaption|figure|footer|form|frame|frameset|h[1-6]|head|header|hr|html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol|optgroup|option|p|param|pre|script|search|section|style|summary|table|tbody|td|textarea|tfoot|th|thead|title|tr|track|ul)(?:[ \t>]|\/?>|$)/i.test(line);
}

function matchingMarkdownDelimiter(value, start, open, close, stopAtBlocks = false) {
  let depth = 0;
  for (let index = start; index < value.length; index += 1) {
    if (stopAtBlocks && isMarkdownBlockBoundary(value, index)) return -1;
    if (value[index] === "\\") {
      if (stopAtBlocks && isMarkdownBlockBoundary(value, index + 1)) return -1;
      index += 1;
      continue;
    }
    if (value[index] === open) depth += 1;
    if (value[index] === close) {
      depth -= 1;
      if (depth === 0) return index;
    }
  }
  return -1;
}

function matchingLinkDestination(value, start) {
  let depth = 0;
  let quote = "";
  let angle = false;
  let angleClosed = false;
  let hasDestination = false;
  let separator = false;
  let titleClosed = false;
  let parenthesizedTitleDepth = 0;
  for (let index = start; index < value.length; index += 1) {
    const character = value[index];
    if (isMarkdownBlockBoundary(value, index)) return -1;
    if (character === "\\") {
      if (
        escapedPhysicalNewlineIndex(value, index) >= 0 &&
        !quote &&
        parenthesizedTitleDepth === 0
      ) return -1;
      if (isMarkdownBlockBoundary(value, index + 1)) return -1;
      index += 1;
      continue;
    }
    if (angle) {
      if (character === "\n" || character === "\r" || character === "<") return -1;
      if (character === ">") {
        angle = false;
        angleClosed = true;
        hasDestination = true;
      }
      continue;
    }
    if (depth > 1 && /\s/.test(character)) return -1;
    if (quote) {
      if (character === quote) {
        quote = "";
        titleClosed = true;
      }
      continue;
    }
    if (parenthesizedTitleDepth > 0) {
      if (character === "(") return -1;
      if (character === ")") {
        parenthesizedTitleDepth = 0;
        titleClosed = true;
      }
      continue;
    }
    if (titleClosed) {
      if (/\s/.test(character)) continue;
      return depth === 1 && character === ")" ? index : -1;
    }
    if (angleClosed) {
      if (/\s/.test(character)) {
        separator = true;
        continue;
      }
      if (!separator) return depth === 1 && character === ")" ? index : -1;
    }
    if (depth === 1 && /\s/.test(character)) {
      if (hasDestination || angleClosed) separator = true;
      continue;
    }
    if (depth === 1 && separator) {
      if (character === "\"" || character === "'") {
        quote = character;
        continue;
      }
      if (character === "(") {
        parenthesizedTitleDepth = 1;
        continue;
      }
      return character === ")" ? index : -1;
    }
    if (depth === 1 && character === "<" && !hasDestination) {
      angle = true;
      continue;
    }
    if (character === "(") {
      depth += 1;
      if (depth > 1) hasDestination = true;
    } else if (depth === 1) {
      hasDestination = true;
    }
    if (character === ")") {
      depth -= 1;
      if (depth === 0) return index;
    }
  }
  return -1;
}

function matchingHtmlTag(value, start) {
  if (!/^<\/?[A-Za-z]/.test(value.slice(start))) return -1;
  let nameEnd = start + 1 + (value[start + 1] === "/" ? 1 : 0);
  while (/[A-Za-z0-9-]/.test(value[nameEnd] || "")) nameEnd += 1;
  if (!/[\s/>]/.test(value[nameEnd] || "")) return -1;
  let quote = "";
  for (let index = start + 1; index < value.length; index += 1) {
    const character = value[index];
    if (character === "\r" && value[index + 1] === "\n") continue;
    if (character === "\n") {
      const continuation = value.slice(index + 1).match(/^([^\r\n]*)/)?.[1] || "";
      if (!continuation || /^\s*(?:[-+*]\s|\d+[.)]\s|#{1,6}\s|>|```|~~~)/.test(continuation)) {
        return -1;
      }
      continue;
    }
    if (character === "\\") {
      index += 1;
      continue;
    }
    if (quote) {
      if (character === quote) quote = "";
      continue;
    }
    if (character === "\"" || character === "'") {
      quote = character;
      continue;
    }
    if (character === ">") return index;
  }
  return -1;
}

function visibleMarkdownText(input, knownReferenceLabels = null) {
  const value = String(input);
  const referenceLabels = knownReferenceLabels ?? markdownReferenceLabels(value);
  let visible = "";
  for (let index = 0; index < value.length;) {
    if (value[index] === "<") {
      const autolinkEnd = value.indexOf(">", index + 1);
      const autolink = autolinkEnd >= 0 ? value.slice(index + 1, autolinkEnd) : "";
      if (/^(?:[A-Za-z][A-Za-z0-9+.-]{1,31}:[^\s<>]*|[^\s<>@]+@[^\s<>@]+)$/.test(autolink)) {
        visible += autolink;
        index = autolinkEnd + 1;
        continue;
      }
      const tagEnd = matchingHtmlTag(value, index);
      if (tagEnd >= 0) {
        index = tagEnd + 1;
        continue;
      }
    }
    const image = value[index] === "!" && value[index + 1] === "[";
    const labelStart = image ? index + 1 : index;
    if (value[labelStart] !== "[") {
      visible += value[index];
      index += 1;
      continue;
    }
    const labelEnd = matchingMarkdownDelimiter(value, labelStart, "[", "]", true);
    if (labelEnd < 0) {
      visible += value[index];
      index += 1;
      continue;
    }
    const destinationStart = labelEnd + 1;
    const directDestination = value[destinationStart] === "(";
    const referenceDestination = value[destinationStart] === "[";
    let destinationEnd = -1;
    if (directDestination) {
      destinationEnd = matchingLinkDestination(value, destinationStart);
    } else if (referenceDestination) {
      destinationEnd = matchingMarkdownDelimiter(value, destinationStart, "[", "]", true);
      if (
        destinationEnd >= 0 &&
        !referenceLabels.has(normalizeReferenceLabel(
          value.slice(destinationStart + 1, destinationEnd) || value.slice(labelStart + 1, labelEnd),
        ))
      ) destinationEnd = -1;
    }
    if (destinationEnd < 0) {
      visible += value[index];
      index += 1;
      continue;
    }
    visible += visibleMarkdownText(value.slice(labelStart + 1, labelEnd), referenceLabels);
    index = destinationEnd + 1;
  }
  return normalizeVisibleMarkdown(decodeHtmlEntities(visible));
}

function markdownDestinationRanges(value) {
  const ranges = [];
  const referenceLabels = markdownReferenceLabels(value);
  for (let index = 0; index < value.length;) {
    const image = value[index] === "!" && value[index + 1] === "[";
    const labelStart = image ? index + 1 : index;
    if (value[labelStart] !== "[") {
      index += 1;
      continue;
    }
    const labelEnd = matchingMarkdownDelimiter(value, labelStart, "[", "]", true);
    if (labelEnd < 0) {
      index += 1;
      continue;
    }
    const destinationStart = labelEnd + 1;
    const directDestination = value[destinationStart] === "(";
    const referenceDestination = value[destinationStart] === "[";
    const destinationEnd = directDestination
      ? matchingLinkDestination(value, destinationStart)
      : referenceDestination
        ? matchingMarkdownDelimiter(value, destinationStart, "[", "]", true)
        : -1;
    const resolvedReference = referenceDestination && destinationEnd >= 0 && referenceLabels.has(
      normalizeReferenceLabel(
        value.slice(destinationStart + 1, destinationEnd) || value.slice(labelStart + 1, labelEnd),
      ),
    );
    if (destinationEnd >= 0 && (!referenceDestination || resolvedReference)) {
      ranges.push([destinationStart, destinationEnd]);
      index = destinationEnd + 1;
    } else {
      index = labelEnd + 1;
    }
  }
  return ranges.concat(markdownReferenceDefinitionRanges(value));
}

function markdownReferenceDefinitionRanges(value) {
  return markdownReferenceDefinitions(value).ranges;
}

function markdownReferenceLabels(value) {
  return markdownReferenceDefinitions(value).labels;
}

function normalizeReferenceLabel(value) {
  return unicodeCaseFold(String(value)
    .trim()
    .replace(/\s+/g, " "));
}

function canStartReferenceDefinition(value, index, previousDefinitionEnd, container = null, byLine = null) {
  if (index === 0) return true;
  if (
    previousDefinitionEnd >= 0 &&
    /^[ \t\r\n]*$/.test(value.slice(previousDefinitionEnd + 1, index))
  ) return true;
  const before = value.slice(0, index).replace(/\r?\n$/, "");
  const previousStart = before.lastIndexOf("\n") + 1;
  const previousContainer = (byLine || container?.byLine)?.get(previousStart);
  const previousLine = before.slice(before.lastIndexOf("\n") + 1);
  const structuralPrevious = previousLine.replace(/^[\u0001\u0002]+/, "");
  if (!structuralPrevious.trim()) {
    if (!previousContainer) return true;
    const previousMarker = previousContainer.markers.at(-1);
    if (previousMarker === "quote") return true;
    return previousMarker?.startsWith("ordered-") && previousContainer.orderedActive === true;
  }
  if (/^ {0,3}(?:#{1,6}(?:[ \t]|$)|(?:`{3,}|~{3,})[ \t]*$|(?:=+|-+)[ \t]*$|(?:(?:\*[ \t]*){3,}|(?:-[ \t]*){3,}|(?:_[ \t]*){3,})$)/.test(structuralPrevious)) return true;
  if (!container) return false;
  const lastMarker = container.markers.at(-1);
  if (lastMarker === "bullet" || lastMarker === "ordered-1") return true;
  if (lastMarker?.startsWith("ordered-")) {
    return container.orderedActive === true;
  }
  if (!previousContainer && lastMarker === "quote") {
    let cursor = previousStart;
    while (cursor > 0) {
      const earlierEnd = cursor - 1 - (value[cursor - 1] === "\n" && value[cursor - 2] === "\r" ? 1 : 0);
      const earlierStart = value.lastIndexOf("\n", earlierEnd - 1) + 1;
      const earlierLine = value.slice(earlierStart, earlierEnd).replace(/^[\u0001\u0002]+/, "");
      if (!earlierLine.trim()) return true;
      const earlierContainer = container.byLine.get(earlierStart);
      if (earlierContainer) return earlierContainer.quoteDepth < container.quoteDepth;
      cursor = earlierStart;
    }
  }
  return !previousContainer || previousContainer.quoteDepth < container.quoteDepth;
}

function referenceDefinitionContinuationCompatible(start, end, projection) {
  const startMarkers = projection.byLine.get(start)?.markers || [];
  const expected = startMarkers.at(-1) === "bullet" || startMarkers.at(-1)?.startsWith("ordered-")
    ? startMarkers.slice(0, -1)
    : startMarkers;
  let lineStart = projection.value.indexOf("\n", start);
  while (lineStart >= 0 && lineStart < end) {
    lineStart += 1;
    const actual = projection.byLine.get(lineStart)?.markers || [];
    if (actual.join("\u0000") !== expected.join("\u0000")) return false;
    lineStart = projection.value.indexOf("\n", lineStart);
  }
  return true;
}

function referenceContainerProjection(value) {
  const projected = value.split("");
  const byLine = new Map();
  const continuationLines = new Set();
  const activeOrdered = new Map();
  const activeListItems = new Map();
  let previousBlank = true;
  let previousBoundary = true;
  let lineStart = 0;
  while (lineStart <= value.length) {
    const lineEnd = value.indexOf("\n", lineStart);
    const end = lineEnd >= 0 ? lineEnd : value.length;
    let cursor = lineStart;
    const markers = [];
    const listFrames = [];
    let quoteDepth = 0;
    let listIndent = -1;
    let listContentIndent = -1;
    let orderedActive = false;
    let continuesListItem = false;
    let quoteWithinList = false;
    for (;;) {
      const rest = value.slice(cursor, end);
      const quote = rest.match(/^ {0,3}>[ \t]?/);
      let list = rest.match(/^ {0,3}([-+*]|(\d{1,9})[.)])(?: {1,4}(?! )|\t)/);
      if (!quote && !list) {
        const indentation = rest.match(/^[ \t]*/)?.[0] || "";
        let column = cursor - lineStart;
        for (let offset = 0; offset < indentation.length; offset += 1) {
          column = indentation[offset] === "\t" ? column + (4 - (column % 4)) : column + 1;
          const continuation = [...activeListItems.values()].some((item) =>
            item.quoteDepth === quoteDepth && column >= item.contentIndent && column <= item.contentIndent + 3);
          if (!continuation) continue;
          const suffix = rest.slice(offset + 1);
          const marker = suffix.match(/^([-+*]|(\d{1,9})[.)])(?: {1,4}(?! )|\t)/);
          if (marker) {
            continuesListItem = true;
            const combined = indentation.slice(0, offset + 1) + marker[0];
            list = Object.assign([combined, marker[1], marker[2]], { index: 0, input: rest });
            break;
          }
        }
        if (!list && indentation) {
          let finalColumn = cursor - lineStart;
          for (const character of indentation) {
            finalColumn = character === "\t" ? finalColumn + (4 - (finalColumn % 4)) : finalColumn + 1;
          }
          continuesListItem = [...activeListItems.values()].some((item) =>
            item.quoteDepth === quoteDepth &&
            finalColumn >= item.contentIndent &&
            finalColumn <= item.contentIndent + 3);
        }
      }
      const match = quote || list;
      if (!match) break;
      const markerCharacter = quote ? "\u0001" : "\u0002";
      if (quote) {
        const markerOffset = match[0].indexOf(">");
        let markerColumn = 0;
        for (const character of value.slice(lineStart, cursor + markerOffset)) {
          markerColumn = character === "\t" ? markerColumn + (4 - (markerColumn % 4)) : markerColumn + 1;
        }
        quoteWithinList ||= [...activeListItems.values()].some((item) =>
          item.quoteDepth === quoteDepth &&
          markerColumn >= item.contentIndent &&
          markerColumn <= item.contentIndent + 3);
        quoteWithinList ||= listFrames.some((item) =>
          item.quoteDepth === quoteDepth &&
          markerColumn >= item.contentIndent &&
          markerColumn <= item.contentIndent + 3);
        markers.push("quote");
        quoteDepth += 1;
      } else if (match[2]) {
        markers.push(`ordered-${Number(match[2])}`);
        const markerOffset = match[0].indexOf(match[1]);
        listIndent = 0;
        for (const character of value.slice(lineStart, cursor + markerOffset)) {
          listIndent = character === "\t" ? listIndent + (4 - (listIndent % 4)) : listIndent + 1;
        }
      } else {
        markers.push("bullet");
        const markerOffset = match[0].indexOf(match[1]);
        listIndent = 0;
        for (const character of value.slice(lineStart, cursor + markerOffset)) {
          listIndent = character === "\t" ? listIndent + (4 - (listIndent % 4)) : listIndent + 1;
        }
      }
      for (let index = cursor; index < cursor + match[0].length; index += 1) {
        if (projected[index] !== "\r" && projected[index] !== "\n") projected[index] = markerCharacter;
      }
      cursor += match[0].length;
      if (list) {
        let column = 0;
        for (const character of value.slice(lineStart, cursor)) {
          column = character === "\t" ? column + (4 - (column % 4)) : column + 1;
        }
        listContentIndent = column;
        listFrames.push({
          marker: markers.at(-1),
          markerIndex: markers.length - 1,
          quoteDepth,
          markerIndent: listIndent,
          contentIndent: listContentIndent,
        });
      }
    }
    const content = value.slice(cursor, end);
    const lastMarker = markers.at(-1);
    let enteredIncompatibleQuote = false;
    if (
      lastMarker === "quote" &&
      !quoteWithinList &&
      ![...activeListItems.values()].some((item) => item.quoteDepth === quoteDepth)
    ) {
      enteredIncompatibleQuote = activeListItems.size > 0 || activeOrdered.size > 0;
      activeOrdered.clear();
      activeListItems.clear();
    }
    const listFrame = listFrames.at(-1);
    const listMarker = listFrame?.marker;
    if (listMarker?.startsWith("ordered-")) {
      const parent = markers.slice(0, listFrame.markerIndex).join("\u0000");
      const key = `${parent}\u0000${listFrame.markerIndent}`;
      const number = Number(listMarker.slice("ordered-".length));
      orderedActive = number === 1 || previousBlank || previousBoundary || activeOrdered.has(key);
      if (orderedActive) {
        for (const [activeKey, active] of activeOrdered) {
          if (active.parent === parent && active.indent > listFrame.markerIndent) activeOrdered.delete(activeKey);
        }
        activeOrdered.set(key, { parent, indent: listFrame.markerIndent });
      }
    } else if (listMarker === "bullet") {
      const parent = markers.slice(0, listFrame.markerIndex).join("\u0000");
      for (const [activeKey, active] of activeOrdered) {
        if (active.parent === parent && active.indent >= listFrame.markerIndent) activeOrdered.delete(activeKey);
      }
    }
    if (listMarker === "bullet" || (listMarker?.startsWith("ordered-") && orderedActive)) {
      for (const [activeKey, active] of activeListItems) {
        if (active.quoteDepth === listFrame.quoteDepth && active.markerIndent >= listFrame.markerIndent) {
          activeListItems.delete(activeKey);
        }
      }
      activeListItems.set(`${listFrame.quoteDepth}\u0000${listFrame.markerIndent}`, {
        quoteDepth: listFrame.quoteDepth,
        markerIndent: listFrame.markerIndent,
        contentIndent: listFrame.contentIndent,
      });
    }
    if (markers.length > 0) byLine.set(lineStart, {
      markers,
      quoteDepth,
      listIndent,
      listContentIndent,
      orderedActive,
    });
    if (continuesListItem) continuationLines.add(lineStart);
    const structuralContent = content.replace(/\r$/, "");
    previousBlank = structuralContent.trim() === "" && (
      markers.length === 0 || markers.every((marker) => marker === "quote")
    );
    const closesContainers = (
      previousBlank ||
      /^ {0,3}#{1,6}(?:[ \t]|$)/.test(structuralContent) ||
      /^ {0,3}(?:`{3,}|~{3,})/.test(structuralContent) ||
      /^ {0,3}(?:(?:\*[ \t]*){3,}|(?:-[ \t]*){3,}|(?:_[ \t]*){3,}|=+[ \t]*|-+[ \t]*)$/.test(structuralContent) ||
      isMarkdownHtmlBlockStart(structuralContent)
    );
    if (closesContainers) {
      activeOrdered.clear();
      activeListItems.clear();
    }
    previousBoundary = closesContainers || quoteWithinList || enteredIncompatibleQuote;
    if (lineEnd < 0) break;
    lineStart = lineEnd + 1;
  }
  return { value: projected.join(""), byLine, continuationLines };
}

function markdownReferenceDefinitions(value) {
  const projection = referenceContainerProjection(value);
  const logical = projection.value;
  const ranges = [];
  const labels = new Set();
  let previousDefinitionEnd = -1;
  const linePattern = /^(?:[\u0001\u0002])* {0,3}\[(?<label>(?:\\.|[^\]\\\r\n])+)\]:[ \t]*/gm;
  for (const match of logical.matchAll(linePattern)) {
    const label = match.groups?.label || "";
    const container = projection.byLine.get(match.index);
    const context = container ? { ...container, byLine: projection.byLine } : null;
    if (!canStartReferenceDefinition(logical, match.index, previousDefinitionEnd, context, projection.byLine)) continue;
    if (Array.from(label).length > 999) continue;
    const destinationStart = skipReferenceWhitespace(logical, match.index + match[0].length);
    if (destinationStart < 0) continue;
    const destinationEnd = referenceDestinationEnd(logical, destinationStart);
    if (destinationEnd < 0) continue;
    const afterDestination = destinationEnd + 1;
    const lineEnd = logical.indexOf("\n", afterDestination);
    const sameLineEnd = lineEnd >= 0 ? lineEnd : logical.length;
    const sameLineRemainder = logical.slice(afterDestination, sameLineEnd);
    let definitionEnd = destinationEnd;
    if (sameLineRemainder.trim()) {
      if (!/^[ \t\r]+/.test(sameLineRemainder)) continue;
      const titleStart = afterDestination + (sameLineRemainder.match(/^[ \t\r]*/)?.[0].length || 0);
      const titleEnd = referenceTitleEnd(logical, titleStart);
      if (titleEnd < 0) continue;
      definitionEnd = titleEnd;
    } else if (lineEnd >= 0) {
      const titleStart = skipReferenceWhitespace(logical, afterDestination);
      const titleEnd = titleStart >= 0 ? referenceTitleEnd(logical, titleStart) : -1;
      if (titleEnd >= 0) definitionEnd = titleEnd;
    }
    if (!referenceDefinitionContinuationCompatible(match.index, definitionEnd, projection)) continue;
    labels.add(normalizeReferenceLabel(label));
    ranges.push([match.index, definitionEnd]);
    previousDefinitionEnd = definitionEnd;
  }
  return { labels, ranges };
}

function skipReferenceWhitespace(value, start) {
  let index = start;
  let crossedLine = false;
  while (index < value.length) {
    if (value[index] === " " || value[index] === "\t" || value[index] === "\r" || value[index] === "\u0001" || value[index] === "\u0002") {
      index += 1;
      continue;
    }
    if (value[index] !== "\n") return index;
    if (isMarkdownBlockBoundary(value, index)) return -1;
    if (crossedLine) return -1;
    crossedLine = true;
    index += 1;
    while (value[index] === "\u0001" || value[index] === "\u0002") index += 1;
    const indentation = value.slice(index).match(/^[ \t]*/)?.[0] || "";
    if (indentation.includes("\t") || indentation.length > 3) return -1;
  }
  return -1;
}

function referenceDestinationEnd(value, start) {
  if (value[start] === "<") {
    for (let index = start + 1; index < value.length; index += 1) {
      if (value[index] === "\n" || value[index] === "\r" || value[index] === "<") return -1;
      if (value[index] === "\\") {
        if (escapedPhysicalNewlineIndex(value, index) >= 0) return -1;
        index += 1;
      }
      else if (value[index] === ">") return index;
    }
    return -1;
  }
  let depth = 0;
  for (let index = start; index < value.length; index += 1) {
    const character = value[index];
    if (/\s/.test(character)) return index > start && depth === 0 ? index - 1 : -1;
    if (character === "\\") {
      if (escapedPhysicalNewlineIndex(value, index) >= 0) return -1;
      index += 1;
      continue;
    }
    if (character === "(") depth += 1;
    if (character === ")") {
      if (depth === 0) return -1;
      depth -= 1;
    }
  }
  return depth === 0 && value.length > start ? value.length - 1 : -1;
}

function referenceTitleEnd(value, start) {
  const open = value[start];
  const close = open === "(" ? ")" : open;
  if (open !== "\"" && open !== "'" && open !== "(") return -1;
  for (let index = start + 1; index < value.length; index += 1) {
    if (value[index] === "\\") {
      const escapedNewline = escapedPhysicalNewlineIndex(value, index);
      if (value[escapedNewline] === "\n" && isMarkdownBlockBoundary(value, escapedNewline)) return -1;
      index += 1;
      continue;
    }
    if (value[index] === "\n" && isMarkdownBlockBoundary(value, index)) return -1;
    if (value[index] !== close) continue;
    let after = index + 1;
    while (value[after] === " " || value[after] === "\t" || value[after] === "\r") after += 1;
    if (after === value.length || value[after] === "\n") return index;
    return -1;
  }
  return -1;
}

function escapedPhysicalNewlineIndex(value, backslash) {
  if (value[backslash] !== "\\") return -1;
  if (value[backslash + 1] === "\n") return backslash + 1;
  if (value[backslash + 1] === "\r" && value[backslash + 2] === "\n") return backslash + 2;
  return -1;
}

function normalizeVisibleMarkdown(value) {
  return value
    .replace(/\\([!"#$%&'()*+,\-./:;<=>?@[\]\\^_`{|}~])/g, "$1")
    .replace(/\p{Default_Ignorable_Code_Point}/gu, "");
}

function decodeHtmlEntities(value) {
  const named = new Map([
    ["amp", "&"], ["apos", "'"], ["colon", ":"], ["gt", ">"], ["lt", "<"],
    ["nbsp", " "], ["ensp", " "], ["emsp", " "], ["thinsp", " "], ["ThinSpace", " "],
    ["FourPerEmSpace", " "],
    ["hairsp", " "], ["numsp", " "], ["puncsp", " "], ["VeryThinSpace", " "],
    ["MediumSpace", " "], ["ThickSpace", " "], ["NegativeThinSpace", "\u200b"],
    ["NegativeVeryThinSpace", "\u200b"], ["NegativeMediumSpace", "\u200b"], ["NegativeThickSpace", "\u200b"],
    ["emsp13", " "], ["emsp14", " "], ["NewLine", " "], ["period", "."],
    ["af", "\u2061"], ["ApplyFunction", "\u2061"], ["ic", "\u2063"],
    ["InvisibleComma", "\u2063"], ["InvisibleTimes", "\u2062"], ["it", "\u2062"],
    ["lrm", "\u200e"], ["NoBreak", "\u2060"], ["rlm", "\u200f"],
    ["quot", "\""], ["shy", "\u00ad"], ["Tab", " "],
    ["ZeroWidthSpace", "\u200b"], ["zwj", "\u200d"], ["zwnj", "\u200c"],
  ]);
  return value.replace(/&(?:#([xX][0-9A-Fa-f]+|\d+)|([A-Za-z][A-Za-z0-9]+));/g, (entity, numeric, name) => {
    if (numeric) {
      const radix = numeric[0].toLowerCase() === "x" ? 16 : 10;
      const digits = radix === 16 ? numeric.slice(1) : numeric;
      const point = Number.parseInt(digits, radix);
      if (!Number.isSafeInteger(point) || point <= 0 || point > 0x10ffff) return entity;
      const decoded = String.fromCodePoint(point);
      return /\s/u.test(decoded) ? " " : decoded;
    }
    return named.get(name) ?? entity;
  });
}

function isEscapedByOddBackslashes(value, index) {
  let count = 0;
  for (let cursor = index - 1; cursor >= 0 && value[cursor] === "\\"; cursor -= 1) {
    count += 1;
  }
  return count % 2 === 1;
}

function isReferenceDefinition(value) {
  if (!value.startsWith("[")) return false;
  const labelEnd = matchingMarkdownDelimiter(value, 0, "[", "]");
  return labelEnd > 0 && value[labelEnd + 1] === ":";
}

function isExplicitGapAbsence(value) {
  return /^(?:none|n\/?a|no material gaps?)$/i.test(normalizePlaceholder(value));
}

function isNoneSentinel(value) {
  return /^none$/i.test(normalizePlaceholder(value));
}

function meaningfulEntry(line, referenceLabels = null) {
  let value = line.trim();
  for (;;) {
    if (/^(?:>\s*|(?:-\s*){3,}|(?:\*\s*){3,}|(?:_\s*){3,})$/.test(value)) return "";
    if (/^(?:```|~~~|<!--|-->|-{3,}|\*{3,}|_{3,})/.test(value)) return "";
    if (/^(?:[-+*]|\d+[.)])\s*$/.test(value)) return "";
    const next = value
      .replace(/^>\s*/, "")
      .replace(new RegExp(`^${LIST_MARKER}(?:\\s+|$)`), "")
      .replace(/^\[[ xX]\](?:\s+|$)/, "")
      .trim();
    if (next === value) break;
    value = next;
  }
  if (/^#{1,6}(?:\s|$)/.test(value)) return "";
  if (isReferenceDefinition(value)) return "";
  const wholeInline = value.match(/^(`+)([\s\S]*)\1$/);
  if (wholeInline) {
    const literal = wholeInline[2].trim();
    return literal && !isPlaceholder(literal, true, true) ? value : "";
  }
  value = visibleMarkdownText(value, referenceLabels).trim();
  if (!value || /^[*_~]+$/.test(value)) return "";
  const fieldValue = value.match(/^[^:]+:[ \t]*(.*)$/)?.[1]?.trim();
  const rawCandidate = fieldValue === undefined ? value : fieldValue;
  const inlineCode = rawCandidate.match(/^(`+)([\s\S]*)\1$/);
  const candidate = (inlineCode ? inlineCode[2] : rawCandidate).trim();
  if (/^Describe in 1-3 sentences what will change and why it matters\.?$/i.test(candidate)) return "";
  return candidate && !/^(?:\.\.\.|<[^>]+>)$/i.test(candidate) ? value : "";
}

function actionableValue(line, referenceLabels = null) {
  const entry = meaningfulEntry(line, referenceLabels);
  if (!entry) return "";
  const field = entry.match(/^([^:]+):(.*)$/);
  if (!field) return executableValue(entry, referenceLabels) ? entry : "";
  const label = field[1].trim().toLowerCase();
  if (/^(?:automated checks?|manual(?: checks?)?|ui\/browser(?: checks?)?|check|test|validation|verify|run|command)$/.test(label)) {
    return executableValue(field[2], referenceLabels) ? entry : "";
  }
  if (/^(?:owner|evidence|rationale|notes?|expected(?: result)?|regression risks? to watch|evidence required for done)$/.test(label)) {
    return "";
  }
  return looksLikeShellCommand(entry) && executableValue(entry, referenceLabels) ? entry : "";
}

function looksLikeShellCommand(value) {
  const command = String(value)
    .replace(/^(?:[A-Za-z_][A-Za-z0-9_]*=(?:"[^"]*"|'[^']*'|\S+)\s+)+/, "")
    .trim();
  return /^(?:\.?\.?\/\S+|(?:bash|bun|cargo|curl|deno|docker|env|eslint|git|go|gradle|grep|java|jq|just|make|mvn|node|npm|npx|pnpm|playwright|python\d*|pytest|rg|rtk|ruby|sh|tsc|vitest|wget|yarn|zsh)(?:\s|$))/i.test(command);
}

function executableValue(value, referenceLabels = null) {
  const raw = String(value).trim();
  const inline = raw.match(/^(`+)([\s\S]*)\1$/);
  const semantic = meaningfulEntry(value, referenceLabels).replace(/^`+|`+$/g, "").trim();
  if (isPlaceholder(semantic, true, Boolean(inline)) || (!inline && /^<[^>]+>$/.test(semantic)) || /^n\/?a$/i.test(semantic)) return "";
  return semantic;
}

function tableCells(line) {
  const trimmed = line.trim();
  if (!trimmed.includes("|")) return null;
  const cells = [];
  let cell = "";
  for (let index = 0; index < trimmed.length; index += 1) {
    const character = trimmed[index];
    if (character === "|") {
      let slashes = 0;
      for (let previous = index - 1; previous >= 0 && trimmed[previous] === "\\"; previous -= 1) slashes += 1;
      if (slashes % 2 === 0) {
        cells.push(cell.trim());
        cell = "";
        continue;
      }
    }
    cell += character;
  }
  cells.push(cell.trim());
  if (cells[0] === "") cells.shift();
  if (cells.at(-1) === "") cells.pop();
  return cells.length >= 2 ? cells : null;
}

function isTableDelimiter(cells) {
  return Array.isArray(cells) && cells.length >= 2 && cells.every((cell) => /^:?-{3,}:?$/.test(cell));
}

function hasRequirementTrace(text) {
  const referenceLabels = markdownReferenceLabels(text);
  const body = sectionBody(text, /^##\s+Requirement Trace\b/i);
  const lines = body.split(/\r?\n/);
  let tableDataAllowed = false;
  let tableHeaderSignature = null;
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    const trimmed = line.trim();
    if (!trimmed) {
      tableDataAllowed = false;
      tableHeaderSignature = null;
      continue;
    }
    const cells = tableCells(trimmed);
    if (cells) {
      if (isTableDelimiter(cells)) {
        tableDataAllowed = index > 0 && Boolean(tableCells(lines[index - 1]));
        continue;
      }
      if (isTableDelimiter(tableCells(lines[index + 1] || ""))) {
        tableHeaderSignature = JSON.stringify(cells.map((cell) =>
          normalizePlaceholder(cell).replace(/\s+/g, " ").toLowerCase(),
        ));
        tableDataAllowed = false;
        continue;
      }
      const rowSignature = JSON.stringify(cells.map((cell) =>
        normalizePlaceholder(cell).replace(/\s+/g, " ").toLowerCase(),
      ));
      if (
        tableDataAllowed && rowSignature !== tableHeaderSignature &&
        !isRequirementTraceHeaderSequence(cells) && cells.length >= 5 &&
        [cells[0], cells[1], cells[3], cells[4]].every((cell) => meaningfulSemanticValue(cell, referenceLabels)) &&
        (Boolean(meaningfulSemanticValue(cells[2], referenceLabels)) || isExplicitGapAbsence(cells[2]))
      ) return true;
      continue;
    }
    tableDataAllowed = false;
    tableHeaderSignature = null;
    const entry = line.replace(/^\s*[-*]\s*/, "").trim();
    const segments = entry.split(/(?:->|→)/).map((segment) => segment.trim());
    if (segments.length >= 4) {
      if (
        !isRequirementTraceHeaderSequence(segments) &&
        [segments[0], segments[1], ...segments.slice(3)].every((segment) => meaningfulSemanticValue(segment, referenceLabels)) &&
        (Boolean(meaningfulSemanticValue(segments[2], referenceLabels)) || isExplicitGapAbsence(segments[2]))
      ) return true;
      continue;
    }
    if (/^no material gaps?\.?$/i.test(entry)) return true;
  }
  return false;
}

function isRequirementTraceHeaderSequence(cells) {
  if (cells.length < 4) return false;
  const normalized = cells.map((cell) =>
    normalizePlaceholder(cell).replace(/\s+/g, " ").toLowerCase(),
  );
  const source = /^(?:requirement(?: \/ source)?|source)$/;
  const observed = /^(?:observed(?: state)?|current state|actual behavior)$/;
  const gap = /^(?:gap(?: \/ ambiguity)?|ambiguity)$/;
  const decision = /^(?:decision|choice|disposition)$/;
  const evidence = /^(?:evidence|proof|step \/ expected evidence|expected evidence)$/;
  if (!source.test(normalized[0]) || !observed.test(normalized[1]) || !gap.test(normalized[2])) {
    return false;
  }
  if (normalized.length === 4) return decision.test(normalized[3]) || evidence.test(normalized[3]);
  return decision.test(normalized[3]) && evidence.test(normalized[4]);
}

function hasField(text, names) {
  const body = sectionBody(text, /^##\s+Workflow Contract\b/i);
  return names.some((name) => {
    const match = body.match(new RegExp(`^[ \\t]*${LIST_MARKER}[ \\t]+${name}:[ \\t]*(.+)$`, "im"));
    return Boolean(match && !isPlaceholder(match[1], true));
  });
}

function hasActionableCheck(text) {
  return parseChecks(text).some((item) =>
    /^(?:checks|validation-plan):action:/.test(item),
  );
}

function hasPlaceholderExpected(text) {
  const lines = scanMarkdown(text);
  const referenceLabels = markdownReferenceLabels(text);
  let inValidation = false;
  let expectedColumn = null;
  let activeExpectedParent = false;
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (/^##\s+(?:Checks|Validation Plan)\b/i.test(line.structural)) {
      inValidation = true;
      expectedColumn = null;
      activeExpectedParent = false;
      continue;
    }
    if (inValidation && /^##\s+/.test(line.structural)) {
      inValidation = false;
      expectedColumn = null;
      activeExpectedParent = false;
      continue;
    }
    if (!inValidation) continue;
    if (line.fenced && !line.indented) {
      expectedColumn = null;
      activeExpectedParent = false;
      continue;
    }
    const expected = line.text.match(EXPECTED_ITEM);
    if (expected) {
      if ((!line.indented || activeExpectedParent) && !executableValue(expected[1], referenceLabels)) return true;
      continue;
    }
    if (line.indented) {
      expectedColumn = null;
      activeExpectedParent = false;
      continue;
    }
    if (line.text.trim() === "") {
      expectedColumn = null;
      continue;
    }
    const cells = tableCells(line.text);
    if (expectedColumn != null) {
      activeExpectedParent = false;
      if (cells && isTableDelimiter(cells)) continue;
      if (cells) {
        if (expectedColumn >= 0 && !executableValue(cells[expectedColumn] || "", referenceLabels)) return true;
        continue;
      }
      expectedColumn = null;
    }
    const command = line.text.match(COMMAND_ITEM);
    const bullet = line.text.match(LIST_ITEM);
    const commandAction = command
      ? executableValue(command[2], referenceLabels)
      : bullet
        ? actionableValue(bullet[2], referenceLabels)
        : looksLikeShellCommand(line.text) ? executableValue(line.text, referenceLabels) : "";
    if (commandAction) {
      expectedColumn = null;
      activeExpectedParent = true;
      continue;
    }
    if (!cells) {
      expectedColumn = null;
      activeExpectedParent = false;
      continue;
    }
    activeExpectedParent = false;
    const nextCells = index + 1 < lines.length ? tableCells(lines[index + 1].text) : null;
    if (isTableDelimiter(nextCells)) {
      expectedColumn = cells.findIndex((cell) => /^expected(?: result| output)?$/i.test(normalizePlaceholder(cell)));
      continue;
    }
    if (isTableDelimiter(cells)) continue;
  }
  return false;
}

/** Mechanical minimum for a READY implementation plan. */
export function evaluateReadyPlan(text) {
  if (parsePlanStatus(text) !== "ready") return { ok: false, missing: ["Status: READY"] };
  const missing = [];
  const referenceLabels = markdownReferenceLabels(text);
  const requiredSections = [
    ["Goal", /^##\s+Goal\b/i],
    ["Acceptance Criteria", /^##\s+Acceptance Criteria\b/i],
    ["Scope", /^##\s+Scope\b/i],
    ["Facts And Assumptions", /^##\s+Facts And Assumptions\b/i],
    ["Requirement Trace", /^##\s+Requirement Trace\b/i],
    ["Steps or Execution Slices", /^##\s+(?:Steps|Execution Slices)\b/i],
    ["Checks or Validation Plan", /^##\s+(?:Checks|Validation Plan)\b/i],
    ["Risks", /^##\s+Risks\b/i],
    ["Open Questions", /^##\s+Open Questions\b/i],
  ];
  for (const [label, heading] of requiredSections) {
    if (label === "Checks or Validation Plan" || label === "Open Questions") continue;
    const body = sectionBody(text, heading);
    if (label === "Risks") {
      const riskEntries = body.split(/\r?\n/).map((line) => meaningfulEntry(line, referenceLabels)).filter(Boolean);
      const riskSentinels = riskEntries.filter((entry) => {
        if (isNoneSentinel(entry)) return true;
        const field = entry.match(/^(Risks?):[ \t]*(.*)$/i);
        return Boolean(field && isNoneSentinel(field[2]));
      });
      if (riskSentinels.length > 0) {
        if (riskEntries.length !== 1 || riskSentinels.length !== 1) missing.push(label);
      } else if (!riskEntries.some((entry) => {
        const field = entry.match(/^([^:]+):[ \t]*(.*)$/);
        if (!field) return Boolean(meaningfulSemanticValue(entry, referenceLabels));
        const label = field[1].trim();
        if (/^(?:risk\s+)?(?:impact|mitigation|owner|likelihood|severity|probability)\b/i.test(label)) return false;
        return Boolean(meaningfulSemanticValue(field[2], referenceLabels));
      })) {
        missing.push(label);
      }
      continue;
    }
    if (!hasMeaningfulValue(body, referenceLabels)) missing.push(label);
  }
  if (!hasRequirementTrace(text) && !missing.includes("Requirement Trace")) {
    missing.push("Requirement Trace needs a populated row or explicit no-material-gap record");
  }
  if (!hasActionableCheck(text) && !missing.includes("Checks or Validation Plan")) {
    missing.push("Checks or Validation Plan needs a populated check");
  }
  if (hasPlaceholderExpected(text)) {
    missing.push("Checks or Validation Plan expected results must not be placeholders");
  }
  for (const [label, names] of [
    ["Workflow Contract.Route", ["Route", "Router decision"]],
    ["Workflow Contract.Role", ["Role"]],
    ["Workflow Contract.Stop condition", ["Stop condition", "Stop conditions"]],
    ["Workflow Contract.Required evidence", ["Required evidence"]],
  ]) {
    if (!hasField(text, names)) missing.push(label);
  }
  const questionRecords = sectionRecords(text, /^##\s+Open Questions\b/i);
  const questionEntries = questionRecords.map((line) => meaningfulEntry(line.rendered, referenceLabels)).filter(Boolean);
  const activeNone = questionRecords
    .map((line) => meaningfulEntry(line.outside, referenceLabels))
    .filter((entry) => /^None\.?$/i.test(entry));
  if (
    questionEntries.length !== 1 ||
    !/^None\.?$/i.test(questionEntries[0]) ||
    activeNone.length !== 1
  ) {
    missing.push("Open Questions must explicitly be None before READY");
  }
  return { ok: missing.length === 0, missing };
}

/**
 * Memoized (2-slot LRU keyed on exact text content). Callers treat the
 * returned array as read-only; identical text returns the same instance,
 * which also lets evaluateCheckFreeze's WeakMap normalization cache hit.
 */
export function parseChecks(text) {
  const s = String(text);
  if (s === pcKeyA) return pcValA;
  if (s === pcKeyB) {
    const k = pcKeyB;
    const v = pcValB;
    pcKeyB = pcKeyA;
    pcValB = pcValA;
    pcKeyA = k;
    pcValA = v;
    return v;
  }
  const checks = parseChecksUncached(s);
  pcKeyB = pcKeyA;
  pcValB = pcValA;
  pcKeyA = s;
  pcValA = checks;
  return checks;
}

export function parseDecisionLog(text) {
  const lines = String(text).split(/\r?\n/);
  const out = [];
  let inLog = false;
  for (const line of lines) {
    if (/^##\s+Decision Log\b/i.test(line)) {
      inLog = true;
      continue;
    }
    if (inLog && /^##\s+/.test(line)) break;
    if (inLog) out.push(line);
  }
  return out.join("\n");
}

function normalize(item) {
  return String(item).replace(/\s+/g, " ").trim().toLowerCase();
}

/**
 * Hot-path caches. evaluateCheckFreeze runs on every Write/Edit/MultiEdit of
 * PLAN.md while a plan is READY, and identical text recurs between mutations:
 * - single-entry cache keyed on exact text content (`===` on strings of equal
 *   length is a memcmp, still far cheaper than re-parsing);
 * - WeakMap keyed on the previousChecks array identity for its normalized
 *   form (callers pass parseChecks output, which is itself memoized).
 */
const prevNormalizedCache = new WeakMap();
let parsedTextKey;
let parsedTextVal;

function parsedBundleFor(text) {
  if (text === parsedTextKey) return parsedTextVal;
  const val = {
    status: parsePlanStatus(text),
    checks: parseChecks(text),
    normSet: null,
    decisionLog: parseDecisionLog(text),
  };
  parsedTextKey = text;
  parsedTextVal = val;
  return val;
}

/**
 * @param {{ previousChecks: string[], currentText: string }} input
 * @returns {{ ok: boolean, status: string, removed: string[], reason: string }}
 */
export function evaluateCheckFreeze({ previousChecks, currentText }) {
  const parsed = parsedBundleFor(String(currentText));
  const prevRaw = previousChecks || [];

  if (prevRaw.length === 0) {
    return {
      ok: true,
      status: parsed.status,
      removed: [],
      reason: "no previous freeze snapshot",
      currentChecks: parsed.checks,
    };
  }

  let prev = prevNormalizedCache.get(prevRaw);
  if (prev === undefined) {
    prev = prevRaw.map(normalize).filter(Boolean);
    prevNormalizedCache.set(prevRaw, prev);
  }

  let curr = parsed.normSet;
  if (curr === null) {
    curr = parsed.normSet = new Set(parsed.checks.map(normalize));
  }

  const removed = [];
  for (let i = 0; i < prev.length; i++) {
    if (!curr.has(prev[i])) removed.push(prev[i]);
  }
  if (removed.length === 0) {
    return {
      ok: true,
      status: parsed.status,
      removed: [],
      reason: "checks preserved or strengthened",
      currentChecks: parsed.checks,
    };
  }

  const status = parsed.status;
  const decisionLog = parsed.decisionLog;
  const demoted = status === "challenged";
  // Structured demote (preferred): "- check_freeze_demote: <nonempty reason>"
  const structuredMatch = decisionLog.match(
    /^\s*[-*]\s*check_freeze_demote:\s*(.+?)\s*$/im,
  );
  const structuredReason =
    structuredMatch && structuredMatch[1].trim() !== ""
      ? structuredMatch[1].trim()
      : null;
  // Legacy keyword path kept for existing plans (G1 residual).
  const keywordRationale =
    /check-freeze|weaken|weakened|removed check|demot/i.test(decisionLog);

  if (demoted && structuredReason) {
    return {
      ok: true,
      status,
      removed,
      reason: "weakening allowed: CHALLENGED with structured check_freeze_demote",
      demote_mode: "structured",
      demote_reason: structuredReason,
      currentChecks: parsed.checks,
    };
  }

  if (demoted && keywordRationale) {
    return {
      ok: true,
      status,
      removed,
      reason: "weakening allowed: CHALLENGED with Decision Log rationale",
      demote_mode: "keyword",
      demote_reason: null,
      currentChecks: parsed.checks,
    };
  }

  return {
    ok: false,
    status,
    removed,
    reason:
      "check-freeze violation: READY checks may only be strengthened; demote to CHALLENGED and record Decision Log rationale (check_freeze_demote: … or legacy check-freeze/weaken keywords) to remove/weaken",
    demote_mode: null,
    demote_reason: null,
    currentChecks: parsed.checks,
  };
}

function main(argv) {
  const args = argv.slice(2);
  let previousPath = null;
  let currentPath = null;
  let previousJson = null;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--previous") previousPath = args[++i];
    else if (args[i] === "--previous-json") previousJson = args[++i];
    else if (args[i] === "--current") currentPath = args[++i];
    else if (args[i] === "-h" || args[i] === "--help") {
      console.log(
        "Usage: plan-check-freeze --current PLAN.md (--previous PLAN.snapshot.md | --previous-json '[...]')",
      );
      process.exit(0);
    }
  }
  if (!currentPath || (!previousPath && !previousJson)) {
    console.error("plan-check-freeze: --current and --previous|--previous-json required");
    process.exit(2);
  }
  const currentText = readFileSync(resolve(currentPath), "utf8");
  let previousChecks = [];
  if (previousJson) {
    try {
      previousChecks = JSON.parse(previousJson);
    } catch (error) {
      console.error(`plan-check-freeze: --previous-json is not valid JSON: ${error instanceof Error ? error.message : String(error)}`);
      process.exit(2);
    }
  } else if (previousPath) {
    previousChecks = parseChecks(readFileSync(resolve(previousPath), "utf8"));
  }
  const result = evaluateCheckFreeze({ previousChecks, currentText });
  console.log(JSON.stringify(result, null, 2));
  process.exit(result.ok ? 0 : 1);
}

const isMain =
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) main(process.argv);
