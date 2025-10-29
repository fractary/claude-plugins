# Fractary Work Manager Plugin

Work item management across multiple platforms.

## Overview

The `fractary-work` plugin provides a unified interface for working with issues, tickets, and work items across different project management platforms. It abstracts platform-specific differences, allowing other Fractary plugins to work seamlessly regardless of the underlying platform.

## Platforms Supported

- ✅ **GitHub Issues** (complete) - Full implementation with issue fetching, commenting, labeling
- 🚧 **Jira** (structure ready) - Framework in place, scripts need implementation
- 🚧 **Linear** (structure ready) - Framework in place, scripts need implementation

## Installation

```bash
claude plugin install fractary/work
```

## Components

### Agent

**`work-manager`** - Orchestrates work item operations
- Fetches work items from configured platform
- Creates comments and updates
- Manages labels and status
- Classifies work item types

### Skill

**`work-manager`** - Platform adapter selection
- Reads configuration to determine active platform (GitHub/Jira/Linear)
- Invokes appropriate platform-specific scripts
- Handles platform-specific data formats

## Configuration

When used with `fractary-faber`, configure in `faber.yaml`:

```yaml
handlers:
  issue_tracker:
    active: "github"
    github:
      owner: "myorg"
      repo: "my-project"
```

## Usage

This plugin is primarily used by other Fractary plugins (especially `fractary-faber`) and typically not invoked directly by users.

**Agent invocation example:**
```bash
claude --agent fractary-work/work-manager "fetch issue-123"
```

## Directory Structure

```
work/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── agents/
│   └── work-manager.md      # Work manager agent
├── skills/
│   └── work-manager/
│       ├── SKILL.md         # Skill definition
│       ├── scripts/
│       │   ├── github/      # GitHub adapter
│       │   ├── jira/        # Jira adapter (future)
│       │   └── linear/      # Linear adapter (future)
│       └── docs/
│           ├── github-api.md
│           ├── jira-api.md
│           └── linear-api.md
└── README.md                # This file
```

## Adding New Platforms

To add support for a new platform:

1. Create scripts directory: `skills/work-manager/scripts/{platform}/`
2. Implement required scripts:
   - `fetch-issue.sh` - Fetch work item details
   - `create-comment.sh` - Post comments
   - `set-label.sh` - Manage labels
   - `classify-issue.sh` - Classify work type
3. Add API documentation: `skills/work-manager/docs/{platform}-api.md`
4. Update handler configuration in your project's `faber.yaml`

## License

Part of the Fractary plugin ecosystem.
