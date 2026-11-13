/**
 * VoidHub decompiler — stage 3: structure recovery.
 *
 * Reconstructs high-level control flow (while/for/repeat/if-else) from
 * the CFG by recognizing back edges as loops, numeric-for and generic-for
 * opcode patterns, and conditional branches as if statements. Blocks that
 * resist structuring fall back to explicit goto/label form so output is
 * always valid.
 */
import type { LuauProto } from "./lbc.js";
export type Statement = {
    kind: "comment";
    text: string;
} | {
    kind: "label";
    pc: number;
} | {
    kind: "goto";
    target: number;
} | {
    kind: "raw";
    pc: number;
    text: string;
} | {
    kind: "if";
    condition: string;
    body: Statement[];
    elseBody?: Statement[];
} | {
    kind: "while";
    condition: string;
    body: Statement[];
} | {
    kind: "repeat";
    body: Statement[];
    condition: string;
} | {
    kind: "numericFor";
    register: number;
    from: string;
    to: string;
    step: string;
    body: Statement[];
} | {
    kind: "genericFor";
    registers: number[];
    iterator: string;
    body: Statement[];
};
export interface StructuredProto {
    protoIndex: number;
    statements: Statement[];
    /** Fraction of instructions that ended up inside structured constructs. */
    structuredRatio: number;
}
/** Structure a single proto. Always produces output; ratio flags quality. */
export declare function structureProto(proto: LuauProto): StructuredProto;
