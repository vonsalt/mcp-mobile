/**
 * VoidHub decompiler — low-level binary reader for Luau bytecode chunks.
 * Handles both the current varint-encoded format (bytecode v3+) and the
 * legacy fixed-width string table encoding, auto-detected per chunk.
 */
export declare class ByteReader {
    private readonly data;
    offset: number;
    private legacyStrings;
    constructor(data: Buffer);
    get position(): number;
    get remaining(): number;
    get eof(): boolean;
    fail(message: string): never;
    ensure(count: number): void;
    u8(): number;
    u32(): number;
    i32(): number;
    f64(): number;
    f32(): number;
    bytes(count: number): Buffer;
    /** Variable-length unsigned integer (7 bits per byte, little-endian groups). */
    varint(): number;
    /** 64-bit variable-length unsigned integer. */
    varint64(): bigint;
    /** Raw string bytes — length is read with the active encoding mode. */
    string(): string;
    /** String table reference — varint id, 0 means "none". */
    stringRef(table: readonly string[]): string | undefined;
    markLegacyStrings(): void;
}
/**
 * Peek helper: checks whether a chunk uses the legacy fixed-width string
 * table. Legacy chunks start with u32 counts that are huge when misread as
 * varints, so we validate by attempting a varint read and sanity-checking
 * the implied table size against the buffer length.
 */
export declare function detectLegacyStringTable(data: Buffer, headerSize: number): boolean;
