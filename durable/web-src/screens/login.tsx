import { useState, type FormEvent } from "react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { useStore } from "../use-store.ts";

export function Login() {
  const [state, store] = useStore();
  const [token, setToken] = useState("");
  const submit = (event: FormEvent) => {
    event.preventDefault();
    const value = token;
    setToken("");
    void store.login(value);
  };
  return (
    <section className="login" aria-labelledby="login-title">
      <h1 id="login-title">Your work, in motion.</h1>
      <p className="muted">Connect to watch runs and send instructions from this device.</p>
      <form onSubmit={submit} className="stack">
        <Label htmlFor="token">Daemon API token</Label>
        <input id="token" className="field" type="password" required autoComplete="off" autoCapitalize="off" spellCheck={false} maxLength={43} aria-describedby="token-help" value={token} onChange={(event) => setToken(event.target.value)} />
        <p className="muted" id="token-help">Use the token from your daemon's private api.token file. This app does not save it. Sessions expire after 12 hours or a daemon restart.</p>
        <Button type="submit" disabled={state.busy.includes("login")}>Connect device</Button>
      </form>
    </section>
  );
}
