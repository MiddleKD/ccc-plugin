#!/usr/bin/env bash
# ccc-verdict.sh <main-checkout> <branch> <verdict> <criteria-json> <report-file>
#
# Records the /ccc:promote result in the handoff record and delivers the final
# report to the approver. <verdict> is promoted | updated | affinity-only | none.
# <criteria-json> is {"completion":"...","contribution":"...","reuse":"..."},
# one evidence sentence each. <report-file> holds the final report text.
set -u
m=${1:?main checkout}; br=${2:?branch}; verdict=${3:?verdict}; crit=${4:?criteria json}; report=${5:?report file}
case $verdict in promoted|updated|affinity-only|none) ;; *) echo "verdict must be promoted|updated|affinity-only|none"; exit 2;; esac
echo "$crit" | jq -e 'has("completion") and has("contribution") and has("reuse")' >/dev/null \
  || { echo "criteria-json needs completion, contribution, reuse"; exit 2; }
[ -s "$report" ] || { echo "report file is empty"; exit 2; }

rec="$(git -C "$m" rev-parse --path-format=absolute --git-common-dir)/ccc/${br//\//_}.json"
[ -f "$rec" ] || { echo "no handoff record at $rec; was the Worker started with ccc-handoff.sh?"; exit 1; }

# promoted/updated mean a folder in <ccc-repo>/harnesses/ was written and passes the harness gate.
here=$(cd "$(dirname "$0")" && pwd); repo=$(cd "$here/../../.." && pwd)
if [ "$verdict" = promoted ] || [ "$verdict" = updated ]; then
  name=$(jq -r '.ccc.harness' "$rec"); [ "$name" = instant ] && name=$(jq -r '.ccc.harnessName // empty' "$rec")
  hd="$repo/harnesses/$name"
  [ -n "$name" ] && [ -f "$hd/HARNESS.md" ] || { echo "verdict $verdict needs $hd/HARNESS.md: write the generalized Harness there first (a saved draft alone is affinity-only)"; exit 1; }
  "$here/ccc-gate.sh" harness "$hd" >/dev/null || { echo "verdict $verdict: $hd fails the harness gate; run ccc-gate.sh harness $hd"; exit 1; }
  since=$(jq -r '.handoffAt // empty' "$rec")
  [ -n "$since" ] || { echo "handoff record has no handoffAt; cannot tell whether harnesses/$name changed in this run"; exit 1; }
  if [ -z "$(git -C "$repo" status --porcelain -- "harnesses/$name")" ] && [ -z "$(git -C "$repo" log -1 --since="$since" --format=%h -- "harnesses/$name")" ]; then
    echo "verdict $verdict but harnesses/$name has no new change; write the update, ask the approver, then commit"; exit 1
  fi
fi

if [ "$verdict" != none ]; then
  enc=$(cd "$m" && pwd -P | sed 's#[/.]#-#g')
  mem=~/.claude/projects/$enc/memory
  hits=$(grep -l -i -E 'harness' "$mem"/*.md 2>/dev/null | grep -v MEMORY.md | head -1)
  if [ -z "$hits" ]; then
    echo "verdict $verdict needs project affinity: write a project memory file under $mem naming the Harness and task shape, then rerun"
    exit 1
  fi
fi

# Keep the Instant Harness draft outside the worktree so the next run of the
# same task shape starts from it instead of rebuilding the recipe.
draft_note=""
if [ "$(jq -r '.ccc.harness // empty' "$rec")" = instant ]; then
  wt=$(jq -r '.worktree' "$rec")
  slug=$(jq -r '.ccc.harnessName // empty' "$rec")
  [ -n "$slug" ] || slug=$(sed -n '1s/^# *\(instant: *\)\{0,1\}//p' "$wt/.claude/ccc/HARNESS.md" 2>/dev/null | tr ' A-Z' '-a-z' | tr -cd 'a-z0-9-')
  if [ -d "$wt/.claude/ccc" ] && [ -n "$slug" ]; then
    dd="$(git -C "$m" rev-parse --path-format=absolute --git-common-dir)/ccc/drafts/$slug"
    mkdir -p "$dd"
    cp -r "$wt/.claude/ccc/." "$dd/"
    for k in skills agents workflows hooks; do [ -d "$wt/.claude/$k" ] && mkdir -p "$dd/$k" && cp -r "$wt/.claude/$k/." "$dd/$k/"; done
    runs=$(( $(cat "$dd/.runs" 2>/dev/null || echo 0) + 1 )); echo $runs > "$dd/.runs"
    draft_note="draft saved: $dd (run $runs of this shape)"
  elif [ ! -d "$wt" ]; then
    echo "worktree $wt is gone: run ccc-verdict.sh before removing the worktree, so the Instant Harness draft is kept"
    exit 1
  fi
fi

approver=$(jq -r '.ccc.approver // empty' "$rec")
case $approver in
  hc:*) hc send "${approver#hc:}" "$(cat "$report")" >/dev/null || { echo "hc send to $approver failed"; exit 1; } ;;
  user) echo "approver is user: print the report below in the conversation" ; cat "$report" ;;
  *) echo "record has no approver"; exit 1 ;;
esac

tmp=$(mktemp)
jq --arg v "$verdict" --argjson c "$crit" --arg to "$approver" \
  '.promote = {verdict:$v, criteria:$c, reportedTo:$to}' "$rec" > "$tmp" && mv "$tmp" "$rec"
echo "verdict $verdict recorded in $rec, report delivered to $approver"
[ -n "$draft_note" ] && echo "$draft_note"
