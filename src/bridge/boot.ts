import { BASE_URL, PROMOTION_JITTER_MAX } from "../config.js";
import { startAsPrimary } from "./handlers/server/primary.js";
import { startAsSecondary } from "./handlers/server/secondary.js";
function tryPromote(): void {
    const jitter = Math.floor(Math.random() * PROMOTION_JITTER_MAX);
    console.error(`[Promote] Waiting ${jitter}ms before attempting promotion...`);
    setTimeout(async () => {
        try {
            await startAsPrimary();
            console.error("[Promote] Successfully promoted to primary!");
        }
        catch {
            console.error("[Promote] Another instance already claimed primary. Reconnecting as secondary...");
            setTimeout(() => startAsSecondary(undefined, undefined, tryPromote), 200);
        }
    }, jitter);
}
export async function boot(): Promise<void> {
    if (BASE_URL) {
        const relayUrl = BASE_URL.replace(/\/$/, "") + "/mcp-relay";
        console.error(`[Boot] --baseurl mode: targeting relay at ${relayUrl}`);
        startAsSecondary(relayUrl, async () => {
            console.error("[Boot] Remote unreachable — starting as primary (fallback).");
            try {
                await startAsPrimary();
                console.error("[Boot] Primary started successfully (fallback from --baseurl).");
            }
            catch (err) {
                const code = (err as NodeJS.ErrnoException | undefined)?.code;
                if (code === "EADDRINUSE") {
                    console.error("[Boot] Port in use locally too — becoming secondary to localhost.");
                    startAsSecondary(undefined, undefined, tryPromote);
                }
                else {
                    console.error("[Boot] Fatal error during fallback primary start:", err);
                    process.exit(1);
                }
            }
        }, tryPromote);
        return;
    }
    try {
        await startAsPrimary();
    }
    catch (err) {
        const code = (err as NodeJS.ErrnoException | undefined)?.code;
        if (code === "EADDRINUSE") {
            startAsSecondary(undefined, undefined, tryPromote);
        }
        else {
            console.error("[Boot] Fatal error:", err);
            process.exit(1);
        }
    }
}
