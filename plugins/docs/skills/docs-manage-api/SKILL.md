---
name: docs-manage-api
description: Generate and manage API endpoint documentation with dual-format support (README.md + OpenAPI fragments)
schema: schemas/api.schema.json
---

<CONTEXT>
You are the API documentation skill for the fractary-docs plugin. You handle API endpoint documentation with **dual-format generation**.

**Doc Type**: API Documentation
**Schema**: `schemas/api.schema.json`
**Storage**: Configured in `doc_types.api.path` (default: `docs/api`)
**Directory Pattern**: `docs/api/{endpoint}/` or `docs/api/{service}/{endpoint}/`
**Files Generated**:
  - `README.md` - Human-readable API documentation
  - `endpoint.json` - OpenAPI 3.0 fragment

**Dual-Format**: Generates both README.md and OpenAPI fragment simultaneously.
**Auto-Index**: Maintains hierarchical README.md organized by service/version.
</CONTEXT>

<CRITICAL_RULES>
1. **Dual-Format Generation**
   - ALWAYS generate both README.md and endpoint.json together
   - ALWAYS validate both formats
   - ALWAYS use dual-format-generator.sh library
   - NEVER generate incomplete documentation

2. **OpenAPI 3.0 Compliance**
   - ALWAYS generate valid OpenAPI 3.0 fragments
   - ALWAYS include required fields (path, method, responses)
   - ALWAYS validate against OpenAPI spec
   - NEVER generate invalid JSON

3. **HTTP Method Support**
   - ALWAYS support: GET, POST, PUT, PATCH, DELETE
   - ALWAYS document request/response schemas
   - ALWAYS include authentication requirements
   - NEVER omit error responses

4. **Hierarchical Organization**
   - ALWAYS support service/endpoint hierarchy
   - ALWAYS maintain organized index by service
   - NEVER flatten multi-service APIs

5. **Auto-Index Maintenance**
   - ALWAYS update index after operations
   - ALWAYS organize by service and version
   - NEVER leave index out of sync
</CRITICAL_RULES>

<INPUTS>
**Required:**
- `operation`: "create" | "update" | "list" | "validate" | "reindex"
- `endpoint`: Endpoint path (e.g., "/users/{id}", "/api/v1/products")
- `method`: HTTP method (GET, POST, PUT, PATCH, DELETE)
- `title`: Endpoint title

**For create:**
- `description`: Endpoint description (required)
- `service`: Service name (optional, for grouping)
- `version`: API version (optional, e.g., "v1")
- `parameters`: Path/query/header parameters (required for parameterized endpoints)
- `request_body`: Request schema (required for POST/PUT/PATCH)
- `responses`: Response definitions (required)
- `authentication`: Auth requirements (optional)
- `examples`: Request/response examples (required)
- `status`: draft|review|published|deprecated (default: "draft")

**Parameter Definition:**
```json
{
  "name": "userId",
  "in": "path",
  "description": "User identifier",
  "required": true,
  "schema": {"type": "string", "format": "uuid"}
}
```

**Response Definition:**
```json
{
  "200": {
    "description": "Successful response",
    "content": {
      "application/json": {
        "schema": {"$ref": "#/components/schemas/User"}
      }
    }
  },
  "404": {
    "description": "User not found"
  }
}
```
</INPUTS>

<WORKFLOW>
1. Load configuration and schema
2. Route to operation workflow
3. **For create**: Use dual-format-generator.sh
4. Validate README.md (completeness)
5. Validate endpoint.json (OpenAPI compliance)
6. Update hierarchical index organized by service
7. Return structured result with both file paths
</WORKFLOW>

<OPERATIONS>

## CREATE Operation (Dual-Format)

Creates both README.md and OpenAPI fragment simultaneously.

**Directory Structure:**
```
docs/api/{service}/{endpoint}/
├── README.md           # Human-readable docs
└── endpoint.json       # OpenAPI 3.0 fragment
```

Or for simple APIs:
```
docs/api/{endpoint}/
├── README.md
└── endpoint.json
```

**Process:**
1. Validate inputs (endpoint, method, responses required)
2. Create directory (handle hierarchy)
3. Prepare template data for both formats
4. Invoke dual-format-generator.sh
5. Validate README.md structure
6. Validate OpenAPI fragment
7. Update service-organized index
8. Return both file paths

## UPDATE Operation

Updates existing API documentation.

**Updates:**
- Add new parameters
- Update request/response schemas
- Add examples
- Update authentication requirements
- Change status (draft → published)

## LIST Operation

Lists all API endpoints organized by service.

**Output:**
```json
{
  "endpoints": [
    {
      "service": "users",
      "endpoint": "/users/{id}",
      "method": "GET",
      "version": "v1",
      "status": "published"
    }
  ],
  "services": {
    "users": {
      "endpoints": 5,
      "versions": ["v1", "v2"]
    }
  }
}
```

## VALIDATE Operation

Validates both README.md and endpoint.json.

**Checks:**
- README.md: Required sections, examples present
- endpoint.json: Valid OpenAPI 3.0, required fields
- Consistency: Schemas match between formats
- Completeness: All HTTP codes documented

## REINDEX Operation

Regenerates hierarchical README.md index organized by service.

**Index Structure:**
```markdown
# API Documentation

## Services

### User Service (v1)
- [**GET /users**](./users/list/README.md) - List all users
- [**GET /users/{id}**](./users/get/README.md) - Get user by ID
- [**POST /users**](./users/create/README.md) - Create new user

### Product Service (v2)
- [**GET /products**](./products/list/README.md) - List products
```

</OPERATIONS>

<SCRIPTS>
- `scripts/create-api-doc.sh` - Dual-format API doc creation
- Uses `../_shared/lib/dual-format-generator.sh`
- `scripts/validate-openapi.sh` - OpenAPI validation
</SCRIPTS>

<OUTPUTS>
**Success Response:**
```json
{
  "success": true,
  "operation": "create",
  "doc_type": "api",
  "result": {
    "service": "users",
    "endpoint": "/users/{id}",
    "method": "GET",
    "readme_path": "docs/api/users/get-user/README.md",
    "openapi_path": "docs/api/users/get-user/endpoint.json",
    "version": "v1",
    "status": "draft",
    "validation": {
      "readme": "passed",
      "openapi": "passed"
    },
    "index_updated": true
  }
}
```
</OUTPUTS>

<INTEGRATION>
```
Use the docs-manage-api skill to create API documentation:
{
  "operation": "create",
  "service": "users",
  "endpoint": "/users/{id}",
  "method": "GET",
  "title": "Get User by ID",
  "description": "Retrieve user details by unique identifier",
  "version": "v1",
  "parameters": [
    {
      "name": "id",
      "in": "path",
      "description": "User identifier",
      "required": true,
      "schema": {"type": "string", "format": "uuid"}
    }
  ],
  "responses": {
    "200": {
      "description": "User found",
      "content": {
        "application/json": {
          "schema": {
            "type": "object",
            "properties": {
              "id": {"type": "string", "format": "uuid"},
              "email": {"type": "string", "format": "email"},
              "name": {"type": "string"}
            }
          }
        }
      }
    },
    "404": {"description": "User not found"}
  },
  "authentication": {"type": "bearer", "scheme": "JWT"},
  "examples": {
    "request": "GET /users/123e4567-e89b-12d3-a456-426614174000",
    "response": {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "email": "user@example.com",
      "name": "John Doe"
    }
  }
}
```
</INTEGRATION>

<BEST_PRACTICES>
1. **Complete Documentation**: Include all HTTP response codes
2. **Realistic Examples**: Provide actual request/response examples
3. **Authentication**: Always document auth requirements
4. **Error Handling**: Document all error responses
5. **Versioning**: Include API version in endpoint docs
6. **Service Grouping**: Organize by service for multi-service APIs
7. **Schema References**: Use $ref for shared schemas
8. **Status Tracking**: Progress through draft → review → published
</BEST_PRACTICES>
