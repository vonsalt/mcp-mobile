/**
 * VoidHub decompiler — worker thread entry point.
 *
 * The pipeline is pure CPU work with no I/O, so it is safe to run in a
 * worker thread. The parent (decompiler/run.ts) transfers the bytecode in,
 * enforces a timeout by terminating this worker, and falls back to running
 * the pipeline on the main thread when workers are unavailable.
 */

import { parentPort, workerData } from "node:worker_threads";
import { runVoidhubPipeline, type VoidhubProfile } from "./pipeline.js";

const port = parentPort;
if (!port)
    throw new Error("pipeline-worker must be started as a worker thread");

const data = workerData as { bytecode: Uint8Array; profile: VoidhubProfile };
const bytecode = Buffer.from(data.bytecode.buffer, data.bytecode.byteOffset, data.bytecode.byteLength);
const result = runVoidhubPipeline(bytecode, data.profile);
port.postMessage(result);
