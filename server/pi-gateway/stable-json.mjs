function canonicalize(value, seen) {
  if (value === null || typeof value === "string" || typeof value === "boolean") return value;
  if (typeof value === "number") return Number.isFinite(value) ? value : String(value);
  if (typeof value === "bigint") return value.toString();
  if (typeof value === "undefined") return null;
  if (typeof value !== "object") return String(value);
  if (seen.has(value)) return "[Circular]";

  seen.add(value);
  let normalized;
  if (Array.isArray(value)) {
    normalized = value.map((item) => canonicalize(item, seen));
  } else {
    normalized = Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, canonicalize(value[key], seen)]),
    );
  }
  seen.delete(value);
  return normalized;
}

export function stableBoundedJson(value, maxCharacters = 16_384) {
  const serialized = JSON.stringify(canonicalize(value, new Set())) ?? "null";
  if (serialized.length <= maxCharacters) return serialized;
  const suffix = "...[truncated]";
  return `${serialized.slice(0, Math.max(0, maxCharacters - suffix.length))}${suffix}`;
}
