/**
 * VoidHub decompiler — stage 2: control-flow graph.
 *
 * Splits a proto's instruction stream into basic blocks using jump
 * targets and fallthrough, then classifies edges so the structurer can
 * recover loops and conditionals.
 */

import { decodeInstructions, IS_BLOCK_TERMINATOR, IS_JUMP, IS_UNCONDITIONAL_JUMP, type DecodedInstruction } from "./opcodes.js";
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

function jumpTarget(instruction: DecodedInstruction): number | undefined {
    if (!IS_JUMP.has(instruction.opName))
        return undefined;
    const operand = instruction.opName === "JUMP" || instruction.opName === "JUMPBACK"
        ? instruction.d
        : instruction.e;
    return instruction.index + 1 + operand;
}

/**
 * Build the CFG for a proto. Instructions that are the target of a jump
 * start a new block; every block terminator ends one.
 */
export function buildControlFlowGraph(proto: LuauProto): ControlFlowGraph {
    const instructions = decodeInstructions(proto.code);
    const leaders = new Set<number>();
    if (instructions.length > 0)
        leaders.add(0);

    for (const instruction of instructions) {
        const target = jumpTarget(instruction);
        if (target !== undefined) {
            if (target >= 0 && target < proto.code.length)
                leaders.add(target);
        }
        // The instruction after a terminator also leads a block.
        if (IS_BLOCK_TERMINATOR.has(instruction.opName)) {
            const next = instruction.index + (instruction.aux !== undefined ? 2 : 1);
            if (next < proto.code.length)
                leaders.add(next);
        }
    }

    const sortedLeaders = [...leaders].sort((a, b) => a - b);
    const blocks: BasicBlock[] = sortedLeaders.map((start, i) => ({
        id: i,
        start,
        end: i + 1 < sortedLeaders.length ? sortedLeaders[i + 1]! : proto.code.length,
        instructions: [],
        successors: [],
        predecessors: [],
    }));

    const blockAt = new Map<number, number>();
    for (const block of blocks) {
        for (let pc = block.start; pc < block.end; pc++)
            blockAt.set(pc, block.id);
    }
    for (const block of blocks) {
        block.instructions = instructions.filter(
            (instruction) => instruction.index >= block.start && instruction.index < block.end,
        );
    }

    const connect = (from: number, to: number): void => {
        const target = blocks[to];
        const source = blocks[from];
        if (target && source && !source.successors.includes(to)) {
            source.successors.push(to);
            target.predecessors.push(from);
        }
    };

    for (const block of blocks) {
        const last = block.instructions.at(-1);
        if (!last)
            continue;
        const lastIndex = last.index + (last.aux !== undefined ? 2 : 1);
        const target = jumpTarget(last);
        if (target !== undefined && blockAt.has(target)) {
            connect(block.id, blockAt.get(target)!);
            // Conditional jumps also fall through.
            if (!IS_UNCONDITIONAL_JUMP.has(last.opName) && blockAt.has(lastIndex))
                connect(block.id, blockAt.get(lastIndex)!);
        }
        else if (IS_BLOCK_TERMINATOR.has(last.opName) && !IS_UNCONDITIONAL_JUMP.has(last.opName)) {
            if (blockAt.has(lastIndex))
                connect(block.id, blockAt.get(lastIndex)!);
        }
        else if (!IS_BLOCK_TERMINATOR.has(last.opName)) {
            if (blockAt.has(lastIndex))
                connect(block.id, blockAt.get(lastIndex)!);
        }
    }

    return { blocks, entryId: 0, blockAt };
}

/** A back edge (target dominates source) marks a loop header. */
export function findLoopHeaders(cfg: ControlFlowGraph): Set<number> {
    const headers = new Set<number>();
    for (const block of cfg.blocks) {
        for (const successor of block.successors) {
            if (successor <= block.id)
                headers.add(successor);
        }
    }
    return headers;
}
