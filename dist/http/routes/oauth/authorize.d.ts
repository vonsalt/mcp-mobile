import type { IncomingMessage, ServerResponse } from "node:http";
export declare function GET(req: IncomingMessage, res: ServerResponse, url: URL): void;
export declare function POST(req: IncomingMessage, res: ServerResponse): Promise<void>;
