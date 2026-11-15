import { SharedCredentialStore } from "../../src/credentials.ts";
import { syntheticOAuth } from "./oauth.ts";

const [path, root, delay] = process.argv.slice(2);
const { models, model } = syntheticOAuth(new SharedCredentialStore(path), root, Number(delay));
const response = await models.completeSimple(model, { messages: [{ role: "user", content: "fixture", timestamp: Date.now() }] });
if (response.content[0]?.type !== "text" || response.content[0].text !== "ok") throw new Error("Synthetic request failed");
console.log("ok");
