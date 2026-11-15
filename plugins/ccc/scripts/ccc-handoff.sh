#!/usr/bin/env bash
# ccc-handoff.sh <worktree> <task-slug> <task text>
#
# The only way /ccc:init starts the task Worker. Refuses unless the init gates
# pass and the branch has no commits yet, then launches the Worker through hc
# and writes a handoff record outside the worktree, where /ccc:promote and the
# cleanup gate can find it after the worktree is gone.
set -u
here=$(cd "$(dirname "$0")" && pwd)
w=${1:?worktree}; slug=${2:?task-slug}; task=${3:?task text}
w=$(cd "$w" && pwd)
br=$(git -C "$w" branch --show-current)
rec_dir="$(git -C "$w" rev-parse --path-format=absolute --git-common-dir)/ccc"
rec="$rec_dir/${br//\//_}.json"

ccc_root=$(cd "$here/../../.." && pwd -P)
wt_main=$(cd "$(git -C "$w" rev-parse --path-format=absolute --git-common-dir)/.." && pwd -P)
if [ "$wt_main" = "$ccc_root" ]; then
  echo "handoff refused: $w is a worktree of ccc-plugin itself; the task's project is somewhere else"
  exit 1
fi
gate=$("$here/ccc-gate.sh" init "$w" 2>&1); rc=$?
echo "$gate"
if [ $rc -ne 0 ]; then echo "handoff refused: init gates fail"; exit 1; fi

base=$(jq -r '.base // empty' "$w/.claude/.ccc.json")
[ -n "$base" ] || { echo "handoff refused: .ccc.json needs 'base' (the commit the worktree was created from)"; exit 1; }
ahead=$(git -C "$w" rev-list --count "$base..HEAD" 2>/dev/null || echo 0)
if [ "${ahead:-0}" -gt 0 ]; then
  echo "handoff refused: $br already has $ahead commit(s); the Worker must start after the gates pass"
  exit 1
fi

reply=${HC_TERMINAL_ID:?run this from the Control Plane hc terminal}
agent=$(hc get "$reply" 2>/dev/null | jq -r '.status.app // empty')
if [ "$agent" != claude-code ]; then
  echo "handoff refused: HC_TERMINAL_ID=$reply is not a Claude Code session ($agent). Run this script from the Control Plane's own Bash tool, unwrapped, so Worker reports come back to the Control Plane."
  exit 1
fi
out=$(hc run --bg --name "$slug" --cwd "$w" claude \
  "$task Follow AGENTS.md. Report with hc send $reply when done or stuck." 2>&1) || { echo "$out"; exit 1; }
worker=$(echo "$out" | jq -r '.address // empty' 2>/dev/null)

mkdir -p "$rec_dir"
jq -n --arg br "$br" --arg w "$w" --arg worker "$worker" --arg cp "$reply" \
      --arg head "$base" --arg gate "$gate" \
      --slurpfile ccc "$w/.claude/.ccc.json" \
  --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{branch:$br, worktree:$w, worker:$worker, controlPlane:$cp, baseCommit:$head, handoffAt:$at, initGate:$gate, ccc:$ccc[0], promote:null}' > "$rec"
echo "handoff ok: Worker $worker started on $br"
echo "record: $rec"
echo "next: hc wait $worker; when it reports done, run /ccc:promote before removing anything"
