/**
 * Local Files Backend for FABER Event Gateway
 *
 * Stores events as individual JSON files in the run's events directory.
 * Uses atomic file operations for concurrent access safety.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import * as crypto from "node:crypto";
import {
  ConsolidateResult,
  EmitEventResult,
  EventType,
  EventTypes,
  FaberEvent,
  GetRunResult,
  ListRunsResult,
  RunMetadata,
  RunState,
  RunSummary,
} from "../types.js";

/**
 * Maximum retry attempts for atomic operations
 */
const MAX_RETRIES = 10;
const RETRY_DELAY_MS = 50;

/**
 * Error result factories for type-safe error handling
 */
function createEmitEventError(
  runId: string,
  type: EventType | "unknown",
  error: string
): EmitEventResult {
  return {
    status: "error",
    operation: "emit-event",
    event_id: 0,
    type: type === "unknown" ? "workflow_error" : type,
    run_id: runId,
    timestamp: new Date().toISOString(),
    event_path: "",
    error,
  };
}

function createGetRunError(runId: string, error: string): GetRunResult {
  return {
    status: "error",
    operation: "get-run",
    run_id: runId,
    metadata: null as unknown as RunMetadata,
    state: null as unknown as RunState,
    error,
  };
}

function createConsolidateError(
  runId: string,
  error: string
): ConsolidateResult {
  return {
    status: "error",
    operation: "consolidate-events",
    run_id: runId,
    events_consolidated: 0,
    output_path: "",
    size_bytes: 0,
    error,
  };
}

export class LocalFilesBackend {
  private readonly basePath: string;
  private readonly resolvedBasePath: string;

  constructor(basePath: string) {
    this.basePath = basePath;
    // Resolve the base path once for path traversal protection
    this.resolvedBasePath = path.resolve(basePath);
  }

  /**
   * Validate run_id format - strict validation to prevent edge cases
   * - org and project must start and end with alphanumeric
   * - uuid must be valid format
   */
  private validateRunId(runId: string): boolean {
    // Stricter regex: no leading/trailing underscores or hyphens in org/project
    return /^[a-z0-9][a-z0-9_-]*[a-z0-9]\/[a-z0-9][a-z0-9_-]*[a-z0-9]\/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/.test(
      runId
    ) || /^[a-z0-9]\/[a-z0-9]\/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/.test(runId);
  }

  /**
   * Get the directory path for a run with path traversal protection
   */
  private getRunDir(runId: string): string {
    const runDir = path.join(this.basePath, runId);
    const resolvedRunDir = path.resolve(runDir);

    // Path traversal protection: ensure resolved path is within base path
    if (!resolvedRunDir.startsWith(this.resolvedBasePath + path.sep)) {
      throw new Error(`Path traversal attempt detected: ${runId}`);
    }

    return runDir;
  }

  /**
   * Get the events directory for a run
   */
  private getEventsDir(runId: string): string {
    return path.join(this.getRunDir(runId), "events");
  }

  /**
   * Generate ISO timestamp with milliseconds for consistency
   */
  private getTimestamp(): string {
    return new Date().toISOString();
  }

  /**
   * Sleep helper for retry backoff
   */
  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  /**
   * Get next event ID atomically using atomic rename pattern
   *
   * This approach is more reliable than file locking:
   * 1. Read current ID
   * 2. Write new ID to temp file with random suffix
   * 3. Atomically rename temp file to target
   * 4. If rename fails due to race, retry with exponential backoff
   */
  private async getNextEventId(runId: string): Promise<number> {
    const eventsDir = this.getEventsDir(runId);
    const nextIdFile = path.join(eventsDir, ".next-id");

    for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
      try {
        // Read current ID
        let currentId = 1;
        if (fs.existsSync(nextIdFile)) {
          const content = fs.readFileSync(nextIdFile, "utf-8").trim();
          currentId = parseInt(content, 10) || 1;
        }

        const nextId = currentId + 1;

        // Write to temp file with unique suffix
        const tempFile = `${nextIdFile}.${crypto.randomBytes(8).toString("hex")}`;
        fs.writeFileSync(tempFile, String(nextId), { flag: "wx" });

        try {
          // Atomic rename - this is the critical section
          fs.renameSync(tempFile, nextIdFile);
          return currentId;
        } catch (renameErr) {
          // Cleanup temp file if rename failed
          try {
            fs.unlinkSync(tempFile);
          } catch {
            // Ignore cleanup errors
          }

          // If rename failed, another process won - retry
          if (attempt < MAX_RETRIES - 1) {
            await this.sleep(RETRY_DELAY_MS * (attempt + 1));
            continue;
          }
          throw renameErr;
        }
      } catch (err) {
        if (
          (err as NodeJS.ErrnoException).code === "EEXIST" &&
          attempt < MAX_RETRIES - 1
        ) {
          // Temp file already exists, retry
          await this.sleep(RETRY_DELAY_MS * (attempt + 1));
          continue;
        }
        throw err;
      }
    }

    throw new Error(`Failed to acquire event ID after ${MAX_RETRIES} attempts`);
  }

  /**
   * Update state.json atomically - CRITICAL operation
   * Throws on failure to ensure state consistency
   */
  private updateState(
    runDir: string,
    eventId: number,
    timestamp: string
  ): void {
    const stateFile = path.join(runDir, "state.json");

    if (!fs.existsSync(stateFile)) {
      throw new Error(`State file not found: ${stateFile}`);
    }

    const state = JSON.parse(fs.readFileSync(stateFile, "utf-8"));
    state.last_event_id = eventId;
    state.updated_at = timestamp;

    // Write to temp file first
    const tempFile = `${stateFile}.${crypto.randomBytes(8).toString("hex")}`;
    fs.writeFileSync(tempFile, JSON.stringify(state, null, 2));

    // Atomic rename
    try {
      fs.renameSync(tempFile, stateFile);
    } catch (err) {
      // Cleanup temp file
      try {
        fs.unlinkSync(tempFile);
      } catch {
        // Ignore cleanup errors
      }
      throw new Error(
        `Failed to update state file: ${(err as Error).message}`
      );
    }
  }

  /**
   * Emit a workflow event
   */
  async emitEvent(eventData: Partial<FaberEvent>): Promise<EmitEventResult> {
    const { run_id } = eventData;

    // Validate run_id
    if (!run_id || !this.validateRunId(run_id)) {
      return createEmitEventError(
        run_id || "",
        (eventData.type as EventType) || "unknown",
        "Invalid or missing run_id"
      );
    }

    // Validate event type
    if (!eventData.type || !EventTypes.includes(eventData.type)) {
      return createEmitEventError(
        run_id,
        "unknown",
        `Invalid event type: ${eventData.type}`
      );
    }

    // Get run directory with path traversal protection
    let runDir: string;
    try {
      runDir = this.getRunDir(run_id);
    } catch (err) {
      return createEmitEventError(
        run_id,
        eventData.type,
        (err as Error).message
      );
    }

    // Check run directory exists
    if (!fs.existsSync(runDir)) {
      return createEmitEventError(
        run_id,
        eventData.type,
        `Run directory not found: ${runDir}`
      );
    }

    // Get next event ID atomically
    let eventId: number;
    try {
      eventId = await this.getNextEventId(run_id);
    } catch (err) {
      return createEmitEventError(
        run_id,
        eventData.type,
        `Failed to get event ID: ${(err as Error).message}`
      );
    }

    const timestamp = this.getTimestamp();

    // Build complete event
    const event: FaberEvent = {
      event_id: eventId,
      type: eventData.type,
      timestamp,
      run_id,
      ...(eventData.phase && { phase: eventData.phase }),
      ...(eventData.step && { step: eventData.step }),
      ...(eventData.status && { status: eventData.status }),
      user: eventData.user || process.env.USER || "unknown",
      source: eventData.source || "mcp-gateway",
      ...(eventData.message && { message: eventData.message }),
      ...(eventData.duration_ms && { duration_ms: eventData.duration_ms }),
      ...(eventData.metadata && { metadata: eventData.metadata }),
      ...(eventData.artifacts && { artifacts: eventData.artifacts }),
      ...(eventData.error && { error: eventData.error }),
    };

    // Write event file
    const eventsDir = this.getEventsDir(run_id);
    const eventFilename = `${String(eventId).padStart(3, "0")}-${eventData.type}.json`;
    const eventPath = path.join(eventsDir, eventFilename);

    fs.writeFileSync(eventPath, JSON.stringify(event, null, 2));

    // Update state.json - CRITICAL: throws on failure
    try {
      this.updateState(runDir, eventId, timestamp);
    } catch (err) {
      return createEmitEventError(
        run_id,
        eventData.type,
        `Event written but state update failed: ${(err as Error).message}`
      );
    }

    return {
      status: "success",
      operation: "emit-event",
      event_id: eventId,
      type: eventData.type,
      run_id,
      timestamp,
      event_path: eventPath,
    };
  }

  /**
   * Get run state and metadata
   */
  async getRun(runId: string, includeEvents = false): Promise<GetRunResult> {
    if (!this.validateRunId(runId)) {
      return createGetRunError(runId, "Invalid run_id format");
    }

    let runDir: string;
    try {
      runDir = this.getRunDir(runId);
    } catch (err) {
      return createGetRunError(runId, (err as Error).message);
    }

    if (!fs.existsSync(runDir)) {
      return createGetRunError(runId, "Run not found");
    }

    const metadataFile = path.join(runDir, "metadata.json");
    const stateFile = path.join(runDir, "state.json");

    try {
      const metadata = JSON.parse(
        fs.readFileSync(metadataFile, "utf-8")
      ) as RunMetadata;
      const state = JSON.parse(
        fs.readFileSync(stateFile, "utf-8")
      ) as RunState;

      const result: GetRunResult = {
        status: "success",
        operation: "get-run",
        run_id: runId,
        metadata,
        state,
      };

      if (includeEvents) {
        const eventsDir = this.getEventsDir(runId);
        if (fs.existsSync(eventsDir)) {
          const eventFiles = fs
            .readdirSync(eventsDir)
            .filter((f) => f.endsWith(".json"));
          result.event_count = eventFiles.length;
        } else {
          result.event_count = 0;
        }
      }

      return result;
    } catch (err) {
      return createGetRunError(
        runId,
        `Failed to read run data: ${(err as Error).message}`
      );
    }
  }

  /**
   * Get events for a run with streaming support for large event sets
   * Uses a generator pattern to avoid loading all events into memory
   */
  async *getEventsStream(runId: string): AsyncGenerator<FaberEvent> {
    if (!this.validateRunId(runId)) {
      return;
    }

    let eventsDir: string;
    try {
      eventsDir = this.getEventsDir(runId);
    } catch {
      return;
    }

    if (!fs.existsSync(eventsDir)) {
      return;
    }

    const eventFiles = fs
      .readdirSync(eventsDir)
      .filter((f) => f.endsWith(".json"))
      .sort();

    for (const file of eventFiles) {
      try {
        const content = fs.readFileSync(path.join(eventsDir, file), "utf-8");
        yield JSON.parse(content) as FaberEvent;
      } catch {
        // Skip invalid event files
        continue;
      }
    }
  }

  /**
   * Get all events for a run (for backward compatibility)
   * For large event sets, prefer getEventsStream
   */
  async getEvents(runId: string): Promise<FaberEvent[]> {
    const events: FaberEvent[] = [];
    for await (const event of this.getEventsStream(runId)) {
      events.push(event);
    }
    return events;
  }

  /**
   * List runs with optional filters
   * Uses an index file for performance when available
   */
  async listRuns(filters: {
    work_id?: string;
    status?: string;
    org?: string;
    project?: string;
    limit?: number;
  }): Promise<ListRunsResult> {
    const { work_id, status, org, project, limit = 20 } = filters;
    const runs: RunSummary[] = [];

    // Check if base path exists
    if (!fs.existsSync(this.basePath)) {
      return {
        status: "success",
        operation: "list-runs",
        runs: [],
        total: 0,
      };
    }

    // Check for index file (optimization for large run counts)
    const indexFile = path.join(this.basePath, ".runs-index.json");
    if (fs.existsSync(indexFile)) {
      try {
        const index = JSON.parse(
          fs.readFileSync(indexFile, "utf-8")
        ) as RunSummary[];
        let filtered = index;

        if (org) {
          filtered = filtered.filter((r) => r.run_id.startsWith(`${org}/`));
        }
        if (project && org) {
          filtered = filtered.filter((r) =>
            r.run_id.startsWith(`${org}/${project}/`)
          );
        }
        if (work_id) {
          filtered = filtered.filter((r) => r.work_id === work_id);
        }
        if (status) {
          filtered = filtered.filter((r) => r.status === status);
        }

        return {
          status: "success",
          operation: "list-runs",
          runs: filtered.slice(0, limit),
          total: filtered.length,
        };
      } catch {
        // Fall through to directory traversal if index is invalid
      }
    }

    // Directory traversal fallback
    try {
      const orgs = fs.readdirSync(this.basePath);

      for (const orgName of orgs) {
        // Skip hidden files and index
        if (orgName.startsWith(".")) continue;
        if (org && orgName !== org) continue;

        const orgDir = path.join(this.basePath, orgName);
        if (!fs.statSync(orgDir).isDirectory()) continue;

        const projects = fs.readdirSync(orgDir);

        for (const projectName of projects) {
          if (projectName.startsWith(".")) continue;
          if (project && projectName !== project) continue;

          const projectDir = path.join(orgDir, projectName);
          if (!fs.statSync(projectDir).isDirectory()) continue;

          const uuids = fs.readdirSync(projectDir);

          for (const uuid of uuids) {
            if (uuid.startsWith(".")) continue;

            const runDir = path.join(projectDir, uuid);
            if (!fs.statSync(runDir).isDirectory()) continue;

            const stateFile = path.join(runDir, "state.json");
            if (!fs.existsSync(stateFile)) continue;

            try {
              const state = JSON.parse(
                fs.readFileSync(stateFile, "utf-8")
              ) as RunState;

              // Apply filters
              if (work_id && state.work_id !== work_id) continue;
              if (status && state.status !== status) continue;

              runs.push({
                run_id: `${orgName}/${projectName}/${uuid}`,
                work_id: state.work_id,
                status: state.status,
                created_at: state.started_at || state.updated_at,
                updated_at: state.updated_at,
                completed_at: state.completed_at,
                current_phase: state.current_phase,
              });
            } catch {
              // Skip invalid state files
              continue;
            }
          }
        }
      }
    } catch (err) {
      return {
        status: "error",
        operation: "list-runs",
        runs: [],
        total: 0,
        error: `Failed to list runs: ${(err as Error).message}`,
      };
    }

    // Sort by created_at descending
    runs.sort(
      (a, b) =>
        new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
    );

    return {
      status: "success",
      operation: "list-runs",
      runs: runs.slice(0, limit),
      total: runs.length,
    };
  }

  /**
   * Consolidate events to JSONL format using streaming
   * Avoids loading all events into memory
   */
  async consolidateEvents(runId: string): Promise<ConsolidateResult> {
    if (!this.validateRunId(runId)) {
      return createConsolidateError(runId, "Invalid run_id format");
    }

    let runDir: string;
    try {
      runDir = this.getRunDir(runId);
    } catch (err) {
      return createConsolidateError(runId, (err as Error).message);
    }

    if (!fs.existsSync(runDir)) {
      return createConsolidateError(runId, "Run not found");
    }

    const outputPath = path.join(runDir, "events.jsonl");
    const tempPath = `${outputPath}.${crypto.randomBytes(8).toString("hex")}`;

    let eventCount = 0;

    try {
      // Use write stream for memory efficiency
      const writeStream = fs.createWriteStream(tempPath);

      for await (const event of this.getEventsStream(runId)) {
        writeStream.write(JSON.stringify(event) + "\n");
        eventCount++;
      }

      // Close the stream and wait for completion
      await new Promise<void>((resolve, reject) => {
        writeStream.on("finish", resolve);
        writeStream.on("error", reject);
        writeStream.end();
      });

      // Atomic rename
      fs.renameSync(tempPath, outputPath);

      const stats = fs.statSync(outputPath);

      return {
        status: "success",
        operation: "consolidate-events",
        run_id: runId,
        events_consolidated: eventCount,
        output_path: outputPath,
        size_bytes: stats.size,
      };
    } catch (err) {
      // Cleanup temp file on error
      try {
        fs.unlinkSync(tempPath);
      } catch {
        // Ignore cleanup errors
      }

      return createConsolidateError(
        runId,
        `Failed to consolidate events: ${(err as Error).message}`
      );
    }
  }

  /**
   * Update the runs index for faster listing
   * Should be called after run completion
   */
  async updateRunsIndex(): Promise<void> {
    const result = await this.listRuns({ limit: 10000 });
    if (result.status === "success") {
      const indexFile = path.join(this.basePath, ".runs-index.json");
      fs.writeFileSync(indexFile, JSON.stringify(result.runs, null, 2));
    }
  }
}
