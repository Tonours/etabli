export function foldAccents(text) {
  return text.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
}

export const ACCENTED_MARKERS = ["décidé"];

export const FOLDED_MARKERS = [
  "we decided",
  "we chose",
  "chosen",
  "instead of",
  "rather than",
  "trade-off",
  "opted for",
  "choisi",
  "plutôt qu",
  "au lieu de",
  "écarté",
  "opté pour",
].map(foldAccents);

export const ACCENTLESS_SEQUENCES = [
  ["nous", "avons"],
  ["vous", "avez"],
  ["ils", "ont"],
  ["elles", "ont"],
  ["j", "ai"],
  ["tu", "as"],
  ["il", "a"],
  ["elle", "a"],
];

const ACCENTLESS_PARTICIPLES = ["decide", "decidee", "decidees"];
const ADVERB_WINDOW = 2;

// Structural paths, tested raw: the hook feeds git's -z output (never
// quoted), so these patterns see real paths, not C-quoted fragments.
export const STRUCTURAL_PATTERNS = [
  /(^|\/)package\.json$/,
  /(^|\/)tsconfig[^/]*\.json$/,
  /(^|\/)[^/]*\.config\.(ts|js|mjs|cjs)$/,
  /(^|\/)schema\.(prisma|sql|graphql)$/,
  /(^|\/)migrations\//,
  /(^|\/)Dockerfile$/,
  /(^|\/)docker-compose[^/]*\.ya?ml$/,
  /(^|\/)\.github\/workflows\//,
  /\.proto$/,
  /(^|\/)auth(\/|\.|$)/i,
  /(^|\/)middleware(\/|\.|$)/i,
];

function hasAccentedDecision(lower) {
  return ACCENTED_MARKERS.some((marker) => lower.includes(marker));
}

function hasFoldedDecision(folded) {
  return FOLDED_MARKERS.some((marker) => folded.includes(marker));
}

function hasAccentlessDecision(folded) {
  const tokens = folded.split(/[^a-z0-9]+/).filter(Boolean);
  return ACCENTLESS_SEQUENCES.some(([subject, auxiliary]) => {
    for (let i = 0; i + 1 < tokens.length; i += 1) {
      if (tokens[i] !== subject || tokens[i + 1] !== auxiliary) continue;
      for (
        let j = i + 2;
        j <= i + 2 + ADVERB_WINDOW && j < tokens.length;
        j += 1
      ) {
        if (ACCENTLESS_PARTICIPLES.includes(tokens[j])) return true;
      }
    }
    return false;
  });
}

export function hasDecisionSignal(text) {
  const lower = text.toLowerCase();
  if (lower === "") return false;
  if (hasAccentedDecision(lower)) return true;
  const folded = foldAccents(lower);
  if (hasFoldedDecision(folded)) return true;
  return hasAccentlessDecision(folded);
}
