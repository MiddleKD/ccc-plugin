#!/usr/bin/env bash
# ccc-gate.sh <stage> <worktree-or-main-checkout> [branch]
#
# Mechanical exit gates for /ccc:init and /ccc:promote. Prints one PASS/FAIL
# line per gate and exits 1 if any gate fails. Judgement stays in the skills;
# this script only checks facts a command can prove.
#
#   init     <worktree>               run before handing off to the task Worker
#   cleanup  <main-checkout> <branch> run after /ccc:promote cleanup
#   harness  <harness-dir>            run on a Harness folder before committing it
set -u
stage=${1:-}; target=${2:-}; branch_arg=${3:-}
fails=0
here=$(cd "$(dirname "$0")" && pwd)
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n      %s\n' "$1" "$2"; fails=$((fails + 1)); }

frontmatter_field() { # $1 file, $2 field -> value or empty
  awk -v f="$2" 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit}
    NR>1 { if (index($0, f":")==1) { sub("^"f":[ ]*", ""); print; exit } }' "$1"
}

check_components() { # $1 = .claude dir
  local c=$1 f n d
  if [ -d "$c/skills" ]; then
    for f in "$c"/skills/*/SKILL.md; do
      [ -e "$f" ] || continue
      d=$(basename "$(dirname "$f")"); n=$(frontmatter_field "$f" name)
      if [ -z "$n" ] || [ -z "$(frontmatter_field "$f" description)" ]; then
        fail "skill $d frontmatter" "$f needs '---' on line 1 with name and description"
      elif [ "$n" != "$d" ]; then
        fail "skill $d name" "frontmatter name '$n' must equal directory name '$d'"
      else pass "skill $d"; fi
    done
  fi
  if [ -d "$c/agents" ]; then
    for f in "$c"/agents/*.md; do
      [ -e "$f" ] || continue
      n=$(frontmatter_field "$f" name)
      if [ -z "$n" ] || [ -z "$(frontmatter_field "$f" description)" ]; then
        fail "agent $(basename "$f")" "needs '---' on line 1 with name and description (else Claude Code skips it silently)"
      elif [[ $n == -* || $n == *:* ]]; then
        fail "agent $(basename "$f")" "name '$n' must not start with '-' or contain ':'"
      else pass "agent $n"; fi
    done
  fi
  if [ -d "$c/workflows" ]; then
    for f in "$c"/workflows/*.js; do
      [ -e "$f" ] || continue
      if ! grep -v -E '^\s*(//.*)?$' "$f" | head -1 | grep -q '^export const meta = {'; then
        fail "workflow $(basename "$f")" "first statement must be 'export const meta = {'"
      elif ! awk '/^export const meta = \{/{m=1} m{print} m&&/^\}/{exit}' "$f" | grep -q -E "^\s*name:\s*['\"]" \
        || ! awk '/^export const meta = \{/{m=1} m{print} m&&/^\}/{exit}' "$f" | grep -q -E "^\s*description:\s*['\"]"; then
        fail "workflow $(basename "$f")" "meta needs literal name and description strings"
      elif grep -q -E 'Date\.now\(\)|Math\.random\(\)|new Date\(\)' "$f"; then
        fail "workflow $(basename "$f")" "Date.now/Math.random/new Date() throw inside workflows; pass values via args"
      elif command -v node >/dev/null && ! err=$(node "$here/wf-check.mjs" "$f" 2>&1); then
        fail "workflow $(basename "$f")" "syntax error: $err"
      else pass "workflow $(basename "$f")"; fi
    done
  fi
  if [ -f "$c/settings.local.json" ]; then
    local cmds
    cmds=$(jq -r '.hooks // {} | .[][] | .hooks[]? | select(.type=="command") | .command' "$c/settings.local.json" 2>/dev/null)
    while IFS= read -r cmd; do
      [ -z "$cmd" ] && continue
      local p=${cmd//\$CLAUDE_PROJECT_DIR/$target}; p=${p//\$\{CLAUDE_PROJECT_DIR\}/$target}; p=${p//\"/}
      p=${p%% *}
      if [[ $p == /* || $p == ./* ]]; then
        if [ ! -f "$p" ]; then fail "hook $cmd" "script $p does not exist"
        elif [ ! -x "$p" ]; then fail "hook $cmd" "script $p is not executable (chmod +x)"
        else
          ev=$(jq -r --arg c "$cmd" '.hooks | to_entries[] | select(any(.value[].hooks[]?; .command == $c)) | .key' "$c/settings.local.json" | head -1)
          if [[ $ev =~ ^(Stop|SubagentStop|PreToolUse|UserPromptSubmit|TaskCompleted)$ ]] && ! grep -q -E 'exit 2|exit \$\{?[A-Za-z_]*\}?|"decision" *: *"block"' "$p"; then
            fail "hook $(basename "$p") ($ev)" "never exits 2 or prints {\"decision\":\"block\"}; any other failure exit is non-blocking, so this hook enforces nothing"
          elif [[ $ev =~ ^(Stop|SubagentStop)$ ]] && ! grep -q 'stop_hook_active' "$p"; then
            fail "hook $(basename "$p") ($ev)" "must exit 0 when stop_hook_active is true, or it can loop"
          else pass "hook $(basename "$p")${ev:+ ($ev)}"; fi
        fi
      fi
    done <<< "$cmds"
    if jq -e '.disableAllHooks == true' "$c/settings.local.json" >/dev/null 2>&1; then
      fail "disableAllHooks" "never set it; it turns off herdr state hooks"
    fi
  fi
}

case $stage in
init)
  w=$target
  [ -d "$w" ] || { echo "no such worktree: $w"; exit 2; }
  br=$(git -C "$w" branch --show-current 2>/dev/null)
  if [[ $br == ccc/* ]] && git -C "$w" worktree list --porcelain | grep -qx "worktree $(cd "$w" && pwd -P)"; then
    pass "1 worktree on $br"
  else fail "1 worktree" "$w must be a linked worktree on a ccc/<task-slug> branch (got '$br')"; fi
  if [ "$(git -C "$w" rev-parse --git-dir)" = "$(git -C "$w" rev-parse --git-common-dir)" ]; then
    fail "1 linked" "$w is the main checkout; the Worker must run in a linked worktree"
  fi

  j=$w/.claude/.ccc.json
  if jq -e . "$j" >/dev/null 2>&1; then pass "2 .ccc.json"; else fail "2 .ccc.json" "$j missing or invalid JSON"; fi

  b=$(jq -r '.base // empty' "$j" 2>/dev/null)
  if [ -n "$b" ] && git -C "$w" cat-file -e "$b^{commit}" 2>/dev/null; then pass "2b base $b"
  else fail "2b base" ".ccc.json needs 'base': the commit the worktree was created from"; fi

  h=$(jq -r '.harness // empty' "$j" 2>/dev/null)
  if [ "$h" = instant ]; then
    if [ -s "$w/.claude/ccc/HARNESS.md" ] && grep -qi 'gate' "$w/.claude/ccc/HARNESS.md"; then
      pass "3 instant HARNESS.md with gates"
    else fail "3 Harness" "instant Harness needs .claude/ccc/HARNESS.md with gated steps"; fi
  elif [ -n "$h" ]; then pass "3 Harness $h"
  else fail "3 Harness" ".ccc.json needs a 'harness' field"; fi

  appr=$(jq -r '.approver // empty' "$j" 2>/dev/null)
  if [[ $appr == user || $appr == hc:* ]]; then pass "3b approver $appr"
  else fail "3b approver" ".ccc.json needs 'approver': \"user\" or \"hc:<terminal>\" (see APPROVAL.md)"; fi

  if [ -f "$w/AGENTS.md" ] && grep -qx '@AGENTS.md' "$w/CLAUDE.md" 2>/dev/null; then pass "4 AGENTS.md imported"
  else fail "4 AGENTS.md" "AGENTS.md must exist and CLAUDE.md must contain the line @AGENTS.md"; fi
  if grep -qi 'commit' "$w/AGENTS.md" 2>/dev/null; then pass "4b AGENTS.md has Completion (commit)"
  else fail "4b AGENTS.md" "copy the Completion section from harnesses/_template/AGENTS.md"; fi

  if [ -f "$w/.claude/settings.local.json" ] && ! jq -e . "$w/.claude/settings.local.json" >/dev/null 2>&1; then
    fail "4c settings.local.json" "invalid JSON"
  fi
  check_components "$w/.claude"

  st=$(git -C "$w" status --short --untracked-files=all)
  if [ -z "$st" ]; then pass "5 git status clean"
  else fail "5 git status" "$(echo "$st" | head -5 | tr '\n' ' ')"; fi
  ex=$(git -C "$w" rev-parse --path-format=absolute --git-path info/exclude)
  if grep -qx "# ccc:$br" "$ex" && grep -qx "# /ccc:$br" "$ex"; then pass "5b exclude marker block"
  else fail "5b exclude" "wrap injected paths in '# ccc:$br' ... '# /ccc:$br' in $ex"; fi

  if jq -e '[.smokeCheckNotes] | flatten | map(tostring) | any(test("pass"; "i"))' "$j" >/dev/null 2>&1; then
    pass "6 Smoke Check pass recorded"
  else fail "6 Smoke Check" "record a pass in .ccc.json smokeCheckNotes"; fi
  ;;
cleanup)
  m=$target; br=$branch_arg
  [ -n "$br" ] || { echo "usage: ccc-gate.sh cleanup <main-checkout> <branch>"; exit 2; }
  if git -C "$m" worktree list --porcelain | grep -A2 '^worktree' | grep -qx "branch refs/heads/$br"; then
    fail "worktree removed" "a worktree for $br still exists"
  else pass "worktree removed"; fi
  if git -C "$m" rev-parse --verify -q "refs/heads/$br" >/dev/null; then
    base=$(git -C "$m" merge-base "$br" HEAD 2>/dev/null)
    if [ "$(git -C "$m" rev-list --count "$base..$br" 2>/dev/null)" -gt 0 ]; then pass "branch $br kept with commits"
    else fail "branch $br" "has no commits beyond its base; the Worker's work was not committed"; fi
  elif git -C "$m" branch --merged | grep -q " $br\$"; then pass "branch $br merged"
  else fail "branch $br" "deleted before merge; the deliverable is lost"; fi
  rec="$(git -C "$m" rev-parse --path-format=absolute --git-common-dir)/ccc/${br//\//_}.json"
  if [ ! -f "$rec" ]; then
    fail "handoff record" "$rec missing: the Worker was not started through ccc-handoff.sh"
  else
    pass "handoff record"
    if jq -e '.promote | type == "object" and has("verdict") and has("reportedTo")' "$rec" >/dev/null 2>&1; then
      pass "promote verdict recorded ($(jq -r .promote.verdict "$rec"))"
    else fail "promote verdict" "run /ccc:promote; it writes .promote {verdict, criteria, reportedTo} into $rec"; fi
  fi
  ex=$(git -C "$m" rev-parse --path-format=absolute --git-path info/exclude)
  if grep -qx "# ccc:$br" "$ex"; then fail "exclude block" "remove '# ccc:$br' ... '# /ccc:$br' from $ex"
  else pass "exclude block removed"; fi
  stray=$(git -C "$m" worktree list --porcelain | awk '/^worktree /{print $2}' | grep '/\.claude/worktrees/' || true)
  if [ -n "$stray" ]; then
    fail "subagent worktrees" "left by an isolation:worktree subagent: $stray (inspect, then git worktree remove)"
  fi
  st=$(git -C "$m" status --short)
  if [ -z "$st" ]; then pass "main checkout clean"
  else fail "main checkout" "$(echo "$st" | head -5 | tr '\n' ' ')"; fi
  ;;
harness)
  d=${target%/}
  [ -f "$d/HARNESS.md" ] || { fail "HARNESS.md" "$d/HARNESS.md missing"; }
  if [ -f "$d/HARNESS.md" ]; then
    n=$(wc -l < "$d/HARNESS.md")
    if [ "$n" -le 200 ]; then pass "HARNESS.md $n lines"; else fail "HARNESS.md length" "$n lines; limit 200"; fi
    for sec in '## Fit' '## Components' '## Situations' '## Init Decisions' '## Smoke Check'; do
      grep -q "^$sec" "$d/HARNESS.md" || fail "HARNESS.md section" "missing '$sec'"
    done
    grep -qi 'gate' "$d/HARNESS.md" && pass "HARNESS.md has gates" || fail "HARNESS.md gates" "no step names a gate"
    ph=$(sed 's/`[^`]*`//g' "$d/HARNESS.md" | grep -n -E '<[A-Za-z][^>]*>' | head -3)
    [ -n "$ph" ] && fail "HARNESS.md placeholders" "template text left outside code spans: $ph"
  fi
  hard=$(grep -rln -E '/home/|/tmp/|/Users/' "$d" 2>/dev/null)
  [ -n "$hard" ] && fail "absolute paths" "project or machine paths in: $hard"
  for f in "$d"/hooks/*; do
    [ -f "$f" ] || continue
    [[ $f == *.json ]] && continue
    [ -x "$f" ] && pass "hook $(basename "$f") executable" || fail "hook $(basename "$f")" "not executable"
  done
  check_components "$d"
  ;;
*) sed -n '2,11p' "$0"; exit 2 ;;
esac

[ $fails -eq 0 ] && echo "ALL GATES PASS" || echo "$fails GATE(S) FAILED"
[ $fails -eq 0 ]
