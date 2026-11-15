# root-cause-bugfix

Harness for fixing a user-reported bug at its root cause, test-first, in a typed codebase, and sealing sibling symptoms of the same cause.

## Fit

- **Use when**: a symptom report (support ticket, issue) without a stack trace; a project with a test runner and a strict type checker; the fix is expected to be small but the cause may surface in several ways.
- **Avoid when**: feature work, large refactors, or performance regressions that need profiling.

## Components

- **Enabled Plugins**: `mattpocock-skills` (global) — `diagnosing-bugs` for the diagnosis loop, `tdd` for red-green.
- **Bundled Components**:
  - `hooks/verify-gates.sh` (Stop) — runs the commands in `$CCC_GATE_TEST` and `$CCC_GATE_TYPECHECK` and blocks ending a turn while either is red. Stack-agnostic: it holds no project commands. It skips an unset gate, and if both are unset it passes and says so on stderr. It lets the stop through on the second attempt (`stop_hook_active`) so it cannot loop.

## Situations

### Symptom report → root-cause fix
1. Baseline: run the full suite and type checker. Gate: record pass/xfail counts and type errors before touching code.
2. Reproduce: turn each reported symptom into a failing test that goes through the public API exactly as the report describes. Gate: the test run shows these tests FAILING with an assertion that matches the reported symptom (paste the failure). A failure caused by a wrong expected value is not a repro.
   If the report's exact steps do not fail, find the input sequence that does produce the reported observation (e.g. a negative argument on a different method) before going further.
3. Diagnose: name the invariant that is violated (e.g. "a line's quantity is always ≥ 1") and every code path that can break it. Gate: a written list of entry points that can violate the invariant.
4. Sibling sweep: add a failing test for each other path that breaks the same invariant (other inputs, boundary values, invalid arguments). Gate: those tests fail too before the fix.
5. Fix at the source of the invariant, not at the display layer. Gate: all new tests pass; no existing test changed in meaning.
6. Verify. Gate: re-run the new tests against the original source (`git show <base>:<file>` into the tree, run, restore). Every symptom test is red there, and a test that is green there is labelled a regression guard, not a repro. Then: full suite green, type checker strict clean, `git diff --stat` only touches the intended source and test files.
7. Commit on the branch. Gate: `git status --short` clean apart from intended files.

Traps:
- Filtering bad data in the presentation layer (hiding a zero line in a receipt) hides the symptom while totals stay wrong.
- Off-by-one comparisons (`< 0` vs `<= 0`) at the invariant boundary; test the exact boundary and one past it.
- Silently clamping invalid input vs. raising: decide explicitly, document it in a test, and handle zero/negative arguments.
- Mutating a list while iterating it; return right after deleting.
- A repro test that goes red only because its expected value is wrong, then green after the expectation is "corrected", proves nothing. The red-on-base re-run in step 6 catches this.
- The literal steps in a report can be harmless on the old code; the symptom may come from a sibling path (a negative argument passed to another method). Reproduce the observation, not only the narrative.
- Tracked build artifacts (e.g. bytecode caches) can show up in the diff; restore them before committing (Python: also set `PYTHONDONTWRITEBYTECODE=1` in worktree `env`).

## Init Decisions

- Keep project paths and commands in AGENTS.md.
- Set the project's gate commands in worktree `settings.local.json` `env`: `CCC_GATE_TEST` (full test suite) and `CCC_GATE_TYPECHECK` (strict type checker). Use paths that resolve from the worktree root, e.g. `".venv/bin/pytest -q"` / `".venv/bin/pyright"` or `"npm test"` / `"npx tsc --noEmit"`. Leave one unset only when the project has no such tool, and say so in AGENTS.md.
- Copy `hooks/verify-gates.sh` to `<worktree>/.claude/hooks/`, `chmod +x`, and register it as a Stop hook in worktree `settings.local.json` only (command `"$CLAUDE_PROJECT_DIR"/.claude/hooks/verify-gates.sh`). Reuse the exact command string if a global equivalent exists.
- Before Smoke Check, pipe `{}` into the hook from the worktree: it must exit 0 on the green baseline. If it prints the "unset" notice, the env was not written.

## Smoke Check

- **Task**: List visible skills and hooks; run the test and typecheck commands; confirm `CCC_GATE_TEST`/`CCC_GATE_TYPECHECK` are set in the Worker's env and the Stop hook is executable and returns 0 on a green tree without the "unset" notice.
- **Pass criteria**: `mattpocock-skills:diagnosing-bugs` and `mattpocock-skills:tdd` visible, Stop hook registered with both gate env vars set, suite and type checker green.
