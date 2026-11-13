/**
 * VoidHub decompiler — stage 2: control-flow graph.
 *
 * Splits a proto's instruction stream into basic blocks using jump
 * targets and fallthrough, then classifies edges so the structurer can
 * recover loops and conditionals.
 */
import { type DecodedInstruction } from "./opcodes.js";
import type { LuauProto } from "./lbc.js";
export interface BasicBlock {
    id: number;
    /** Instruction index (word offset) of the first instruction. */
    start: number;
    /** Exclusive end — index just past the last instruction. */
    end: number;
    instructions: DecodedInstruction[];
    successors: number[];
    predecessors: number[];
}
export interface ControlFlowGraph {
    blocks: BasicBlock[];
    entryId: number;
    /** Map from instruction index to owning block id. */
    blockAt: Map<number, number>;
}
/**
 * Build the CFG for a proto. Instructions that are the target of a jump
 * start a new block; every block terminator ends one.
 */
export declare function buildControlFlowGraph(proto: LuauProto): ControlFlowGraph;
/** A back edge (target dominates source) marks a loop header. */
export declare function findLoopHeaders(cfg: ControlFlowGraph): Set<number>;
