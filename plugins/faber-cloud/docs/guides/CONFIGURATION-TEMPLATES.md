# Configuration Templates Guide

This guide explains the three configuration templates provided by faber-cloud for different Terraform infrastructure patterns.

## Overview

faber-cloud provides **three configuration templates** designed for different infrastructure organization patterns:

1. **Flat Template** - Single directory, simple structure
2. **Modular Template** - Shared modules, moderate complexity
3. **Multi-Environment Template** - Per-environment directories, complex structure

The **adoption workflow** (`/fractary-faber-cloud:adopt`) automatically selects the appropriate template based on your discovered infrastructure structure.

## Template Selection Logic

The adoption process analyzes your infrastructure and selects a template using these criteria:

```
Flat Template:
  ✓ Single Terraform directory
  ✓ No modules/ subdirectory
  ✓ No environments/ subdirectory
  ✓ Uses *.tfvars files for environment differences
  ✓ Workspace-based or single state file

Modular Template:
  ✓ Has modules/ subdirectory
  ✓ Shared reusable modules
  ✓ Single root directory with environment tfvars
  ✓ Module composition pattern

Multi-Environment Template:
  ✓ Has environments/ subdirectory
  ✓ Separate directory per environment
  ✓ Each environment has own Terraform files
  ✓ May also have shared modules/
  ✓ Highest isolation between environments
```

## Template Comparison

| Feature | Flat | Modular | Multi-Environment |
|---------|------|---------|-------------------|
| **Directory Structure** | Single | Single + modules/ | environments/ + modules/ |
| **Environment Separation** | tfvars files | tfvars files | Directories |
| **Module Support** | No | Yes (shared) | Yes (shared) |
| **State Management** | Workspaces or separate files | Workspaces | Separate per environment |
| **Complexity** | Simple | Moderate | Complex |
| **Best For** | Small projects, prototypes | Growing projects, reusability | Large projects, strict isolation |
| **Team Size** | 1-2 developers | 2-5 developers | 5+ developers |
| **Promotion Path** | No | No | Yes (dev→staging→prod) |

## Template 1: Flat

### When to Use

Use the **Flat Template** when:

- Starting a new infrastructure project
- Managing a single application or service
- Infrastructure has < 20 resources
- No need for shared modules
- Simple environment differences (mostly variable values)
- Small team (1-2 developers)

### Directory Structure

```
project/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── test.tfvars
│   ├── prod.tfvars
│   └── terraform.tfstate (or workspaces)
└── .fractary/
    └── plugins/
        └── faber-cloud/
            └── config/
                └── faber-cloud.json
```

### Configuration Structure

```json
{
  "version": "1.0",
  "project": {
    "name": "myapp",
    "description": "Infrastructure managed by faber-cloud",
    "repository": "https://github.com/myorg/myapp"
  },
  "environments": [
    {
      "name": "test",
      "aws_profile": "myapp-test",
      "terraform_dir": "./terraform",
      "terraform_vars": "test.tfvars",
      "protected": false
    },
    {
      "name": "prod",
      "aws_profile": "myapp-prod",
      "terraform_dir": "./terraform",
      "terraform_vars": "prod.tfvars",
      "protected": true
    }
  ],
  "terraform": {
    "version": "1.0",
    "default_directory": "./terraform",
    "backend_type": "local",
    "var_file_pattern": "{environment}.tfvars",
    "plan_file": "tfplan",
    "state_file": "terraform.tfstate"
  },
  "deployment": {
    "validation": {
      "enhanced_environment_detection": true,
      "require_environment_match": true,
      "check_state_file": true,
      "check_workspace": true,
      "check_tfvars": true
    }
  }
}
```

### Key Features

- **Single Directory**: All Terraform files in one location
- **tfvars-Based Environments**: `test.tfvars` and `prod.tfvars` contain environment-specific values
- **Workspace State Management**: Uses Terraform workspaces or separate state files
- **Simple Validation**: Checks workspace and tfvars file match

### Advantages

- Simple to understand and navigate
- Easy to get started
- Low complexity, fast operations
- Good for prototyping

### Limitations

- Limited code reuse across environments
- Can become messy as project grows
- No physical separation between environments
- Harder to manage with large teams

### Migration Path

**Growing beyond flat?**

When you have > 5 shared resource patterns, migrate to **Modular Template**:

```bash
# Reorganize structure
mkdir -p terraform/modules
mv terraform/networking terraform/modules/
mv terraform/database terraform/modules/

# Re-run adoption
/fractary-faber-cloud:adopt
# Will detect modules/ and select Modular Template
```

## Template 2: Modular

### When to Use

Use the **Modular Template** when:

- Infrastructure has repeated patterns (VPC, RDS, S3 buckets)
- Need code reuse across environments
- Managing 20-50 resources
- Team of 2-5 developers
- Want DRY (Don't Repeat Yourself) infrastructure code
- Moderate complexity acceptable

### Directory Structure

```
project/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── test.tfvars
│   ├── prod.tfvars
│   └── modules/
│       ├── networking/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── database/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── compute/
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
└── .fractary/
    └── plugins/
        └── faber-cloud/
            └── config/
                └── faber-cloud.json
```

### Configuration Structure

```json
{
  "version": "1.0",
  "project": {
    "name": "myapp",
    "description": "Modular infrastructure managed by faber-cloud",
    "repository": "https://github.com/myorg/myapp"
  },
  "environments": [
    {
      "name": "test",
      "aws_profile": "myapp-test",
      "terraform_dir": "./terraform",
      "terraform_vars": "test.tfvars",
      "protected": false
    },
    {
      "name": "prod",
      "aws_profile": "myapp-prod",
      "terraform_dir": "./terraform",
      "terraform_vars": "prod.tfvars",
      "protected": true
    }
  ],
  "terraform": {
    "version": "1.0",
    "default_directory": "./terraform",
    "modules_directory": "./terraform/modules",
    "backend_type": "local",
    "var_file_pattern": "{environment}.tfvars",
    "module_sources": {
      "local": true,
      "registry": false
    }
  },
  "deployment": {
    "validation": {
      "enhanced_environment_detection": true,
      "require_environment_match": true,
      "check_state_file": true,
      "check_workspace": true,
      "check_tfvars": true,
      "validate_modules": true
    }
  },
  "modules": {
    "validate_before_apply": true,
    "cache_registry_modules": true,
    "allowed_sources": [
      "local",
      "terraform-aws-modules"
    ]
  }
}
```

### Key Features

- **modules_directory**: Declares location of reusable modules
- **Module Validation**: Validates modules before deployment
- **Module Sources Control**: Specify allowed module sources (local, registry)
- **Module Caching**: Cache registry modules for faster operations

### Advantages

- Code reuse reduces duplication
- Easier to maintain repeated patterns
- Encapsulation of complex resources
- Better testing (modules can be tested independently)
- Scales better than flat structure

### Limitations

- More complex than flat structure
- Module versioning can be tricky
- Still shares same directory for environments
- Can over-engineer simple infrastructure

### Module Best Practices

**Good module candidates:**
- Networking (VPC, subnets, routing)
- Database configurations (RDS with backups, monitoring)
- Load balancers with target groups
- S3 buckets with policies and encryption
- Lambda functions with IAM roles

**Poor module candidates:**
- Single resources without complexity
- One-off configurations
- Resources that never repeat

### Migration Path

**Need more isolation?**

When managing 3+ environments with different lifecycles, migrate to **Multi-Environment Template**:

```bash
# Reorganize structure
mkdir -p terraform/environments/{dev,test,staging,prod}
# Move environment-specific files
# Keep shared modules/

# Re-run adoption
/fractary-faber-cloud:adopt
# Will detect environments/ and select Multi-Environment Template
```

## Template 3: Multi-Environment

### When to Use

Use the **Multi-Environment Template** when:

- Managing 3+ environments (dev, test, staging, prod)
- Need strong isolation between environments
- Different infrastructure in each environment
- Infrastructure has > 50 resources
- Team of 5+ developers
- Require promotion paths (dev → staging → prod)
- Enterprise-grade requirements

### Directory Structure

```
project/
├── terraform/
│   ├── environments/
│   │   ├── dev/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── terraform.tfvars
│   │   │   └── backend.tf
│   │   ├── test/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── terraform.tfvars
│   │   │   └── backend.tf
│   │   ├── staging/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── terraform.tfvars
│   │   │   └── backend.tf
│   │   └── prod/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       ├── terraform.tfvars
│   │       └── backend.tf
│   └── modules/
│       ├── networking/
│       ├── database/
│       └── compute/
└── .fractary/
    └── plugins/
        └── faber-cloud/
            └── config/
                └── faber-cloud.json
```

### Configuration Structure

```json
{
  "version": "1.0",
  "project": {
    "name": "myapp",
    "description": "Multi-environment infrastructure managed by faber-cloud",
    "repository": "https://github.com/myorg/myapp"
  },
  "environments": [
    {
      "name": "dev",
      "aws_profile": "myapp-dev",
      "terraform_dir": "./terraform/environments/dev",
      "terraform_vars": "terraform.tfvars",
      "protected": false
    },
    {
      "name": "test",
      "aws_profile": "myapp-test",
      "terraform_dir": "./terraform/environments/test",
      "terraform_vars": "terraform.tfvars",
      "protected": false
    },
    {
      "name": "staging",
      "aws_profile": "myapp-staging",
      "terraform_dir": "./terraform/environments/staging",
      "terraform_vars": "terraform.tfvars",
      "protected": true
    },
    {
      "name": "prod",
      "aws_profile": "myapp-prod",
      "terraform_dir": "./terraform/environments/prod",
      "terraform_vars": "terraform.tfvars",
      "protected": true
    }
  ],
  "terraform": {
    "version": "1.0",
    "default_directory": "./terraform",
    "environments_directory": "./terraform/environments",
    "modules_directory": "./terraform/modules",
    "backend_type": "local",
    "var_file_pattern": "terraform.tfvars",
    "environment_path_pattern": "{environments_directory}/{environment}",
    "module_sources": {
      "local": true,
      "registry": false
    }
  },
  "deployment": {
    "approval": {
      "required": true,
      "environments": ["staging", "prod"]
    },
    "validation": {
      "enhanced_environment_detection": true,
      "require_environment_match": true,
      "check_state_file": true,
      "check_workspace": false,
      "check_tfvars": true,
      "check_directory_path": true,
      "validate_modules": true
    },
    "promotion": {
      "enabled": true,
      "path": ["dev", "staging", "prod"],
      "require_previous_success": true
    }
  },
  "modules": {
    "validate_before_apply": true,
    "cache_registry_modules": true,
    "shared_modules": true,
    "allowed_sources": [
      "local",
      "terraform-aws-modules"
    ]
  }
}
```

### Key Features

- **environments_directory**: Root location for all environment directories
- **environment_path_pattern**: Pattern for resolving environment paths
- **Separate State Files**: Each environment has isolated state
- **Directory Path Validation**: Validates operations target correct directory
- **Promotion Paths**: Enforces dev → staging → prod progression
- **No Workspace Checking**: Uses directories instead of workspaces

### Advantages

- **Maximum isolation** between environments
- Different infrastructure per environment
- Separate state files (no workspace confusion)
- Clear promotion paths
- Excellent for large teams
- Enterprise-ready

### Limitations

- Most complex structure
- More overhead to manage
- Can duplicate code across environments (use modules!)
- Requires discipline to keep environments in sync

### Promotion Workflow

The multi-environment template supports **promotion paths**:

```json
{
  "deployment": {
    "promotion": {
      "enabled": true,
      "path": ["dev", "staging", "prod"],
      "require_previous_success": true
    }
  }
}
```

**How it works:**

1. **Deploy to dev first**:
   ```bash
   /fractary-faber-cloud:deploy-execute --env=dev
   ```

2. **After dev succeeds, can deploy to staging**:
   ```bash
   /fractary-faber-cloud:deploy-execute --env=staging
   ```

3. **After staging succeeds, can deploy to prod**:
   ```bash
   /fractary-faber-cloud:deploy-execute --env=prod
   ```

If you try to skip steps, faber-cloud will block the deployment.

## Configuration Fields Explained

### Common to All Templates

#### project

```json
{
  "project": {
    "name": "myapp",
    "description": "Infrastructure managed by faber-cloud",
    "repository": "https://github.com/myorg/myapp"
  }
}
```

- **name**: Project identifier, used in AWS profiles, tags, naming
- **description**: Human-readable description
- **repository**: Git repository URL for documentation

#### environments

```json
{
  "environments": [
    {
      "name": "test",
      "aws_profile": "myapp-test",
      "terraform_dir": "./terraform",
      "terraform_vars": "test.tfvars",
      "protected": false
    }
  ]
}
```

Each environment requires:
- **name**: Environment identifier (test, prod, dev, staging)
- **aws_profile**: AWS CLI profile name
- **terraform_dir**: Directory containing Terraform files
- **terraform_vars**: Variable file for this environment
- **protected**: If true, requires approval for deployments

#### terraform

```json
{
  "terraform": {
    "version": "1.0",
    "default_directory": "./terraform",
    "backend_type": "local",
    "var_file_pattern": "{environment}.tfvars",
    "plan_file": "tfplan",
    "state_file": "terraform.tfstate"
  }
}
```

- **version**: Terraform version constraint
- **default_directory**: Default location for Terraform files
- **backend_type**: State backend (local, s3, remote)
- **var_file_pattern**: Pattern for finding tfvars files
- **plan_file**: Name of plan file for preview operations
- **state_file**: State file name (for local backend)

#### handlers

```json
{
  "handlers": {
    "iac": {
      "active": "terraform",
      "terraform": {
        "auto_init": true,
        "lock_timeout": "10m",
        "parallelism": 10
      }
    },
    "hosting": {
      "active": "aws",
      "aws": {
        "retry_attempts": 3,
        "retry_delay": 5
      }
    }
  }
}
```

Handlers define provider-specific settings:
- **iac.active**: Which IaC tool (terraform, pulumi, cdk)
- **hosting.active**: Which cloud provider (aws, azure, gcp)
- Provider-specific configuration nested under handler

#### deployment

```json
{
  "deployment": {
    "approval": {
      "required": true,
      "environments": ["prod"]
    },
    "validation": {
      "enhanced_environment_detection": true,
      "require_environment_match": true,
      "check_state_file": true,
      "check_workspace": true,
      "check_tfvars": true
    },
    "rollback": {
      "enabled": true,
      "automatic": false,
      "keep_failed_plans": true
    }
  }
}
```

- **approval**: Require manual approval for specific environments
- **validation**: Enhanced validation checks (see SPEC-00030-02)
- **rollback**: Rollback behavior on failures

### Template-Specific Fields

#### Modular Template

```json
{
  "terraform": {
    "modules_directory": "./terraform/modules"
  },
  "modules": {
    "validate_before_apply": true,
    "cache_registry_modules": true,
    "allowed_sources": [
      "local",
      "terraform-aws-modules"
    ]
  }
}
```

- **modules_directory**: Location of reusable modules
- **validate_before_apply**: Run `terraform validate` on modules
- **cache_registry_modules**: Cache external modules
- **allowed_sources**: Whitelist of allowed module sources

#### Multi-Environment Template

```json
{
  "terraform": {
    "environments_directory": "./terraform/environments",
    "environment_path_pattern": "{environments_directory}/{environment}"
  },
  "deployment": {
    "validation": {
      "check_directory_path": true,
      "check_workspace": false
    },
    "promotion": {
      "enabled": true,
      "path": ["dev", "staging", "prod"],
      "require_previous_success": true
    }
  }
}
```

- **environments_directory**: Root for all environment directories
- **environment_path_pattern**: How to resolve environment paths
- **check_directory_path**: Validate operations target correct directory
- **check_workspace**: Disabled (uses directories, not workspaces)
- **promotion**: Enforce promotion paths between environments

## Customizing Templates

After adoption generates a configuration, you can customize it:

### Adding Hooks

See [HOOKS.md](./HOOKS.md) for comprehensive hook documentation.

Example - add pre-deployment validation:

```json
{
  "hooks": {
    "pre_deploy": [
      {
        "name": "security-scan",
        "command": "bash ./scripts/security-scan.sh {{environment}}",
        "critical": true,
        "timeout": 300
      }
    ]
  }
}
```

### Enabling Monitoring

Enable CloudWatch logging:

```json
{
  "monitoring": {
    "enabled": true,
    "cloudwatch": {
      "enabled": true,
      "log_group": "/aws/faber-cloud/{environment}"
    }
  }
}
```

### Enabling Notifications

Enable Slack notifications:

```json
{
  "notifications": {
    "enabled": true,
    "slack": {
      "webhook_url": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL",
      "channel": "#infrastructure"
    }
  }
}
```

### Changing Backend

Switch from local to S3 backend:

```json
{
  "terraform": {
    "backend_type": "s3",
    "backend_config": {
      "bucket": "myapp-terraform-state",
      "key": "{environment}/terraform.tfstate",
      "region": "us-east-1",
      "dynamodb_table": "terraform-locks",
      "encrypt": true
    }
  }
}
```

### Adding More Environments

Add a new environment:

```json
{
  "environments": [
    {
      "name": "staging",
      "aws_profile": "myapp-staging",
      "terraform_dir": "./terraform/environments/staging",
      "terraform_vars": "terraform.tfvars",
      "protected": true
    }
  ]
}
```

Then create AWS profile:

```bash
aws configure --profile myapp-staging
```

## Decision Tree: Which Template?

Use this decision tree to choose the right template:

```
Start
  |
  ├─ Do you have an environments/ directory?
  │   └─ YES → Multi-Environment Template
  │
  ├─ Do you have a modules/ directory?
  │   └─ YES → Modular Template
  │
  └─ Single Terraform directory with tfvars?
      └─ YES → Flat Template

OR

Based on project characteristics:

Resources < 20, Team 1-2 people
  → Flat Template

Resources 20-50, Team 2-5 people, Need reusability
  → Modular Template

Resources > 50, Team 5+ people, Need isolation, Enterprise
  → Multi-Environment Template
```

## Template Migration Guide

### Flat → Modular

When you've identified repeated patterns:

1. **Create modules directory**:
   ```bash
   mkdir -p terraform/modules
   ```

2. **Extract common patterns**:
   ```bash
   # Example: Extract networking
   mkdir terraform/modules/networking
   # Move VPC, subnet, routing resources to module
   ```

3. **Update main.tf to use modules**:
   ```hcl
   module "networking" {
     source = "./modules/networking"
     environment = var.environment
     vpc_cidr = var.vpc_cidr
   }
   ```

4. **Re-run adoption**:
   ```bash
   /fractary-faber-cloud:adopt
   ```

5. **Test thoroughly**:
   ```bash
   /fractary-faber-cloud:deploy-plan --env=test
   # Verify "No changes" if you migrated correctly
   ```

### Modular → Multi-Environment

When you need stronger isolation:

1. **Create environments directory**:
   ```bash
   mkdir -p terraform/environments/{dev,test,staging,prod}
   ```

2. **Copy Terraform files to each environment**:
   ```bash
   for env in dev test staging prod; do
     cp terraform/*.tf terraform/environments/$env/
     cp terraform/${env}.tfvars terraform/environments/$env/terraform.tfvars
   done
   ```

3. **Update module sources** (now relative):
   ```hcl
   # In environments/test/main.tf
   module "networking" {
     source = "../../modules/networking"  # Note: ../../
     # ...
   }
   ```

4. **Re-run adoption**:
   ```bash
   /fractary-faber-cloud:adopt
   ```

5. **Test each environment separately**:
   ```bash
   /fractary-faber-cloud:deploy-plan --env=dev
   /fractary-faber-cloud:deploy-plan --env=test
   # Verify each environment independently
   ```

## Best Practices

### All Templates

1. **Version Control**: Always commit `.fractary/plugins/faber-cloud/faber-cloud.json`
2. **Test First**: Always test in test environment before production
3. **Protected Environments**: Mark prod (and staging) as `"protected": true`
4. **Use Hooks**: Leverage lifecycle hooks for custom logic
5. **Document Changes**: Update repository README when configuration changes

### Flat Template

1. **Keep It Simple**: Don't over-engineer, flat is meant to be simple
2. **Use Workspaces**: Leverage Terraform workspaces for state separation
3. **Consistent Naming**: Use consistent tfvars naming (env.tfvars)

### Modular Template

1. **Module Versioning**: Version your modules (git tags, semantic versioning)
2. **Module Documentation**: Document module inputs, outputs, and purpose
3. **Test Modules**: Test modules independently before using in root
4. **Limit Module Depth**: Avoid modules calling modules calling modules

### Multi-Environment Template

1. **Shared Modules**: Keep common logic in modules/, environment-specific in environments/
2. **Consistent Structure**: Each environment should have same file structure
3. **Promotion Discipline**: Always follow promotion path (dev → staging → prod)
4. **Separate State Backends**: Use separate S3 buckets or paths for each environment
5. **Environment Parity**: Keep environments as similar as possible (IaC, not config)

## Troubleshooting

### Adoption Selected Wrong Template

**Problem**: Adoption selected Flat, but you have modules

**Solution**: Ensure modules are in `terraform/modules/` directory (exact name). Re-run adoption:
```bash
/fractary-faber-cloud:adopt
```

### Environment Validation Failing

**Problem**: `Error: Environment mismatch detected`

**Solution**: Check your configuration matches your directory structure:
- Flat: Same `terraform_dir` for all environments, different `terraform_vars`
- Modular: Same pattern as Flat, but with modules/
- Multi-Environment: Different `terraform_dir` per environment

### Modules Not Found

**Problem**: `Error: Module not found: ./modules/networking`

**Solution**:
- **Modular**: Modules should be at `terraform/modules/`
- **Multi-Environment**: Update module sources in environment files to use `../../modules/`

### Promotion Blocked

**Problem**: `Error: Cannot deploy to prod - staging has not succeeded`

**Solution**: Follow promotion path:
```bash
# Deploy to previous environment first
/fractary-faber-cloud:deploy-execute --env=staging
# Wait for success, then deploy to prod
/fractary-faber-cloud:deploy-execute --env=prod
```

## Configuration Schema

All templates conform to the faber-cloud configuration schema:

```
$schema: https://raw.githubusercontent.com/fractary/claude-plugins/main/plugins/faber-cloud/schemas/faber-cloud-config.schema.json
```

This schema validates:
- Required fields are present
- Field types are correct
- Values are within acceptable ranges
- Environment configurations are valid

## Next Steps

After understanding configuration templates:

1. **Run Adoption**: Let adoption select the right template
   ```bash
   /fractary-faber-cloud:adopt
   ```

2. **Review Generated Config**: Check `.fractary/adoption/faber-cloud.json`

3. **Customize as Needed**: Add hooks, monitoring, notifications

4. **Test Thoroughly**: Start with test environment
   ```bash
   /fractary-faber-cloud:audit --env=test
   /fractary-faber-cloud:deploy-plan --env=test
   ```

5. **Follow Migration Guide**: See `MIGRATION.md` generated by adoption

## Related Documentation

- [HOOKS.md](./HOOKS.md) - Comprehensive hook system guide with 11+ examples
- [MIGRATION-FROM-CUSTOM-AGENTS.md](./MIGRATION-FROM-CUSTOM-AGENTS.md) - Migrate from custom scripts
- [SPEC-00030-01](../../specs/SPEC-00030-01-faber-cloud-adoption-migration.md) - Adoption specification
- [SPEC-00030-02](../../specs/SPEC-00030-02-enhanced-environment-validation.md) - Environment validation specification
- [adopt command](../../commands/adopt.md) - Adoption command documentation
