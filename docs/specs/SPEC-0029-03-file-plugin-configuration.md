# SPEC-0029-03: File Plugin Configuration & Init Command

**Issue**: #29
**Phase**: 1 (fractary-file Enhancement)
**Dependencies**: SPEC-0029-01, SPEC-0029-02
**Status**: Draft
**Created**: 2025-01-15

## Overview

Create the `/fractary-file:init` command and configuration wizard to simplify setup of the file plugin across all storage handlers. Implement sensible defaults (local storage) and interactive configuration for all 5 providers (Local, R2, S3, GCS, Google Drive).

## Requirements

### Functional Requirements

1. **Init Command**
   - Interactive wizard for provider selection
   - Guided credential collection
   - Configuration validation
   - Test connection before saving
   - Support `--global` flag for user-wide config
   - Support `--handler <provider>` for specific provider setup
   - Non-interactive mode with command-line arguments

2. **Default Configuration**
   - Default handler: `local`
   - Default path: `./storage`
   - Zero-configuration startup for local storage
   - Automatic directory creation

3. **Configuration File Management**
   - Global config: `~/.config/fractary/file/config.json`
   - Project config: `.fractary/plugins/file/config.json`
   - Project config overrides global config
   - Support environment variable expansion (`${VAR_NAME}`)

4. **Validation**
   - Validate configuration syntax
   - Validate required fields for each handler
   - Test connection to provider
   - Verify credentials work
   - Check bucket/folder existence

5. **Configuration Display**
   - Command to show current configuration
   - Mask sensitive values (credentials)
   - Show active handler
   - Show config source (global vs project)

### Non-Functional Requirements

1. **Security**
   - Never log credentials
   - Support environment variables for sensitive values
   - Recommend environment variables over hardcoded credentials
   - Secure file permissions on config files (0600)

2. **Usability**
   - Clear prompts and explanations
   - Helpful examples in wizard
   - Sensible defaults
   - Easy to re-run and update configuration

3. **Compatibility**
   - Work on Linux, macOS, WSL
   - Handle missing directories gracefully
   - Support both JSON and environment variables

## Architecture

### Command Structure

```
plugins/file/commands/
├── init.md
├── show-config.md
├── test-connection.md
└── switch-handler.md
```

### Init Command Flow

```
/fractary-file:init [--global] [--handler <provider>]
    ↓
Welcome message + explain purpose
    ↓
Select handler (or use --handler flag)
    ├─ local (default)
    ├─ r2
    ├─ s3
    ├─ gcs
    └─ gdrive
    ↓
Collect handler-specific configuration
    ├─ Prompt for required fields
    ├─ Suggest environment variables
    └─ Show examples
    ↓
Test connection (optional but recommended)
    ├─ Attempt list operation
    └─ Report success/failure
    ↓
Save configuration
    ├─ Choose global vs project
    ├─ Create directories if needed
    ├─ Set file permissions
    └─ Write JSON config
    ↓
Confirmation message
```

### Configuration Schema

Complete schema with all handlers:

```json
{
  "$schema": "https://fractary.com/schemas/file-plugin-config-v1.json",
  "schema_version": "1.0",
  "active_handler": "local",
  "handlers": {
    "local": {
      "base_path": "./storage",
      "create_directories": true,
      "permissions": "0755"
    },
    "r2": {
      "account_id": "${R2_ACCOUNT_ID}",
      "access_key_id": "${R2_ACCESS_KEY_ID}",
      "secret_access_key": "${R2_SECRET_ACCESS_KEY}",
      "bucket_name": "my-bucket",
      "public_url": "https://pub-xxxxx.r2.dev",
      "region": "auto"
    },
    "s3": {
      "region": "us-east-1",
      "bucket_name": "my-bucket",
      "access_key_id": "${AWS_ACCESS_KEY_ID}",
      "secret_access_key": "${AWS_SECRET_ACCESS_KEY}",
      "endpoint": null,
      "public_url": null
    },
    "gcs": {
      "project_id": "my-project",
      "bucket_name": "my-bucket",
      "service_account_key": "${GOOGLE_APPLICATION_CREDENTIALS}",
      "region": "us-central1"
    },
    "gdrive": {
      "client_id": "${GDRIVE_CLIENT_ID}",
      "client_secret": "${GDRIVE_CLIENT_SECRET}",
      "folder_id": "root",
      "auth_method": "oauth2"
    }
  },
  "global_settings": {
    "retry_attempts": 3,
    "retry_delay_ms": 1000,
    "timeout_seconds": 300,
    "verify_checksums": true,
    "parallel_uploads": 4
  }
}
```

## Implementation Details

### Init Command (commands/init.md)

```markdown
---
name: fractary-file:init
description: Initialize and configure the fractary-file plugin
---

# File Plugin Initialization

Initialize the fractary-file plugin with interactive configuration wizard.

## Usage

    /fractary-file:init [--global] [--handler <provider>] [--non-interactive]

## Options

- `--global`: Save configuration to user-wide location (~/.config/fractary/file/)
- `--handler <provider>`: Configure specific handler (local|r2|s3|gcs|gdrive)
- `--non-interactive`: Skip prompts, use defaults or environment variables
- `--test`: Test connection after configuration

## Examples

    # Interactive setup (local by default)
    /fractary-file:init

    # Setup S3 globally
    /fractary-file:init --global --handler s3

    # Non-interactive setup using environment variables
    /fractary-file:init --handler r2 --non-interactive

## Workflow

When invoked, this command:

1. Determines configuration location (global vs project)
2. Presents handler selection menu
3. Guides through handler-specific configuration
4. Offers to test connection
5. Saves configuration with appropriate permissions
6. Displays next steps

## Handler-Specific Prompts

### Local Handler
- Base path (default: ./storage)
- Create directories automatically? (default: yes)
- Directory permissions (default: 0755)

### R2 Handler
- Cloudflare Account ID
- R2 Access Key ID (suggest env var: R2_ACCESS_KEY_ID)
- R2 Secret Access Key (suggest env var: R2_SECRET_ACCESS_KEY)
- Bucket name
- Public URL (optional)

### S3 Handler
- AWS Region (default: us-east-1)
- Bucket name
- AWS Access Key ID (suggest env var: AWS_ACCESS_KEY_ID)
- AWS Secret Access Key (suggest env var: AWS_SECRET_ACCESS_KEY)
- Custom endpoint (optional, for S3-compatible services)

### GCS Handler
- GCP Project ID
- Bucket name
- Service account key path (suggest env var: GOOGLE_APPLICATION_CREDENTIALS)
- Region (default: us-central1)

### Google Drive Handler
- Client ID (suggest env var: GDRIVE_CLIENT_ID)
- Client Secret (suggest env var: GDRIVE_CLIENT_SECRET)
- Root folder ID (default: root)
- Authentication flow instructions

## Post-Configuration

After successful configuration:
1. Show active handler
2. Suggest testing with simple operation
3. Show configuration file location
4. Provide links to handler-specific documentation

## Error Handling

- Missing credentials: Show setup instructions for provider
- Invalid bucket/folder: Offer to create or verify name
- Connection test failed: Show detailed error and troubleshooting steps
- Permission denied: Check file permissions and suggest fixes
```

### Interactive Wizard Implementation

The wizard should be implemented as a skill that the init command invokes:

**skills/config-wizard/SKILL.md:**

```markdown
<CONTEXT>
You are the config-wizard skill for the fractary-file plugin. You guide users through interactive configuration setup with clear prompts, helpful examples, and validation.
</CONTEXT>

<CRITICAL_RULES>
1. NEVER store credentials in plaintext without warning user
2. ALWAYS recommend environment variables for sensitive data
3. ALWAYS test configuration before saving
4. NEVER proceed if validation fails without user confirmation
5. ALWAYS set secure file permissions (0600) on config files
</CRITICAL_RULES>

<WORKFLOW>

## Phase 1: Handler Selection

Prompt user to select handler:
```
🗄️  File Plugin Configuration

Which storage provider would you like to use?

  1. Local Filesystem (default, no setup required)
  2. Cloudflare R2 (S3-compatible)
  3. AWS S3
  4. Google Cloud Storage (GCS)
  5. Google Drive

Enter selection [1-5] (default: 1):
```

## Phase 2: Collect Configuration

Based on selection, collect required information:

### For Local:
```
📁 Local Filesystem Configuration

Storage path [./storage]: _____
Create directories automatically? [Y/n]: _____
Directory permissions [0755]: _____
```

### For R2:
```
☁️  Cloudflare R2 Configuration

Cloudflare Account ID: _____
R2 Bucket name: _____

For credentials, we recommend using environment variables:
  export R2_ACCESS_KEY_ID="your-key"
  export R2_SECRET_ACCESS_KEY="your-secret"

Enter R2 Access Key ID (or env var name) [${R2_ACCESS_KEY_ID}]: _____
Enter R2 Secret Access Key (or env var name) [${R2_SECRET_ACCESS_KEY}]: _____

Public URL (optional, for public files): _____
```

### For S3:
```
☁️  AWS S3 Configuration

AWS Region [us-east-1]: _____
S3 Bucket name: _____

For credentials, we recommend using environment variables:
  export AWS_ACCESS_KEY_ID="your-key"
  export AWS_SECRET_ACCESS_KEY="your-secret"

Or use IAM roles if running in AWS.

Enter AWS Access Key ID (or env var name) [${AWS_ACCESS_KEY_ID}]: _____
Enter AWS Secret Access Key (or env var name) [${AWS_SECRET_ACCESS_KEY}]: _____

Custom endpoint (for S3-compatible services) [none]: _____
```

### For GCS:
```
☁️  Google Cloud Storage Configuration

GCP Project ID: _____
GCS Bucket name: _____
Region [us-central1]: _____

For authentication, set up a service account:
1. Go to https://console.cloud.google.com/iam-admin/serviceaccounts
2. Create service account with Storage Admin role
3. Download JSON key file
4. Set environment variable: export GOOGLE_APPLICATION_CREDENTIALS="/path/to/key.json"

Service account key path [${GOOGLE_APPLICATION_CREDENTIALS}]: _____
```

### For Google Drive:
```
☁️  Google Drive Configuration

To use Google Drive, you need to:
1. Create OAuth 2.0 credentials at https://console.cloud.google.com/apis/credentials
2. Enable Google Drive API
3. Configure rclone with credentials

Client ID (or env var) [${GDRIVE_CLIENT_ID}]: _____
Client Secret (or env var) [${GDRIVE_CLIENT_SECRET}]: _____
Root folder ID [root]: _____

We'll help you set up rclone authentication after configuration is saved.
```

## Phase 3: Validation

Before saving, validate the configuration:
```
✓ Configuration collected
↻ Testing connection...
```

Run test operation (list with limit 1):
- Success: ✓ Connection successful
- Failure: ✗ Connection failed: [error message]

If test fails, offer options:
```
Connection test failed: [specific error]

Options:
1. Review and fix configuration
2. Save anyway (not recommended)
3. Cancel

Enter selection [1-3]:
```

## Phase 4: Save Configuration

Confirm save location:
```
Where should the configuration be saved?

1. Project (.fractary/plugins/file/config.json) - recommended
2. Global (~/.config/fractary/file/config.json)

Enter selection [1-2] (default: 1):
```

Save configuration:
```
💾 Saving configuration...
✓ Configuration saved to .fractary/plugins/file/config.json
✓ File permissions set to 0600 (secure)
```

## Phase 5: Next Steps

Show completion message:
```
✅ File plugin configured successfully!

Active handler: {provider}
Configuration: {path}

Next steps:
1. Test the plugin: /fractary-file:test
2. Upload a file: Use @agent-fractary-file:file-manager
3. Read documentation: {handler-specific-docs}

Environment variables required:
  {list of env vars if using ${VAR} syntax}

Make sure these are set before using the plugin.
```

</WORKFLOW>

<VALIDATION>
For each handler, validate:

**Local:**
- Path is writable
- Parent directory exists or can be created

**R2:**
- Account ID format valid
- Credentials set (either directly or env vars exist)
- Bucket accessible

**S3:**
- Region valid
- Bucket accessible
- Credentials valid

**GCS:**
- Project ID valid
- Service account key file exists and readable
- Bucket accessible

**Google Drive:**
- OAuth credentials format valid
- Rclone is installed
</VALIDATION>

<ERROR_HANDLING>
- Missing dependencies (rclone, aws cli, gcloud): Show installation instructions
- Invalid credentials: Show credential setup instructions
- Network errors: Suggest checking connectivity
- Permission denied: Show permission fix commands
</ERROR_HANDLING>
```

### Additional Commands

**commands/show-config.md:**
```markdown
---
name: fractary-file:show-config
description: Display current file plugin configuration
---

Displays the current configuration with sensitive values masked.

Example output:
```
📋 File Plugin Configuration

Active Handler: s3
Configuration Source: Project (.fractary/plugins/file/config.json)

Handler: s3
  Region: us-east-1
  Bucket: my-bucket
  Access Key ID: ****** (from ${AWS_ACCESS_KEY_ID})
  Secret Access Key: ****** (from ${AWS_SECRET_ACCESS_KEY})

Global Settings:
  Retry Attempts: 3
  Timeout: 300s
  Verify Checksums: true
```
```

**commands/test-connection.md:**
```markdown
---
name: fractary-file:test-connection
description: Test connection to configured storage provider
---

Tests the current file plugin configuration by attempting a list operation.

Example output:
```
🔍 Testing connection to s3...

✓ Authentication successful
✓ Bucket accessible
✓ List operation successful

Connection test passed! Plugin is ready to use.
```
```

**commands/switch-handler.md:**
```markdown
---
name: fractary-file:switch-handler
description: Switch active storage handler
---

Usage: /fractary-file:switch-handler <provider>

Switches the active handler to a different configured provider.

Example:
```
$ /fractary-file:switch-handler r2

Switching active handler from 'local' to 'r2'...
✓ Handler switched successfully

Active handler is now: r2
Configuration: .fractary/plugins/file/config.json

Note: Make sure r2 handler is properly configured.
Test with: /fractary-file:test-connection
```
```

## Testing Strategy

### Unit Tests
- Configuration file creation
- Configuration merging (global + project)
- Environment variable expansion
- Validation logic for each handler
- Permission setting

### Integration Tests
- Interactive wizard with simulated input
- Non-interactive mode with command-line args
- Configuration save and load
- Handler switching
- Connection testing

### Manual Tests
- Run init wizard for each handler
- Test with real credentials
- Test environment variable expansion
- Test global vs project config
- Test configuration updates

## Success Criteria

- [ ] /fractary-file:init command works interactively
- [ ] Non-interactive mode works with environment variables
- [ ] Default (local) handler requires no configuration
- [ ] All 5 handlers can be configured through wizard
- [ ] Configuration validation catches common errors
- [ ] Connection tests work for all handlers
- [ ] Credentials are properly secured (file permissions)
- [ ] Environment variable substitution works
- [ ] Configuration can be displayed (with masking)
- [ ] Handler switching works
- [ ] Documentation complete

## Open Questions

1. Should we support importing configuration from other tools (aws cli config, gcloud config)?
   - **Decision**: Defer to future enhancement, manual config for now

2. Should we auto-detect IAM roles/instance profiles for S3?
   - **Decision**: Yes, support empty credentials for IAM role usage

3. Should we validate bucket ownership or just access?
   - **Decision**: Just validate access (list permission sufficient)

## Implementation Checklist

- [ ] Create commands/init.md
- [ ] Create skills/config-wizard/SKILL.md
- [ ] Implement handler selection menu
- [ ] Implement configuration collectors for all 5 handlers
- [ ] Implement validation logic
- [ ] Implement connection testing
- [ ] Implement configuration saving with secure permissions
- [ ] Create commands/show-config.md
- [ ] Create commands/test-connection.md
- [ ] Create commands/switch-handler.md
- [ ] Create config.example.json
- [ ] Write user documentation
- [ ] Test all handlers
- [ ] Test global vs project configuration
- [ ] Test environment variable expansion

## Timeline

**Estimated Duration**: 1 week

**Breakdown**:
- Days 1-2: Init command and wizard implementation
- Days 3-4: Validation and connection testing
- Day 5: Additional commands (show, test, switch)
- Days 6-7: Testing and documentation

## Dependencies

- SPEC-0029-01: Architecture
- SPEC-0029-02: All handler implementations

## Next Steps

After Phase 1 complete, proceed to:
- **SPEC-0029-04**: Begin Phase 2 (fractary-docs plugin)
