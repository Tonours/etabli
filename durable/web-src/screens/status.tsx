import { Check, TriangleAlert } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import type { RunView } from "../../shared/runs-view.ts";

export function Status({ view }: { view: RunView }) {
  return (
    <Badge variant={view.tone === "muted" ? "outline" : "secondary"} data-tone={view.tone}>
      {view.tone === "alert" && <TriangleAlert aria-hidden="true" />}
      {view.tone === "ok" && <Check aria-hidden="true" />}
      {view.label}
    </Badge>
  );
}
