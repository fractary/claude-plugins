# Fractary DevOps Plugin - Handlers

**Version:** 1.0.0

---

## Handler Pattern

Handlers centralize provider/tool-specific logic in dedicated skills.

### Handler Types

**Four categories:**
- **hosting**: Cloud providers (AWS, GCP, Azure)
- **iac**: IaC tools (Terraform, Pulumi, CDK)
- **source-control**: Git providers (GitHub, GitLab)
- **issue-tracker**: Issue systems (GitHub Issues, Jira, Linear)

### Handler Skill Structure

```
skills/handler-hosting-aws/
├── SKILL.md                # Handler interface
├── workflow/               # Operation workflows
│   ├── authenticate.md
│   ├── deploy.md
│   └── verify.md
├── docs/
│   └── best-practices.md
└── scripts/
    ├── auth.sh
    ├── deploy.sh
    └── verify.sh
```

### Configuration

```json
{
  "handlers": {
    "hosting": { "active": "aws", "aws": {...} },
    "iac": { "active": "terraform", "terraform": {...} }
  }
}
```

### Invocation Pattern

```markdown
<EXECUTE_DEPLOYMENT>
hosting_handler = config.handlers.hosting.active

**USE SKILL: handler-hosting-${hosting_handler}**
Operation: deploy
Arguments: ${environment} ${resources}
</EXECUTE_DEPLOYMENT>
```

### Creating New Handlers

1. Create skill directory: `skills/handler-{type}-{name}/`
2. Implement SKILL.md with standard operations
3. Add handler config to schema
4. Test with sample project

---

See architecture document for complete handler system design.
