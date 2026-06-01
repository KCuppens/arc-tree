/**
 * arc-tree — type declarations for the arc-tree package.
 *
 * These types document the shape of data passed to arc-tree widgets
 * and the structure of API responses. Arc itself is not TypeScript,
 * but these types are useful when building typed wrappers or tests.
 */

/** A single node in the tree, as returned by GET /admin/tree/:model */
export interface TreeRow {
  /** Unique identifier */
  id: number | string;
  /** Parent node id, or null for root nodes */
  parentId: number | string | null;
  /** Materialized path string — ancestor IDs joined by "/" (e.g. "1/5/12") */
  path: string;
  /** Zero-based nesting depth (0 = root) */
  depth: number;
  /** Any additional model fields are passed through */
  [key: string]: unknown;
}

/** Row shape expected by the CmsTreeTable widget */
export interface TreeTableRow {
  id: number | string;
  parentId: number | string | null;
  depth: number;
  /** Primary label displayed in the Name column */
  label: string;
  /** Optional muted text shown in column 2 */
  secondary?: string;
  /** Optional badge/tag shown in column 2 */
  badge?: string;
}

/** Row shape expected by the CmsParentPicker widget */
export interface ParentPickerOption {
  id: number | string;
  depth: number;
  /** Display label — must include "—".repeat(depth) prefix for visual indentation */
  label: string;
}

/** Successful response from POST /admin/tree/:model/:id/move */
export interface MoveResponse {
  ok: true;
  /** New materialized path of the moved node */
  path: string;
}

/** Error response from any tree route */
export interface TreeErrorResponse {
  error: string;
}

/** arc.config.json "tree" configuration block */
export interface ArcTreeConfig {
  /**
   * Model/table names to enable tree support on.
   * @default ["pages"]
   */
  models: string[];
}

/** Package metadata exported from src/index.js */
export interface ArcTreePackage {
  serverDir: string;
  serverRoutes: string[];
  widgetsDir: string;
  version: string;
}
