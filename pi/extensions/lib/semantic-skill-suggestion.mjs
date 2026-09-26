import { lstatSync, readFileSync, realpathSync } from "node:fs";
import { dirname, join, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { evaluateSemanticProfile, loadSemanticProfilePolicy } from "./semantic-profiles.mjs";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const CATALOG = join(ROOT, "workflow/runtime/skill-surface.tsv");
const MAX_SKILLS = 100;
const MAX_DESCRIPTION = 260;
const MAX_PROMPT = 1200;

function normalizePrompt(prompt) {
  const value = String(prompt).replace(/\s+/g, " ").trim();
  if (!value) throw new Error("empty prompt");
  if (value.length > MAX_PROMPT) throw new Error("skill prompt too large");
  return value;
}

function frontmatterDescription(text) {
  const frontmatter = text.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/)?.[1];
  if (!frontmatter) throw new Error("skill frontmatter required");
  const lines = frontmatter.split(/\r?\n/);
  const index = lines.findIndex((line) => /^description:\s*/.test(line));
  if (index < 0) throw new Error("skill description required");
  const raw = lines[index].replace(/^description:\s*/, "").trim();
  if (/^[>|][+-]?$/.test(raw)) {
    const values = [];
    for (const line of lines.slice(index + 1)) {
      if (line && !/^\s+/.test(line)) break;
      if (line.trim()) values.push(line.trim());
    }
    return raw.startsWith("|") ? values.join("\n") : values.join(" ");
  }
  if (raw.startsWith('"') && raw.endsWith('"')) {
    try { return JSON.parse(raw); } catch { throw new Error("invalid quoted skill description"); }
  }
  if (raw.startsWith("'") && raw.endsWith("'")) return raw.slice(1, -1).replace(/''/g, "'");
  return raw;
}

function descriptionFromSkill(path) {
  const status = lstatSync(path);
  const realPath = realpathSync(path);
  if (status.isSymbolicLink() || !status.isFile() || !realPath.startsWith(`${ROOT}${sep}`)) throw new Error("unsafe skill catalog path");
  const text = readFileSync(realPath, "utf8");
  return frontmatterDescription(text).replace(/\s+/g, " ").trim().slice(0, MAX_DESCRIPTION);
}

function sourceRoot(source) {
  if (source === "pi") return join(ROOT, "pi/skills");
  if (source === "extras") return join(ROOT, "extras/skills");
  return join(ROOT, "vendor", source, "skills");
}

export function loadSkillSuggestionCatalog(catalogPath = CATALOG) {
  const records = readFileSync(catalogPath, "utf8").split("\n").filter((line) => line && !line.startsWith("#")).map((line) => {
    const [name, source] = line.split("\t");
    if (!/^[a-z0-9][a-z0-9-]*(?:\/[a-z0-9][a-z0-9-]*)?$/.test(name || "") || name.length > 96 || !/^[a-z0-9][a-z0-9-]{0,63}$/.test(source || "")) throw new Error("invalid skill catalog row");
    return { name, source, description: descriptionFromSkill(join(sourceRoot(source), name, "SKILL.md")) };
  });
  if (!records.length || records.length > MAX_SKILLS) throw new Error("invalid skill catalog size");
  if (new Set(records.map(({ name }) => name)).size !== records.length) throw new Error("duplicate skill catalog name");
  return records;
}

function choiceQuestion(records, instructions) {
  return { type: "choice", instructions, criteria: Object.fromEntries([...records.map(({ name, description }) => [name, description]), ["none", "No listed skill is a good fit."]]) };
}

function rankedCandidates(answer, limit = 3) {
  return Object.entries(answer?.probabilities || {}).filter(([name]) => name !== "none").sort((a, b) => b[1] - a[1]).slice(0, limit).map(([name]) => name);
}

export async function suggestSkill({ prompt, catalog = loadSkillSuggestionCatalog(), policy = loadSemanticProfilePolicy(), provider, allowProviderEgress = false, persistReceipt = true, cwd = process.cwd() }) {
  const userRequest = normalizePrompt(prompt);
  const stageOneQuestions = {
    candidate: choiceQuestion(catalog, "Choose the best potentially relevant skill from its name and short description, or none."),
    needs_skill: { type: "noul", instructions: "Would a specialized skill materially improve handling of this request?" }
  };
  const stageOne = await evaluateSemanticProfile({ profileId: "skill-suggestion", state: { user_request: userRequest, stage: "shortlist" }, questions: stageOneQuestions, policy, provider, allowProviderEgress, persistReceipt, cwd });
  if (stageOne.outcome === "abstain") return { selected: null, shortlist: [], outcome: "abstain", stages: [stageOne] };
  const stageOneAnswer = stageOne.answers?.candidate;
  const fallbackShortlist = stageOne.decisions?.candidate?.raw_value && stageOne.decisions.candidate.raw_value !== "none" ? [stageOne.decisions.candidate.raw_value] : [];
  const shortlist = stageOneAnswer ? rankedCandidates(stageOneAnswer) : fallbackShortlist;
  if (stageOne.decisions?.needs_skill?.value === false || shortlist.length === 0) return { selected: null, shortlist, outcome: stageOne.outcome === "uncertain" ? "uncertain" : "no_match", stages: [stageOne] };
  const byName = new Map(catalog.map((record) => [record.name, record]));
  const finalists = shortlist.map((name) => byName.get(name)).filter(Boolean);
  const fitQuestionIds = new Map(finalists.map(({ name }, index) => [name, `fits_${index}`]));
  const fitQuestions = Object.fromEntries(finalists.map(({ name, description }) => [fitQuestionIds.get(name), { type: "noul", instructions: `Does ${name} directly fit the request? Skill description: ${description}` }]));
  const stageTwoQuestions = { selected: choiceQuestion(finalists, "Choose the single best-fitting shortlisted skill, or none."), ...fitQuestions };
  const stageTwo = await evaluateSemanticProfile({ profileId: "skill-suggestion", state: { user_request: userRequest, stage: "selection" }, questions: stageTwoQuestions, policy, provider, allowProviderEgress, persistReceipt, cwd });
  const selected = stageTwo.decisions?.selected?.value;
  const fit = selected ? stageTwo.decisions?.[fitQuestionIds.get(selected)]?.value : false;
  return { selected: fit === true && selected !== "none" ? selected : null, shortlist, outcome: stageTwo.outcome === "accepted" && fit === true && selected !== "none" ? "accepted" : "uncertain", stages: [stageOne, stageTwo] };
}
