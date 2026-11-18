import { ChevronDown } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible";
import { useStore } from "../use-store.ts";

export function Settings() {
  const [state, store] = useStore();
  return (
    <Collapsible className="settings">
      <CollapsibleTrigger asChild><Button variant="ghost">Settings <ChevronDown aria-hidden="true" /></Button></CollapsibleTrigger>
      <CollapsibleContent className="settings-content">
        <section aria-labelledby="notifications-title" className="stack">
          <h2 id="notifications-title">Notifications</h2>
          <p className="muted" id="push-state">{state.push.text}</p>
          {state.push.subscribed
            ? <Button variant="outline" disabled={state.busy.includes("unsubscribe")} onClick={() => void store.disableNotifications()}>Disable notifications</Button>
            : <Button variant="outline" disabled={!state.push.available || state.busy.includes("subscribe")} onClick={() => void store.enableNotifications()}>Enable notifications</Button>}
        </section>
        <p className="muted">Install from your browser's app menu, or Share → Add to Home Screen. Connection and run data are available online only.</p>
      </CollapsibleContent>
    </Collapsible>
  );
}
