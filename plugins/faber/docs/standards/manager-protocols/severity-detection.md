# Severity and Category Auto-Detection

This document defines heuristics for automatically assigning severity and category to warnings and errors when skills do not provide explicit values.

## Overview

When a skill response includes warnings or errors as simple strings (backward compatible format), the workflow manager applies auto-detection heuristics to assign:
- **Severity**: low, medium, high
- **Category**: deprecation, performance, security, style, compatibility, validation, configuration, other

Skills SHOULD provide explicit severity and category for accuracy. Auto-detection is a fallback mechanism.

---

## Severity Detection

### High Severity

Issues that require immediate attention and may block further progress.

**Keywords** (case-insensitive):
- `critical`, `fatal`, `crash`, `corruption`
- `security`, `vulnerability`, `exploit`, `attack`
- `breaking`, `breaking change`, `incompatible`
- `fail`, `failure`, `failed`, `error`
- `data loss`, `data corruption`
- `authentication`, `authorization`, `permission denied`
- `injection`, `xss`, `csrf`, `sql injection`

**Patterns**:
```
/\b(critical|fatal|security|vulnerability|breaking|crash)\b/i
/\b(authentication|authorization) (fail|error)/i
/\bdata (loss|corruption)\b/i
```

### Medium Severity

Issues that should be addressed but don't block immediate progress.

**Keywords** (case-insensitive):
- `deprecated`, `deprecation`, `obsolete`, `removed in`
- `warning`, `warn`, `caution`
- `should`, `consider`, `recommend`
- `performance`, `slow`, `timeout`
- `memory`, `leak`, `cpu`
- `missing`, `incomplete`

**Patterns**:
```
/\b(deprecated|obsolete|removed in)\b/i
/\bwill be removed\b/i
/\bperformance (issue|warning|concern)\b/i
/\bshould (be|use|consider)\b/i
```

### Low Severity

Informational issues that can be safely ignored in most cases.

**Keywords** (case-insensitive):
- `style`, `format`, `formatting`, `lint`
- `minor`, `trivial`, `cosmetic`
- `optional`, `suggestion`
- `info`, `note`, `hint`
- `convention`, `best practice`

**Patterns**:
```
/\b(style|format|lint) (issue|warning|error)\b/i
/\b(minor|trivial|cosmetic)\b/i
/\boptional(ly)?\b/i
```

### Default

If no patterns match, assign **medium** severity (err on the side of caution).

---

## Category Detection

### deprecation

Issues related to deprecated or obsolete features.

**Keywords**:
- `deprecated`, `deprecation`, `obsolete`
- `will be removed`, `removed in`, `end of life`
- `legacy`, `old api`, `outdated`
- `replaced by`, `use instead`

**Patterns**:
```
/\b(deprecated|obsolete|legacy)\b/i
/\bwill be removed (in|by)\b/i
/\breplaced (by|with)\b/i
```

### performance

Issues related to performance, speed, or resource usage.

**Keywords**:
- `performance`, `slow`, `fast`, `speed`
- `memory`, `ram`, `heap`
- `cpu`, `processor`, `compute`
- `timeout`, `latency`, `response time`
- `bundle`, `size`, `large`, `heavy`
- `leak`, `allocation`

**Patterns**:
```
/\b(performance|speed|latency)\b/i
/\b(memory|heap|ram) (usage|leak)\b/i
/\bbundle size\b/i
/\btimeout\b/i
```

### security

Issues related to security vulnerabilities or risks.

**Keywords**:
- `security`, `secure`, `insecure`
- `vulnerability`, `vulnerable`, `exploit`
- `attack`, `vector`, `threat`
- `authentication`, `authorization`, `auth`
- `permission`, `access`, `privilege`
- `injection`, `xss`, `csrf`, `sqli`
- `encryption`, `decrypt`, `certificate`
- `credential`, `password`, `secret`, `token`

**Patterns**:
```
/\b(security|vulnerability|exploit)\b/i
/\b(auth|permission|access) (error|denied|fail)\b/i
/\b(xss|csrf|sql.?injection)\b/i
/\b(credential|password|secret|token)\b/i
```

### style

Issues related to code style, formatting, or conventions.

**Keywords**:
- `style`, `format`, `formatting`
- `lint`, `linter`, `eslint`, `prettier`
- `convention`, `naming`, `indent`
- `whitespace`, `spacing`, `tabs`, `spaces`
- `line length`, `max length`

**Patterns**:
```
/\b(style|format|lint)\b/i
/\b(eslint|prettier|tslint)\b/i
/\b(naming|indent|whitespace)\b/i
```

### compatibility

Issues related to compatibility between versions, platforms, or systems.

**Keywords**:
- `compatibility`, `compatible`, `incompatible`
- `version`, `upgrade`, `downgrade`
- `platform`, `browser`, `node`
- `api`, `interface`, `contract`
- `breaking`, `migration`

**Patterns**:
```
/\b(in)?compatible\b/i
/\bbreaking (change|update)\b/i
/\b(version|upgrade|migration)\b/i
```

### validation

Issues related to data validation, schema, or type checking.

**Keywords**:
- `validation`, `validate`, `invalid`
- `schema`, `type`, `typing`
- `required`, `missing`, `undefined`
- `format`, `pattern`, `regex`
- `constraint`, `rule`

**Patterns**:
```
/\b(valid|invalid|validation)\b/i
/\bschema (error|mismatch)\b/i
/\b(required|missing) (field|property|parameter)\b/i
```

### configuration

Issues related to configuration, settings, or environment.

**Keywords**:
- `configuration`, `config`, `setting`
- `environment`, `env`, `variable`
- `parameter`, `option`, `flag`
- `default`, `override`

**Patterns**:
```
/\b(config|configuration|setting)\b/i
/\b(env|environment) (variable|var)\b/i
/\bmissing (config|setting|parameter)\b/i
```

### other

Default category when no patterns match.

---

## Detection Algorithm

```pseudocode
FUNCTION detectSeverityAndCategory(text: string):
  severity = null
  category = null

  # Severity detection (first match wins)
  IF matchesHighSeverityPatterns(text) THEN
    severity = "high"
  ELSE IF matchesMediumSeverityPatterns(text) THEN
    severity = "medium"
  ELSE IF matchesLowSeverityPatterns(text) THEN
    severity = "low"
  ELSE
    severity = "medium"  # Default

  # Category detection (first match wins)
  IF matchesSecurityPatterns(text) THEN
    category = "security"
  ELSE IF matchesDeprecationPatterns(text) THEN
    category = "deprecation"
  ELSE IF matchesPerformancePatterns(text) THEN
    category = "performance"
  ELSE IF matchesValidationPatterns(text) THEN
    category = "validation"
  ELSE IF matchesCompatibilityPatterns(text) THEN
    category = "compatibility"
  ELSE IF matchesConfigurationPatterns(text) THEN
    category = "configuration"
  ELSE IF matchesStylePatterns(text) THEN
    category = "style"
  ELSE
    category = "other"  # Default

  RETURN { severity, category }
```

## Priority Order

Category detection follows priority order (security issues take precedence):

1. **security** - Always highest priority
2. **deprecation** - Breaking changes are important
3. **performance** - May affect user experience
4. **validation** - Data integrity issues
5. **compatibility** - Platform/version issues
6. **configuration** - Setup issues
7. **style** - Lowest priority among specific categories
8. **other** - Fallback

---

## Examples

### Input: "Deprecated API: useCallback will be removed in v3.0"
- **Severity**: medium (contains "deprecated", "will be removed")
- **Category**: deprecation (contains "deprecated", "will be removed")

### Input: "SQL injection vulnerability in user input handler"
- **Severity**: high (contains "vulnerability", "injection")
- **Category**: security (contains "vulnerability", "injection")

### Input: "Line too long (120 chars, max 100)"
- **Severity**: low (style-related, no critical keywords)
- **Category**: style (contains "line", formatting context)

### Input: "Memory leak detected in event listener"
- **Severity**: medium (contains "leak")
- **Category**: performance (contains "memory", "leak")

### Input: "Missing required field 'user_id' in request body"
- **Severity**: medium (contains "missing", "required")
- **Category**: validation (contains "required", "missing", "field")

---

## Integration

### Converting String to Object

When processing a response with string warnings/errors:

```pseudocode
FUNCTION processWarning(warning):
  IF typeof warning == "string" THEN
    detected = detectSeverityAndCategory(warning)
    RETURN {
      text: warning,
      severity: detected.severity,
      category: detected.category
    }
  ELSE
    # Already an object, validate and fill missing fields
    RETURN {
      text: warning.text,
      severity: warning.severity ?? detectSeverityAndCategory(warning.text).severity,
      category: warning.category ?? detectSeverityAndCategory(warning.text).category
    }
```

### Skill Override

Skills can always provide explicit severity and category to override auto-detection:

```json
{
  "status": "warning",
  "message": "Build completed with issues",
  "warnings": [
    {
      "text": "Custom warning message",
      "severity": "high",
      "category": "security"
    }
  ]
}
```

Explicit values are always preferred over auto-detected values.
