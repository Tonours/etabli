import { watchRun } from "../../src/client.ts";

const [host, tokenFile, id] = process.argv.slice(2);
const controller = new AbortController();
const timer = setTimeout(() => { controller.abort(); console.error("watch timed out"); process.exitCode = 1; }, 5000);
function done(result: string): void {
  clearTimeout(timer);
  controller.abort();
  console.log(JSON.stringify({ result }));
}
try {
  await watchRun("unused", id, 23, { host, tokenFile }, controller.signal, () => done("value"), () => done("closed"));
} catch { done("refused"); }
