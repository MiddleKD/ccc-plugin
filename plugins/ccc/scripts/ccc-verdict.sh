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

if [ "$verdict" != none ]; then
  enc=$(cd "$m" && pwd -P | sed 's#[/.]#-#g')
  mem=~/.claude/projects/$enc/memory
  hits=$(grep -l -i -E 'harness' "$mem"/*.md 2>/dev/null | grep -v MEMORY.md | head -1)
  if [ -z "$hits" ]; then
    echo "verdict $verdict needs project affinity: write a project memory file under $mem naming the Harness and task shape, then rerun"
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
