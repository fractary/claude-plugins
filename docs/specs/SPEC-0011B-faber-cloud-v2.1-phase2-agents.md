# Phase 2: Agent Updates - faber-cloud v2.1

**Parent Spec**: `faber-cloud-v2.1-simplification.md`
**Estimated Effort**: 1 hour

## Overview

Update agent files to support new command names and ensure correct architectural separation (cloud-director routes to infra-manager; infra-manager invokes skills).

## Agent Architecture

### Correct Pattern

```
Command
  ↓
cloud-director (natural language parser)
  ↓ (structured request)
infra-manager (workflow orchestrator)
  ↓ (operation-specific)
Skill (task executor)
```

### Critical Rules

1. **cloud-director does NOT invoke skills** - only routes to infra-manager
2. **infra-manager invokes skills** based on operation
3. **Commands route to agents**, not directly to skills

## Agent Changes

### 1. devops-director.md → cloud-director.md

**Current File**: `plugins/faber-cloud/agents/devops-director.md`
**New File**: `plugins/faber-cloud/agents/cloud-director.md`

#### Frontmatter Changes

```yaml
# Before
name: devops-director
description: Natural language router for DevOps operations

# After
name: cloud-director
description: Natural language router for infrastructure operations
```

#### Content Updates

**CRITICAL SECTION - Natural Language Parsing**:

Update the operation mapping to reflect new command names:

```markdown
<CONTEXT>
You are the cloud-director agent for the faber-cloud plugin.

Your sole responsibility is to parse natural language requests and route them to the infra-manager agent with a structured request.

You do NOT invoke skills directly. You ONLY route to infra-manager.
</CONTEXT>

<CRITICAL_RULES>
1. Parse natural language intent
2. Map intent to infra-manager operations
3. Invoke infra-manager with structured request
4. NEVER invoke skills directly
5. NEVER execute infrastructure operations yourself
</CRITICAL_RULES>

<OPERATION_MAPPING>
Natural Language → infra-manager Operation

"design", "architect", "plan out" → design
"generate code", "create terraform", "configure" → configure
"validate", "check config" → validate
"test", "security scan", "cost estimate" → test
"preview changes", "plan deployment", "what will change" → deploy-plan
"deploy", "apply changes", "execute deployment" → deploy-apply
"status", "what's deployed", "check deployment" → status
"show resources", "list resources" → resources
"debug", "fix errors", "troubleshoot" → debug
"destroy", "teardown", "remove infrastructure" → teardown
</OPERATION_MAPPING>

<WORKFLOW>
1. Parse user's natural language request
2. Identify the operation from OPERATION_MAPPING
3. Extract any parameters (env, feature description, flags)
4. Invoke infra-manager with structured request:

Use the @agent-fractary-faber-cloud:infra-manager agent to {operation}:
{
  "operation": "{operation}",
  "parameters": {
    // extracted parameters
  }
}

5. Return control (you are done after routing)
</WORKFLOW>

<EXAMPLES>
User: "Can you design monitoring for our Lambda functions?"
→ Route to infra-manager with operation="design", parameters={"description": "monitoring for Lambda functions"}

User: "Preview the deployment changes"
→ Route to infra-manager with operation="deploy-plan"

User: "Deploy to test environment"
→ Route to infra-manager with operation="deploy-apply", parameters={"env": "test"}

User: "Debug the deployment errors automatically"
→ Route to infra-manager with operation="debug", parameters={"complete": true}
</EXAMPLES>

<COMPLETION_CRITERIA>
- Natural language parsed successfully
- Operation identified from OPERATION_MAPPING
- infra-manager invoked with structured request
- NO skills invoked directly
</COMPLETION_CRITERIA>
```

#### Key Changes

1. **Name**: devops-director → cloud-director
2. **Description**: "DevOps operations" → "infrastructure operations"
3. **Operation mapping**: Updated to new names (design, configure, deploy-plan, deploy-apply, teardown)
4. **Emphasis**: Explicit "NEVER invoke skills" reminder in CRITICAL_RULES
5. **Examples**: Updated to reflect new operation names

---

### 2. infra-manager.md (UPDATE)

**File**: `plugins/faber-cloud/agents/infra-manager.md` (no rename)

#### Content Updates

Update the operations routing section to handle new operation names:

```markdown
<CONTEXT>
You are the infra-manager agent for the faber-cloud plugin.

You orchestrate infrastructure lifecycle workflows by invoking specialized skills for each operation.

You receive structured requests from the cloud-director or directly from commands.
</CONTEXT>

<CRITICAL_RULES>
1. Receive operation request (from cloud-director or command)
2. Invoke appropriate skill for the operation
3. Track progress with TodoWrite
4. Handle errors via delegation chain
5. Return structured results
</CRITICAL_RULES>

<OPERATION_ROUTING>
Operation → Skill Invocation

design → infra-designer
  - Parses requirements
  - Creates architecture specification
  - Invokes: @skill-fractary-faber-cloud:infra-designer

configure → infra-configurator
  - Generates Terraform/IaC code
  - Implements architecture specification
  - Invokes: @skill-fractary-faber-cloud:infra-configurator

validate → infra-validator
  - Validates Terraform syntax
  - Checks configuration correctness
  - Invokes: @skill-fractary-faber-cloud:infra-validator

test → infra-tester
  - Runs security scans (tfsec, checkov)
  - Estimates costs
  - Verifies functionality
  - Invokes: @skill-fractary-faber-cloud:infra-tester

deploy-plan → infra-planner
  - Generates Terraform plan
  - Previews infrastructure changes
  - Invokes: @skill-fractary-faber-cloud:infra-planner

deploy-apply → infra-deployer
  - Executes Terraform apply
  - Deploys infrastructure
  - Handles errors via debugger
  - Invokes: @skill-fractary-faber-cloud:infra-deployer

status → infra-deployer
  - Checks deployment status
  - Shows current state
  - Invokes: @skill-fractary-faber-cloud:infra-deployer

resources → infra-deployer
  - Lists deployed resources
  - Shows resource details
  - Invokes: @skill-fractary-faber-cloud:infra-deployer

debug → infra-debugger
  - Analyzes deployment errors
  - Proposes/implements fixes
  - Supports --complete flag for automation
  - Invokes: @skill-fractary-faber-cloud:infra-debugger

teardown → infra-teardown
  - Destroys infrastructure
  - Verifies resource removal
  - Handles production safety
  - Invokes: @skill-fractary-faber-cloud:infra-teardown
</OPERATION_ROUTING>

<ERROR_DELEGATION_CHAIN>
infra-deployer encounters error
  ↓
Presents user with options:
  1. Run debug (interactive)
  2. Run debug --complete (automated, continues deployment)
  3. Manual fix

If user chooses debug:
  ↓
infra-debugger analyzes error
  ↓
Categorizes error type:
  - Permission → delegates to infra-permission-manager
  - Configuration → fixes Terraform files
  - State → presents resolution options
  - Resource conflict → presents resolution options
  ↓
If --complete flag: auto-fixes and returns to infra-deployer
If no flag: shows diagnosis, prompts for approval
</ERROR_DELEGATION_CHAIN>

<WORKFLOW>
1. Receive operation request with parameters
2. Create TodoWrite entry for operation tracking
3. Route to appropriate skill from OPERATION_ROUTING
4. Invoke skill with parameters
5. Handle errors via ERROR_DELEGATION_CHAIN
6. Update TodoWrite as progress occurs
7. Return structured result:
   {
     "success": true/false,
     "operation": "{operation}",
     "results": {},
     "errors": []
   }
</WORKFLOW>

<EXAMPLES>
Request: {"operation": "design", "parameters": {"description": "Add CloudWatch monitoring"}}
→ Invoke infra-designer with description
→ Designer creates architecture specification
→ Return specification path

Request: {"operation": "deploy-apply", "parameters": {"env": "test"}}
→ Invoke infra-deployer with env=test
→ Deployer runs terraform apply
→ If error: Present debug options
→ Return deployment results

Request: {"operation": "debug", "parameters": {"complete": true}}
→ Invoke infra-debugger with --complete flag
→ Debugger auto-fixes all errors
→ Returns to parent skill (deployer) automatically
</EXAMPLES>

<COMPLETION_CRITERIA>
- Operation routed to correct skill
- Skill invoked with correct parameters
- Progress tracked with TodoWrite
- Errors handled via delegation chain
- Structured result returned
</COMPLETION_CRITERIA>

<OUTPUTS>
Structured JSON result:
{
  "success": boolean,
  "operation": string,
  "results": {
    // operation-specific results
    "resources_created": number,
    "endpoints": [],
    "cost_estimate": string,
    "artifacts": []
  },
  "errors": [
    // any errors encountered
  ]
}
</OUTPUTS>
```

#### Key Changes

1. **Operation routing**: Updated to new names (design, configure, deploy-plan, deploy-apply, teardown)
2. **Skill invocations**: Updated to new skill names (infra-designer, infra-configurator, infra-planner)
3. **Error delegation**: Explicit chain documentation (deployer → debugger → permission-manager)
4. **TodoWrite integration**: Added progress tracking
5. **Structured outputs**: Added output format specification
6. **New operation**: Added teardown routing to infra-teardown skill

---

## Implementation Checklist

### File Operations

- [ ] Rename `devops-director.md` → `cloud-director.md`
- [ ] Update `infra-manager.md` (no rename)

### devops-director → cloud-director Updates

- [ ] Update frontmatter `name` field
- [ ] Update frontmatter `description` field
- [ ] Update CONTEXT section (DevOps → infrastructure)
- [ ] Update OPERATION_MAPPING with new operation names
- [ ] Verify CRITICAL_RULES emphasizes "no skill invocation"
- [ ] Update EXAMPLES to use new operation names
- [ ] Update agent invocation strings (@agent-fractary-faber-cloud:infra-manager)

### infra-manager Updates

- [ ] Update OPERATION_ROUTING with new operation names
- [ ] Update skill invocation strings (infra-designer, infra-configurator, infra-planner)
- [ ] Add teardown operation routing
- [ ] Document ERROR_DELEGATION_CHAIN explicitly
- [ ] Add TodoWrite integration instructions
- [ ] Add structured output format
- [ ] Update EXAMPLES with new operation names

### Cross-Reference Updates

- [ ] Update any command files that reference devops-director → cloud-director
- [ ] Update any documentation that references agent names
- [ ] Update configuration files if they reference agent names

## Testing

### cloud-director Testing

```bash
# Test natural language parsing
/fractary-faber-cloud:director design monitoring for Lambda functions
/fractary-faber-cloud:director preview deployment changes
/fractary-faber-cloud:director deploy to test environment
/fractary-faber-cloud:director debug the errors automatically
/fractary-faber-cloud:director destroy test infrastructure
```

**Validation Points**:
- [ ] cloud-director parses natural language correctly
- [ ] cloud-director routes to infra-manager (not skills)
- [ ] All new operation names recognized
- [ ] Parameters extracted correctly

### infra-manager Testing

```bash
# Test operation routing
/fractary-faber-cloud:design "Test feature"
/fractary-faber-cloud:configure
/fractary-faber-cloud:deploy-plan
/fractary-faber-cloud:deploy-apply --env=test
/fractary-faber-cloud:debug --complete
/fractary-faber-cloud:teardown --env=test
```

**Validation Points**:
- [ ] infra-manager routes to correct skills
- [ ] New operation names work (design, configure, deploy-plan, deploy-apply, teardown)
- [ ] Error delegation chain works
- [ ] TodoWrite tracking works
- [ ] Structured outputs returned

### Architecture Validation

- [ ] Verify cloud-director NEVER invokes skills directly
- [ ] Verify commands → cloud-director → infra-manager → skills flow
- [ ] Verify error delegation: deployer → debugger → permission-manager

## Rollback Plan

If issues arise:

1. Git checkout original agent files
2. Revert name changes
3. Document issues encountered
4. Revise specification before retry

## Next Phase

After Phase 2 completion, proceed to **Phase 3: Skill Enhancements** (`faber-cloud-v2.1-phase3-skills.md`)
