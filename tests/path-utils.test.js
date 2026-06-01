'use strict'
const { test } = require('node:test')
const assert = require('node:assert/strict')
const { computeMove, subtreeRows, remapPath } = require('../src/lib/path-utils')

// Sample tree used across tests:
//   1  (root, path="1",     depth=0)
//     3  (path="1/3",   depth=1)
//       7  (path="1/3/7", depth=2)
//     5  (path="1/5",   depth=1)
//   2  (root, path="2",     depth=0)
//     4  (path="2/4",   depth=1)
//  10  (root, path="10",    depth=0)  — tests no false prefix match with "1"

const ROWS = [
  { id: 1,  parentId: null, path: '1',     depth: 0 },
  { id: 2,  parentId: null, path: '2',     depth: 0 },
  { id: 3,  parentId: 1,   path: '1/3',   depth: 1 },
  { id: 4,  parentId: 2,   path: '2/4',   depth: 1 },
  { id: 5,  parentId: 1,   path: '1/5',   depth: 1 },
  { id: 7,  parentId: 3,   path: '1/3/7', depth: 2 },
  { id: 10, parentId: null, path: '10',    depth: 0 },
]

// ── computeMove: valid moves ────────────────────────────────────────────────

test('computeMove — move sibling to different parent (same depth)', () => {
  const result = computeMove('5', '2', ROWS.find(r => r.id === 5), ROWS)
  assert.equal(result.ok, true)
  assert.equal(result.oldPath, '1/5')
  assert.equal(result.newPath, '2/5')
  assert.equal(result.depthDelta, 0)
})

test('computeMove — promote node to root (newParentId=null)', () => {
  const result = computeMove('3', null, ROWS.find(r => r.id === 3), ROWS)
  assert.equal(result.ok, true)
  assert.equal(result.oldPath, '1/3')
  assert.equal(result.newPath, '3')
  assert.equal(result.depthDelta, -1)
})

test('computeMove — move node to deeper parent (+1 depth)', () => {
  const result = computeMove('5', '4', ROWS.find(r => r.id === 5), ROWS)
  assert.equal(result.ok, true)
  assert.equal(result.newPath, '2/4/5')
  assert.equal(result.depthDelta, 1)
})

test('computeMove — move root node under deep parent', () => {
  // 2 (depth=0) → under 7 (depth=2): newPath="1/3/7/2", depthDelta=+3
  const result = computeMove('2', '7', ROWS.find(r => r.id === 2), ROWS)
  assert.equal(result.ok, true)
  assert.equal(result.newPath, '1/3/7/2')
  assert.equal(result.depthDelta, 3)
})

test('computeMove — move root to root (same position, null→null)', () => {
  const result = computeMove('1', null, ROWS.find(r => r.id === 1), ROWS)
  assert.equal(result.ok, true)
  assert.equal(result.newPath, '1')
  assert.equal(result.depthDelta, 0)
})

test('computeMove — node with null path falls back to id string', () => {
  const noPath = { id: 5, parentId: 1, path: null, depth: 1 }
  const result = computeMove('5', null, noPath, ROWS)
  assert.equal(result.ok, true)
  assert.equal(result.oldPath, '5')
  assert.equal(result.newPath, '5')
  assert.equal(result.depthDelta, 0)
})

test('computeMove — node with empty path falls back to id string', () => {
  const emptyPath = { id: 5, parentId: 1, path: '', depth: 1 }
  const result = computeMove('5', '2', emptyPath, ROWS)
  assert.equal(result.ok, true)
  assert.equal(result.oldPath, '5')
})

// ── computeMove: cycle detection ────────────────────────────────────────────

test('computeMove — self-parent is rejected', () => {
  const result = computeMove('3', '3', ROWS.find(r => r.id === 3), ROWS)
  assert.ok(!result.ok)
  assert.equal(result.error, 'A node cannot be its own parent')
})

test('computeMove — direct descendant is rejected (node 3 → child 7)', () => {
  const result = computeMove('3', '7', ROWS.find(r => r.id === 3), ROWS)
  assert.ok(!result.ok)
  assert.match(result.error, /subtree/)
})

test('computeMove — deep descendant is rejected (root 1 → grandchild 7)', () => {
  const result = computeMove('1', '7', ROWS.find(r => r.id === 1), ROWS)
  assert.ok(!result.ok)
  assert.match(result.error, /subtree/)
})

test('computeMove — sibling with same numeric prefix is NOT rejected (1 vs 10)', () => {
  // Node 1 must NOT be considered an ancestor of node 10
  const result = computeMove('1', '10', ROWS.find(r => r.id === 1), ROWS)
  assert.equal(result.ok, true)
  assert.equal(result.newPath, '10/1')
})

// ── computeMove: missing data ────────────────────────────────────────────────

test('computeMove — null node returns not-found error', () => {
  const result = computeMove('99', '2', null, ROWS)
  assert.ok(!result.ok)
  assert.equal(result.error, 'not found')
})

test('computeMove — nonexistent parent returns error', () => {
  const result = computeMove('5', '99', ROWS.find(r => r.id === 5), ROWS)
  assert.ok(!result.ok)
  assert.equal(result.error, 'Parent not found')
})

// ── subtreeRows ──────────────────────────────────────────────────────────────

test('subtreeRows — returns node and all descendants', () => {
  const rows = subtreeRows(ROWS, '1/3')
  const ids = rows.map(r => r.id).sort((a, b) => a - b)
  assert.deepEqual(ids, [3, 7])
})

test('subtreeRows — root subtree includes all descendants', () => {
  const rows = subtreeRows(ROWS, '1')
  const ids = rows.map(r => r.id).sort((a, b) => a - b)
  assert.deepEqual(ids, [1, 3, 5, 7])
})

test('subtreeRows — leaf node returns only itself', () => {
  const rows = subtreeRows(ROWS, '1/5')
  assert.equal(rows.length, 1)
  assert.equal(rows[0].id, 5)
})

test('subtreeRows — does not match numeric prefix without slash ("1" vs "10")', () => {
  const rows = subtreeRows(ROWS, '1')
  const ids = rows.map(r => r.id)
  assert.ok(!ids.includes(10), 'node 10 must not be in subtree of node 1')
})

test('subtreeRows — row with null path is not included (null-safe)', () => {
  const rowsWithNull = [...ROWS, { id: 99, path: null, depth: 0 }]
  const rows = subtreeRows(rowsWithNull, '1')
  assert.ok(!rows.find(r => r.id === 99))
})

// ── remapPath ────────────────────────────────────────────────────────────────

test('remapPath — remap descendant path when subtree root moves', () => {
  // Subtree root 1/3 → 2/4/3; child 1/3/7 → 2/4/3/7
  assert.equal(remapPath('1/3/7', '1/3', '2/4/3'), '2/4/3/7')
})

test('remapPath — remap the node itself (rowPath === oldPath)', () => {
  assert.equal(remapPath('1/3', '1/3', '2/3'), '2/3')
})

test('remapPath — remap when promoted to root', () => {
  // 1/3 → 3 (promoted to root); child 1/3/7 → 3/7
  assert.equal(remapPath('1/3/7', '1/3', '3'), '3/7')
})

test('remapPath — remap when deepened by two levels', () => {
  // node 5 at "1/5" moved under "2/4" → "2/4/5"
  assert.equal(remapPath('1/5', '1/5', '2/4/5'), '2/4/5')
})
