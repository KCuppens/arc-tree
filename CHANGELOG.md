# Changelog

All notable changes to arc-tree will be documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning: [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

<!-- Describe changes here as they land, before the next release tag -->

---

## [0.1.0] — 2026-05-31

### Added
- `CmsTreeTable` widget — collapsible, drag-and-drop tree table for CMS list pages
- `CmsParentPicker` widget — indented `<select>` with cycle-safe descendant exclusion
- `GET /admin/tree/:model` — returns all rows ordered by materialized path
- `POST /admin/tree/:model/:id/move` — moves a node + subtree with cycle detection
- `arc cms add tree` CLI command — installs package, runs DB migration, backfills existing rows
- Materialized path migration (`path TEXT`, `depth INTEGER`) with B-tree indexes
- One-pass recursive CTE backfill for existing data
- Full keyboard navigation: Arrow keys, Space/Enter to expand/collapse
- ARIA treegrid semantics (`role="treegrid"`, `aria-level`, `aria-expanded`)
- Error toast for failed move operations
- Loading state (`arc-tree--moving`) during API calls
- Breadcrumb path on edit pages — derived from stored `path`, zero extra queries
- Path cascade: changing `parentId` in the edit form updates `path`/`depth` for the whole subtree
- Delete cascade: re-homed children get correct `path`/`depth` after parent deletion
- TypeScript type declarations in `src/types.d.ts`
