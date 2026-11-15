# Worker Instructions (<harness-name>)

<!-- Control Plane replaces placeholders during /ccc:init and keeps only the active Situation section. -->

## Situation: <active-situation>

<Focused steps for this task.>

## Active Components

- <Only the Components selected for this run, with exact invocation names.>

## Working rules

- You are already in an isolated worktree. Start subagents without `isolation: worktree`; that option puts their copy under the main checkout and leaves it behind.

## Completion

- Leave 1-2 lines of Harness feedback in your final report (what helped, what got in the way).
- Commit your work on the current `ccc/<task-slug>` branch before reporting done; the branch is your deliverable and an uncommitted worktree is lost at cleanup. Exclude Harness files and generated artifacts.
- Then open a **draft PR** (a ready PR only if explicitly authorized at `init`). When the user forbade PRs or push, stop at the commit.
