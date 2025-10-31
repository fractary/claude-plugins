# OmniDAS Codex Manager Bundle

A Claude Code agent bundle that provides convenient commands for triggering Codex synchronization operations across your organization's projects. This bundle works in conjunction with the [codex-github-core](https://github.com/omnidasai/codex-github-core) package to enable seamless documentation synchronization.

## Overview

The Codex Manager bundle provides Claude Code agents and commands that allow any project in your organization to trigger documentation synchronization with the central Codex repository. While this bundle handles the user interface and command execution, the actual file synchronization is performed by GitHub workflows in the core bundle.

### Architecture

- **This Bundle (codex-manager)**: Installed on every project that needs to sync with Codex
  - Provides `/codex-sync` and `/codex-publish-distros` commands
  - Includes the intelligent Codex Manager agent
  - Triggers workflows in the core repository

- **Core Bundle (codex-core)**: Installed only on the central Codex repository
  - Contains the GitHub Actions workflows
  - Handles all file movement and synchronization
  - Manages the actual sync operations between projects and Codex

## Quick Start

### Commands

- **`/codex-sync-project`** - Sync the current project's documentation with Codex
- **`/codex-sync-project [project-name]`** - Sync a specific project with Codex
- **`/codex-sync-project *`** - Sync ALL organization projects with Codex (use with caution)
- **`/codex-publish-distros`** - Publish Codex content to all distribution bundle repositories
- **`/codex-publish-distros [repo-name]`** - Publish to a specific distribution repository
- **`/codex-publish-distros --dry-run`** - Preview distribution changes without pushing

### Natural Language Support

The Codex Manager agent recognizes various natural language requests:
- "sync codex"
- "sync all documents"
- "synchronize documentation"
- "codex sync project"
- "sync the fleet project"
- Even handles common misspellings like "codec sync" or "sink codex"

## Features

- **Background Execution**: All sync operations run in the background, allowing you to continue working
- **Sequential Workflow Management**: Ensures sync operations execute in the correct order
- **Intelligent Detection**: Recognizes various command variations and natural language requests
- **Progress Monitoring**: Provides status updates as workflows complete
- **Error Handling**: Reports failures with actionable information

## Installation

This bundle is typically distributed through Codex synchronization itself. Once your project syncs with Codex, you'll receive:

```
.claude/
├── agents/
│   └── omnidas/
│       └── codex/
│           └── codex-manager.md
└── commands/
    └── omnidas/
        └── codex/
            ├── codex-sync-project.md
            └── codex-publish-distros.md
```

## How It Works

### Documentation Sync
1. **You trigger a sync** using commands or natural language in Claude Code
2. **The agent activates** and determines the appropriate sync scope (current project, specific project, or all projects)
3. **GitHub workflows are triggered** sequentially in the core Codex repository:
   - Pull Project Docs (pulls from projects to Codex)
   - Push Docs to Projects (pushes from Codex to projects)
   - Push Claude to Projects (pushes Claude agents/commands to projects)
4. **Files are synchronized** according to metadata rules and patterns
5. **You receive updates** while continuing to work

### Distribution Publishing
1. **You trigger a publish** using the `/codex-publish-distros` command
2. **The agent activates** and determines which distribution repositories to update
3. **The distribution workflow is triggered** in the core Codex repository
4. **Files are copied** to the `assets/` folder of target distribution repositories according to distribution configs
5. **Changes are committed and pushed** to the distribution repositories

## Documentation

### Essential Guides
- **[Setup Guide](./.omnidas/codex.omnidas.ai/docs/guides/codex-manager-guide-setup.md)** - Complete setup instructions including permissions and configuration
- **[Operations Guide](./.omnidas/codex.omnidas.ai/docs/guides/codex-manager-guide.md)** - Agent operational instructions and workflows

## Requirements

- GitHub CLI (`gh`) installed and authenticated
- Personal Access Token (PAT) configured for Codex operations (see [Setup Guide](./.omnidas/codex.omnidas.ai/docs/guides/codex-manager-guide-setup.md))
  - If you've set up the core bundle, reuse the same `CODEX_SYNC_PAT`
- The [codex-github-core](https://github.com/omnidasai/codex-github-core) must be installed on your organization's central Codex repository

## Related Projects

- **[codex-github-core](https://github.com/omnidasai/codex-github-core)** - The core bundle containing GitHub workflows and infrastructure
