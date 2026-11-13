// VoidHub decompiler regression tests.
// Builds synthetic Luau bytecode chunks and verifies every pipeline profile.
import test from "node:test";
import assert from "node:assert/strict";
import { runVoidhubPipeline } from "../dist/decompiler/voidhub/pipeline.js";
import { parseLuauBytecode } from "../dist/decompiler/voidhub/lbc.js";
import { buildControlFlowGraph, findLoopHeaders } from "../dist/decompiler/voidhub/cfg.js";
import { decodeInstructions, OPCODE_NAMES } from "../dist/decompiler/voidhub/opcodes.js";

function varint(value) {
    const bytes = [];
    let v = value >>> 0;
    while (v >= 128) {
        bytes.push((v & 127) | 128);
        v >>>= 7;
    }
    bytes.push(v);
    return bytes;
}

function u8v(value) {
    return [value & 255];
}

function f64v(value) {
    const buffer = Buffer.alloc(8);
    buffer.writeDoubleLE(value, 0);
    return [...buffer];
}

/** Build a single instruction word: op | A<<8 | D<<16. */
function word(op, a, d) {
    return (((d & 0xffff) << 16) | (op & 255) | ((a & 255) << 8)) >>> 0;
}

/**
 * Minimal chunk builder. The code array holds 32-bit instruction WORDS
 * (not bytes); constants and strings are assembled into a version-4
 * varint-encoded module.
 */
function buildChunk({ strings = [], code = [], constants = [], numParams = 0, vararg = 1 }) {
    const chunk = [...[0x1b, 0x4c, 0x75, 0x61, 0x75], 4, 1];
    chunk.push(...varint(strings.length));
    for (const s of strings) {
        chunk.push(...varint(s.length));
        for (const ch of s)
            chunk.push(ch.charCodeAt(0));
    }
    chunk.push(
        ...varint(1),
        ...u8v(8), ...u8v(numParams), ...u8v(0), ...u8v(vararg), ...u8v(0),
        ...varint(0),                        // no type info
        ...varint(code.length),              // word count
    );
    const wordBuffer = Buffer.alloc(4);
    for (const w of code) {
        wordBuffer.writeUInt32LE(w >>> 0, 0);
        chunk.push(...wordBuffer);
    }
    chunk.push(...varint(constants.length));
    for (const constant of constants)
        chunk.push(...constant);
    chunk.push(...varint(0), ...varint(0), ...varint(0), ...u8v(0), ...u8v(0), ...varint(0));
    return Buffer.from(chunk);
}

const numericConstant = (value) => [...u8v(2), ...f64v(value)];
const stringConstant = (stringTableIndex) => [...u8v(3), ...varint(stringTableIndex + 1)];

test("opcode table is positional and stable", () => {
    assert.equal(OPCODE_NAMES[0], "NOP");
    assert.equal(OPCODE_NAMES[4], "LOADN");
    assert.equal(OPCODE_NAMES[22], "RETURN");
    assert.equal(OPCODE_NAMES[56], "FORNPREP");
    assert.equal(OPCODE_NAMES[57], "FORNLOOP");
    assert.equal(decodeInstructions([word(4, 3, 9)])[0].opName, "LOADN");
});

test("parses a well-formed chunk and reports exact consumption", () => {
    const bytecode = buildChunk({
        strings: ["print"],
        code: [word(4, 0, 7), word(22, 0, 0)],
        constants: [numericConstant(7)],
    });
    const chunk = parseLuauBytecode(bytecode);
    assert.equal(chunk.bytecodeVersion, 4);
    assert.equal(chunk.strings.length, 1);
    assert.equal(chunk.protos.length, 1);
    assert.equal(chunk.consumedBytes, bytecode.length);
    assert.equal(chunk.protos[0].code.length, 2);
    assert.deepEqual(chunk.protos[0].constants[0], { type: "number", value: 7 });
});

test("rejects truncated bytecode without crashing", () => {
    assert.throws(() => parseLuauBytecode(Buffer.from([0x1b, 0x4c, 0x75])), /too small|Could not parse/);
});

test("all profiles decompile a numeric for loop", () => {
    // sum = 0; for i = 1, 10 do sum = sum + 1 end; print(sum)
    const code = [
        word(4, 0, 0),        // 0: LOADN r0, 0
        word(56, 1, 2),       // 1: FORNPREP r1 -> 4
        word(39, 0, 0),      // 2: ADDK r0, r0, K0
        word(57, 1, -2),      // 3: FORNLOOP r1 -> 2
        word(7, 4, 0),       // 4: GETGLOBAL r4 (aux word follows)
        0,                    //    aux = K0
        word(6, 5, 0),       // 5: MOVE r5, r0
        word(21, 4, 1),      // 6: CALL r4, 1, 0
        word(22, 0, 0),       // 7: RETURN
    ];
    const bytecode = buildChunk({
        strings: ["print"],
        code,
        constants: [numericConstant(1)],
    });

    for (const profile of ["disasm", "balanced", "structured"]) {
        const result = runVoidhubPipeline(bytecode, profile);
        assert.equal(result.ok, true, `${profile} should succeed: ${result.error}`);
        assert.ok(result.source && result.source.length > 0, `${profile} should produce source`);
        assert.equal(result.protoCount, 1);
        assert.equal(result.instructionCount, 8);
    }

    const disasm = runVoidhubPipeline(bytecode, "disasm");
    assert.match(disasm.source, /for r1 = r2, r3, r4 do/);
    assert.match(disasm.source, /r0 = r0 \+ 1/);

    const structured = runVoidhubPipeline(bytecode, "structured");
    assert.match(structured.source, /for r1 = r2, r3, r4 do/);
    assert.match(structured.source, /r0 = r0 \+ 1/);
    // The loop body must not be duplicated after the loop.
    const bodyMatches = structured.source.match(/r0 = r0 \+ 1/g) ?? [];
    assert.equal(bodyMatches.length, 1, "loop body should appear exactly once");
    assert.ok(structured.structuredRatio > 0, "structured ratio should be positive");
});

test("string constants resolve through the string table", () => {
    const bytecode = buildChunk({
        strings: ["game", "Workspace"],
        code: [word(7, 0, 0), 0], // GETGLOBAL r0, aux -> K0
        constants: [stringConstant(1)],
    });
    const result = runVoidhubPipeline(bytecode, "disasm");
    assert.match(result.source, /Workspace/);
});

test("paste-void text export helper rejects empty content", async () => {
    const { exportTextToPasteVoid } = await import("../dist/shared/paste-void.js");
    const result = await exportTextToPasteVoid("", "test");
    assert.equal(result.ok, false);
});

test("structured profile reports a clean failure on garbage input", () => {
    const garbage = Buffer.from([0x1b, 0x4c, 0x75, 0x61, 0x75, 4, 1, 0xff, 0xff, 0xff, 0xff, 0xff]);
    const result = runVoidhubPipeline(garbage, "structured");
    assert.equal(result.ok, false);
    assert.ok(result.error);
});

test("LOADN renders its signed 16-bit D operand", () => {
    // LOADN r0, 1000 used to render "r0 = 3" (the C byte) instead of the
    // signed 16-bit D value.
    const bytecode = buildChunk({
        code: [
            word(4, 0, 1000),   // 0: LOADN r0, 1000
            word(4, 1, -5),     // 1: LOADN r1, -5
            word(22, 0, 0),     // 2: RETURN
        ],
    });
    const result = runVoidhubPipeline(bytecode, "disasm");
    assert.equal(result.ok, true, result.error);
    assert.match(result.source, /r0 = 1000/);
    assert.match(result.source, /r1 = -5/);
});

test("while-loop back edge yields a loop header and a while construct", () => {
    // LOADB r0,1; JUMPIFNOT r0,-2 (back to pc 0); RETURN
    const code = [
        word(3, 0, 1),        // 0: LOADB r0, true
        word(26, 0, -2),      // 1: JUMPIFNOT r0, -2 -> 0
        word(22, 0, 0),       // 2: RETURN
    ];
    const bytecode = buildChunk({ code });
    const chunk = parseLuauBytecode(bytecode);
    const proto = chunk.protos[chunk.mainIndex];

    // CFG: the JUMPIFNOT must produce a back edge to pc 0.
    const cfg = buildControlFlowGraph(proto);
    const jumpBlock = cfg.blocks.find((block) => block.instructions.some((i) => i.opName === "JUMPIFNOT"));
    assert.ok(jumpBlock, "JUMPIFNOT block should exist");
    const backEdgeTarget = jumpBlock.successors.map((id) => cfg.blocks[id].start)
        .find((start) => start <= jumpBlock.start);
    assert.notEqual(backEdgeTarget, undefined, "JUMPIFNOT should create a back edge");
    const headers = findLoopHeaders(cfg);
    assert.equal(headers.size, 1, "exactly one loop header expected");
    const headerBlock = jumpBlock.successors.map((id) => cfg.blocks[id])
        .find((block) => block.start <= jumpBlock.start);
    assert.ok(headers.has(headerBlock.id), "back-edge target must be the loop header");

    // Structured profile recovers a while construct with the D-based target.
    const structured = runVoidhubPipeline(bytecode, "structured");
    assert.equal(structured.ok, true, structured.error);
    assert.match(structured.source, /while r0 do/);
    assert.ok(structured.structuredRatio > 0, "structured ratio should be positive");

    // Disasm annotation must use D (target 0), never a bogus negative target.
    const disasm = runVoidhubPipeline(bytecode, "disasm");
    assert.equal(disasm.ok, true, disasm.error);
    assert.match(disasm.source, /if not r0 then goto 0/);
    assert.doesNotMatch(disasm.source, /goto -\d+/);
});

test("numeric for loop produces a loop header via the FORNLOOP back edge", () => {
    const code = [
        word(56, 1, 1),       // 0: FORNPREP r1 -> 2
        word(39, 0, 0),      // 1: ADDK r0, r0, K0 (body)
        word(57, 1, -2),      // 2: FORNLOOP r1 -> 1
        word(22, 0, 0),       // 3: RETURN
    ];
    const bytecode = buildChunk({ code, constants: [numericConstant(1)] });
    const chunk = parseLuauBytecode(bytecode);
    const cfg = buildControlFlowGraph(chunk.protos[chunk.mainIndex]);
    const headers = findLoopHeaders(cfg);
    assert.equal(headers.size, 1, "FORNLOOP back edge should mark the body block as loop header");
});

test("JUMPIF target annotations use the D operand", () => {
    const code = [
        word(25, 0, 2),       // 0: JUMPIF r0, +2 -> 3
        word(3, 1, 1),        // 1: LOADB r1, true
        word(22, 0, 0),       // 2: RETURN
        word(22, 0, 0),       // 3: RETURN
    ];
    const bytecode = buildChunk({ code });
    const disasm = runVoidhubPipeline(bytecode, "disasm");
    assert.equal(disasm.ok, true, disasm.error);
    assert.match(disasm.source, /if r0 then goto 3/);
    assert.doesNotMatch(disasm.source, /goto -\d+/);
    const balanced = runVoidhubPipeline(bytecode, "balanced");
    assert.equal(balanced.ok, true, balanced.error);
    assert.match(balanced.source, /JUMPIF -> 3/);
});

test("JUMPIFEQ renders the second register from the AUX word", () => {
    // A = r1, D = jump offset, AUX = r2.
    const code = [
        word(27, 1, 1),       // 0: JUMPIFEQ r1, r2, D=+1 -> 2
        2,                    //    AUX word: register 2
        word(22, 0, 0),       // 2: RETURN
    ];
    const bytecode = buildChunk({ code });
    const disasm = runVoidhubPipeline(bytecode, "disasm");
    assert.equal(disasm.ok, true, disasm.error);
    assert.match(disasm.source, /if r1 == r2 then goto 2/);
    const structured = runVoidhubPipeline(bytecode, "structured");
    assert.equal(structured.ok, true, structured.error);
    assert.match(structured.source, /r1 == r2/);
});

test("JUMPX decodes its target from the E operand", () => {
    // JUMPX (opcode 67) encodes its offset in the signed 24-bit E operand
    // (bits 8-23), unlike every other jump which uses D.
    const jumpxWord = ((OPCODE_NAMES.indexOf("JUMPX")) | (2 << 8)) >>> 0; // E = +2 -> pc 3
    const code = [
        jumpxWord,            // 0: JUMPX +2 -> 3
        word(3, 1, 1),        // 1: LOADB r1, true (skipped)
        word(22, 0, 0),       // 2: RETURN (skipped)
        word(22, 0, 0),       // 3: RETURN
    ];
    const bytecode = buildChunk({ code });
    const chunk = parseLuauBytecode(bytecode);
    const proto = chunk.protos[chunk.mainIndex];

    // CFG: the JUMPX block must have exactly one edge to the block at pc 3
    // (unconditional, so no fallthrough to pc 1).
    const cfg = buildControlFlowGraph(proto);
    const jumpxBlock = cfg.blocks.find((block) => block.instructions.some((i) => i.opName === "JUMPX"));
    assert.ok(jumpxBlock, "JUMPX block should exist");
    assert.equal(jumpxBlock.successors.length, 1, "JUMPX is unconditional: single successor");
    assert.equal(cfg.blocks[jumpxBlock.successors[0]].start, 3, "JUMPX must jump to pc 3 via E");

    const disasm = runVoidhubPipeline(bytecode, "disasm");
    assert.equal(disasm.ok, true, disasm.error);
    assert.match(disasm.source, /goto 3/);
    assert.doesNotMatch(disasm.source, /goto -\d+/);
    const balanced = runVoidhubPipeline(bytecode, "balanced");
    assert.equal(balanced.ok, true, balanced.error);
    assert.match(balanced.source, /JUMPX -> 3/);
});
