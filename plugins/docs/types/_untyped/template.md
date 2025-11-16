---
title: "{{title}}"
fractary_doc_type: _untyped
status: {{status}}
version: {{version}}
created: {{created}}
updated: {{updated}}
author: {{author}}
tags: {{#tags}}{{.}}, {{/tags}}
codex_sync: true
generated: true
---

# {{title}}

{{description}}

{{#sections}}
## {{section_title}}

{{section_content}}

{{/sections}}

---

*Generated with fractary-docs plugin*
