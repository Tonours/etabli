/**
 * Shared value predicates for workflow libs. Byte-for-byte identical logic
 * previously duplicated across ledger-integrity,
 * no-progress-guard and ledger-auto-emit.
 * @param {unknown} value
 */
export function isObject(value) {
 return value !== null && typeof value === "object" && !Array.isArray(value);
}

/** @param {unknown} value */
export function isNonEmptyString(value) {
 return typeof value === "string" && value.trim() !== "";
}

/** @param {unknown} value @param {number} [minimum] */
export function isStringArray(value, minimum = 1) {
 return (
  Array.isArray(value) &&
  value.length >= minimum &&
  value.every(isNonEmptyString)
 );
}
