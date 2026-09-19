import { validateJudgmentRequest, validateJudgmentResponse } from "./semantic-judgment.mjs";

export const TYPESAFE_TRANSPORT = Object.freeze({
  execution: "live_http",
  cache: "no-store",
});

export class TypeSafeServiceError extends Error {
  constructor(code, status = null, retryable = false) {
    super(code);
    this.name = "TypeSafeServiceError";
    this.code = code;
    this.status = status;
    this.retryable = retryable;
  }
}

function retryDelay(response, attempt) {
  const retryAfter = Number(response?.headers?.get?.("retry-after"));
  if (Number.isFinite(retryAfter) && retryAfter >= 0) return Math.min(retryAfter * 1000, 5000);
  return Math.min(150 * 2 ** attempt, 1200);
}

function abandonResponse(response, controller) {
  controller.abort();
  try {
    const cancellation = response.body?.cancel?.();
    cancellation?.catch?.(() => {});
  } catch {}
}

async function readBoundedText(response, maxBytes, deadline) {
  if (!response.body?.getReader) {
    const raw = await Promise.race([response.text(), deadline]);
    if (Buffer.byteLength(raw, "utf8") > maxBytes) throw new TypeSafeServiceError("response_too_large");
    return raw;
  }
  const reader = response.body.getReader();
  const chunks = [];
  let bytes = 0;
  let complete = false;
  try {
    while (true) {
      const { done, value } = await Promise.race([reader.read(), deadline]);
      if (done) { complete = true; break; }
      bytes += value.byteLength;
      if (bytes > maxBytes) { void reader.cancel().catch(() => {}); throw new TypeSafeServiceError("response_too_large"); }
      chunks.push(value);
    }
  } finally {
    if (complete) reader.releaseLock();
    else void reader.cancel().catch(() => {});
  }
  const output = new Uint8Array(bytes);
  let offset = 0;
  for (const chunk of chunks) { output.set(chunk, offset); offset += chunk.byteLength; }
  return new TextDecoder().decode(output);
}

export async function evaluateTypeSafe(request, options = {}) {
  validateJudgmentRequest(request);
  const apiKey = options.apiKey ?? process.env.TYPESAFE_API_KEY;
  if (!apiKey) throw new TypeSafeServiceError("missing_api_key");
  const fetchImpl = options.fetchImpl ?? globalThis.fetch;
  const sleep = options.sleep ?? ((ms) => new Promise((resolve) => setTimeout(resolve, ms)));
  const timeoutMs = options.timeoutMs ?? 1200;
  const maxRetries = options.maxRetries ?? 2;
  const maxResponseBytes = options.maxResponseBytes ?? 1_048_576;
  for (let attempt = 0; attempt <= maxRetries; attempt += 1) {
    const controller = new AbortController();
    let rejectDeadline;
    const deadline = new Promise((_, reject) => { rejectDeadline = reject; });
    const timer = setTimeout(() => {
      controller.abort();
      rejectDeadline(new TypeSafeServiceError("timeout"));
    }, timeoutMs);
    try {
      const response = await Promise.race([fetchImpl(options.endpoint ?? "https://api.typesafe.ai/v1/systemone", {
        method: "POST",
        cache: TYPESAFE_TRANSPORT.cache,
        headers: {
          authorization: `Bearer ${apiKey}`,
          "content-type": "application/json",
          "cache-control": "no-store, no-cache, max-age=0",
          pragma: "no-cache",
        },
        body: JSON.stringify(request),
        signal: controller.signal,
      }), deadline]);
      if (!response.ok) {
        abandonResponse(response, controller);
        const retryable = response.status === 429 || response.status === 529;
        if (retryable && attempt < maxRetries) { await sleep(retryDelay(response, attempt)); continue; }
        throw new TypeSafeServiceError(`http_${response.status}`, response.status, retryable);
      }
      const declaredLength = Number(response.headers?.get?.("content-length"));
      if (Number.isFinite(declaredLength) && declaredLength > maxResponseBytes) {
        abandonResponse(response, controller);
        throw new TypeSafeServiceError("response_too_large");
      }
      let raw;
      try { raw = await readBoundedText(response, maxResponseBytes, deadline); }
      catch (error) {
        if (error instanceof TypeSafeServiceError) throw error;
        throw new TypeSafeServiceError(error?.name === "AbortError" ? "timeout" : "body_read_error");
      }
      let body;
      try { body = JSON.parse(raw); } catch { throw new TypeSafeServiceError("malformed_json"); }
      try { return validateJudgmentResponse(request, body); } catch { throw new TypeSafeServiceError("malformed_response"); }
    } catch (error) {
      if (error instanceof TypeSafeServiceError) throw error;
      if (attempt < maxRetries && error?.name !== "AbortError") { await sleep(retryDelay(null, attempt)); continue; }
      throw new TypeSafeServiceError(error?.name === "AbortError" ? "timeout" : "network_error", null, error?.name !== "AbortError");
    } finally {
      clearTimeout(timer);
      controller.abort();
    }
  }
  throw new TypeSafeServiceError("retry_exhausted", null, true);
}
