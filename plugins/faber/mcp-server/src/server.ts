#!/usr/bin/env node
/**
 * FABER Event Gateway MCP Server
 *
 * An MCP server that provides workflow event logging capabilities for FABER.
 *
 * Resources:
 * - faber://runs - List all runs
 * - faber://runs/{run_id} - Get run details
 * - faber://runs/{run_id}/events - Get run events
 *
 * Tools:
 * - emit_event - Emit a workflow event
 * - get_run - Get run state and metadata
 * - list_runs - List runs with filters
 * - consolidate_events - Consolidate events to JSONL
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListResourcesRequestSchema,
  ListToolsRequestSchema,
  ReadResourceRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { LocalFilesBackend } from "./backends/local-files.js";
import { EventTypes, FaberEvent, RunMetadata, RunState } from "./types.js";

// Configuration from environment
const BASE_PATH = process.env.FABER_RUNS_PATH || ".fractary/plugins/faber/runs";

// Initialize backend
const backend = new LocalFilesBackend(BASE_PATH);

// Create MCP server
const server = new Server(
  {
    name: "faber-event-gateway",
    version: "1.0.0",
  },
  {
    capabilities: {
      resources: {},
      tools: {},
    },
  }
);

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "emit_event",
        description: "Emit a workflow event to a FABER run",
        inputSchema: {
          type: "object",
          properties: {
            run_id: {
              type: "string",
              description: "Full run identifier (org/project/uuid)",
            },
            type: {
              type: "string",
              description: "Event type",
              enum: EventTypes,
            },
            phase: {
              type: "string",
              description: "Current workflow phase",
              enum: ["frame", "architect", "build", "evaluate", "release"],
            },
            step: {
              type: "string",
              description: "Current step within phase",
            },
            status: {
              type: "string",
              description: "Event status",
              enum: ["started", "completed", "failed", "skipped", "pending"],
            },
            message: {
              type: "string",
              description: "Human-readable event description",
            },
            metadata: {
              type: "object",
              description: "Event-specific metadata",
            },
            artifacts: {
              type: "array",
              description: "Artifacts created or modified",
              items: {
                type: "object",
                properties: {
                  type: { type: "string" },
                  name: { type: "string" },
                  path: { type: "string" },
                  url: { type: "string" },
                },
                required: ["type", "name"],
              },
            },
            duration_ms: {
              type: "number",
              description: "Duration in milliseconds",
            },
            error: {
              type: "object",
              description: "Error information",
              properties: {
                code: { type: "string" },
                message: { type: "string" },
                recoverable: { type: "boolean" },
              },
            },
          },
          required: ["run_id", "type"],
        },
      },
      {
        name: "get_run",
        description: "Get run state and metadata",
        inputSchema: {
          type: "object",
          properties: {
            run_id: {
              type: "string",
              description: "Full run identifier",
            },
            include_events: {
              type: "boolean",
              description: "Include event count",
              default: false,
            },
          },
          required: ["run_id"],
        },
      },
      {
        name: "list_runs",
        description: "List runs with optional filters",
        inputSchema: {
          type: "object",
          properties: {
            work_id: {
              type: "string",
              description: "Filter by work item ID",
            },
            status: {
              type: "string",
              description: "Filter by status",
              enum: ["pending", "in_progress", "completed", "failed"],
            },
            org: {
              type: "string",
              description: "Filter by organization",
            },
            project: {
              type: "string",
              description: "Filter by project",
            },
            limit: {
              type: "number",
              description: "Maximum results",
              default: 20,
            },
          },
        },
      },
      {
        name: "consolidate_events",
        description: "Consolidate run events to JSONL format",
        inputSchema: {
          type: "object",
          properties: {
            run_id: {
              type: "string",
              description: "Run to consolidate",
            },
          },
          required: ["run_id"],
        },
      },
    ],
  };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case "emit_event": {
        const result = await backend.emitEvent(args as Partial<FaberEvent>);
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(result, null, 2),
            },
          ],
        };
      }

      case "get_run": {
        const { run_id, include_events } = args as {
          run_id: string;
          include_events?: boolean;
        };
        const result = await backend.getRun(run_id, include_events);
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(result, null, 2),
            },
          ],
        };
      }

      case "list_runs": {
        const result = await backend.listRuns(args as {
          work_id?: string;
          status?: string;
          org?: string;
          project?: string;
          limit?: number;
        });
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(result, null, 2),
            },
          ],
        };
      }

      case "consolidate_events": {
        const { run_id } = args as { run_id: string };
        const result = await backend.consolidateEvents(run_id);
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(result, null, 2),
            },
          ],
        };
      }

      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({ error: message }, null, 2),
        },
      ],
      isError: true,
    };
  }
});

// List available resources
server.setRequestHandler(ListResourcesRequestSchema, async () => {
  const runs = await backend.listRuns({ limit: 100 });

  const resources = [
    {
      uri: "faber://runs",
      name: "All FABER Runs",
      description: "List of all workflow runs",
      mimeType: "application/json",
    },
  ];

  // Add each run as a resource
  for (const run of runs.runs) {
    resources.push({
      uri: `faber://runs/${run.run_id}`,
      name: `Run ${run.run_id.split("/").pop()}`,
      description: `Work #${run.work_id} - ${run.status}`,
      mimeType: "application/json",
    });
    resources.push({
      uri: `faber://runs/${run.run_id}/events`,
      name: `Events for ${run.run_id.split("/").pop()}`,
      description: `Event log for run`,
      mimeType: "application/json",
    });
  }

  return { resources };
});

// Read resource content
server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
  const { uri } = request.params;

  // Parse URI
  const match = uri.match(/^faber:\/\/runs(?:\/(.+?))?(?:\/(events))?$/);
  if (!match) {
    throw new Error(`Invalid resource URI: ${uri}`);
  }

  const [, runId, eventsPath] = match;

  if (!runId) {
    // List all runs
    const result = await backend.listRuns({ limit: 100 });
    return {
      contents: [
        {
          uri,
          mimeType: "application/json",
          text: JSON.stringify(result, null, 2),
        },
      ],
    };
  }

  if (eventsPath === "events") {
    // Get run events
    const events = await backend.getEvents(runId);
    return {
      contents: [
        {
          uri,
          mimeType: "application/json",
          text: JSON.stringify(events, null, 2),
        },
      ],
    };
  }

  // Get run details
  const result = await backend.getRun(runId, true);
  return {
    contents: [
      {
        uri,
        mimeType: "application/json",
        text: JSON.stringify(result, null, 2),
      },
    ],
  };
});

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("FABER Event Gateway MCP server started");
}

main().catch((error) => {
  console.error("Server error:", error);
  process.exit(1);
});
