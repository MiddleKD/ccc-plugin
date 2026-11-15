# documentation-release-audit

Repeatable audit of a Markdown documentation corpus before a release.

## Fit

- **Use when**: a release requires broad docs integrity checks against local CLI reference material.
- **Avoid when**: editing a single page without corpus-wide validation or when push/PR is required but forbidden.

## Components

- **Enabled Plugins**: none. Avoids unrelated skills and hook behavior; task uses only precise local checks.
- **AGENTS.md** — ordered audit procedure and mandatory gates; appropriate because this is a single-worker, bounded audit rather than a repeatable parallel subtask or a reusable invoked procedure.
- **Worker-provided independent final review** — a fresh-context reviewer without isolation verifies corpus coverage, links, and supported options; the ccc isolation-removal hook keeps the reviewer on the same worktree.

## Situations

### Release documentation corpus audit
1. Enumerate `<docs root>/**/*.md` dynamically; count content documents separately from `<audit report>`. Gate: record exact count and every document in the report.
2. Review the prior audit and scan each content document for TODO/FIXME/TBD and deprecated notices; record exact evidence and reasoned disposition in `<audit report>`. Gate: one evidence row per content document, no undocumented markers.
3. Check local destinations and heading anchors in every Markdown document, repairing broken references. Gate: validator reports zero broken local links/anchors (including the report).
4. Scan CLI options only in command contexts against `<canonical CLI flag list>`; fix unsupported options without changing prose tokens or inventing features. Gate: zero unsupported command-context flags.
5. Run an independent read-only corpus review without isolation, run `git diff --check`, inspect the full diff, and commit only intended docs. Gate: independent review has no unresolved findings; clean status after commit. Do not push or create a PR when the task forbids them.

Traps: derive counts every run; exclude the report from content-marker evidence while still checking it as Markdown for links; distinguish command-context flags from prose, placeholders, and unrelated grammar; preserve meaningful author TODOs and specific historical deprecation warnings with evidence rather than deleting or inventing content.

## Init Decisions

- During init, resolve `<docs root>`, `<audit report>`, and `<canonical CLI flag list>` from the target project, then place their concrete paths and relevant task commands in `AGENTS.md`.
- Use project-provided link/flag checking tools when available; otherwise use focused inline checks without adding dependencies.
- No Plugins, custom scripts, or settings hooks are needed; use the independent Agent review at the final gate.

## Smoke Check

- **Task**: list all Markdown docs, inspect the canonical CLI flag list, and report counts without editing files; verify the audit instructions distinguish report vs content scope.
- **Pass criteria**: Worker sees these instructions and reports matching live file and flag counts, no edits.
