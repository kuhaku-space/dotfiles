# Agent Instructions

## Documentation

### Reading

- Read only documentation relevant to the current task.
- Access known files directly; use `docs/INDEX.md` only when locating documentation.
- Prefer targeted searches and relevant sections over entire files.
- Reuse information already available in the current context.
- Check related documentation when changes may affect other components.
- Prioritize current specifications and source code over outdated documentation.

### Writing

- Keep documentation concise, accurate, and nonredundant.
- Organize documents by topic with descriptive headings.
- Maintain a single source of truth; link instead of duplicating content.
- Separate current specifications from historical decisions.
- Update the relevant documentation when behavior, architecture, commands, or conventions change.
- Update `docs/INDEX.md` when the documentation structure changes.

### Principle

Minimize unnecessary context and tool calls without compromising correctness, completeness, or verification.

## Verification

- Run the relevant checks documented for the project after making changes.

## Git

- Commit directly to `main`. Do not create feature branches.
- Commit after every change. Do not leave completed changes uncommitted; keep each commit focused on a single logical change.
- Follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) for every commit message:
  - Format: `<type>(<optional scope>): <description>`, e.g. `feat(contests): allow reordering problems`.
  - Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
  - Write the description in the imperative mood, lowercase, without a trailing period.
  - Mark breaking changes with `!` after the type/scope (e.g. `feat(auth)!: ...`) and a `BREAKING CHANGE:` footer explaining the migration.
