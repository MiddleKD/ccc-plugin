# Component Precedence & Conflict Rules

Apply these rules across **all** layers: global ↔ worktree, existing project config ↔ Harness, and Plugin ↔ Plugin.

## Precedence Table

| Component | Precedence | Action when bundling / copying |
|---|---|---|
| **skill** | Global (`~/.claude/skills`) beats project (`.claude/skills`). `skillOverrides` matches by skill name only and does **not** apply to Plugin skills (`plugin:skill`). | Prefix copied skill directory and `name` with `<harness>-`. Disable any matching global skill in worktree `settings.local.json` via `"skillOverrides": { "<name>": "off" }`. |
| **agent** | Project beats global; Plugin agent is lowest. | Keep original name; project copy automatically wins. |
| **workflow** | Project beats global. | Keep original name; project copy automatically wins. |
| **hook** | All layers merge and **every** matching hook runs. Individual hooks cannot be disabled. | Check global settings, project config, and enabled Plugins first. If the same hook is already active in another layer, omit it from worktree `settings.local.json`. Never set `disableAllHooks: true` (that disables herdr state hooks). |
| **Plugin Component** | Namespaced as `<plugin>:<name>`. | If only a subset of a Plugin's Components was copied into the Harness, disable that Plugin in worktree `settings.local.json` (`"<plugin>@<marketplace>": false`). |

## Linked Worktree Fallback Gotcha

When a linked worktree has no `.claude/skills/` directory, Claude Code falls back to loading the main checkout's `.claude/skills/`. Creating `.claude/skills/` inside the worktree disables that fallback. If the target project already has project-level skills that the Worker needs, copy them into the worktree alongside the Harness skills.

## Disambiguating Overlapping Roles

When two active Components serve the same role (e.g., two TDD skills or two code-review skills), pick one in `AGENTS.md` and name it explicitly so the Worker does not guess. Record newly discovered overlaps in `<ccc-repo>/CONFLICTS.md`.
