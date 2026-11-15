# <harness-name>

One-line summary of what this Harness equips a Worker to do.

## Fit

- **Use when**: <task types, repo characteristics>
- **Avoid when**: <task types where this Harness adds noise or conflicts>

## Components

- **Enabled Plugins**: `<plugin>@ccc` (reason)
- **Bundled Components**:
  - `skills/<harness>-<skill>/` — copied from `<plugin>@<version>` (original skill disabled via `skillOverrides` if global)
  - `agents/<agent>.md` — copied from `<plugin>@<version>`
  - `hooks/<hook>` — ...

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
