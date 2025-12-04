#!/usr/bin/env node
/**
 * Fractary Codex MCP Server v3.0
 *
 * Exposes codex knowledge base as MCP resources using codex:// URIs.
 * Features:
 * - On-demand fetch for missing/expired content
 * - Current project detection for local file resolution
 * - Offline mode support
 * - Unified fetch layer integration (lib/ scripts)
 *
 * Usage:
 *   node dist/index.js
 *
 * Environment Variables:
 *   CODEX_CACHE_PATH   - Path to codex cache directory (default: .fractary/plugins/codex/cache)
 *   CODEX_CONFIG_PATH  - Path to configuration file (default: .fractary/plugins/codex/config.json)
 *   CODEX_CURRENT_ORG  - Override current organization detection
 *   CODEX_CURRENT_PROJECT - Override current project detection
 *   CODEX_LIB_PATH     - Path to lib/ scripts (default: auto-detect from plugin)
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
import { exec, execFile, spawn } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);

// Configuration from environment
const CACHE_PATH = process.env.CODEX_CACHE_PATH || "./.fractary/plugins/codex/cache";
const CONFIG_PATH = process.env.CODEX_CONFIG_PATH || "./.fractary/plugins/codex/config.json";
const CACHE_INDEX_PATH = path.join(CACHE_PATH, "index.json");

// Detect lib path (try various locations)
function getLibPath(): string {
  if (process.env.CODEX_LIB_PATH) {
    return process.env.CODEX_LIB_PATH;
  }

  // Try relative to this script (when running from mcp-server/dist)
  const candidates = [
    path.join(__dirname, "../../lib"),
    path.join(__dirname, "../../../lib"),
    path.join(process.cwd(), "plugins/codex/lib"),
    path.join(process.env.HOME || "", ".claude/plugins/marketplaces/fractary/plugins/codex/lib"),
  ];

  // For now, just use the most likely path - actual validation would need sync fs
  return candidates[0];
}

const LIB_PATH = getLibPath();

interface CacheEntry {
  uri: string;
  path: string;
  source: string;
  cached_at: string;
  expires_at: string;
  ttl: number;
  size_bytes: number;
  hash: string;
  last_accessed: string;
  synced_via?: string;
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

interface CodexConfig {
  organization?: string;
  project_name?: string;
  codex_repo?: string;
  cache?: {
    default_ttl?: number;
    offline_mode?: boolean;
    fallback_to_stale?: boolean;
    check_expiration?: boolean;
  };
  auth?: {
    default?: string;
    fallback_to_public?: boolean;
  };
  sources?: Record<string, {
    type?: string;
    ttl?: number;
    token_env?: string;
  }>;
}

let config: CodexConfig = {};

/**
 * Load configuration from file
 */
async function loadConfig(): Promise<CodexConfig> {
  try {
    const content = await fs.readFile(CONFIG_PATH, "utf-8");
    return JSON.parse(content) as CodexConfig;
  } catch {
    return {};
  }
}

/**
 * Read cache index from filesystem
 */
async function readCacheIndex(): Promise<CacheIndex | null> {
  try {
    const content = await fs.readFile(CACHE_INDEX_PATH, "utf-8");
    return JSON.parse(content) as CacheIndex;
  } catch {
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
 * Detect current project from config or git remote
 */
async function detectCurrentProject(): Promise<{ org: string | null; project: string | null }> {
  // Priority 1: Environment variables
  if (process.env.CODEX_CURRENT_ORG && process.env.CODEX_CURRENT_PROJECT) {
    return {
      org: process.env.CODEX_CURRENT_ORG,
      project: process.env.CODEX_CURRENT_PROJECT,
    };
  }

  // Priority 2: Config file
  if (config.organization && config.project_name) {
    return {
      org: config.organization,
      project: config.project_name,
    };
  }

  // Priority 3: Git remote
  try {
    const { stdout } = await execAsync("git remote get-url origin");
    const url = stdout.trim();

    // Parse GitHub URLs
    const match = url.match(/github\.com[:/]([^/]+)\/([^/]+?)(?:\.git)?$/);
    if (match) {
      return { org: match[1], project: match[2] };
    }
  } catch {
    // Git not available or not in a git repo
  }

  return { org: null, project: null };
}

/**
 * Validate and normalize file path to prevent directory traversal
 */
function validateAndNormalizePath(filePath: string): string | null {
  // Reject absolute paths
  if (filePath.startsWith("/")) {
    return null;
  }

  // Reject parent directory traversal
  if (filePath.includes("../") || filePath.startsWith("..") || filePath.includes("/..")) {
    return null;
  }

  // Normalize the path (remove ./ and duplicate /)
  const normalized = path.normalize(filePath).replace(/^\.\//, "");

  // Final check: ensure no traversal after normalization
  if (normalized.startsWith("..") || normalized.includes("/../")) {
    return null;
  }

  return normalized;
}

/**
 * Parse codex:// URI into components
 */
function parseUri(uri: string): { org: string; project: string; filePath: string } | null {
  if (!uri.startsWith("codex://")) {
    return null;
  }

  const pathPart = uri.replace("codex://", "");
  const parts = pathPart.split("/");

  if (parts.length < 2) {
    return null;
  }

  const filePath = parts.slice(2).join("/");

  // Validate file path to prevent directory traversal
  const validatedPath = validateAndNormalizePath(filePath);
  if (!validatedPath) {
    return null;
  }

  return {
    org: parts[0],
    project: parts[1],
    filePath: validatedPath,
  };
}

/**
 * Check if URI refers to current project
 */
async function isCurrentProject(org: string, project: string): Promise<boolean> {
  const current = await detectCurrentProject();
  return current.org === org && current.project === project;
}

/**
 * Resolve URI to file path (local or cache)
 */
async function resolveUri(uri: string): Promise<{ path: string; isLocal: boolean } | null> {
  const parsed = parseUri(uri);
  if (!parsed) {
    return null;
  }

  const { org, project, filePath } = parsed;

  // Check if it's the current project and file exists locally
  if (await isCurrentProject(org, project)) {
    if (filePath) {
      try {
        await fs.access(filePath);
        return { path: filePath, isLocal: true };
      } catch {
        // File doesn't exist locally, fall through to cache
      }
    }
  }

  // Resolve to cache path
  const cachePath = path.join(CACHE_PATH, org, project, filePath);
  return { path: cachePath, isLocal: false };
}

/**
 * Fetch content on-demand using lib scripts
 */
async function fetchOnDemand(uri: string): Promise<string | null> {
  const parsed = parseUri(uri);
  if (!parsed) {
    return null;
  }

  const { org, project, filePath } = parsed;

  // Check if offline mode is enabled
  if (config.cache?.offline_mode) {
    console.error(`[codex] Offline mode enabled, skipping fetch for ${uri}`);
    return null;
  }

  try {
    // Use lib/fetch-github.sh to fetch content with execFile (no shell interpretation)
    const fetchScript = path.join(LIB_PATH, "fetch-github.sh");
    const { stdout } = await new Promise<{ stdout: string; stderr: string }>((resolve, reject) => {
      execFile(
        fetchScript,
        [org, project, filePath, "--raw"],
        { timeout: 30000, maxBuffer: 10 * 1024 * 1024 },
        (error, stdout, stderr) => {
          if (error) reject(error);
          else resolve({ stdout, stderr });
        }
      );
    });

    // Store in cache using lib/cache-manager.sh with execFile (no shell interpretation)
    const cacheScript = path.join(LIB_PATH, "cache-manager.sh");
    await new Promise<void>((resolve, reject) => {
      const proc = spawn(cacheScript, ["put", uri, "--source", "github"], {
        timeout: 10000,
      });

      proc.stdin!.write(stdout);
      proc.stdin!.end();

      let error = "";
      proc.stderr!.on("data", (data) => {
        error += data.toString();
      });

      proc.on("close", (code) => {
        if (code !== 0) {
          reject(new Error(`Cache manager exited with code ${code}: ${error}`));
        } else {
          resolve();
        }
      });
    });

    return stdout;
  } catch (error) {
    console.error(`[codex] On-demand fetch failed for ${uri}:`, error);
    return null;
  }
}

/**
 * Main server setup
 */
async function main() {
  // Load configuration
  config = await loadConfig();

  const server = new Server(
    {
      name: "fractary-codex",
      version: "3.0.0",
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
    const resources = index.entries.map((entry) => ({
      uri: entry.uri,
      name: entry.path,
      description: `${entry.source} | ${entry.size_bytes} bytes | ${
        isFresh(entry) ? "fresh" : "expired"
      }${entry.synced_via ? ` | synced via ${entry.synced_via}` : ""}`,
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

    // Try to resolve the URI
    const resolved = await resolveUri(uri);
    if (!resolved) {
      throw new Error(`Failed to resolve URI: ${uri}`);
    }

    let content: string | null = null;
    let metadata: Record<string, unknown> = {};

    // Try to read from resolved path
    try {
      content = await fs.readFile(resolved.path, "utf-8");

      if (resolved.isLocal) {
        metadata = {
          source: "local",
          isCurrentProject: true,
          path: resolved.path,
        };
      } else {
        // Get metadata from cache index
        const index = await readCacheIndex();
        const entry = index?.entries.find((e) => e.uri === uri);
        if (entry) {
          metadata = {
            source: entry.source,
            cached_at: entry.cached_at,
            expires_at: entry.expires_at,
            fresh: isFresh(entry),
            size_bytes: entry.size_bytes,
            synced_via: entry.synced_via,
          };
        }
      }
    } catch {
      // Content not in cache, try on-demand fetch
      if (!config.cache?.offline_mode) {
        content = await fetchOnDemand(uri);
        if (content) {
          metadata = {
            source: "on-demand",
            fetched_at: new Date().toISOString(),
          };
        }
      }
    }

    // Handle cache miss
    if (!content) {
      // Check for stale content if fallback enabled
      if (config.cache?.fallback_to_stale) {
        try {
          content = await fs.readFile(resolved.path, "utf-8");
          metadata = {
            source: "stale-fallback",
            warning: "Content may be outdated",
          };
        } catch {
          // No content available at all
        }
      }

      if (!content) {
        const offlineMsg = config.cache?.offline_mode
          ? " (offline mode enabled)"
          : "";
        throw new Error(
          `Resource not found: ${uri}${offlineMsg}. Run '/fractary-codex:sync-project --from-codex' to populate cache.`
        );
      }
    }

    return {
      contents: [
        {
          uri,
          mimeType: "text/markdown",
          text: content,
          ...(Object.keys(metadata).length > 0 && {
            metadata: JSON.stringify(metadata, null, 2),
          }),
        },
      ],
    };
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
            "Fetch a document from codex knowledge base. Uses codex://org/project/path format.",
          inputSchema: {
            type: "object",
            properties: {
              uri: {
                type: "string",
                description:
                  "Document URI in codex://org/project/path format (e.g., codex://fractary/auth-service/docs/oauth.md)",
              },
              force_refresh: {
                type: "boolean",
                description: "Force refresh from source, bypassing cache",
                default: false,
              },
            },
            required: ["uri"],
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
        {
          name: "codex_sync_status",
          description: "Check if cache was populated via sync and show sync information",
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
      const uri = (args as Record<string, unknown>)?.uri as string ?? "";
      const forceRefresh = (args as Record<string, unknown>)?.force_refresh ?? false;

      if (!uri.startsWith("codex://")) {
        return {
          content: [
            {
              type: "text",
              text: `Invalid URI format. Use codex://org/project/path format.\nExample: codex://fractary/auth-service/docs/oauth.md`,
            },
          ],
        };
      }

      try {
        // If force refresh, clear cache entry first
        if (forceRefresh) {
          const cacheScript = path.join(LIB_PATH, "cache-manager.sh");
          await execAsync(`"${cacheScript}" remove "${uri}"`).catch(() => {});
        }

        // Try to fetch content
        const resolved = await resolveUri(uri);
        let content: string | null = null;

        if (resolved) {
          try {
            content = await fs.readFile(resolved.path, "utf-8");
          } catch {
            content = await fetchOnDemand(uri);
          }
        }

        if (content) {
          return {
            content: [
              {
                type: "text",
                text: content,
              },
            ],
          };
        } else {
          return {
            content: [
              {
                type: "text",
                text: `Failed to fetch ${uri}. ${config.cache?.offline_mode ? "Offline mode is enabled." : "Check if the resource exists."}`,
              },
            ],
          };
        }
      } catch (error) {
        return {
          content: [
            {
              type: "text",
              text: `Error fetching ${uri}: ${error instanceof Error ? error.message : String(error)}`,
            },
          ],
        };
      }
    }

    if (name === "codex_cache_status") {
      const index = await readCacheIndex();
      const current = await detectCurrentProject();

      if (!index) {
        return {
          content: [
            {
              type: "text",
              text: `📦 Codex Cache Status

Cache is empty (no index found)

Current project: ${current.org}/${current.project || "(not detected)"}
Offline mode: ${config.cache?.offline_mode ? "enabled" : "disabled"}

Run '/fractary-codex:sync-project --from-codex' to populate cache.`,
            },
          ],
        };
      }

      const fresh = index.entries.filter(isFresh).length;
      const expired = index.entries.length - fresh;
      const sources = [...new Set(index.entries.map(e => e.source))];
      const orgs = [...new Set(index.entries.map(e => {
        const parsed = parseUri(e.uri);
        return parsed?.org;
      }).filter(Boolean))];

      return {
        content: [
          {
            type: "text",
            text: `📦 Codex Cache Status

Total entries: ${index.stats.total_entries}
Total size: ${(index.stats.total_size_bytes / 1024 / 1024).toFixed(2)} MB
Fresh entries: ${fresh}
Expired entries: ${expired}
Last cleanup: ${index.stats.last_cleanup || "never"}

Sources: ${sources.join(", ") || "none"}
Organizations: ${orgs.join(", ") || "none"}

Current project: ${current.org}/${current.project || "(not detected)"}
Offline mode: ${config.cache?.offline_mode ? "enabled" : "disabled"}
Fallback to stale: ${config.cache?.fallback_to_stale !== false ? "enabled" : "disabled"}`,
          },
        ],
      };
    }

    if (name === "codex_sync_status") {
      const index = await readCacheIndex();

      if (!index || index.entries.length === 0) {
        return {
          content: [
            {
              type: "text",
              text: `🔄 Codex Sync Status

Cache is empty. Run '/fractary-codex:sync-project --from-codex' to populate.`,
            },
          ],
        };
      }

      const syncedEntries = index.entries.filter(e => e.synced_via);
      const onDemandEntries = index.entries.filter(e => !e.synced_via);
      const projects = [...new Set(index.entries.map(e => {
        const parsed = parseUri(e.uri);
        return parsed ? `${parsed.org}/${parsed.project}` : null;
      }).filter(Boolean))];

      return {
        content: [
          {
            type: "text",
            text: `🔄 Codex Sync Status

Synced entries: ${syncedEntries.length}
On-demand fetched: ${onDemandEntries.length}

Projects in cache:
${projects.map(p => `  - ${p}`).join("\n") || "  (none)"}

${syncedEntries.length > 0 ? `Last sync: ${syncedEntries.sort((a, b) =>
  new Date(b.cached_at).getTime() - new Date(a.cached_at).getTime()
)[0]?.cached_at || "unknown"}` : "No sync operations recorded."}`,
          },
        ],
      };
    }

    throw new Error(`Unknown tool: ${name}`);
  });

  // Start server
  const transport = new StdioServerTransport();
  await server.connect(transport);

  console.error("Fractary Codex MCP Server v3.0 running");
  console.error(`  Cache path: ${CACHE_PATH}`);
  console.error(`  Config path: ${CONFIG_PATH}`);
  console.error(`  Lib path: ${LIB_PATH}`);
  console.error(`  Offline mode: ${config.cache?.offline_mode ? "enabled" : "disabled"}`);
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
