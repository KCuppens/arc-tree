# arc-tree

[![CI](https://github.com/KCuppens/arc-tree/actions/workflows/ci.yml/badge.svg)](https://github.com/KCuppens/arc-tree/actions/workflows/ci.yml)
[![npm](https://img.shields.io/npm/v/arc-tree)](https://www.npmjs.com/package/arc-tree)
[![license](https://img.shields.io/npm/l/arc-tree)](LICENSE)

Tree-view mixin for [Arc](https://arc-lang.com) CMS projects. Adds collapsible, drag-and-drop hierarchy to any CMS entity (pages, groups, or custom models) using a **materialized path** strategy — one SQL index, O(log n + k) subtree reads, no recursive CTEs at runtime.

```
/admin/pages  →  Tree view                 List view
               ▼ About                     Title         Slug      Status
                 ▶ Team                    Home          /p/home   live
                   └ Alice                 About         /p/about  live
                 ▶ Services               Services      /p/…       draft
               ─ Contact                  Contact       /p/…       live
```

## Features

- **Collapsible tree** — expand/collapse subtrees; state is local, zero server round-trips
- **Drag and drop** — move any node to a new parent; cycle detection prevents invalid moves
- **Keyboard navigation** — Arrow keys move focus; Space/Enter toggle expand; fully accessible
- **ARIA treegrid** — `role="treegrid"`, `aria-level`, `aria-expanded` on every node
- **Breadcrumb** — edit pages show the full ancestor path derived from the stored `path` column (zero extra queries)
- **Parent picker** — indented `<select>` with descendant exclusion to prevent cycles
- **Path auto-sync** — changing a page's parent via the edit form cascades `path`/`depth` to all descendants
- **Zero runtime dependencies** — vanilla JS, no external libraries

## Install

```bash
npm install arc-tree
arc cms add tree          # updates arc.config.json + runs DB migration
```

The `arc cms add tree` command:
1. Adds `"arc-tree"` to `packages` in `arc.config.json`
2. Adds `path TEXT`, `depth INTEGER` columns to each configured model
3. Creates B-tree indexes on `path` and `parentId`
4. Backfills existing rows using a single recursive CTE

## Configuration

```json5
// arc.config.json
{
  "packages": ["arc-cms", "arc-tree"],
  "tree": {
    "models": ["pages", "groups"]   // tables to receive path + depth columns
  }
}
```

## Storage model

arc-tree uses **adjacency list + materialized path** — the best balance of read performance, write safety, and debuggability for SQLite CMS workloads:

| Field     | Type            | Description                                     |
|-----------|-----------------|--------------------------------------------------|
| `parentId`| INTEGER nullable| Direct parent FK (already exists on `pages`)    |
| `path`    | TEXT            | `"1/5/12"` — ancestor IDs root → self           |
| `depth`   | INTEGER         | 0 = root, 1 = first child, etc.                 |

### Why not MPTT (django-mptt style)?

| Criterion         | Materialized path | MPTT (lft/rght) |
|-------------------|:-----------------:|:---------------:|
| Read subtree      | O(log n + k) ✓    | O(log n + k) ✓  |
| Move node         | O(k) ✓            | O(n) ✗          |
| Concurrent writes | Safe ✓            | Table lock ✗    |
| Human-readable    | Yes ✓             | No ✗            |
| SQLite friendly   | Yes ✓             | Partial ✗       |

## API routes

The package registers two routes under `/admin` (requires `admin` or `editor` role):

### `GET /admin/tree/:model`

Returns all rows ordered by `path ASC`. Feed directly into `CmsTreeTable`.

```json
[
  { "id": 1, "parentId": null, "path": "1",   "depth": 0, "title": "Home", ... },
  { "id": 3, "parentId": 1,   "path": "1/3", "depth": 1, "title": "About", ... }
]
```

### `POST /admin/tree/:model/:id/move`

Body: `{ "newParentId": "3" }` — pass `null` to promote to root.

Validates:
- Node exists
- `newParentId` is not the node itself
- `newParentId` is not a descendant of the node (cycle detection)

Returns `{ "ok": true, "path": "1/3/5" }` or `{ "error": "..." }` with 4xx status.

## Widgets

### `CmsTreeTable`

Drop-in for any CMS list page. Import and replace the inline `<table>`.

```arc
import CmsTreeTable from "@arc-tree/widgets/CmsTreeTable.arc"
```

**Props:**

| Prop         | Type    | Default | Description                                        |
|--------------|---------|---------|-----------------------------------------------------|
| `rows`       | Any     | —       | Flat row array with `id`, `parentId`, `depth`, `label` |
| `entityUrl`  | String  | —       | Base URL for Edit buttons (e.g. `/admin/pages`)    |
| `moveUrl`    | String  | `""`    | POST endpoint for drag-drop; `""` = read-only      |
| `col2Header` | String  | `""`    | Column 2 header; omit to show only the name column |
| `draggable`  | Bool    | `true`  | Set `false` to force read-only regardless of `moveUrl` |

**Row shape:**

```js
{
  id:        number | string,
  parentId:  number | string | null,
  depth:     number,          // 0-based
  label:     string,          // primary display text
  secondary: string,          // optional: shown as muted text in col 2
  badge:     string,          // optional: shown as a tag chip in col 2
}
```

**Example — pages list:**

```arc
@server fn listPagesTree() -> Any
  const rows = db.pages.findMany({ orderBy: { path: "asc" } })
  return rows.map(p => ({
    id:        p.id,
    parentId:  p.parentId,
    depth:     p.depth ?? 0,
    label:     p.title,
    secondary: "/p/" + p.slug,
    badge:     p.published ? "live" : "draft"
  }))

@live const treeRows = listPagesTree()

CmsTreeTable
  rows=treeRows
  entityUrl="/admin/pages"
  moveUrl="/admin/tree/pages"
  col2Header="Slug / Status"
```

### `CmsParentPicker`

Indented `<select>` for the parent field on edit pages. Automatically excludes the current node and its descendants.

```arc
import CmsParentPicker from "@arc-tree/widgets/CmsParentPicker.arc"
```

**Props:**

| Prop         | Type   | Default | Description                                              |
|--------------|--------|---------|----------------------------------------------------------|
| `name`       | String | —       | `@state` variable name to bind (use `bind:value="{name}"`) |
| `options`    | Any    | —       | Flat array with `{ id, depth, label }`                  |
| `excludeIds` | Any    | `[]`    | String array of IDs to hide (self + descendants)         |

**Server-side options builder:**

```arc
const parentOptions = allPages
  .filter(p => p.id != parseInt(pageId))
  .map(p => ({
    id:    p.id,
    depth: p.depth ?? 0,
    label: "—".repeat(p.depth ?? 0) + " " + p.title
  }))
```

**Usage:**

```arc
@state let parentId = data.page.parentId ? String(data.page.parentId) : ""

CmsParentPicker
  name="parentId"
  options=data.parentOptions
  excludeIds=data.descendantIds
```

## Adding a new model

1. Add the model name to `"tree.models"` in `arc.config.json`
2. Run `arc cms add tree` again to migrate the new table
3. Add `GET /admin/tree/mymodel` and `POST /admin/tree/mymodel/:id/move` to `tree.arc` (follow the existing `pages` pattern)
4. Use `CmsTreeTable` + `CmsParentPicker` in your list and edit pages

## Keyboard shortcuts

| Key            | Action                             |
|----------------|------------------------------------|
| `↑` / `↓`     | Move focus to previous / next row  |
| `→`            | Expand focused node                |
| `←`            | Collapse focused node (or jump to parent) |
| `Space`/`Enter`| Toggle expand/collapse             |

## Performance

| Operation          | Complexity   | Notes                                          |
|--------------------|:------------:|------------------------------------------------|
| `GET /tree/:model` | O(n)         | Single `SELECT * ORDER BY path` scan           |
| `POST .../move`    | O(k)         | k = subtree size; one DB call per affected row |
| Expand / collapse  | O(1)         | Pure client-side `Set` toggle, no re-fetch     |
| Ancestor breadcrumb| O(d)         | Split stored path string — zero DB queries     |
| Migration backfill | O(n)         | One recursive CTE pass at install time         |

Path strings stay compact: `≤ 70 chars` at depth 10 with 6-digit IDs.

## Theming

The widgets use CSS custom properties from the Arc CMS design system:

```css
--brand-from      /* accent colour (focus rings, drop targets) */
--ui-fg           /* primary text */
--ui-fg-2         /* secondary text */
--ui-fg-3         /* muted / placeholder text */
--ui-bg-2         /* card background */
--ui-bg-3         /* hover background */
--ui-border       /* border colour */
```

Override any of these on `:root` or a scoped selector to theme the tree.

## License

MIT © arc-tree contributors
