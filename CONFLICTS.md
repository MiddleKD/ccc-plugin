# Conflict Rules

Single record of observed Component overlaps across Plugins, Harnesses, and settings layers, and which takes precedence.

Format per entry:
```
- **<Component A> vs <Component B>** (kind: skill|agent|hook|workflow|mcp|lsp)
  - Scope: <layers involved, e.g. mattpocock-skills vs superpowers>
  - Precedence: <winner and how to enforce it in worktree local settings or AGENTS.md>
  - Observed: <YYYY-MM-DD, brief note from Smoke Check or Worker session>
```

---

- **mattpocock-skills vs superpowers** (kind: skill)
  - Scope: tdd ↔ test-driven-development, diagnosing-bugs ↔ systematic-debugging, code-review ↔ requesting-code-review, grilling ↔ brainstorming
  - Precedence: Both are Plugin skills, so `skillOverrides` cannot hide either. Enable only one Plugin per worktree, or copy the chosen skill into the Harness and disable both Plugins.
  - Observed: 2026-11-15, layer test. With both on, the Worker saw both TDD and both debugging skills.
- **superpowers using-superpowers vs any Harness AGENTS.md** (kind: hook)
  - Scope: superpowers SessionStart hook injects "You have superpowers" and pushes `superpowers:using-superpowers` on every prompt
  - Precedence: The hook cannot be turned off individually. When AGENTS.md names a non-superpowers skill, leave superpowers disabled.
  - Observed: 2026-11-15, a one-word reply still loaded `superpowers:using-superpowers` first.
- **ponytail vs superpowers** (kind: hook)
  - Scope: both inject SessionStart context
  - Precedence: No collision found. Both load ("PONYTAIL MODE ACTIVE", "You have superpowers").
  - Observed: 2026-11-15, layer test.
