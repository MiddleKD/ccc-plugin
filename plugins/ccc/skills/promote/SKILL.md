---
name: promote
description: Evaluate a Worker's Harness and promote it or record project affinity. Use when a Worker finishes, before removing its worktree.
---

# /ccc:promote

Evaluate a Worker's run **before** cleaning up its worktree, and when warranted, extract a reusable Harness into `ccc-plugin`, record project-to-Harness affinity in project memory, or add an entry to `CONFLICTS.md`.

## Locate ccc-plugin

Resolve `<ccc-repo>` from `~/.claude/plugins/known_marketplaces.json` (`ccc` entry).

Every commit to `<ccc-repo>` and every branch deletion goes to the `approver` recorded in `.ccc.json`, the way [`APPROVAL.md`](${CLAUDE_PLUGIN_ROOT}/reference/APPROVAL.md) describes. With `hc:<terminal>`, ask through `hc send`; a dialog in this session blocks forever.

## 1. Gather Evidence (Before Worktree Cleanup)

Inspect the target worktree and Worker session **before** removing the worktree or branch:
- Read `<worktree>/.claude/.ccc.json` (used Harness or `instant`, situation, copied Components, `smokeCheckNotes`) and the Harness draft in `<worktree>/.claude/ccc/`.
- Read the Worker's final report (including its 1-2 lines of Harness feedback).
- Inspect the Worker's session output (`hc read` if still alive) and Claude session transcript under `~/.claude/projects/` for actual tool calls, friction, retries, and hook/skill issues.
- Check git diff / PR status in `<worktree>` to verify task completion.

**Done when**: Evidence from `.ccc.json`, Worker report, transcript, and git state is collected.

## 2. Evaluate Against Three Criteria

Score the run honestly on all three:
1. **Smooth completion**: Did the Worker finish without setup blockers or repeated retries?
2. **Harness contribution**: Did the bundled Plugins, skills, agents, hooks, or `AGENTS.md` instructions measurably help?
3. **Reuse value**: Will this task **shape** recur in other projects? Judge the recipe in `.claude/ccc/HARNESS.md` (steps, gates, traps, Component choices), not this instance. A recipe built from generic Plugins is still reusable when its steps and gates are what made the run succeed. A Harness that only names a Plugin and adds nothing a Worker would not do anyway has no reuse value.

Before scoring, revise the draft from the evidence: add traps the Worker hit and gates that caught a bug, and drop Components it never used. When the Worker skipped a gate, enforce it with a Component (a Stop hook that runs the gate command, or a reviewer agent) instead of adding another instruction. Score the revised draft.

If the setup does not clear all three, skip promotion proposals and state why, naming what the recipe would need to earn promotion. Still propose `CONFLICTS.md` updates if a real Component conflict was observed.

**Done when**: Each criterion has a yes/no with one evidence sentence from the transcript or git state, and the verdict is one of `promoted`, `updated` (an existing Harness), `affinity-only`, or `none`.

## 3. Propose Separate Actions (Only What Earned It)

Keep **Harness promotion** (generic recipe in `ccc-plugin`) strictly separate from **project affinity** (project memory):

- **A. Promote to `ccc-plugin` Harness** (when reusable across projects):
  - Copy the revised `<worktree>/.claude/ccc/` to `<ccc-repo>/harnesses/<harness-name>/` (name it after the task shape). If a promoted Harness was used, update that Harness instead of creating a new one: merge, keeping every earlier step, gate, and trap unless this run's evidence shows it wrong, and mark language- or stack-specific lines with their stack.
  - Copy any external Components used from Plugins into `<harness-name>/{skills,agents,hooks,workflows}/` so the Harness is self-contained (record provenance in `HARNESS.md`, follow `${CLAUDE_PLUGIN_ROOT}/reference/COMPONENT-RULES.md`).
  - Strip **all** project-specific details (repo names, paths, library versions, directory ownership).
  - Keep `HARNESS.md` <= 200 lines.
  - Run `${CLAUDE_PLUGIN_ROOT}/scripts/ccc-gate.sh harness <ccc-repo>/harnesses/<harness-name>` until it prints `ALL GATES PASS`, and include its output in the approval request.
  - Get the approver's yes before committing to `ccc-plugin`.

- **B. Record Project Affinity** (when this Harness fits this project):
  - Save or update a `project` memory file in the **target project's** Claude project memory directory (`~/.claude/projects/<encoded-project-path>/memory/`), noting which Harness (and Situation) works well for which task types in that repo.
  - Never write project affinity into `<ccc-repo>/harnesses/` or into the target repo's tracked files.

- **C. Update `CONFLICTS.md`** (when a new Component conflict or precedence lesson occurred):
  - Append a concise entry to `<ccc-repo>/CONFLICTS.md` following its format, and get the approver's yes before committing.

**Done when**: Proposed actions are executed (commits approved per `APPROVAL.md`) or explicitly declined.

## 4. Clean Up Worktree

Only **after** evaluation and any extraction are complete. The Worker's deliverable is the branch, so cleanup removes the worktree and keeps the branch:
1. Confirm the Worker's work is committed on `ccc/<task-slug>`: `git -C <worktree> status --short` lists nothing outside the Harness files. If it lists anything else, stop and ask the approver.
2. Remove the worktree with plain `git worktree remove <worktree>`. When it refuses, report why and stop; `--force` needs the approver.
3. Keep branch `ccc/<task-slug>`. Delete it only when the approver says so or `git branch --merged` lists it, using `git branch -d`.
4. Delete the `# ccc:<branch>` … `# /ccc:<branch>` block from the shared git exclude (`git rev-parse --git-path info/exclude`, run from the main checkout).

## 5. Record and report

Write the final report to a file: task result with commit hashes, gate outputs, the Harness composition (each Component and why it fit the task, or why `AGENTS.md` alone was enough), the verdict with the three evidence sentences, and what was left for the approver. Then deliver it and record the verdict:

```
${CLAUDE_PLUGIN_ROOT}/scripts/ccc-verdict.sh <main-checkout> ccc/<task-slug> <verdict> '{"completion":"…","contribution":"…","reuse":"…"}' <report-file>
```

**Done when**: `${CLAUDE_PLUGIN_ROOT}/scripts/ccc-gate.sh cleanup <main-checkout> ccc/<task-slug>` prints `ALL GATES PASS`, or the approver chose to keep the worktree.
