const known = (value) => value === null || value === undefined ? "inconnu" : String(value);
const compact = (value, limit = 160) => {
  const text = known(value).replace(/\s+/g, " ").trim();
  const characters = Array.from(text);
  return characters.length > limit ? characters.slice(0, limit).join("") + "… (Détails)" : text;
};
const row = (label, value) => label + " : " + compact(value);
const short = (value) => value ? String(value).slice(0, 12) : "inconnu";
const result = (title, lines, color) => ({ title, lines, color });
const amount = (value) => typeof value === "number" ? value.toLocaleString("fr-FR") : known(value);
const subset = (items) => items?.length ? items.slice(0, 3).map((item) => compact(item, 100))
  .concat(items.length > 3 ? ["+" + (items.length - 3) + " autres dans Détails"] : []) : ["Aucun élément enregistré"];

export function captureTime(value) {
  if (!value) return "inconnue";
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? compact(value, 30)
    : date.toLocaleString("fr-FR", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" });
}

// Lay out readable terminal rows before paging, including wide Unicode text.
export function pageContent(lines, page, columns = 72, rows = 14) {
  const width = Math.max(20, Math.min(76, columns));
  const wrapped = lines.flatMap((line) => {
    const characters = Array.from(String(line));
    if (!characters.length) return [""];
    const output = [];
    while (characters.length) {
      let cells = 0, end = 0, space = -1;
      while (end < characters.length) {
        const character = characters[end];
        const size = /\p{Mark}/u.test(character) ? 0 : character.codePointAt(0) >= 0x2e80 ? 2 : 1;
        if (cells + size > width) break;
        cells += size;
        if (/\s/.test(character)) space = end;
        end += 1;
      }
      const cut = end < characters.length && space > 0 ? space + 1 : end;
      output.push(characters.splice(0, cut).join("").trimEnd());
    }
    return output;
  });
  const size = Math.max(4, rows);
  const pages = Math.max(1, Math.ceil(wrapped.length / size));
  const current = Math.min(Math.max(0, page), pages - 1);
  return { page: current, pages, lines: wrapped.slice(current * size, (current + 1) * size) };
}

const EVENT_NAMES = {
  route_decided: "Routage choisi", plan_created: "Plan préparé", file_changed: "Fichier modifié",
  validation_run: "Vérification", validation_failed: "Vérification échouée",
  review_completed: "Revue", adversary_completed: "Revue contradictoire",
  simplification_completed: "Simplification", quality_completed: "Qualité",
  human_checkpoint: "Décision humaine", handoff: "Reprise préparée",
  archive_written: "Plan archivé", plan_removed: "Plan courant retiré",
  completed: "Travail terminé", blocked: "Travail bloqué", correction: "Correction",
  retry_classified: "Nouvelle tentative", no_progress: "Sans progrès", ship_completed: "Publication",
};
const DECISIONS = { requested: "Demandé", granted: "Accord enregistré", refused: "Refus enregistré", unknown: "Décision inconnue" };
const VERDICTS = { GO: "validé", "GO WITH NOTES": "validé avec réserves", BLOCK: "bloqué", READY: "prêt", CHALLENGED: "à corriger" };
const EVENT_STATUS = { pass: "réussi", clean: "aucun point à corriger", unavailable: "indisponible",
  requested: "demande enregistrée", pending: "demande enregistrée", granted: "accord enregistré", approved: "accord enregistré",
  allowed: "accord enregistré", denied: "refus enregistré", rejected: "refus enregistré", refused: "refus enregistré", revoked: "refus enregistré" };
const CHANGED_FIELDS = { root: "Le projet a changé.", run: "Le workflow sélectionné a changé.",
  base_sha: "La base Git a changé.", head_sha: "La révision HEAD a changé.",
  snapshot_sha256: "Le contenu ne correspond plus à la capture de référence.",
  ledger_sha256: "Le journal du workflow a changé." };

function explainCondition(message) {
  const changed = typeof message === "string" && message.match(/^(\w+) changed$/);
  if (changed && Object.hasOwn(CHANGED_FIELDS, changed[1])) return CHANGED_FIELDS[changed[1]];
  const missing = typeof message === "string" && message.match(/^profile [a-z-]+ missing (\w+)$/);
  return missing && Object.hasOwn(EVENT_NAMES, missing[1]) ? "Étape manquante : " + EVENT_NAMES[missing[1]] + "." : message;
}

export function eventSummary(event) {
  const detail = event.detail || {};
  const status = typeof detail.exit === "number" ? (detail.exit === 0 ? "réussi" : "échec (" + detail.exit + ")")
    : VERDICTS[detail.verdict || detail.status] || EVENT_STATUS[detail.status || detail.decision] || detail.status || detail.decision || "";
  const description = detail.command || detail.summary || detail.reason || detail.evidence || detail.path || detail.next_action;
  return ["#" + event.sequence + " · " + captureTime(event.ts) + " · " + (EVENT_NAMES[event.event] || event.event) + (status ? " · " + status : ""),
    ...(description ? ["  " + compact(description)] : [])];
}

export function viewOverview(state) {
  const snapshot = state.snapshot;
  if (state.tab === "usage") {
    const usage = state.usage, context = usage?.context, tokens = state.turn?.usage;
    return result(usage || tokens ? "Mesures observées par Claude" : "Aucune mesure disponible", [
      row("Contexte", amount(context?.tokens) + " / " + amount(context?.window) + " tokens · " + known(context?.percent) + " %"),
      row("Coût déclaré par Claude", known(usage?.cost?.usd) + " USD"),
      ...(usage?.rateLimits?.length ? usage.rateLimits.map((limit) => row(
        limit.kind === "five_hour" ? "Limite sur 5 h" : limit.kind === "seven_day" ? "Limite hebdomadaire" : limit.kind,
        known(limit.percentUsed) + " % utilisés · remise à zéro " + captureTime(limit.resetsAt)))
        : ["Limites du compte : inconnues"]),
      "",
      "Dernier tour principal · modèle " + known(tokens?.model),
      row("Entrée / sortie", amount(tokens?.input_tokens) + " / " + amount(tokens?.output_tokens) + " tokens"),
      row("Cache lu", amount(tokens?.cache_read_input_tokens) + " tokens"),
      row("Cache écrit", amount(tokens?.cache_creation_input_tokens) + " tokens"),
      "Cache et tokens du tour ne mesurent pas le contexte actuel.",
    ]);
  }
  if (!snapshot) return result("Lecture indisponible", ["Actualiser les sources (r) pour afficher le workflow.",
    "Les valeurs absentes restent inconnues."], "warning");
  const selection = snapshot.selection || {};
  const resume = snapshot.resume;
  if (state.tab === "resume") {
    if (!selection.valid && !resume) return result("Aucun workflow actif attesté", [
      "Aucune reprise disponible pour la sélection actuelle.",
      "Travail précédent : /etabli run NOM_DU_RUN.",
      "Voir Détails pour contrôler la sélection et ses sources.",
      "Usage et Skills restent consultables.",
    ], "warning");
    const title = selection.terminal === "completed" ? "Travail terminé"
      : selection.terminal === "blocked" || resume?.blocker ? "Travail bloqué"
        : selection.terminal ? "État terminal : " + selection.terminal
          : selection.valid ? "Travail en cours" : "Aucun workflow actif attesté";
    return result(title, [
      ...(selection.reason ? ["À vérifier : sélection du workflow indisponible, voir Détails.",
        "Choisir un run avec /etabli run SLUG, puis actualiser."] : []),
      ...(snapshot.resume_error ? ["Reprise canonique indisponible ; consulter le diagnostic dans Détails."] : []),
      ...(selection.historical ? ["Historique consulté ; objectif du plan courant non lié à ce run."] : []),
      row("Prochaine action", resume?.next_action),
      row("Blocage", resume ? resume.blocker || "aucun enregistré" : "inconnu"),
      row("Objectif du plan courant", resume?.objective),
      "",
      "Déjà effectué", ...subset(resume?.done),
      "À terminer", ...subset(resume?.pending),
    ], resume?.blocker || selection.terminal === "blocked" ? "error" : !selection.valid ? "warning" : undefined);
  }
  if (state.tab === "routing") {
    const route = snapshot.routing || {}, contract = route.contract;
    const names = { answer: "Réponse / modification ciblée", implement: "Implémentation",
      "plan-implement": "Plan puis implémentation", "plan-loop": "Préparation du plan", review: "Revue",
      verify: "Vérification", "ops-stop": "Décision humaine requise" };
    return result(route.route ? names[route.route] || route.route : "Aucun routage enregistré", [
      row("Raison", route.route ? route.reason : "Aucune décision de routage dans le journal."),
      row("Contrat applicable", contract?.path),
      contract?.error ? row("Contrat indisponible", contract.error)
        : contract?.changed === true ? "Attention : contrat modifié depuis la décision."
          : contract?.changed === false ? "Contrat inchangé depuis la décision."
            : "Comparaison du contrat : inconnue, hash enregistré absent.",
      row("Décision enregistrée", captureTime(route.ts)),
      "Cette vue explique le choix enregistré dans le journal.",
    ], contract?.changed || contract?.error ? "warning" : undefined);
  }
  if (state.tab === "journal") {
    const journal = snapshot.journal || {};
    return result(known(journal.total) + " événements enregistrés", [
      "Chronologie · lot " + ((journal.page || 0) + 1) + "/" + (journal.pages || 1),
      ...(journal.items || []).flatMap(eventSummary),
      ...(!journal.total ? [selection.reason || "Aucun journal disponible pour ce run."] : []),
    ]);
  }
  if (state.tab === "checkpoints") {
    const checkpoints = snapshot.checkpoints || [];
    return result(checkpoints.length ? "Demandes et décisions enregistrées" : "Aucune décision enregistrée", [
      "Historique uniquement ; aucune permission actuelle accordée ici.",
      ...checkpoints.flatMap((item) => [
        "#" + item.sequence + " · " + (DECISIONS[item.state] || DECISIONS.unknown) + " · " + compact(item.target || item.category),
        "  " + captureTime(item.ts) + " · " + compact(item.category) + (item.request_sequence ? " · demande #" + item.request_sequence : ""),
        ...(item.orphan_decision ? ["  Attention : décision sans demande liée."] : []),
      ]),
    ]);
  }
  if (state.tab === "diagnostic") {
    const diagnostic = state.diagnostic;
    if (!diagnostic) return result("Vérification à lancer", ["Vérifier les préconditions (p) : outils et preuves nécessaires.",
      "Tester la clôture (c) : vérifier la chaîne d'événements.",
      "Ce test ne clôture pas le run et ne vérifie pas l'archive réelle."]);
    const missing = (diagnostic.checks || []).filter((check) => check.status === "missing");
    const title = state.diagnosticStale ? "Résultat à recontrôler"
      : missing.length ? "Préconditions manquantes"
      : diagnostic.ready === true ? "Préconditions du contrôle remplies"
        : diagnostic.ready === false ? "Préconditions manquantes" : "Résultat inconnu";
    return result(title, [
      row("Contrôle", diagnostic.mode === "close" ? "Clôture prospective" : "Préconditions"),
      row("Dernier contrôle", captureTime(diagnostic.captured_at)),
      ...(diagnostic.error ? [row("À résoudre", explainCondition(diagnostic.error))] : []),
      ...(diagnostic.remediation ? [row("Action", explainCondition(diagnostic.error) !== diagnostic.error
        ? "Compléter cette étape et ses preuves. Commandes exactes dans Détails, puis retester la clôture (c)."
        : diagnostic.remediation)] : []),
      ...missing.flatMap((check) => [row("Manquant", check.name), row("Action", check.remediation)]),
      ...(!missing.length && !diagnostic.error ? ["Aucun élément manquant signalé par ce contrôle."] : []),
      ...(diagnostic.mode === "close" || diagnostic.scope ? ["Contrôle prospectif ; archive et nettoyage non vérifiés."] : []),
    ], state.diagnosticStale || diagnostic.ready !== true ? "warning" : undefined);
  }
  if (state.tab === "review") {
    const dossier = state.review;
    if (!dossier) return result("Aucun dossier capturé", [
      ...(state.reviewNotice ? [compact(state.reviewNotice)] : []),
      "Capturer le diff (g) pour réunir les preuves de cette révision.",
      "Base vide : HEAD. L'extrait de fichier est facultatif.",
    ]);
    const invalid = dossier.state === "invalidated";
    return result(invalid ? "Dossier invalidé" : dossier.complete === false ? "Dossier incomplet"
      : state.reviewStale ? "Dossier à recontrôler" : "Dossier capturé", [
      ...(state.reviewNotice ? [compact(state.reviewNotice)] : []),
      row("Fraîcheur du dossier", state.reviewStale ? "à recontrôler (v)" : "vérifiée au dernier contrôle"),
      row("Lecture des fichiers", dossier.complete === true ? "complète" : dossier.complete === false ? "incomplète" : "inconnue"),
      ...(dossier.invalidation_reasons || []).map((reason) => row("Invalidation", explainCondition(reason))),
      ...(dossier.invalidated_files?.length ? [row("Fichiers invalidés", dossier.invalidated_files.join(", "))] : []),
      row("Révision", short(dossier.identity?.base_sha) + " → " + short(dossier.identity?.head_sha)),
      row("Diff", amount(dossier.patch_bytes) + " octets · " + (dossier.patch_preview_truncated ? "aperçu tronqué, hash du diff entier conservé" : "aperçu disponible")),
      row("Extraits / preuves", (dossier.excerpts?.length || 0) + " / " + (dossier.proofs?.length || 0)),
      ...(dossier.proofs?.some((proof) => !proof.revision) ? ["Attention : preuves du journal sans révision attestée."] : []),
      invalid ? "Capturer à nouveau (g) pour établir une nouvelle référence." : "Détails (d) : diff, extraits, preuves et hashes.",
      "Preuves brutes ; aucun verdict de revue.",
    ], invalid ? "error" : state.reviewStale || dossier.complete !== true ? "warning" : undefined);
  }
  if (state.tab === "skills") {
    const skills = snapshot.skills || {}, items = skills.items || [];
    const scoped = items.filter((skill) => skill.scope_active !== false);
    const overrides = { on: "activé", off: "désactivé", "name-only": "nom uniquement", "user-invocable-only": "invocation utilisateur uniquement" };
    return result(scoped.length + " skills dans ce périmètre", [
      row("Périmètre", "shared + " + known(skills.active_scope)),
      "Fichier disponible, commande visible et invocation sont distincts.",
      ...(scoped.length < items.length ? [(items.length - scoped.length) + " hors périmètre, accessibles dans Détails."] : []),
      ...scoped.flatMap((skill) => {
        const command = state.commands?.find((item) => item.name === skill.name);
        const override = state.overrides?.[skill.name];
        return [skill.name + " · " + (skill.available === false ? "source indisponible" : skill.available === true ? "source disponible" : "source inconnue")
          + " · " + skill.source + "/" + skill.scope + (override ? " · " + overrides[override] : "")
          + (skill.scope_active === undefined ? " · périmètre inconnu" : ""),
          "  " + compact(skill.invocation_condition || skill.error || "Condition inconnue", 130),
          "  Commande : " + (state.commands === null ? "inconnue" : command ? "/" + command.name + " visible, fichier non attesté" : "absente du catalogue Claude")];
      }),
    ]);
  }
  return result("Vue inconnue", ["Choisir une vue avec les touches 1 à 8."]);
}
