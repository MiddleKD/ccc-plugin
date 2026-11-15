#!/usr/bin/env bash
# ccc-gate.sh <stage> <worktree-or-main-checkout> [branch]
#
# Mechanical exit gates for /ccc:init and /ccc:promote. Prints one PASS/FAIL
# line per gate and exits 1 if any gate fails. Judgement stays in the skills;
# this script only checks facts a command can prove.
#
#   init     <worktree>               run before handing off to the task Worker
#   cleanup  <main-checkout> <branch> run after /ccc:promote cleanup
#   harness  <harness-dir> [worktree] run on a Harness folder before committing it;
#                                     with the source worktree, also checks for its project paths
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

check_declared() { # $1 = HARNESS.md, $2 = dir holding skills/agents/workflows/hooks
  local h=$1 d=$2 kind f base
  [ -f "$h" ] || return
  for kind in skills agents workflows hooks; do
    for f in "$d/$kind"/*; do
      [ -e "$f" ] || continue
      base=$(basename "$f"); base=${base%.md}; base=${base%.js}
      grep -q -F "$base" "$h" || fail "$kind/$(basename "$f") undeclared" "installed but not named in $(basename "$h") Components; promote would evaluate a different recipe"
    done
  done
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
      elif grep -q -E '\bargs\.[A-Za-z_]' "$f" && ! grep -q -E 'typeof args|Array\.isArray\(args|args \?\?|args\?\.' "$f"; then
        fail "workflow $(basename "$f")" "reads args.<field> without checking it; args is undefined when omitted and can arrive as free text, so check its shape or derive the input itself (e.g. list files with an agent)"
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

  # The worktree must belong to the recorded target, and the target must not be ccc-plugin.
  wt_main=$(cd "$(git -C "$w" rev-parse --path-format=absolute --git-common-dir)/.." && pwd -P)
  ccc_root=$(cd "$here/../../.." && pwd -P)
  tg=$(jq -r '.target // empty' "$j" 2>/dev/null)
  if [ "$wt_main" = "$ccc_root" ]; then
    fail "0 target" "this worktree belongs to ccc-plugin ($ccc_root), not the project the task is for; remove it and create it with git -C <target> worktree add"
  elif [ -z "$tg" ]; then
    fail "0 target" ".ccc.json needs 'target': the absolute path of the project repository"
  elif [ "$(cd "$tg" 2>/dev/null && pwd -P)" != "$wt_main" ]; then
    fail "0 target" "worktree belongs to $wt_main but .ccc.json target is $tg"
  else pass "0 target $tg"; fi

  b=$(jq -r '.base // empty' "$j" 2>/dev/null)
  main_head=$(git -C "$(git -C "$w" rev-parse --path-format=absolute --git-common-dir)/.." rev-parse HEAD 2>/dev/null)
  if [ -n "$b" ] && git -C "$w" cat-file -e "$b^{commit}" 2>/dev/null && ! git -C "$w" merge-base --is-ancestor "$b" "$main_head" 2>/dev/null \
     && [ "$(jq -r '.baseApprovedBy // empty' "$j")" = "" ]; then
    fail "2b base" "base $b is not in the main checkout's history (an earlier ccc/* branch?); recreate the worktree from HEAD, or record baseApprovedBy if the approver chose it"
  elif [ -n "$b" ] && git -C "$w" cat-file -e "$b^{commit}" 2>/dev/null; then pass "2b base $b"
  else fail "2b base" ".ccc.json needs 'base': the commit the worktree was created from"; fi

  h=$(jq -r '.harness // empty' "$j" 2>/dev/null)
  repo=$(cd "$here/../../.." && pwd)
  if [ -n "$h" ] && [ "$h" != instant ] && [ ! -f "$repo/harnesses/$h/HARNESS.md" ]; then
    fail "3 Harness" "harness '$h' is neither 'instant' nor a folder in $repo/harnesses/ (a saved draft is 'instant' with harnessName)"
  elif [ "$h" = instant ]; then
    if [ -s "$w/.claude/ccc/HARNESS.md" ] && grep -qi 'gate' "$w/.claude/ccc/HARNESS.md"; then
      pass "3 instant HARNESS.md with gates"
    else fail "3 Harness" "instant Harness needs .claude/ccc/HARNESS.md with gated steps"; fi
  elif [ -n "$h" ]; then pass "3 Harness $h"
  else fail "3 Harness" ".ccc.json needs a 'harness' field"; fi

  appr=$(jq -r '.approver // empty' "$j" 2>/dev/null)
  if [[ $appr == hc:* && -n "${HC_TERMINAL_ID:-}" && ${appr#hc:} == "$HC_TERMINAL_ID" ]]; then
    fail "3b approver" "approver is this Control Plane ($appr); use the terminal that sent the request"
  elif [[ $appr == user || $appr == hc:* ]]; then pass "3b approver $appr"
  else fail "3b approver" ".ccc.json needs 'approver': \"user\" or \"hc:<terminal>\" (see APPROVAL.md)"; fi

  if [ -f "$w/AGENTS.md" ] && grep -qx '@AGENTS.md' "$w/CLAUDE.md" 2>/dev/null; then pass "4 AGENTS.md imported"
  else fail "4 AGENTS.md" "AGENTS.md must exist and CLAUDE.md must contain the line @AGENTS.md"; fi
  if grep -qi 'commit' "$w/AGENTS.md" 2>/dev/null; then pass "4b AGENTS.md has Completion (commit)"
  else fail "4b AGENTS.md" "copy the Completion section from harnesses/_template/AGENTS.md"; fi

  if [ -f "$w/.claude/settings.local.json" ] && ! jq -e . "$w/.claude/settings.local.json" >/dev/null 2>&1; then
    fail "4c settings.local.json" "invalid JSON"
  fi
  check_components "$w/.claude"
  if [ "$h" = instant ]; then
    check_declared "$w/.claude/ccc/HARNESS.md" "$w/.claude"
    # Every inventory Plugin must be either used or listed as considered, so a
    # Control Plane cannot silently skip Plugins it never looked at.
    if [ -x "$here/ccc-inventory.sh" ] && [ -f "$w/.claude/ccc/HARNESS.md" ]; then
      miss=""
      for pl in $(jq -r '.plugins[].name' "$repo/.claude-plugin/marketplace.json"); do
        [ "$pl" = ccc ] && continue
        "$here/ccc-inventory.sh" "$pl" 2>/dev/null | grep -q '^  mod ' && continue
        grep -q -F "$pl" "$w/.claude/ccc/HARNESS.md" || miss="$miss $pl"
      done
      [ -n "$miss" ] && fail "3c Plugins considered" "HARNESS.md names neither use nor reason to skip for:$miss (add them under Components 'Considered, not used')"
    fi
  fi

  st=$(git -C "$w" status --short --untracked-files=all)
  if [ -z "$st" ]; then pass "5 git status clean"
  else fail "5 git status" "$(echo "$st" | head -5 | tr '\n' ' ')"; fi
  ex=$(git -C "$w" rev-parse --path-format=absolute --git-path info/exclude)
  if grep -qx "# ccc:$br" "$ex" && grep -qx "# /ccc:$br" "$ex"; then pass "5b exclude marker block"
  else fail "5b exclude" "wrap injected paths in '# ccc:$br' ... '# /ccc:$br' in $ex"; fi

  # Every Plugin the Harness relies on must be on in the worktree (not the main
  # checkout) and must have been seen by the Smoke Check Worker.
  for pl in $(jq -r '.plugins // [] | .[] | sub("@.*$"; "")' "$j" 2>/dev/null); do
    on=$(jq -r --arg k "$pl@" '[.enabledPlugins // {} | to_entries[] | select(.value==true and (.key|startswith($k)))] | length' \
         "$w/.claude/settings.local.json" "$HOME/.claude/settings.json" 2>/dev/null | awk "{s+=\$1} END {print s+0}")
    if [ "${on:-0}" -eq 0 ]; then fail "6b plugin $pl" "not enabled in $w/.claude/settings.local.json; run ccc-enable.sh $w $pl"
    elif ! jq -e --arg p "$pl:" '(.smokeCheckLoaded // []) | any(startswith($p))' "$j" >/dev/null 2>&1; then
      fail "6b plugin $pl" "Smoke Check did not record a $pl skill in smokeCheckLoaded; the Worker may not see it"
    else pass "6b plugin $pl loaded in Worker"; fi
  done
  mainloc="$(cd "$(git -C "$w" rev-parse --path-format=absolute --git-common-dir)/.." && pwd)/.claude/settings.local.json"
  if [ -f "$mainloc" ] && [ "$(git -C "$(dirname "$(dirname "$mainloc")")" ls-files --error-unmatch .claude/settings.local.json 2>/dev/null)" = "" ] \
     && jq -e '.enabledPlugins // {} | to_entries | any(.key|endswith("@ccc"))' "$mainloc" >/dev/null 2>&1; then
    fail "6c main checkout" "$mainloc enables ccc Plugins (a local install leaked there); move them with ccc-enable.sh"
  fi
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
  rec="$(git -C "$m" rev-parse --path-format=absolute --git-common-dir)/ccc/${br//\//_}.json"
  if git -C "$m" rev-parse --verify -q "refs/heads/$br" >/dev/null; then
    base=$(jq -r '.baseCommit // empty' "$rec" 2>/dev/null)
    [ -n "$base" ] || base=$(git -C "$m" merge-base "$br" HEAD 2>/dev/null)
    if [ "$(git -C "$m" rev-list --count "$base..$br" 2>/dev/null)" -gt 0 ]; then pass "branch $br kept with commits"
    else fail "branch $br" "has no commits beyond its base; the Worker's work was not committed"; fi
  else fail "branch $br" "deleted; the Worker's commits are the deliverable (delete only after the approver merges it)"; fi
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
  # Local Plugin installs must not outlive their worktree.
  orphans=$(jq -r '[.plugins | to_entries[] | .key as $k | .value[] | select(.scope=="local") | "\($k)\t\(.projectPath)"] | .[]' \
    "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null | while IFS=$'\t' read -r k pth; do
      case $pth in *.worktrees/*) [ -d "$pth" ] || printf '%s@%s ' "$k" "$pth";; esac; done)
  [ -n "$orphans" ] && fail "plugin records" "local installs left for removed worktrees: $orphans(run ccc-disable.sh before removing a worktree; to clear now, delete those entries from ~/.claude/plugins/installed_plugins.json)"
  # Every ccc/* worktree of this repo must have a handoff record; one without is an abandoned attempt.
  for wp in $(git -C "$m" worktree list --porcelain | awk '/^worktree /{w=$2} /^branch refs\/heads\/ccc\//{print w}'); do
    wb=$(git -C "$wp" branch --show-current 2>/dev/null)
    [ -f "$(git -C "$m" rev-parse --path-format=absolute --git-common-dir)/ccc/${wb//\//_}.json" ] \
      || fail "abandoned worktree" "$wp ($wb) has no handoff record; remove it and its branch if it holds no commits"
  done
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
  # Project facts leak in as repo-relative paths. With a source worktree given,
  # any path from its AGENTS.md that also appears in HARNESS.md is a leak.
  src=${branch_arg:-}
  if [ -n "$src" ] && [ -f "$src/AGENTS.md" ] && [ -f "$d/HARNESS.md" ]; then
    leaks=$(grep -o -E '`[A-Za-z0-9_./*-]+/[A-Za-z0-9_.*-]+`' "$src/AGENTS.md" | sort -u | while read -r tok; do
      grep -q -F "$tok" "$d/HARNESS.md" && printf '%s ' "$tok"; done)
    [ -n "$leaks" ] && fail "project paths" "HARNESS.md repeats project paths from AGENTS.md: $leaks- name the role instead and let init fill the path in AGENTS.md"
  fi
  hard=$(grep -rln -E '/home/|/tmp/|/Users/' "$d" 2>/dev/null)
  [ -n "$hard" ] && fail "absolute paths" "project or machine paths in: $hard"
  for f in "$d"/hooks/*; do
    [ -f "$f" ] || continue
    [[ $f == *.json ]] && continue
    [ -x "$f" ] && pass "hook $(basename "$f") executable" || fail "hook $(basename "$f")" "not executable"
  done
  check_components "$d"
  check_declared "$d/HARNESS.md" "$d"
  ;;
*) sed -n '2,11p' "$0"; exit 2 ;;
esac

[ $fails -eq 0 ] && echo "ALL GATES PASS" || echo "$fails GATE(S) FAILED"
[ $fails -eq 0 ]
