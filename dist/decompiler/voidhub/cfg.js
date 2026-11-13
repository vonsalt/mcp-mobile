/**
 * VoidHub decompiler — stage 2: control-flow graph.
 *
 * Splits a proto's instruction stream into basic blocks using jump
 * targets and fallthrough, then classifies edges so the structurer can
 * recover loops and conditionals.
 */
import { decodeInstructions, IS_BLOCK_TERMINATOR, IS_UNCONDITIONAL_JUMP, jumpTargetPc } from "./opcodes.js";
/**
 * Build the CFG for a proto. Instructions that are the target of a jump
 * start a new block; every block terminator ends one.
 */
export function buildControlFlowGraph(proto) {
    const instructions = decodeInstructions(proto.code);
    const leaders = new Set();
    if (instructions.length > 0)
        leaders.add(0);
    for (const instruction of instructions) {
        const target = jumpTargetPc(instruction);
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
    const blocks = sortedLeaders.map((start, i) => ({
        id: i,
        start,
        end: i + 1 < sortedLeaders.length ? sortedLeaders[i + 1] : proto.code.length,
        instructions: [],
        successors: [],
        predecessors: [],
    }));
    const blockAt = new Map();
    for (const block of blocks) {
        for (let pc = block.start; pc < block.end; pc++)
            blockAt.set(pc, block.id);
    }
    for (const block of blocks) {
        block.instructions = instructions.filter((instruction) => instruction.index >= block.start && instruction.index < block.end);
    }
    const connect = (from, to) => {
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
        const target = jumpTargetPc(last);
        if (target !== undefined && blockAt.has(target)) {
            connect(block.id, blockAt.get(target));
            // Conditional jumps also fall through.
            if (!IS_UNCONDITIONAL_JUMP.has(last.opName) && blockAt.has(lastIndex))
                connect(block.id, blockAt.get(lastIndex));
        }
        else if (IS_BLOCK_TERMINATOR.has(last.opName) && !IS_UNCONDITIONAL_JUMP.has(last.opName)) {
            if (blockAt.has(lastIndex))
                connect(block.id, blockAt.get(lastIndex));
        }
        else if (!IS_BLOCK_TERMINATOR.has(last.opName)) {
            if (blockAt.has(lastIndex))
                connect(block.id, blockAt.get(lastIndex));
        }
    }
    return { blocks, entryId: 0, blockAt };
}
/** A back edge (target dominates source) marks a loop header. */
export function findLoopHeaders(cfg) {
    const headers = new Set();
    for (const block of cfg.blocks) {
        for (const successor of block.successors) {
            if (successor <= block.id)
                headers.add(successor);
        }
    }
    return headers;
}
