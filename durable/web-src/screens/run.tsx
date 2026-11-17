import type { FormEvent } from "react";
import { ended, describe as view } from "../../shared/runs-view.ts";
import { Button } from "@/components/ui/button";
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import type { Block } from "../activity.ts";
import { useStore } from "../use-store.ts";

const CONNECTION = { "": "", connecting: "Connecting to live stream…", connected: "Live stream connected", reconnecting: "Stream disconnected. Reconnecting…" } as const;

function blockText(block: Block): string {
  return block.parts.map((part) => part.kind === "text" ? `${part.who}\n${part.text}` : part.kind === "tool" ? `${part.name} ${part.body}` : `${part.name}\n${part.text}`).join("\n\n");
}

export function RunView() {
  const [state, store] = useStore();
  const run = store.selectedRun();
  if (!run) return null;
  const over = ended(run);
  const submit = (event: FormEvent) => { event.preventDefault(); void store.steer(); };
  const { activity } = state;
  return (
    <section className="run" aria-label="Selected run">
      <div className="section-heading"><h2>{run.repo}</h2><span>{view(run, Date.now()).label}</span></div>
      <p className="prompt">{run.prompt}</p>
      <p role="status">{CONNECTION[state.connection]}</p>
      <div className="stream" tabIndex={0} aria-label="Live run stream">
        {activity.omitted && <p className="muted">Earlier entries are outside this live window.</p>}
        {activity.blocks.map((block) => <pre key={block.id}>{block.gap ? "Earlier activity not shown" : blockText(block)}</pre>)}
        {activity.live && <pre>{blockText(activity.live)}</pre>}
        {!activity.blocks.length && !activity.live && <p className="muted">Waiting for run output…</p>}
      </div>
      <Collapsible open={state.panel === "plan"} onOpenChange={(open) => store.setPanel(open ? "plan" : "overview")}>
        <CollapsibleTrigger asChild><Button variant="ghost">Run plan</Button></CollapsibleTrigger>
        <CollapsibleContent>
          <pre tabIndex={0}>{state.plan?.enabled ? [`Status: ${state.plan.status}`, ...Object.entries(state.plan.sections).map(([name, content]) => `${name}\n${content}`)].join("\n\n") : "This run has no plan yet."}</pre>
        </CollapsibleContent>
      </Collapsible>
      {!over && (
        <form onSubmit={submit} className="stack">
          <Label htmlFor="instruction">Send an instruction</Label>
          <Textarea id="instruction" required maxLength={64000} rows={3} value={state.draft} onChange={(event) => store.setDraft(event.target.value)} />
          <Button type="submit" disabled={state.send.status === "sending"}>Send instruction</Button>
          {state.send.status === "queued" && <p role="status">Instruction sent.</p>}
          {state.send.status === "failed" && <p role="alert" className="error-text">{state.send.error}</p>}
        </form>
      )}
      {!over && !state.abort.open && <Button variant="destructive" onClick={() => store.openAbort(true)}>Abort run</Button>}
      {!over && state.abort.open && (
        <div className="stack">
          <p>Abort this run and stop its active work?</p>
          {state.abort.error && <p role="alert" className="error-text">{state.abort.error}</p>}
          <Button variant="destructive" disabled={state.busy.includes("abort")} onClick={() => void store.confirmAbort()}>Yes, abort run</Button>
          <Button variant="outline" onClick={() => store.openAbort(false)}>Keep running</Button>
        </div>
      )}
    </section>
  );
}
