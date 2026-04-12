---
name: dev-workflow
description: >
  Master orchestrator for the AI-driven development workflow. Use when
  starting a new User Story / Issue implementation. Coordinates the Planner, Developer,
  Reviewer, and Tester agents through all 7 phases with human approval gates.
  Supports multiple work item providers (ADO, Jira, GitLab, GitHub, Zoho, local-markdown) and git providers
  (ADO, GitLab, GitHub, gh-cli, glab-cli) via provider adapters. Supports multi-repo stories with
  parallel developer agents across repos while maintaining sequential execution
  within each repo.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent, mcp__azure-devops__*, mcp__jira__*, mcp__gitlab__*, mcp__github__*, mcp__zoho__*
argument-hint: "[command] <Work-Item-ID> [project-name] [team-name]"
---

# AI-Driven Development Workflow

## Provider Resolution

Before executing any command, **read `.claude/context/provider-config.md`** to determine
the active work item and git providers. All MCP tool calls throughout the workflow are
resolved through the provider adapters in `skills/providers/<provider>/`.

## Usage

```
/dev-workflow <Work-Item-ID> [project-name] [team-name]            # Full pipeline
/dev-workflow <command> <Work-Item-ID> [project-name] [team-name]   # Specific phase
```

**Examples:**
- `/dev-workflow 123456 MyProject backend` (ADO)
- `/dev-workflow PROJ-123 PROJ backend` (Jira)
- `/dev-workflow 42 mygroup/myproject backend` (GitLab)
- `/dev-workflow plan 123456` (specific phase)

## Argument Parsing

Parse `$ARGUMENTS`:

- **First token**: If it looks like a work item ID (numeric, or matches Jira key pattern
  like `PROJ-123`), treat as Story/Issue ID and run the **full pipeline**.
  If it matches a command name, use that command (**direct phase mode**).
- **Story/Issue ID** (required): The Work Item ID (format depends on provider).
- **Project name** (optional): Defaults from `provider-config.md`.
- **Team name** (optional): Defaults from `provider-config.md` if configured, otherwise must be provided.

Pass all three values to downstream commands and agents.

## Commands

| Command | File | Phase | Description |
|---------|------|-------|-------------|
| `preflight` | `commands/preflight.md` | Pre | Branch creation and setup |
| `requirements` | `commands/requirements.md` | 1 | Requirements Ingestion |
| `plan` | `commands/plan.md` | 2 | Planning & Approval |
| `develop` | `commands/develop.md` | 3 | Development Loop |
| `approve-impl` | `commands/approve-impl.md` | 4 | Human Approval of Implementation |
| `test` | `commands/test.md` | 5 | Test Implementation |
| `create-pr` | `commands/create-pr.md` | 6 | PR Creation |
| `review-response` | `commands/review-response.md` | 7 | PR Review Response |

If the first token doesn't match a command name and isn't numeric, show this usage table and stop.

## Orchestrator Rules

**Before executing any command**, read `context/orchestrator-rules.md`. These rules apply to
ALL phases and cannot be overridden by individual commands.

## Full Pipeline Mode

When no command is specified (first argument is the Story ID), execute all commands in sequence:

1. `preflight` → 2. `requirements` → 3. `plan` → 4. `develop` → 5. `approve-impl` → 6. `test` → 7. `create-pr`

After `create-pr` completes, `review-response` is **not** run automatically — it is triggered
on demand (via direct phase mode) once PR review comments arrive from human reviewers.

Read each command file **as you reach that phase**. Do not pre-load all command files — load
one at a time to conserve context.

After each command completes, proceed to the next automatically (unless a human gate blocks).

## Direct Phase Mode

When a command is specified, read its command file and execute it. Each command file states
its own prerequisites — verify them before proceeding.

This mode is useful for:
- **Resuming** a workflow after a session interruption
- **Re-running** a specific phase (e.g., re-running tests after manual fixes)
- **Debugging** a single phase in isolation
