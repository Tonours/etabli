import { TABS, newState, viewLines } from "./views.js";
import { captureTime, pageContent, viewOverview } from "./overview.js";

const PANE = "etabli";
const HOTKEYS = { refresh: "r", details: "d", prev: "b", next: "n", "journal-prev": "j", "journal-next": "k", preflight: "p", close: "c", capture: "g", recheck: "v" };
let state = newState();
let requestSequence = 0;
let activitySequence = 0;
let usageSequence = 0;
let parentTurnSequence = 0;

function reserveRequest() {
  const generation = ++requestSequence;
  if (state.reviewPending) {
    state.reviewNotice = state.reviewBaseline ? "Capture annulée par une action plus récente ; dossier précédent conservé, à recontrôler." : "Capture annulée par une action plus récente ; capturer explicitement.";
    state.reviewPending = 0;
    state.reviewStale = true;
  }
  state.generation = generation;
  state.busy = false;
  return generation;
}

function applyUsage(usage, sequence) {
  if (usage === null || sequence <= state.lastUsageWrite) return;
  state.lastUsageWrite = sequence;
  state.usage = usage;
}

function markActivity(capturedState = state) {
  if (state !== capturedState) return;
  activitySequence += 1;
  state.stale = true;
  state.reviewStale = true;
  state.diagnosticStale = true;
}

async function bind($, generation = requestSequence) {
  const capturedState = state;
  const capturedIdentity = state.identity;
  const identity = JSON.stringify([await $.session.id(), await $.session.cwd()]);
  if ((generation !== null && generation !== requestSequence) || state !== capturedState) return null;
  if (state.identity !== capturedIdentity && state.identity !== identity) return null;
  if (identity !== state.identity) {
    if (!state.identity) state.identity = identity;
    else state = newState(identity);
  }
  return identity;
}

async function observation($) {
  try { const identity = await bind($, null); return identity === null ? null : { identity, capturedState: state }; }
  catch { markActivity(); return null; }
}

async function refresh($, mode = "snapshot", kind = "", freshReview = null, generation = reserveRequest()) {
  if (generation !== requestSequence) return;
  const activity = activitySequence;
  let identity = state.identity;
  state.generation = generation;
  if (mode === "review") { state.reviewPending = generation; state.reviewNotice = "Lecture du dossier en cours…"; }
  try {
    const capturedState = state;
    if (await bind($, generation) === null) return;
    if (generation !== requestSequence) return;
    identity = state.identity;
    state.generation = generation;
    if (mode !== "snapshot" && state !== capturedState) throw new Error("Session or project changed; reopen /etabli before capturing evidence");
    if (mode !== "snapshot" && !state.snapshot) throw new Error("Aucune projection disponible pour cette session ; Actualiser avant cette action.");
    if (mode === "review" && !freshReview && !state.reviewBaseline) throw new Error("Aucun dossier capturé à recontrôler ; utiliser Capturer.");
    state.busy = true;
    state.error = null;
    await $.ui.invalidate("ui.render");
    const cwd = await $.session.cwd();
    const argv = ["node", $.plugin.root + "/../../../scripts/lib/etabli-session.mjs", mode, "--cwd", cwd];
    if (state.run) argv.push("--run", state.run);
    if (mode === "snapshot") argv.push("--page", String(state.journalPage));
    if (mode === "diagnostic") argv.push("--kind", kind);
    const excerpt = freshReview ? freshReview.excerpt : state.reviewBaseline ? state.reviewExcerpt : state.excerpt.trim();
    const reviewBase = freshReview ? freshReview.base : state.reviewBase;
    if (mode === "review") {
      argv.push("--base", reviewBase);
      if (excerpt) argv.push("--excerpt", excerpt);
    }
    const previous = mode === "review" && !freshReview ? state.reviewBaseline || undefined : undefined;
    const result = await $.process.run(argv, { cwd, stdin: JSON.stringify({ previous }), timeoutMs: 120000 });
    if (result.isStdoutTruncated) throw new Error("Native helper stdout exceeds 4 MiB (exact total unknown); inspect scripts/etabli-session review directly or choose a closer Git base.");
    if (!result.stdout.trim()) throw new Error(`Etabli bridge unavailable: check node on PATH and the source helper ${argv[1]}`);
    const data = JSON.parse(result.stdout);
    if (result.exitCode !== 0 || (mode !== "diagnostic" && data.error)) throw new Error(data.error || "Etabli helper failed; check node and the source checkout path");
    let usage = null, usageOrder = 0, commands = null, overrides = null;
    if (mode === "snapshot") {
      usageOrder = ++usageSequence;
      usage = await $.session.usage().catch(() => null);
      commands = await $.command.list().catch(() => null);
      const settings = await $.settings.read().catch(() => ({}));
      const raw = settings.skillOverrides;
      overrides = raw && typeof raw === "object" ? Object.fromEntries(Object.entries(raw)
        .filter((entry) => ["on", "off", "name-only", "user-invocable-only"].includes(entry[1]))) : null;
    }
    const current = JSON.stringify([await $.session.id(), await $.session.cwd()]);
    if (current !== identity || state.identity !== identity || state.generation !== generation || generation !== requestSequence) return;
    if (mode !== "snapshot" && state.snapshot) {
      const root = mode === "review" ? data.identity.root : data.project_root;
      const run = mode === "review" ? data.identity.run : data.run;
      if (root !== state.snapshot.root || run !== state.snapshot.selection.run) throw new Error("Project or active run changed; refresh the session projection before this check");
    }
    if (mode === "snapshot") {
      if (state.snapshot && (data.root !== state.snapshot.root || data.selection.run !== state.snapshot.selection.run)) {
        state.review = null;
        state.reviewBaseline = null;
        state.reviewExcerpt = "";
        state.reviewBase = "";
        state.reviewNotice = "";
        state.reviewStale = true;
        state.diagnostic = null;
        state.diagnosticStale = true;
      }
      state.snapshot = data;
      state.journalPage = data.journal.page;
      state.stale = activitySequence !== activity;
      applyUsage(usage, usageOrder);
      state.commands = commands;
      state.overrides = overrides;
    }
    if (mode === "diagnostic") { state.diagnostic = data; state.diagnosticStale = activitySequence !== activity; }
    if (mode === "review") {
      if (freshReview) { state.reviewExcerpt = excerpt; state.reviewBase = reviewBase; state.reviewBaseline = data.identity; }
      state.review = data;
      state.reviewNotice = "";
      state.reviewStale = activitySequence !== activity;
    }
    state.page = 0;
  } catch (error) {
    if (state.identity === identity && state.generation === generation && generation === requestSequence) {
      state.error = error.message;
      state.stale = true;
      if (mode === "review") {
        if (!freshReview && state.reviewBaseline && state.review) state.review = { ...state.review,
          state: "invalidated", complete: false, freshness: "failed recheck; previous capture retained",
          invalidation_reasons: [...new Set([...state.review.invalidation_reasons, error.message])] };
        state.reviewStale = true;
        state.reviewNotice = freshReview && state.review ? "Nouvelle capture échouée ; dossier précédent conservé, à recontrôler." : "";
      }
      if (mode === "diagnostic") { state.diagnostic = null; state.diagnosticStale = true; }
    }
  } finally {
    if (state.identity === identity && state.generation === generation && generation === requestSequence) {
      state.busy = false;
      if (state.reviewPending === generation) state.reviewPending = 0;
      try { await $.ui.invalidate("ui.render"); } catch { /* The generation is already released if painting fails. */ }
    }
  }
}

export function register(on) {
  on("session.start", async ($, e, next) => {
    state = newState();
    try { await $.command.register({ name: "etabli", description: "Ouvrir le cockpit du workflow Etabli", argumentHint: "[vue | run SLUG]", immediate: true }); }
    catch (error) { state.error = `Cannot register /etabli: ${error.message}`; state.stale = true; }
    return next(e);
  });

  on("session.end", ($, e, next) => {
    state = newState();
    return next(e);
  });

  on("command.run", { command: ["clear", "resume"] }, async ($, e, next) => {
    state = newState();
    return next(e);
  });

  on("command.run", { command: "etabli" }, async ($, e) => {
    const generation = reserveRequest();
    let capturedState = state;
    try {
      if (await bind($, generation) === null) return {};
      const args = e.args.trim().split(/\s+/).filter(Boolean);
      if (args[0] === "run") {
        state = newState(state.identity);
        state.run = args[1] || "";
      } else if (args[0] && TABS.some((tab) => tab[0] === args[0])) state.tab = args[0];
      capturedState = state;
      await $.ui.open({ id: PANE, title: "Etabli", focus: true, closeOnEscape: true, rows: 36, columns: 72 });
      if (generation !== requestSequence || state !== capturedState) return {};
      await refresh($, "snapshot", "", null, generation);
    } catch (error) {
      if (state === capturedState && generation === requestSequence) {
        state.error = error.message;
        state.busy = false;
        markActivity(capturedState);
        try { await $.ui.invalidate("ui.render"); } catch { /* The command remains immediate. */ }
      }
    }
    return {};
  });

  on("session.measure", async ($, e, next) => {
    const sequence = ++usageSequence;
    const observed = await observation($);
    const result = await next(e);
    if (!observed) return result;
    try {
      const current = JSON.stringify([await $.session.id(), await $.session.cwd()]);
      if (state !== observed.capturedState || current !== observed.identity) return result;
      applyUsage({ context: e.context, rateLimits: e.rateLimits, cost: e.cost }, sequence);
      await $.ui.invalidate("ui.render");
    } catch { markActivity(observed.capturedState); }
    return result;
  });

  on("turn.complete", async ($, e, next) => {
    const parentSequence = e.agentId ? 0 : ++parentTurnSequence;
    const observed = await observation($);
    if (observed && !e.agentId) markActivity(observed.capturedState);
    const result = await next(e);
    if (!observed || e.agentId) return result;
    try {
      const sequence = ++usageSequence;
      const usage = await $.session.usage().catch(() => null);
      const current = JSON.stringify([await $.session.id(), await $.session.cwd()]);
      if (state !== observed.capturedState || current !== observed.identity) return result;
      if (parentSequence > state.lastParentWrite) {
        state.lastParentWrite = parentSequence;
        state.turn = { turnId: e.turnId, usage: e.usage || null };
      }
      markActivity(observed.capturedState);
      applyUsage(usage, sequence);
      await $.ui.invalidate("ui.render");
    } catch { markActivity(observed.capturedState); }
    return result;
  });

  on("tool.call", async ($, e, next) => {
    const capturedState = state;
    const capturedIdentity = state.identity;
    markActivity(capturedState);
    try { return await next(e); }
    finally {
      const identity = capturedIdentity || capturedState.identity;
      if (state === capturedState || (identity && state.identity === identity)) {
        markActivity();
        try { void $.ui.invalidate("ui.render").catch(() => {}); } catch { /* Observation cannot replace the tool result. */ }
      }
    }
  });

  on("ui.render", { component: "Pane" }, async ($, e, next) => {
    if (e.requestId !== PANE) return next(e);
    if (await bind($) === null) return next(e);
    const { Box, Text, Button, Input } = $.ui.resolve(e);
    const redraw = () => $.ui.invalidate("ui.render");
    const project = state.snapshot?.root?.split("/").filter(Boolean).at(-1);
    const overview = viewOverview(state);
    const columns = e.props?.bodyColumns || 72;
    // The pane's allocated height follows this tree; only the viewport is stable.
    const rows = Math.max(4, Math.min(14, (e.viewport?.rows || 40) - (state.tab === "review" ? 22 : 18)));
    const page = pageContent(state.details ? viewLines(state) : overview.lines, state.page, columns - 2, rows);
    const primary = state.tab === "review" ? state.review && state.review.complete && state.review.state !== "invalidated" && state.reviewStale ? "recheck" : "capture"
      : state.tab === "diagnostic" ? "preflight" : state.stale || !state.snapshot ? "refresh" : "";
    const button = (key, label, onPress) => Button({ key, label: `${label} (${HOTKEYS[key]})`, hotkey: HOTKEYS[key],
      variant: key === primary ? "primary" : "secondary", onPress });
    const navigation = TABS.map((tab, index) => Button({ key: tab[0], label: tab[1], hotkey: String(index + 1), plain: true,
      dimColor: state.tab !== tab[0], onPress: () => { state.tab = tab[0]; state.page = 0; state.details = false; redraw(); } }));
    const controls = [button("refresh", "Actualiser", () => refresh($))];
    if (state.tab === "journal") controls.push(
      button("journal-prev", "Lot précédent", () => { state.journalPage = Math.max(0, state.journalPage - 1); return refresh($); }),
      button("journal-next", "Lot suivant", () => { state.journalPage += 1; return refresh($); }));
    if (state.tab === "diagnostic") controls.push(
      button("preflight", "Vérifier les préconditions", () => refresh($, "diagnostic", "preflight")),
      button("close", "Tester la clôture", () => refresh($, "diagnostic", "close")));
    if (state.tab === "review") controls.push(
      button("capture", "Capturer le diff", () => {
        const input = { base: state.base.trim() || "HEAD", excerpt: state.excerpt.trim() };
        return refresh($, "review", "", input);
      }),
      button("recheck", "Vérifier le dossier", () => refresh($, "review")));
    controls.push(button("details", state.details ? "Revenir à la synthèse" : "Voir les détails", () => {
      state.details = !state.details; state.page = 0; redraw();
    }));
    const inputs = state.tab === "review" ? [
      Input({ key: "base", label: "Base Git (vide = HEAD)", value: state.base, placeholder: "HEAD", onInput: (value) => { state.base = value; redraw(); }, onSubmit: (value) => { state.base = value; redraw(); } }),
      Input({ key: "excerpt", label: "Extrait facultatif", value: state.excerpt, placeholder: "src/fichier.ts:20-45", onInput: (value) => { state.excerpt = value; redraw(); }, onSubmit: (value) => { state.excerpt = value; redraw(); } }),
    ] : [];
    return Box({ flexDirection: "column", children: [
      Text({ bold: true, children: ["Établi · " + TABS.find((tab) => tab[0] === state.tab)?.[1]
        + (project && project.toLowerCase() !== "etabli" ? " · " + project : !project ? " · Projet inconnu" : "")] }),
      Text({ color: state.stale ? "warning" : undefined, children: [state.busy ? "Lecture en cours…"
        : `Capture : ${captureTime(state.snapshot?.captured_at)} ; fraîcheur ${!state.snapshot ? "inconnue" : state.stale ? "à recontrôler" : "vérifiée uniquement à la capture"}`] }),
      ...[navigation.slice(0, 4), navigation.slice(4)].map((children) => Box({ flexDirection: "row", flexWrap: "wrap", columnGap: 2, children })),
      Text({ children: [" "] }),
      Text({ bold: true, color: overview.color, children: [overview.title + (state.details ? " · détails" : "")] }),
      ...(state.error ? [Text({ color: "error", children: [`Erreur : ${state.error}`] }),
        Text({ children: ["Réessayer avec Actualiser (r) ; les anciennes données restent à recontrôler."] })] : []),
      ...page.lines.map((line, index) => Text({ key: `line-${index}`,
        bold: !state.details && (line.startsWith("Prochaine action :") || ["Déjà effectué", "À terminer"].includes(line)),
        children: [line || " "] })),
      ...inputs,
      Box({ flexDirection: "row", flexWrap: "wrap", columnGap: 1, children: controls }),
      ...(page.pages > 1 ? [Box({ flexDirection: "row", columnGap: 2, children: [
        button("prev", "Précédent", () => { state.page = Math.max(0, page.page - 1); redraw(); }),
        Text({ children: [`Page ${page.page + 1}/${page.pages}`] }),
        button("next", "Suivant", () => { state.page = Math.min(page.pages - 1, page.page + 1); redraw(); }),
      ] })] : []),
    ] });
  });
}
