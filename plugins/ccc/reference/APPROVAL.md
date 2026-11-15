# Approval

Some actions need an approver's yes before they happen: committing to `<ccc-repo>`, deleting a branch the Worker produced, removing a worktree with `--force`, and any push or PR beyond the draft PR the task allows.

## Who approves

Decide once at the start of `/ccc:init` and record it as `approver` in `<worktree>/.claude/.ccc.json`:

- **`"hc:<terminal>"`** when the request came through hc (the prompt arrived as `<hc from="<terminal> …">`). Nobody is watching this session's screen, so a dialog here blocks forever.
- **`"user"`** when a person typed the request in this session.

## How to ask

- **`hc:<terminal>`**: `hc send <terminal> "[approval] <action>: <what changes, with a diff summary or file list>. Reply 'approve' or 'reject'."`, then `hc wait --children any` until the reply arrives. Treat silence as a reject and leave the change uncommitted.
- **`user`**: ask in the conversation, with the same content.

Ask once per action and include enough for the approver to decide without opening files: the target path, the diff stat, and the one-line reason. Batch actions that belong together (a Harness folder and its `CONFLICTS.md` entry) into one request.

## What never needs approval

Writing inside the worktree, the Worker's commits on `ccc/<task-slug>`, project memory, and removing a clean worktree without `--force`.
