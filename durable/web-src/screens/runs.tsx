import { describe as view } from "../../shared/runs-view.ts";
import { Button } from "@/components/ui/button";
import { useStore } from "../use-store.ts";
import { RunView } from "./run.tsx";

export function Runs() {
  const [state, store] = useStore();
  const now = Date.now();
  return (
    <section aria-labelledby="runs-title">
      <div className="section-heading"><h1 id="runs-title">Runs</h1><Button variant="outline" disabled={state.busy.includes("refresh")} onClick={() => void store.refresh()}>Refresh runs</Button></div>
      <p className="muted">Open a run to watch its progress or change direction.</p>
      <div className="run-layout">
        <ol className="run-list" aria-label="Runs">
          {state.runs?.length === 0 && <li>No runs yet. Submit a task from the CLI to get started.</li>}
          {[...state.runs ?? []].reverse().map((run) => (
            <li key={run.id}>
              <a className="run-link" href={`#${run.id}`} aria-current={run.id === state.selected ? "true" : undefined}>
                <strong>{run.repo}</strong>
                <small>{view(run, now).label} · {new Date(run.createdAt).toLocaleString()}</small>
              </a>
            </li>
          ))}
        </ol>
        {state.selected && <RunView />}
      </div>
    </section>
  );
}
