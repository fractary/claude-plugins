# Fractary DevOps Plugin - Configuration

**Version:** 1.0.0
**Last Updated:** 2025-10-28

---

## Configuration File Structure

**Location:** `.fractary/plugins/faber-cloud/devops.json`

### Complete Example

```json
{
  "version": "1.0",
  
  "project": {
    "name": "corthovore",
    "subsystem": "core",
    "organization": "corthos"
  },
  
  "handlers": {
    "hosting": {
      "active": "aws",
      "aws": {
        "account_id": "123456789012",
        "region": "us-east-1",
        "profiles": {
          "discover_deploy": "corthovore-core-discover-deploy",
          "test_deploy": "corthovore-core-test-deploy",
          "prod_deploy": "corthovore-core-prod-deploy"
        }
      },
      "gcp": {
        "project_id": "corthovore-core",
        "region": "us-central1"
      }
    },
    
    "iac": {
      "active": "terraform",
      "terraform": {
        "directory": "./infrastructure/terraform",
        "var_file_pattern": "{environment}.tfvars",
        "backend": {
          "type": "s3",
          "bucket": "corthovore-terraform-state",
          "key": "{project}/terraform.tfstate"
        }
      }
    }
  },
  
  "resource_naming": {
    "pattern": "{project}-{subsystem}-{environment}-{resource}",
    "separator": "-"
  },
  
  "environments": {
    "test": {
      "auto_approve": false,
      "require_confirmation": false
    },
    "prod": {
      "auto_approve": false,
      "require_confirmation": true
    }
  },
  
  "logging": {
    "backend": "s3",
    "s3_bucket": "corthovore-devops-logs",
    "local_cache_days": 7
  }
}
```

### Pattern Substitution

Variables available in patterns:
- `{project}`: Project name
- `{subsystem}`: Subsystem name
- `{environment}`: Current environment (test/prod)
- `{resource}`: Resource name
- `{organization}`: Organization name

Example: `{project}-{subsystem}-{environment}-{resource}` → `corthovore-core-test-uploads`

---

See [full specification](fractary-faber-cloud-configuration.md) for detailed schema and examples.
