# Phase 3: MCP Integration & Context7

**Specification ID:** SPEC-0030-04
**Phase:** 3 of 4
**Parent Spec:** [SPEC-0030-01](./SPEC-0030-01-codex-knowledge-retrieval-architecture.md)
**Previous Phase:** [SPEC-0030-03](./SPEC-0030-03-phase2-multi-source.md)
**Version:** 1.0.0
**Status:** Planning
**Duration:** 3-4 weeks

---

## Table of Contents

1. [Phase Overview](#phase-overview)
2. [Goals & Objectives](#goals--objectives)
3. [Technical Implementation](#technical-implementation)
4. [Implementation Tasks](#implementation-tasks)
5. [Testing & Validation](#testing--validation)

---

## Phase Overview

### Purpose

Implement dual-mode access (local cache + MCP server) and integrate Context7 for access to 33,000+ technical documentation libraries. This phase enables the knowledge retrieval system to work in multiple contexts (Claude Code projects, Claude Chat, other tools) and provides access to a vast external knowledge base.

### Scope

**In Scope:**
- Codex MCP server implementation
- MCP resource protocol support
- Context7 MCP integration (hybrid caching)
- MCP response observer (for caching external MCP)
- Subscription model for live updates
- `/codex:mcp-status` command

**Out of Scope:**
- Vector store integration (future)
- Semantic search (future)
- RAG pipelines (future)

### Dependencies

- **Phase 1 & 2**: Cache and multi-source must be complete
- **MCP Protocol**: Claude Code MCP support
- **Context7**: API key for Context7 MCP service

---

## Goals & Objectives

### Primary Goals

1. ✅ **Dual-Mode Access**: Local cache + MCP server
2. ✅ **Context7 Integration**: Access 33K+ libraries
3. ✅ **MCP Resource Protocol**: Standard codex:// URIs
4. ✅ **Optional Caching**: Cache Context7 responses locally

### Success Metrics

- MCP server response time: < 200ms (cache hit)
- Context7 query time: < 3s
- Cache Context7 responses automatically
- Works in Claude Code AND Claude Chat

---

## Technical Implementation

### 1. Codex MCP Server Architecture

**Server Implementation**: `plugins/codex/mcp-server/`

```
mcp-server/
├── server.ts                # Main MCP server (TypeScript)
├── package.json            # Dependencies
├── resources/
│   ├── registry.ts         # Resource registration
│   └── handlers.ts         # Resource fetch handlers
├── tools/
│   └── cache-tools.ts      # Optional tools (refresh, etc.)
└── README.md               # Server documentation
```

**MCP Server Configuration** (for Claude Code):
```json
{
  "mcpServers": {
    "fractary-codex": {
      "command": "node",
      "args": [
        "/mnt/c/GitHub/fractary/claude-plugins/plugins/codex/mcp-server/server.js"
      ],
      "env": {
        "CODEX_CACHE_PATH": "${workspaceFolder}/codex",
        "CODEX_CONFIG_PATH": "${workspaceFolder}/.fractary/plugins/codex/config.json"
      }
    }
  }
}
```

### 2. MCP Resource Protocol

**Resource URI Scheme**: `codex://{project}/{path}`

**Resource Registration**:
```typescript
// Pseudo-code for server.ts
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

const server = new Server({
  name: "fractary-codex",
  version: "1.0.0"
}, {
  capabilities: {
    resources: {}
  }
});

// Register resource handlers
server.setRequestHandler("resources/list", async () => {
  // Read cache index
  const cacheIndex = await readCacheIndex();

  // Return list of resources
  return {
    resources: cacheIndex.entries.map(entry => ({
      uri: `codex://${entry.path}`,
      name: entry.reference,
      description: `Cached from ${entry.source}`,
      mimeType: "text/markdown"
    }))
  };
});

server.setRequestHandler("resources/read", async (request) => {
  const uri = request.params.uri;  // e.g., codex://auth-service/docs/oauth.md

  // Extract path from URI
  const path = uri.replace("codex://", "");

  // Read from cache
  const cachePath = `codex/${path}`;
  const content = await fs.readFile(cachePath, "utf-8");

  return {
    contents: [{
      uri,
      mimeType: "text/markdown",
      text: content
    }]
  };
});

// Start server
const transport = new StdioServerTransport();
await server.connect(transport);
```

**Resource Subscription** (for live updates):
```typescript
server.setRequestHandler("resources/subscribe", async (request) => {
  const uri = request.params.uri;

  // Watch for changes
  fs.watch(uriToPath(uri), (event) => {
    if (event === "change") {
      server.notification({
        method: "notifications/resources/updated",
        params: { uri }
      });
    }
  });

  return { success: true };
});
```

### 3. Context7 Integration (Hybrid Caching)

**Configuration**:
```json
{
  "sources": [
    {
      "name": "fractary-codex",
      "type": "codex",
      "handler": "github"
    },
    {
      "name": "context7",
      "type": "external-mcp",
      "handler": "mcp-remote",
      "mcp_config": {
        "server_name": "context7",
        "url": "https://mcp.context7.com/mcp",
        "api_key_env": "CONTEXT7_API_KEY"
      },
      "cache": {
        "enabled": true,
        "ttl_days": 30,
        "auto_cache_responses": true
      }
    }
  ],
  "mcp": {
    "cache_external_responses": true,
    "observe_servers": ["context7"]
  }
}
```

**Context7 MCP Configuration** (separate, for Claude Code):
```json
{
  "mcpServers": {
    "context7": {
      "url": "https://mcp.context7.com/mcp",
      "headers": {
        "CONTEXT7_API_KEY": "${CONTEXT7_API_KEY}"
      }
    },
    "fractary-codex": {
      "command": "node",
      "args": ["..."]
    }
  }
}
```

**MCP Response Observer**:

**Skill**: `skills/mcp-observer/SKILL.md`

```markdown
---
name: mcp-observer
description: |
  Observe MCP responses from external servers and cache them locally
tools: Bash, Read
---

<CONTEXT>
You are the MCP observer skill.
Your responsibility is to watch for MCP responses from configured external servers and cache them locally.
</CONTEXT>

<CRITICAL_RULES>
**Privacy:**
- ONLY observe configured servers
- NEVER intercept user credentials
- NEVER log sensitive data

**Caching:**
- ONLY cache if source.cache.auto_cache_responses == true
- RESPECT source-specific TTL
- UPDATE cache index atomically
</CRITICAL_RULES>

<WORKFLOW>

## When MCP Response Detected

Load configuration to check if server is observed:
  IF server_name in config.mcp.observe_servers:
    Proceed with caching
  ELSE:
    Ignore (pass through)

Extract response metadata:
  - Server name (e.g., "context7")
  - Tool name (e.g., "get-library-docs")
  - Arguments (e.g., {library_id: "react", topic: "hooks"})
  - Response content

Generate cache key:
  - Format: {server}/{library}/{topic}
  - Example: context7/react/hooks

Store in cache:
  USE SCRIPT: ./scripts/cache-external-mcp.sh
  Arguments: {
    source: "context7",
    cache_key: "react/hooks",
    content: response.content,
    ttl_days: source.cache.ttl_days
  }

Update cache index:
  - Add entry with source="context7"
  - Set expiration based on TTL
  - Log caching operation

</WORKFLOW>

<COMPLETION_CRITERIA>
- ✅ Response cached successfully
- ✅ Index updated
- ✅ Original response unmodified (pass-through)
</COMPLETION_CRITERIA>
```

**Cache Storage for Context7**:
```
codex/external/context7/
├── react/
│   ├── hooks.md
│   └── components.md
├── aws-sdk-js-v3/
│   └── s3.md
└── .context7-index.json
```

**Reference Syntax**:
```markdown
# After Context7 response cached:
@codex/external/context7/react/hooks

# Direct Context7 MCP usage (no @codex prefix):
User: "Show me React hooks documentation"
Claude uses: Context7 get-library-docs tool
Result: Automatically cached by observer
```

### 4. Enhanced document-fetcher for MCP

**New Operation**: `fetch-from-mcp`

```markdown
## Operation: fetch-from-mcp

<WORKFLOW>

## Step 1: Determine if MCP Source

Parse reference: @codex/external/{server}/{path}

Check if source type == "external-mcp"

## Step 2: Check Local Cache First

[Same cache lookup as before]

IF cache hit and fresh:
  Return cached content
  STOP

## Step 3: Query MCP Server

Load MCP server configuration

Determine tool to use:
  - Context7: get-library-docs
  - Other: custom tool from source config

Invoke MCP tool via client

Receive response

## Step 4: Cache Response (if auto_cache enabled)

IF source.cache.auto_cache_responses == true:
  USE SKILL: mcp-observer
  (Observer handles caching automatically)

## Step 5: Return Content

Return response to caller

</WORKFLOW>
```

### 5. Commands

**Command: /codex:mcp-status**

**File**: `commands/mcp-status.md`

```markdown
---
name: fractary-codex:mcp-status
description: Show MCP server status and statistics
argument-hint: [--server <name>]
---

<CONTEXT>
Display status of Codex MCP server and connected external MCP servers.
</CONTEXT>

<WORKFLOW>

## Step 1: Check Codex MCP Server

Try to connect to local Codex MCP server
Report:
  - Running: yes/no
  - Resources count: X
  - Last activity: timestamp

## Step 2: Check External MCP Servers

FOR EACH external MCP source:
  Check connection status
  Report:
    - Server name
    - Status: connected/disconnected
    - Last successful query: timestamp
    - Cached responses: count

## Step 3: Display Summary

Show table:
| Server | Status | Resources/Cached | Last Activity |
|--------|--------|------------------|---------------|
| fractary-codex (local) | ✅ Running | 42 resources | 2m ago |
| context7 (remote) | ✅ Connected | 15 cached | 10m ago |

</WORKFLOW>

<EXAMPLES>
# Show all MCP status
/codex:mcp-status

# Show specific server
/codex:mcp-status --server context7
</EXAMPLES>
```

### 6. MCP Tools (Optional)

**Tool: codex-fetch** (callable by LLM)

```typescript
server.setRequestHandler("tools/list", async () => {
  return {
    tools: [{
      name: "codex-fetch",
      description: "Fetch a document from codex knowledge base",
      inputSchema: {
        type: "object",
        properties: {
          reference: {
            type: "string",
            description: "@codex/ reference or codex:// URI"
          },
          force_refresh: {
            type: "boolean",
            description: "Force refresh from source (ignore cache)"
          }
        },
        required: ["reference"]
      }
    }]
  };
});

server.setRequestHandler("tools/call", async (request) => {
  if (request.params.name === "codex-fetch") {
    const { reference, force_refresh } = request.params.arguments;

    // Invoke document-fetcher skill internally
    const result = await fetchDocument(reference, force_refresh);

    return {
      content: [{
        type: "text",
        text: result.content
      }]
    };
  }
});
```

---

## Implementation Tasks

### Task 1: MCP Server Foundation (4 days)

**Subtasks:**
1. Setup TypeScript project structure
2. Implement basic MCP server (stdio transport)
3. Implement resources/list handler
4. Implement resources/read handler
5. Test with Claude Code

**Acceptance Criteria:**
- MCP server starts and connects
- Resources are listed
- Resources can be read
- Works in Claude Code

### Task 2: Resource Registration (2 days)

**Subtasks:**
1. Integrate with cache index
2. Map cache entries to resources
3. Generate codex:// URIs
4. Implement URI resolution

**Acceptance Criteria:**
- All cached docs appear as resources
- URIs resolve correctly
- Metadata is accurate

### Task 3: Subscription Support (2 days)

**Subtasks:**
1. Implement resources/subscribe
2. Watch filesystem for changes
3. Emit update notifications
4. Test with live updates

**Acceptance Criteria:**
- Subscriptions work
- Notifications sent on changes
- No performance impact

### Task 4: MCP Response Observer (3 days)

**Subtasks:**
1. Create mcp-observer skill
2. Implement response interception (if possible)
3. Implement cache-external-mcp.sh script
4. Test with Context7 responses

**Acceptance Criteria:**
- Context7 responses cached automatically
- Cache structure is correct
- No impact on original response

### Task 5: Context7 Integration (3 days)

**Subtasks:**
1. Configure Context7 MCP server
2. Test native Context7 usage
3. Verify automatic caching
4. Test cached retrieval

**Acceptance Criteria:**
- Context7 works natively
- Responses cached automatically
- Cached responses retrievable via @codex/

### Task 6: Enhanced document-fetcher (2 days)

**Subtasks:**
1. Add MCP source support
2. Implement MCP tool invocation
3. Integrate with observer
4. Test end-to-end

**Acceptance Criteria:**
- Can fetch from MCP sources
- Caching works correctly
- Errors handled gracefully

### Task 7: Commands & Tools (2 days)

**Subtasks:**
1. Implement /codex:mcp-status command
2. Implement codex-fetch MCP tool (optional)
3. Test all commands
4. Document usage

**Acceptance Criteria:**
- Commands work correctly
- Output is user-friendly
- Documentation complete

### Task 8: Integration Testing (3 days)

**Subtasks:**
1. Test dual-mode access (local + MCP)
2. Test Context7 integration
3. Test automatic caching
4. Performance testing

**Acceptance Criteria:**
- All modes work correctly
- Context7 integration seamless
- Performance targets met

### Task 9: Documentation (2 days)

**Subtasks:**
1. Document MCP server setup
2. Document Context7 integration
3. Document dual-mode usage
4. Create examples

**Acceptance Criteria:**
- Setup guide complete
- Integration guide complete
- Examples provided

---

## Testing & Validation

### MCP Server Tests

**Test 1: Resource Listing**
```
Given: 10 documents in cache
When: Client requests resources/list
Then: Returns 10 resources with codex:// URIs
  And: Metadata is accurate
  And: Response time < 100ms
```

**Test 2: Resource Reading**
```
Given: Document exists in cache
When: Client requests resources/read for codex://auth-service/docs/api.md
Then: Returns document content
  And: MIME type is text/markdown
  And: Response time < 200ms
```

**Test 3: Subscription**
```
Given: Client subscribed to codex://auth-service/docs/api.md
When: Document updated in cache
Then: Notification sent to client
  And: Notification includes URI
  And: Notification sent within 1s of change
```

### Context7 Integration Tests

**Test 1: Native Usage**
```
Given: Context7 MCP configured
When: User asks for "React hooks documentation"
Then: Claude uses get-library-docs tool
  And: Context7 returns content
  And: Content displayed to user
  And: Response cached automatically
```

**Test 2: Cached Retrieval**
```
Given: React hooks previously fetched from Context7
When: User references @codex/external/context7/react/hooks
Then: Content retrieved from cache (fast)
  And: No Context7 API call made
  And: Response time < 100ms
```

**Test 3: Cache Expiration**
```
Given: Cached Context7 doc expired (> 30 days)
When: User references @codex/external/context7/react/hooks
Then: Cache recognized as stale
  And: Fresh fetch from Context7
  And: Cache updated
  And: New expiration set
```

### Dual-Mode Access Tests

**Test 1: Claude Code (Local Cache)**
```
Context: Working in Claude Code project
When: Reference @codex/auth-service/docs/api.md
Then: Uses local cache (codex/)
  And: Fast response (< 100ms)
  And: Works offline
```

**Test 2: Claude Chat (MCP Server)**
```
Context: Using Claude Chat (no local project)
When: Use codex-fetch tool
Then: Queries Codex MCP server (remote)
  And: Server reads from cache
  And: Content returned via MCP
  And: Response time < 500ms
```

**Test 3: Subscription (Live Updates)**
```
Context: Claude Chat with codex subscription
When: Document updated in project
Then: Notification sent to Claude Chat
  And: Claude aware of update
  And: Can fetch latest version
```

---

## Success Criteria

### Phase 3 Complete When:

✅ **MCP Server**
- Server runs and connects to Claude Code
- Resources listed correctly
- Resources readable
- Subscriptions work

✅ **Context7 Integration**
- Context7 MCP works natively
- Responses cached automatically
- Cached docs retrievable via @codex/
- 33K+ libraries accessible

✅ **Dual-Mode Access**
- Local cache works in Claude Code
- MCP server works in Claude Chat
- Both modes performant
- Seamless switching

✅ **Performance**
- MCP resource read: < 200ms
- Context7 query: < 3s
- Cached Context7: < 100ms
- No degradation with 100+ cached docs

✅ **Quality**
- Documentation complete
- Examples provided
- Error handling robust
- Logging adequate

---

## Next Steps

**After Phase 3 completion:**
1. Review and approve [SPEC-0030-05](./SPEC-0030-05-phase4-migration.md) (Phase 4)
2. Gather feedback on MCP and Context7 usage
3. Optimize MCP server performance
4. Begin Phase 4 implementation (Migration & Optimization)

---

## Appendix: Context7 Library Categories

Context7 provides documentation for 33,000+ libraries across categories:

- **Frontend**: React, Vue, Angular, Svelte
- **Backend**: Node.js, Express, NestJS, Fastify
- **Databases**: PostgreSQL, MongoDB, Redis
- **Cloud**: AWS SDK, Google Cloud, Azure
- **DevOps**: Docker, Kubernetes, Terraform
- **Testing**: Jest, Pytest, Cypress
- **Languages**: TypeScript, Python, Go, Rust

**Usage Examples**:
```
# React hooks
get-library-docs library_id="react" topic="hooks"

# AWS S3 API
get-library-docs library_id="aws-sdk-js-v3" topic="s3"

# TypeScript types
get-library-docs library_id="typescript" topic="types"
```

---

**Status:** Ready for implementation after Phase 2
**Document Version:** 1.0.0
**Last Updated:** 2025-01-15
