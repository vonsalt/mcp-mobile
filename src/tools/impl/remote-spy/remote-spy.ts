import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendFireAndForget, toolTextResponse } from "../../factory.js";
import { PASTE_VOID_TEXT_ENDPOINT, exportTextToPasteVoid } from "../../../shared/paste-void.js";

const MAX_CAPTURED_LOGS = 500;

/**
 * Escape a value for interpolation into a double-quoted Lua string literal.
 * Backslash must be escaped first, then the quote delimiter and the control
 * characters that would otherwise break out of the literal. JSON.stringify is
 * NOT safe here — it can emit \uXXXX escapes that Lua does not understand.
 */
function escapeLuaDoubleQuotedString(value: string): string {
    return value
        .replace(/\\/g, "\\\\")
        .replace(/"/g, '\\"')
        .replace(/\n/g, "\\n")
        .replace(/\r/g, "\\r")
        .replace(/\t/g, "\\t");
}

function buildCaptureScript(duration: number, nameFilter: string | undefined): string {
    const filter = nameFilter ? escapeLuaDoubleQuotedString(nameFilter) : "";
    return `
setthreadidentity(8)
local logs = {}
local startTime = os.clock()
local DURATION = ${duration}
local MAX_LOGS = ${MAX_CAPTURED_LOGS}
local NAME_FILTER = ${nameFilter ? `"${filter}"` : "nil"}

local function escStr(s)
    return tostring(s):gsub('\\\\', '\\\\\\\\'):gsub('"', '\\\\"'):gsub('\\n', '\\\\n'):gsub('\\r', '\\\\r'):gsub('\\t', '\\\\t')
end

local function serialize(v, d)
    d = d or 0
    if d > 4 then return '"[max depth]"' end
    local t = type(v)
    if t == "nil" then return "null"
    elseif t == "boolean" then return tostring(v)
    elseif t == "number" then
        if v ~= v then return '"NaN"' end
        return tostring(v)
    elseif t == "string" then return '"' .. escStr(v) .. '"'
    elseif t == "table" then
        local arr = {}
        for i = 1, #v do arr[i] = serialize(v[i], d + 1) end
        if #arr > 0 then return "[" .. table.concat(arr, ",") .. "]" end
        local kv = {}
        for k, val in pairs(v) do
            if type(k) == "string" or type(k) == "number" then
                table.insert(kv, '"' .. escStr(tostring(k)) .. '":' .. serialize(val, d + 1))
            end
        end
        return "{" .. table.concat(kv, ",") .. "}"
    else
        return '"[' .. t .. ': ' .. escStr(tostring(v)) .. ']"'
    end
end

local ok, mt = pcall(getrawmetatable, game)
if not ok then print("[MCP-SPY] getrawmetatable not available"); return end
local oldNamecall = mt.__namecall
pcall(setreadonly, mt, false)
mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if method == "FireServer" or method == "InvokeServer" or method == "FireAllClients" or method == "FireClient" then
        local name = tostring(self.Name or self)
        local match = not NAME_FILTER or name:lower():find(NAME_FILTER:lower(), 1, true)
        if match and #logs < MAX_LOGS then
            table.insert(logs, {
                name = name,
                method = method,
                t = math.floor((os.clock() - startTime) * 1000),
                args = {...}
            })
        end
    end
    return oldNamecall(self, ...)
end)
pcall(setreadonly, mt, true)

print("[MCP-SPY] Capturing remotes for " .. DURATION .. "s" .. (NAME_FILTER and (" (filter: " .. NAME_FILTER .. ")") or "") .. "...")

task.delay(DURATION, function()
    pcall(setreadonly, mt, false)
    mt.__namecall = oldNamecall
    pcall(setreadonly, mt, true)

    local entries = {}
    for _, log in ipairs(logs) do
        local argParts = {}
        for _, a in ipairs(log.args) do
            table.insert(argParts, serialize(a))
        end
        table.insert(entries, string.format(
            '{"name":%s,"method":%s,"t":%d,"args":[%s]}',
            serialize(log.name), serialize(log.method), log.t, table.concat(argParts, ",")
        ))
    end
    local jsonBody = '[' .. table.concat(entries, ',') .. ']'

    local uploadOk, result = pcall(request, {
        Url = "${PASTE_VOID_TEXT_ENDPOINT}",
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = '{"content":' .. serialize(jsonBody) .. ',"language":"json","title":"remote-spy-capture"}'
    })

    if uploadOk and result and result.Body then
        local rawUrl = result.Body:match('"rawUrl":"([^"]+)"')
        if rawUrl then
            print("[MCP-SPY] Results (" .. #logs .. " remotes): " .. rawUrl)
        else
            print("[MCP-SPY] Upload response: " .. tostring(result.Body):sub(1, 300))
        end
    else
        print("[MCP-SPY] Upload failed: " .. tostring(result))
        print("[MCP-SPY] Inline fallback (" .. #logs .. " captured):")
        for i = 1, math.min(10, #logs) do
            local l = logs[i]
            print(string.format("  [%dms] %s %s", l.t, l.method, l.name))
        end
    end
end)
`;
}

export default function register(server: McpServer): void {
    server.registerTool("remote-spy", {
        title: "Capture Roblox remote calls",
        description:
            "Captures remote calls (FireServer, InvokeServer) on the Roblox client. " +
            "Injects a spy script, captures for the given duration, uploads results to paste-void.lovable.app, " +
            "and prints the rawUrl to console. After the duration, call get-console-output and look for " +
            "'[MCP-SPY] Results' — that line contains the paste-void URL to fetch for full results.",
        inputSchema: z.object({
            duration: z
                .number()
                .int()
                .min(1)
                .max(600)
                .optional()
                .default(10)
                .describe("Seconds to capture remote calls (default: 10, range 1-600)"),
            nameFilter: z
                .string()
                .optional()
                .describe("Only capture remotes whose name contains this substring (case-insensitive)"),
        }),
    }, async ({ duration, nameFilter }) => {
        const script = buildCaptureScript(duration, nameFilter);

        const upload = await exportTextToPasteVoid(script, "mcp-remote-spy", "lua");
        if (!upload.ok || !upload.url) {
            return toolTextResponse(
                `Failed to upload capture script to paste-void: ${upload.error ?? "no raw URL in response"}. ` +
                    "The remote spy was not injected — check paste-void availability and retry.",
                {},
                true,
            );
        }

        const rawUrl = upload.url;
        const loadstringSource = `setthreadidentity(8)\nloadstring(game:HttpGet("${rawUrl}"))()`;

        return sendFireAndForget({
            type: "execute",
            data: { source: loadstringSource },
            successMessage:
                `Remote spy injected (duration: ${duration}s${nameFilter ? `, filter: ${nameFilter}` : ""}). ` +
                `After ${duration}s, call get-console-output and look for "[MCP-SPY] Results" — ` +
                `that line has the paste-void rawUrl with all captured remote calls.`,
        });
    });
}
