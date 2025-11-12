# Documentation Standards

Standards for documentation across the Fractary plugin ecosystem.

**Version**: 2.0 (2025-01-15)

## Overview

This document defines documentation standards for:
- Plugin READMEs
- User guides
- API documentation
- Examples and tutorials
- Troubleshooting guides
- Migration guides

## Plugin README Standards

### Structure

Every plugin README must include:

1. **Title** - Plugin name prominently displayed
2. **Overview** - Brief description (2-3 paragraphs)
3. **Key Features** - Bulleted list of main features
4. **Quick Start** - Get up and running in < 5 minutes
5. **Architecture** - High-level architecture diagram/description
6. **Operations/Commands** - Comprehensive operation reference
7. **Configuration** - Configuration options and examples
8. **Integration** - How it integrates with other plugins
9. **Troubleshooting** - Common issues and solutions
10. **Documentation Links** - Links to detailed guides
11. **Version & Changelog** - Current version and major changes

### Template

```markdown
# Plugin Name

Brief description.

## Overview

Comprehensive overview with key concepts.

### Key Features

- Feature 1
- Feature 2
- Feature 3

## Quick Start

Minimal steps to get started (< 5 minutes).

## Architecture

Three-layer architecture diagram and explanation.

## Operations

Detailed operation documentation.

## Configuration

Configuration schema and examples.

## Integration

Integration with other plugins.

## Troubleshooting

Common issues.

## Documentation

Links to detailed guides.

## Version

Current version and changelog.
```

### Writing Style

- **Clear and concise** - No unnecessary jargon
- **Action-oriented** - Use active voice
- **Progressive disclosure** - Basic → advanced
- **Code examples** - Concrete examples for everything
- **Visual aids** - Diagrams where helpful

### Code Examples

**Do**:
```markdown
Use @agent-fractary-file:file-manager to upload:
{
  "operation": "upload",
  "parameters": {
    "local_path": "./file.txt",
    "remote_path": "archive/file.txt"
  }
}
```

**Don't**:
```markdown
Call the file upload API.
```

Always show complete, runnable examples.

---

## User Guide Standards

### Purpose

User guides provide **comprehensive, task-oriented documentation** for a single plugin or feature.

### Structure

1. **Title & Overview** - What is this guide about?
2. **Table of Contents** - For guides > 3 pages
3. **Key Concepts** - Core concepts explained
4. **Quick Start** - Minimal working example
5. **Detailed Topics** - Organized by task/feature
6. **Configuration** - All configuration options
7. **Integration** - Working with other tools
8. **Advanced Topics** - Power user features
9. **Troubleshooting** - Common issues
10. **Best Practices** - Recommended patterns
11. **Further Reading** - Links to related docs

### Length

- **Minimum**: 2,000 words
- **Target**: 3,000-5,000 words
- **Maximum**: 10,000 words

If exceeding 10,000 words, split into multiple focused guides.

### Writing Guidelines

**Progressive complexity**:
- Start simple
- Build complexity gradually
- Advanced topics at end

**Task-oriented**:
- Organize by what users want to accomplish
- Use "How to..." framing
- Provide complete working examples

**Reference material**:
- Include comprehensive configuration reference
- Document all options, even rarely-used ones
- Explain "why" not just "what"

### Example Titles

Good:
- "Fractary File Plugin - Comprehensive Guide"
- "Setting Up Cloud Storage"
- "Migrating to New Plugins"

Bad:
- "File Plugin"
- "Documentation"
- "Guide"

---

## API Documentation Standards

### Purpose

API documentation defines **exact invocation patterns** for agents and provides request/response schemas.

### Structure

```markdown
# API Reference

## Overview
Brief introduction to API patterns.

## Plugin Name API

### operation-name

Description of operation.

**Request**:
```
Full request template with types
```

**Response**:
```json
Response schema
```

**Example**:
```
Complete working example
```

**Error Codes**:
- ERROR_CODE: Description
```

### Request Documentation

**Always include**:
- Parameter types (string, number, boolean, object, array)
- Required vs optional
- Default values
- Valid ranges/options

**Example**:
```markdown
**Request**:
```
Use @agent-fractary-file:file-manager to upload:
{
  "operation": "upload",
  "parameters": {
    "local_path": string,     // Required: Path to local file
    "remote_path": string,    // Required: Destination path
    "public": boolean         // Optional: Make public (default: false)
  }
}
```
```

### Response Documentation

**Always include**:
- Success response schema
- Error response schema
- Example responses
- Field descriptions

### Error Documentation

Document all error codes:
```markdown
### Error Codes

- `INVALID_PARAMETERS`: Missing required parameters
- `FILE_NOT_FOUND`: Requested file doesn't exist
- `PERMISSION_DENIED`: Insufficient permissions
```

---

## Example & Tutorial Standards

### Examples

**Purpose**: Demonstrate specific feature or workflow

**Structure**:
1. **Scenario** - What are we demonstrating?
2. **Prerequisites** - What's needed before starting
3. **Steps** - Step-by-step walkthrough
4. **Expected Output** - What should happen
5. **Troubleshooting** - Common issues
6. **Next Steps** - What to explore next

**Length**: 500-2,000 words

**Example Types**:
- Complete workflow examples
- Integration examples
- Multi-plugin examples
- Real-world scenarios

### Tutorials

**Purpose**: Teach how to accomplish specific task

**Structure**:
1. **Goal** - What will you learn?
2. **Prerequisites** - Required knowledge/setup
3. **Time Estimate** - How long will this take?
4. **Steps** - Detailed steps with explanations
5. **Verification** - How to verify success
6. **Troubleshooting** - Common issues
7. **Next Steps** - Related tutorials

**Length**: 1,000-3,000 words

**Tutorial Types**:
- Setup tutorials
- Integration tutorials
- Advanced technique tutorials
- Migration tutorials

### Writing Guidelines

**For Examples**:
- Show, don't tell
- Complete, runnable code
- Real-world scenarios
- Annotated with explanations

**For Tutorials**:
- Step-by-step instructions
- Explain "why" at each step
- Include checkpoints
- Provide troubleshooting

**Both**:
- Use consistent formatting
- Include time estimates
- Test all code examples
- Update when APIs change

---

## Troubleshooting Guide Standards

### Structure

```markdown
# Troubleshooting Guide

## Table of Contents
Organized by category.

## Category Name

### Symptom/Problem

**Symptoms**:
- Observable symptoms

**Causes**:
- Possible causes

**Solutions**:
1. Solution 1 (most likely)
2. Solution 2
3. Solution 3

**Example**:
```
Working example of solution
```
```

### Categories

Common categories:
- General Issues
- Plugin-Specific Issues
- Integration Issues
- Configuration Issues
- Performance Issues
- Error Messages

### Writing Guidelines

**Symptoms first**:
- Lead with observable symptoms
- Use exact error messages
- Describe visible behavior

**Progressive solutions**:
- Simple/common solutions first
- Complex solutions last
- Explain trade-offs

**Complete examples**:
- Show commands to run
- Show expected output
- Show how to verify fix

---

## Migration Guide Standards

### Structure

```markdown
# Migration Guide

## Overview
What's changing and why.

## Benefits
What you gain from migrating.

## Quick Start
Minimal migration steps.

## Detailed Migration

### Step 1: Title
Detailed instructions.

### Step 2: Title
Detailed instructions.

## Backward Compatibility
What still works.

## Rollback Plan
How to undo migration.

## Troubleshooting
Common migration issues.
```

### Types

1. **User Migration Guides**
   - For end users
   - Task-oriented
   - Minimal technical detail

2. **Developer Migration Guides**
   - For plugin developers
   - Implementation-focused
   - Technical detail

### Writing Guidelines

**Clarity**:
- Explain impact clearly
- No surprises
- Honest about effort

**Safety**:
- Rollback procedures
- Backward compatibility
- Risk mitigation

**Support**:
- Troubleshooting section
- Support resources
- Known issues

---

## Writing Style Guidelines

### General Principles

1. **Clarity over cleverness**
   - Simple, direct language
   - No unnecessary jargon
   - Define technical terms

2. **Active voice**
   - "Upload the file" not "The file should be uploaded"
   - "The plugin creates..." not "The file is created by..."

3. **Present tense**
   - "The plugin uploads files" not "The plugin will upload files"

4. **Second person for instructions**
   - "You can configure..." not "One can configure..."

5. **Consistent terminology**
   - Choose one term and stick with it
   - "Plugin" not "plugin/extension/addon"
   - "Archive" not "archive/store/save"

### Formatting Standards

**Headings**:
- Use ATX-style headings (`#` not underlines)
- Title case for H1
- Sentence case for H2-H6

**Code blocks**:
- Always specify language
- Use `bash` for shell commands
- Use `json` for JSON
- Use `markdown` for markdown examples

**Lists**:
- Use `-` for unordered lists
- Use `1.` for ordered lists
- Indent nested lists by 2 spaces

**Emphasis**:
- **Bold** for strong emphasis, UI elements, important terms
- *Italic* for emphasis, first use of terms
- `Code` for commands, file names, code elements

### Examples

**Good**:
```markdown
Upload the file to cloud storage:

```bash
/fractary-file:upload ./file.txt
```

The plugin uploads the file and returns a URL.
```

**Bad**:
```markdown
The file can be uploaded by using the upload command which will cause the system to store the file in cloud storage and a URL will be returned.
```

---

## Code Example Standards

### General Guidelines

- **Complete**: Show full context, not fragments
- **Runnable**: Code should work as-is
- **Annotated**: Explain non-obvious parts
- **Tested**: All examples must be tested

### Agent Invocation Examples

**Always use declarative format**:
```markdown
Use the @agent-fractary-file:file-manager agent to upload:
{
  "operation": "upload",
  "parameters": {
    "local_path": "./file.txt",
    "remote_path": "archive/file.txt"
  }
}
```

**Never use**:
- Pseudo-code
- Incomplete fragments
- Untested examples

### Configuration Examples

**Show complete files**:
```json
{
  "schema_version": "1.0",
  "active_handler": "r2",
  "handlers": {
    "r2": {
      "account_id": "${R2_ACCOUNT_ID}",
      "access_key_id": "${R2_ACCESS_KEY_ID}",
      "secret_access_key": "${R2_SECRET_ACCESS_KEY}",
      "bucket_name": "my-bucket"
    }
  }
}
```

**Include comments**:
```json
{
  "active_handler": "r2",  // Which handler to use
  "handlers": {
    "r2": {
      "bucket_name": "my-bucket"  // Your R2 bucket name
    }
  }
}
```

---

## File Organization Standards

### Directory Structure

```
docs/
├── guides/           # User guides (task-oriented)
├── api/              # API reference docs
├── examples/         # Example workflows
├── tutorials/        # Step-by-step tutorials
├── standards/        # Documentation standards
└── specs/            # Technical specifications
```

### File Naming

**Guides**:
- `plugin-name-guide.md`
- `migrating-to-feature.md`
- `troubleshooting.md`

**API Docs**:
- `plugin-api-reference.md`
- `plugins-api-reference.md` (combined)

**Examples**:
- `complete-workflow-name.md`
- `integration-scenario.md`

**Tutorials**:
- `setup-feature-name.md`
- `howto-task-name.md`

**Use**:
- Lowercase
- Hyphens not underscores
- Descriptive names
- `.md` extension

---

## Maintenance Standards

### Review Cycle

- **Quarterly**: Review all docs for accuracy
- **On release**: Update docs for changes
- **On user feedback**: Address gaps immediately

### Update Process

1. Identify outdated content
2. Update documentation
3. Test all examples
4. Update version/date
5. Commit with descriptive message

### Versioning

**In document**:
```markdown
---

**Version**: 1.0 (2025-01-15)
```

**Changelog**:
```markdown
## Changelog

### v1.1 (2025-02-01)
- Added section on X
- Updated Y for new API

### v1.0 (2025-01-15)
- Initial release
```

### Deprecation

**When deprecating**:
1. Add warning at top
2. Link to replacement docs
3. Keep for 2 versions
4. Remove when safe

**Deprecation notice**:
```markdown
> ⚠️ **DEPRECATED**: This guide is deprecated as of v2.0. See [New Guide](link) for current documentation.
```

---

## Quality Checklist

Before publishing documentation:

- [ ] All code examples tested
- [ ] Links verified (no broken links)
- [ ] Formatting consistent
- [ ] Spelling and grammar checked
- [ ] Screenshots/diagrams current
- [ ] Follows style guidelines
- [ ] Version number updated
- [ ] Changelog updated
- [ ] Cross-references correct
- [ ] Peer reviewed (for major docs)

---

## Tools

### Validation

```bash
# Validate all markdown
./tools/validate-docs.sh

# Check links
./tools/check-links.sh

# Spell check
./tools/spell-check.sh
```

### Generation

```bash
# Generate README from template
./tools/generate-readme.sh plugin-name

# Generate API docs
./tools/generate-api-docs.sh plugin-name
```

---

## Further Reading

### Related Standards

- [FRACTARY-PLUGIN-STANDARDS.md](./FRACTARY-PLUGIN-STANDARDS.md) - Plugin development standards
- [COMMAND-TEMPLATE.md](./COMMAND-TEMPLATE.md) - Command documentation template
- [CHANGELOG-STANDARDS.md](./CHANGELOG-STANDARDS.md) - Changelog maintenance and versioning
- [LOG-STANDARDS.md](./LOG-STANDARDS.md) - Log types, retention, and management

### Domain-Specific Documentation

- **Changelogs**: See [CHANGELOG-STANDARDS.md](./CHANGELOG-STANDARDS.md) for:
  - Keep a Changelog format
  - Semantic versioning guidelines
  - Breaking change documentation
  - Update timing and automation

- **Logs**: See [LOG-STANDARDS.md](./LOG-STANDARDS.md) for:
  - Log type categories (session, build, test, deployment, audit, etc.)
  - Retention policies and archival
  - Cloud storage integration
  - Audit report standards

---

**Standards Version**: 2.0 (2025-01-15)
**Last Updated**: 2025-01-15
**Next Review**: 2025-04-15
