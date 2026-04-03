export const WIDE_THRESHOLD = 90;
export const COMPACT_THRESHOLD = 72;
export const VERY_NARROW_THRESHOLD = 60;

export type WidthBand = "wide" | "compact" | "narrow" | "very-narrow";

export function getWidthBand(width: number): WidthBand {
  if (width >= WIDE_THRESHOLD) return "wide";
  if (width >= COMPACT_THRESHOLD) return "compact";
  if (width >= VERY_NARROW_THRESHOLD) return "narrow";
  return "very-narrow";
}
