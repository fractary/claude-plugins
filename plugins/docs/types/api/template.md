---
title: "{{title}}"
fractary_doc_type: api
endpoint: {{endpoint}}
method: {{method}}
service: {{service}}
version: {{version}}
status: {{status}}
date: {{date}}
author: {{author}}
tags: {{#tags}}{{.}}, {{/tags}}
codex_sync: true
generated: true
---

# {{title}}

**Endpoint**: `{{method}} {{endpoint}}`
**Service**: {{service}}
**Version**: {{version}}
**Status**: {{status}}

## Overview

{{description}}

## Authentication

{{#authentication}}
**Type**: {{type}}
**Scheme**: {{scheme}}

{{details}}
{{/authentication}}

{{^authentication}}
No authentication required.
{{/authentication}}

## Request

### HTTP Method

`{{method}} {{endpoint}}`

### Parameters

{{#parameters}}
#### `{{name}}` ({{in}})

- **Type**: `{{schema.type}}`
- **Required**: {{required}}
- **Description**: {{description}}
{{#schema.format}}
- **Format**: `{{schema.format}}`
{{/schema.format}}

{{/parameters}}

{{^parameters}}
No parameters required.
{{/parameters}}

### Request Body

{{#request_body}}
**Content-Type**: `application/json`

```json
{{schema}}
```

**Description**: {{description}}

{{/request_body}}

{{^request_body}}
No request body required.
{{/request_body}}

## Response

### Success Response (200)

{{#responses.200}}
**Content-Type**: `application/json`

```json
{{example}}
```

**Schema**:
```json
{{schema}}
```

{{/responses.200}}

### Error Responses

{{#error_responses}}
#### {{code}} - {{title}}

**Description**: {{description}}

```json
{{example}}
```

{{/error_responses}}

## Examples

### Example Request

```bash
curl -X {{method}} "https://api.example.com{{endpoint}}" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json"{{#request_example}} \
  -d '{{request_example}}'{{/request_example}}
```

### Example Response

```json
{{response_example}}
```

## Error Codes

| Code | Description |
|------|-------------|
{{#error_codes}}
| {{code}} | {{description}} |
{{/error_codes}}

## Rate Limiting

{{#rate_limiting}}
{{rate_limiting}}
{{/rate_limiting}}

{{^rate_limiting}}
Standard rate limits apply. See [Rate Limiting Guide](../../guides/rate-limiting.md).
{{/rate_limiting}}

## Related Endpoints

{{#related}}
- [{{.}}]({{.}})
{{/related}}

---

*Generated with fractary-docs plugin*
*OpenAPI specification: [endpoint.json](./endpoint.json)*
