import type { IncomingMessage, ServerResponse } from "http";
export async function GET(_req: IncomingMessage, res: ServerResponse, url: URL): Promise<void> {
    const userId = url.searchParams.get("userId");
    if (!userId) {
        res.writeHead(400);
        res.end("Missing userId");
        return;
    }
    try {
        const robloxRes = await fetch(`https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=${encodeURIComponent(userId)}&size=150x150&format=Png&isCircular=false`);
        const json = (await robloxRes.json()) as {
            data?: {
                imageUrl?: string;
            }[];
        };
        const imageUrl = json.data?.[0]?.imageUrl;
        if (imageUrl) {
            res.writeHead(302, { Location: imageUrl, "Cache-Control": "public, max-age=300" });
            res.end();
        }
        else {
            res.writeHead(404);
            res.end("No thumbnail found");
        }
    }
    catch {
        res.writeHead(502);
        res.end("Failed to fetch thumbnail");
    }
}
