import type { FormEvent } from "react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { useStore } from "../use-store.ts";

export function Schedules() {
  const [state, store] = useStore();
  const submit = (event: FormEvent) => { event.preventDefault(); void store.createSchedule(); };
  return (
    <section className="schedules" aria-labelledby="schedules-title">
      <h1 id="schedules-title">Schedules</h1>
      <p className="muted">Schedules use UTC, at minute resolution. Missed times coalesce into one recoverable overdue run; they do not produce a backlog.</p>
      <ol className="schedule-list" aria-label="Schedules">
        {state.schedules?.length === 0 && <li>No scheduled tasks. Choose a repository and UTC time below.</li>}
        {state.schedules?.map((row) => (
          <li key={row.id}>
            <strong>{row.repo}</strong>
            <p className="muted">{row.cron} UTC · Next: {new Date(row.nextDue).toISOString()}</p>
            <p className="prompt">{row.prompt}</p>
            <Button variant="outline" disabled={state.deleting.includes(row.id)} onClick={() => void store.deleteSchedule(row.id)}>Delete schedule</Button>
          </li>
        ))}
      </ol>
      <form onSubmit={submit} className="stack">
        <h2>Schedule a task</h2>
        <Label htmlFor="repo">Repository</Label>
        <input id="repo" className="field" required placeholder="owner/repository" autoComplete="off" value={state.form.repo} onChange={(event) => store.setForm({ repo: event.target.value })} />
        <Label htmlFor="prompt">Task</Label>
        <Textarea id="prompt" required rows={3} maxLength={64000} value={state.form.prompt} onChange={(event) => store.setForm({ prompt: event.target.value })} />
        <Label htmlFor="cron">Cron expression (UTC)</Label>
        <input id="cron" className="field" required placeholder="0 9 * * 1-5" aria-describedby="cron-help" value={state.form.cron} onChange={(event) => store.setForm({ cron: event.target.value })} />
        <p id="cron-help" className="muted">Minute, hour, day of month, month, day of week. Numbers, *, lists, ranges and steps; when both day fields are restricted, either can match.</p>
        <Button type="submit" disabled={state.busy.includes("schedule")}>Create schedule</Button>
      </form>
    </section>
  );
}
