@group "/admin" @auth(admin, editor)

  # ── GET /admin/tree/:model ────────────────────────────────────────────────
  # Returns all rows ordered by materialized path (ASC) for the given model.
  @get "/tree/:model"
    const model  = request.params.model
    const MODELS = { pages: true, groups: true }
    if !MODELS[model] return json({ error: "Unsupported model" }, 400)
    return json(db[model].findMany({ orderBy: { path: "asc" } }))

  # ── POST /admin/tree/:model/:id/move ──────────────────────────────────────
  # Body: { newParentId: string | null }
  # Moves the node and all its descendants to the new parent in O(k) updates,
  # where k is the subtree size. Validates cycles before touching the DB.
  @post "/tree/:model/:id/move"
    const model        = request.params.model
    const ENTITY_TYPES = { pages: "Page", groups: "Group" }
    if !ENTITY_TYPES[model] return json({ error: "Unsupported model" }, 400)

    const nodeId = parseInt(request.params.id)
    if isNaN(nodeId)
      return json({ error: "Invalid node id" }, 422)

    const body        = parseBody(request) || {}
    const newParentId = body.newParentId ? String(body.newParentId) : null
    if newParentId && !/^\d+$/.test(newParentId)
      return json({ error: "Invalid parent id" }, 422)

    const { computeMove, subtreeRows, remapPath } = require('../lib/path-utils')
    const dbTable    = db[model]
    const entityType = ENTITY_TYPES[model]
    const allRows    = dbTable.findMany({})
    const node       = allRows.find(r => String(r.id) == String(nodeId))
    const plan       = computeMove(String(nodeId), newParentId, node, allRows)
    if plan.error return json({ error: plan.error }, 422)
    if !plan.oldPath return json({ error: "Node has no path — run arc cms add tree to backfill" }, 500)

    db.transaction(() => {
      subtreeRows(allRows, plan.oldPath).forEach(row => {
        const newPath         = remapPath(row.path || "", plan.oldPath, plan.newPath)
        const newDepth        = Math.max(0, (row.depth || 0) + plan.depthDelta)
        const updatedParentId = String(row.id) == String(nodeId) ? (newParentId ? parseInt(newParentId) : null) : row.parentId
        dbTable.update(row.id, { path: newPath, depth: newDepth, parentId: updatedParentId })
      })
    })

    db.auditlogs.create({
      actorId: session.userId, action: "update", entityType: entityType,
      entityId: String(nodeId),
      after: JSON.stringify({ path: plan.newPath, parentId: newParentId ?? null })
    })
    return json({ ok: true, path: plan.newPath })
