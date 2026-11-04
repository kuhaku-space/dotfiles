# Agent Instructions

## Documentation

- Locate documentation via `docs/INDEX.md`; read only what the task needs.
- Trust current source code over outdated documentation.
- Keep docs concise with a single source of truth; link instead of duplicating.
- Keep current docs in `docs/current`; move completed migration records to `docs/archive`.
- Update relevant docs when behavior, commands, or conventions change, and `docs/INDEX.md` when the structure changes.

## Verification

- Run the relevant checks in `docs/commands.md` after making changes.

## Git

- Commit directly to `main` after every change, one logical change per commit.
- Follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/), e.g. `feat(zsh): add alias`.
