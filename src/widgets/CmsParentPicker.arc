# CmsParentPicker — indented <select> for choosing a tree node's parent.
#
# options: flat array ordered by path ASC, each item: { id, depth, label }
#          where label already has "—" depth-prefix applied server-side.
# name:    the @state variable name to bind with bind:value="{name}"
# excludeIds: string array — IDs to hide (pass current node + all its descendants
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
