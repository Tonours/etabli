import { readEvidence } from "./review-evidence-pack.mjs";
import { sha256 } from "./review-run-receipt.mjs";

// Exact excerpts only; this parser does not infer implicit requirements.
export function reviewPromptSources(root, selections) {
  const kinds = ["contract", "plan", "diff", "evidence"];
  return selections.map(({kind, path, start, end}) => {
    if (!kinds.includes(kind)) throw new Error("invalid prompt source kind");
    const evidence = readEvidence(root, path, {start, end});
    const obligations = ["contract", "plan"].includes(kind)
      ? evidence.text.split("\n").flatMap((line, index) => /^\s*[-*]\s+\[[ xX]\]/.test(line)
        ? [{id: sha256(evidence.path + ":" + (evidence.start + index) + ":" + line),
            line: evidence.start + index}] : []) : [];
    return {kind, ...evidence, obligations, extraction: "explicit_checkboxes_only"};
  });
}

export function observedPromptSources(payload, origins = []) {
  const strings = [];
  const visit = (value) => {
    if (typeof value === "string") strings.push(value);
    else if (Array.isArray(value)) value.forEach(visit);
    else if (value && typeof value === "object") Object.values(value).forEach(visit);
  };
  visit(payload);
  return origins.map(({kind,path,start,end,text,file_sha256,excerpt_sha256,obligations=[]}) => ({
    kind, path, start, end, file_sha256, excerpt_sha256: excerpt_sha256 ?? sha256(text),
    bytes: Buffer.byteLength(text), obligations,
    observed: Boolean(text) && strings.some(value => value.includes(text)),
  }));
}
