/**
 * VoidHub decompiler — stage 4: code generation.
 *
 * Renders recovered statements as Luau-style source, walking nested
 * protos and inlining closure constants. Debug names are used when the
 * chunk carries them; registers fall back to r0/r1/… naming.
 */
import type { LuauChunk } from "./lbc.js";
import type { StructuredProto } from "./structurer.js";
export interface GeneratedProto {
    protoIndex: number;
    name: string;
    source: string;
}
/** Render the whole chunk, main proto first. */
export declare function generateSource(chunk: LuauChunk, structuredMain: StructuredProto): string;
