#!/bin/bash
# Work Common: Markdown to ADF Converter
# Converts markdown text to Atlassian Document Format (ADF) JSON for Jira

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <markdown_text>" >&2
    echo "  Converts markdown to ADF JSON for Jira API" >&2
    exit 2
fi

MARKDOWN="$1"

# For MVP: Simple conversion handling common markdown patterns
# This handles the most common cases for FABER workflows

# Escape JSON strings properly
escape_json() {
    local text="$1"
    # Escape backslashes first, then quotes, newlines, tabs
    text="${text//\\/\\\\}"
    text="${text//\"/\\\"}"
    text="${text//$'\n'/\\n}"
    text="${text//$'\t'/\\t}"
    echo "$text"
}

# Convert simple markdown paragraph to ADF
# For MVP, we'll create a basic ADF structure with paragraphs
# Advanced features (headings, lists, formatting) can be added incrementally

# Check if markdown is empty
if [ -z "$MARKDOWN" ]; then
    # Empty ADF document
    cat <<'EOF'
{
  "type": "doc",
  "version": 1,
  "content": []
}
EOF
    exit 0
fi

# For MVP: Convert to simple paragraphs
# Split on double newlines for paragraphs
# Convert **bold** and *italic* inline
# This covers 80% of FABER use cases

# Escape the markdown text for JSON
ESCAPED_TEXT=$(escape_json "$MARKDOWN")

# Build basic ADF with paragraphs
# Split on double newlines, create paragraph for each
# For now, treat each line as a paragraph (simple approach)

# Use Python for more robust markdown→ADF conversion
# Fall back to simple text if python not available
if command -v python3 &> /dev/null; then
    python3 << 'PYTHON_SCRIPT'
import json
import re
import sys

def markdown_to_adf(markdown):
    """Convert markdown to ADF JSON (MVP version)"""

    doc = {
        "type": "doc",
        "version": 1,
        "content": []
    }

    if not markdown.strip():
        return doc

    # Split into paragraphs (double newline)
    paragraphs = re.split(r'\n\n+', markdown.strip())

    for para in paragraphs:
        if not para.strip():
            continue

        # Check for heading
        heading_match = re.match(r'^(#{1,6})\s+(.+)$', para)
        if heading_match:
            level = len(heading_match.group(1))
            text = heading_match.group(2)
            doc["content"].append({
                "type": "heading",
                "attrs": {"level": min(level, 6)},
                "content": parse_inline(text)
            })
            continue

        # Check for bullet list
        if re.match(r'^\s*[-*]\s+', para):
            list_items = []
            for line in para.split('\n'):
                if re.match(r'^\s*[-*]\s+', line):
                    text = re.sub(r'^\s*[-*]\s+', '', line)
                    list_items.append({
                        "type": "listItem",
                        "content": [{
                            "type": "paragraph",
                            "content": parse_inline(text)
                        }]
                    })
            doc["content"].append({
                "type": "bulletList",
                "content": list_items
            })
            continue

        # Check for numbered list
        if re.match(r'^\s*\d+\.\s+', para):
            list_items = []
            for line in para.split('\n'):
                if re.match(r'^\s*\d+\.\s+', line):
                    text = re.sub(r'^\s*\d+\.\s+', '', line)
                    list_items.append({
                        "type": "listItem",
                        "content": [{
                            "type": "paragraph",
                            "content": parse_inline(text)
                        }]
                    })
            doc["content"].append({
                "type": "orderedList",
                "content": list_items
            })
            continue

        # Check for code block
        if para.startswith('```'):
            code_match = re.match(r'^```(\w*)\n(.*?)\n?```$', para, re.DOTALL)
            if code_match:
                language = code_match.group(1) or 'plain'
                code = code_match.group(2)
                doc["content"].append({
                    "type": "codeBlock",
                    "attrs": {"language": language},
                    "content": [{
                        "type": "text",
                        "text": code
                    }]
                })
                continue

        # Regular paragraph with inline formatting
        doc["content"].append({
            "type": "paragraph",
            "content": parse_inline(para)
        })

    return doc

def parse_inline(text):
    """Parse inline markdown (bold, italic, links, code)"""
    content = []

    # Simple token-based parsing
    # This is MVP - proper markdown parser would be better

    # For now, convert **bold** and *italic* and [links](url)
    # Split by markdown patterns and build ADF nodes

    # Simple approach: treat whole text as text node with marks
    # Advanced parsing can be added later

    # Pattern: **bold**, *italic*, `code`, [link](url)
    parts = []
    current_pos = 0

    # Combined pattern for all inline elements
    pattern = r'(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`|\[([^\]]+)\]\(([^)]+)\))'

    for match in re.finditer(pattern, text):
        # Add text before match
        if match.start() > current_pos:
            plain_text = text[current_pos:match.start()]
            if plain_text:
                parts.append({"type": "text", "text": plain_text})

        matched = match.group(1)

        # Bold
        if matched.startswith('**') and matched.endswith('**'):
            parts.append({
                "type": "text",
                "text": matched[2:-2],
                "marks": [{"type": "strong"}]
            })
        # Italic
        elif matched.startswith('*') and matched.endswith('*'):
            parts.append({
                "type": "text",
                "text": matched[1:-1],
                "marks": [{"type": "em"}]
            })
        # Code
        elif matched.startswith('`') and matched.endswith('`'):
            parts.append({
                "type": "text",
                "text": matched[1:-1],
                "marks": [{"type": "code"}]
            })
        # Link
        elif matched.startswith('['):
            link_text = match.group(2)
            link_url = match.group(3)
            parts.append({
                "type": "text",
                "text": link_text,
                "marks": [{"type": "link", "attrs": {"href": link_url}}]
            })

        current_pos = match.end()

    # Add remaining text
    if current_pos < len(text):
        remaining = text[current_pos:]
        if remaining:
            parts.append({"type": "text", "text": remaining})

    # If no parts, return plain text
    if not parts:
        return [{"type": "text", "text": text}]

    return parts

# Read markdown from stdin or argument
markdown = sys.stdin.read() if not sys.stdin.isatty() else '''$ESCAPED_TEXT'''

# Convert and output
adf = markdown_to_adf(markdown)
print(json.dumps(adf, indent=2))
PYTHON_SCRIPT
else
    # Fallback: Simple text-only ADF (no python available)
    cat <<EOF
{
  "type": "doc",
  "version": 1,
  "content": [
    {
      "type": "paragraph",
      "content": [
        {
          "type": "text",
          "text": "$ESCAPED_TEXT"
        }
      ]
    }
  ]
}
EOF
fi

exit 0
