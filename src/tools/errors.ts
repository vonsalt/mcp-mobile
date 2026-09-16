import type { ToolTextResponse } from "./factory.js";
export const NO_CLIENT_ERROR: ToolTextResponse = {
    content: [
        {
            type: "text",
            text: "No Roblox client connected to the MCP server. Please notify the user that they have to run the connector.luau script in order to connect the MCP server to their game.",
        },
    ],
    isError: true,
};
export const INVALID_CLIENT_ERROR: ToolTextResponse = {
    content: [
        {
            type: "text",
            text: "Invalid client ID provided. Please use the list-clients tool to get a list of valid client IDs.",
        },
    ],
    isError: true,
};
