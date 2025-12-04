/**
 * Type definitions for FABER Event Gateway
 */

export const EventTypes = [
  "workflow_start",
  "workflow_complete",
  "workflow_error",
  "workflow_cancelled",
  "workflow_resumed",
  "workflow_rerun",
  "phase_start",
  "phase_skip",
  "phase_complete",
  "phase_error",
  "step_start",
  "step_complete",
  "step_error",
  "step_retry",
  "artifact_create",
  "artifact_modify",
  "commit_create",
  "branch_create",
  "pr_create",
  "pr_merge",
  "spec_generate",
  "spec_validate",
  "test_run",
  "docs_update",
  "checkpoint",
  "skill_invoke",
  "agent_invoke",
  "decision_point",
  "retry_loop_enter",
  "retry_loop_exit",
  "approval_request",
  "approval_granted",
  "approval_denied",
  "hook_execute",
] as const;

export type EventType = (typeof EventTypes)[number];

export const Phases = [
  "frame",
  "architect",
  "build",
  "evaluate",
  "release",
] as const;

export type Phase = (typeof Phases)[number];

export const EventStatuses = [
  "started",
  "completed",
  "failed",
  "skipped",
  "pending",
  "cancelled",
] as const;

export type EventStatus = (typeof EventStatuses)[number];

export const RunStatuses = [
  "pending",
  "in_progress",
  "completed",
  "failed",
  "cancelled",
] as const;

export type RunStatus = (typeof RunStatuses)[number];

export interface Artifact {
  type: "branch" | "commit" | "spec" | "pr" | "deployment" | "tag" | "document" | "file" | "other";
  name: string;
  path?: string;
  url?: string;
  sha?: string;
  size_bytes?: number;
}

export interface EventError {
  code: string;
  message: string;
  stack?: string;
  recoverable?: boolean;
}

export interface FaberEvent {
  event_id: number;
  type: EventType;
  timestamp: string;
  run_id: string;
  phase?: Phase;
  step?: string;
  status?: EventStatus;
  user?: string;
  source?: string;
  message?: string;
  duration_ms?: number;
  metadata?: Record<string, unknown>;
  artifacts?: Artifact[];
  error?: EventError;
}

export interface PhaseState {
  status: "pending" | "in_progress" | "completed" | "failed" | "skipped";
  started_at?: string;
  completed_at?: string;
  steps: Array<{
    name: string;
    status: "pending" | "in_progress" | "completed" | "failed" | "skipped";
    started_at?: string;
    completed_at?: string;
    duration_ms?: number;
  }>;
  retry_count?: number;
}

export interface RunState {
  run_id: string;
  work_id: string;
  workflow_version: string;
  status: RunStatus;
  current_phase: Phase | null;
  last_event_id: number;
  started_at: string | null;
  updated_at: string;
  completed_at: string | null;
  phases: {
    frame: PhaseState;
    architect: PhaseState;
    build: PhaseState;
    evaluate: PhaseState;
    release: PhaseState;
  };
  artifacts: Record<string, string>;
  errors: EventError[];
}

export interface RunRelationships {
  parent_run_id: string | null;
  rerun_of: string | null;
  child_runs: string[];
}

export interface RunEnvironment {
  hostname: string;
  git_branch: string;
  git_commit: string;
  working_directory: string;
}

export interface RunMetadata {
  run_id: string;
  work_id: string;
  target: string | null;
  workflow_id: string;
  autonomy: "dry-run" | "assist" | "guarded" | "autonomous";
  source_type: "github" | "jira" | "linear" | "manual";
  phases: Phase[];
  created_at: string;
  created_by: string;
  relationships: RunRelationships;
  environment: RunEnvironment;
}

export interface RunSummary {
  run_id: string;
  work_id: string;
  status: RunStatus;
  created_at: string;
  updated_at: string;
  completed_at: string | null;
  current_phase: Phase | null;
  event_count?: number;
}

export interface EmitEventResult {
  status: "success" | "error";
  operation: "emit-event";
  event_id: number;
  type: EventType;
  run_id: string;
  timestamp: string;
  event_path: string;
  error?: string;
}

export interface GetRunResult {
  status: "success" | "error";
  operation: "get-run";
  run_id: string;
  metadata: RunMetadata;
  state: RunState;
  event_count?: number;
  error?: string;
}

export interface ListRunsResult {
  status: "success" | "error";
  operation: "list-runs";
  runs: RunSummary[];
  total: number;
  error?: string;
}

export interface ConsolidateResult {
  status: "success" | "error";
  operation: "consolidate-events";
  run_id: string;
  events_consolidated: number;
  output_path: string;
  size_bytes: number;
  error?: string;
}
