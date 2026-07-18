import express, { Request, Response } from "express";
import { randomUUID } from "node:crypto";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { isInitializeRequest } from "@modelcontextprotocol/sdk/types.js";

const UPTIME_KUMA_METRICS_URL =
  process.env.UPTIME_KUMA_METRICS_URL || "http://192.168.1.20:3001/metrics";
const UPTIME_KUMA_API_KEY = process.env.UPTIME_KUMA_API_KEY;
const MCP_PORT = process.env.MCP_PORT ? parseInt(process.env.MCP_PORT, 10) : 3100;

const STATUS_BY_INDEX = ["down", "up", "pending", "maintenance"] as const;

interface MonitorStatus {
  name: string;
  status: (typeof STATUS_BY_INDEX)[number];
}

// Same Prometheus text-format parsing approach used in the n8n alerting
// design — pulls the "monitor_status{...} N" lines out of Uptime Kuma's
// /metrics endpoint. See Docs/LessonsLearned.md (2026-07-15) for the raw
// format this is parsing.
async function getMonitorStatuses(): Promise<MonitorStatus[]> {
  if (!UPTIME_KUMA_API_KEY) {
    throw new Error("UPTIME_KUMA_API_KEY is not set");
  }

  const res = await fetch(UPTIME_KUMA_METRICS_URL, {
    headers: {
      Authorization: "Basic " + Buffer.from(`:${UPTIME_KUMA_API_KEY}`).toString("base64"),
    },
  });

  if (!res.ok) {
    throw new Error(`Uptime Kuma metrics request failed: ${res.status} ${res.statusText}`);
  }

  const text = await res.text();
  const results: MonitorStatus[] = [];

  for (const line of text.split("\n")) {
    if (!line.startsWith("monitor_status{")) continue;
    const nameMatch = line.match(/monitor_name="([^"]+)"/);
    const valueMatch = line.match(/}\s+(\d+)\s*$/);
    if (nameMatch && valueMatch) {
      const idx = parseInt(valueMatch[1], 10);
      results.push({ name: nameMatch[1], status: STATUS_BY_INDEX[idx] ?? "pending" });
    }
  }

  return results;
}

// A fresh McpServer instance is created per session (see the POST handler
// below) rather than shared globally — matches the pattern in the official
// SDK's own streamable-http example.
function buildServer(): McpServer {
  const server = new McpServer({ name: "homelab-uptime-kuma", version: "1.0.0" });

  server.registerTool(
    "get_service_status",
    {
      title: "Get Homelab Service Status",
      description:
        "Returns the current up/down status of every service monitored by Uptime Kuma in Kyle's homelab (Proxmox, n8n, Portainer, TrueNAS, Plex, etc.)",
      inputSchema: {},
    },
    async () => {
      const statuses = await getMonitorStatuses();
      const down = statuses.filter((s) => s.status === "down");

      const summary =
        down.length === 0
          ? `All ${statuses.length} monitored services are up.`
          : `${down.length} service(s) down: ${down.map((s) => s.name).join(", ")}.`;

      const detail = statuses.map((s) => `- ${s.name}: ${s.status}`).join("\n");

      return {
        content: [{ type: "text" as const, text: `${summary}\n\nFull status:\n${detail}` }],
      };
    },
  );

  return server;
}

const app = express();
app.use(express.json());

// Streamable HTTP is session-based: the first request (an MCP "initialize")
// has no session ID yet, so a new transport + McpServer pair gets created
// and keyed by a generated session ID. Every subsequent request from that
// same client carries an `Mcp-Session-Id` header and reuses the same
// transport. This map is in-memory, so restarting the container drops any
// active sessions — acceptable for a homelab tool, not for something with
// real uptime requirements.
const transports: Record<string, StreamableHTTPServerTransport> = {};

async function handleMcpPost(req: Request, res: Response): Promise<void> {
  const sessionId = req.headers["mcp-session-id"] as string | undefined;

  try {
    let transport: StreamableHTTPServerTransport;

    if (sessionId && transports[sessionId]) {
      transport = transports[sessionId];
    } else if (!sessionId && isInitializeRequest(req.body)) {
      transport = new StreamableHTTPServerTransport({
        sessionIdGenerator: () => randomUUID(),
        onsessioninitialized: (sid) => {
          transports[sid] = transport;
        },
      });

      transport.onclose = () => {
        if (transport.sessionId) delete transports[transport.sessionId];
      };

      const server = buildServer();
      await server.connect(transport);
      await transport.handleRequest(req, res, req.body);
      return;
    } else {
      res.status(400).json({
        jsonrpc: "2.0",
        error: { code: -32000, message: "Bad Request: No valid session ID provided" },
        id: null,
      });
      return;
    }

    await transport.handleRequest(req, res, req.body);
  } catch (err) {
    console.error("Error handling MCP request:", err);
    if (!res.headersSent) {
      res.status(500).json({
        jsonrpc: "2.0",
        error: { code: -32603, message: "Internal server error" },
        id: null,
      });
    }
  }
}

async function handleSessionRequest(req: Request, res: Response): Promise<void> {
  const sessionId = req.headers["mcp-session-id"] as string | undefined;
  if (!sessionId || !transports[sessionId]) {
    res.status(400).send("Invalid or missing session ID");
    return;
  }
  await transports[sessionId].handleRequest(req, res);
}

app.post("/mcp", handleMcpPost);
app.get("/mcp", handleSessionRequest);
app.delete("/mcp", handleSessionRequest);

app.listen(MCP_PORT, () => {
  console.log(`Homelab MCP server (Uptime Kuma) listening on port ${MCP_PORT}`);
});
