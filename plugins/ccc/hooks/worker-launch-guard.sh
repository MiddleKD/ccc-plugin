#!/usr/bin/env bash
# PreToolUse(Bash): stop a Control Plane from launching a Worker with a raw
# `hc run ... claude` into a git repository's main checkout. Workers start in a
# ccc worktree through ccc-handoff.sh, which /ccc:init runs after its gates.
# Only `hc run` commands that start `claude` and name a --cwd are checked.
input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // empty')
case $cmd in *"hc run"*claude*) ;; *) exit 0 ;; esac
case $cmd in *ccc-handoff.sh*) exit 0 ;; esac
# A Smoke Check Worker runs inside the worktree /ccc:init already made.
cwd=$(printf '%s' "$cmd" | grep -o -E -- '--cwd[= ]+("[^"]+"|[^ ]+)' | head -1 | sed -E 's/--cwd[= ]+//; s/^"//; s/"$//')
[ -n "$cwd" ] || exit 0
[ -d "$cwd" ] || exit 0
git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1 || exit 0
gd=$(git -C "$cwd" rev-parse --path-format=absolute --git-dir)
cd_=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir)
top=$(git -C "$cwd" rev-parse --show-toplevel)
if [ "$gd" != "$cd_" ] && [ -f "$top/.claude/.ccc.json" ]; then exit 0; fi
jq -n --arg d "$cwd" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",
  permissionDecisionReason:("ccc: \($d) is a repository checkout without a ccc Harness. Start Workers through /ccc:init, which creates a worktree and Harness and launches the Worker with ccc-handoff.sh.")}}'
