# CmsTreeTable — tree-view replacement for flat CMS list tables.
#
# Each row object must have:
#   id         — unique identifier (number or string)
#   parentId   — parent id, or null/undefined for root nodes
#   depth      — 0-based nesting level (0 = root)
#   label      — primary display text (e.g. page title)
#
# Optional per-row fields:
#   secondary  — shown in column 2 as muted text (e.g. slug)
#   badge      — shown in column 2 as a tag chip (e.g. "draft", "live")
#
# Props:
#   rows       — flat sorted array from GET /admin/tree/:model
#   entityUrl  — base URL for Edit links (e.g. "/admin/pages")
#   moveUrl    — POST endpoint for drag-and-drop (e.g. "/admin/tree/pages")
#                omit or pass "" to disable drag-and-drop
#   col2Header — header label for the secondary column; omit to hide column
#   draggable  — set false to disable drag-and-drop even when moveUrl is set

widget CmsTreeTable(
  rows:       Any,
  entityUrl:  String,
  moveUrl:    String = "",
  col2Header: String = "",
  draggable:  Bool   = true,
  label:      String = "Content tree"
)

  col class="arc-tree-outer"
    col class="!table-wrap"
      table class="!table arc-tree-table"
        attr role="treegrid"
        attr aria-label="{label}"
        attr data-move-url="{moveUrl}"
        thead
          tr
            th attr scope="col" "Name"
            if col2Header != ""
              th attr scope="col" "{col2Header}"
            th attr scope="col" attr aria-label="Actions"
        tbody
          for row in rows
            tr class="arc-tree-row"
              attr role="row"
              attr aria-level="{row.depth + 1}"
              attr data-tree-id="{row.id}"
              attr data-tree-parent="{row.parentId}"
              attr data-tree-depth="{row.depth}"
              attr tabindex="0"
              td class="arc-tree-cell-label" attr role="gridcell"
                button class="arc-tree-toggle"
                  attr type="button"
                  attr aria-label="Expand"
                  attr data-toggle-id="{row.id}"
                  attr tabindex="-1"
                  "▶"
                span class="arc-tree-leaf-pad" attr aria-hidden="true"
                text class="arc-tree-label" "{row.label}"
              if col2Header != ""
                td attr role="gridcell"
                  if row.badge
                    text class="!badge arc-tree-badge" "{row.badge}"
                  if row.secondary
                    text class="arc-tree-secondary" "{row.secondary}"
              td class="arc-tree-actions" attr role="gridcell"
                link href="{entityUrl}/{row.id}" class="!btn !btn--ghost !btn--sm arc-tree-edit-link" attr tabindex="-1" "Edit"

  @raw '<script>
(function () {
  "use strict";

  document.querySelectorAll(".arc-tree-table").forEach(function (table) {
    var expanded   = new Set();
    var dragId     = null;
    var dropTarget = null;
    var isMoving   = false;
    var moveUrl    = table.dataset.moveUrl || "";

    /* ─── row cache — built once at init, avoids repeated querySelectorAll ─── */
    var rowList  = [];
    var rowMap   = {};
    var childIds = {};

    function buildCache() {
      rowList  = Array.from(table.querySelectorAll(".arc-tree-row"));
      rowMap   = {};
      childIds = {};
      rowList.forEach(function (tr) {
        var id  = String(tr.dataset.treeId);
        var pid = tr.dataset.treeParent ? String(tr.dataset.treeParent) : "";
        rowMap[id] = tr;
        if (pid) {
          if (!childIds[pid]) childIds[pid] = [];
          childIds[pid].push(id);
        }
      });
    }

    function rowById(id) { return rowMap[String(id)] || null; }
    function hasChildren(nodeId) { return !!(childIds[String(nodeId)] && childIds[String(nodeId)].length); }

    /* ─── O(n) linear visibility — rows are path-sorted so parent always precedes child ─── */
    function computeVisible() {
      var vis = {};
      rowList.forEach(function (tr) {
        var id  = String(tr.dataset.treeId);
        var pid = tr.dataset.treeParent ? String(tr.dataset.treeParent) : "";
        vis[id] = !pid || !!(vis[pid] && expanded.has(pid));
      });
      return vis;
    }

    /* ─── indentation + aria-setsize/posinset ─── */
    function applyLayout() {
      var sibCount = {};
      var sibIdx   = {};
      rowList.forEach(function (tr) {
        var id  = String(tr.dataset.treeId);
        var key = tr.dataset.treeParent ? String(tr.dataset.treeParent) : "__root__";
        sibCount[key] = (sibCount[key] || 0) + 1;
        sibIdx[id]    = sibCount[key];
      });

      rowList.forEach(function (tr) {
        var depth   = parseInt(tr.dataset.treeDepth) || 0;
        var nodeId  = String(tr.dataset.treeId);
        var key     = tr.dataset.treeParent ? String(tr.dataset.treeParent) : "__root__";
        var cell    = tr.querySelector(".arc-tree-cell-label");
        var toggle  = tr.querySelector(".arc-tree-toggle");
        var leafPad = tr.querySelector(".arc-tree-leaf-pad");
        var leaf    = !hasChildren(nodeId);

        if (cell)    cell.style.paddingLeft = (depth * 20 + 12) + "px";
        if (toggle)  { toggle.hidden = leaf; toggle.setAttribute("aria-label", expanded.has(nodeId) ? "Collapse" : "Expand"); }
        if (leafPad) leafPad.hidden = !leaf;

        tr.setAttribute("aria-setsize",  String(sibCount[key] || 1));
        tr.setAttribute("aria-posinset", String(sibIdx[nodeId] || 1));
      });
    }

    /* ─── refresh: show/hide rows + aria-expanded on both toggle and row ─── */
    function refresh() {
      var vis = computeVisible();
      rowList.forEach(function (tr) {
        var nodeId  = String(tr.dataset.treeId);
        tr.hidden   = !vis[nodeId];

        var open   = expanded.has(nodeId);
        var toggle = tr.querySelector(".arc-tree-toggle");
        if (toggle) {
          toggle.textContent = open ? "▼" : "▶";
          toggle.setAttribute("aria-expanded", String(open));
          toggle.setAttribute("aria-label", open ? "Collapse" : "Expand");
        }
        if (hasChildren(nodeId)) {
          tr.setAttribute("aria-expanded", String(open));
        } else {
          tr.removeAttribute("aria-expanded");
        }
      });
    }

    function toggleExpand(nodeId) {
      if (!hasChildren(nodeId)) return;
      expanded.has(nodeId) ? expanded.delete(nodeId) : expanded.add(nodeId);
      refresh();
    }

    /* ─── move via API ─── */
    function moveNode(fromId, toParentId) {
      if (!moveUrl || isMoving) return;
      isMoving = true;
      table.classList.add("arc-tree--moving");
      table.setAttribute("aria-busy", "true");
      fetch(moveUrl + "/" + fromId + "/move", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: "same-origin",
        body: JSON.stringify({ newParentId: toParentId })
      })
        .then(function (r) {
          if (!r.ok) throw new Error("HTTP " + r.status);
          return r.json();
        })
        .then(function (body) {
          if (body.error) {
            showToast(body.error, "error");
          } else {
            window.location.reload();
          }
        })
        .catch(function (err) { console.error("[arc-tree] moveNode failed:", err); showToast("Move failed — please try again", "error"); })
        .finally(function () {
          isMoving  = false;
          dragId    = null;
          table.classList.remove("arc-tree--moving");
          table.removeAttribute("aria-busy");
        });
    }

    function showToast(msg, type) {
      var el = document.createElement("div");
      el.className = "arc-tree-toast arc-tree-toast--" + (type || "info");
      el.setAttribute("role", "alert");
      el.textContent = msg;
      document.body.appendChild(el);
      setTimeout(function () { el.remove(); }, 4000);
    }

    /* ─── click: toggle expand ─── */
    table.addEventListener("click", function (e) {
      var toggle = e.target.closest(".arc-tree-toggle");
      if (!toggle) return;
      var tr = toggle.closest(".arc-tree-row");
      if (tr) toggleExpand(String(tr.dataset.treeId));
    });

    /* ─── keyboard: Space = toggle; Enter = toggle (parent) or edit (leaf); Arrows = navigate ─── */
    table.addEventListener("keydown", function (e) {
      var tr = e.target.closest(".arc-tree-row");
      if (!tr) return;
      var nodeId = String(tr.dataset.treeId);

      if (e.key === " ") {
        var toggle = tr.querySelector(".arc-tree-toggle");
        if (toggle && !toggle.hidden) { e.preventDefault(); toggleExpand(nodeId); }
        return;
      }

      if (e.key === "Enter") {
        e.preventDefault();
        var toggle = tr.querySelector(".arc-tree-toggle");
        if (toggle && !toggle.hidden) {
          toggleExpand(nodeId);
        } else {
          var editLink = tr.querySelector(".arc-tree-edit-link");
          if (editLink) editLink.click();
        }
        return;
      }

      var visible = rowList.filter(function (r) { return !r.hidden; });
      var idx     = visible.indexOf(tr);

      if (e.key === "ArrowDown") { e.preventDefault(); if (visible[idx + 1]) visible[idx + 1].focus(); }
      if (e.key === "ArrowUp")   { e.preventDefault(); if (visible[idx - 1]) visible[idx - 1].focus(); }
      if (e.key === "ArrowRight") {
        e.preventDefault();
        if (!expanded.has(nodeId) && hasChildren(nodeId)) { expanded.add(nodeId); refresh(); }
      }
      if (e.key === "ArrowLeft") {
        e.preventDefault();
        if (expanded.has(nodeId)) { expanded.delete(nodeId); refresh(); }
        else {
          var parentTr = rowById(String(tr.dataset.treeParent || ""));
          if (parentTr) parentTr.focus();
        }
      }
    });

    /* ─── drag and drop (delegated to tbody — 5 listeners instead of 5×N) ─── */
    if (moveUrl) {
      rowList.forEach(function (tr) { tr.setAttribute("draggable", "true"); });

      var tbody = table.querySelector("tbody");
      if (tbody) {
        tbody.addEventListener("dragstart", function (e) {
          var tr = e.target.closest(".arc-tree-row");
          if (!tr) return;
          dragId = String(tr.dataset.treeId);
          e.dataTransfer.effectAllowed = "move";
          e.dataTransfer.setData("text/plain", dragId);
          /* Defer so drag image captures un-dimmed state */
          requestAnimationFrame(function () { tr.classList.add("arc-tree-dragging"); });
        });

        tbody.addEventListener("dragend", function (e) {
          var tr = e.target.closest(".arc-tree-row");
          dragId = null;
          if (tr) tr.classList.remove("arc-tree-dragging");
          if (dropTarget) { dropTarget.classList.remove("arc-tree-drop-target"); dropTarget = null; }
        });

        tbody.addEventListener("dragover", function (e) {
          var tr = e.target.closest(".arc-tree-row");
          if (!tr || !dragId || dragId === String(tr.dataset.treeId)) return;
          e.preventDefault();
          e.dataTransfer.dropEffect = "move";
          if (tr !== dropTarget) {
            if (dropTarget) dropTarget.classList.remove("arc-tree-drop-target");
            dropTarget = tr;
            tr.classList.add("arc-tree-drop-target");
          }
        });

        tbody.addEventListener("dragleave", function (e) {
          if (!tbody.contains(e.relatedTarget)) {
            if (dropTarget) { dropTarget.classList.remove("arc-tree-drop-target"); dropTarget = null; }
          }
        });

        tbody.addEventListener("drop", function (e) {
          e.preventDefault();
          var tr = e.target.closest(".arc-tree-row");
          if (dropTarget) { dropTarget.classList.remove("arc-tree-drop-target"); dropTarget = null; }
          if (!dragId || !tr || dragId === String(tr.dataset.treeId)) return;
          moveNode(dragId, String(tr.dataset.treeId));
        });
      }

      /* Drop on table header = move to root */
      var thead = table.querySelector("thead");
      if (thead) {
        thead.addEventListener("dragover", function (e) {
          if (!dragId) return;
          e.preventDefault();
          e.dataTransfer.dropEffect = "move";
          thead.classList.add("arc-tree-root-target");
        });
        thead.addEventListener("dragleave", function (e) {
          if (!thead.contains(e.relatedTarget)) thead.classList.remove("arc-tree-root-target");
        });
        thead.addEventListener("drop", function (e) {
          e.preventDefault();
          thead.classList.remove("arc-tree-root-target");
          if (dragId) moveNode(dragId, null);
        });
      }
    }

    /* ─── init ─── */
    buildCache();
    applyLayout();
    refresh();
  });
})();
</script>'

  design
    .arc-tree-outer
      overflow: hidden
      position: relative

    .arc-tree-table
      table-layout: auto
    .arc-tree-table.arc-tree--moving
      pointer-events: none
      opacity: 0.6
      cursor: wait

    .arc-tree-row:focus
      outline: 2px solid var(--brand-from, #5956f0)
      outline-offset: -2px
    .arc-tree-row:focus-visible
      outline: 2px solid var(--brand-from, #5956f0)
      outline-offset: -2px

    .arc-tree-cell-label
      display: flex
      align-items: center
      gap: 6px
      min-width: 180px

    .arc-tree-toggle
      flex-shrink: 0
      display: inline-flex
      align-items: center
      justify-content: center
      width: 20px
      height: 20px
      border-radius: 4px
      font-size: 9px
      color: var(--ui-fg-3, #a3a3a3)
      background: none
      border: none
      cursor: pointer
      transition: background-color 0.1s, color 0.1s
    .arc-tree-toggle:hover
      background-color: var(--ui-bg-3, #f0f0f0)
      color: var(--ui-fg, #050d1f)
    .arc-tree-toggle:focus-visible
      outline: 2px solid var(--brand-from, #5956f0)
      outline-offset: 1px

    .arc-tree-leaf-pad
      flex-shrink: 0
      width: 20px

    .arc-tree-label
      font-size: 14px
      font-weight: 500
      white-space: nowrap
      overflow: hidden
      text-overflow: ellipsis
      max-width: 360px

    .arc-tree-secondary
      font-size: 12px
      color: var(--ui-fg-3, #a3a3a3)
      white-space: nowrap
    .arc-tree-badge
      font-size: 11px

    .arc-tree-actions
      text-align: right
      white-space: nowrap
      width: 64px

    /* drag states */
    .arc-tree-dragging
      opacity: 0.35
    .arc-tree-drop-target > td
      background-color: color-mix(in srgb, var(--brand-from, #5956f0) 8%, transparent)
      outline: 2px solid var(--brand-from, #5956f0)
      outline-offset: -2px
    thead.arc-tree-root-target th
      background-color: color-mix(in srgb, var(--brand-from, #5956f0) 8%, transparent)
      outline: 2px dashed var(--brand-from, #5956f0)
      outline-offset: -2px

    /* toast notifications */
    .arc-tree-toast
      position: fixed
      bottom: 24px
      right: 24px
      padding: 10px 16px
      border-radius: 8px
      font-size: 13px
      font-weight: 500
      z-index: 9999
      animation: arc-tree-fadein 0.2s ease
      box-shadow: 0 4px 16px rgba(0,0,0,0.12)
    .arc-tree-toast--error
      background: #fef2f2
      color: #b91c1c
      border: 1px solid rgba(185,28,28,0.25)
    .arc-tree-toast--info
      background: var(--ui-bg-2, #f0f9ff)
      color: var(--ui-fg, #050d1f)
      border: 1px solid var(--ui-border, #e2e8f0)

    @keyframes arc-tree-fadein
      from
        opacity: 0
        transform: translateY(8px)
      to
        opacity: 1
        transform: translateY(0)
