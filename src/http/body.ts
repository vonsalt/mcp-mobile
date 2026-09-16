import type { IncomingMessage } from "http";
export function readBody(req: IncomingMessage): Promise<string> {
    return new Promise((resolve, reject) => {
        let body = "";
        req.on("data", (chunk: Buffer) => {
            body += chunk.toString();
        });
        req.on("end", () => resolve(body));
        req.on("error", reject);
    });
}
export async function readJsonBody<T>(req: IncomingMessage): Promise<T> {
    const raw = await readBody(req);
    return raw ? (JSON.parse(raw) as T) : ({} as T);
}
