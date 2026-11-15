#!/usr/bin/env bash
# PreToolUse(Agent): in a ccc Worker worktree, deny subagents that ask for
# isolation. Any isolation mode hands the subagent a different copy of the
# code (a worktree under the main checkout, or a remote copy) that lacks the
# Worker's uncommitted changes and can be left behind after cleanup.
# Outside a ccc worktree this hook does nothing.
input=$(cat)
dir=${CLAUDE_PROJECT_DIR:-$(echo "$input" | jq -r '.cwd // empty')}
[ -f "$dir/.claude/.ccc.json" ] || exit 0
iso=$(echo "$input" | jq -r '.tool_input.isolation // empty')
[ -z "$iso" ] && exit 0
jq -n --arg iso "$iso" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",
  permissionDecisionReason:("ccc Worker: start this subagent again without the isolation field (got \"" + $iso + "\"). You are already in an isolated worktree; isolation would give the subagent a copy without your uncommitted changes.")}}'
