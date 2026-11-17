import { useEffect, useLayoutEffect, useRef, type FormEvent } from "react";
import { ArrowLeft, Check, ChevronDown, ChevronRight, ExternalLink, TriangleAlert } from "lucide-react";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible";
import { Label } from "@/components/ui/label";
import { Separator } from "@/components/ui/separator";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";
import { age, describe, ended, pullRequest, title } from "../../shared/runs-view.ts";
import { excerpt, type Block, type Part } from "../activity.ts";
import type { Run } from "../api.ts";
import type { Panel, State } from "../store.ts";
import { useStore } from "../use-store.ts";
import { Status } from "./status.tsx";

const PHASES = [["Plan", "planning"], ["Build", "implementing"], ["Review", "reviewing"], ["Publish", "publishing"]] as const;
const clock = (time: number | undefined) => time ? new Date(time).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }) : "";

function left(deadline: number, now: number): string {
  const minutes = Math.ceil((deadline - now) / 60_000);
  if (!deadline || minutes <= 0) return "";
  return minutes < 60 ? `${minutes}m left` : `${Math.floor(minutes / 60)}h ${minutes % 60}m left`;
}

function PartView({ part }: { part: Part }) {
  if (part.kind === "tool") {
    return (
      <Collapsible className="tool">
        <CollapsibleTrigger asChild><Button variant="ghost" className="tool-line"><ChevronRight aria-hidden="true" /><span>{part.name} · {part.summary}</span></Button></CollapsibleTrigger>
        <CollapsibleContent><pre>{part.body}</pre></CollapsibleContent>
      </Collapsible>
    );
  }
  if (part.kind === "result") return <div className="result"><p className="meta">{part.name}</p>{part.text && <pre>{part.text}</pre>}</div>;
  return <div className="said"><p className="meta">{part.who}</p><p className="text">{part.text}</p></div>;
}

function BlockView({ block }: { block: Block }) {
  if (block.gap) return <p className="meta gap" role="note">Some activity was missed while reconnecting.</p>;
  return <article className="activity-entry">{block.time !== undefined && <p className="meta"><time>{clock(block.time)}</time></p>}{block.parts.map((part, index) => <PartView key={index} part={part} />)}</article>;
}

function ActivityPanel({ state, over }: { state: State; over: boolean }) {
  const [, store] = useStore();
  const scroll = useRef<HTMLDivElement>(null);
  const { activity, panel } = state;
  useLayoutEffect(() => {
    const node = scroll.current;
    if (!node || panel !== "activity") return;
    node.scrollTop = activity.follow ? node.scrollHeight : activity.offset;
  }, [panel, activity.blocks, activity.live, activity.follow]);
  const onScroll = () => {
    const node = scroll.current;
    if (!node || node.clientHeight === 0 || panel !== "activity") return;
    const follow = node.scrollHeight - node.scrollTop - node.clientHeight < 40;
    if (follow !== activity.follow || !follow) store.follow(follow, node.scrollTop);
  };
  const connection = over ? "Recorded activity" : state.connection === "connected" ? (activity.follow ? "Connected · following latest activity" : "Connected · viewing earlier activity") : state.connection === "reconnecting" ? "Reconnecting…" : "Connecting…";
  const empty = !activity.blocks.length && !activity.live;
  return (
    <div className="panel-stack">
      <p className="meta" role="status">{connection}</p>
      <div className="activity-scroll" ref={scroll} role="region" tabIndex={0} aria-label="Activity history" onScroll={onScroll}>
        {activity.omitted && <p className="meta">Earlier activity not shown.</p>}
        {activity.blocks.map((block) => <BlockView key={block.id} block={block} />)}
        {activity.live && <BlockView block={activity.live} />}
        {empty && <p className="meta">{over ? "No activity was recorded for this run." : "No activity recorded yet."}</p>}
      </div>
      {!activity.follow && <Button variant="outline" onClick={() => store.follow(true, 0)}>Jump to latest</Button>}
    </div>
  );
}

function PlanPanel({ state, run }: { state: State; run: Run }) {
  const plan = state.plan;
  const sections = plan?.enabled ? Object.entries(plan.sections).filter(([, content]) => content.trim()) : [];
  return (
    <div className="panel-stack">
      <h2>Run plan</h2>
      {plan === undefined ? <p className="meta" role="status">Loading plan…</p> : !plan?.enabled ? <p className="muted">This run has no plan yet.</p> : (
        <>
          <p className="meta">Status: {plan.status}</p>
          {sections.length === 0 && <p className="muted">The plan has no content yet.</p>}
          {sections.map(([name, content]) => <section key={name} className="plan-section"><h3>{name}</h3><p className="text">{content}</p></section>)}
        </>
      )}
      <Separator />
      <h3>Full task</h3>
      <p className="text">{run.prompt}</p>
    </div>
  );
}

function InstructionsPanel({ state, field }: { state: State; field: React.RefObject<HTMLTextAreaElement | null> }) {
  const [, store] = useStore();
  const { send } = state;
  const submit = (event: FormEvent) => { event.preventDefault(); void store.steer(); };
  return (
    <form className="instruction-form" onSubmit={submit}>
      <div className="label-row">
        <Label htmlFor="instruction">Instruction</Label>
        <span className={send.status === "failed" ? "error-text" : "feedback"} role={send.status === "failed" ? "alert" : "status"}>
          {send.status === "sending" && "Sending…"}
          {send.status === "queued" && <><Check aria-hidden="true" />Instruction queued</>}
          {send.status === "failed" && `Not sent: ${send.error} Your draft is kept.`}
        </span>
      </div>
      <Textarea ref={field} id="instruction" rows={5} maxLength={64000} value={state.draft} aria-invalid={send.status === "failed" || undefined} aria-describedby="instruction-help" onChange={(event) => store.setDraft(event.target.value)} />
      <p className="meta" id="instruction-help">Read by the agent on its next turn. Your draft stays here if sending fails.</p>
      {state.activity.queued.length > 0 && (
        <Alert>
          <AlertTitle>Queued instruction</AlertTitle>
          <AlertDescription>{state.activity.queued.map((text, index) => <p key={index} className="text">{text}</p>)}<p>Waiting for the agent to read it.</p></AlertDescription>
        </Alert>
      )}
      <Button type="submit" disabled={!state.draft || send.status === "sending"}>{send.status === "failed" ? "Retry" : send.status === "sending" ? "Sending…" : "Send instruction"}</Button>
    </form>
  );
}

function Preserved({ state }: { state: State }) {
  const { send, draft } = state;
  const outcome = send.ended && send.status !== "idle";
  if (!outcome && !draft) return null;
  const heading = !outcome ? "Draft not sent" : send.status === "sending" ? "Instruction delivery pending" : send.status === "failed" ? "Instruction not delivered" : "Instruction accepted before the run ended";
  const detail = !outcome ? "This run ended before you sent this draft." : send.status === "sending" ? "The run ended while your instruction was sending." : send.status === "failed" ? send.error : "The agent may not have read it.";
  return (
    <section className="preserved">
      <Alert><AlertTitle>{heading}</AlertTitle><AlertDescription>{detail}{outcome && send.content && send.content !== draft && <p className="text">Submitted instruction: {send.content}</p>}</AlertDescription></Alert>
      {draft && <><Label htmlFor="preserved">Your draft (read-only)</Label><Textarea id="preserved" value={draft} readOnly /></>}
    </section>
  );
}

function Overview({ state, run, now, open }: { state: State; run: Run; now: number; open: (panel: Panel) => void }) {
  const view = describe(run, now), link = pullRequest(run.url), over = ended(run);
  const queued = run.status === "queued", phase = PHASES.findIndex(([, status]) => status === run.status);
  const latest = state.activity.live ?? state.activity.blocks.filter((block) => !block.gap).at(-1);
  const meta = [left(run.deadline, now), state.activity.turns ? `Turn ${state.activity.turns}${state.activity.maxTurns ? ` of ${state.activity.maxTurns}` : ""}` : ""].filter(Boolean).join(" · ");
  return (
    <div className="panel-stack">
      {queued && <section><h2>Waiting to start</h2><p className="muted">This run is in the queue.</p></section>}
      {!over && !queued && (
        <section aria-label="Current phase">
          <ol className="phases">{PHASES.map(([name], index) => <li key={name} aria-current={index === phase ? "step" : undefined}>{index > 0 && <ChevronRight aria-hidden="true" />}{name}</li>)}</ol>
          {meta && <p className="meta">{meta}</p>}
        </section>
      )}
      {over && view.hint && <Alert data-tone="alert"><TriangleAlert aria-hidden="true" /><AlertTitle>{view.label}</AlertTitle><AlertDescription>{view.hint}</AlertDescription></Alert>}
      {link && <Button variant="outline" asChild className="self-start"><a href={link} target="_blank" rel="noreferrer">Pull request<ExternalLink aria-hidden="true" /></a></Button>}
      {over && <Preserved state={state} />}
      {!queued && (
        <section className="latest" aria-labelledby="latest-title">
          <h2 id="latest-title">Latest activity</h2>
          {latest?.time !== undefined && <p className="meta"><time>{clock(latest.time)}</time></p>}
          <p className="text line-clamp-4">{latest ? excerpt(latest) : over ? "No activity was recorded for this run." : "No activity recorded yet."}</p>
          <Button variant="ghost" onClick={() => open("activity")}>View activity<ChevronRight aria-hidden="true" /></Button>
        </section>
      )}
      {!over && !queued && (
        <section className="steer-entry">
          {state.activity.queued.length === 0 && <p className="meta">No instructions queued</p>}
          <Button onClick={() => open("instructions")}>Give instruction</Button>
        </section>
      )}
    </div>
  );
}

function RunActions({ state }: { state: State }) {
  const [, store] = useStore();
  const keep = useRef<HTMLButtonElement>(null), trigger = useRef<HTMLButtonElement>(null);
  useEffect(() => { if (state.abort.open) keep.current?.focus(); }, [state.abort.open]);
  return (
    <Collapsible className="run-actions">
      <Separator />
      <CollapsibleTrigger asChild><Button variant="ghost" className="action-toggle" ref={trigger}><ChevronDown aria-hidden="true" className="chevron" />Run actions</Button></CollapsibleTrigger>
      <CollapsibleContent>
        {state.abort.open ? (
          <section className="confirmation" aria-label="Confirm abort">
            <h3>Abort this run?</h3>
            <p>The agent stops its active work.</p>
            {state.abort.error && <p role="alert" className="error-text">{state.abort.error}</p>}
            <div className="button-row">
              <Button variant="outline" ref={keep} onClick={() => { store.openAbort(false); trigger.current?.focus(); }}>Keep running</Button>
              <Button variant="destructive" disabled={state.busy.includes("abort")} onClick={() => void store.confirmAbort()}>Abort run</Button>
            </div>
          </section>
        ) : <Button variant="destructive" onClick={() => store.openAbort(true)}>Abort run</Button>}
      </CollapsibleContent>
    </Collapsible>
  );
}

export function RunView({ run }: { run: Run }) {
  const [state, store] = useStore();
  const field = useRef<HTMLTextAreaElement>(null);
  const overview = useRef<HTMLButtonElement>(null);
  const instructionsFocused = useRef(false);
  const heading = useRef<HTMLHeadingElement>(null);
  const now = Date.now(), over = ended(run), instruct = !over && run.status !== "queued";
  useLayoutEffect(() => {
    if (!instruct && instructionsFocused.current) { instructionsFocused.current = false; overview.current?.focus(); }
  }, [instruct]);
  useEffect(() => { if (window.matchMedia("(max-width: 720px)").matches) heading.current?.focus(); }, [run.id]);
  const open = (panel: Panel) => {
    store.setPanel(panel);
    requestAnimationFrame(() => { if (panel === "instructions") field.current?.focus(); });
  };
  const trackInstructions = { onFocus: () => { instructionsFocused.current = true; }, onBlur: (event: React.FocusEvent) => { if (event.relatedTarget) instructionsFocused.current = false; } };
  return (
    <section className="detail" aria-labelledby="run-title">
      <Button asChild variant="ghost" className="back min-[721px]:hidden"><a href="#"><ArrowLeft aria-hidden="true" />All runs</a></Button>
      <header className="run-head">
        <Status view={describe(run, now)} />
        <h1 id="run-title" ref={heading} tabIndex={-1}>{title(run.prompt)}</h1>
        <p className="meta">{run.repo} · {run.startedAt ? `started ${age(run.startedAt, now)} ago` : `created ${age(run.createdAt, now)} ago`}</p>
      </header>
      <Tabs value={state.panel} onValueChange={(value) => store.setPanel(value as Panel)}>
        <TabsList aria-label="Run panels" className="run-tabs">
          <TabsTrigger value="overview" ref={overview}>Overview</TabsTrigger>
          <TabsTrigger value="activity">Activity</TabsTrigger>
          <TabsTrigger value="plan">Plan</TabsTrigger>
          {instruct && <TabsTrigger value="instructions" {...trackInstructions}>Instructions</TabsTrigger>}
        </TabsList>
        {instruct && state.activity.queued.length > 0 && state.panel !== "instructions" && (
          <p className="inbox" role="status">Instruction queued · <button type="button" className="text-link" onClick={() => open("instructions")}>View</button></p>
        )}
        <TabsContent value="overview" forceMount><Overview state={state} run={run} now={now} open={open} /></TabsContent>
        <TabsContent value="activity" forceMount><ActivityPanel state={state} over={over} /></TabsContent>
        <TabsContent value="plan" forceMount><PlanPanel state={state} run={run} /></TabsContent>
        {instruct && <TabsContent value="instructions" forceMount {...trackInstructions}><InstructionsPanel state={state} field={field} /></TabsContent>}
      </Tabs>
      {!over && <RunActions state={state} />}
    </section>
  );
}
