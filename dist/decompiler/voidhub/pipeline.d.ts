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
/** Run the pipeline for one profile. Never throws — failures are reported. */
export declare function runVoidhubPipeline(bytecode: Buffer, profile: VoidhubProfile): VoidhubResult;
