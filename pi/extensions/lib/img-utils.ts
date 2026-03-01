/**
 * Image injection utilities — pure functions for testing.
 */

export const IMAGE_EXTENSIONS = new Set([".png", ".jpg", ".jpeg", ".gif", ".webp"]);

export const MIME_MAP: Record<string, string> = {
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".webp": "image/webp",
};

export function getExtension(path: string): string {
  const dot = path.lastIndexOf(".");
  return dot >= 0 ? path.slice(dot).toLowerCase() : "";
}

export function formatSize(bytes: number): string {
  if (bytes < 1024) return `${bytes}B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)}KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)}MB`;
}

/**
 * Tokenize input handling:
 * - backslash-escaped spaces (shell-style dropped file paths)
 * - double-quoted strings
 * - regular whitespace-separated tokens
 *
 * Note: single quotes are NOT treated as delimiters (macOS filenames use apostrophes)
 */
export function tokenize(input: string): string[] {
  const tokens: string[] = [];
  let i = 0;

  while (i < input.length) {
    // Skip whitespace
    if (input[i] === " " || input[i] === "\t") {
      i++;
      continue;
    }

    // Double-quoted string (single quotes are NOT special - macOS filenames use apostrophes)
    if (input[i] === '"') {
      i++;
      let token = "";
      while (i < input.length && input[i] !== '"') {
        if (input[i] === "\\" && i + 1 < input.length) {
          token += input[i + 1];
          i += 2;
        } else {
          token += input[i];
          i++;
        }
      }
      if (i < input.length) i++; // skip closing quote
      tokens.push(token);
      continue;
    }

    // Unquoted token (handles backslash-escaped spaces)
    let token = "";
    while (i < input.length && input[i] !== " " && input[i] !== "\t") {
      if (input[i] === "\\" && i + 1 < input.length && input[i + 1] === " ") {
        token += " ";
        i += 2;
      } else if (input[i] === "\\" && i + 1 < input.length) {
        token += input[i + 1];
        i += 2;
      } else {
        token += input[i];
        i++;
      }
    }
    tokens.push(token);
  }

  return tokens;
}

export function isImagePath(token: string): boolean {
  return IMAGE_EXTENSIONS.has(getExtension(token));
}
