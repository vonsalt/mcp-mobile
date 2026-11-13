/**
 * VoidHub decompiler — Luau binary chunk parser (stage 0).
 *
 * Parses a serialized Luau module into protos, constants, and raw
 * instruction words, following the public bytecode container format:
 * signature, version byte, (v4+) type version byte, string table,
 * flat proto table, main proto id. Protos are self-describing with
 * version-gated fields.
 */
export declare const LUAU_SIGNATURE = "\u001BLuau";
export type LuauConstant = {
    type: "nil";
} | {
    type: "boolean";
    value: boolean;
} | {
    type: "number";
    value: number;
} | {
    type: "integer";
    value: bigint;
} | {
    type: "string";
    value: string;
} | {
    type: "vector";
    x: number;
    y: number;
    z: number;
} | {
    type: "import";
    id: number;
} | {
    type: "table";
    keys: number[];
} | {
    type: "tableWithConstants";
    keys: number[];
    constants: (number | null)[];
} | {
    type: "closure";
    protoIndex: number;
} | {
    type: "classShape";
    classNameIndex: number;
} | {
    type: "unknown";
    tag: number;
};
export interface LuauLocal {
    name?: string;
    startPc: number;
    endPc: number;
    register: number;
}
export interface LuauProto {
    index: number;
    maxStackSize: number;
    numParams: number;
    numUpvalues: number;
    isVararg: number;
    flags: number;
    /** Raw instruction words, including AUX words inline. */
    code: number[];
    constants: LuauConstant[];
    /** Indices into the flat proto table for nested functions. */
    children: number[];
    lineDefined: number;
    debugName?: string;
    locals: LuauLocal[];
    upvalueNames: (string | undefined)[];
    /** Per-instruction line deltas when line info is present. */
    lines?: number[];
}
export interface LuauChunk {
    bytecodeVersion: number;
    typeVersion: number;
    strings: string[];
    protos: LuauProto[];
    mainIndex: number;
    /** Byte size of the parsed header (signature + versions). */
    headerSize: number;
    /** Total bytes consumed by the parser — must equal the buffer length. */
    consumedBytes: number;
}
/**
 * Parse a Luau binary chunk. Accepts buffers with or without the
 * "\x1bLuau" signature and auto-detects the string table encoding by
 * trying the current varint format first and falling back to the legacy
 * fixed-width format.
 */
export declare function parseLuauBytecode(data: Buffer): LuauChunk;
