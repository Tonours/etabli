import { createContext, useContext, useSyncExternalStore } from "react";
import type { State, Store } from "./store.ts";

export const StoreContext = createContext<Store | undefined>(undefined);

export function useStore(): [State, Store] {
  const store = useContext(StoreContext);
  if (!store) throw new Error("StoreContext is missing");
  return [useSyncExternalStore(store.subscribe, store.get), store];
}
