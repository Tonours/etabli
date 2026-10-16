const STATUS_LINE = /^\s*(?:[-*+]\s+)?(?:\*\*|__)?Status(?:\*\*|__)?\s*:/i;
const CANONICAL = /^- Status: (DRAFT|CHALLENGED|READY)\s*$/i;

export function parsePlanStatus(text) {
  const declarations = [];
  let fence = null;
  let comment = false;
  for (const line of String(text).split(/\r?\n/)) {
    if (comment) {
      if (line.includes("-->")) comment = false;
      continue;
    }
    const marker = line.match(/^\s{0,3}(`{3,}|~{3,})/)?.[1];
    if (fence) {
      if (marker && marker[0] === fence[0] && marker.length >= fence.length) fence = null;
      continue;
    }
    if (marker) {
      fence = marker;
      continue;
    }
    if (/^\s*<!--/.test(line) && !line.includes("-->")) {
      comment = true;
      continue;
    }
    if (STATUS_LINE.test(line)) declarations.push(line);
  }
  if (declarations.length !== 1) return "unknown";
  return declarations[0].match(CANONICAL)?.[1].toLowerCase() ?? "unknown";
}
