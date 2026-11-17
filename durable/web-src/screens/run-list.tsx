import { useLayoutEffect, useRef } from "react";
import { ChevronRight, ExternalLink } from "lucide-react";
import { Separator } from "@/components/ui/separator";
import { Skeleton } from "@/components/ui/skeleton";
import { age, describe, GROUPS, order, pullRequest, since, summary, title } from "../../shared/runs-view.ts";
import { useStore } from "../use-store.ts";
import { Status } from "./status.tsx";

export function RunList() {
  const [state] = useStore();
  const focused = useRef("");
  const list = useRef<HTMLElement>(null);
  useLayoutEffect(() => {
    const active = document.activeElement;
    if (!focused.current || (active && active !== document.body)) return;
    list.current?.querySelector<HTMLAnchorElement>(`a.run-link[data-run="${focused.current}"]`)?.focus();
  });
  if (!state.runs) {
    return (
      <section className="run-list" aria-label="All runs" aria-busy="true">
        <div className="list-head"><h1>Runs</h1><p role="status" className="summary">Loading runs…</p></div>
        <div className="loading" aria-hidden="true">{[1, 2, 3].map((row) => <div key={row}><Skeleton className="h-5 w-24" /><Skeleton className="mt-3 h-5 w-3/4" /><Skeleton className="mt-2 h-4 w-1/2" /></div>)}</div>
      </section>
    );
  }
  const now = Date.now();
  const { groups, counts } = order(state.runs, now);
  return (
    <section className="run-list" aria-label="All runs" ref={list}
      onFocus={(event) => { const id = (event.target as HTMLElement).dataset.run; if (id) focused.current = id; }}
      onBlur={(event) => { if (event.relatedTarget && !list.current?.contains(event.relatedTarget as Node)) focused.current = ""; }}>
      <div className="list-head"><h1>Runs</h1><p className="summary">{summary(counts)}</p></div>
      {state.runs.length === 0 && <div className="empty"><h2>No runs yet</h2><p className="muted">Start a task from the CLI. New runs will appear here.</p></div>}
      {state.runs.length > 0 && GROUPS.map(({ group, heading }) => (
        <section className="run-group" key={group} aria-labelledby={`group-${group}`}>
          <h2 id={`group-${group}`}>{heading} <span>{groups[group].length}</span></h2>
          <Separator />
          {groups[group].length === 0 ? <p className="muted group-empty">{group === "attention" ? "Nothing needs you." : "None."}</p> : (
            <ul>
              {groups[group].map((run) => {
                const view = describe(run, now), link = pullRequest(run.url), name = title(run.prompt);
                return (
                  <li key={run.id} data-selected={run.id === state.selected}>
                    <a className="run-link" data-run={run.id} href={`#${run.id}`} aria-current={run.id === state.selected ? "page" : undefined}>
                      <span className="row-title"><span>{name}</span><ChevronRight aria-hidden="true" /></span>
                      <Status view={view} />
                      <span className="meta">{run.repo} · {age(since(run), now)}</span>
                      {group === "attention" && view.hint && <span className="hint">{view.hint}</span>}
                    </a>
                    {link && <a className="pr-link" href={link} target="_blank" rel="noreferrer" aria-label={`Pull request for ${name}`}>Pull request<ExternalLink aria-hidden="true" /></a>}
                  </li>
                );
              })}
            </ul>
          )}
        </section>
      ))}
    </section>
  );
}
