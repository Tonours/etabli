import { createServer } from "node:http";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
const root = process.env.ETABLI_RUN_DIR,
  state = join(root, "state.json");
const html =
  '<!doctype html><html lang="en"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Value editor</title><style>body{background:#fff;color:#000}:focus-visible{outline:2px solid #000;outline-offset:2px}</style><label for="value">Value</label><input id="value"><button id="save">Save</button><p role="status"></p><script>const input=document.querySelector("input"); fetch("/state").then(r=>r.json()).then(s=>{input.value=s.value;document.body.dataset.ready="true"});document.querySelector("button").onclick=async()=>{await fetch("/state",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify({value:input.value})});document.querySelector("[role=status]").textContent="Saved"}</script></html>';
const server = createServer(async (request, response) => {
  if (request.url === "/state") {
    if (request.method === "POST") {
      let bytes = "";
      for await (const chunk of request) bytes += chunk;
      const value = JSON.parse(bytes).value;
      if (typeof value !== "string") {
        response.writeHead(400).end();
        return;
      }
      writeFileSync(state, JSON.stringify({ value }) + "\n");
    }
    response.setHeader("content-type", "application/json");
    response.end(readFileSync(state));
  } else {
    response.setHeader("content-type", "text/html");
    response.end(html);
  }
});
server.listen(0, "127.0.0.1", () =>
  writeFileSync(
    join(root, "url.json"),
    JSON.stringify({ url: "http://127.0.0.1:" + server.address().port }) + "\n",
  ),
);
process.on("SIGTERM", () => server.close());
