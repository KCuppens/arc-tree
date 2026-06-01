@group "/admin" @auth(admin, editor)

  # ── Shared move helper ────────────────────────────────────────────────────
  # Recomputes materialized path + depth for `nodeId` and all its descendants
  # after being re-parented to `newParentId` (null = root).
  # Returns { ok, path } on success or { error } on validation failure.
  # Callers pass the already-fetched node row and the full page list to avoid
  # redundant DB round-trips.
  @server fn _moveSubtree(nodeId: String, newParentId: String, node: Any, allRows: Any) -> Any
    if !node return { error: "not found" }

    const oldPath = node.path || nodeId
    let newPath   = nodeId

    if newParentId
      if newParentId == nodeId
        return { error: "A node cannot be its own parent" }
      const newParent = allRows.find(r => String(r.id) == newParentId)
      if !newParent return { error: "Parent not found" }
      const parentPath = newParent.path || newParentId
      if parentPath.startsWith(oldPath + "/") || parentPath == oldPath
        return { error: "Cannot move a node into its own subtree" }
      newPath = parentPath + "/" + nodeId

    const depthDelta = newPath.split("/").length - oldPath.split("/").length
    return { ok: true, oldPath: oldPath, newPath: newPath, depthDelta: depthDelta }

  # ── GET /admin/tree/:model ─────────────────────────────────────────────────
  # Returns all rows for the model ordered by materialized path (ASC).
  # Supports: pages, groups. Add more models as needed by extending the if chain.
  @get "/tree/:model"
    const model = request.params.model
    if model == "pages"
      return json(db.pages.findMany({ orderBy: { path: "asc" } }))
    if model == "groups"
      return json(db.groups.findMany({ orderBy: { path: "asc" } }))
    return json({ error: "Unsupported model" }, 400)

  # ── POST /admin/tree/:model/:id/move ──────────────────────────────────────
  # Body: { newParentId: string | null }
  # Moves the node and all its descendants to the new parent in O(k) updates,
  # where k is the subtree size. Validates cycles before touching the DB.
  @post "/tree/:model/:id/move"
    const model       = request.params.model
    const nodeIdRaw   = request.params.id
    const nodeId      = parseInt(nodeIdRaw)
    if isNaN(nodeId)
      return json({ error: "Invalid node id" }, 422)

    const body        = parseBody(request) || {}
    const newParentId = body.newParentId ? String(body.newParentId) : null
    if newParentId && !/^\d+$/.test(newParentId)
      return json({ error: "Invalid parent id" }, 422)

    if model == "pages"
      const allRows = db.pages.findMany({})
      const node    = allRows.find(r => String(r.id) == String(nodeId))
      const plan    = _moveSubtree(String(nodeId), newParentId, node, allRows)
      if plan.error return json({ error: plan.error }, 422)
      if !plan.oldPath return json({ error: "Node has no path — run arc cms add tree to backfill" }, 500)

      const subtree = allRows.filter(r => r.path == plan.oldPath || (r.path || "").startsWith(plan.oldPath + "/"))
      db.transaction(() => {
        subtree.forEach(row => {
          const np = plan.newPath + (row.path || "").slice(plan.oldPath.length)
          const nd = Math.max(0, (row.depth || 0) + plan.depthDelta)
          db.pages.update(row.id, {
            path:     np,
            depth:    nd,
            parentId: String(row.id) == String(nodeId) ? (newParentId ? parseInt(newParentId) : null) : row.parentId
          })
        })
      })

      db.auditlogs.create({
        actorId: session.userId, action: "update", entityType: "Page",
        entityId: String(nodeId),
        after: JSON.stringify({ path: plan.newPath, parentId: newParentId ?? null })
      })
      return json({ ok: true, path: plan.newPath })

    if model == "groups"
      const allRows = db.groups.findMany({})
      const node    = allRows.find(r => String(r.id) == String(nodeId))
      const plan    = _moveSubtree(String(nodeId), newParentId, node, allRows)
      if plan.error return json({ error: plan.error }, 422)
      if !plan.oldPath return json({ error: "Node has no path — run arc cms add tree to backfill" }, 500)

      const subtree = allRows.filter(r => r.path == plan.oldPath || (r.path || "").startsWith(plan.oldPath + "/"))
      db.transaction(() => {
        subtree.forEach(row => {
          const np = plan.newPath + (row.path || "").slice(plan.oldPath.length)
          const nd = Math.max(0, (row.depth || 0) + plan.depthDelta)
          db.groups.update(row.id, {
            path:     np,
            depth:    nd,
            parentId: String(row.id) == String(nodeId) ? (newParentId ? parseInt(newParentId) : null) : row.parentId
          })
        })
      })

      db.auditlogs.create({
        actorId: session.userId, action: "update", entityType: "Group",
        entityId: String(nodeId),
        after: JSON.stringify({ path: plan.newPath, parentId: newParentId ?? null })
      })
      return json({ ok: true, path: plan.newPath })

    return json({ error: "Unsupported model" }, 400)
