/**
 * VoidHub decompiler — Luau opcode tables.
 *
 * Opcode numbering is positional and append-only across Luau bytecode versions,
 * so one table covers every version the pipeline accepts. Semantics follow the
 * public Luau bytecode definition; unknown opcodes decode as raw words.
 */

export const OPCODE_NAMES: readonly string[] = [
    "NOP",
    "BREAK",
    "LOADNIL",
    "LOADB",
    "LOADN",
    "LOADK",
    "MOVE",
    "GETGLOBAL",
    "SETGLOBAL",
    "GETUPVAL",
    "SETUPVAL",
    "CLOSEUPVALS",
    "GETIMPORT",
    "GETTABLE",
    "SETTABLE",
    "GETTABLEKS",
    "SETTABLEKS",
    "GETTABLEN",
    "SETTABLEN",
    "NEWCLOSURE",
    "NAMECALL",
    "CALL",
    "RETURN",
    "JUMP",
    "JUMPBACK",
    "JUMPIF",
    "JUMPIFNOT",
    "JUMPIFEQ",
    "JUMPIFLE",
    "JUMPIFLT",
    "JUMPIFNOTEQ",
    "JUMPIFNOTLE",
    "JUMPIFNOTLT",
    "ADD",
    "SUB",
    "MUL",
    "DIV",
    "MOD",
    "POW",
    "ADDK",
    "SUBK",
    "MULK",
    "DIVK",
    "MODK",
    "POWK",
    "AND",
    "OR",
    "ANDK",
    "ORK",
    "CONCAT",
    "NOT",
    "MINUS",
    "LENGTH",
    "NEWTABLE",
    "DUPTABLE",
    "SETLIST",
    "FORNPREP",
    "FORNLOOP",
    "FORGLOOP",
    "FORGPREP_INEXT",
    "FASTCALL3",
    "FORGPREP_NEXT",
    "NATIVECALL",
    "GETVARARGS",
    "DUPCLOSURE",
    "PREPVARARGS",
    "LOADKX",
    "JUMPX",
    "FASTCALL",
    "COVERAGE",
    "CAPTURE",
    "SUBRK",
    "DIVRK",
    "FASTCALL1",
    "FASTCALL2",
    "FASTCALL2K",
    "FORGPREP",
    "JUMPXEQKNIL",
    "JUMPXEQKB",
    "JUMPXEQKN",
    "JUMPXEQKS",
    "IDIV",
    "IDIVK",
    "GETUDATAKS",
    "SETUDATAKS",
    "NAMECALLUDATA",
    "NEWCLASSMEMBER",
    "CALLFB",
    "CMPPROTO",
    "FASTPCALL",
    "NEWCLASS",
    "CONSTRUCT",
    "FINCONSTRUCT",
    "GETPRIVATEFIELD",
    "SETPRIVATEFIELD",
];

/** Opcodes whose instruction word is followed by one AUX word (length 2). */
const AUX_OPCODES: readonly string[] = [
    "GETGLOBAL",
    "SETGLOBAL",
    "GETIMPORT",
    "GETTABLEKS",
    "SETTABLEKS",
    "NAMECALL",
    "JUMPIFEQ",
    "JUMPIFLE",
    "JUMPIFLT",
    "JUMPIFNOTEQ",
    "JUMPIFNOTLE",
    "JUMPIFNOTLT",
    "NEWTABLE",
    "SETLIST",
    "FORGLOOP",
    "LOADKX",
    "FASTCALL2",
    "FASTCALL2K",
    "FASTCALL3",
    "JUMPXEQKNIL",
    "JUMPXEQKB",
    "JUMPXEQKN",
    "JUMPXEQKS",
    "GETUDATAKS",
    "SETUDATAKS",
    "NAMECALLUDATA",
    "NEWCLASSMEMBER",
    "CALLFB",
    "CMPPROTO",
    "NEWCLASS",
    "CONSTRUCT",
    "GETPRIVATEFIELD",
    "SETPRIVATEFIELD",
];

/** Opcodes whose signed D/E operand is a jump offset in instruction words. */
const JUMP_OPCODES: readonly string[] = [
    "JUMP",
    "JUMPX",
    "JUMPIF",
    "JUMPIFNOT",
    "JUMPIFEQ",
    "JUMPIFLE",
    "JUMPIFLT",
    "JUMPIFNOTEQ",
    "JUMPIFNOTLE",
    "JUMPIFNOTLT",
    "FORNPREP",
    "FORNLOOP",
    "FORGPREP",
    "FORGLOOP",
    "FORGPREP_INEXT",
    "FORGPREP_NEXT",
    "JUMPBACK",
    "JUMPXEQKNIL",
    "JUMPXEQKB",
    "JUMPXEQKN",
    "JUMPXEQKS",
    "CMPPROTO",
];

export const AUX_WORD = new Set(AUX_OPCODES);
export const IS_JUMP = new Set(JUMP_OPCODES);

/** Unconditional forward/backward jump opcodes. */
export const IS_UNCONDITIONAL_JUMP = new Set(["JUMP", "JUMPBACK", "JUMPX"]);
/** Conditional jump opcodes (all remaining jumps). */
export const IS_CONDITIONAL_JUMP = new Set(
    JUMP_OPCODES.filter((name) => !IS_UNCONDITIONAL_JUMP.has(name)),
);

/** Opcodes that terminate a basic block. */
export const IS_BLOCK_TERMINATOR = new Set([
    ...JUMP_OPCODES,
    "RETURN",
    "CALL",
    "FORNLOOP",
]);

export interface DecodedInstruction {
    /** Byte offset of the instruction header word inside the proto code array. */
    index: number;
    word: number;
    opcode: number;
    opName: string;
    /** AUX word payload when the opcode carries one. */
    aux?: number;
    a: number;
    b: number;
    c: number;
    d: number;
    e: number;
}

/**
 * Jump offset in instruction words. Every jump opcode encodes its offset in
 * the signed 16-bit D operand (bits 16-31) except JUMPX, which encodes it in
 * the signed 24-bit E operand (bits 8-23). Single source of truth for the
 * whole pipeline.
 */
export function jumpOffset(instruction: DecodedInstruction): number {
    return instruction.opName === "JUMPX" ? instruction.e : instruction.d;
}

/**
 * Absolute instruction index (word offset) a jump lands on, or undefined
 * when the instruction is not a jump.
 */
export function jumpTargetPc(instruction: DecodedInstruction): number | undefined {
    if (!IS_JUMP.has(instruction.opName))
        return undefined;
    return instruction.index + 1 + jumpOffset(instruction);
}

/** Decode a flat array of instruction words into records with operands. */
export function decodeInstructions(code: readonly number[]): DecodedInstruction[] {
    const out: DecodedInstruction[] = [];
    let index = 0;
    while (index < code.length) {
        const word = code[index]!;
        const opcode = word & 0xff;
        const opName = OPCODE_NAMES[opcode] ?? `UNKNOWN_${opcode}`;
        const hasAux = AUX_WORD.has(opName);
        const aux = hasAux ? code[index + 1] : undefined;
        out.push({
            index,
            word,
            opcode,
            opName,
            aux,
            a: (word >> 8) & 0xff,
            b: (word >> 16) & 0xff,
            c: (word >> 24) & 0xff,
            d: (word | 0) >> 16,
            e: (word | 0) >> 8,
        });
        index += hasAux ? 2 : 1;
    }
    return out;
}
