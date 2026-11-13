/**
 * VoidHub decompiler — Luau opcode tables.
 *
 * Opcode numbering is positional and append-only across Luau bytecode versions,
 * so one table covers every version the pipeline accepts. Semantics follow the
 * public Luau bytecode definition; unknown opcodes decode as raw words.
 */
export declare const OPCODE_NAMES: readonly string[];
export declare const AUX_WORD: Set<string>;
export declare const IS_JUMP: Set<string>;
/** Unconditional forward/backward jump opcodes. */
export declare const IS_UNCONDITIONAL_JUMP: Set<string>;
/** Conditional jump opcodes (all remaining jumps). */
export declare const IS_CONDITIONAL_JUMP: Set<string>;
/** Opcodes that terminate a basic block. */
export declare const IS_BLOCK_TERMINATOR: Set<string>;
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
export declare function jumpOffset(instruction: DecodedInstruction): number;
/**
 * Absolute instruction index (word offset) a jump lands on, or undefined
 * when the instruction is not a jump.
 */
export declare function jumpTargetPc(instruction: DecodedInstruction): number | undefined;
/** Decode a flat array of instruction words into records with operands. */
export declare function decodeInstructions(code: readonly number[]): DecodedInstruction[];
