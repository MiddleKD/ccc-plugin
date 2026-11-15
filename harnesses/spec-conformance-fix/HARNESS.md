# spec-conformance-fix

Harness for making a small parser conform to a written spec (RFC-style): decide ambiguous rules, test the boundary cases, fix.

## Fit

- **Use when**: a parser/validator with an existing test suite; the task asks how to treat ambiguous spec corners and to raise errors for invalid input.
- **Avoid when**: feature work without a spec, or performance work.

## Components

- **Enabled Plugins**: none. The Worker did not invoke `tdd` or `karpathy-guidelines`; the steps and gates in `AGENTS.md` did the work, so a kind heavier than `AGENTS.md` is not needed for a small single-module task.
- **Considered, not used**: `mattpocock-skills:tdd` and `andrej-karpathy-skills:karpathy-guidelines` (enabled in run 1, never invoked; add `tdd` back if the Worker skips red-first); `superpowers:test-driven-development` (overlaps tdd, its SessionStart hook is noisy, see CONFLICTS.md); `pyright-lsp:pyright` (pyright-langserver not installed); `mattpocock-skills:diagnosing-bugs` (not a bug report, a spec decision).
- **Considered, not used (other Plugins)**: `exa` (no web research needed), `ponytail` (overlaps karpathy-guidelines), `diagram-design` (no diagrams), `hallmark` (no web design), `hyperframes` (no video).
- No agents/workflows/hooks: the task is small and single-module.

## Situations

### Spec corner decisions → fix + boundary tests
1. Baseline. Gate: full test command green, count recorded.
2. Write the decisions down (one line per corner, in a test docstring or comment) before coding. Gate: each corner has a stated rule.
3. Write one failing test per corner, plus a regression guard for the neighbouring valid case. Gate: new tests run RED on the unfixed source for the right reason (not a wrong expected value).
4. Minimal fix. Gate: all new and old tests green; old tests unchanged.
5. Re-run new tests against base source. Gate: every non-guard test red there.
6. Commit on the branch. Gate: `git status --short` clean, diff touches only source and test files.

Traps:
- Name the skills at the step that uses them in AGENTS.md, or the Worker will not call them.
- Silently stripping whitespace: RFC 4180 says spaces are part of the field.
- Error messages without position, or off-by-one row numbers (decide 1-based and whether blank lines count; test it).
- Raising on blank lines or on a trailing newline.
- Changing the meaning of existing tests to make new rules pass.

## Init Decisions

- Test command goes in AGENTS.md. Set `PYTHONDONTWRITEBYTECODE=1` in worktree env.

## Smoke Check

- **Task**: run the test command and confirm env is set.
- **Pass criteria**: tests green.
