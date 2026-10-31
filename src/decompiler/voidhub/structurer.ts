/**
 * VoidHub decompiler — stage 3: structure recovery.
 *
 * Reconstructs high-level control flow (while/for/repeat/if-else) from
 * the CFG by recognizing back edges as loops, numeric-for and generic-for
 * opcode patterns, and conditional branches as if statements. Blocks that
 * resist structuring fall back to explicit goto/label form so output is
 * always valid.
 */

import { decodeInstructions, IS_UNCONDITIONAL_JUMP, type DecodedInstruction } from "./opcodes.js";
import type { LuauConstant, LuauProto } from "./lbc.js";
import { buildControlFlowGraph, findLoopHeaders, type BasicBlock, type ControlFlowGraph } from "./cfg.js";

export type Statement =
    | { kind: "comment"; text: string }
    | { kind: "label"; pc: number }
    | { kind: "goto"; target: number }
    | { kind: "raw"; pc: number; text: string }
    | { kind: "if"; condition: string; body: Statement[]; elseBody?: Statement[] }
    | { kind: "while"; condition: string; body: Statement[] }
    | { kind: "repeat"; body: Statement[]; condition: string }
    | { kind: "numericFor"; register: number; from: string; to: string; step: string; body: Statement[] }
    | { kind: "genericFor"; registers: number[]; iterator: string; body: Statement[] };

export interface StructuredProto {
    protoIndex: number;
    statements: Statement[];
    /** Fraction of instructions that ended up inside structured constructs. */
    structuredRatio: number;
}

function constantText(constant: LuauConstant | undefined): string {
    if (constant === undefined)
        return "?";
    switch (constant.type) {
        case "string":
            return JSON.stringify(constant.value);
        case "number":
            return String(constant.value);
        case "boolean":
            return constant.value ? "true" : "false";
        case "nil":
            return "nil";
        default:
            return "k";
    }
}

function reg(index: number): string {
    return `r${index}`;
}

function instructionText(proto: LuauProto, instruction: DecodedInstruction): string {
    const k = proto.constants;
    const a = instruction.a;
    const b = instruction.b;
    const c = instruction.c;
    const aux = instruction.aux;
    switch (instruction.opName) {
        case "LOADNIL":
            return `${reg(a)} = nil`;
        case "LOADB":
            return `${reg(a)} = ${b !== 0 ? "true" : "false"}`;
        case "LOADN":
            return `${reg(a)} = ${c < 128 ? c : c - 256}`;
        case "LOADK":
            return `${reg(a)} = ${constantText(k[b])}`;
        case "LOADKX":
            return `${reg(a)} = ${constantText(k[aux ?? 0])}`;
        case "MOVE":
            return `${reg(a)} = ${reg(b)}`;
        case "GETGLOBAL":
            return `${reg(a)} = _G[${constantText(k[aux ?? 0])}]`;
        case "SETGLOBAL":
            return `_G[${constantText(k[aux ?? 0])}] = ${reg(a)}`;
        case "GETUPVAL":
            return `${reg(a)} = upvalue_${b}`;
        case "SETUPVAL":
            return `upvalue_${b} = ${reg(a)}`;
        case "GETIMPORT":
            return `${reg(a)} = import(${constantText(k[aux ?? 0])})`;
        case "GETTABLE":
            return `${reg(a)} = ${reg(b)}[${reg(c)}]`;
        case "SETTABLE":
            return `${reg(b)}[${reg(c)}] = ${reg(a)}`;
        case "GETTABLEKS":
            return `${reg(a)} = ${reg(b)}[${constantText(k[aux ?? 0])}]`;
        case "SETTABLEKS":
            return `${reg(b)}[${constantText(k[aux ?? 0])}] = ${reg(a)}`;
        case "GETTABLEN":
            return `${reg(a)} = ${reg(b)}[${c < 128 ? c : c - 256}]`;
        case "SETTABLEN":
            return `${reg(b)}[${c < 128 ? c : c - 256}] = ${reg(a)}`;
        case "NAMECALL":
            return `${reg(a + 1)} = ${reg(b)}:${constantText(k[aux ?? 0])}(...)`;
        case "CALL": {
            const argCount = b - 1;
            const resultCount = c - 1;
            const args = argCount < 0 ? "..." : argCount === 0 ? "" : `${reg(a + 1)}..r${a + argCount}`;
            const results = resultCount < 0 ? "..." : resultCount === 0 ? "" : `${reg(a)}..r${a + resultCount - 1}`;
            return resultCount === 0
                ? `${reg(a)}(${args})`
                : `${results} = ${reg(a)}(${args})`;
        }
        case "RETURN": {
            const count = b - 1;
            if (count < 0)
                return "return ...";
            if (count === 0)
                return "return";
            return `return ${reg(a)}${count > 1 ? `, …(${count})` : ""}`;
        }
        case "ADD":
            return `${reg(a)} = ${reg(b)} + ${reg(c)}`;
        case "SUB":
            return `${reg(a)} = ${reg(b)} - ${reg(c)}`;
        case "MUL":
            return `${reg(a)} = ${reg(b)} * ${reg(c)}`;
        case "DIV":
            return `${reg(a)} = ${reg(b)} / ${reg(c)}`;
        case "MOD":
            return `${reg(a)} = ${reg(b)} % ${reg(c)}`;
        case "POW":
            return `${reg(a)} = ${reg(b)} ^ ${reg(c)}`;
        case "ADDK":
            return `${reg(a)} = ${reg(b)} + ${constantText(k[c])}`;
        case "SUBK":
            return `${reg(a)} = ${reg(b)} - ${constantText(k[c])}`;
        case "MULK":
            return `${reg(a)} = ${reg(b)} * ${constantText(k[c])}`;
        case "DIVK":
            return `${reg(a)} = ${reg(b)} / ${constantText(k[c])}`;
        case "MODK":
            return `${reg(a)} = ${reg(b)} % ${constantText(k[c])}`;
        case "POWK":
            return `${reg(a)} = ${reg(b)} ^ ${constantText(k[c])}`;
        case "AND":
            return `${reg(a)} = ${reg(a)} and ${reg(b)}`;
        case "OR":
            return `${reg(a)} = ${reg(a)} or ${reg(b)}`;
        case "ANDK":
            return `${reg(a)} = ${reg(a)} and ${constantText(k[b])}`;
        case "ORK":
            return `${reg(a)} = ${reg(a)} or ${constantText(k[b])}`;
        case "NOT":
            return `${reg(a)} = not ${reg(b)}`;
        case "MINUS":
            return `${reg(a)} = -${reg(b)}`;
        case "LENGTH":
            return `${reg(a)} = #${reg(b)}`;
        case "NEWTABLE":
            return `${reg(a)} = {}`;
        case "DUPTABLE":
            return `${reg(a)} = dup(${constantText(k[aux ?? 0])})`;
        case "SETLIST":
            return `${reg(b)}:set_list(${reg(b + 1)}, ${aux ?? 0})`;
        case "CONCAT":
            return `${reg(a)} = concat(${reg(a)}, …, ${reg(c - 1)})`;
        case "GETVARARGS":
            return `${reg(a)} = varargs(${b})`;
        case "DUPCLOSURE":
            return `${reg(a)} = closure(${constantText(k[b])})`;
        case "NEWCLOSURE":
            return `${reg(a)} = closure(${b}, ${aux ?? ""})`;
        case "CAPTURE":
            return `capture(${b === 0 ? "val" : b === 1 ? "ref" : "up"} ${reg(c)})`;
        case "IDIV":
            return `${reg(a)} = ${reg(b)} // ${reg(c)}`;
        case "IDIVK":
            return `${reg(a)} = ${reg(b)} // ${constantText(k[c])}`;
        case "SUBRK":
            return `${reg(a)} = ${constantText(k[b])} - ${reg(c)}`;
        case "DIVRK":
            return `${reg(a)} = ${constantText(k[b])} / ${reg(c)}`;
        case "CLOSEUPVALS":
            return `close_upvalues(${reg(a)})`;
        case "COVERAGE":
        case "NOP":
        case "BREAK":
            return "";
        default:
            return `${instruction.opName.toLowerCase()} a=${a} b=${b} c=${c}`;
    }
}

function conditionText(proto: LuauProto, instruction: DecodedInstruction, negate: boolean): string {
    const k = proto.constants;
    const a = instruction.a;
    const d = instruction.d;
    const aux = instruction.aux;
    let condition: string;
    switch (instruction.opName) {
        case "JUMPIF":
            condition = reg(a);
            break;
        case "JUMPIFNOT":
            condition = reg(a);
            negate = !negate;
            break;
        case "JUMPIFEQ":
            condition = `${reg(a)} == ${reg(d)}`;
            break;
        case "JUMPIFLE":
            condition = `${reg(a)} <= ${reg(d)}`;
            break;
        case "JUMPIFLT":
            condition = `${reg(a)} < ${reg(d)}`;
            break;
        case "JUMPIFNOTEQ":
            condition = `${reg(a)} ~= ${reg(d)}`;
            break;
        case "JUMPIFNOTLE":
            condition = `${reg(a)} > ${reg(d)}`;
            break;
        case "JUMPIFNOTLT":
            condition = `${reg(a)} >= ${reg(d)}`;
            break;
        case "JUMPXEQKNIL":
            condition = `${reg(a)} == nil`;
            break;
        case "JUMPXEQKB":
            condition = `${reg(a)} == ${aux !== 0 ? "true" : "false"}`;
            break;
        case "JUMPXEQKN":
        case "JUMPXEQKS":
            condition = `${reg(a)} == ${constantText(k[aux ?? 0])}`;
            break;
        default:
            condition = `${reg(a)} ?`;
    }
    if (negate)
        return `not (${condition})`;
    return condition;
}

function rawStatements(proto: LuauProto, block: BasicBlock, skipJump: boolean): Statement[] {
    const out: Statement[] = [];
    for (const instruction of block.instructions) {
        if (skipJump && IS_UNCONDITIONAL_JUMP.has(instruction.opName) && instruction === block.instructions.at(-1))
            continue;
        // Loop step instructions are mechanics, not body code.
        if (instruction.opName === "FORNLOOP" || instruction.opName === "FORGLOOP")
            continue;
        const text = instructionText(proto, instruction);
        if (text !== "")
            out.push({ kind: "raw", pc: instruction.index, text });
    }
    return out;
}

function structureBlock(
    proto: LuauProto,
    cfg: ControlFlowGraph,
    block: BasicBlock,
    loopHeaders: Set<number>,
    visited: Set<number>,
): Statement[] {
    const out: Statement[] = [];
    if (visited.has(block.id))
        return out;
    visited.add(block.id);

    const last = block.instructions.at(-1);
    const lastIndex = last ? last.index + (last.aux !== undefined ? 2 : 1) : block.end;
    const fallthroughId = cfg.blockAt.get(lastIndex);
    const emitThenAdvance = (statements: Statement[]): void => {
        out.push(...statements);
    };

    // Numeric for loop: FORNPREP jumps to a FORNLOOP.
    if (last && last.opName === "FORNPREP") {
        const bodyStart = last.index + 1;
        const loopEnd = last.index + 1 + last.d;
        const body = statementsBetween(proto, cfg, bodyStart, loopEnd, loopHeaders, visited);
        emitThenAdvance([
            {
                kind: "numericFor",
                register: last.a,
                from: reg(last.a + 1),
                to: reg(last.a + 2),
                step: reg(last.a + 3),
                body,
            },
        ]);
        // Consume every block inside the loop range so the outer walker
        // does not re-emit them.
        for (let pc = bodyStart; pc < loopEnd; pc++) {
            const id = cfg.blockAt.get(pc);
            if (id !== undefined)
                visited.add(id);
        }
        return out;
    }

    // Generic for loop: FORGPREP* + FORGLOOP back edge.
    if (last && (last.opName === "FORGPREP" || last.opName === "FORGPREP_NEXT" || last.opName === "FORGPREP_INEXT")) {
        const base = last.a;
        const bodyStart = last.index + 1;
        const loopEnd = last.index + 1 + last.d;
        const body = rawStatementsInRange(proto, cfg, bodyStart, loopEnd, loopHeaders, visited);
        for (let pc = bodyStart; pc < loopEnd; pc++) {
            const id = cfg.blockAt.get(pc);
            if (id !== undefined)
                visited.add(id);
        }
        emitThenAdvance([
            {
                kind: "genericFor",
                registers: [base + 3, base + 4, base + 5],
                iterator: reg(base),
                body,
            },
        ]);
        return out;
    }

    // Conditional branch -> if statement with structured bodies.
    if (last && last.opName.startsWith("JUMPIF") || (last && last.opName.startsWith("JUMPXEQK"))) {
        const condition = conditionText(proto, last, false);
        const targetId = cfg.blockAt.get(last.index + 1 + (last.opName === "JUMP" ? last.d : last.e));
        if (targetId !== undefined) {
            const thenBlock = cfg.blocks[targetId];
            const thenBody = structureBlock(proto, cfg, thenBlock, loopHeaders, visited);
            const elseBody = fallthroughId !== undefined
                ? structureBlock(proto, cfg, cfg.blocks[fallthroughId]!, loopHeaders, visited)
                : undefined;
            emitThenAdvance([
                {
                    kind: "if",
                    condition,
                    body: thenBody,
                    ...(elseBody ? { elseBody } : {}),
                },
            ]);
            return out;
        }
    }

    // Unconditional jump that is not a loop back edge -> goto.
    if (last && IS_UNCONDITIONAL_JUMP.has(last.opName) && !loopHeaders.has(block.id)) {
        emitThenAdvance(rawStatements(proto, block, true));
        const target = last.opName === "JUMPX" ? last.d : last.index + 1 + last.d;
        if (target < block.start)
            emitThenAdvance([{ kind: "goto", target }]);
        return out;
    }

    // Loop header with back edge -> while loop.
    if (loopHeaders.has(block.id) && block.predecessors.some((p) => p >= block.id)) {
        const loopLast = block.instructions.at(-1);
        if (loopLast && loopLast.opName.startsWith("JUMPIF")) {
            const condition = conditionText(proto, loopLast, true);
            const bodyBlocks = collectLoopBody(proto, cfg, block, loopHeaders, visited);
            emitThenAdvance([
                { kind: "while", condition, body: bodyBlocks },
            ]);
            return out;
        }
        emitThenAdvance([{ kind: "label", pc: block.start }]);
        emitThenAdvance(rawStatements(proto, block, false));
        return out;
    }

    // Plain fallthrough block.
    emitThenAdvance(rawStatements(proto, block, false));
    if (last && last.opName === "JUMPIFNOT") {
        // Fallthrough is the then-branch; keep as-is.
    }
    return out;
}

function statementsBetween(
    proto: LuauProto,
    cfg: ControlFlowGraph,
    startPc: number,
    endPc: number,
    loopHeaders: Set<number>,
    visited: Set<number>,
): Statement[] {
    const out: Statement[] = [];
    let pc = startPc;
    while (pc < endPc) {
        const blockId = cfg.blockAt.get(pc);
        if (blockId === undefined || visited.has(blockId))
            break;
        const block = cfg.blocks[blockId]!;
        out.push(...structureBlock(proto, cfg, block, loopHeaders, visited));
        const last = block.instructions.at(-1);
        pc = last ? last.index + (last.aux !== undefined ? 2 : 1) : block.end;
        if (last && IS_UNCONDITIONAL_JUMP.has(last.opName))
            break;
    }
    return out;
}

function rawStatementsInRange(
    proto: LuauProto,
    cfg: ControlFlowGraph,
    startPc: number,
    endPc: number,
    loopHeaders: Set<number>,
    visited: Set<number>,
): Statement[] {
    const out: Statement[] = [];
    let pc = startPc;
    while (pc < endPc) {
        const blockId = cfg.blockAt.get(pc);
        if (blockId === undefined || visited.has(blockId))
            break;
        const block = cfg.blocks[blockId]!;
        visited.add(blockId);
        out.push(...rawStatements(proto, block, true));
        const last = block.instructions.at(-1);
        pc = last ? last.index + (last.aux !== undefined ? 2 : 1) : block.end;
    }
    return out;
}

function collectLoopBody(
    proto: LuauProto,
    cfg: ControlFlowGraph,
    header: BasicBlock,
    loopHeaders: Set<number>,
    visited: Set<number>,
): Statement[] {
    const body: Statement[] = [];
    for (const block of cfg.blocks) {
        if (block.id === header.id || visited.has(block.id))
            continue;
        if (block.start < header.start)
            continue;
        const reachesHeader = block.successors.includes(header.id);
        if (!reachesHeader && !header.successors.includes(block.id))
            continue;
        body.push(...rawStatements(proto, block, true));
        visited.add(block.id);
    }
    return body;
}

/** Structure a single proto. Always produces output; ratio flags quality. */
export function structureProto(proto: LuauProto): StructuredProto {
    const cfg = buildControlFlowGraph(proto);
    const loopHeaders = findLoopHeaders(cfg);
    const visited = new Set<number>();
    const statements: Statement[] = [];

    let pc = 0;
    while (pc < proto.code.length) {
        const blockId = cfg.blockAt.get(pc);
        if (blockId === undefined)
            break;
        if (visited.has(blockId)) {
            const block = cfg.blocks[blockId]!;
            const last = block.instructions.at(-1);
            pc = last ? last.index + (last.aux !== undefined ? 2 : 1) : block.end;
            if (last && IS_UNCONDITIONAL_JUMP.has(last.opName)) {
                const target = last.opName === "JUMPX" ? last.d : last.index + 1 + last.d;
                pc = Math.max(pc, target);
            }
            continue;
        }
        const before = statements.length;
        statements.push(...structureBlock(proto, cfg, cfg.blocks[blockId]!, loopHeaders, visited));
        const block = cfg.blocks[blockId]!;
        const last = block.instructions.at(-1);
        const nextPc = last ? last.index + (last.aux !== undefined ? 2 : 1) : block.end;
        if (nextPc <= pc) {
            // Safety: always advance.
            pc = nextPc === pc ? Math.min(proto.code.length, pc + 1) : nextPc;
        }
        else {
            pc = nextPc;
        }
        void before;
    }

    const structuredCount = countStructured(statements);
    const total = decodeInstructions(proto.code).length;
    return {
        protoIndex: proto.index,
        statements,
        structuredRatio: total === 0 ? 1 : structuredCount / total,
    };
}

function countStructured(statements: Statement[]): number {
    let count = 0;
    for (const statement of statements) {
        if (statement.kind === "if" || statement.kind === "while" || statement.kind === "repeat"
            || statement.kind === "numericFor" || statement.kind === "genericFor") {
            count += statement.kind === "if"
                ? countStructured(statement.body) + countStructured(statement.elseBody ?? [])
                : countStructured(statement.body);
            count += 4; // the construct itself
        }
        else if (statement.kind === "raw") {
            count += 1;
        }
    }
    return count;
}
