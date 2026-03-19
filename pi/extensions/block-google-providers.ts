import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

const BLOCKED_PROVIDERS = new Set(["google-antigravity", "google-gemini-cli"]);
const FALLBACKS = [
  ["openai-codex", "gpt-5.4"],
  ["github-copilot", "gpt-5.4"],
  ["openai-codex", "gpt-5.3-codex"],
  ["github-copilot", "gpt-5.3-codex"],
] as const;

type ProviderModel = {
  provider: string;
  id: string;
};

function isBlocked(model: ProviderModel | undefined): boolean {
  return model !== undefined && BLOCKED_PROVIDERS.has(model.provider);
}

function formatModel(model: ProviderModel | undefined): string {
  return model ? `${model.provider}/${model.id}` : "none";
}

export default function (pi: ExtensionAPI) {
  let switching = false;

  async function switchToAllowed(
    ctx: ExtensionContext,
    preferred?: ProviderModel,
  ): Promise<ProviderModel | undefined> {
    if (switching) return undefined;

    const candidates: ProviderModel[] = [];
    if (preferred && !isBlocked(preferred)) candidates.push(preferred);

    for (const [provider, id] of FALLBACKS) {
      const model = ctx.modelRegistry.find(provider, id);
      if (model && !isBlocked(model)) candidates.push(model);
    }

    switching = true;
    try {
      for (const candidate of candidates) {
        const ok = await pi.setModel(candidate);
        if (ok) return candidate;
      }
      return undefined;
    } finally {
      switching = false;
    }
  }

  async function enforceAllowedModel(
    ctx: ExtensionContext,
    preferred?: ProviderModel,
  ): Promise<ProviderModel | undefined> {
    if (!isBlocked(ctx.model)) return ctx.model;
    return switchToAllowed(ctx, preferred);
  }

  async function repairCurrentModel(ctx: ExtensionContext): Promise<void> {
    if (!isBlocked(ctx.model)) return;

    const next = await enforceAllowedModel(ctx);
    if (next) {
      ctx.ui.notify(
        `Google providers disabled. Switched to ${formatModel(next)}.`,
        "warning",
      );
      return;
    }

    ctx.ui.notify(
      "Google providers disabled. No fallback model available.",
      "error",
    );
  }

  pi.on("session_start", async (_event, ctx) => {
    await repairCurrentModel(ctx);
  });

  pi.on("session_switch", async (_event, ctx) => {
    await repairCurrentModel(ctx);
  });

  pi.on("model_select", async (event, ctx) => {
    if (switching || !isBlocked(event.model)) return;

    const next = await switchToAllowed(ctx, event.previousModel);
    if (next) {
      ctx.ui.notify(
        `Blocked ${formatModel(event.model)}. Using ${formatModel(next)} instead.`,
        "warning",
      );
      return;
    }

    ctx.ui.notify(
      `Blocked ${formatModel(event.model)}. No fallback model available.`,
      "error",
    );
  });

  pi.on("input", async (_event, ctx) => {
    if (!isBlocked(ctx.model)) return { action: "continue" };

    const next = await enforceAllowedModel(ctx);
    if (next) return { action: "continue" };

    ctx.ui.notify(
      "Google providers disabled. Request blocked until you select a non-Google model.",
      "error",
    );
    return { action: "handled" };
  });
}
