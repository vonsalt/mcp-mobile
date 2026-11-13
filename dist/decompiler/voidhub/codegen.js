/**
 * VoidHub decompiler — stage 4: code generation.
 *
 * Renders recovered statements as Luau-style source, walking nested
 * protos and inlining closure constants. Debug names are used when the
 * chunk carries them; registers fall back to r0/r1/… naming.
 */
import { structureProto } from "./structurer.js";
const INDENT = "    ";
function renderStatements(statements, depth) {
    const pad = INDENT.repeat(depth);
    const out = [];
    for (const statement of statements) {
        switch (statement.kind) {
            case "comment":
                out.push(`${pad}-- ${statement.text}`);
                break;
            case "label":
                out.push(`${pad}::pc${statement.pc}::`);
                break;
            case "goto":
                out.push(`${pad}goto pc${statement.target}`);
                break;
            case "raw":
                out.push(`${pad}${statement.text}`);
                break;
            case "if":
                out.push(`${pad}if ${statement.condition} then`);
                out.push(...renderStatements(statement.body, depth + 1));
                if (statement.elseBody && statement.elseBody.length > 0) {
                    out.push(`${pad}else`);
                    out.push(...renderStatements(statement.elseBody, depth + 1));
                }
                out.push(`${pad}end`);
                break;
            case "while":
                out.push(`${pad}while ${statement.condition} do`);
                out.push(...renderStatements(statement.body, depth + 1));
                out.push(`${pad}end`);
                break;
            case "repeat":
                out.push(`${pad}repeat`);
                out.push(...renderStatements(statement.body, depth + 1));
                out.push(`${pad}until ${statement.condition}`);
                break;
            case "numericFor":
                out.push(`${pad}for r${statement.register} = ${statement.from}, ${statement.to}, ${statement.step} do`);
                out.push(...renderStatements(statement.body, depth + 1));
                out.push(`${pad}end`);
                break;
            case "genericFor":
                out.push(`${pad}for ${statement.registers.map((r) => `r${r}`).join(", ")} in ${statement.iterator} do`);
                out.push(...renderStatements(statement.body, depth + 1));
                out.push(`${pad}end`);
                break;
        }
    }
    return out;
}
function renderProto(chunk, proto, structured, isMain) {
    const params = Array.from({ length: proto.numParams }, (_, i) => `a${i + 1}`);
    if (proto.isVararg)
        params.push("...");
    const name = isMain
        ? "main"
        : proto.debugName || `proto_${proto.index}`;
    const header = isMain
        ? `-- main function (vararg: ${proto.isVararg ? "yes" : "no"}, params: ${proto.numParams})`
        : `local function ${name}(${params.join(", ")})`;
    const lines = [header];
    lines.push(...renderStatements(structured.statements, 1));
    if (!isMain)
        lines.push("end");
    // Nested closures referenced through constants.
    for (const constant of proto.constants) {
        if (constant.type === "closure") {
            const child = chunk.protos[constant.protoIndex];
            if (child) {
                const childStructured = structureProto(child);
                lines.push("");
                lines.push(...renderProto(chunk, child, childStructured, false).split("\n"));
            }
        }
    }
    return lines.join("\n");
}
/** Render the whole chunk, main proto first. */
export function generateSource(chunk, structuredMain) {
    const banner = [
        "-- Decompiled with VoidHub decompiler (multi-stage)",
        `-- Bytecode version ${chunk.bytecodeVersion}, ${chunk.protos.length} protos, ${chunk.strings.length} strings`,
        "-- Output is register-level pseudo-Luau: r<n> are stack slots.",
        "",
    ];
    const body = renderProto(chunk, chunk.protos[chunk.mainIndex], structuredMain, true);
    return `${banner.join("\n")}\n${body}\n`;
}
