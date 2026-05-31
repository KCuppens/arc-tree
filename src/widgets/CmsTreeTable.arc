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
  draggable:  Bool   = true
)

  col class="arc-tree-outer"
    col class="!table-wrap"
      table class="!table arc-tree-table"
        attr role="treegrid"
        attr aria-label="Content tree"
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
                  attr aria-label="Expand"
                  attr data-toggle-id="{row.id}"
                  attr tabindex="-1"
                  "▶"
                span class="arc-tree-leaf-pad" attr aria-hidden="true"
                text class="arc-tree-label" "{row.label}"
              if col2Header != ""
                td attr role="gridcell"
                  if row.badge != ""
                    text class="!badge arc-tree-badge" "{row.badge}"
                  if row.secondary != ""
                    text class="arc-tree-secondary" "{row.secondary}"
              td class="arc-tree-actions" attr role="gridcell"
                link href="{entityUrl}/{row.id}"
                  button class="!btn !btn--ghost !btn--sm" attr tabindex="-1" "Edit"

  @raw '<script>
(function () {
  "use strict";

  document.querySelectorAll(".arc-tree-table").forEach(function (table) {
    var expanded  = new Set();
    var dragId    = null;
    var isMoving  = false;
    var moveUrl   = table.dataset.moveUrl || "";

    /* ─── row helpers ─── */
    function allRows() {
      return Array.from(table.querySelectorAll(".arc-tree-row"));
    }

    function rowById(id) {
      return table.querySelector(".arc-tree-row[data-tree-id=\"" + id + "\"]");
    }

    function hasChildren(nodeId) {
      return !!table.querySelector(".arc-tree-row[data-tree-parent=\"" + nodeId + "\"]");
    }

    function isVisible(tr) {
      var depth = parseInt(tr.dataset.treeDepth) || 0;
      if (depth === 0) return true;
      var parentId = String(tr.dataset.treeParent || "");
      if (!expanded.has(parentId)) return false;
      var parentTr = rowById(parentId);
      return parentTr ? isVisible(parentTr) : false;
    }

    /* ─── indentation (set after render; avoids arithmetic in Arc templates) ─── */
    function applyLayout() {
      allRows().forEach(function (tr) {
        var depth   = parseInt(tr.dataset.treeDepth) || 0;
        var nodeId  = String(tr.dataset.treeId);
        var cell    = tr.querySelector(".arc-tree-cell-label");
        var toggle  = tr.querySelector(".arc-tree-toggle");
        var leafPad = tr.querySelector(".arc-tree-leaf-pad");
        var leaf    = !hasChildren(nodeId);

        if (cell)    cell.style.paddingLeft = (depth * 20 + 12) + "px";
        if (toggle)  { toggle.hidden = leaf; toggle.setAttribute("aria-label", expanded.has(nodeId) ? "Collapse" : "Expand"); }
        if (leafPad) leafPad.hidden = !leaf;
      });
    }

    /* ─── expand / collapse ─── */
    function refresh() {
      allRows().forEach(function (tr) {
        var nodeId  = String(tr.dataset.treeId);
        var visible = isVisible(tr);
        tr.hidden   = !visible;
        var toggle  = tr.querySelector(".arc-tree-toggle");
        if (toggle) {
          var open = expanded.has(nodeId);
          toggle.textContent = open ? "▼" : "▶";
          toggle.setAttribute("aria-expanded", String(open));
          toggle.setAttribute("aria-label", open ? "Collapse" : "Expand");
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
      if (isMoving) return;
      isMoving = true;
      table.classList.add("arc-tree--moving");
      fetch(moveUrl + "/" + fromId + "/move", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: "same-origin",
        body: JSON.stringify({ newParentId: toParentId })
      })
        .then(function (r) { return r.json(); })
        .then(function (body) {
          if (body.error) {
            showToast(body.error, "error");
          } else {
            window.location.reload();
          }
        })
        .catch(function () { showToast("Move failed — please try again", "error"); })
        .finally(function () {
          isMoving = false;
          table.classList.remove("arc-tree--moving");
        });
    }

    function showToast(msg, type) {
      var el = document.createElement("div");
      el.className = "arc-tree-toast arc-tree-toast--" + (type || "info");
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

    /* ─── keyboard: Space/Enter = expand; Arrow keys = navigate ─── */
    table.addEventListener("keydown", function (e) {
      var tr = e.target.closest(".arc-tree-row");
      if (!tr) return;
      var nodeId = String(tr.dataset.treeId);

      if (e.key === " " || e.key === "Enter") {
        var toggle = tr.querySelector(".arc-tree-toggle");
        if (toggle && !toggle.hidden) { e.preventDefault(); toggleExpand(nodeId); }
        return;
      }

      var visible = allRows().filter(function (r) { return !r.hidden; });
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
          var parentId = String(tr.dataset.treeParent || "");
          var parentTr = rowById(parentId);
          if (parentTr) parentTr.focus();
        }
      }
    });

    /* ─── drag and drop ─── */
    if (moveUrl) {
      allRows().forEach(function (tr) {
        tr.setAttribute("draggable", "true");

        tr.addEventListener("dragstart", function (e) {
          dragId = String(tr.dataset.treeId);
          e.dataTransfer.effectAllowed = "move";
          e.dataTransfer.setData("text/plain", dragId);
          /* Defer class to next frame so the drag image captures the un-dimmed state */
          requestAnimationFrame(function () { tr.classList.add("arc-tree-dragging"); });
        });

        tr.addEventListener("dragend", function () {
          dragId = null;
          tr.classList.remove("arc-tree-dragging");
          table.querySelectorAll(".arc-tree-drop-target").forEach(function (el) {
            el.classList.remove("arc-tree-drop-target");
          });
        });

        tr.addEventListener("dragover", function (e) {
          if (!dragId || dragId === String(tr.dataset.treeId)) return;
          e.preventDefault();
          e.dataTransfer.dropEffect = "move";
          table.querySelectorAll(".arc-tree-drop-target").forEach(function (el) {
            el.classList.remove("arc-tree-drop-target");
          });
          tr.classList.add("arc-tree-drop-target");
        });

        tr.addEventListener("dragleave", function (e) {
          /* Only clear if leaving the row entirely, not a child element */
          if (!tr.contains(e.relatedTarget)) tr.classList.remove("arc-tree-drop-target");
        });

        tr.addEventListener("drop", function (e) {
          e.preventDefault();
          tr.classList.remove("arc-tree-drop-target");
          if (!dragId || dragId === String(tr.dataset.treeId)) return;
          moveNode(dragId, String(tr.dataset.treeId));
        });
      });

      /* Drop on the table header = move to root */
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
      color: #ef4444
      border: 1px solid rgba(239,68,68,0.25)
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
