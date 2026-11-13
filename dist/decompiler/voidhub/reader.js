/**
 * VoidHub decompiler — low-level binary reader for Luau bytecode chunks.
 * Handles both the current varint-encoded format (bytecode v3+) and the
 * legacy fixed-width string table encoding, auto-detected per chunk.
 */
export class ByteReader {
    data;
    offset = 0;
    legacyStrings = false;
    constructor(data) {
        this.data = data;
    }
    get position() {
        return this.offset;
    }
    get remaining() {
        return this.data.length - this.offset;
    }
    get eof() {
        return this.offset >= this.data.length;
    }
    fail(message) {
        throw new Error(`${message} (at byte ${this.offset})`);
    }
    ensure(count) {
        if (this.offset + count > this.data.length)
            this.fail("Unexpected end of bytecode");
    }
    u8() {
        this.ensure(1);
        return this.data[this.offset++];
    }
    u32() {
        this.ensure(4);
        const value = this.data.readUInt32LE(this.offset);
        this.offset += 4;
        return value;
    }
    i32() {
        this.ensure(4);
        const value = this.data.readInt32LE(this.offset);
        this.offset += 4;
        return value;
    }
    f64() {
        this.ensure(8);
        const value = this.data.readDoubleLE(this.offset);
        this.offset += 8;
        return value;
    }
    f32() {
        this.ensure(4);
        const value = this.data.readFloatLE(this.offset);
        this.offset += 4;
        return value;
    }
    bytes(count) {
        this.ensure(count);
        const slice = this.data.subarray(this.offset, this.offset + count);
        this.offset += count;
        return slice;
    }
    /** Variable-length unsigned integer (7 bits per byte, little-endian groups). */
    varint() {
        let result = 0;
        let shift = 0;
        for (let i = 0; i < 5; i++) {
            const byte = this.u8();
            result |= (byte & 127) << shift;
            if ((byte & 128) === 0)
                return result >>> 0;
            shift += 7;
        }
        return this.fail("Malformed varint");
    }
    /** 64-bit variable-length unsigned integer. */
    varint64() {
        let result = 0n;
        let shift = 0n;
        for (let i = 0; i < 10; i++) {
            const byte = this.u8();
            result |= BigInt(byte & 127) << shift;
            if ((byte & 128) === 0)
                return result;
            shift += 7n;
        }
        return this.fail("Malformed varint64");
    }
    /** Raw string bytes — length is read with the active encoding mode. */
    string() {
        const length = this.legacyStrings ? this.u32() : this.varint();
        if (length > 0x7ffffff)
            this.fail("String length out of range");
        return this.bytes(length).toString("utf8");
    }
    /** String table reference — varint id, 0 means "none". */
    stringRef(table) {
        const id = this.varint();
        if (id === 0)
            return undefined;
        const value = table[id - 1];
        if (value === undefined)
            this.fail(`String id ${id} out of range`);
        return value;
    }
    markLegacyStrings() {
        this.legacyStrings = true;
    }
}
/**
 * Peek helper: checks whether a chunk uses the legacy fixed-width string
 * table. Legacy chunks start with u32 counts that are huge when misread as
 * varints, so we validate by attempting a varint read and sanity-checking
 * the implied table size against the buffer length.
 */
export function detectLegacyStringTable(data, headerSize) {
    try {
        const reader = new ByteReader(data);
        reader.offset = headerSize;
        const count = reader.varint();
        if (count === 0)
            return false;
        if (count > data.length)
            return true;
        // Validate that `count` strings fit in the remaining bytes.
        let consumed = 0;
        for (let i = 0; i < Math.min(count, 64); i++) {
            const length = reader.varint();
            if (length > data.length)
                return true;
            reader.offset += length;
            consumed = reader.offset;
            if (reader.offset >= data.length && i + 1 < count)
                return true;
        }
        return false;
    }
    catch {
        return true;
    }
}
