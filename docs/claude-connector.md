# Claude Remote Connector Guide

This guide explains how to connect a **public HTTPS deployment** of Roblox Executor MCP to Claude through a remote MCP connector. It applies to Railway, Render, a custom domain, or a public HTTPS tunnel.

> Local Claude Desktop configuration using `claude_desktop_config.json` is a separate stdio workflow. For that workflow, see [Claude Desktop Setup](setup-claude-desktop.md).

## Before You Begin

Your server must be reachable from the public internet. Claude connects to remote MCP servers from Anthropic's cloud infrastructure rather than from the device running Claude, so a private LAN address, a VPN-only address, or `localhost` will not work for this setup. [1]

| Requirement | What to use |
|---|---|
| Public server URL | Your own HTTPS deployment URL, such as `https://YOUR-SERVICE.up.railway.app` |
| MCP connector URL | Your public server URL followed by `/mcp` |
| Server secret | A strong `MCP_AUTH_TOKEN` environment variable on the deployment |
| OAuth Client ID / secret | Leave both fields blank for the built-in OAuth flow |
| Roblox client | A running Roblox executor connected to the same public server |

## 1. Deploy the Server

Fork or clone this repository into **your own** GitHub account, then deploy that copy to Railway, Render, or another HTTPS-capable host. Do not copy another person's Railway domain or OAuth configuration.

Set one service variable before connecting Claude:

```text
MCP_AUTH_TOKEN=use-a-long-random-private-value
```

The server derives its protected-resource metadata, authorization-server metadata, OAuth endpoints, and MCP authentication challenge from the public host that receives the request. A normal clone does **not** need `PUBLIC_BASE_URL`, an OAuth Client ID, or an OAuth Client Secret.

## 2. Verify the Deployment

Replace `YOUR_HOST` below with your own public host. Before adding the connector, open:

```text
https://YOUR_HOST/.well-known/oauth-protected-resource/mcp
```

It must return JSON with values that use the **same host** as your deployment:

```json
{
  "resource": "https://YOUR_HOST/mcp",
  "authorization_servers": ["https://YOUR_HOST"]
}
```

Also open:

```text
https://YOUR_HOST/.well-known/oauth-authorization-server
```

It must return JSON including `authorization_endpoint`, `token_endpoint`, and `registration_endpoint`. These endpoints implement the MCP authorization discovery flow that remote clients use. [2]

## 3. Add the Connector in Claude

For an individual Claude account, open **Customize → Connectors**, select **+**, and choose **Add custom connector**. On a Team or Enterprise workspace, an Owner must first add the connector under **Organization settings → Connectors → Add → Custom → Web**. [1]

Enter the following values:

| Claude field | Value |
|---|---|
| Name | `Roblox MCP` |
| Remote MCP server URL | `https://YOUR_HOST/mcp` |
| OAuth Client ID | Leave blank |
| OAuth Client Secret | Leave blank |

Select **Add**, then select **Connect**. When the Roblox MCP authorization page opens, enter the exact `MCP_AUTH_TOKEN` configured on the server and select **Authorize Roblox MCP**.

> Do **not** append `?token=` to the connector URL. Do **not** paste the long-lived `MCP_AUTH_TOKEN` into Claude's connector fields. The OAuth sign-in exchanges it for a short-lived access token instead.

Claude should then display the connector as **Connected** and show the available tools.

## 4. Connect a Roblox Client

The Claude connector can authenticate successfully even when no Roblox client is currently attached. Tool calls require a live Roblox client, so configure the mobile bridge with the same deployment origin and server token:

```lua
getgenv().BridgeURL = "https://YOUR_HOST"
getgenv().MCP_AUTH_TOKEN = "YOUR_MCP_AUTH_TOKEN"
loadstring(game:HttpGet("https://YOUR_HOST/mobile-connector.luau"))()
```

Use your own HTTPS deployment host in all three locations. For local PC setups, use the local loader instructions in the [main README](../README.md).

## 5. Test the End-to-End Connection

Open a new Claude conversation, select **+ → Connectors**, and enable **Roblox MCP** for that conversation. Start with a read-only request:

> Use Roblox MCP to call `list-clients`. Do not execute code or make any changes.

If Claude returns a client, run a second read-only request:

> Use Roblox MCP to call `get-game-info`. Do not execute code or make any changes.

| Result | Meaning | Next step |
|---|---|---|
| Tools appear and `list-clients` returns a client | The Claude, server, and Roblox bridge path is working | Use read-only tools first, then enable only the tools you need |
| Connector is connected but Claude reports no client | OAuth works; the Roblox bridge is not connected | Recheck `BridgeURL` and `MCP_AUTH_TOKEN` in the executor loader |
| Claude reports Unauthorized | OAuth authorization is stale or the token was entered incorrectly | Disconnect the connector, add `https://YOUR_HOST/mcp` again, and authorize with the current token |
| Claude reports it could not register | The host is serving old or mismatched metadata | Check both well-known URLs above and redeploy the latest `main` branch |

## Tool Permissions and Safety

A remote MCP connector can expose both read-only and state-changing tools. In Claude's connector settings, set high-impact tools such as **Execute Code**, **Execute a Luau file**, remote interception, and other write-capable actions to **Ask every time** unless you explicitly trust the current task and conversation. Claude also recommends connecting only to servers you trust and reviewing tool permissions carefully. [1]

## References

[1]: https://support.claude.com/en/articles/11175166-get-started-with-custom-connectors-using-remote-mcp "Get started with custom connectors using remote MCP"
[2]: https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization "Model Context Protocol Authorization"
