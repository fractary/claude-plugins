/**
 * Local Files Backend for FABER Event Gateway
 *
 * Stores events as individual JSON files in the run's events directory.
 * Uses file-based locking for concurrent access safety.
 */

import * as fs from "node:fs";
import * as path from "node:path";
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
  RunStatus,
  RunSummary,
} from "../types.js";

export class LocalFilesBackend {
  constructor(private basePath: string) {}

  /**
   * Validate run_id format
   */
  private validateRunId(runId: string): boolean {
    return /^[a-z0-9_-]+\/[a-z0-9_-]+\/[a-f0-9-]{36}$/.test(runId);
  }

  /**
   * Get the directory path for a run
   */
  private getRunDir(runId: string): string {
    return path.join(this.basePath, runId);
  }

  /**
   * Get the events directory for a run
   */
  private getEventsDir(runId: string): string {
    return path.join(this.getRunDir(runId), "events");
  }

  /**
   * Get next event ID atomically
   *
   * Note: This uses a simple file-based locking mechanism that provides
   * basic coordination but is not a true exclusive lock on Unix systems.
   * For high-concurrency scenarios, consider using a proper locking library
   * like 'proper-lockfile'. For typical FABER usage (single-agent workflows),
   * this implementation is sufficient.
   */
  private async getNextEventId(runId: string): Promise<number> {
    const eventsDir = this.getEventsDir(runId);
    const nextIdFile = path.join(eventsDir, ".next-id");
    const lockFile = path.join(eventsDir, ".next-id.lock");

    // Simple file-based locking
    let lockFd: number | undefined;
    try {
      // Create lock file with exclusive flags for basic coordination
      lockFd = fs.openSync(lockFile, "wx");

      // Read current ID
      let currentId = 1;
      if (fs.existsSync(nextIdFile)) {
        const content = fs.readFileSync(nextIdFile, "utf-8").trim();
        currentId = parseInt(content, 10) || 1;
      }

      // Write next ID
      fs.writeFileSync(nextIdFile, String(currentId + 1));

      return currentId;
    } catch (err) {
      // If lock file already exists (EEXIST), retry with regular open
      // This handles the case where a previous process didn't clean up
      if ((err as NodeJS.ErrnoException).code === "EEXIST") {
        lockFd = fs.openSync(lockFile, "w");

        let currentId = 1;
        if (fs.existsSync(nextIdFile)) {
          const content = fs.readFileSync(nextIdFile, "utf-8").trim();
          currentId = parseInt(content, 10) || 1;
        }

        fs.writeFileSync(nextIdFile, String(currentId + 1));

        return currentId;
      }
      throw err;
    } finally {
      if (lockFd !== undefined) {
        fs.closeSync(lockFd);
        // Clean up lock file after releasing
        try {
          fs.unlinkSync(lockFile);
        } catch {
          // Ignore cleanup errors - file may have been removed by another process
        }
      }
    }
  }

  /**
   * Emit a workflow event
   */
  async emitEvent(eventData: Partial<FaberEvent>): Promise<EmitEventResult> {
    const { run_id } = eventData;

    // Validate run_id
    if (!run_id || !this.validateRunId(run_id)) {
      return {
        status: "error",
        operation: "emit-event",
        event_id: 0,
        type: eventData.type || ("unknown" as EventType),
        run_id: run_id || "",
        timestamp: new Date().toISOString(),
        event_path: "",
        error: "Invalid or missing run_id",
      };
    }

    // Validate event type
    if (!eventData.type || !EventTypes.includes(eventData.type)) {
      return {
        status: "error",
        operation: "emit-event",
        event_id: 0,
        type: eventData.type || ("unknown" as EventType),
        run_id,
        timestamp: new Date().toISOString(),
        event_path: "",
        error: `Invalid event type: ${eventData.type}`,
      };
    }

    // Check run directory exists
    const runDir = this.getRunDir(run_id);
    if (!fs.existsSync(runDir)) {
      return {
        status: "error",
        operation: "emit-event",
        event_id: 0,
        type: eventData.type,
        run_id,
        timestamp: new Date().toISOString(),
        event_path: "",
        error: `Run directory not found: ${runDir}`,
      };
    }

    // Get next event ID
    const eventId = await this.getNextEventId(run_id);
    const timestamp = new Date().toISOString();

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

    // Update state.json
    const stateFile = path.join(runDir, "state.json");
    if (fs.existsSync(stateFile)) {
      const state = JSON.parse(fs.readFileSync(stateFile, "utf-8"));
      state.last_event_id = eventId;
      state.updated_at = timestamp;
      fs.writeFileSync(stateFile, JSON.stringify(state, null, 2));
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
  async getRun(
    runId: string,
    includeEvents = false
  ): Promise<GetRunResult> {
    if (!this.validateRunId(runId)) {
      return {
        status: "error",
        operation: "get-run",
        run_id: runId,
        metadata: {} as RunMetadata,
        state: {} as RunState,
        error: "Invalid run_id format",
      };
    }

    const runDir = this.getRunDir(runId);
    if (!fs.existsSync(runDir)) {
      return {
        status: "error",
        operation: "get-run",
        run_id: runId,
        metadata: {} as RunMetadata,
        state: {} as RunState,
        error: "Run not found",
      };
    }

    const metadataFile = path.join(runDir, "metadata.json");
    const stateFile = path.join(runDir, "state.json");

    const metadata = JSON.parse(
      fs.readFileSync(metadataFile, "utf-8")
    ) as RunMetadata;
    const state = JSON.parse(fs.readFileSync(stateFile, "utf-8")) as RunState;

    const result: GetRunResult = {
      status: "success",
      operation: "get-run",
      run_id: runId,
      metadata,
      state,
    };

    if (includeEvents) {
      const eventsDir = this.getEventsDir(runId);
      const eventFiles = fs
        .readdirSync(eventsDir)
        .filter((f) => f.endsWith(".json"));
      result.event_count = eventFiles.length;
    }

    return result;
  }

  /**
   * Get all events for a run
   */
  async getEvents(runId: string): Promise<FaberEvent[]> {
    if (!this.validateRunId(runId)) {
      return [];
    }

    const eventsDir = this.getEventsDir(runId);
    if (!fs.existsSync(eventsDir)) {
      return [];
    }

    const eventFiles = fs
      .readdirSync(eventsDir)
      .filter((f) => f.endsWith(".json"))
      .sort();

    return eventFiles.map((f) => {
      const content = fs.readFileSync(path.join(eventsDir, f), "utf-8");
      return JSON.parse(content) as FaberEvent;
    });
  }

  /**
   * List runs with optional filters
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

    // Traverse directory structure: basePath/org/project/uuid
    const orgs = fs.readdirSync(this.basePath);

    for (const orgName of orgs) {
      if (org && orgName !== org) continue;

      const orgDir = path.join(this.basePath, orgName);
      if (!fs.statSync(orgDir).isDirectory()) continue;

      const projects = fs.readdirSync(orgDir);

      for (const projectName of projects) {
        if (project && projectName !== project) continue;

        const projectDir = path.join(orgDir, projectName);
        if (!fs.statSync(projectDir).isDirectory()) continue;

        const uuids = fs.readdirSync(projectDir);

        for (const uuid of uuids) {
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
   * Consolidate events to JSONL format
   */
  async consolidateEvents(runId: string): Promise<ConsolidateResult> {
    if (!this.validateRunId(runId)) {
      return {
        status: "error",
        operation: "consolidate-events",
        run_id: runId,
        events_consolidated: 0,
        output_path: "",
        size_bytes: 0,
        error: "Invalid run_id format",
      };
    }

    const runDir = this.getRunDir(runId);
    if (!fs.existsSync(runDir)) {
      return {
        status: "error",
        operation: "consolidate-events",
        run_id: runId,
        events_consolidated: 0,
        output_path: "",
        size_bytes: 0,
        error: "Run not found",
      };
    }

    const events = await this.getEvents(runId);
    const outputPath = path.join(runDir, "events.jsonl");

    // Write as JSONL (one JSON object per line)
    const jsonl = events.map((e) => JSON.stringify(e)).join("\n");
    fs.writeFileSync(outputPath, jsonl);

    const stats = fs.statSync(outputPath);

    return {
      status: "success",
      operation: "consolidate-events",
      run_id: runId,
      events_consolidated: events.length,
      output_path: outputPath,
      size_bytes: stats.size,
    };
  }
}
