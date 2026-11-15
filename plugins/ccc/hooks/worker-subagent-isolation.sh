#!/usr/bin/env bash
# PreToolUse(Agent): inside a ccc Worker worktree, strip the isolation field
# from Agent calls and let them run. Any isolation mode hands the subagent a
# different copy of the code (a worktree under the main checkout, or a remote
# copy) that lacks the Worker's uncommitted changes and can be left behind.
# Some models emit the field even when told not to, so rewriting beats denying.
# Outside a ccc worktree this hook does nothing.
input=$(cat)
dir=${CLAUDE_PROJECT_DIR:-$(echo "$input" | jq -r '.cwd // empty')}
[ -f "$dir/.claude/.ccc.json" ] || exit 0
iso=$(echo "$input" | jq -r '.tool_input.isolation // empty')
[ -z "$iso" ] && exit 0
echo "$input" | jq --arg iso "$iso" '{hookSpecificOutput:{
  hookEventName:"PreToolUse",
  permissionDecision:"allow",
  permissionDecisionReason:("ccc: removed isolation=" + $iso + " so the subagent runs in the Worker worktree"),
  updatedInput:(.tool_input | del(.isolation)),
  additionalContext:("ccc removed isolation=\"" + $iso + "\" from this subagent call. It ran in your worktree and saw your uncommitted changes.")}}'
