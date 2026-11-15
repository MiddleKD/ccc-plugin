# Harnesses

Reusable, self-contained execution bundles for Workers. Each subfolder under `harnesses/` (other than `_template/`) is a promoted Harness.

Start from `_template/` when creating a Harness via `/ccc:promote`.

## Folder contract

Required:
- `HARNESS.md` — <= 200 lines. Covers: fit / non-fit tasks, bundled Components (with provenance if copied), per-situation usage, `init` decisions, and Smoke Check task.

Optional (include only what the Harness needs):
- `AGENTS.md` — Worker instruction template (referenced from worktree `CLAUDE.md` via `@AGENTS.md`).
- `settings.local.json` — worktree local settings template (`enabledPlugins`, `skillOverrides`, hook or LSP config).
- `skills/<name>/` — copied or custom skills. Prefix copied skill names with `<harness>-` when a global skill of the same name exists.
- `agents/` — copied or custom agents (keep original names; project overrides user and plugin).
- `hooks/` — hook scripts (must be executable) and hook config.
- `workflows/` — copied or custom workflows (keep original names; project overrides personal).

## Rules

1. **Self-contained**: Copy external Components into the Harness folder when only a subset of a Plugin is needed, and record the source Plugin + version in `HARNESS.md`. Enable a full Plugin in `settings.local.json` only when most of it is needed.
2. **Frozen snapshot**: Never sync copied Components back to upstream. A Harness stays pinned to its promoted state until explicitly updated.
3. **Generic only**: Omit project-specific details (repo paths, library versions, directory ownership, test or build commands). Scripts read project commands from env that `/ccc:init` sets in worktree `settings.local.json`, and `HARNESS.md` names those env vars under Init Decisions. Store project-to-Harness affinity in that project's Claude project memory instead.
4. **Thin `HARNESS.md`**: Keep `HARNESS.md` under 200 lines so Control Plane scans stay fast.
5. **Precedence-safe**: Apply the Component precedence table in `plugins/ccc/skills/init/COMPONENT-RULES.md` whenever bundling Components.
