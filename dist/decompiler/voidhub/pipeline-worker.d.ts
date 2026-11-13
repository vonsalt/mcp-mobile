/**
 * VoidHub decompiler — worker thread entry point.
 *
 * The pipeline is pure CPU work with no I/O, so it is safe to run in a
 * worker thread. The parent (decompiler/run.ts) transfers the bytecode in,
 * enforces a timeout by terminating this worker, and falls back to running
 * the pipeline on the main thread when workers are unavailable.
 */
export {};
