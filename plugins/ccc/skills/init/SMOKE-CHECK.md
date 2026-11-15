# Smoke Check Procedure

Run Smoke Check in the freshly initialized worktree using `hc` (herdr-core) — never `claude -p`, so herdr hooks and interactive session behavior are exercised.

## 1. Launch Worker

```bash
hc run --cwd <worktree-path> --bg --label ccc=smoke-check --label harness=<harness-name> claude
```

Wait for idle prompt, then send the Smoke Check prompt with `hc send` and wait with `hc wait`. Read output with `hc read`.

## 2. Two-Stage Prompt

1. **Common check** (always run):
   - List loaded skills, agents, workflows, hooks, and MCP/LSP servers visible to the Worker.
   - Verify expected Components and MCP/LSP tools are present, overridden global skills are hidden, and required binaries (e.g., `pyright-langserver` for `pyright-lsp`) exist.
2. **Harness-specific task**:
   - For a promoted Harness: run the Smoke Check task defined in its `HARNESS.md`.
   - For an Instant Harness: run a short local verification task chosen during `init` that exercises the selected Plugins/Components together.

**Guardrail**: Keep Smoke Check strictly local — no git push, no PR creation, no external posts.

## 3. Retry & Recording

- If Smoke Check fails, diagnose the cause (settings, path, hook permission, precedence collision), fix the worktree setup, and retry up to **2 times**.
- If it still fails after 2 retries, report the failure, logs, and attempted fixes to the user.
- Record every Smoke Check failure and fix in `<worktree>/.claude/.ccc.json` (`smokeCheckNotes`) so `/ccc:promote` and `CONFLICTS.md` have the evidence.
- Clean up the Smoke Check `hc` terminal after reading its final output.
