---
kb_id: faber-debug-002
category: build
issue_pattern: "Missing npm dependency in package.json"
symptoms:
  - "Cannot find module 'package-name'"
  - "npm ERR! missing: package-name"
  - "Error: Module not found"
keywords:
  - npm
  - dependency
  - package
  - install
  - missing
root_causes:
  - "Package not listed in package.json"
  - "node_modules not installed or out of sync"
  - "Package installed globally but not locally"
solutions:
  - title: "Install missing dependency"
    steps:
      - "Identify the missing package name from the error"
      - "Run: npm install {package-name}"
      - "Verify package.json was updated"
    faber_command: "/fractary-faber:run --work-id {work_id} --step builder --prompt \"Install missing npm dependency and add to package.json\""
  - title: "Reinstall node_modules"
    steps:
      - "Delete node_modules directory"
      - "Delete package-lock.json if corrupted"
      - "Run: npm install"
    faber_command: "/fractary-faber:run --work-id {work_id} --step builder --prompt \"Clean reinstall of npm dependencies\""
status: verified
created: 2025-01-20
last_used: 2025-11-28
usage_count: 8
references:
  - "https://docs.npmjs.com/cli/v10/commands/npm-install"
---

# Missing npm dependency in package.json

## Problem Description

The build or runtime fails because a required npm package is not installed or not listed as a dependency. This typically occurs when new code references a package that wasn't added to package.json.

## Symptoms

When this issue occurs, you will typically see:

- `Cannot find module 'package-name'`
- `npm ERR! missing: package-name`
- `Error: Module not found`

## Root Cause Analysis

This issue commonly occurs when:

1. Package not listed in package.json
2. node_modules not installed or out of sync
3. Package installed globally but not locally

### Contributing Factors

- Copying code from another project without dependencies
- Running `npm install` with --no-save flag
- Git operations that don't include node_modules

## Solution

### Install missing dependency

**Steps:**

1. Identify the missing package name from the error
2. Run: npm install {package-name}
3. Verify package.json was updated

**FABER Command:**
```
/fractary-faber:run --work-id {work_id} --step builder --prompt "Install missing npm dependency and add to package.json"
```

### Reinstall node_modules

If node_modules is corrupted or out of sync:

**Steps:**

1. Delete node_modules directory
2. Delete package-lock.json if corrupted
3. Run: npm install

**FABER Command:**
```
/fractary-faber:run --work-id {work_id} --step builder --prompt "Clean reinstall of npm dependencies"
```

## Verification

After applying the fix, verify success by:

1. Check package.json includes the dependency
2. Run `npm ls {package-name}` to verify it's installed
3. Run the build again

## Prevention

To prevent this issue in the future:

1. Always use `npm install {package}` (not --no-save)
2. Commit package-lock.json to version control
3. Run `npm ci` in CI/CD for deterministic installs

## Related Issues

- https://docs.npmjs.com/cli/v10/commands/npm-install

## Notes

For development dependencies, use `npm install --save-dev {package}`.

---

*Entry created: 2025-01-20*
*Last used: 2025-11-28*
*Status: verified*
