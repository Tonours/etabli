import { Alert, AlertDescription } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Login } from "./screens/login.tsx";
import { Runs } from "./screens/runs.tsx";
import { Schedules } from "./screens/schedules.tsx";
import { Settings } from "./screens/settings.tsx";
import { useStore } from "./use-store.ts";

export function App() {
  const [state, store] = useStore();
  const signedIn = state.session === "in";
  return (
    <div className="shell" data-open-run={signedIn && !!state.selected}>
      <header className="app-header">
        <a className="brand" href="#" aria-label="Etabli home">établi<span>Run control</span></a>
        {signedIn && (
          <nav aria-label="Run control">
            <Button variant="ghost" aria-pressed={state.tab === "runs"} onClick={() => void store.showTab("runs")}>Runs</Button>
            <Button variant="ghost" aria-pressed={state.tab === "schedules"} onClick={() => void store.showTab("schedules")}>Schedules</Button>
          </nav>
        )}
        {signedIn && <Settings />}
        {signedIn && <Button variant="outline" disabled={state.busy.includes("logout")} onClick={() => void store.logout()}>Sign out</Button>}
      </header>
      <div role="status" aria-live="polite" className="global-message">
        {state.message && <Alert variant={state.message.tone === "error" ? "destructive" : "default"}><AlertDescription>{state.message.text}</AlertDescription></Alert>}
      </div>
      <main className="workspace">
        {!signedIn ? <Login /> : state.tab === "runs" ? <Runs /> : <Schedules />}
      </main>
    </div>
  );
}
