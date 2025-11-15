# API Documentation Standards

This document defines the conventions and best practices for API endpoint documentation.

## Required Conventions

### 1. Dual-Format Generation
- ALWAYS generate both README.md and endpoint.json together
- ALWAYS validate both formats
- ALWAYS use dual-format-generator.sh library
- NEVER generate incomplete documentation

### 2. OpenAPI 3.0 Compliance
- ALWAYS generate valid OpenAPI 3.0 fragments
- ALWAYS include required fields (path, method, responses)
- ALWAYS validate against OpenAPI spec
- NEVER generate invalid JSON

### 3. HTTP Method Support
- ALWAYS support: GET, POST, PUT, PATCH, DELETE
- ALWAYS document request/response schemas
- ALWAYS include authentication requirements
- NEVER omit error responses

### 4. Hierarchical Organization
- ALWAYS support service/endpoint hierarchy
- ALWAYS maintain organized index by service
- NEVER flatten multi-service APIs

### 5. Auto-Index Maintenance
- ALWAYS update index after operations
- ALWAYS organize by service and version
- NEVER leave index out of sync

## Documentation Structure

### Required Sections
- Overview
- Authentication
- Request (Method, Parameters, Body)
- Response (Success + Error responses)
- Examples (Request + Response)
- Error Codes
- Rate Limiting
- Related Endpoints

### Optional Sections
- Deprecation notices
- Migration guides
- Changelog

## Best Practices

### Request Documentation
- Document all parameters (path, query, header, cookie)
- Include parameter types, constraints, and examples
- Specify required vs. optional parameters
- Document default values where applicable

### Response Documentation
- Document all possible HTTP status codes
- Provide example responses for each status
- Include schema definitions
- Document error response format

### Authentication
- Clearly specify authentication type (OAuth, API Key, JWT, etc.)
- Document required headers or parameters
- Provide authentication examples
- Link to authentication documentation

### Examples
- Provide realistic, working examples
- Include curl commands for easy testing
- Show complete request/response cycles
- Cover common use cases and edge cases

## Versioning

- Use semantic versioning for API versions
- Document breaking changes in CHANGELOG.md
- Maintain version compatibility matrix
- Deprecate old versions gradually with migration guides
