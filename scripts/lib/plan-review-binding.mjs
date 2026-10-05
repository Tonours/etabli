import { createHash } from "node:crypto";
import { closeSync, constants, fstatSync, lstatSync, openSync, readFileSync } from "node:fs";
import { dirname, extname, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import commonmark from "../vendor/commonmark/commonmark.cjs";
import { parsePlanStatus } from "./plan-check-freeze.mjs";
import { selectActiveLedger } from "./ledger-integrity.mjs";

const digest = (value) => createHash("sha256").update(value).digest("hex");
const sha = (value) => typeof value === "string" && /^[a-f0-9]{64}$/.test(value);
const children = (node) => {
  const result = [];
  for (let child = node.firstChild; child; child = child.next) result.push(child);
  return result;
};
const text = (node) => node.literal ?? children(node).map(text).join("");
const heading = (node) => text(node).trim().toLowerCase();
export function planContract(source) {
  // CommonMark locates owned bookkeeping, but command bytes stay authoritative:
  // rendering would erase escapes that change shell behavior.
  const parser = new commonmark.Parser(), lines = String(source).split(/\r?\n/);
  const walker = parser.parse(String(source)).walker();
  let event;
  while ((event = walker.next())) {
    if (!event.entering || event.node.type !== "item") continue;
    const [line, column] = event.node.sourcepos[0], prefix = lines[line-1].slice(0,column-1);
    const rest = lines[line-1].slice(column-1);
    lines[line-1] = prefix + rest.replace(/^([-+*]|\d+[.)])(\s+)\[[xX]\](?=\s|$)/, "$1$2[ ]");
  }
  const document = parser.parse(lines.join("\n")), excluded = new Set();
  function visit(node, section) {
    const paragraph = node.type === "item" && node.firstChild?.type === "paragraph" ? text(node.firstChild) : "";
    const simple = node.type === "item" && children(node).length === 1 && node.sourcepos[0][0] === node.sourcepos[1][0];
    const owner = node.parent?.parent;
    if (simple && ((section === "meta" && /^(?:Status: (?:DRAFT|CHALLENGED|READY)|Last revised: [^\n]*|Archive: [^\n]*)$/.test(paragraph)) ||
        (/^(?:checks|validation plan)\b/.test(section) && /^last run:/i.test(paragraph) && owner?.type === "item" && /^command:/i.test(text(owner.firstChild))))) {
      excluded.add(node.sourcepos[0][0]-1);
    }
    for (const child of children(node)) visit(child,section);
  }
  let section = "", decisions = [];
  for (const node of children(document)) {
    if (node.type === "heading" && node.level <= 2) section = heading(node);
    visit(node,section);
    if (section === "decision log" && node.type !== "heading") decisions.push(text(node));
  }
  return { contract_sha256:digest(lines.filter((_,index) => !excluded.has(index)).join("\n")), decisions, source:String(source) };
}

export function readPlanContractFile(path) {
  const fd = openSync(path, constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
  try {
    const stat = fstatSync(fd);
    if (!stat.isFile() || stat.size > 16_777_216) throw new Error("plan requires a regular text snapshot at most 16 MiB");
    const source = new TextDecoder("utf-8",{fatal:true,ignoreBOM:true}).decode(readFileSync(fd));
    if (source.includes("\0")) throw new Error("plan requires text");
    return { ...planContract(source), status:parsePlanStatus(source) };
  } finally { closeSync(fd); }
}

export function readRootPlanContract(root) {
  const path = resolve(root,"PLAN.md");
  return lstatSync(path,{throwIfNoEntry:false}) ? readPlanContractFile(path) : null;
}

export function evaluatePlanReview(events, source) {
  const bindings = events.filter((row) => row.event === "plan_created" && Object.hasOwn(row.detail,"plan_contract_sha256"));
  if (!bindings.length) return {ok:true,mode:"legacy-unbound"};
  if (bindings.some((row) => !sha(row.detail.plan_contract_sha256))) return {ok:false,reason:"invalid_plan_binding"};
  const current = planContract(source).contract_sha256;
  const latest = events.filter((row) => row.event === "adversary_completed" && row.detail.mode === "plan").at(-1)?.detail;
  if (!latest) return {ok:false,reason:"missing_plan_review"};
  if (!sha(latest.plan_contract_sha256) || latest.plan_contract_sha256 !== current) return {ok:false,reason:"stale_plan_review"};
  if (latest.verdict !== "READY" || !Array.isArray(latest.accepted_findings) ||
      latest.accepted_findings.some((finding) => !finding || typeof finding !== "object" || finding.blocking !== false)) {
    return {ok:false,reason:"blocking_plan_review"};
  }
  const provenance = latest.model_provenance;
  if (!provenance || ![provenance.requested,provenance.effective].every((model) =>
      model && [model.family,model.model,model.provider].every((value) => typeof value === "string" && value.length)) ||
      ![provenance.runner,provenance.run_id].every((value) => typeof value === "string" && value.length)) {
    return {ok:false,reason:"invalid_plan_review_provenance"};
  }
  return {ok:true,mode:"bound-reviewed",contract_sha256:current};
}

export function planReviewPermission(root, source) {
  const selection = selectActiveLedger(root);
  if (selection.reason) return {ok:false,reason:selection.reason};
  return selection.ledger ? evaluatePlanReview(selection.ledger.events,source) : {ok:true,mode:"legacy-no-ledger"};
}

function confinedPath(root, run, path) {
  const absolute = resolve(root,path), directory = resolve(root,".workflow",run), rel = relative(directory,absolute);
  if (!rel || rel === ".." || rel.startsWith(`..${sep}`) || rel.startsWith(sep)) return false;
  for (let current = absolute; current !== resolve(root); current = dirname(current)) {
    const stat = lstatSync(current,{throwIfNoEntry:false});
    if (stat?.isSymbolicLink()) return false;
    if (dirname(current) === current) return false;
  }
  return true;
}

export function isReviewPreparationPath(root, path) {
  if (![".md",".patch"].includes(extname(path))) return false;
  try {
    const selection = selectActiveLedger(root);
    return !selection.reason && Boolean(selection.ledger) && confinedPath(root,selection.ledger.run,path);
  } catch { return false; }
}

const centralCheck = fileURLToPath(new URL("../plan-review-check",import.meta.url));
const centralHunter = fileURLToPath(new URL("../pi-review-hunter",import.meta.url));
export function isPlanReviewBootstrap(words, root) {
  if (!words?.length) return false;
  words = [...words];
  if (words[0] === "rtk" && words[1] === "proxy") words.splice(0,2);
  const interpreter = ["node","bun","bash"].includes(words[0]) ? words.shift() : null;
  const executable = resolve(root,words.shift() ?? "");
  if ([resolve(root,"scripts/plan-review-check"),centralCheck].includes(executable)) {
    return interpreter !== "bash" && words.length === 2 && words[0] === "--hash" && resolve(root,words[1]) === resolve(root,"PLAN.md");
  }
  if (![resolve(root,"scripts/pi-review-hunter"),centralHunter].includes(executable) || words.length % 2) return false;
  if (interpreter && interpreter !== "bash") return false;
  const options = {};
  for (let index=0; index<words.length; index+=2) {
    const key = words[index], value = words[index+1];
    if (!["--prompt-file","--patch","--capture-dir","--pass-id","--role","--model","--timeout"].includes(key) || Object.hasOwn(options,key) || !value) return false;
    options[key] = value;
  }
  if (options["--role"] !== "adversary-plan" || !/^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$/.test(options["--pass-id"] ?? "") ||
      (options["--model"] && !/^[A-Za-z0-9][A-Za-z0-9_./:@-]*$/.test(options["--model"])) ||
      (options["--timeout"] && !/^[1-9][0-9]*$/.test(options["--timeout"]))) return false;
  const selected = selectActiveLedger(root);
  if (selected.reason || !selected.ledger || !options["--capture-dir"] ||
      !confinedPath(root,selected.ledger.run,options["--capture-dir"]) ||
      lstatSync(resolve(root,options["--capture-dir"]),{throwIfNoEntry:false})) return false;
  if (!options["--prompt-file"] || !isReviewPreparationPath(root,options["--prompt-file"]) || extname(options["--prompt-file"]) !== ".md") return false;
  const patch = options["--patch"];
  if (!patch || (resolve(root,patch) !== resolve(root,"PLAN.md") &&
      (!isReviewPreparationPath(root,patch) || extname(patch) !== ".patch"))) return false;
  try {
    return readFileSync(resolve(root,patch),"utf8") === readRootPlanContract(root)?.source;
  } catch { return false; }
}
