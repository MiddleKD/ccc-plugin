#!/usr/bin/env bash
# ccc-disable.sh <worktree>
#
# Undoes ccc-enable.sh: uninstalls every Plugin the worktree turned on at local
# scope, so no install record outlives the worktree. Run it from /ccc:promote
# before `git worktree remove`; once the directory is gone, `claude plugin
# uninstall --scope local` can no longer reach the record.
set -u
w=$(cd "${1:?worktree}" && pwd)
wl="$w/.claude/settings.local.json"
[ -f "$wl" ] || { echo "no $wl; nothing to disable"; exit 0; }
rc=0
for k in $(jq -r '.enabledPlugins // {} | to_entries[] | select(.value==true) | .key' "$wl"); do
  out=$(cd "$w" && claude plugin uninstall "$k" --scope local 2>&1) \
    && echo "disabled $k" || { echo "$out" | tail -1; rc=1; }
done
left=$(jq -r --arg w "$w" '[.plugins[][] | select(.scope=="local" and .projectPath==$w)] | length' \
  "$HOME/.claude/plugins/installed_plugins.json")
[ "$left" = 0 ] || { echo "still $left local install record(s) for $w"; rc=1; }
exit $rc
