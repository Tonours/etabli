import { expect, test } from "claude-code/testing";

const PANE = {
  plugin: "etabli", component: "Pane", requestId: "etabli",
  viewport: { columns: 120, rows: 40 },
  props: { title: "Etabli", isFocused: true, bodyColumns: 80, placement: "inline", scroll: { offset: 0, bodyRows: 30 }, view: {} },
} as const;

test("an unavailable bridge produces a diagnostic and no model context", async ($, on) => {
  on("session.id", () => ({ value: "session" }));
  on("session.cwd", () => ({ value: "/work" }));
  on("ui.open", () => ({ value: { isPlaced: true } }));
  on("process.run", () => ({ value: { exitCode: 1, stdout: '{"error":"missing source bridge"}', stderr: "", isStdoutTruncated: false, isStderrTruncated: false } }));
  const result = await $.command.run({ command: "etabli", args: "", origin: { kind: "composer" }, presentation: { isFullscreen: false, columns: 120 } });
  expect(result.context).toBeUndefined();
  const ui = await $.ui.mount({ ...PANE, surface: "terminal" });
  expect(await ui.find({ type: "Text", text: /missing source bridge/ })).toBeDefined();
  expect(await ui.find({ key: "usage" })).toBeDefined();
  expect(await ui.find({ key: "checkpoints" })).toBeDefined();
  await ui.press({ key: "usage" });
  expect(await ui.find({ type: "Text", text: /Cache lu : inconnu/ })).toBeDefined();
});

test("unknown context and cache render on terminal and desktop without assuming zero", async ($, on) => {
  on("session.id", () => ({ value: "session" }));
  on("session.cwd", () => ({ value: "/work" }));
  for (const surface of ["terminal", "desktop"] as const) {
    const ui = await $.ui.mount({ ...PANE, surface });
    await ui.press({ key: "usage" });
    expect(await ui.find({ type: "Text", text: /Contexte : inconnu/ })).toBeDefined();
    expect(await ui.find({ type: "Text", text: /Cache lu : inconnu/ })).toBeDefined();
    await ui.unmount();
  }
});

test("native command matcher resets review for clear and resume", async ($, on) => {
  on("command.run", { command: ["clear", "resume"] }, () => ({ text: "fixture core command" }));
  on("session.id", () => ({ value: "same-session" }));
  on("session.cwd", () => ({ value: "/work" }));
  on("ui.open", () => ({ value: { isPlaced: true } }));
  on("process.run", (_, { argv }) => ({ value: {
    exitCode: 0, stderr: "", isStdoutTruncated: false, isStderrTruncated: false,
    stdout: JSON.stringify(argv[2] === "review" ? {
      state: "captured", complete: true, authority: "raw_evidence_only", captured_at: "fixture", freshness: "capture only",
      identity: { root: "/work", run: "run", base_sha: "base", head_sha: "head", snapshot_sha256: "original", files: [], excerpts: [] },
      invalidated_files: [], invalidation_reasons: [], patch: "", patch_bytes: 0, patch_sha256: "patch", excerpts: [], proofs: [],
    } : { root: "/work", selection: { run: "run" }, journal: { page: 0 } }),
  } }));
  const command = (name: string, args = "") => $.command.run({ command: name, args, origin: { kind: "composer" }, presentation: { isFullscreen: false, columns: 120 } });
  for (const name of ["clear", "resume"]) {
    await command("etabli", "review");
    const ui = await $.ui.mount({ ...PANE, surface: "terminal" });
    await ui.press({ key: "capture" });
    expect(await ui.find({ type: "Text", text: /Dossier capturé/ })).toBeDefined();
    await command(name);
    await command("etabli", "review");
    expect(await ui.find({ type: "Text", text: /Aucun dossier capturé/ })).toBeDefined();
    await ui.unmount();
  }
});

test("native narrow pane starts with a summary and reveals full source details on demand", async ($, on) => {
  on("session.id", () => ({ value: "ux-session" }));
  on("session.cwd", () => ({ value: "/work" }));
  on("ui.open", () => ({ value: { isPlaced: true } }));
  on("process.run", () => ({ value: { exitCode: 0, stderr: "", isStdoutTruncated: false, isStderrTruncated: false,
    stdout: JSON.stringify({ root: "/work", captured_at: "2026-10-02T10:00:00Z",
      selection: { run: "ux", valid: true, source: ".workflow/ux/events.jsonl" },
      resume: { objective: "Réduire la lecture", next_action: "Relire le diff", done: ["Synthèse ajoutée"], pending: ["Vérifier le rendu"], git: {} },
      journal: { page: 0 }, routing: {}, skills: { items: [] } }),
  } }));
  await $.command.run({ command: "etabli", args: "", origin: { kind: "composer" }, presentation: { isFullscreen: false, columns: 80 } });
  const ui = await $.ui.mount({ ...PANE, surface: "terminal", props: { ...PANE.props, bodyColumns: 68, scroll: { offset: 0, bodyRows: 8 } } });
  expect(await ui.find({ type: "Text", text: /Travail en cours/ })).toBeDefined();
  expect(await ui.find({ type: "Text", text: /Prochaine action : Relire le diff/ })).toBeDefined();
  expect(await ui.find({ type: "Text", text: /Synthèse ajoutée/ })).toBeDefined();
  expect(await ui.find({ type: "Text", text: /Source :/ })).toBeUndefined();
  await ui.press({ key: "details" });
  expect(await ui.find({ type: "Text", text: /Source : .workflow\/ux\/events.jsonl/ })).toBeDefined();
  await ui.press({ key: "details" });
  expect(await ui.find({ type: "Text", text: /Prochaine action : Relire le diff/ })).toBeDefined();
  await ui.unmount();
});
