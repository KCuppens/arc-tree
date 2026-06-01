'use strict'
const { test } = require('node:test')
const assert = require('node:assert/strict')
const { DatabaseSync } = require('node:sqlite')
const fs = require('node:fs')
const path = require('node:path')

const TEMPLATE = fs.readFileSync(
  path.join(__dirname, '../src/schema/migrate.sql'),
  'utf8'
)

/** Apply the migration template to an in-memory SQLite DB */
function applyMigration(db, model) {
  let sql = TEMPLATE.replace(/{model}/g, model)
  // node:sqlite's bundled SQLite parser doesn't support "ADD COLUMN IF NOT EXISTS".
  // Strip it and rely on the duplicate-column error catch below for idempotency.
  sql = sql.replace(/\bADD COLUMN IF NOT EXISTS\b/gi, 'ADD COLUMN')
  // Strip comment-only lines so empty chunks don't cause issues
  const stripped = sql.split('\n')
    .filter(line => !line.trim().startsWith('--'))
    .join('\n')
  const stmts = stripped.split(';').map(s => s.trim()).filter(s => s.length > 0)
  for (const stmt of stmts) {
    try {
      db.exec(stmt)
    } catch (e) {
      // Idempotency: ignore "already exists" and "duplicate column" errors
      if (!e.message.includes('already exists') && !e.message.includes('duplicate column')) {
        throw e
      }
    }
  }
}

test('migration — adds path, depth, and parentId columns', () => {
  const db = new DatabaseSync(':memory:')
  db.exec('CREATE TABLE pages (id INTEGER PRIMARY KEY, title TEXT)')
  applyMigration(db, 'pages')
  const cols = db.prepare('PRAGMA table_info(pages)').all().map(c => c.name)
  assert.ok(cols.includes('path'),     'path column added')
  assert.ok(cols.includes('depth'),    'depth column added')
  assert.ok(cols.includes('parentId'), 'parentId column added')
})

test('migration — creates path and parentId indexes', () => {
  const db = new DatabaseSync(':memory:')
  db.exec('CREATE TABLE pages (id INTEGER PRIMARY KEY, title TEXT)')
  applyMigration(db, 'pages')
  const names = db.prepare(
    "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='pages'"
  ).all().map(i => i.name)
  assert.ok(names.includes('idx_pages_path'),     'path index created')
  assert.ok(names.includes('idx_pages_parentid'), 'parentId index created')
})

test('migration — backfills single root node', () => {
  const db = new DatabaseSync(':memory:')
  db.exec('CREATE TABLE pages (id INTEGER PRIMARY KEY, title TEXT, parentId INTEGER)')
  db.exec("INSERT INTO pages VALUES (1, 'Home', NULL)")
  applyMigration(db, 'pages')
  const row = db.prepare('SELECT path, depth FROM pages WHERE id = 1').get()
  assert.equal(row.path, '1')
  assert.equal(row.depth, 0)
})

test('migration — backfills two-level hierarchy', () => {
  const db = new DatabaseSync(':memory:')
  db.exec('CREATE TABLE pages (id INTEGER PRIMARY KEY, title TEXT, parentId INTEGER)')
  db.exec("INSERT INTO pages VALUES (1, 'Home', NULL), (2, 'About', 1), (3, 'Contact', 1)")
  applyMigration(db, 'pages')
  const about   = db.prepare('SELECT path, depth FROM pages WHERE id = 2').get()
  const contact = db.prepare('SELECT path, depth FROM pages WHERE id = 3').get()
  assert.equal(about.path,   '1/2'); assert.equal(about.depth,   1)
  assert.equal(contact.path, '1/3'); assert.equal(contact.depth, 1)
})

test('migration — backfills three levels of nesting', () => {
  const db = new DatabaseSync(':memory:')
  db.exec('CREATE TABLE pages (id INTEGER PRIMARY KEY, title TEXT, parentId INTEGER)')
  db.exec("INSERT INTO pages VALUES (1, 'Root', NULL), (2, 'Child', 1), (3, 'Grand', 2)")
  applyMigration(db, 'pages')
  const gc = db.prepare('SELECT path, depth FROM pages WHERE id = 3').get()
  assert.equal(gc.path, '1/2/3')
  assert.equal(gc.depth, 2)
})

test('migration — multiple independent roots get standalone paths', () => {
  const db = new DatabaseSync(':memory:')
  db.exec('CREATE TABLE groups (id INTEGER PRIMARY KEY, name TEXT, parentId INTEGER)')
  db.exec("INSERT INTO groups VALUES (10, 'A', NULL), (20, 'B', NULL), (30, 'C', 10)")
  applyMigration(db, 'groups')
  const a = db.prepare('SELECT path FROM groups WHERE id = 10').get()
  const b = db.prepare('SELECT path FROM groups WHERE id = 20').get()
  const c = db.prepare('SELECT path FROM groups WHERE id = 30').get()
  assert.equal(a.path, '10')
  assert.equal(b.path, '20')
  assert.equal(c.path, '10/30')
})

test('migration — cleans up orphaned rows whose parentId points to deleted parent', () => {
  const db = new DatabaseSync(':memory:')
  // Pre-create table with columns already present (simulates re-run scenario)
  db.exec(`CREATE TABLE pages (
    id INTEGER PRIMARY KEY, title TEXT,
    parentId INTEGER, path TEXT DEFAULT '', depth INTEGER DEFAULT 0
  )`)
  // Row 5 has parentId=999 (deleted parent) — CTE won't reach it
  db.exec("INSERT INTO pages VALUES (5, 'Orphan', 999, '', 0)")
  applyMigration(db, 'pages')
  const orphan = db.prepare('SELECT path, depth FROM pages WHERE id = 5').get()
  assert.equal(orphan.path, '5',  'orphan gets standalone root path')
  assert.equal(orphan.depth, 0,   'orphan gets depth=0')
})

test('migration — is idempotent (running twice does not corrupt data)', () => {
  const db = new DatabaseSync(':memory:')
  db.exec('CREATE TABLE pages (id INTEGER PRIMARY KEY, parentId INTEGER)')
  db.exec("INSERT INTO pages VALUES (1, NULL), (2, 1)")
  applyMigration(db, 'pages')
  // Second run
  assert.doesNotThrow(() => applyMigration(db, 'pages'))
  const rows = db.prepare('SELECT id, path, depth FROM pages ORDER BY id').all()
  assert.equal(rows[0].path, '1');   assert.equal(rows[0].depth, 0)
  assert.equal(rows[1].path, '1/2'); assert.equal(rows[1].depth, 1)
})

test('migration — handles empty table (no rows to backfill)', () => {
  const db = new DatabaseSync(':memory:')
  db.exec('CREATE TABLE pages (id INTEGER PRIMARY KEY)')
  assert.doesNotThrow(() => applyMigration(db, 'pages'))
})

test('migration — uses correct model name in indexes (groups vs pages)', () => {
  const db = new DatabaseSync(':memory:')
  db.exec('CREATE TABLE groups (id INTEGER PRIMARY KEY, parentId INTEGER)')
  applyMigration(db, 'groups')
  const names = db.prepare(
    "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='groups'"
  ).all().map(i => i.name)
  assert.ok(names.includes('idx_groups_path'),     'group path index uses correct name')
  assert.ok(names.includes('idx_groups_parentid'), 'group parentId index uses correct name')
})
