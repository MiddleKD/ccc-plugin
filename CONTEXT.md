# ccc-plugin

A personal Claude Code plugin marketplace and harness library for dynamically provisioning task-specific worker environments.

## Language

**Control Plane**:
The main Herdr session that plans work with the user, provisions worktrees, and assembles harnesses for workers.
_Avoid_: Orchestrator, master session

**Worker**:
An isolated Claude Code session running inside a dedicated worktree under a provisioned harness.
_Avoid_: Sub-agent, child session

**Plugin**:
An upstream or standalone Claude Code extension (skills, hooks, MCP servers, or LSPs) stored in this marketplace with minimal personal modification.
_Avoid_: Mod, addon

**Harness**:
A standalone, folder-based, reusable execution bundle stored in `ccc-plugin` that includes `skills/`, `agents/`, `hooks/`, `workflow.js`, settings templates, and agent instructions, along with when to use it and how to initialize it.
_Avoid_: Preset, template, profile

**Instant Harness**:
An ephemeral, task-specific environment provisioned on the fly for a single worktree without modifying the target project's tracked configuration.
_Avoid_: Temp setup

**Smoke Check**:
A short real task run by a Worker launched through herdr inside a freshly initialized worktree, used to confirm that the harness's plugins and components load and work together.
_Avoid_: Test run, dry run

**Component**:
Any individual execution building block bundled inside a Harness or Plugin: a skill, agent, hook, or workflow.
_Avoid_: Module, asset

**Conflict Rules**:
The single record of known overlaps between plugins and which one takes precedence, accumulated from real use.
_Avoid_: Catalog, plugin guide

**Promotion**:
The act of extracting a successful Instant Harness into a committed Harness folder in `ccc-plugin`, while optionally recording the project-to-harness affinity in Claude project memory.
_Avoid_: Saving, exporting
