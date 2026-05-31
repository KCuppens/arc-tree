# Contributing to arc-tree

Thank you for your interest in contributing!

## Dev setup

```bash
git clone https://github.com/your-org/arc-tree
cd arc-tree
# no npm install needed — zero runtime dependencies

# Link into a local Arc CMS project for manual testing:
cd /your-arc-project
npm link /path/to/arc-tree
arc cms add tree
arc dev
```

## Project structure

```
arc-tree/
├── src/
│   ├── index.js          Arc package contract (exports serverDir, widgetsDir)
│   ├── server/
│   │   └── tree.arc      GET /admin/tree/:model + POST .../move routes
│   ├── widgets/
│   │   ├── CmsTreeTable.arc     Tree table widget
│   │   └── CmsParentPicker.arc  Parent selector widget
│   ├── schema/
│   │   └── migrate.sql   Idempotent migration template
│   └── types.d.ts        TypeScript declarations
├── README.md
├── CHANGELOG.md
└── package.json
```

## Guidelines

**Server routes (`tree.arc`)**
- All routes require `admin` or `editor` role via `@auth`
- Validate all inputs before touching the DB
- Return `{ error: "..." }` with an appropriate 4xx status on failure
- Emit an audit log entry for every mutation
- The `_moveSubtree` helper is the single source of truth for path arithmetic — extend it, don't bypass it

**Widgets**
- No external JS dependencies
- All interactive behaviour lives in the `@raw '<script>...</script>'` block, scoped with an IIFE
- CSS uses `--ui-*` and `--brand-*` custom properties so it respects the host app's theme
- New interactions must be keyboard-accessible and carry appropriate ARIA attributes

**Adding a new model**
1. Add an `if model == "mymodel"` branch to both the `GET` and `POST` handlers in `tree.arc`
2. Update `arc.config.json` docs in README.md
3. Add an entry to CHANGELOG.md

## Submitting changes

1. Fork the repo and create a branch: `git checkout -b feat/my-change`
2. Make your changes with clear, focused commits
3. Update CHANGELOG.md under `[Unreleased]`
4. Open a pull request — describe what changed and why

## Reporting bugs

Open a GitHub issue with:
- Arc version (`arc --version`)
- arc-tree version
- Steps to reproduce
- Expected vs. actual behaviour
