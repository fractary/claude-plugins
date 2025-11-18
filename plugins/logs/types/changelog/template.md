---
log_type: changelog
title: "{{title}}"
changelog_id: {{changelog_id}}
version: {{version}}
release_date: {{release_date}}
status: {{status}}
{{#compare_url}}
compare_url: {{compare_url}}
{{/compare_url}}
{{#contributors}}
contributors:
{{#contributors}}
  - {{.}}
{{/contributors}}
{{/contributors}}
---

# {{title}}

**Version**: `{{version}}`
**Release Date**: {{release_date}}
**Status**: {{status}}

{{#compare_url}}
**Compare**: [View changes]({{compare_url}})
{{/compare_url}}

---

## Summary

{{#notes}}
{{notes}}
{{/notes}}
{{^notes}}
This release includes the changes listed below.
{{/notes}}

---

{{#breaking_changes}}
## ⚠️ Breaking Changes

{{#breaking_changes}}
### {{description}}

{{#migration_notes}}
**Migration Notes**: {{migration_notes}}
{{/migration_notes}}

{{/breaking_changes}}

---

{{/breaking_changes}}
{{#changes.added}}
## ✨ Added

{{#changes.added}}
- {{.}}
{{/changes.added}}

{{/changes.added}}
{{#changes.changed}}
## 🔄 Changed

{{#changes.changed}}
- {{.}}
{{/changes.changed}}

{{/changes.changed}}
{{#changes.deprecated}}
## ⚠️ Deprecated

{{#changes.deprecated}}
- {{.}}
{{/changes.deprecated}}

{{/changes.deprecated}}
{{#changes.removed}}
## 🗑️ Removed

{{#changes.removed}}
- {{.}}
{{/changes.removed}}

{{/changes.removed}}
{{#changes.fixed}}
## 🐛 Fixed

{{#changes.fixed}}
- {{.}}
{{/changes.fixed}}

{{/changes.fixed}}
{{#changes.security}}
## 🔒 Security

{{#changes.security}}
- {{.}}
{{/changes.security}}

{{/changes.security}}
---

{{#work_items}}
## 📋 Related Work Items

{{#work_items}}
- **{{type}}** [#{{id}}]({{url}}): {{title}}
{{/work_items}}

{{/work_items}}
{{#contributors}}
## 👥 Contributors

{{#contributors}}
- {{.}}
{{/contributors}}

{{/contributors}}
---

**Log ID**: `{{changelog_id}}`
**Generated**: {{release_date}}
