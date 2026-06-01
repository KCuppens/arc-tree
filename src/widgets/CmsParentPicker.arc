# CmsParentPicker — indented <select> for choosing a tree node's parent.
#
# options:    Array<ParentPickerOption> — flat list ordered by path ASC.
#             Each item: { id: number|string, depth: number, label: string }
#             where label already has the "—" depth-prefix applied server-side.
#             TypeScript: see ParentPickerOption in arc-tree/src/types.d.ts
# name:       the @state variable name to bind with bind:value="{name}"
# excludeIds: Array<string> — IDs to suppress (pass current node + descendants
#             to prevent setting a node as its own ancestor)

widget CmsParentPicker(
  name:       String,
  options:    Any,
  excludeIds: Any    = [],
  ariaLabel:  String = "Parent"
)

  col gap="4px"
    select class="!input arc-pp-select"
      attr bind:value="{name}"
      attr aria-label="{ariaLabel}"
      option value="" "— No parent (root level) —"
      for opt in options
        if !excludeIds.map(String).includes(String(opt.id))
          option value="{opt.id}" "{opt.label}"

  design
    .arc-pp-select
      width: 100%
      font-family: inherit
      font-size: 14px
