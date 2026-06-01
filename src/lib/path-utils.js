'use strict'

/**
 * Computes the new materialized path for a node being re-parented.
 * Pure function — no DB access, fully testable.
 *
 * @param {string}      nodeId      — ID of the node being moved (string)
 * @param {string|null} newParentId — ID of the new parent, or null for root
 * @param {object|null} node        — the row for nodeId (must have .path)
 * @param {object[]}    allRows     — all rows in the model (.id and .path required)
 * @returns {{ ok: true, oldPath: string, newPath: string, depthDelta: number }
 *          | { error: string }}
 */
function computeMove(nodeId, newParentId, node, allRows) {
  if (!node) return { error: 'not found' }

  const oldPath = node.path || String(nodeId)
  let newPath   = String(nodeId)

  if (newParentId) {
    if (String(newParentId) === String(nodeId)) {
      return { error: 'A node cannot be its own parent' }
    }
    const newParent = allRows.find(r => String(r.id) === String(newParentId))
    if (!newParent) return { error: 'Parent not found' }
    const parentPath = newParent.path || String(newParentId)
    if (parentPath.startsWith(oldPath + '/') || parentPath === oldPath) {
      return { error: 'Cannot move a node into its own subtree' }
    }
    newPath = parentPath + '/' + String(nodeId)
  }

  const depthDelta = newPath.split('/').length - oldPath.split('/').length
  return { ok: true, oldPath, newPath, depthDelta }
}

/**
 * Returns the subset of rows that belong to the subtree rooted at oldPath.
 * Includes the node itself and all descendants.
 *
 * @param {object[]} allRows — all rows (must have .path)
 * @param {string}   oldPath — materialized path of the subtree root
 * @returns {object[]}
 */
function subtreeRows(allRows, oldPath) {
  return allRows.filter(r =>
    r.path === oldPath || (r.path || '').startsWith(oldPath + '/')
  )
}

/**
 * Remaps a single row's path after its subtree root has been moved.
 * Strips oldPath prefix and replaces with newPath.
 *
 * @param {string} rowPath — the row's current path
 * @param {string} oldPath — old root path of the moved subtree
 * @param {string} newPath — new root path of the moved subtree
 * @returns {string}
 */
function remapPath(rowPath, oldPath, newPath) {
  return newPath + rowPath.slice(oldPath.length)
}

module.exports = { computeMove, subtreeRows, remapPath }
