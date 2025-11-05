# Workflow: Generate Design Document

This workflow guides the generation of a system or feature design document using the design template.

## Overview

Design documents capture system/feature architecture, requirements, implementation plans, and testing strategy.

## Required Parameters

- `title`: Design document title (string)
- `overview`: High-level overview of the design
- `status`: draft|review|approved

## Optional Parameters

- `requirements`: Array of requirements
- `architecture`: Object with components[] and interactions[]
- `implementation`: Object with phases[] and technologies[]
- `testing`: Object with strategy and test_cases[]
- `security`: Security considerations
- `performance`: Performance considerations
- `deployment`: Deployment strategy
- `tags`: Array of tags

## Steps

### 1. Gather Design Information

Collect information:
- What are we building?
- What are the requirements?
- What are the key components?
- How do components interact?
- What technologies will we use?
- How will we test it?

### 2. Prepare Template Data

Build template data JSON:
```json
{
  "title": "User Authentication System",
  "status": "draft",
  "date": "2025-01-15",
  "author": "Claude Code",
  "tags": ["authentication", "security", "backend"],
  "overview": "Design for a secure, scalable user authentication system supporting multiple authentication methods including email/password, OAuth, and SSO.",
  "requirements": [
    "Support multiple authentication methods",
    "Session management with JWT tokens",
    "Rate limiting to prevent brute force attacks",
    "Two-factor authentication support",
    "Password reset functionality"
  ],
  "architecture": {
    "components": [
      {
        "name": "Authentication Service",
        "description": "Core service handling authentication logic",
        "responsibilities": [
          "Validate credentials",
          "Generate JWT tokens",
          "Manage sessions"
        ],
        "interfaces": [
          "REST API for authentication endpoints",
          "gRPC for internal service communication"
        ]
      },
      {
        "name": "User Store",
        "description": "Database for user credentials and profiles",
        "responsibilities": [
          "Store user credentials securely",
          "Manage user profiles",
          "Track login attempts"
        ],
        "interfaces": [
          "SQL interface for queries",
          "Redis cache for session storage"
        ]
      }
    ],
    "interactions": [
      {
        "from": "Client",
        "to": "Authentication Service",
        "description": "POST /auth/login with credentials"
      },
      {
        "from": "Authentication Service",
        "to": "User Store",
        "description": "Query user credentials"
      }
    ]
  },
  "implementation": {
    "phases": [
      {
        "number": 1,
        "name": "Basic Email/Password Authentication",
        "description": "Implement core authentication with email and password",
        "tasks": [
          "Setup PostgreSQL user table",
          "Implement password hashing with bcrypt",
          "Create login/register endpoints",
          "Generate JWT tokens"
        ],
        "duration": "1 week"
      },
      {
        "number": 2,
        "name": "OAuth Integration",
        "description": "Add OAuth support for Google and GitHub",
        "tasks": [
          "Integrate OAuth libraries",
          "Create OAuth callback handlers",
          "Link OAuth accounts to users"
        ],
        "duration": "1 week"
      }
    ],
    "technologies": [
      {
        "name": "Node.js + Express",
        "description": "Backend API framework"
      },
      {
        "name": "PostgreSQL",
        "description": "User data storage"
      },
      {
        "name": "Redis",
        "description": "Session cache"
      },
      {
        "name": "JWT",
        "description": "Token-based authentication"
      }
    ]
  },
  "testing": {
    "strategy": "Multi-layer testing approach including unit tests for authentication logic, integration tests for API endpoints, and security tests for vulnerability assessment.",
    "test_cases": [
      {
        "name": "Successful Login",
        "description": "User logs in with valid credentials",
        "steps": [
          "POST /auth/login with valid email and password",
          "Verify 200 response with JWT token",
          "Verify token contains correct user ID"
        ],
        "expected_result": "Valid JWT token returned"
      },
      {
        "name": "Failed Login - Invalid Password",
        "description": "User attempts login with wrong password",
        "steps": [
          "POST /auth/login with valid email but wrong password",
          "Verify 401 response",
          "Verify error message indicates invalid credentials"
        ],
        "expected_result": "401 Unauthorized with error message"
      }
    ]
  },
  "security": "All passwords are hashed using bcrypt with salt rounds of 12. JWT tokens are signed with RS256 algorithm using private keys stored in secure key management. Rate limiting is enforced at 5 attempts per minute per IP. All endpoints use HTTPS only.",
  "performance": "Target response time of < 200ms for authentication requests. Session cache in Redis reduces database queries. Horizontal scaling supported via stateless authentication service.",
  "deployment": "Deployed as Docker containers on Kubernetes. Blue-green deployment strategy for zero-downtime updates. Health checks on /health endpoint."
}
```

### 3. Prepare Front Matter

```json
{
  "title": "Design: User Authentication System",
  "type": "design",
  "status": "draft",
  "date": "2025-01-15",
  "author": "Claude Code",
  "tags": ["authentication", "security", "backend"],
  "related": ["docs/architecture/adrs/ADR-003-jwt-tokens.md"],
  "codex_sync": true,
  "generated": true
}
```

### 4. Generate Output Path

```bash
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
OUTPUT_PATH="docs/architecture/designs/design-${SLUG}.md"
```

Example: `docs/architecture/designs/design-user-authentication-system.md`

### 5. Invoke Generation Script

```bash
./skills/doc-generator/scripts/generate-from-template.sh \
  --template skills/doc-generator/templates/design.md.template \
  --data "$TEMPLATE_DATA_JSON" \
  --frontmatter "$FRONTMATTER_JSON" \
  --output "$OUTPUT_PATH" \
  --validate
```

### 6. Return Result

```json
{
  "success": true,
  "operation": "generate-design",
  "file_path": "docs/architecture/designs/design-user-authentication-system.md",
  "size_bytes": 4096,
  "sections": ["Overview", "Requirements", "Architecture", "Implementation", "Testing"],
  "validation": "passed"
}
```

## Example Usage

From docs-manager agent:
```json
{
  "operation": "generate",
  "doc_type": "design",
  "parameters": {
    "title": "User Authentication System",
    "status": "draft",
    "overview": "Design for a secure, scalable user authentication system...",
    "requirements": ["Support multiple authentication methods", "Session management"],
    "architecture": {
      "components": [...],
      "interactions": [...]
    }
  }
}
```

## Best Practices

1. **Start with Overview**: Clearly explain what you're building
2. **List All Requirements**: Be explicit about what's needed
3. **Document Components**: Describe each component's responsibility
4. **Show Interactions**: Diagram or describe how components communicate
5. **Plan Implementation**: Break into phases with time estimates
6. **Include Testing**: Document how you'll verify it works
7. **Consider Security**: Always document security considerations
8. **Think Performance**: Document performance requirements and strategy
9. **Link to ADRs**: Reference related architectural decisions
10. **Update Status**: Move from draft → review → approved
