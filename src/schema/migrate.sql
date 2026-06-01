-- arc-tree migration for {model}
-- Adds materialized path + depth columns and backfills from existing parentId data.
-- Placeholders: {model} is replaced with the actual table name at install time.

ALTER TABLE {model} ADD COLUMN IF NOT EXISTS path     TEXT    DEFAULT '';
ALTER TABLE {model} ADD COLUMN IF NOT EXISTS depth    INTEGER DEFAULT 0;
-- NOTE: SQLite silently ignores REFERENCES in ADD COLUMN; enforce FK integrity in application logic.
ALTER TABLE {model} ADD COLUMN IF NOT EXISTS parentId INTEGER REFERENCES {model}(id);

CREATE INDEX IF NOT EXISTS idx_{model}_path     ON {model}(path);
CREATE INDEX IF NOT EXISTS idx_{model}_parentid ON {model}(parentId);

-- Backfill existing rows in one O(n) recursive CTE pass.
-- Rows with no parent get path = CAST(id AS TEXT), depth = 0.
-- Child rows get path = parent.path || '/' || id, depth = parent.depth + 1.
WITH RECURSIVE _tree(id, path, depth) AS (
  SELECT id, CAST(id AS TEXT), 0
  FROM {model} WHERE parentId IS NULL
  UNION ALL
  SELECT m.id, t.path || '/' || m.id, t.depth + 1
  FROM {model} m JOIN _tree t ON m.parentId = t.id
)
UPDATE {model} SET
  path  = (SELECT path  FROM _tree WHERE _tree.id = {model}.id),
  depth = (SELECT depth FROM _tree WHERE _tree.id = {model}.id)
WHERE EXISTS (SELECT 1 FROM _tree WHERE _tree.id = {model}.id);

-- Clean up disconnected rows (parentId points to a deleted parent) that the CTE missed.
-- These would appear as ghost roots with path='' — reset them to standalone root nodes.
UPDATE {model} SET path = CAST(id AS TEXT), depth = 0
WHERE path IS NULL OR path = '';
