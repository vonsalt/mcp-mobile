/**
 * VoidHub decompiler — public entry point.
 *
 * A self-contained, in-process multi-stage Luau decompiler. No network
 * calls, works with any executor that can produce bytecode via
 * getscriptbytecode, and degrades gracefully through its stages.
 */

export { parseLuauBytecode, type LuauChunk, type LuauProto, type LuauConstant } from "./lbc.js";
export { disassembleChunk, disassembleProto } from "./disasm.js";
export { buildControlFlowGraph, findLoopHeaders } from "./cfg.js";
export { structureProto } from "./structurer.js";
export { generateSource } from "./codegen.js";
export { runVoidhubPipeline, type VoidhubProfile, type VoidhubResult, type StageReport } from "./pipeline.js";
export { OPCODE_NAMES, decodeInstructions, jumpOffset, jumpTargetPc } from "./opcodes.js";
