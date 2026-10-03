import commonmark from "../vendor/commonmark/commonmark.cjs";

export const assertionProtocol = "etabli-project-verification/1";

function text(node) {
  let value = "";
  const walker = node.walker();
  let event;
  while ((event = walker.next())) {
    if (event.entering && ["text", "code"].includes(event.node.type)) value += event.node.literal;
  }
  return value;
}

export function productVerificationDeclaration(source, { allowIncomplete = false, normalizedChecks } = {}) {
  const document = new commonmark.Parser().parse(source);
  let section = false;
  let count = 0;
  const fields = {};
  for (let node = document.firstChild; node; node = node.next) {
    if (node.type === "heading" && node.level === 2) {
      section = text(node).toLowerCase() === "product verification";
      if (section) count++;
    } else if (section && node.type === "list") {
      for (let item = node.firstChild; item; item = item.next) {
        const match = text(item).match(/^(Required|Evidence pack|Subject root):\s*(.+)$/i);
        if (!match) throw new Error("Product Verification accepts Required, Evidence pack and Subject root fields only");
        const key = match[1].toLowerCase();
        if (key in fields) throw new Error(`Duplicate Product Verification field: ${key}`);
        fields[key] = match[2].trim();
      }
    }
  }
  if (!count) return { required: false };
  if (count !== 1 || !["yes", "no", "auto"].includes(fields.required)) {
    throw new Error("Product Verification needs one explicit Required: yes, no or auto declaration");
  }
  if (fields.required === "no") return { required: false };
  const policy = fields.required === "auto" ? { assertion_protocol: assertionProtocol } : {};
  if (fields.required === "auto") {
    let classified;
    try { classified = classifiedCriteria(normalizedChecks); }
    catch (error) {
      if (allowIncomplete) return { unresolved: true, reason: error.message };
      throw error;
    }
    if (!classified.some(criterion => criterion.kind === "product")) return { required: false };
  }
  if (!fields["evidence pack"] || !fields["subject root"]) {
    if (allowIncomplete) return { required: true, ...policy };
    throw new Error("Product Verification requires Evidence pack and Subject root paths");
  }
  return { required: true, pack: fields["evidence pack"], subjectRoot: fields["subject root"], ...policy };
}

function classifiedCriteria(normalizedChecks) {
  if (!Array.isArray(normalizedChecks)) throw new Error("Auto product verification needs normalized acceptance criteria");
  const acceptance = normalizedChecks.filter(value => value.startsWith("acceptance-criteria:"));
  const criteria = acceptance.filter(value => !acceptance.some(parent => value.startsWith(`${parent}>`)));
  if (!criteria.length) throw new Error("Auto product verification needs classified acceptance criteria");
  const ids = new Set();
  return criteria.map(criterion => {
    const match = criterion.match(/^acceptance-criteria:(AC-[A-Za-z0-9-]+) \[(product|process|judgment)\]: /);
    if (!match || ids.has(match[1])) throw new Error("Product plans need unique classified AC IDs for every acceptance criterion");
    ids.add(match[1]);
    return { id: match[1], kind: match[2], criterion };
  });
}

export function productCriteria(normalizedChecks) {
  const products = [];
  for (const { id, kind, criterion } of classifiedCriteria(normalizedChecks)) {
    if (kind !== "product") continue;
    const proof = criterion.match(/\bProof: (action(?:,result)?(?:,side_effect)?|result(?:,side_effect)?|side_effect)\./)?.[1];
    if (!proof) throw new Error(`${id} needs explicit Proof: action,result[,side_effect].`);
    const roles = proof.split(",");
    if (!roles.includes("action") || !roles.includes("result")) throw new Error(`${id} requires action and result proof`);
    products.push({ id, proof: roles });
  }
  if (!products.length) throw new Error("Required product verification needs at least one product acceptance criterion");
  return products;
}
