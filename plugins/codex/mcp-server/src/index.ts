#!/usr/bin/env node
/**
 * Fractary Codex MCP Server
 *
 * Exposes codex knowledge base as MCP resources using codex:// URIs.
 * Integrates with local cache from Phases 1 & 2.
 *
 * Usage:
 *   node dist/index.js
 *
 * Environment Variables:
 *   CODEX_CACHE_PATH - Path to codex cache directory (default: ./codex)
 *   CODEX_CONFIG_PATH - Path to configuration file (default: ./.fractary/plugins/codex/config.json)
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListResourcesRequestSchema,
  ListToolsRequestSchema,
  ReadResourceRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import * as fs from "fs/promises";
import * as path from "path";

// Configuration from environment
const CACHE_PATH = process.env.CODEX_CACHE_PATH || "./codex";
const CONFIG_PATH = process.env.CODEX_CONFIG_PATH || "./.fractary/plugins/codex/config.json";
const CACHE_INDEX_PATH = path.join(CACHE_PATH, ".cache-index.json");

interface CacheEntry {
  reference: string;
  path: string;
  source: string;
  cached_at: string;
  expires_at: string;
  ttl_days: number;
  size_bytes: number;
  hash: string;
  last_accessed: string;
}

interface CacheIndex {
  version: string;
  entries: CacheEntry[];
  stats: {
    total_entries: number;
    total_size_bytes: number;
    last_cleanup: string | null;
  };
}

/**
 * Read cache index from filesystem
 */
async function readCacheIndex(): Promise<CacheIndex | null> {
  try {
    const content = await fs.readFile(CACHE_INDEX_PATH, "utf-8");
    return JSON.parse(content) as CacheIndex;
  } catch (error) {
    // Cache index doesn't exist or is invalid
    return null;
  }
}

/**
 * Check if cache entry is fresh (not expired)
 */
function isFresh(entry: CacheEntry): boolean {
  const now = new Date();
  const expiresAt = new Date(entry.expires_at);
  return expiresAt > now;
}

/**
 * Convert cache path to codex:// URI
 */
function pathToUri(cachePath: string): string {
  return `codex://${cachePath}`;
}

/**
 * Convert codex:// URI to cache path
 */
function uriToPath(uri: string): string {
  return uri.replace("codex://", "");
}

/**
 * Main server setup
 */
async function main() {
  const server = new Server(
    {
      name: "fractary-codex",
      version: "1.0.0",
    },
    {
      capabilities: {
        resources: {},
        tools: {},
      },
    }
  );

  /**
   * List all cached resources
   */
  server.setRequestHandler(ListResourcesRequestSchema, async () => {
    const index = await readCacheIndex();

    if (!index || index.entries.length === 0) {
      return {
        resources: [],
      };
    }

    // Return all cached resources (fresh and expired)
    // Claude can decide whether to use expired content
    const resources = index.entries.map((entry) => ({
      uri: pathToUri(entry.path),
      name: entry.reference,
      description: `${entry.source} | ${entry.size_bytes} bytes | ${
        isFresh(entry) ? "fresh" : "expired"
      }`,
      mimeType: "text/markdown",
    }));

    return { resources };
  });

  /**
   * Read a specific resource
   */
  server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
    const uri = request.params.uri;

    if (!uri.startsWith("codex://")) {
      throw new Error(`Invalid URI: ${uri}. Must start with codex://`);
    }

    const relativePath = uriToPath(uri);
    const filePath = path.join(CACHE_PATH, relativePath);

    try {
      const content = await fs.readFile(filePath, "utf-8");

      // Read cache index to get metadata
      const index = await readCacheIndex();
      const entry = index?.entries.find((e) => e.path === relativePath);

      const metadata = entry
        ? {
            source: entry.source,
            cached_at: entry.cached_at,
            expires_at: entry.expires_at,
            fresh: isFresh(entry),
            size_bytes: entry.size_bytes,
          }
        : undefined;

      return {
        contents: [
          {
            uri,
            mimeType: "text/markdown",
            text: content,
            ...(metadata && {
              metadata: JSON.stringify(metadata, null, 2),
            }),
          },
        ],
      };
    } catch (error) {
      throw new Error(
        `Failed to read resource ${uri}: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  });

  /**
   * List available tools
   */
  server.setRequestHandler(ListToolsRequestSchema, async () => {
    return {
      tools: [
        {
          name: "codex_fetch",
          description:
            "Fetch a document from codex knowledge base by reference. Use @codex/project/path format.",
          inputSchema: {
            type: "object",
            properties: {
              reference: {
                type: "string",
                description:
                  "Document reference in @codex/project/path format (e.g., @codex/auth-service/docs/oauth.md)",
              },
              force_refresh: {
                type: "boolean",
                description: "Force refresh from source, bypassing cache",
                default: false,
              },
            },
            required: ["reference"],
          },
        },
        {
          name: "codex_cache_status",
          description: "Get current status of codex cache (entries, size, freshness)",
          inputSchema: {
            type: "object",
            properties: {},
          },
        },
      ],
    };
  });

  /**
   * Handle tool calls
   */
  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;

    if (name === "codex_fetch") {
      // This would invoke the document-fetcher skill
      // For now, return a message that this requires plugin integration
      return {
        content: [
          {
            type: "text",
            text: `The codex_fetch tool requires integration with Claude Code plugins.

Please use the /fractary-codex:fetch command instead:

/fractary-codex:fetch ${args.reference}${args.force_refresh ? " --force-refresh" : ""}

This MCP server currently provides read-only access to cached documents via resources.`,
          },
        ],
      };
    }

    if (name === "codex_cache_status") {
      const index = await readCacheIndex();

      if (!index) {
        return {
          content: [
            {
              type: "text",
              text: "Cache is empty (no index found)",
            },
          ],
        };
      }

      const fresh = index.entries.filter(isFresh).length;
      const expired = index.entries.length - fresh;

      return {
        content: [
          {
            type: "text",
            text: `📦 Codex Cache Status

Total entries: ${index.stats.total_entries}
Total size: ${(index.stats.total_size_bytes / 1024 / 1024).toFixed(2)} MB
Fresh entries: ${fresh}
Expired entries: ${expired}
Last cleanup: ${index.stats.last_cleanup || "never"}`,
          },
        ],
      };
    }

    throw new Error(`Unknown tool: ${name}`);
  });

  // Start server
  const transport = new StdioServerTransport();
  await server.connect(transport);

  console.error("Fractary Codex MCP Server running");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
