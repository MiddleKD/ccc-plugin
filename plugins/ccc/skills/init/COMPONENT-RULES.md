# Component Precedence & Conflict Rules

Apply these rules across **all** layers: global ↔ worktree, existing project config ↔ Harness, and Plugin ↔ Plugin.

## Precedence Table

| Component | Precedence | Action when bundling / copying |
|---|---|---|
| **skill** | Global (`~/.claude/skills`) beats project (`.claude/skills`). `skillOverrides` matches by skill name only and does **not** apply to Plugin skills (`plugin:skill`). | Prefix copied skill directory and `name` with `<harness>-`. Disable any matching global skill in worktree `settings.local.json` via `"skillOverrides": { "<name>": "off" }`. |
| **agent** | Project beats global; Plugin agent is lowest. | Keep original name; project copy automatically wins. |
| **workflow** | Project beats global. | Keep original name; project copy automatically wins. |
| **hook** | All layers merge and every hook runs, except entries with an identical `command` string, which run once. Individual hooks cannot be disabled. | Before registering a Harness hook, look for the same behaviour in global settings, project settings, and enabled Plugins' `hooks` files. If it exists, omit it. If you must register it, reuse the exact `command` string so the duplicate collapses. Never set `disableAllHooks: true` (that disables herdr state hooks). |
| **Plugin Component** | Namespaced as `<plugin>:<name>`. | If only a subset of a Plugin's Components was copied into the Harness, disable that Plugin in worktree `settings.local.json` (`"<plugin>@<marketplace>": false`). |

## Enabling Plugins in a worktree

Install task Plugins at local scope from inside the worktree: `claude plugin install <plugin>@ccc --scope local`. Writing `enabledPlugins` alone does nothing for a Plugin that is not yet in the cache. The command writes `.claude/settings.local.json` and leaves `~/.claude/settings.json` untouched.

## Binaries a Plugin needs

hc and Claude Code sessions inherit a non-interactive PATH, so binaries installed by shell rc files (pnpm, nvm, pyenv) are missing. An LSP Plugin then fails silently with `Executable not found`. When a Plugin needs such a binary, set `env.PATH` in worktree `settings.local.json` to the directory holding it followed by the current PATH.

## Linked Worktree Fallback Gotcha

When a linked worktree has no `.claude/skills/` directory, Claude Code falls back to loading the main checkout's `.claude/skills/`. Creating `.claude/skills/` inside the worktree disables that fallback. If the target project already has project-level skills that the Worker needs, copy them into the worktree alongside the Harness skills.

## Disambiguating Overlapping Roles

When two active Components serve the same role (e.g., two TDD skills or two code-review skills), pick one in `AGENTS.md` and name it explicitly so the Worker does not guess. Record newly discovered overlaps in `<ccc-repo>/CONFLICTS.md`.
