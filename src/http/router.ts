import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import type { IncomingMessage, ServerResponse } from "http";
import type { WebSocket } from "ws";
import { HTTP_METHODS, type HttpMethod, type RouteHandler, type WsRouteHandler, } from "./types.js";
import { isAuthorizedLocalAdminRequest } from "./local-admin.js";
import { writeAuthorizationServerMetadata, writeProtectedResourceMetadata } from "../oauth/mcp-oauth.js";
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const routesDir = path.join(__dirname, "routes");
interface RegisteredHttpRoute {
    method: HttpMethod;
    path: string;
    handler: RouteHandler;
}
interface RegisteredWsRoute {
    path: string;
    handler: WsRouteHandler;
}
const httpRoutes: RegisteredHttpRoute[] = [];
const wsRoutes: RegisteredWsRoute[] = [];
let defaultWsHandler: WsRouteHandler | null = null;
const WS_FALLBACK_NAME = "_ws-fallback";
const LOCAL_ADMIN_API_ROUTES = new Set([
    "/api/client-setup",
    "/api/dashboard-settings",
    "/api/decompiler-settings",
    "/api/decompiler-settings/connector",
    "/api/decompiler-settings/setup",
    "/api/semantic-settings",
    "/api/semantic-settings/test",
]);
export function requiresLocalAdmin(req: IncomingMessage, pathname: string): boolean {
    if (LOCAL_ADMIN_API_ROUTES.has(pathname))
        return true;
    if (pathname === "/api/server-logs" && req.method === "DELETE")
        return true;
    return pathname === "/api/scripts/source" && req.method === "PUT";
}
async function walk(dir: string): Promise<string[]> {
    const out: string[] = [];
    const entries = await fs.promises.readdir(dir, { withFileTypes: true });
    for (const entry of entries) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) {
            out.push(...(await walk(full)));
        }
        else if (entry.isFile() && entry.name.endsWith(".js")) {
            out.push(full);
        }
    }
    return out;
}
const GROUP_SEGMENT = /^\(.+\)$/;
function fileToUrlPath(file: string): string {
    const rel = path.relative(routesDir, file);
    const parsed = path.parse(rel);
    const segments = parsed.dir
        ? parsed.dir.split(path.sep).filter((seg) => !GROUP_SEGMENT.test(seg))
        : [];
    const dir = segments.join("/");
    const name = parsed.name;
    if (!dir && name === "index")
        return "/";
    if (name === "index")
        return "/" + dir;
    return "/" + (dir ? `${dir}/${name}` : name);
}
let loadPromise: Promise<void> | null = null;
export function loadRoutes(): Promise<void> {
    if (loadPromise)
        return loadPromise;
    loadPromise = (async () => {
        const files = await walk(routesDir);
        for (const file of files) {
            const base = path.basename(file, path.extname(file));
            const isReserved = base.startsWith("_");
            const isFallback = base === WS_FALLBACK_NAME;
            if (isReserved && !isFallback)
                continue;
            const mod = (await import(pathToFileURL(file).href)) as Record<string, unknown>;
            if (isFallback) {
                if (typeof mod.WS === "function") {
                    defaultWsHandler = mod.WS as WsRouteHandler;
                }
                else {
                    console.error(`[Router] ${WS_FALLBACK_NAME} must export a WS handler. Skipping.`);
                }
                continue;
            }
            const urlPath = fileToUrlPath(file);
            let registered = false;
            for (const method of HTTP_METHODS) {
                const handler = mod[method];
                if (typeof handler === "function") {
                    httpRoutes.push({ method, path: urlPath, handler: handler as RouteHandler });
                    registered = true;
                }
            }
            if (typeof mod.WS === "function") {
                wsRoutes.push({ path: urlPath, handler: mod.WS as WsRouteHandler });
                registered = true;
            }
            if (!registered) {
                console.error(`[Router] ${file} exports no recognized method handlers (GET/POST/…/WS). Skipping.`);
            }
        }
        console.error(`[Router] Loaded ${httpRoutes.length} HTTP route(s), ${wsRoutes.length} WS route(s)` +
            (defaultWsHandler ? " + WS fallback" : "") +
            ".");
    })();
    return loadPromise;
}
export async function dispatchHttp(req: IncomingMessage, res: ServerResponse): Promise<void> {
    const url = new URL(req.url || "/", `http://localhost`);
    if (requiresLocalAdmin(req, url.pathname) &&
        !isAuthorizedLocalAdminRequest(req)) {
        res.writeHead(403, { "Content-Type": "application/json", "Cache-Control": "no-store" });
        res.end(JSON.stringify({ error: "Authorized local dashboard access required." }));
        return;
    }
    // Dot-prefixed route directories are not emitted by TypeScript's include glob,
    // so keep standards-mandated well-known endpoints explicit in the router.
    if (req.method === "GET" && url.pathname === "/.well-known/oauth-protected-resource/mcp") {
        writeProtectedResourceMetadata(req, res);
        return;
    }
    if (req.method === "GET" && url.pathname === "/.well-known/oauth-authorization-server") {
        writeAuthorizationServerMetadata(req, res);
        return;
    }
    for (const route of httpRoutes) {
        if (route.path === url.pathname && route.method === req.method) {
            try {
                await route.handler(req, res, url);
            }
            catch (err) {
                console.error(`[Router] Handler error for ${req.method} ${url.pathname}:`, err);
                if (!res.headersSent) {
                    res.writeHead(500);
                    res.end("Internal server error");
                }
            }
            return;
        }
    }
    res.writeHead(200);
    res.end("MCP Server Running");
}
export function dispatchWs(ws: WebSocket, req: IncomingMessage): void {
    const urlPath = req.url || "/";
    const match = wsRoutes.find((r) => r.path === urlPath);
    if (match) {
        match.handler(ws, req);
        return;
    }
    defaultWsHandler?.(ws, req);
}
