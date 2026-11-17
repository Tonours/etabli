import { TriangleAlert } from "lucide-react";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Login } from "./screens/login.tsx";
import { RunList } from "./screens/run-list.tsx";
import { RunView } from "./screens/run-view.tsx";
import { Schedules } from "./screens/schedules.tsx";
import { Settings } from "./screens/settings.tsx";
import { useStore } from "./use-store.ts";

function Runs() {
  const [, store] = useStore();
  const run = store.selectedRun();
  return (
    <div className="runs-layout">
      <div className="list-pane">
        <div className="list-actions"><RefreshButton /></div>
        <RunList />
      </div>
      {run ? <RunView key={run.id} run={run} /> : <section className="detail-placeholder"><h2>Select a run</h2><p className="muted">Its status and next step appear here.</p></section>}
    </div>
  );
}

function RefreshButton() {
  const [state, store] = useStore();
  return <Button variant="outline" disabled={state.busy.includes("refresh")} onClick={() => void store.refresh()}>Refresh runs</Button>;
}

export function App() {
  const [state, store] = useStore();
  const signedIn = state.session === "in";
  return (
    <div className="shell" data-open-run={signedIn && state.tab === "runs" && !!state.selected}>
      <header className="app-header">
        <a className="brand" href="#" aria-label="Etabli home">établi<span>Run control</span></a>
        {signedIn && (
          <nav aria-label="Run control">
            <Button variant={state.tab === "runs" ? "secondary" : "ghost"} aria-pressed={state.tab === "runs"} onClick={() => void store.showTab("runs")}>Runs</Button>
            <Button variant={state.tab === "schedules" ? "secondary" : "ghost"} aria-pressed={state.tab === "schedules"} onClick={() => void store.showTab("schedules")}>Schedules</Button>
          </nav>
        )}
        {signedIn && <Settings />}
        {signedIn && <Button variant="outline" disabled={state.busy.includes("logout")} onClick={() => void store.logout()}>Sign out</Button>}
      </header>
      <div role="status" aria-live="polite" className="global-message">
        {state.message && (
          <Alert variant={state.message.tone === "error" ? "destructive" : "default"} data-tone={state.message.tone}>
            {state.message.tone === "error" && <TriangleAlert aria-hidden="true" />}
            <AlertDescription>{state.message.text}</AlertDescription>
          </Alert>
        )}
      </div>
      <main className="workspace">
        {!signedIn ? <Login /> : state.tab === "runs" ? <Runs /> : <Schedules />}
      </main>
    </div>
  );
}
