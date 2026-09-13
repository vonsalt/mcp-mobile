import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { BASE_URL, WS_PORT } from "../../../config.js";
import { getInstanceRole } from "../../../bridge/handlers/shared/communication.js";
import { isSupported, performScreenshot, type ScreenshotResult, } from "../../../platform/windows-screenshot.js";
export default function register(server: McpServer): void {
    server.registerTool("screenshot-window", {
        title: "Take a screenshot of a Roblox window",
        description: "Capture an actual OS screenshot of a Roblox window via Windows APIs. Returns a downscaled JPEG to limit vision-token cost. Provide pid when multiple windows are open; secondary servers relay capture to the primary host.",
        inputSchema: z.object({
            pid: z
                .number()
                .describe("The PID (process ID) of the Roblox window to capture. If omitted and only one Roblox window exists, it is captured automatically. If multiple windows exist and no pid is provided, the tool returns a list of windows for disambiguation.")
                .optional(),
            maxWidth: z
                .number()
                .describe("Maximum image width in pixels; the screenshot is downscaled to this (default: 1280). Lower values cost fewer vision tokens.")
                .optional()
                .default(1280),
        }),
    }, async ({ pid, maxWidth }) => {
        if (getInstanceRole() === "secondary") {
            try {
                const primaryBase = BASE_URL ? BASE_URL.replace(/\/$/, "") : `http://localhost:${WS_PORT}`;
                const targetUrl = primaryBase + "/api/screenshot";
                const resp = await fetch(targetUrl, {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ pid, maxWidth }),
                });
                const result = (await resp.json()) as ScreenshotResult;
                return renderScreenshotResult(result);
            }
            catch (err) {
                return {
                    content: [
                        {
                            type: "text" as const,
                            text: `Failed to relay screenshot to primary: ${(err as Error).message || err}`,
                        },
                    ],
                    isError: true,
                };
            }
        }
        if (!isSupported()) {
            // Fall back to client-side screenshot for non-Windows platforms
            try {
                const { sendAndWait } = await import("../../factory.js");
                const result = await sendAndWait({
                    type: "client-screenshot",
                    data: { maxWidth, quality: 80 },
                    stampClient: true,
                    maxOutputChars: 32000,
                    failureMessage: () => "Client-side screenshot is not supported by this executor. The screenshot-window tool requires Windows, and the connected executor does not support in-game screenshot capture.",
                });
                if (result.isError) {
                    return result;
                }
                const text = (result.content as any[])
                    ?.filter((c: any) => c.type === "text")
                    .map((c: any) => c.text)
                    .join("");
                if (text) {
                    const match = text.match(/data:image\/([a-z]+);base64,([A-Za-z0-9+/=]+)/);
                    if (match) {
                        return {
                            content: [
                                {
                                    type: "image" as const,
                                    data: match[2],
                                    mimeType: `image/${match[1]}`,
                                },
                            ],
                        };
                    }
                    const match2 = text.match(/"imageBase64":\s*"data:image\/([a-z]+);base64,([A-Za-z0-9+/=]+)/);
                    if (match2) {
                        return {
                            content: [
                                {
                                    type: "image" as const,
                                    data: match2[2],
                                    mimeType: `image/${match2[1]}`,
                                },
                            ],
                        };
                    }
                }
                return result;
            }
            catch (fallbackErr) {
                return {
                    content: [
                        {
                            type: "text" as const,
                            text: "Error: The screenshot-window tool is only available on Windows. The current platform is: " +
                                process.platform +
                                ". Client-side screenshot fallback also failed: " +
                                ((fallbackErr as Error).message || fallbackErr),
                        },
                    ],
                    isError: true,
                };
            }
        }
        try {
            return renderScreenshotResult(performScreenshot(pid, maxWidth));
        }
        catch (err) {
            return {
                content: [
                    {
                        type: "text" as const,
                        text: `Screenshot failed: ${(err as Error).message || err}`,
                    },
                ],
                isError: true,
            };
        }
    });
}
function renderScreenshotResult(result: ScreenshotResult) {
    if (result.error) {
        return {
            content: [{ type: "text" as const, text: result.error }],
            isError: true,
        };
    }
    if (result.needsDisambiguation && result.windows) {
        const listing = result.windows.map((w) => `  • PID ${w.pid} — "${w.title}"`).join("\n");
        return {
            content: [
                {
                    type: "text" as const,
                    text: "Multiple Roblox windows were found. Please re-call this tool with the `pid` parameter set to the correct process:\n\n" +
                        listing,
                },
            ],
        };
    }
    if (result.imageBase64) {
        return {
            content: [
                {
                    type: "image" as const,
                    data: result.imageBase64,
                    mimeType: result.mimeType ?? "image/jpeg",
                },
            ],
        };
    }
    return {
        content: [{ type: "text" as const, text: "Screenshot failed: unexpected result." }],
        isError: true,
    };
}
