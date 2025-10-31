# Fractary FABER Architecture Specification

**Version:** 1.0.0
**Date:** 2025-01-28
**Status:** Draft

---

## Table of Contents

1. [Overview](#overview)
2. [FABER Framework](#faber-framework)
3. [Architecture Philosophy](#architecture-philosophy)
4. [Plugin Taxonomy](#plugin-taxonomy)
5. [Core Components](#core-components)
6. [Configuration System](#configuration-system)
7. [Repository Structure](#repository-structure)
8. [Plugin Naming & Namespacing](#plugin-naming--namespacing)
9. [Distribution & Installation](#distribution--installation)
10. [Conversion & Portability](#conversion--portability)
11. [Implementation Phases](#implementation-phases)
12. [Example Usage](#example-usage)
13. [Appendix](#appendix)

---

## Overview

### Purpose

Fractary FABER is a universal workflow framework for AI-assisted development that provides structured, repeatable processes for creating any artifact—from application code to content to infrastructure.

### Key Principles

1. **Universal Applicability**: FABER works for any artifact with a creation lifecycle
2. **Framework Agnostic**: Claude Code native, but convertible to other frameworks
3. **Minimal Configuration**: Simple YAML config enables complex workflows
4. **Artifact-Focused**: Named by what they produce, not who uses them
5. **Composable**: Plugins can extend and combine

### FABER Acronym

**F**rame → **A**rchitect → **B**uild → **E**valuate → **R**elease

A five-stage lifecycle that applies universally:
- **Frame**: Define requirements and goals
- **Architect**: Design the solution
- **Build**: Create the artifact
- **Evaluate**: Test and validate
- **Release**: Deploy and document

---

## FABER Framework

### The Five Stages

#### 1. Frame
**Purpose:** Understand what needs to be built

**Activities:**
- Gather requirements
- Define acceptance criteria
- Identify constraints
- Analyze audience/users
- Research existing solutions

**Outputs:**
- Requirements document
- Success criteria
- Constraints list
- Research findings

**Checkpoints:**
- Requirements are clear and complete
- Acceptance criteria are measurable
- Stakeholders agree on scope

---

#### 2. Architect
**Purpose:** Design the solution structure

**Activities:**
- Create architecture design
- Plan implementation approach
- Design interfaces/APIs
- Identify components
- Document decisions

**Outputs:**
- Architecture diagrams
- Design specifications
- Component breakdown
- Decision records (ADRs)

**Checkpoints:**
- Architecture is feasible
- Design meets requirements
- Technical approach is sound
- Team agrees on design

---

#### 3. Build
**Purpose:** Create the artifact

**Activities:**
- Write code/content
- Implement design
- Create assets
- Generate artifacts
- Integrate components

**Outputs:**
- Source code
- Content files
- Configuration
- Assets (images, videos, etc.)

**Checkpoints:**
- Artifact is created
- Code/content is complete
- Structure matches design
- Initial quality checks pass

---

#### 4. Evaluate
**Purpose:** Validate quality and correctness

**Activities:**
- Run tests
- Review quality
- Check against requirements
- Gather feedback
- Identify issues

**Outputs:**
- Test results
- Quality metrics
- Review feedback
- Issue list

**Checkpoints:**
- Tests pass
- Quality meets standards
- Requirements are satisfied
- Issues are addressed

---

#### 5. Release
**Purpose:** Deploy and document

**Activities:**
- Deploy to production
- Generate documentation
- Update version
- Create changelog
- Notify stakeholders

**Outputs:**
- Deployed artifact
- Documentation
- Release notes
- Version tag

**Checkpoints:**
- Artifact is deployed
- Documentation is complete
- Version is updated
- Stakeholders notified

---

## Architecture Philosophy

### Key Architectural Insights

#### 1. Custom Logic is an Artifact, Not Agent Logic

**Insight:** Even "domain-specific" logic (like novel anti-bot strategies) isn't a feature of the agent—it's an **output artifact** (code) produced by a generic agent reading specs.

**Implication:** Agents can be generic; domain knowledge lives in:
- Specifications (docs/specs/)
- Configuration (faber.yaml)
- Skills (project-specific)

#### 2. Director and Manager Are Generic

**Director:**
- Batch/parallel orchestration
- Intent parsing (via domain glossary)
- Entity discovery and filtering
- Result aggregation

**Manager:**
- Workflow execution
- Checkpoint validation
- Issue tracking integration
- Context maintenance

**Both are 100% generic** - domain knowledge is in configuration artifacts.

#### 3. Workflows vs. Infrastructure Separation

**Software Engineering Workflow:**
- **Builds:** Application code
- **Release:** Simple deploy to existing infrastructure

**Cloud Infrastructure Workflow:**
- **Builds:** Cloud infrastructure
- **Release:** Provision/update infrastructure

**Relationship:** Software engineering depends on cloud infrastructure but they build different things.

#### 4. Single Config File Pattern

All project configuration in one file (`faber.yaml`):
- Project metadata
- Handler configuration (GitHub, Jira, etc.)
- Domain glossary (embedded)
- Entity registry (embedded)
- Workflow definitions
- Skill mappings

**~400 lines covers complete framework** for complex projects.

---

## Plugin Taxonomy

### Repository: `claude-plugins`

Single monorepo (in fractary GitHub org) containing all Fractary Claude Code plugins.

**GitHub URL:** `github.com/fractary/claude-plugins`

### Plugin Categories

#### Foundation
**`fractary-faber`**
- Director agent
- Manager agent
- IssueManager, RepoManager, FileManager
- Workflow engine
- Handler abstractions

#### Technical Workflows
**`fractary-faber-app`**
- Application development (web, mobile, desktop, cross-platform)
- Supports: React, React Native, Flutter, Electron, etc.
- Features: create-feature, fix-bug, refactor-code

**`fractary-faber-api`**
- Backend services and APIs
- Supports: REST, GraphQL, gRPC, serverless
- Features: create-endpoint, add-model, implement-auth

**`fractary-faber-cloud`**
- Cloud infrastructure and operations
- Supports: AWS, GCP, Azure, Terraform, Kubernetes, Docker, CI/CD
- Features: provision-infra, deploy, scale, monitor

**`fractary-faber-cli`**
- Command-line tools and scripts
- Supports: Python CLI, Node CLI, shell scripts
- Features: create-command, add-argument, implement-output

**`fractary-faber-lib`**
- Libraries, SDKs, and packages
- Supports: NPM, PyPI, crates.io, etc.
- Features: create-library, add-api, publish

**`fractary-faber-scraper`**
- Web scrapers (Corthovore's domain)
- Features: create-scraper, add-extractor, test-scraper

**`fractary-faber-etl`**
- Data pipelines (Extract, Transform, Load)
- Supports: ETL, ELT, streaming, batch processing
- Features: create-pipeline, add-transform, schedule

**`fractary-faber-model`**
- Machine learning models
- Features: train-model, evaluate, deploy

#### Content Workflows
**`fractary-faber-video`**
- Video creation (YouTube, courses, tutorials)
- Features: create-video, edit, publish

**`fractary-faber-blog`**
- Written content (blog posts, articles)
- Features: create-post, optimize-seo, publish

**`fractary-faber-www`**
- Marketing websites and landing pages
- Supports: Static sites, WordPress, Webflow, landing pages
- Features: create-site, create-landing-page, optimize-conversion

**`fractary-faber-podcast`**
- Podcast episodes
- Features: create-episode, edit, publish

**`fractary-faber-course`**
- Online courses
- Features: create-course, add-lesson, publish

**`fractary-faber-social`**
- Social media campaigns
- Features: create-campaign, schedule-posts

#### Utility Tools
**`fractary-convert`**
- Framework conversion tool

**`fractary-validator`**
- Configuration validation

**`fractary-sync`**
- Plugin synchronization

---

## Core Components

### Director Agent

**Purpose:** Multi-entity orchestration and lifecycle coordination

**Responsibilities:**
1. **Intent Parsing:** Convert natural language → structured commands
2. **Batch Operations:** Spawn multiple manager instances (parallel/sequential)
3. **Entity Discovery:** Query and filter entities based on criteria
4. **Result Aggregation:** Collect and summarize results
5. **Lifecycle Coordination:** Enforce FABER checkpoints

**Key Features:**
- Reads domain glossary for intent parsing
- Reads entity registry for entity queries
- Framework-agnostic (bundled in faber-core)

**Example Commands:**
```bash
# User says: "test all zillow scrapers"
# Director:
# 1. Parses: {operation: test, entity_type: scraper, filter: {target: zillow}}
# 2. Queries: entity_registry.scrapers where target=zillow
# 3. Spawns: manager instances for each scraper (parallel)
# 4. Aggregates: results from all managers
```

---

### Manager Agent

**Purpose:** Single-entity workflow execution

**Responsibilities:**
1. **Workflow Execution:** Execute FABER stages sequentially
2. **Skill Invocation:** Call appropriate skills for each stage
3. **Checkpoint Validation:** Validate stage checkpoints
4. **Context Maintenance:** Track state through workflow
5. **Issue Reporting:** Self-report progress to issue tracker
6. **User Interaction:** Prompt user at non-auto stages

**Key Features:**
- Reads workflow-config.yaml
- Executes stages: Frame → Architect → Build → Evaluate → Release
- Maintains context across steps
- Framework-agnostic (bundled in faber-core)

**Example Execution:**
```yaml
workflow: create-scraper
entity: zillow-listings

stages:
  - frame:
      skills: [requirements-gatherer]
      checkpoints: [requirements_clear]
      result: ✓ passed

  - architect:
      skills: [scraper-designer]
      checkpoints: [design_valid]
      result: ✓ passed

  - build:
      skills: [scraper-builder]
      checkpoints: [config_created, config_valid]
      result: ✓ passed

  - evaluate:
      skills: [job-runner-local]
      checkpoints: [test_passes]
      result: ✓ passed

  - release:
      skills: [scraper-documenter, git-committer]
      checkpoints: [documented, committed]
      result: ✓ passed
```

---

### IssueManager Agent

**Purpose:** Issue tracker integration

**Handler Abstraction:**
```python
class IssueHandler(ABC):
    @abstractmethod
    def create_issue(self, title, body, labels) -> str: pass

    @abstractmethod
    def update_issue(self, issue_id, updates) -> bool: pass

    @abstractmethod
    def close_issue(self, issue_id, resolution) -> bool: pass
```

**Implementations:**
- GitHub Issues
- GitLab Issues
- Jira
- Linear
- Custom (extensible)

**Usage:**
```python
# In Manager workflow
issue_manager.update_issue(
    issue_id=self.issue_id,
    updates={
        'status': 'in_progress',
        'comment': 'Stage: Build - Creating scraper configuration'
    }
)
```

---

### RepoManager Agent

**Purpose:** Repository operations

**Handler Abstraction:**
```python
class RepoHandler(ABC):
    @abstractmethod
    def create_branch(self, branch_name, base_branch) -> bool: pass

    @abstractmethod
    def commit_files(self, files, message) -> str: pass

    @abstractmethod
    def create_pull_request(self, title, body, base, head) -> str: pass

    @abstractmethod
    def create_release(self, tag, name, notes) -> str: pass
```

**Implementations:**
- GitHub
- GitLab
- Bitbucket
- Custom (extensible)

---

### FileManager Agent

**Purpose:** File system operations

**Capabilities:**
- Read/write files
- Search files by pattern
- Directory operations
- File validation

**Usage:**
```python
# In skill execution
file_manager.write_file(
    path='scraper_configs/zillow-listings.yaml',
    content=scraper_config
)
```

---

## Configuration System

### faber.yaml Schema

**Single configuration file** (~400 lines for complex projects, ~50 for simple)

```yaml
# ==================================================
# PROJECT METADATA
# ==================================================
project:
  name: "my-project"
  type: "web-app"
  version: "1.0.0"
  description: "Project description"

# ==================================================
# HANDLER CONFIGURATION
# ==================================================
handlers:
  issue_tracker:
    type: "github-issues"  # or: jira, linear, gitlab-issues
    config:
      owner: "myorg"
      repo: "my-project"
      default_labels: ["faber"]

  repository:
    type: "github"  # or: gitlab, bitbucket
    config:
      owner: "myorg"
      repo: "my-project"
      main_branch: "main"

# ==================================================
# DOMAIN GLOSSARY (Embedded)
# ==================================================
glossary:
  # Entity definitions
  feature:
    aliases: ["feature", "capability", "functionality"]
    description: "New functionality for the application"

  bug:
    aliases: ["bug", "issue", "defect"]
    description: "Problem to be fixed"

# ==================================================
# ENTITY REGISTRY (Embedded)
# ==================================================
entities:
  feature:
    primary_key: "name"
    file_location: "src/features/"
    file_pattern: "{name}/"
    required_fields: [name, description]

  component:
    primary_key: "name"
    file_location: "src/components/"
    file_pattern: "{name}.tsx"

# ==================================================
# WORKFLOWS
# ==================================================
workflows:
  create-feature:
    description: "Create new application feature"

    stages:
      - stage: frame
        description: "Define feature requirements"
        skills:
          - requirements-gatherer
          - acceptance-criteria-writer
        checkpoints:
          - requirements_clear
          - acceptance_criteria_defined

      - stage: architect
        description: "Design feature architecture"
        skills:
          - architecture-designer
          - api-spec-generator
        checkpoints:
          - architecture_defined
          - api_spec_complete

      - stage: build
        description: "Implement feature"
        skills:
          - code-generator
          - test-generator
        outputs:
          - files_created
        checkpoints:
          - code_implemented
          - tests_written

      - stage: evaluate
        description: "Test feature"
        skills:
          - test-runner
          - code-reviewer
        checkpoints:
          - tests_pass
          - code_reviewed

      - stage: release
        description: "Deploy and document"
        skills:
          - deployer
          - documentation-generator
        checkpoints:
          - deployed
          - documented

# ==================================================
# SKILLS
# ==================================================
skills:
  requirements-gatherer:
    agent: requirements_manager
    description: "Gather feature requirements from user"
    inputs: [feature_name]
    outputs: [requirements_doc]

  code-generator:
    agent: code_manager
    description: "Generate code for feature"
    inputs: [requirements, architecture]
    outputs: [source_files]

  test-runner:
    agent: test_manager
    description: "Run test suite"
    inputs: [test_pattern]
    outputs: [test_results, coverage]

# ==================================================
# AGENTS
# ==================================================
agents:
  requirements_manager:
    description: "Manages requirements gathering"
    skills: [requirements-gatherer, acceptance-criteria-writer]

  code_manager:
    description: "Manages code generation"
    skills: [code-generator, test-generator]

  test_manager:
    description: "Manages testing"
    skills: [test-runner, coverage-analyzer]
```

---

### Configuration Sections Explained

#### Project Metadata
Basic project information used throughout workflows.

#### Handler Configuration
Platform integrations (GitHub, Jira, etc.) with credentials and settings.

#### Domain Glossary
Maps natural language terms to entities and operations for intent parsing.

#### Entity Registry
Defines entity types, their locations, and metadata for querying.

#### Workflows
FABER stage definitions with skills, checkpoints, and outputs.

#### Skills
Atomic operations that can be invoked during workflow stages.

#### Agents
Logical groupings of skills (can be project-specific or from plugins).

---

## Repository Structure

### Monorepo Organization

```
claude-plugins/
├── .claudeplugins                        # Manifest
├── plugins/
│   ├── faber/                            # Foundation (core)
│   │   ├── .claude/
│   │   │   ├── agents/
│   │   │   │   ├── director.md
│   │   │   │   ├── manager.md
│   │   │   │   ├── issue-manager.md
│   │   │   │   ├── repo-manager.md
│   │   │   │   └── file-manager.md
│   │   │   └── skills/
│   │   │       ├── arg-parser/
│   │   │       ├── workflow-executor/
│   │   │       ├── checkpoint-validator/
│   │   │       └── intent-parser/
│   │   ├── handlers/
│   │   │   ├── github.py
│   │   │   ├── gitlab.py
│   │   │   ├── jira.py
│   │   │   └── linear.py
│   │   ├── faber.yaml.template
│   │   └── README.md
│   │
│   ├── faber-app/                        # Workflow plugins
│   │   ├── .claude/
│   │   │   └── skills/
│   │   │       ├── code-generator/
│   │   │       ├── test-runner/
│   │   │       └── deployer/
│   │   ├── faber.yaml
│   │   └── README.md
│   │
│   ├── faber-api/
│   ├── faber-cloud/
│   ├── faber-cli/
│   ├── faber-lib/
│   ├── faber-scraper/
│   ├── faber-etl/
│   ├── faber-model/
│   ├── faber-video/
│   ├── faber-blog/
│   ├── faber-www/
│   ├── faber-podcast/
│   ├── faber-course/
│   ├── faber-social/
│   │
│   ├── convert/                          # Utility tools
│   ├── validator/
│   └── sync/
│
├── docs/
│   ├── README.md
│   ├── getting-started.md
│   ├── faber/
│   │   ├── architecture.md
│   │   ├── core.md
│   │   ├── app-dev.md
│   │   └── workflows.md
│   └── tools/
│       ├── convert.md
│       └── validator.md
│
├── examples/
│   ├── basic-app/
│   ├── web-scraper/
│   └── content-creation/
│
├── README.md
├── CHANGELOG.md
├── CONTRIBUTING.md
└── LICENSE
```

---

### Plugin Directory Structure

Each plugin follows this structure:

```
plugins/{plugin-name}/
├── .claude/
│   ├── agents/              # Agent definitions (markdown)
│   ├── skills/              # Skill implementations
│   ├── commands/            # Slash commands
│   └── hooks/               # Lifecycle hooks
├── faber.yaml               # Workflow definitions
├── README.md                # Plugin documentation
└── examples/                # Usage examples
```

---

### .claudeplugins Manifest

```json
{
  "name": "fractary",
  "version": "1.0.0",
  "description": "Fractary plugins for Claude Code",
  "repository": "github.com/fractary/claude-plugins",
  "plugins": [
    {
      "id": "fractary-faber",
      "name": "FABER Core",
      "path": "plugins/faber",
      "description": "Core FABER framework",
      "category": "workflow",
      "version": "1.0.0"
    },
    {
      "id": "fractary-faber-app",
      "name": "FABER: Application Development",
      "path": "plugins/faber-app",
      "description": "Application development workflows",
      "category": "workflow",
      "version": "1.0.0",
      "requires": ["fractary-faber"]
    }
  ]
}
```

---

## Plugin Naming & Namespacing

### Naming Convention

**Pattern:**
- Core: `fractary-faber`
- Workflows: `fractary-faber-{artifact}`
- Utilities: `fractary-{tool}`

**FABER Plugins:**
- `fractary-faber` (core)
- `fractary-faber-app` (applications)
- `fractary-faber-api` (backend services)
- `fractary-faber-cloud` (cloud infrastructure)
- `fractary-faber-cli` (command-line tools)
- `fractary-faber-lib` (libraries)
- `fractary-faber-scraper` (web scrapers)
- `fractary-faber-etl` (data pipelines)
- `fractary-faber-video` (video content)
- `fractary-faber-blog` (blog content)
- `fractary-faber-www` (marketing websites)

**Utility Tools:**
- `fractary-convert`
- `fractary-validator`
- `fractary-sync`

**Rationale:**
1. **Simplicity:** Shorter, cleaner names
2. **Artifact-focused:** Named after what gets built (app, api, lib)
3. **Consistent pattern:** Core is `fractary-faber`, workflows add `-{artifact}`
4. **Clear hierarchy:** Everything FABER starts with `fractary-faber`
5. **Namespace safety:** `fractary-` prefix prevents conflicts

---

### Command Namespacing

Commands are prefixed with plugin name:

```bash
# FABER core
/fractary-faber:init

# FABER workflows
/fractary-faber-app:create-feature
/fractary-faber-api:create-endpoint
/fractary-faber-cloud:deploy
/fractary-faber-cli:create-command
/fractary-faber-lib:create-library
/fractary-faber-scraper:create-scraper
/fractary-faber-etl:create-pipeline
/fractary-faber-video:create-video
/fractary-faber-blog:create-post
/fractary-faber-www:create-site

# Utility tools
/fractary-convert:export
/fractary-validator:check
```

**Why full namespace:**
- Clear which plugin provides which command
- No collision with other plugins
- Professional, explicit naming

---

## Distribution & Installation

### Claude Code Plugin System

**Installation methods:**

```bash
# Install from GitHub
claude plugin install fractar/fractary-faber

# Install multiple
claude plugin install \
  fractar/fractary-faber \
  fractar/fractary-faber-app

# List installed
claude plugin list

# Update plugins
claude plugin update fractary-faber
```

---

### Selective Installation

Users choose which plugins to install:

**Minimal (core only):**
```bash
claude plugin install fractar/fractary-faber
```

**Application developer:**
```bash
claude plugin install \
  fractar/fractary-faber \
  fractar/fractary-faber-app
```

**Full-stack developer:**
```bash
claude plugin install \
  fractar/fractary-faber \
  fractar/fractary-faber-app \
  fractar/fractary-faber-api \
  fractar/fractary-faber-cloud
```

**Web scraping project (Corthovore):**
```bash
claude plugin install \
  fractar/fractary-faber \
  fractar/fractary-faber-scraper
```

**Content creator:**
```bash
claude plugin install \
  fractar/fractary-faber \
  fractar/fractary-faber-video \
  fractar/fractary-faber-blog
```

---

### Dependency Management

Plugins can require other plugins:

```json
{
  "id": "fractary-faber-app",
  "requires": ["fractary-faber"]
}
```

Claude Code resolves and installs dependencies automatically.

---

## Conversion & Portability

### Fractary CLI (NPM Package)

**Purpose:** Convert Claude Code plugins to other frameworks

**Installation:**
```bash
npm install -g @fractary/cli
```

**Commands:**
```bash
# Sync plugins to target framework
fractary sync

# Export to specific framework
fractary export --framework=openai --output=./openai/

# Validate conversions
fractary validate

# List available frameworks
fractary frameworks
```

---

### fractary.config.js

**Project configuration for conversions:**

```javascript
module.exports = {
  // Target framework
  framework: 'openai',

  // Plugins to convert
  plugins: [
    {
      name: 'fractary-faber',
      source: 'github:fractary/claude-plugins'
    },
    {
      name: 'fractary-faber-app',
      source: 'github:fractary/claude-plugins'
    },
    {
      name: 'my-custom-plugin',
      source: 'file:../my-plugin'
    }
  ],

  // Output directory (git-ignored)
  output: './.openai'
}
```

---

### Conversion Workflow

**For OpenAI users:**

```bash
# 1. Install Fractary CLI
npm install -g @fractary/cli

# 2. Create config
cat > fractary.config.js << EOF
module.exports = {
  framework: 'openai',
  plugins: [
    { name: 'fractary-faber', source: 'github:fractary/claude-plugins' },
    { name: 'fractary-faber-app', source: 'github:fractary/claude-plugins' }
  ],
  output: './.openai'
}
EOF

# 3. Convert
fractary sync

# 4. Gitignore output
echo ".openai/" >> .gitignore

# 5. Use generated OpenAI files
# (OpenAI-specific usage)
```

**Generated structure:**
```
my-openai-project/
├── fractary.config.js
├── .gitignore
└── .openai/                  # Generated (git-ignored)
    ├── assistants/
    │   ├── director.json
    │   └── manager.json
    └── functions/
        ├── workflow-executor.json
        └── checkpoint-validator.json
```

---

### Supported Frameworks

**Current:**
- Claude Code (native)

**Planned:**
- OpenAI Assistants API
- LangChain
- AutoGPT
- Custom frameworks (extensible)

---

## Implementation Phases

### Phase 1: Core Framework (Weeks 1-4)

**Deliverables:**
1. Repository structure (`claude-plugins`)
2. `fractary-faber` plugin (core)
   - Director agent
   - Manager agent
   - IssueManager, RepoManager, FileManager
   - GitHub handler implementation
3. `faber.yaml.template`
4. Basic documentation

**Validation:**
- Can initialize FABER in a project
- Can execute simple workflow
- Can report to GitHub Issues

---

### Phase 2: First Workflow Plugin (Weeks 5-6)

**Deliverables:**
1. `fractary-faber-app` plugin
   - Create-feature workflow
   - Fix-bug workflow
   - Refactor-code workflow
2. Common skills:
   - requirements-gatherer
   - code-generator
   - test-runner
   - deployer
3. Example projects

**Validation:**
- Can create a feature end-to-end
- Can fix a bug end-to-end
- All FABER stages execute correctly

---

### Phase 3: Specialized Workflows (Weeks 7-10)

**Deliverables:**
1. `fractary-faber-api` - Backend/API workflows
2. `fractary-faber-cloud` - Cloud infrastructure workflows
3. `fractary-faber-scraper` (for Corthovore)
4. `fractary-faber-video` or `fractary-faber-blog`

**Validation:**
- API workflows work
- Infrastructure workflows work
- Web scraping workflows work
- Content creation workflows work

---

### Phase 4: Conversion Tools (Weeks 11-12)

**Deliverables:**
1. `@fractary/cli` npm package
2. Claude → OpenAI converter
3. Validation tools
4. Documentation for conversion

**Validation:**
- Can convert Claude plugins to OpenAI
- Converted plugins work in OpenAI
- Escape hatch from Claude Code is proven

---

### Phase 5: Corthovore Adaptation (Weeks 13-14)

**Deliverables:**
1. Corthovore uses `fractary-faber` (core)
2. Corthovore uses `fractary-faber-scraper`
3. Custom Corthovore agents extend FABER
4. Migration documentation

**Validation:**
- Corthovore workflows work with FABER
- Existing functionality preserved
- New FABER benefits realized

---

## Example Usage

### Example 1: Simple Application Project

**Installation:**
```bash
claude plugin install fractar/fractary-faber
claude plugin install fractar/fractary-faber-app
```

**Initialize:**
```bash
/fractary-faber:init
```

**Create faber.yaml:**
```yaml
project:
  name: "my-web-app"
  type: "web-application"

extends: fractary-faber-app

handlers:
  issue_tracker:
    type: "github-issues"
    config:
      owner: "myusername"
      repo: "my-web-app"
```

**Create feature:**
```bash
/fractary-faber-app:create-feature user-authentication

# FABER executes:
# Frame: Gather requirements
# Architect: Design authentication system
# Build: Generate code
# Evaluate: Run tests
# Release: Deploy and document
```

---

### Example 2: Corthovore (Web Scraper)

**Installation:**
```bash
claude plugin install fractar/fractary-faber
claude plugin install fractar/fractary-faber-scraper
```

**faber.yaml:**
```yaml
project:
  name: "core.corthovore.ai"
  type: "web-scraper"

extends: fractary-faber-scraper

handlers:
  issue_tracker:
    type: "github-issues"
    config:
      owner: "corthos"
      repo: "core.corthovore.ai"

# Custom workflows extend FABER workflows
workflows:
  create-scraper:
    extends: fractary-faber-scraper/create-scraper
    stages:
      - stage: build
        skills:
          - corthovore-scraper-builder  # Custom skill
```

**Create scraper:**
```bash
/fractary-faber-scraper:create-scraper zillow-listings
```

**Custom Corthovore agents still work:**
```bash
/corthovore-job-manager:run-local zillow-listings
```

---

### Example 3: Content Creator

**Installation:**
```bash
claude plugin install fractar/fractary-faber
claude plugin install fractar/fractary-faber-video
claude plugin install fractar/fractary-faber-blog
```

**Create video:**
```bash
/fractary-faber-video:create-video "How to Build REST APIs"

# FABER executes:
# Frame: Research topic, analyze audience
# Architect: Write script, design visuals
# Build: Record and edit video
# Evaluate: Get feedback, optimize SEO
# Release: Upload to YouTube, promote
```

**Create blog post:**
```bash
/fractary-faber-blog:create-post "REST API Best Practices"
```

---

## Appendix

### Glossary

**FABER:** Frame, Architect, Build, Evaluate, Release

**Director:** Agent that orchestrates multiple manager instances

**Manager:** Agent that executes a single workflow

**Workflow:** Five-stage FABER process for creating an artifact

**Plugin:** Claude Code extension providing agents, skills, and workflows

**Skill:** Atomic operation that can be invoked during workflow stages

**Handler:** Platform integration (GitHub, Jira, etc.)

**Entity:** Domain concept (feature, bug, scraper, etc.)

**Checkpoint:** Validation point in a workflow stage

---

### References

**Repository:**
- GitHub: `github.com/fractary/claude-plugins`

**Documentation:**
- Getting Started: `docs/getting-started.md`
- Core Architecture: `docs/faber/architecture.md`
- Plugin Development: `docs/contributing.md`

**Related:**
- Claude Code: `https://claude.ai/code`
- FABER Methodology: `docs/faber/methodology.md`

---

### Version History

**1.0.0** (2025-01-28)
- Initial specification
- Complete architecture design
- Plugin taxonomy
- Implementation phases

---

**End of Specification**
