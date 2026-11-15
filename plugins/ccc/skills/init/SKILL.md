---
name: init
description: Provision a worktree with a Harness or Instant Harness for a Worker, then Smoke Check it. Use when handing a task to a new Worker.
---

# /ccc:init

Provision an isolated git worktree for a task, install a matching Harness (or assemble an Instant Harness), enforce Component precedence, and verify with a real `hc` Worker Smoke Check.

Read [`COMPONENT-RULES.md`](COMPONENT-RULES.md) and [`SMOKE-CHECK.md`](SMOKE-CHECK.md) before installing or verifying.

## Locate ccc-plugin

Resolve the `ccc-plugin` repository path from the `ccc` marketplace entry in `~/.claude/plugins/known_marketplaces.json` (or `~/.claude/plugins/cache/ccc/` if remote). All references to `<ccc-repo>` below mean that repository root.

## 1. Scan Project & Memory

Inspect the target repository before choosing anything:
- Tech stack, package manager, test runner, dev server ports (web projects only).
- Existing `CLAUDE.md`, `AGENTS.md`, `.claude/skills/`, `.claude/agents/`, `.claude/hooks/`, `.claude/workflows/`, `.claude/settings*.json`.
- Project memory for this repo (`~/.claude/projects/<encoded-path>/memory/`) for prior Harness recommendations.

**Done when**: Stack, test command, existing project Components, and any project memory Harness affinity are known.

## 2. Inventory Components & Check Conflicts

Build a single flat view of all candidate Components across every layer:
1. Read `~/.claude/settings.json` (`enabledPlugins`, `skillOverrides`, `hooks`) and `<ccc-repo>/.claude-plugin/marketplace.json` to see which Plugins are globally enabled vs available.
2. Scan `~/.claude/plugins/cache/` for each candidate Plugin's Components (`skills/`, `agents/`, `hooks/`, `workflows/`, `mcp.json`, `lspServers`) — extract **only** names and frontmatter `description`s, not full bodies.
3. Read `<ccc-repo>/CONFLICTS.md` and check for known overlaps among the active layers.

**Done when**: Every active and candidate Component (skill, agent, workflow, hook, MCP/LSP) across global, project, and Plugin layers is listed with its name and role, and conflicts are flagged.

## 3. Select Harness or Assemble Instant Harness

- Check `<ccc-repo>/harnesses/*/HARNESS.md` (skip `_template/`) and project memory.
- If a promoted Harness fits: select it, read its `HARNESS.md`, pick the single **Situation** matching this task, and apply its **Init Decisions**.
- Otherwise: design an **Instant Harness**. Its value is the *recipe*, not the Plugin list:
  1. Name the task **shape** in generic words (e.g. "multi-module refactor with type checking"), never the project.
  2. Write the Situation as ordered steps, each ending on a **gate**: a command whose output proves the step done (tests green, type checker clean, diff limited to named files).
  3. For each step, pick the Component that does it best, from any layer. Add a Component only when a step needs it: a reviewer agent for a review gate, a Stop or PostToolUse hook to enforce a gate the Worker might skip, an LSP Plugin for type feedback.
  4. Record the shape's known traps (what a Worker gets wrong on this kind of task) as instructions.
  Write the result as a full Harness folder draft in `<worktree>/.claude/ccc/` (copy `<ccc-repo>/harnesses/_template/`, fill `HARNESS.md`). The draft is what `/ccc:promote` later generalizes, so write it generic from the start and keep project facts in `AGENTS.md` only.
- For every overlapping role, choose one winner to name in `AGENTS.md` and apply [`COMPONENT-RULES.md`](COMPONENT-RULES.md).

**Done when**: Harness (promoted, or `instant` with a filled `.claude/ccc/HARNESS.md` whose every step has a gate), active Situation, Plugin list, Component copies, and conflict resolutions are decided.

## 4. Prepare Worktree

- Branch: `ccc/<task-slug>` (from current HEAD unless user specified a base).
- Worktree path: `../<project-name>.worktrees/<task-slug>` (sibling to target repo root).
- Run `git worktree add -b ccc/<task-slug> <worktree-path>`.
- Copy required untracked files (e.g., `.env*`) from the main checkout.
- Install dependencies using the project's package manager.
- If the project runs a dev server, assign an isolated port (e.g., env var or local config) so parallel worktrees do not collide.

**Done when**: Worktree exists on `ccc/<task-slug>`, dependencies are installed, and required untracked files are present.

## 5. Install Harness into Worktree

1. **Copy, never symlink** Harness files (`skills/`, `agents/`, `hooks/`, `workflows/`) into `<worktree>/.claude/`. Ensure hook scripts are executable (`chmod +x`).
2. Apply [`COMPONENT-RULES.md`](COMPONENT-RULES.md) (rename copied skills with `<harness>-` prefix, disable matching global skills, disable partially-copied Plugins, omit duplicate hooks, preserve needed project skills).
3. Install task Plugins with `claude plugin install <plugin>@ccc --scope local` from the worktree, then add `skillOverrides`, `env`, and hooks to `<worktree>/.claude/settings.local.json`. Never touch `~/.claude/settings.json` or tracked project settings.
4. Write `<worktree>/AGENTS.md` containing **only** the active Situation's steps and gates, project facts (paths, commands), explicitly named Components, Worker feedback prompt (1-2 lines on Harness fit), and PR rule (draft PR by default; ready PR only if user explicitly authorized it at `init`).
5. Ensure `<worktree>/CLAUDE.md` imports `@AGENTS.md` (append `@AGENTS.md` if `CLAUDE.md` exists, or create it).
6. Record state in `<worktree>/.claude/.ccc.json` (`harness`, `situation`, `plugins`, `copiedComponents`, `smokeCheckNotes`, `createdAt`).
7. Add all injected files (`AGENTS.md`, `CLAUDE.md` if newly created, `.claude/settings.local.json`, `.claude/.ccc.json`, `.claude/ccc/`, and copied `.claude/{skills,agents,hooks,workflows}/`) to the git local exclude (`git rev-parse --git-path info/exclude`), wrapped in `# ccc:<branch>` / `# /ccc:<branch>` marker lines. Linked worktrees share this file with the main checkout, so the markers let `/ccc:promote` remove exactly this block. Verify `git status` is clean.

**Done when**: All Harness files are installed in `<worktree>`, `settings.local.json` is valid JSON, and `git status` in `<worktree>` shows no injected files.

## 6. Run Smoke Check

Follow [`SMOKE-CHECK.md`](SMOKE-CHECK.md) using `hc` in `<worktree>`.

**Done when**: Smoke Check passes (or 2 retries are exhausted and the failure report is presented to the user). Report the worktree path, branch, active Harness, and Smoke Check outcome.
