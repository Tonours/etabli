/**
 * Qwen3.8-27B Uncensored (abliterated) — self-hosted on OVH t2-le-45 (V100S).
 *
 * llama.cpp server with OpenAI-compatible API on port 8080 (Tailscale 100.x).
 * Endpoint: ~/.config/qwen/endpoint (updated by qwen-up.sh hook).
 * API key: ~/.config/qwen/api-key (chmod 600), resolved at request time via !command —
 * works in any shell, no env var needed.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const ENDPOINT_FILE = join(homedir(), ".config", "qwen", "endpoint");
const DEFAULT_ENDPOINT = "http://145.239.55.134:8080/v1";

function resolveEndpoint(): string {
  try {
    const value = readFileSync(ENDPOINT_FILE, "utf8").trim();
    if (value.startsWith("http")) return value;
  } catch {
    /* file absent — fall back */
  }
  return DEFAULT_ENDPOINT;
}

export default function (pi: ExtensionAPI) {
  pi.registerProvider("qwen-unc", {
    name: "Qwen Uncensored (OVH)",
    baseUrl: resolveEndpoint(),
    apiKey: "!cat ~/.config/qwen/api-key",
    api: "openai-completions",
    models: [
      {
        id: "qwen3.8-27b-uncensored",
        name: "Qwen3.8-27B Uncensored",
        reasoning: true,
        input: ["text"],
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
        contextWindow: 262144,
        maxTokens: 32768,
        compat: {
          // llama-server --jinja reads chat_template_kwargs.enable_thinking
          thinkingFormat: "qwen-chat-template",
        },
      },
    ],
  });
}
