#!/usr/bin/env bash
# ccc-inventory.sh [plugin ...]
#
# Lists every Component (skills, agents, commands, workflows, hooks, MCP, LSP)
# of the ccc marketplace Plugins, one line per Component with its description.
# Installed Plugins are read from the plugin cache; the rest are fetched once
# into ~/.cache/ccc/plugins/<name>/ from their marketplace source, so /ccc:init
# can choose a Plugin it has never installed. With names, lists only those.
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../.." && pwd)
mp="$repo/.claude-plugin/marketplace.json"
store=${CCC_PLUGIN_STORE:-$HOME/.cache/ccc/plugins}
cache="$HOME/.claude/plugins/cache/ccc"
mkdir -p "$store"

desc() { # $1 file -> frontmatter description, one line (handles folded > and | blocks)
  awk 'NR==1&&$0!="---"{exit} NR>1&&$0=="---"{exit}
       inblk && /^[ \t]/ {sub(/^[ \t]+/,""); out=out" "$0; next}
       inblk {exit}
       NR>1&&/^description:/{sub(/^description:[ ]*/,""); if ($0 ~ /^[>|][-+]?$/) {inblk=1; next} gsub(/^"|"$/,""); out=$0; exit}
       END{sub(/^ /,"",out); print out}' "$1" | cut -c1-160
}

skill_dirs() { # $1 root -> skill directories, honouring plugin.json "skills"
  local r=$1 pj="$1/.claude-plugin/plugin.json"
  if [ -f "$pj" ] && [ "$(jq -r '.skills | type' "$pj")" = array ]; then
    jq -r '.skills[]' "$pj" | while read -r d; do echo "$r/${d#./}"; done
  else
    for d in "$r"/skills/*/ "$r"/*/; do [ -f "$d/SKILL.md" ] && echo "${d%/}"; done
    [ -f "$r/SKILL.md" ] && echo "$r"
  fi
}

fetch() { # $1 name -> prints plugin root dir
  local name=$1 src kind dir
  src=$(jq -c --arg n "$name" '.plugins[] | select(.name==$n) | .source' "$mp")
  # 1. installed copy
  if [ -d "$cache/$name" ]; then
    dir=$(ls -d "$cache/$name"/*/ 2>/dev/null | sort -V | tail -1)
    [ -n "$dir" ] && { echo "${dir%/}"; return; }
  fi
  # 2. local source inside this repo
  if [[ $src == \"./* ]]; then echo "$repo/$(echo "$src" | jq -r . | sed 's#^\./##')"; return; fi
  # 3. fetched copy
  dir="$store/$name"
  if [ ! -d "$dir/root" ]; then
    rm -rf "$dir"; mkdir -p "$dir"
    kind=$(echo "$src" | jq -r '.source')
    case $kind in
      github) git clone -q --depth 1 "https://github.com/$(echo "$src" | jq -r .repo).git" "$dir/root" ;;
      url) git clone -q --depth 1 $(echo "$src" | jq -r 'if .ref then "--branch " + .ref else "" end') "$(echo "$src" | jq -r .url)" "$dir/root" ;;
      git-subdir)
        git clone -q --depth 1 $(echo "$src" | jq -r 'if .ref then "--branch " + .ref else "" end') "$(echo "$src" | jq -r .url)" "$dir/src" \
          && ln -s "$dir/src/$(echo "$src" | jq -r .path)" "$dir/root" ;;
      archive)
        curl -sL -o "$dir/p.zip" "$(echo "$src" | jq -r .url)" \
          && echo "$(echo "$src" | jq -r .sha256)  $dir/p.zip" | sha256sum -c --quiet \
          && mkdir -p "$dir/root" && python3 -I -m zipfile -e "$dir/p.zip" "$dir/root" ;;
      *) echo "unsupported source $kind" >&2; return 1 ;;
    esac || { echo "fetch failed: $name" >&2; return 1; }
  fi
  echo "$dir/root"
}

list() { # $1 name, $2 root
  local n=$1 r=$2 f
  local pj="$r/.claude-plugin/plugin.json"
  local mdesc; mdesc=$(jq -r --arg n "$n" '.plugins[] | select(.name==$n) | .description // ""' "$mp" | cut -c1-140)
  local en; en=$(jq -r --arg n "$n" '[.enabledPlugins // {} | to_entries[] | select(.value == true and (.key | startswith($n + "@"))) | .key] | if length > 0 then "on as " + join(",") else "off" end' "$HOME/.claude/settings.json")
  echo "## $n  (global: $en) — $mdesc"
  skill_dirs "$r" | sort -u | while read -r d; do
    [ -f "$d/SKILL.md" ] && echo "  skill    $n:$(basename "$d") — $(desc "$d/SKILL.md")"
  done
  for f in "$r"/agents/*.md; do [ -f "$f" ] && echo "  agent    $n:$(basename "$f" .md) — $(desc "$f")"; done
  for f in "$r"/commands/*.md; do [ -f "$f" ] && echo "  command  /$n:$(basename "$f" .md) — $(desc "$f")"; done
  for f in "$r"/workflows/*.js; do [ -f "$f" ] && echo "  workflow /$(basename "$f" .js)"; done
  local hj="$r/hooks/hooks.json"
  [ -f "$pj" ] && [ "$(jq -r '.hooks // empty | type' "$pj")" = string ] && hj="$r/$(jq -r .hooks "$pj")"
  if [ -f "$hj" ]; then
    if jq -e '.modules' "$hj" >/dev/null 2>&1; then echo "  mod      UI mod (changes the Claude Code interface, not Claude's behaviour)"
    else jq -r '.hooks // {} | to_entries[] | "  hook     \(.key)\(if .value[0].matcher then "(" + .value[0].matcher + ")" else "" end)"' "$hj"; fi
  fi
  { for f in "$r/.mcp.json" "$r/mcp.json"; do [ -f "$f" ] && jq -r '(.mcpServers // .) | keys[] | "  mcp      " + .' "$f"; done
    [ -f "$pj" ] && jq -r '.mcpServers // {} | if type=="object" then keys[] | "  mcp      " + . else empty end' "$pj"; } | sort -u
  { [ -f "$pj" ] && jq -r '.lspServers // {} | to_entries[] | "  lsp      \(.key) (needs \(.value.command))"' "$pj"
  jq -r --arg n "$n" '.plugins[] | select(.name==$n) | .lspServers // {} | to_entries[] | "  lsp      \(.key) (needs \(.value.command))"' "$mp"; } | sort -u
}

names=("$@")
[ ${#names[@]} -eq 0 ] && mapfile -t names < <(jq -r '.plugins[].name' "$mp")
for n in "${names[@]}"; do
  root=$(fetch "$n") || continue
  list "$n" "$root"
done
