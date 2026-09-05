# Agent Instructions

## Core rules

- Read `docs/INDEX.md` before loading project documentation.
- Load only the documents relevant to the current task.
- Do not recursively read all files under `docs/`.
- Do not read `docs/archive/` unless historical context is explicitly required.
- Prefer current source code over stale documentation when they conflict.
- When behavior, architecture, commands, or conventions change, update the smallest relevant document.

## Source priority

When sources conflict, use this priority unless a task says otherwise:

1. Explicit user/task instructions
2. `docs/current/`
3. Relevant project documentation referenced by `docs/INDEX.md`
4. Source code and tests
5. `docs/decisions/`
6. `docs/archive/`

## Working procedure

1. Read `docs/INDEX.md`.
2. Identify the minimum set of relevant documents.
3. Read those documents only.
4. Inspect the relevant source files.
5. Make the change.
6. Run the relevant checks from `docs/commands.md`.
7. Update documentation only if the documented behavior changed.
