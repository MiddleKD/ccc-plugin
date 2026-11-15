#!/usr/bin/env bash
# Stop hook: block ending a turn while the project's test or typecheck gate is red.
# Gate commands come from env (set by /ccc:init in worktree settings.local.json):
#   CCC_GATE_TEST       e.g. "npm test", ".venv/bin/pytest -q"
#   CCC_GATE_TYPECHECK  e.g. "npx tsc --noEmit", ".venv/bin/pyright"
# An unset gate is skipped. If both are unset, the hook passes and says so on stderr.
set -o pipefail
input=$(cat)
if echo "$input" | grep -q '"stop_hook_active": *true'; then exit 0; fi
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

if [ -z "${CCC_GATE_TEST:-}" ] && [ -z "${CCC_GATE_TYPECHECK:-}" ]; then
  echo "verify-gates: CCC_GATE_TEST and CCC_GATE_TYPECHECK are unset; no gates checked (passing)." >&2
  exit 0
fi

fail=0; report=""
run_gate() { # $1 label, $2 command
  [ -z "$2" ] && { report+="$1: skipped (unset)"$'\n'; return; }
  local out; out=$(bash -c "$2" 2>&1 | tail -8); local rc=$?
  if [ $rc -ne 0 ]; then fail=1; report+="$1 FAILED ($2, exit $rc):"$'\n'"$out"$'\n'; fi
}
run_gate test "${CCC_GATE_TEST:-}"
run_gate typecheck "${CCC_GATE_TYPECHECK:-}"

if [ $fail -ne 0 ]; then
  printf 'Gate failed. Fix before stopping (or explain in your report why it is red on purpose).\n%s' "$report" >&2
  exit 2
fi
exit 0
