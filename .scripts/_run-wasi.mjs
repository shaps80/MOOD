import { readFileSync } from "node:fs";
import { WASI } from "node:wasi";

const [, , executable, ...args] = process.argv;
const wasi = new WASI({
  version: "preview1",
  args: [executable, ...args],
  env: process.env,
});
const module = await WebAssembly.compile(readFileSync(executable));
const instance = await WebAssembly.instantiate(module, {
  wasi_snapshot_preview1: wasi.wasiImport,
});
wasi.start(instance);
