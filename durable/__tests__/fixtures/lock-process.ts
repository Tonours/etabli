import { writerLock } from "../../src/lock.ts";
await writerLock(process.argv[2]);
console.log("locked");
setInterval(() => undefined, 1000);
