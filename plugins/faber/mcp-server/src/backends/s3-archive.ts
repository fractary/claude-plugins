/**
 * S3 Archive Backend for FABER Event Gateway
 *
 * Archives events to S3 for long-term storage and analysis.
 * Supports consolidation to JSONL format for efficient storage.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { spawn } from "node:child_process";
import {
  ConsolidateResult,
  FaberEvent,
  RunMetadata,
  RunState,
} from "../types.js";

export interface S3Config {
  bucket: string;
  prefix: string;
  region: string;
  consolidateOnComplete: boolean;
  cleanupLocalAfterArchive: boolean;
}

export interface ArchiveResult {
  status: "success" | "error";
  operation: "archive-to-s3";
  run_id: string;
  s3_path: string;
  files_archived: string[];
  size_bytes: number;
  error?: string;
}

export class S3ArchiveBackend {
  constructor(
    private config: S3Config,
    private localBasePath: string
  ) {}

  /**
   * Execute AWS CLI command
   */
  private async execAwsCli(args: string[]): Promise<{
    stdout: string;
    stderr: string;
    code: number;
  }> {
    return new Promise((resolve) => {
      const proc = spawn("aws", args, {
        env: { ...process.env, AWS_REGION: this.config.region },
      });

      let stdout = "";
      let stderr = "";

      proc.stdout.on("data", (data) => {
        stdout += data.toString();
      });

      proc.stderr.on("data", (data) => {
        stderr += data.toString();
      });

      proc.on("close", (code) => {
        resolve({ stdout, stderr, code: code ?? 1 });
      });
    });
  }

  /**
   * Get S3 path for a run
   */
  private getS3Path(runId: string): string {
    return `s3://${this.config.bucket}/${this.config.prefix}${runId}`;
  }

  /**
   * Get local run directory
   */
  private getLocalRunDir(runId: string): string {
    return path.join(this.localBasePath, runId);
  }

  /**
   * Archive a completed run to S3
   */
  async archiveRun(runId: string): Promise<ArchiveResult> {
    const localRunDir = this.getLocalRunDir(runId);
    const s3Path = this.getS3Path(runId);

    // Check if local directory exists
    if (!fs.existsSync(localRunDir)) {
      return {
        status: "error",
        operation: "archive-to-s3",
        run_id: runId,
        s3_path: s3Path,
        files_archived: [],
        size_bytes: 0,
        error: `Local run directory not found: ${localRunDir}`,
      };
    }

    const filesArchived: string[] = [];
    let totalSize = 0;

    try {
      // Consolidate events to JSONL if configured
      if (this.config.consolidateOnComplete) {
        const eventsDir = path.join(localRunDir, "events");
        const jsonlPath = path.join(localRunDir, "events.jsonl");

        if (fs.existsSync(eventsDir)) {
          const events: FaberEvent[] = [];
          const eventFiles = fs
            .readdirSync(eventsDir)
            .filter((f) => f.endsWith(".json"))
            .sort();

          for (const file of eventFiles) {
            const content = fs.readFileSync(path.join(eventsDir, file), "utf-8");
            try {
              events.push(JSON.parse(content));
            } catch {
              // Skip invalid JSON files
            }
          }

          // Write consolidated JSONL
          const jsonl = events.map((e) => JSON.stringify(e)).join("\n");
          fs.writeFileSync(jsonlPath, jsonl);
        }
      }

      // Upload metadata.json
      const metadataPath = path.join(localRunDir, "metadata.json");
      if (fs.existsSync(metadataPath)) {
        const result = await this.execAwsCli([
          "s3",
          "cp",
          metadataPath,
          `${s3Path}/metadata.json`,
        ]);
        if (result.code === 0) {
          filesArchived.push("metadata.json");
          totalSize += fs.statSync(metadataPath).size;
        }
      }

      // Upload state.json
      const statePath = path.join(localRunDir, "state.json");
      if (fs.existsSync(statePath)) {
        const result = await this.execAwsCli([
          "s3",
          "cp",
          statePath,
          `${s3Path}/state.json`,
        ]);
        if (result.code === 0) {
          filesArchived.push("state.json");
          totalSize += fs.statSync(statePath).size;
        }
      }

      // Upload events.jsonl if consolidated
      const jsonlPath = path.join(localRunDir, "events.jsonl");
      if (fs.existsSync(jsonlPath)) {
        const result = await this.execAwsCli([
          "s3",
          "cp",
          jsonlPath,
          `${s3Path}/events.jsonl`,
        ]);
        if (result.code === 0) {
          filesArchived.push("events.jsonl");
          totalSize += fs.statSync(jsonlPath).size;
        }
      } else {
        // Upload individual event files if not consolidated
        const eventsDir = path.join(localRunDir, "events");
        if (fs.existsSync(eventsDir)) {
          const result = await this.execAwsCli([
            "s3",
            "sync",
            eventsDir,
            `${s3Path}/events/`,
          ]);
          if (result.code === 0) {
            const eventFiles = fs
              .readdirSync(eventsDir)
              .filter((f) => f.endsWith(".json"));
            filesArchived.push(...eventFiles.map((f) => `events/${f}`));
            for (const f of eventFiles) {
              totalSize += fs.statSync(path.join(eventsDir, f)).size;
            }
          }
        }
      }

      // Cleanup local files if configured and archive was successful
      if (
        this.config.cleanupLocalAfterArchive &&
        filesArchived.length > 0
      ) {
        // Only delete events directory, keep state and metadata
        const eventsDir = path.join(localRunDir, "events");
        if (fs.existsSync(eventsDir)) {
          fs.rmSync(eventsDir, { recursive: true });
        }
        // Delete consolidated JSONL if it exists locally
        if (fs.existsSync(jsonlPath)) {
          fs.unlinkSync(jsonlPath);
        }
      }

      return {
        status: "success",
        operation: "archive-to-s3",
        run_id: runId,
        s3_path: s3Path,
        files_archived: filesArchived,
        size_bytes: totalSize,
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return {
        status: "error",
        operation: "archive-to-s3",
        run_id: runId,
        s3_path: s3Path,
        files_archived: filesArchived,
        size_bytes: totalSize,
        error: message,
      };
    }
  }

  /**
   * List archived runs in S3
   */
  async listArchivedRuns(filters?: {
    org?: string;
    project?: string;
    limit?: number;
  }): Promise<{
    status: "success" | "error";
    runs: Array<{ run_id: string; s3_path: string; size_bytes: number }>;
    error?: string;
  }> {
    const { org, project, limit = 100 } = filters ?? {};

    let prefix = this.config.prefix;
    if (org) {
      prefix += `${org}/`;
      if (project) {
        prefix += `${project}/`;
      }
    }

    try {
      const result = await this.execAwsCli([
        "s3api",
        "list-objects-v2",
        "--bucket",
        this.config.bucket,
        "--prefix",
        prefix,
        "--delimiter",
        "/",
        "--max-keys",
        String(limit * 3), // Account for nested structure
      ]);

      if (result.code !== 0) {
        return {
          status: "error",
          runs: [],
          error: result.stderr,
        };
      }

      // Parse S3 response to extract run IDs
      const response = JSON.parse(result.stdout);
      const runs: Array<{
        run_id: string;
        s3_path: string;
        size_bytes: number;
      }> = [];

      if (response.CommonPrefixes) {
        for (const cp of response.CommonPrefixes) {
          const runPath = cp.Prefix.replace(this.config.prefix, "").replace(
            /\/$/,
            ""
          );
          // Only include if it looks like a complete run_id (org/project/uuid)
          if (/^[a-z0-9_-]+\/[a-z0-9_-]+\/[a-f0-9-]{36}$/.test(runPath)) {
            runs.push({
              run_id: runPath,
              s3_path: `s3://${this.config.bucket}/${cp.Prefix}`,
              size_bytes: 0, // Would need additional API call to get size
            });
          }
        }
      }

      return {
        status: "success",
        runs: runs.slice(0, limit),
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return {
        status: "error",
        runs: [],
        error: message,
      };
    }
  }

  /**
   * Restore a run from S3 to local storage
   */
  async restoreRun(runId: string): Promise<{
    status: "success" | "error";
    run_id: string;
    local_path: string;
    files_restored: string[];
    error?: string;
  }> {
    const s3Path = this.getS3Path(runId);
    const localRunDir = this.getLocalRunDir(runId);

    try {
      // Create local directory
      fs.mkdirSync(localRunDir, { recursive: true });
      fs.mkdirSync(path.join(localRunDir, "events"), { recursive: true });

      const filesRestored: string[] = [];

      // Download all files from S3
      const result = await this.execAwsCli([
        "s3",
        "sync",
        `${s3Path}/`,
        `${localRunDir}/`,
      ]);

      if (result.code !== 0) {
        return {
          status: "error",
          run_id: runId,
          local_path: localRunDir,
          files_restored: [],
          error: result.stderr,
        };
      }

      // List restored files
      const files = this.listFilesRecursive(localRunDir);
      filesRestored.push(
        ...files.map((f) => f.replace(`${localRunDir}/`, ""))
      );

      // If events.jsonl exists but events/ is empty, expand it
      const jsonlPath = path.join(localRunDir, "events.jsonl");
      const eventsDir = path.join(localRunDir, "events");
      if (
        fs.existsSync(jsonlPath) &&
        fs.readdirSync(eventsDir).filter((f) => f.endsWith(".json")).length ===
          0
      ) {
        const jsonl = fs.readFileSync(jsonlPath, "utf-8");
        const lines = jsonl.split("\n").filter((l) => l.trim());
        for (const line of lines) {
          try {
            const event = JSON.parse(line) as FaberEvent;
            const filename = `${String(event.event_id).padStart(3, "0")}-${event.type}.json`;
            fs.writeFileSync(
              path.join(eventsDir, filename),
              JSON.stringify(event, null, 2)
            );
            filesRestored.push(`events/${filename}`);
          } catch {
            // Skip invalid lines
          }
        }
      }

      return {
        status: "success",
        run_id: runId,
        local_path: localRunDir,
        files_restored: filesRestored,
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return {
        status: "error",
        run_id: runId,
        local_path: localRunDir,
        files_restored: [],
        error: message,
      };
    }
  }

  /**
   * Helper to list files recursively
   */
  private listFilesRecursive(dir: string): string[] {
    const files: string[] = [];
    const entries = fs.readdirSync(dir, { withFileTypes: true });

    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        files.push(...this.listFilesRecursive(fullPath));
      } else {
        files.push(fullPath);
      }
    }

    return files;
  }
}
