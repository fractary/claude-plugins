---
kb_id: faber-debug-001
category: build
issue_pattern: "TypeScript type errors in module imports"
symptoms:
  - "error TS2307: Cannot find module"
  - "error TS2305: Module has no exported member"
  - "Type error: Expected * but received *"
keywords:
  - type error
  - typescript
  - import
  - module
  - cannot find
root_causes:
  - "Missing type declarations (@types/ package)"
  - "Incorrect import path or module resolution"
  - "Version mismatch between package and types"
solutions:
  - title: "Install missing type declarations"
    steps:
      - "Identify the package name from the error message"
      - "Check if @types/{package} exists on npm"
      - "Install: npm install --save-dev @types/{package}"
    faber_command: "/fractary-faber:run --work-id {work_id} --step builder --prompt \"Install missing TypeScript type declarations for the imported modules\""
  - title: "Fix import paths"
    steps:
      - "Check the import statement path"
      - "Verify the file/module exists at that path"
      - "Update to correct relative or absolute path"
    faber_command: "/fractary-faber:run --work-id {work_id} --step builder --prompt \"Fix incorrect module import paths in TypeScript files\""
status: verified
created: 2025-01-15
last_used: 2025-12-01
usage_count: 12
references:
  - "https://www.typescriptlang.org/docs/handbook/module-resolution.html"
---

# TypeScript type errors in module imports

## Problem Description

TypeScript compiler reports errors when trying to import modules, typically showing "Cannot find module" or "has no exported member" errors. This blocks the build phase.

## Symptoms

When this issue occurs, you will typically see:

- `error TS2307: Cannot find module`
- `error TS2305: Module has no exported member`
- `Type error: Expected * but received *`

## Root Cause Analysis

This issue commonly occurs when:

1. Missing type declarations (@types/ package)
2. Incorrect import path or module resolution
3. Version mismatch between package and types

### Contributing Factors

- New dependencies added without corresponding type packages
- Refactoring that moved files without updating imports
- Using packages that don't ship their own types

## Solution

### Install missing type declarations

If the error mentions a third-party package:

**Steps:**

1. Identify the package name from the error message
2. Check if @types/{package} exists on npm
3. Install: npm install --save-dev @types/{package}

**FABER Command:**
```
/fractary-faber:run --work-id {work_id} --step builder --prompt "Install missing TypeScript type declarations for the imported modules"
```

### Fix import paths

If the error is for local modules:

**Steps:**

1. Check the import statement path
2. Verify the file/module exists at that path
3. Update to correct relative or absolute path

**FABER Command:**
```
/fractary-faber:run --work-id {work_id} --step builder --prompt "Fix incorrect module import paths in TypeScript files"
```

## Verification

After applying the fix, verify success by:

1. Run `npm run build` or `tsc --noEmit`
2. Check that no TS2307 or TS2305 errors remain
3. Verify the application runs correctly

## Prevention

To prevent this issue in the future:

1. Always install @types packages when adding new dependencies
2. Use TypeScript path aliases consistently
3. Run type checking as part of CI

## Related Issues

- https://www.typescriptlang.org/docs/handbook/module-resolution.html

## Notes

This is one of the most common build-phase issues in TypeScript projects.

---

*Entry created: 2025-01-15*
*Last used: 2025-12-01*
*Status: verified*
