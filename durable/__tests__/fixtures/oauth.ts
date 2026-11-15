import { appendFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { createModels, createProvider, type CredentialStore, type OAuthCredential } from "@earendil-works/pi-ai";
import { createFauxCore, fauxAssistantMessage } from "@earendil-works/pi-ai/providers/faux";

export function syntheticOAuth(credentials: CredentialStore, root: string, delay: number) {
  const core = createFauxCore({ provider: "fixtureoauth", models: [{ id: "fixture" }] });
  core.setResponses([fauxAssistantMessage("ok")]);
  const refresh = async (credential: OAuthCredential): Promise<OAuthCredential> => {
    await appendFile(join(root, "refreshes"), "refresh\n");
    await writeFile(join(root, "refresh-held"), "ready");
    await new Promise((resolve) => setTimeout(resolve, delay));
    return { ...credential, access: "synthetic-rotated-access", refresh: "synthetic-rotated-refresh", expires: Date.now() + 3_600_000 };
  };
  const models = createModels({ credentials });
  models.setProvider(createProvider({ id: "fixtureoauth", auth: { oauth: { name: "Synthetic OAuth", login: async () => { throw new Error("No login in fixture"); }, refresh, toAuth: async (credential) => ({ apiKey: credential.access }) } }, models: core.models, api: { stream: core.stream, streamSimple: core.streamSimple } }));
  return { models, model: core.getModel(), refresh };
}
