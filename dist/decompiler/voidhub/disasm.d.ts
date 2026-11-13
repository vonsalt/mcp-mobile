/**
 * VoidHub decompiler — stage 1: annotated disassembly.
 *
 * Turns raw instruction words into named, operand-resolved listing lines,
 * with constant folding for K-variant opcodes and jump target annotation.
 * This stage always succeeds and is the fallback output of the whole
 * pipeline when later stages cannot recover structure.
 */
import type { LuauChunk, LuauProto } from "./lbc.js";
export interface DisasmLine {
    pc: number;
    opName: string;
    text: string;
    raw: string;
}
export interface ProtoDisasm {
    protoIndex: number;
    header: string;
    lines: DisasmLine[];
}
/** Disassemble a single proto into annotated lines. */
export declare function disassembleProto(chunk: LuauChunk, proto: LuauProto): ProtoDisasm;
/** Disassemble an entire chunk, main proto first. */
export declare function disassembleChunk(chunk: LuauChunk): string;
