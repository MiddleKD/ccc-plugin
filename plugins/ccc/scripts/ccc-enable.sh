#!/usr/bin/env bash
# ccc-enable.sh <worktree> <plugin> [plugin ...]
#
# Turns on ccc marketplace Plugins for one worktree only. `claude plugin install
# --scope local` run inside a linked worktree writes enabledPlugins into the
# MAIN checkout's .claude/settings.local.json, so the worktree never sees it and
# the main checkout gets a stray file. This installs, then moves the entries
# into <worktree>/.claude/settings.local.json and restores the main checkout.
set -u
w=$(cd "${1:?worktree}" && pwd); shift
[ $# -gt 0 ] || { echo "usage: ccc-enable.sh <worktree> <plugin> [plugin ...]"; exit 2; }
main=$(cd "$(git -C "$w" rev-parse --path-format=absolute --git-common-dir)/.." && pwd)
ml="$main/.claude/settings.local.json"; wl="$w/.claude/settings.local.json"
mkdir -p "$w/.claude"; [ -f "$wl" ] || echo '{}' > "$wl"
had_main_dir=0; [ -d "$main/.claude" ] && had_main_dir=1
before=$(cat "$ml" 2>/dev/null || echo '{}')

rc=0
for p in "$@"; do
  if jq -e --arg p "$p@" '.enabledPlugins // {} | to_entries | any(.value == true and (.key | startswith($p)))' "$HOME/.claude/settings.json" >/dev/null 2>&1; then
    echo "skipped $p: already on globally; the Worker sees it without a local install"
    continue
  fi
  out=$(cd "$w" && claude plugin install "$p@ccc" --scope local 2>&1) || { echo "$out" | tail -2; rc=1; continue; }
  # Move whichever file got the entry into the worktree file.
  for f in "$ml" "$wl"; do
    if [ -f "$f" ] && jq -e --arg k "$p@ccc" '.enabledPlugins[$k] == true' "$f" >/dev/null 2>&1; then
      jq --arg k "$p@ccc" '.enabledPlugins[$k] = true' "$wl" > "$wl.tmp" && mv "$wl.tmp" "$wl"
    fi
  done
  echo "enabled $p@ccc in $wl"
done

# Restore the main checkout's local settings to what they were.
if [ -f "$ml" ]; then
  echo "$before" | jq . > "$ml"
  [ "$before" = '{}' ] && rm -f "$ml"
fi
[ $had_main_dir = 0 ] && rmdir "$main/.claude" 2>/dev/null

jq -e . "$wl" >/dev/null || { echo "invalid JSON in $wl"; exit 1; }
exit $rc
