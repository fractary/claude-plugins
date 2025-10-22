---
org: omnidas
name: sync-project
description: Sync project documentation with Codex
codex_sync_include: [*]
codex_sync_exclude: []
tags: [sync, documentation, workflow]
---

# codex-sync-project

Synchronizes project documentation with the central Codex repository.

## Usage

```bash
# Sync current project (default)
/codex-sync-project

# Sync specific project
/codex-sync-project project-name

# Sync all projects
/codex-sync-project *
```

## What it does

1. Triggers GitHub workflows to sync documentation between projects and Codex
2. Runs three workflows in sequence:
   - **Pull**: OmniDAS Codex - Sync Pull Docs (pulls from projects)
   - **Push Docs**: OmniDAS Codex - Sync Push Docs (pushes to projects)
   - **Push Claude**: OmniDAS Codex - Sync Push Claude (pushes Claude tools)
3. Monitors progress in the background
4. Allows you to continue working while sync completes

## Parameters

- **No argument**: Syncs the current project you're working in
- **Project name**: Syncs a specific project (e.g., `tts.omnidas.ai`)
- **Asterisk (*)**: Syncs all projects in the organization

## Examples

```bash
# Working in tts.omnidas.ai and want to sync it
/codex-sync-project

# Want to sync a different project
/codex-sync-project fleet.omnidas.ai

# Major documentation update, sync everything
/codex-sync-project *
```

## Implementation

This command invokes the codex-sync-manager agent to handle the sync process in the background.