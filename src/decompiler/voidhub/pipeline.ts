/**
 * VoidHub decompiler — pipeline orchestrator.
 *
 * Runs the multi-stage decompiler against a raw bytecode buffer:
 *   stage 0: parse (lbc)
 *   stage 1: disassembly (disasm)
 *   stage 2: control-flow graph (cfg)
 *   stage 3: structure recovery (structurer)
 *   stage 4: code generation (codegen)
 *
 * Profiles control how far the pipeline runs:
 *   - "disasm":    stage 1 only. Fastest, always succeeds.
 *   - "balanced":  stages 0-2 plus per-block pseudo-code.
 *   - "structured": full pipeline — loops, conditionals, nested protos.
 */

import { parseLuauBytecode, type LuauChunk, type LuauProto } from "./lbc.js";
import { disassembleChunk } from "./disasm.js";
import { buildControlFlowGraph, findLoopHeaders } from "./cfg.js";
import { structureProto, type StructuredProto, type Statement } from "./structurer.js";
import { generateSource } from "./codegen.js";
import { decodeInstructions } from "./opcodes.js";

export type VoidhubProfile = "disasm" | "balanced" | "structured";

export interface StageReport {
    name: string;
    ok: boolean;
    detail: string;
    durationMs: number;
}

export interface VoidhubResult {
    ok: boolean;
    source?: string;
    error?: string;
    profile: VoidhubProfile;
    stages: StageReport[];
    protoCount: number;
    instructionCount: number;
    structuredRatio: number;
}

function countInstructions(chunk: LuauChunk): number {
    return chunk.protos.reduce((sum, proto) => sum + decodeInstructions(proto.code).length, 0);
}

/** Walk protos in a stable order: main first, then children depth-first. */
function orderedProtos(chunk: LuauChunk): LuauProto[] {
    const out: LuauProto[] = [];
    const walk = (index: number): void => {
        const proto = chunk.protos[index];
        if (!proto)
            return;
        out.push(proto);
        for (const child of proto.children)
            walk(child);
    };
    walk(chunk.mainIndex);
    for (const proto of chunk.protos) {
        if (!out.includes(proto))
            out.push(proto);
    }
    return out;
}

/** Balanced profile: per-block pseudo-code with explicit gotos. */
function renderBalanced(chunk: LuauChunk): string {
    const lines: string[] = [
        "-- Decompiled with VoidHub decompiler (balanced profile)",
        `-- Bytecode version ${chunk.bytecodeVersion}, ${chunk.protos.length} protos`,
        "",
    ];
    for (const proto of orderedProtos(chunk)) {
        const cfg = buildControlFlowGraph(proto);
        const loopHeaders = findLoopHeaders(cfg);
        const name = proto.debugName || `proto_${proto.index}`;
        lines.push(`function ${name}() -- ${proto.code.length} words`);
        for (const block of cfg.blocks) {
            lines.push(`    ::block_${block.id}::`);
            for (const instruction of block.instructions) {
                const target = instruction.opName.startsWith("JUMPIF") || instruction.opName.startsWith("JUMP")
                    ? `${instruction.index + 1 + instruction.e}`
                    : undefined;
                lines.push(
                    target !== undefined && target !== ""
                        ? `    -- pc${instruction.index}: ${instruction.opName} -> ${target}`
                        : `    -- pc${instruction.index}: ${instruction.opName}`,
                );
            }
            if (loopHeaders.has(block.id))
                lines.push("    -- ^ loop header");
        }
        lines.push("end");
        lines.push("");
    }
    return lines.join("\n");
}

function renderStructured(chunk: LuauChunk): { source: string; ratio: number } {
    const main = chunk.protos[chunk.mainIndex]!;
    const structured = structureProto(main);
    const source = generateSource(chunk, structured);
    return { source, ratio: structured.structuredRatio };
}

/** Run the pipeline for one profile. Never throws — failures are reported. */
export function runVoidhubPipeline(bytecode: Buffer, profile: VoidhubProfile): VoidhubResult {
    const stages: StageReport[] = [];
    const track = <T>(name: string, run: () => T): T | undefined => {
        const startedAt = Date.now();
        try {
            const value = run();
            stages.push({ name, ok: true, detail: "ok", durationMs: Date.now() - startedAt });
            return value;
        }
        catch (error) {
            stages.push({
                name,
                ok: false,
                detail: error instanceof Error ? error.message : String(error),
                durationMs: Date.now() - startedAt,
            });
            return undefined;
        }
    };

    const chunk = track("parse", () => parseLuauBytecode(bytecode));
    if (!chunk) {
        return {
            ok: false,
            error: stages.find((stage) => !stage.ok)?.detail ?? "Unknown parse failure",
            profile,
            stages,
            protoCount: 0,
            instructionCount: 0,
            structuredRatio: 0,
        };
    }

    const instructionCount = countInstructions(chunk);

    if (profile === "disasm") {
        const source = track("disassemble", () => disassembleChunk(chunk));
        if (source === undefined) {
            return {
                ok: false,
                error: "Disassembly stage failed",
                profile,
                stages,
                protoCount: chunk.protos.length,
                instructionCount,
                structuredRatio: 0,
            };
        }
        return {
            ok: true,
            source,
            profile,
            stages,
            protoCount: chunk.protos.length,
            instructionCount,
            structuredRatio: 0,
        };
    }

    if (profile === "balanced") {
        const source = track("balance", () => renderBalanced(chunk));
        if (source === undefined) {
            // Fall back to plain disassembly rather than failing.
            const disasm = track("disassemble-fallback", () => disassembleChunk(chunk));
            return {
                ok: disasm !== undefined,
                source: disasm,
                error: disasm === undefined ? "Balanced profile failed" : undefined,
                profile,
                stages,
                protoCount: chunk.protos.length,
                instructionCount,
                structuredRatio: 0,
            };
        }
        return {
            ok: true,
            source,
            profile,
            stages,
            protoCount: chunk.protos.length,
            instructionCount,
            structuredRatio: 0,
        };
    }

    // structured profile: full pipeline with graceful degradation.
    const structured = track("structure", () => renderStructured(chunk));
    if (structured === undefined) {
        const balanced = track("balanced-fallback", () => renderBalanced(chunk));
        const source = balanced ?? disassembleChunk(chunk);
        return {
            ok: source !== undefined,
            source,
            error: structured === undefined && balanced === undefined ? "Structured profile failed" : undefined,
            profile,
            stages,
            protoCount: chunk.protos.length,
            instructionCount,
            structuredRatio: 0,
        };
    }

    return {
        ok: true,
        source: structured.source,
        profile,
        stages,
        protoCount: chunk.protos.length,
        instructionCount,
        structuredRatio: structured.ratio,
    };
}
