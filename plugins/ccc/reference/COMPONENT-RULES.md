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

## Subagents inside a Worker

A Worker's subagents run with no `isolation` field, in the task worktree, where they see uncommitted changes. Every isolation mode hands them a different copy: `worktree` creates one under the **main checkout's** `.claude/worktrees/` that stays behind and dirties it; `remote` runs in a cloud copy that has none of the Worker's uncommitted edits, so a reviewer audits stale code. The template's Working rules carry this; an authored agent omits the `isolation` field for the same reason.

## Linked Worktree Fallback Gotcha

When a linked worktree has no `.claude/skills/` directory, Claude Code falls back to loading the main checkout's `.claude/skills/`. Creating `.claude/skills/` inside the worktree disables that fallback. If the target project already has project-level skills that the Worker needs, copy them into the worktree alongside the Harness skills.

## Disambiguating Overlapping Roles

When two active Components serve the same role (e.g., two TDD skills or two code-review skills), pick one in `AGENTS.md` and name it explicitly so the Worker does not guess. Record newly discovered overlaps in `<ccc-repo>/CONFLICTS.md`.

## Choosing a Component kind

Each kind does a different job. Pick by what the step needs, and write the reason into `HARNESS.md` Components:

| The step needs… | Kind | Why that kind |
|---|---|---|
| ordered instructions and project facts for this run | `AGENTS.md` | Always in context; cheapest. Holds steps, gates, traps. |
| a reusable procedure the Worker invokes on its own at one point in the work | **skill** | Loaded only when its description matches, so it costs nothing until needed. |
| a second opinion with a fresh context, or a role that must not see the Worker's reasoning (reviewer, verifier, adversary) | **agent** | Runs in its own context with its own tool limits; its verdict is independent of the Worker's. |
| the same sub-task over many items in parallel (files, modules, endpoints), or a fixed fan-out/fan-in | **workflow** | Runs many agents deterministically; intermediate results stay out of the Worker's context. |
| a gate the Worker might skip or claim falsely | **hook** | Runs whether the Worker remembers or not. |

A Harness made of `AGENTS.md` alone is right for small tasks. When the task has many items, needs an independent check, or has a gate that was skipped before, the Harness needs the matching Component, not another instruction line.

## Authoring Components

Files Claude Code cannot parse are skipped without a message, so `ccc-gate.sh init` checks each kind. Write them to pass it:

- **skill** — `skills/<name>/SKILL.md`, frontmatter on line 1 with `name` (equal to the directory) and `description`. The description is the trigger: say *when* to use it, in the words the Worker's task will contain. Reference bundled files as `${CLAUDE_SKILL_DIR}/<file>`.
- **agent** — `agents/<name>.md`, frontmatter on line 1 with `name` (no `:`, no leading `-`) and `description`; optional `tools` (comma list) to restrict it, e.g. `Read, Grep, Glob, Bash` for a reviewer that must not edit. The body is its system prompt: state its one job, its inputs, and its output format. The Worker starts it by name through the Agent tool, so name it in `AGENTS.md` at the step that uses it.
- **workflow** — `workflows/<name>.js`. First statement `export const meta = { name: '<name>', description: '...' }` with literal strings only. Body is JavaScript with top-level `await`, using `agent(prompt, opts)`, `pipeline(items, fn)`, `parallel(fns)`, `phase(title)`, `log(msg)`, and `args`. `Date.now()`, `Math.random()`, and `new Date()` throw; pass such values through `args`. The Worker runs it as `/<name>`; `.claude/workflows/` needs `enableWorkflows` on, which is the user's global default.
- **hook** — script in `hooks/`, executable, registered in `settings.local.json` with `"$CLAUDE_PROJECT_DIR"/.claude/hooks/<script>`. Read project commands from env set in `settings.local.json`, never hard-code them. Only exit code 2 (or exit 0 with `{"decision":"block"}`) blocks; any other failing exit is a non-blocking notice, so a gate script run under `set -e` enforces nothing. A Stop hook must exit 0 when `stop_hook_active` is true, or it loops. Start from `<ccc-repo>/harnesses/root-cause-bugfix/hooks/verify-gates.sh`, which already does both.
