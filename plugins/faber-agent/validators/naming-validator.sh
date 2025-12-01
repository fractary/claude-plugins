#!/bin/bash
#
# naming-validator.sh
#
# Validates naming conventions for agents, skills, commands, and plugins
# against Fractary standards.
#
# Usage: naming-validator.sh <artifact_name> <artifact_type>
#
# Arguments:
#   artifact_name  - Name to validate (e.g., "data-fetcher", "fractary-faber:run")
#   artifact_type  - Type: "agent" | "skill" | "command" | "plugin"
#
# Exit codes:
#   0 - Name is valid
#   1 - Name violates conventions
#   2 - Invalid arguments
#
# Output:
#   Validation results in structured format

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <artifact_name> <artifact_type>" >&2
    echo "  artifact_type: agent | skill | command | plugin" >&2
    exit 2
fi

ARTIFACT_NAME="$1"
ARTIFACT_TYPE="$2"

# Validate artifact type
if [[ ! "$ARTIFACT_TYPE" =~ ^(agent|skill|command|plugin)$ ]]; then
    echo "Error: artifact_type must be one of: agent, skill, command, plugin" >&2
    exit 2
fi

# Initialize validation state
ERRORS=0
WARNINGS=0

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Naming Convention Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Name: $ARTIFACT_NAME"
echo "Type: $ARTIFACT_TYPE"
echo ""

# Validation rules by artifact type
case "$ARTIFACT_TYPE" in
    agent)
        echo "Checking agent naming conventions..."
        echo ""

        # Rule 1: Lowercase with hyphens only
        if [[ ! "$ARTIFACT_NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
            echo -e "${RED}❌${NC} Must use lowercase letters, numbers, and hyphens only"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "${GREEN}✅${NC} Uses lowercase and hyphens"
        fi

        # Rule 2: Must start with letter
        if [[ ! "$ARTIFACT_NAME" =~ ^[a-z] ]]; then
            echo -e "${RED}❌${NC} Must start with a letter"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "${GREEN}✅${NC} Starts with letter"
        fi

        # Rule 3: No consecutive hyphens
        if [[ "$ARTIFACT_NAME" =~ -- ]]; then
            echo -e "${RED}❌${NC} Contains consecutive hyphens"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "${GREEN}✅${NC} No consecutive hyphens"
        fi

        # Rule 4: Length check (3-50 characters)
        length=${#ARTIFACT_NAME}
        if [ $length -lt 3 ] || [ $length -gt 50 ]; then
            echo -e "${RED}❌${NC} Length must be 3-50 characters (current: $length)"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "${GREEN}✅${NC} Length is valid ($length characters)"
        fi

        # Rule 5: Should end with descriptive suffix for type
        if [[ "$ARTIFACT_NAME" =~ -(manager|creator|handler|director)$ ]]; then
            echo -e "${GREEN}✅${NC} Has descriptive suffix"
        else
            echo -e "${YELLOW}⚠${NC} Consider adding descriptive suffix (-manager, -creator, -handler, -director)"
            WARNINGS=$((WARNINGS + 1))
        fi
        ;;

    skill)
        echo "Checking skill naming conventions..."
        echo ""

        # Rule 1: Lowercase with hyphens only
        if [[ ! "$ARTIFACT_NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
            echo -e "${RED}❌${NC} Must use lowercase letters, numbers, and hyphens only"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "${GREEN}✅${NC} Uses lowercase and hyphens"
        fi

        # Rule 2: Must start with letter
        if [[ ! "$ARTIFACT_NAME" =~ ^[a-z] ]]; then
            echo -e "${RED}❌${NC} Must start with a letter"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "${GREEN}✅${NC} Starts with letter"
        fi

        # Rule 3: No consecutive hyphens
        if [[ "$ARTIFACT_NAME" =~ -- ]]; then
            echo -e "${RED}❌${NC} Contains consecutive hyphens"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "${GREEN}✅${NC} No consecutive hyphens"
        fi

        # Rule 4: Length check (3-50 characters)
        length=${#ARTIFACT_NAME}
        if [ $length -lt 3 ] || [ $length -gt 50 ]; then
            echo -e "${RED}❌${NC} Length must be 3-50 characters (current: $length)"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "${GREEN}✅${NC} Length is valid ($length characters)"
        fi

        # Rule 5: Handler skills should have "handler-" prefix
        if [[ "$ARTIFACT_NAME" =~ ^handler- ]]; then
            echo -e "${GREEN}✅${NC} Handler skill with proper prefix"
            # Should follow handler-{type}-{provider} pattern
            if [[ ! "$ARTIFACT_NAME" =~ ^handler-[a-z]+-[a-z]+$ ]]; then
                echo -e "${YELLOW}⚠${NC} Handler should follow pattern: handler-{type}-{provider}"
                WARNINGS=$((WARNINGS + 1))
            fi
        fi
        ;;

    command)
        echo "Checking command naming conventions..."
        echo ""

        # Commands have format: plugin:subcommand
        if [[ ! "$ARTIFACT_NAME" =~ ^[a-z][a-z0-9-]+:[a-z][a-z0-9-]+$ ]]; then
            echo -e "${RED}❌${NC} Must follow format: plugin:subcommand (e.g., fractary-faber:run)"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "${GREEN}✅${NC} Follows plugin:subcommand format"
        fi

        # Extract plugin and subcommand
        if [[ "$ARTIFACT_NAME" =~ ^([^:]+):([^:]+)$ ]]; then
            plugin="${BASH_REMATCH[1]}"
            subcommand="${BASH_REMATCH[2]}"

            # Rule 1: Plugin should start with fractary-
            if [[ ! "$plugin" =~ ^fractary- ]]; then
                echo -e "${YELLOW}⚠${NC} Plugin should start with 'fractary-' prefix"
                WARNINGS=$((WARNINGS + 1))
            else
                echo -e "${GREEN}✅${NC} Plugin has fractary- prefix"
            fi

            # Rule 2: No consecutive hyphens in either part
            if [[ "$plugin" =~ -- ]] || [[ "$subcommand" =~ -- ]]; then
                echo -e "${RED}❌${NC} Contains consecutive hyphens"
                ERRORS=$((ERRORS + 1))
            else
                echo -e "${GREEN}✅${NC} No consecutive hyphens"
            fi

            # Rule 3: Length checks
            plugin_len=${#plugin}
            subcommand_len=${#subcommand}
            if [ $plugin_len -lt 3 ] || [ $plugin_len -gt 50 ]; then
                echo -e "${RED}❌${NC} Plugin name length must be 3-50 characters"
                ERRORS=$((ERRORS + 1))
            fi
            if [ $subcommand_len -lt 2 ] || [ $subcommand_len -gt 50 ]; then
                echo -e "${RED}❌${NC} Subcommand length must be 2-50 characters"
                ERRORS=$((ERRORS + 1))
            fi
        fi

        # Rule 4: No leading slash (commands in frontmatter don't have /)
        if [[ "$ARTIFACT_NAME" =~ ^/ ]]; then
            echo -e "${RED}❌${NC} Command name must NOT have leading slash in frontmatter"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "${GREEN}✅${NC} No leading slash (correct for frontmatter)"
        fi
        ;;

    plugin)
        echo "Checking plugin naming conventions..."
        echo ""

        # Rule 1: Must start with fractary-
        if [[ ! "$ARTIFACT_NAME" =~ ^fractary- ]]; then
            echo -e "${RED}❌${NC} Plugin name must start with 'fractary-'"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "${GREEN}✅${NC} Starts with fractary-"
        fi

        # Rule 2: Lowercase with hyphens only
        if [[ ! "$ARTIFACT_NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
            echo -e "${RED}❌${NC} Must use lowercase letters, numbers, and hyphens only"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "${GREEN}✅${NC} Uses lowercase and hyphens"
        fi

        # Rule 3: No consecutive hyphens
        if [[ "$ARTIFACT_NAME" =~ -- ]]; then
            echo -e "${RED}❌${NC} Contains consecutive hyphens"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "${GREEN}✅${NC} No consecutive hyphens"
        fi

        # Rule 4: Length check (10-50 characters including fractary- prefix)
        length=${#ARTIFACT_NAME}
        if [ $length -lt 10 ] || [ $length -gt 50 ]; then
            echo -e "${RED}❌${NC} Length must be 10-50 characters (current: $length)"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "${GREEN}✅${NC} Length is valid ($length characters)"
        fi

        # Rule 5: Check plugin type patterns
        if [[ "$ARTIFACT_NAME" =~ ^fractary-faber- ]]; then
            echo -e "${GREEN}✅${NC} Workflow plugin (fractary-faber-* pattern)"
        elif [[ "$ARTIFACT_NAME" =~ ^fractary-[a-z]+$ ]]; then
            echo -e "${GREEN}✅${NC} Primitive or utility plugin (fractary-{name} pattern)"
        else
            echo -e "${YELLOW}⚠${NC} Consider standard patterns: fractary-faber-{domain} or fractary-{primitive}"
            WARNINGS=$((WARNINGS + 1))
        fi
        ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

# Exit based on results
if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}FAILED${NC}: $ERRORS naming convention errors found"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}PASSED WITH WARNINGS${NC}: $WARNINGS naming suggestions"
    exit 0
else
    echo -e "${GREEN}PASSED${NC}: Name follows all conventions"
    exit 0
fi
