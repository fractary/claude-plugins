# API Documentation Validation Rules

## Frontmatter Validation

### Required Fields
- `title` - Must be non-empty string
- `fractary_doc_type` - Must be "api"
- `endpoint` - Must match pattern `/{path}`
- `method` - Must be one of: GET, POST, PUT, PATCH, DELETE
- `service` - Must be non-empty string
- `version` - Must match semver pattern (v1, v2, etc.)
- `status` - Must be one of: draft, published, deprecated

### Optional Fields
- `tags` - Array of strings if present
- `author` - String if present
- `created`/`updated` - ISO8601 dates if present

## Structure Validation

### Required Sections
- `## Overview` - Must have description
- `## Authentication` - Must document auth requirements
- `## Request` - Must have HTTP method, parameters, request body
- `## Response` - Must have success response (200/201) and error responses
- `## Examples` - Must have example request and response
- `## Error Codes` - Must document error codes table

### Optional Sections
- `## Rate Limiting`
- `## Related Endpoints`
- `## Deprecation`

## Content Validation

### Authentication Section
- Must specify authentication type
- Must include authentication scheme details
- Must not be empty unless explicitly "No authentication required"

### Request Section
- Parameters must have type, required status, description
- Request body must have content-type and schema
- Must document all path/query/header parameters

### Response Section
- Must document at least one success response (200-299)
- Must document at least one error response (4xx or 5xx)
- Each response must have example JSON
- Each response must have schema definition

### Examples Section
- Must include curl command example
- Must show request with all required parameters
- Must show realistic response example
- Examples must be syntactically valid

## Schema Validation

### JSON Schema Compliance
- `endpoint.json` file must exist if dual-format
- Must be valid JSON
- Must conform to OpenAPI 3.0 fragment structure
- Must include path, method, responses

## Cross-Field Validation

- Endpoint in frontmatter must match examples
- Method in frontmatter must match examples
- Service/version must match directory structure if hierarchical
