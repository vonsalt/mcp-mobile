import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
export declare function createMcpServer(): McpServer;
interface McpSession {
    transport: StreamableHTTPServerTransport;
    server: McpServer;
    createdAt: number;
    lastUsed: number;
}
export declare function createSession(): McpSession;
export declare function getSession(sessionId: string): McpSession | undefined;
export declare function deleteSession(sessionId: string): boolean;
export declare function activeSessionCount(): number;
export {};
