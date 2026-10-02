import commonmark from "../vendor/commonmark/commonmark.cjs";

function text(node) {
  let value = "";
  const walker = node.walker();
  let event;
  while ((event = walker.next())) {
    if (event.entering && ["text", "code"].includes(event.node.type)) value += event.node.literal;
  }
  return value;
}

export function productVerificationDeclaration(source, { allowIncomplete = false } = {}) {
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
  if (count !== 1 || !["yes", "no"].includes(fields.required)) {
    throw new Error("Product Verification needs one explicit Required: yes or no declaration");
  }
  if (fields.required === "no") return { required: false };
  if (!fields["evidence pack"] || !fields["subject root"]) {
    if (allowIncomplete) return { required: true };
    throw new Error("Product Verification requires Evidence pack and Subject root paths");
  }
  return { required: true, pack: fields["evidence pack"], subjectRoot: fields["subject root"] };
}

export function productCriteria(normalizedChecks) {
  const acceptance = normalizedChecks.filter(value => value.startsWith("acceptance-criteria:"));
  const criteria = acceptance.filter(value => !acceptance.some(parent => value.startsWith(`${parent}>`)));
  const ids = new Set();
  const products = [];
  for (const criterion of criteria) {
    const match = criterion.match(/^acceptance-criteria:(AC-[A-Za-z0-9-]+) \[(product|process|judgment)\]: /);
    if (!match || ids.has(match[1])) throw new Error("Product plans need unique classified AC IDs for every acceptance criterion");
    ids.add(match[1]);
    if (match[2] !== "product") continue;
    const proof = criterion.match(/\bProof: (action(?:,result)?(?:,side_effect)?|result(?:,side_effect)?|side_effect)\./)?.[1];
    if (!proof) throw new Error(`${match[1]} needs explicit Proof: action,result[,side_effect].`);
    const roles = proof.split(",");
    if (!roles.includes("action") || !roles.includes("result")) throw new Error(`${match[1]} requires action and result proof`);
    products.push({ id: match[1], proof: roles });
  }
  if (!products.length) throw new Error("Required product verification needs at least one product acceptance criterion");
  return products;
}
