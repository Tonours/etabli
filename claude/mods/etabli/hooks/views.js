export const TABS = [
  ["resume", "Reprise"], ["routing", "Routage"], ["journal", "Journal"], ["checkpoints", "Accords"],
  ["diagnostic", "Diagnostic"], ["review", "Revue"], ["usage", "Usage"], ["skills", "Skills"],
];

const known = (value) => value === null || value === undefined ? "inconnu" : String(value);
const list = (items) => items?.length ? items.join(" ; ") : "aucun enregistrement";
function clipLine(line, suffix = "…") {
  const characters = Array.from(line);
  return characters.length > 200 ? characters.slice(0, 200).join("") + suffix : line;
}
const detailLine = (detail) => clipLine(JSON.stringify(detail), "… [détail tronqué ; consulter le journal]");

export function usageLines(usage, turn) {
  const context = usage?.context;
  const tokens = turn?.usage;
  return [
    "Source : $.session.usage / session.measure ; fenêtre actuelle, aucun comptage payant.",
    `Contexte : ${known(context?.tokens)} / ${known(context?.window)} tokens ; ${known(context?.percent)} %`,
    `Coût déclaré par Claude : ${known(usage?.cost?.usd)} USD (aucune estimation ajoutée)`,
    ...(usage?.rateLimits?.length ? usage.rateLimits.map((limit) => `${limit.kind} : ${known(limit.percentUsed)} % utilisés ; reset ${known(limit.resetsAt)}`) : ["Limites du compte : inconnues / aucune mesure disponible"]),
    `Dernier tour principal : ${known(turn?.turnId)} ; modèle ${known(tokens?.model)}`,
    `Entrée : ${known(tokens?.input_tokens)} ; sortie : ${known(tokens?.output_tokens)} tokens`,
    `Cache lu : ${known(tokens?.cache_read_input_tokens)} ; cache écrit : ${known(tokens?.cache_creation_input_tokens)} tokens`,
    "Les tokens du tour sont cumulés sur ses réponses ; ils ne mesurent pas la fenêtre actuelle ni un total de session.",
  ];
}

export function viewLines(state) {
  const snapshot = state.snapshot;
  if (state.tab === "usage") return usageLines(state.usage, state.turn);
  if (!snapshot) return ["Aucune projection disponible. Actualiser pour lire les sources."];
  const selection = snapshot.selection;
  const resume = snapshot.resume;
  if (state.tab === "resume") return [
    `Run : ${known(selection.run)} ; ${selection.historical ? "sélection historique explicite" : "sélection active"}`,
    `Source : ${known(selection.source)} ; validité ${selection.valid ? "vérifiée à la capture" : "indisponible"}`,
    ...(selection.reason ? [`Diagnostic : ${selection.reason}`] : []),
    ...(snapshot.resume_error ? [`Diagnostic de reprise : ${snapshot.resume_error}`] : []),
    `Objectif (PLAN.md courant) : ${known(resume?.objective)}`,
    ...(selection.historical ? ["Liaison de l'objectif du plan courant à ce run historique : non attestée."] : []),
    `Prochaine action : ${known(resume?.next_action)}`,
    `Blocage : ${resume ? resume.blocker || "aucun enregistré" : "inconnu"}`,
    `Déjà effectué : ${list(resume?.done)}`,
    `En attente : ${list(resume?.pending)}`,
    `État : ${known(resume?.state)} ; terminal ${known(selection.terminal)}`,
    `Branche : ${known(resume?.git?.branch)} ; HEAD ${known(resume?.git?.head)}`,
    `Ne pas refaire : ${list(resume?.do_not_redo)}`,
  ];
  if (state.tab === "routing") {
    const route = snapshot.routing;
    return [
      `Route enregistrée : ${known(route.route)}`,
      `Raison : ${known(route.reason)}`,
      `Source : ${known(route.source)} ; ${known(route.ts)}`,
      `Contrat : ${known(route.contract?.path)}`,
      `SHA256 actuel : ${known(route.contract?.sha256)}`,
      `SHA256 enregistré : ${known(route.contract?.recorded_sha256)}`,
      `Contrat modifié depuis la décision : ${known(route.contract?.changed)}`,
      ...(route.contract?.error ? [`Contrat indisponible : ${route.contract.error}`] : []),
      "Projection de la décision du journal ; aucune nouvelle route ni réécriture du prompt.",
    ];
  }
  if (state.tab === "journal") return [
    `${snapshot.journal.total} événements ; page ${snapshot.journal.page + 1}/${snapshot.journal.pages} ; ordre chronologique`,
    `Source : ${known(snapshot.journal.source)}`,
    ...snapshot.journal.items.flatMap((event) => [`#${event.sequence} ${known(event.ts)} — ${event.event}`, detailLine(event.detail)]),
    ...(snapshot.journal.total ? [] : [selection.reason || "Aucun journal actif validé"]),
  ];
  if (state.tab === "checkpoints") return [
    "Historique du journal. Une demande ne vaut pas décision ; aucune permission Claude n'est accordée ici.",
    ...snapshot.checkpoints.flatMap((checkpoint) => [
      `#${checkpoint.sequence} ${checkpoint.ts} — ${checkpoint.state} (${known(checkpoint.decision)})`,
      `${known(checkpoint.category)} / ${known(checkpoint.target)} ; ${known(checkpoint.consent_class)}`,
      `Demande liée : ${known(checkpoint.request_sequence)}${checkpoint.orphan_decision ? " ; décision sans demande liée" : ""}`,
    ]),
    ...(snapshot.checkpoints.length ? [] : ["Aucun checkpoint enregistré"]),
  ];
  if (state.tab === "diagnostic") {
    const diagnostic = state.diagnostic;
    if (!diagnostic) return ["Choisir Préconditions ou Clôture prospective pour lancer un diagnostic."];
    return [
      `Diagnostic : ${known(diagnostic.mode)} ; prêt ${known(diagnostic.ready)}`,
      `Capture du diagnostic : ${known(diagnostic.captured_at)} ; fraîcheur ${state.diagnosticStale ? "à recontrôler" : "vérifiée au dernier diagnostic"}`,
      `Projet : ${known(diagnostic.project_root)} ; run ${known(diagnostic.run)} ; source du diagnostic ${known(diagnostic.root || diagnostic.scope)}`,
      ...((diagnostic.checks || []).flatMap((check) => [`${check.name} : ${check.status}`, ...(check.status === "missing" ? [check.remediation] : [])])),
      ...(diagnostic.error ? [diagnostic.error, diagnostic.remediation || "Corriger les preuves ou la sélection du run puis relancer."] : []),
      ...(diagnostic.mode === "close" || diagnostic.scope ? ["Clôture prospective uniquement : aucun run clôturé, archive/hash/cleanup non vérifiés."] : []),
      ...(diagnostic.note ? [diagnostic.note] : []),
    ];
  }
  if (state.tab === "review") {
    const dossier = state.review;
    if (!dossier) return [state.reviewNotice || "Capturer explicitement le diff et des extraits pour créer un dossier en mémoire."];
    const patchLines = dossier.patch.split("\n");
    const visiblePatch = patchLines.slice(0, 40).map((line) => clipLine(line));
    const displayLimited = patchLines.length > 40 || patchLines.some((line) => Array.from(line).length > 200);
    return [
      `Dossier : ${dossier.state} ; lisibilité complète ${dossier.complete} ; ${dossier.authority}`,
      ...(state.reviewNotice ? [state.reviewNotice] : []),
      `Fraîcheur du dossier : ${state.reviewStale ? "à recontrôler" : "vérifiée au dernier contrôle du dossier"}`,
      `Capture : ${dossier.captured_at} ; ${dossier.freshness}`,
      `Base : ${dossier.identity.base_sha} ; HEAD : ${dossier.identity.head_sha}`,
      `Référence demandée : ${known(state.reviewBase)} ; SHA initial ${known(state.reviewBaseline?.base_sha)}`,
      `Projet : ${dossier.identity.root} ; run ${known(dossier.identity.run)}`,
      `Snapshot SHA256 : ${dossier.identity.snapshot_sha256}`,
      `Capture de référence SHA256 : ${known(state.reviewBaseline?.snapshot_sha256)}`,
      `Journal SHA256 : ${known(dossier.identity.ledger_sha256)}`,
      `Invalidations : ${list(dossier.invalidation_reasons)} ; fichiers ${list(dossier.invalidated_files)}`,
      `Diff décodé UTF8 : ${dossier.patch_bytes} octets ; SHA256 ${dossier.patch_sha256}`,
      `Aperçu ${dossier.patch_preview_truncated ? "tronqué" : "entier"} : ${known(dossier.patch_preview_bytes ?? dossier.patch_bytes)} / ${dossier.patch_bytes} octets ; hash du diff entier.`,
      ...dossier.excerpts.flatMap((excerpt) => [`${excerpt.path}:${excerpt.start}-${excerpt.end} — fichier ${excerpt.file_sha256} ; extrait ${excerpt.excerpt_sha256}`, ...excerpt.text.split("\n").map((line) => clipLine(line, "… [extrait tronqué ; consulter le fichier]"))]),
      ...dossier.proofs.flatMap((proof) => [`Preuve #${proof.sequence} ${proof.ts} ${proof.event} — ${proof.binding}`, detailLine(proof.detail)]),
      `Affichage ${displayLimited ? "limité à 40 lignes de 200 caractères" : "entier de l'aperçu"} ; consulter le diff complet avec Git.`,
      ...visiblePatch,
      ...dossier.identity.files.map((file) => `${file.status} ${file.path} — ${known(file.sha256)}`),
    ];
  }
  if (state.tab === "skills") return [
    `Scope : shared + ${snapshot.skills.active_scope} (${snapshot.skills.scope_source})`,
    "Disponibilité du fichier et visibilité de commande sont distinctes ; aucune invocation automatique.",
    ...snapshot.skills.items.flatMap((skill) => {
      const command = state.commands?.find((command) => command.name === skill.name);
      return [
        `${skill.name} — ${skill.source}/${skill.scope} ; source ${skill.available ? "disponible" : "indisponible"} ; scope ${skill.scope_active ? "actif" : "inactif"}${skill.opt_in ? " ; opt-in" : ""}`,
        `${skill.path} ; invocation modèle ${known(skill.model_invocation)} ; utilisateur ${known(skill.user_invocable)}`,
        `Commande : ${state.commands === null ? "inconnue" : command ? `/${command.name} visible (${command.source}) ; identité du fichier non attestée` : "absente du catalogue natif"}`,
        `Override natif : ${known(state.overrides?.[skill.name])} ; condition : ${skill.invocation_condition || skill.error}`,
      ];
    }),
  ];
  return ["Vue inconnue"];
}

export function pageLines(lines, page, size = 14) {
  const pages = Math.max(1, Math.ceil(lines.length / size));
  const current = Math.min(Math.max(0, page), pages - 1);
  return { page: current, pages, lines: lines.slice(current * size, (current + 1) * size) };
}

export function newState(identity = "") {
  return { identity, generation: 0, tab: "resume", page: 0, details: false, journalPage: 0, run: "", snapshot: null,
    diagnostic: null, diagnosticStale: true, review: null, reviewBaseline: null, reviewExcerpt: "", reviewBase: "", reviewNotice: "", reviewPending: 0, reviewStale: true,
    usage: null, lastUsageWrite: 0, turn: null, lastParentWrite: 0, commands: null, overrides: null,
    error: null, busy: false, stale: false, base: "HEAD", excerpt: "" };
}
