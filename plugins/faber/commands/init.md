# /fractary-faber:init

Initialize FABER workflow configuration for a project.

## What This Does

Analyzes your project and generates `.fractary/plugins/faber/config.json` with appropriate settings for your project type.

**Features**:
- 🔍 Auto-detects project type (software, infrastructure, application)
- 📝 Generates configuration from appropriate template
- ⚙️ Configures default phases and steps
- 🪝 Sets up hook points for customization
- ✅ Validates configuration after creation

## Usage

```bash
# Auto-detect project type and generate config
/fractary-faber:init

# Specify project type explicitly  
/fractary-faber:init --type software

# Analyze without creating config (dry-run)
/fractary-faber:init --analyze
```

## Implementation

This command should:
1. Analyze project structure to detect type
2. Select appropriate template (software/infrastructure/application)
3. Generate `.fractary/plugins/faber/config.json`
4. Validate configuration
5. Report success

Templates are located in `plugins/faber/config/templates/`

## See Also

- `/fractary-faber:audit` - Validate configuration
- `/fractary-faber:run` - Execute workflow
- Config templates: `plugins/faber/config/templates/`
