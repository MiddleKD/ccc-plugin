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

_No conflicts recorded yet. Add entries only when observed during Smoke Check or `/ccc:promote`._
