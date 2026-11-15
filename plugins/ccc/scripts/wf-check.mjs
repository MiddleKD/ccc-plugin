// node wf-check.mjs <file>: parse a workflow body as an async function (top-level await + return allowed)
import { readFileSync } from "node:fs";
const src = readFileSync(process.argv[2], "utf8").replace(/^export const meta\b/m, "const meta");
const AsyncFunction = (async () => {}).constructor;
try { new AsyncFunction("agent", "parallel", "pipeline", "phase", "log", "args", src); }
catch (e) { console.error(String(e.message)); process.exit(1); }
