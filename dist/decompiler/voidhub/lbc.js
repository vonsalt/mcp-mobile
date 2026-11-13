/**
 * VoidHub decompiler — Luau binary chunk parser (stage 0).
 *
 * Parses a serialized Luau module into protos, constants, and raw
 * instruction words, following the public bytecode container format:
 * signature, version byte, (v4+) type version byte, string table,
 * flat proto table, main proto id. Protos are self-describing with
 * version-gated fields.
 */
import { ByteReader, detectLegacyStringTable } from "./reader.js";
export const LUAU_SIGNATURE = "\u001bLuau";
function readConstant(reader, strings) {
    const tag = reader.u8();
    switch (tag) {
        case 0:
            return { type: "nil" };
        case 1:
            return { type: "boolean", value: reader.u8() !== 0 };
        case 2:
            return { type: "number", value: reader.f64() };
        case 3:
            return { type: "string", value: reader.stringRef(strings) ?? "" };
        case 4: {
            // import id (u32)
            const id = reader.u32();
            return { type: "import", id };
        }
        case 5: {
            const keys = reader.varint();
            const list = [];
            for (let i = 0; i < keys; i++)
                list.push(reader.varint());
            return { type: "table", keys: list };
        }
        case 6:
            return { type: "closure", protoIndex: reader.varint() };
        case 7: {
            // vector constant (4 x f32)
            const x = reader.f32();
            const y = reader.f32();
            const z = reader.f32();
            reader.f32();
            return { type: "vector", x, y, z };
        }
        case 8: {
            // double-precision vector (4 x f64)
            const x = reader.f64();
            const y = reader.f64();
            const z = reader.f64();
            reader.f64();
            return { type: "vector", x, y, z };
        }
        case 9: {
            // table with constant values
            const keys = reader.varint();
            const keyList = [];
            const constants = [];
            for (let i = 0; i < keys; i++) {
                keyList.push(reader.varint());
                constants.push(reader.i32());
            }
            return { type: "tableWithConstants", keys: keyList, constants };
        }
        case 10: {
            // 64-bit integer
            const negative = reader.u8() !== 0;
            const magnitude = reader.varint64();
            return { type: "integer", value: negative ? -magnitude : magnitude };
        }
        case 11:
            return { type: "classShape", classNameIndex: reader.varint() };
        default:
            return { type: "unknown", tag };
    }
}
function readProto(reader, index, strings, version, typeVersion) {
    const proto = {
        index,
        maxStackSize: reader.u8(),
        numParams: reader.u8(),
        numUpvalues: reader.u8(),
        isVararg: reader.u8(),
        flags: version >= 4 ? reader.u8() : 0,
        code: [],
        constants: [],
        children: [],
        lineDefined: 0,
        locals: [],
        upvalueNames: [],
    };
    // Type info blob (v4+, typeVersion 1-3) — skipped, not needed for output.
    if (version >= 4 && typeVersion >= 1) {
        const size = reader.varint();
        if (size > 0)
            reader.bytes(size);
    }
    const codeSize = reader.varint();
    if (codeSize > 16_000_000)
        reader.fail("Proto code size out of range");
    for (let i = 0; i < codeSize; i++)
        proto.code.push(reader.u32());
    const constantSize = reader.varint();
    if (constantSize > 1_000_000)
        reader.fail("Proto constant count out of range");
    for (let i = 0; i < constantSize; i++)
        proto.constants.push(readConstant(reader, strings));
    const childCount = reader.varint();
    for (let i = 0; i < childCount; i++)
        proto.children.push(reader.varint());
    proto.lineDefined = reader.varint();
    proto.debugName = reader.stringRef(strings);
    const hasLineInfo = reader.u8() !== 0;
    if (hasLineInfo) {
        reader.u8(); // line gap log2
        const lines = [];
        for (let i = 0; i < codeSize; i++)
            lines.push(reader.u8());
        proto.lines = lines;
        const intervals = ((codeSize - 1) >> 3) + 1;
        for (let i = 0; i < intervals; i++)
            reader.i32();
    }
    const hasDebugInfo = reader.u8() !== 0;
    if (hasDebugInfo) {
        const localCount = reader.varint();
        for (let i = 0; i < localCount; i++) {
            proto.locals.push({
                name: reader.stringRef(strings),
                startPc: reader.varint(),
                endPc: reader.varint(),
                register: reader.u8(),
            });
        }
        const upvalueCount = reader.varint();
        for (let i = 0; i < upvalueCount; i++)
            proto.upvalueNames.push(reader.stringRef(strings));
    }
    // Feedback vector (v11+) — skipped.
    if (version >= 11) {
        const feedbackSize = reader.varint();
        for (let i = 0; i < feedbackSize; i++) {
            const slotType = reader.u8();
            if (slotType === 1 /* call target */ || slotType === 2 /* construct */)
                reader.varint();
        }
    }
    // Inline cost (v12+, only when the inlinable flag is set).
    if (version >= 12 && (proto.flags & 1) !== 0)
        reader.varint64();
    return proto;
}
function parseWithReader(data, headerSize, legacyStrings) {
    const reader = new ByteReader(data);
    reader.offset = headerSize;
    if (legacyStrings)
        reader.markLegacyStrings();
    const bytecodeVersion = reader.u8();
    if (bytecodeVersion === 0)
        reader.fail("Bytecode blob carries an error message instead of code");
    if (bytecodeVersion < 3 || bytecodeVersion > 14)
        reader.fail(`Unsupported Luau bytecode version ${bytecodeVersion}`);
    const typeVersion = bytecodeVersion >= 4 ? reader.u8() : 0;
    const stringCount = legacyStrings ? reader.u32() : reader.varint();
    if (stringCount > 1_000_000)
        reader.fail("String table out of range");
    const strings = [];
    for (let i = 0; i < stringCount; i++)
        strings.push(reader.string());
    const protoCount = reader.varint();
    if (protoCount > 100_000)
        reader.fail("Proto table out of range");
    const protos = [];
    for (let i = 0; i < protoCount; i++) {
        if (bytecodeVersion >= 12)
            reader.varint(); // proto byte size prefix
        protos.push(readProto(reader, i, strings, bytecodeVersion, typeVersion));
    }
    const mainIndex = reader.varint();
    if (mainIndex >= protos.length)
        reader.fail("Main proto index out of range");
    return {
        bytecodeVersion,
        typeVersion,
        strings,
        protos,
        mainIndex,
        headerSize,
        consumedBytes: reader.position,
    };
}
/**
 * Parse a Luau binary chunk. Accepts buffers with or without the
 * "\x1bLuau" signature and auto-detects the string table encoding by
 * trying the current varint format first and falling back to the legacy
 * fixed-width format.
 */
export function parseLuauBytecode(data) {
    let headerSize = 0;
    if (data.length >= 5 && data.subarray(0, 5).toString("latin1") === LUAU_SIGNATURE)
        headerSize = 5;
    if (data.length <= headerSize + 2)
        throw new Error("Bytecode blob is too small to parse");
    // The version byte decides whether a type-version byte follows.
    const versionByte = data[headerSize];
    const typeByteFollows = versionByte >= 4 && versionByte <= 14;
    const contentHeaderSize = headerSize + (typeByteFollows ? 2 : 1);
    const attempts = detectLegacyStringTable(data, contentHeaderSize)
        ? [true, false]
        : [false, true];
    let lastError = null;
    for (const legacy of attempts) {
        try {
            const chunk = parseWithReader(data, headerSize, legacy);
            // A clean parse lands exactly at the end of the buffer; leftover
            // bytes mean the encoding guess was wrong.
            if (chunk.consumedBytes === data.length)
                return chunk;
            lastError = new Error(`Encoding mismatch: parsed ${chunk.consumedBytes} of ${data.length} bytes`);
        }
        catch (error) {
            lastError = error;
        }
    }
    throw new Error(`Could not parse Luau bytecode: ${lastError instanceof Error ? lastError.message : String(lastError)}`);
}
