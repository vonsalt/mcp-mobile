/**
 * VoidHub decompiler — stage 1: annotated disassembly.
 *
 * Turns raw instruction words into named, operand-resolved listing lines,
 * with constant folding for K-variant opcodes and jump target annotation.
 * This stage always succeeds and is the fallback output of the whole
 * pipeline when later stages cannot recover structure.
 */

import { decodeInstructions, IS_JUMP, type DecodedInstruction } from "./opcodes.js";
import type { LuauChunk, LuauConstant, LuauProto } from "./lbc.js";

export interface DisasmLine {
    pc: number;
    opName: string;
    text: string;
    raw: string;
}

function formatConstant(constant: LuauConstant | undefined): string {
    if (constant === undefined)
        return "?";
    switch (constant.type) {
        case "nil":
            return "nil";
        case "boolean":
            return constant.value ? "true" : "false";
        case "number":
            return String(constant.value);
        case "integer":
            return constant.value.toString();
        case "string":
            return JSON.stringify(constant.value);
        case "vector":
            return `vector(${constant.x}, ${constant.y}, ${constant.z})`;
        case "import":
            return `import#${constant.id}`;
        case "table":
            return `{ ${constant.keys.length} keys }`;
        case "tableWithConstants":
            return `{ ${constant.keys.length} keys + constants }`;
        case "closure":
            return `closure<proto ${constant.protoIndex}>`;
        case "classShape":
            return `classShape<${constant.classNameIndex}>`;
        default:
            return `tag#${constant.tag}`;
    }
}

function register(prefix: string, index: number): string {
    return `${prefix}${index}`;
}

const D_OPERAND_JUMPS = new Set([
    "JUMP",
    "JUMPBACK",
    "JUMPX",
    "FORNPREP",
    "FORNLOOP",
    "FORGPREP",
    "FORGLOOP",
    "FORGPREP_INEXT",
    "FORGPREP_NEXT",
    "CMPPROTO",
]);

function jumpTarget(instruction: DecodedInstruction): number | undefined {
    if (!IS_JUMP.has(instruction.opName))
        return undefined;
    const operand = D_OPERAND_JUMPS.has(instruction.opName)
        ? instruction.d
        : instruction.e;
    return instruction.index + 1 + operand;
}

function renderInstruction(chunk: LuauChunk, proto: LuauProto, instruction: DecodedInstruction): string {
    const k = proto.constants;
    const a = instruction.a;
    const b = instruction.b;
    const c = instruction.c;
    const d = instruction.d;
    const aux = instruction.aux;

    switch (instruction.opName) {
        case "NOP":
            return "";
        case "BREAK":
            return "breakpoint";
        case "LOADNIL":
            return `r${a} = nil`;
        case "LOADB":
            return `r${a} = ${b !== 0 ? "true" : "false"}`;
        case "LOADN":
            return `r${a} = ${c < 128 ? c : c - 256}`;
        case "LOADK":
            return `r${a} = ${formatConstant(k[b])}`;
        case "LOADKX":
            return `r${a} = ${formatConstant(k[aux ?? 0])}`;
        case "MOVE":
            return `r${a} = r${b}`;
        case "GETGLOBAL":
            return `r${a} = _G[${formatConstant(k[aux ?? 0])}]`;
        case "SETGLOBAL":
            return `_G[${formatConstant(k[aux ?? 0])}] = r${a}`;
        case "GETUPVAL":
            return `r${a} = up${b}`;
        case "SETUPVAL":
            return `up${b} = r${a}`;
        case "CLOSEUPVALS":
            return `close_upvalues(r${a})`;
        case "GETIMPORT":
            return `r${a} = import(${formatConstant(k[aux ?? 0])})`;
        case "GETTABLE":
            return `r${a} = r${b}[r${c}]`;
        case "SETTABLE":
            return `r${b}[r${c}] = r${a}`;
        case "GETTABLEKS":
            return `r${a} = r${b}[${formatConstant(k[aux ?? 0])}]`;
        case "SETTABLEKS":
            return `r${b}[${formatConstant(k[aux ?? 0])}] = r${a}`;
        case "GETTABLEN":
            return `r${a} = r${b}[${c < 128 ? c : c - 256}]`;
        case "SETTABLEN":
            return `r${b}[${c < 128 ? c : c - 256}] = r${a}`;
        case "NEWCLOSURE":
            return `r${a} = closure(${b}, [${Array.from({ length: instruction.word >>> 8 & 0xff ? 0 : 0 }, () => "").join("")}${aux !== undefined ? aux : ""}...)`;
        case "NAMECALL":
            return `r${a + 1} = r${b}:${formatConstant(k[aux ?? 0])}(...)`;
        case "CALL": {
            const argCount = b - 1;
            const resultCount = c - 1;
            const args = argCount < 0 ? "..." : `r${a + 1}${argCount > 0 ? `, ${register("r", a + 2)}…` : ""}`;
            const results = resultCount < 0 ? "..." : resultCount === 0 ? "(discarded)" : `${resultCount} values`;
            return `r${a}${resultCount > 0 ? `, …` : ""} = call r${a}(${args}) -> ${results}`;
        }
        case "RETURN": {
            const count = b - 1;
            return `return ${count < 0 ? "..." : count === 0 ? "nothing" : `r${a}, … (${count} values)`}`;
        }
        case "JUMP":
            return `goto ${jumpTarget(instruction)}`;
        case "JUMPBACK":
            return `goto ${jumpTarget(instruction)}`;
        case "JUMPIF":
            return `if r${a} then goto ${jumpTarget(instruction)}`;
        case "JUMPIFNOT":
            return `if not r${a} then goto ${jumpTarget(instruction)}`;
        case "JUMPIFEQ":
            return `if r${a} == r${d} then goto ${jumpTarget(instruction)}`;
        case "JUMPIFLE":
            return `if r${a} <= r${d} then goto ${jumpTarget(instruction)}`;
        case "JUMPIFLT":
            return `if r${a} < r${d} then goto ${jumpTarget(instruction)}`;
        case "JUMPIFNOTEQ":
            return `if r${a} ~= r${d} then goto ${jumpTarget(instruction)}`;
        case "JUMPIFNOTLE":
            return `if r${a} > r${d} then goto ${jumpTarget(instruction)}`;
        case "JUMPIFNOTLT":
            return `if r${a} >= r${d} then goto ${jumpTarget(instruction)}`;
        case "JUMPXEQKNIL":
            return `if r${a} == nil then goto ${jumpTarget(instruction)}`;
        case "JUMPXEQKB":
            return `if r${a} == ${aux !== 0 ? "true" : "false"} then goto ${jumpTarget(instruction)}`;
        case "JUMPXEQKN":
            return `if r${a} == ${formatConstant(k[aux ?? 0])} then goto ${jumpTarget(instruction)}`;
        case "JUMPXEQKS":
            return `if r${a} == ${formatConstant(k[aux ?? 0])} then goto ${jumpTarget(instruction)}`;
        case "ADD":
            return `r${a} = r${b} + r${c}`;
        case "SUB":
            return `r${a} = r${b} - r${c}`;
        case "MUL":
            return `r${a} = r${b} * r${c}`;
        case "DIV":
            return `r${a} = r${b} / r${c}`;
        case "MOD":
            return `r${a} = r${b} % r${c}`;
        case "POW":
            return `r${a} = r${b} ^ r${c}`;
        case "ADDK":
            return `r${a} = r${b} + ${formatConstant(k[c])}`;
        case "SUBK":
            return `r${a} = r${b} - ${formatConstant(k[c])}`;
        case "MULK":
            return `r${a} = r${b} * ${formatConstant(k[c])}`;
        case "DIVK":
            return `r${a} = r${b} / ${formatConstant(k[c])}`;
        case "MODK":
            return `r${a} = r${b} % ${formatConstant(k[c])}`;
        case "POWK":
            return `r${a} = r${b} ^ ${formatConstant(k[c])}`;
        case "AND":
            return `r${a} = r${a} and r${b}`;
        case "OR":
            return `r${a} = r${a} or r${b}`;
        case "ANDK":
            return `r${a} = r${a} and ${formatConstant(k[b])}`;
        case "ORK":
            return `r${a} = r${a} or ${formatConstant(k[b])}`;
        case "CONCAT":
            return `r${a} = concat(r${a} .. r${c - 1})`;
        case "NOT":
            return `r${a} = not r${b}`;
        case "MINUS":
            return `r${a} = -r${b}`;
        case "LENGTH":
            return `r${a} = #r${b}`;
        case "NEWTABLE":
            return `r${a} = { } -- ${aux ?? 0} array slots, ${b} hash slots`;
        case "DUPTABLE":
            return `r${a} = dup_table(${formatConstant(k[aux ?? 0])})`;
        case "SETLIST":
            return `r${b}:set_list(r${b + 1}, ${aux ?? 0})`;
        case "FORNPREP":
            return `for r${a} = r${a + 1}, r${a + 2}, r${a + 3} do -- prep, goto ${jumpTarget(instruction)}`;
        case "FORNLOOP":
            return `end -- numeric for loop step, goto ${jumpTarget(instruction)}`;
        case "FORGLOOP":
            return `end -- generic for loop step (state ${aux ?? 0}), goto ${jumpTarget(instruction)}`;
        case "FORGPREP":
        case "FORGPREP_INEXT":
        case "FORGPREP_NEXT":
            return `for r${a + 3}, r${a + 4}, r${a + 5} in r${a} do -- prep, goto ${jumpTarget(instruction)}`;
        case "FASTCALL":
        case "FASTCALL1":
        case "FASTCALL2":
        case "FASTCALL2K":
        case "FASTCALL3":
            return `fastcall ${aux !== undefined ? `builtin ${aux}` : ""} (skips ${d} words)`;
        case "NATIVECALL":
            return `native call r${a}`;
        case "GETVARARGS":
            return `r${a}${b > 1 ? ", …" : ""} = varargs(${b})`;
        case "DUPCLOSURE":
            return `r${a} = dup_closure(${formatConstant(k[b])})`;
        case "PREPVARARGS":
            return `adjust_varargs(${a})`;
        case "JUMPX":
            return `goto ${d}`;
        case "COVERAGE":
            return `coverage(${aux ?? 0})`;
        case "CAPTURE":
            return `capture(${b === 0 ? "value" : b === 1 ? "reference" : "upvalue"} r${c})`;
        case "SUBRK":
            return `r${a} = ${formatConstant(k[b])} - r${c}`;
        case "DIVRK":
            return `r${a} = ${formatConstant(k[b])} / r${c}`;
        case "IDIV":
            return `r${a} = r${b} // r${c}`;
        case "IDIVK":
            return `r${a} = r${b} // ${formatConstant(k[c])}`;
        case "GETUDATAKS":
            return `r${a} = r${b}.${formatConstant(k[aux ?? 0])} (userdata)`;
        case "SETUDATAKS":
            return `r${b}.${formatConstant(k[aux ?? 0])} = r${a} (userdata)`;
        case "NAMECALLUDATA":
            return `r${a + 1} = r${b}:${formatConstant(k[aux ?? 0])}(...) (userdata)`;
        case "NEWCLASSMEMBER":
            return `class_member ${formatConstant(k[aux ?? 0])}`;
        case "CALLFB":
            return `r${a} = call_feedback r${a}(..., ${aux ?? 0})`;
        case "CMPPROTO":
            return `compare_proto(${aux ?? 0}) goto ${jumpTarget(instruction)}`;
        case "FASTPCALL":
            return `fast_pcall(${aux ?? 0})`;
        case "NEWCLASS":
            return `r${a} = class ${formatConstant(k[aux ?? 0])}`;
        case "CONSTRUCT":
            return `construct ${formatConstant(k[aux ?? 0])}`;
        case "FINCONSTRUCT":
            return `end construct`;
        case "GETPRIVATEFIELD":
            return `r${a} = private r${b}.${formatConstant(k[aux ?? 0])}`;
        case "SETPRIVATEFIELD":
            return `r${b}.${formatConstant(k[aux ?? 0])} = r${a} (private)`;
        default:
            return `-- unknown opcode ${instruction.opName} A=${a} B=${b} C=${c} D=${d}`;
    }
}

export interface ProtoDisasm {
    protoIndex: number;
    header: string;
    lines: DisasmLine[];
}

/** Disassemble a single proto into annotated lines. */
export function disassembleProto(chunk: LuauChunk, proto: LuauProto): ProtoDisasm {
    const instructions = decodeInstructions(proto.code);
    const name = proto.debugName
        ? `${proto.debugName}`
        : `proto_${proto.index}`;
    const params = Array.from({ length: proto.numParams }, (_, i) => `a${i + 1}`).join(", ");
    const vararg = proto.isVararg ? (params ? ", ..." : "...") : "";
    const header = `function ${name}(${params}${vararg}) -- ${proto.code.length} words, ${proto.maxStackSize} stack, ${proto.constants.length} constants`;

    const lines: DisasmLine[] = instructions.map((instruction) => {
        const target = jumpTarget(instruction);
        const rendered = renderInstruction(chunk, proto, instruction);
        return {
            pc: instruction.index,
            opName: instruction.opName,
            text: target !== undefined ? `${rendered}  ; -> ${target}` : rendered,
            raw: `${instruction.word.toString(16).padStart(8, "0")}${instruction.aux !== undefined ? ` ${instruction.aux.toString(16).padStart(8, "0")}` : ""}`,
        };
    });

    return { protoIndex: proto.index, header, lines };
}

/** Disassemble an entire chunk, main proto first. */
export function disassembleChunk(chunk: LuauChunk): string {
    const order: number[] = [];
    const walk = (index: number): void => {
        order.push(index);
        for (const child of chunk.protos[index]!.children)
            walk(child);
    };
    walk(chunk.mainIndex);

    const parts: string[] = [];
    for (const index of order) {
        const proto = chunk.protos[index]!;
        const result = disassembleProto(chunk, proto);
        parts.push(`${result.header}`);
        for (const line of result.lines)
            parts.push(`  ${line.pc.toString().padStart(5)}  ${line.text}`);
        parts.push("end");
        parts.push("");
    }
    return parts.join("\n");
}
