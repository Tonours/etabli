/**
 * Load and format route-context manifests for router injection (blueprint T1).
 */
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const DEFAULT_MANIFEST = join(HERE, "../../workflow/route-context-manifests.json");

/**
 * @param {string} [manifestPath]
 */
export function loadRouteContextManifest(manifestPath = DEFAULT_MANIFEST) {
  if (!existsSync(manifestPath)) return null;
  try {
    return JSON.parse(readFileSync(manifestPath, "utf8"));
  } catch {
    return null;
  }
}

/**
 * Normalize verify aliases to manifest keys.
 * @param {string} route
 */
export function manifestRouteKey(route) {
  if (route === "verify") return "verify-workflow";
  return route;
}

/**
 * @param {string} route
 * @param {any} manifest
 */
export function getRouteManifestEntry(route, manifest) {
  if (!manifest?.routes) return null;
  const key = manifestRouteKey(route);
  return manifest.routes[key] || null;
}

/**
 * Compact progressive-disclosure block for system/route context.
 * @param {string} route
 * @param {string} [manifestPath]
 */
export function formatRouteContextGuidance(route, manifestPath = DEFAULT_MANIFEST) {
  const manifest = loadRouteContextManifest(manifestPath);
  const entry = getRouteManifestEntry(route, manifest);
  if (!entry) return "";

  const required = Array.isArray(entry.required_sources) ? entry.required_sources : [];
  const conditional = Array.isArray(entry.conditional_sources) ? entry.conditional_sources : [];
  const budget = entry.max_estimated_tokens;
  const stop = entry.stop || "";
  const disclosure = entry.progressive_disclosure || manifest?.defaults?.progressive_disclosure || [];

  const lines = [
    "Route context manifest (progressive load):",
    `Required sources: ${required.join(", ") || "(none)"}`,
  ];
  if (conditional.length) lines.push(`Conditional sources: ${conditional.join(", ")}`);
  if (typeof budget === "number") lines.push(`Soft context budget: ≤${budget} estimated tokens (ceil chars/4 style)`);
  if (stop) lines.push(`Route stop: ${stop}`);
  if (Array.isArray(disclosure) && disclosure.length) {
    lines.push(`Load order: ${disclosure.join(" → ")}`);
  }
  lines.push(
    "Do not bulk-read manuals outside required/conditional sources unless a reproduced failure requires it.",
  );
  return lines.join("\n");
}
