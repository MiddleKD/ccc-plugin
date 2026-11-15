---
name: promote
description: Evaluate a Worker's Harness and promote it or record project affinity. Use when a Worker finishes, before removing its worktree.
---

# /ccc:promote

Evaluate a Worker's run **before** cleaning up its worktree, and when warranted, extract a reusable Harness into `ccc-plugin`, record project-to-Harness affinity in project memory, or add an entry to `CONFLICTS.md`.

## Locate ccc-plugin

Resolve `<ccc-repo>` from `~/.claude/plugins/known_marketplaces.json` (`ccc` entry).

## 1. Gather Evidence (Before Worktree Cleanup)

Inspect the target worktree and Worker session **before** removing the worktree or branch:
- Read `<worktree>/.claude/.ccc.json` (used Harness or `instant`, situation, copied Components, `smokeCheckNotes`).
- Read the Worker's final report (including its 1-2 lines of Harness feedback).
- Inspect the Worker's session output (`hc read` if still alive) and Claude session transcript under `~/.claude/projects/` for actual tool calls, friction, retries, and hook/skill issues.
- Check git diff / PR status in `<worktree>` to verify task completion.

**Done when**: Evidence from `.ccc.json`, Worker report, transcript, and git state is collected.

## 2. Evaluate Against Three Criteria

Score the run honestly on all three:
1. **Smooth completion**: Did the Worker finish without setup blockers or repeated retries?
2. **Harness contribution**: Did the bundled Plugins, skills, agents, hooks, or `AGENTS.md` instructions measurably help?
3. **Reuse value**: Is this setup general enough to benefit future tasks (either across projects or repeatedly in this project)?

If the setup does not clear all three, skip promotion proposals and state why. Still propose `CONFLICTS.md` updates if a real Component conflict was observed.

**Done when**: Clear yes/no verdict with specific evidence from the transcript for each criterion.

## 3. Propose Separate Actions (Only What Earned It)

Keep **Harness promotion** (generic recipe in `ccc-plugin`) strictly separate from **project affinity** (project memory):

- **A. Promote to `ccc-plugin` Harness** (when reusable across projects):
  - Copy `<ccc-repo>/harnesses/_template/` to `<ccc-repo>/harnesses/<harness-name>/`.
  - Copy any external Components used from Plugins into `<harness-name>/{skills,agents,hooks,workflows}/` so the Harness is self-contained (record provenance in `HARNESS.md`, follow `plugins/ccc/skills/init/COMPONENT-RULES.md`).
  - Strip **all** project-specific details (repo names, paths, library versions, directory ownership).
  - Keep `HARNESS.md` <= 200 lines.
  - Ask user confirmation before committing to `ccc-plugin`.

- **B. Record Project Affinity** (when this Harness fits this project):
  - Save or update a `project` memory file in the **target project's** Claude project memory directory (`~/.claude/projects/<encoded-project-path>/memory/`), noting which Harness (and Situation) works well for which task types in that repo.
  - Never write project affinity into `<ccc-repo>/harnesses/` or into the target repo's tracked files.

- **C. Update `CONFLICTS.md`** (when a new Component conflict or precedence lesson occurred):
  - Append a concise entry to `<ccc-repo>/CONFLICTS.md` following its format, and ask user confirmation before committing.

**Done when**: Proposed actions are executed (with user confirmation for commits) or explicitly declined.

## 4. Clean Up Worktree

Only **after** evaluation and any extraction are complete:
- Ask or confirm before removing `<worktree>` (`git worktree remove`) and deleting branch `ccc/<task-slug>` (if merged or no longer needed).
- Delete the `# ccc:<branch>` … `# /ccc:<branch>` block from the shared git exclude (`git rev-parse --git-path info/exclude`, run from the main checkout).

**Done when**: Evaluation is complete and worktree cleanup is either done or deferred per user choice.
