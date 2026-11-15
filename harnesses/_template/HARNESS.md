# <harness-name>

One-line summary of what this Harness equips a Worker to do.

## Fit

- **Use when**: <task types, repo characteristics>
- **Avoid when**: <task types where this Harness adds noise or conflicts>

## Components

Each line: path or name, origin (`authored`, or copied from `<plugin>@<version>`), and which step it serves and why that kind.

- **Enabled Plugins**: `<plugin>@ccc` — <step> — <work it does that AGENTS.md alone cannot: a checker, renderer, gate, or decision>
- **skills/**: `<harness>-<skill>/` — <origin> — <step, reason>
- **agents/**: `<agent>.md` — <origin> — <step, reason>
- **workflows/**: `<workflow>.js` — <origin> — <step, reason>
- **hooks/**: `<hook>` (<event>) — <origin> — <gate it enforces>; env it reads: `<VAR>`
- **Considered, not used**: `<plugin>:<component>` — <why: no unique work here, missing binary, needs API key, overlaps the chosen one>

## Situations

### <Situation A, e.g. Green-field feature>
1. <Ordered workflow for the Worker>
2. <Verification step>

### <Situation B, e.g. Bug fix>
1. <Ordered workflow for the Worker>
2. <Verification step>

## Init Decisions

- <What Control Plane must check during project scan and adjust in `AGENTS.md` or `settings.local.json`>
- <Which `skillOverrides` or Plugin disables to apply>

## Smoke Check

- **Task**: <Short read-only or local task for a Worker launched via `hc` to verify Components load and cooperate>
- **Pass criteria**: <Observable state confirming the Harness works>
