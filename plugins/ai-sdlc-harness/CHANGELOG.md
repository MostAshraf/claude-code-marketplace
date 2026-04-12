# Changelog

All notable changes to `ai-sdlc-harness` are documented here.

---

## [1.0.0] — 2026-04-12

First public release.

### Features

- **7-phase development workflow** — Requirements → Plan → Develop → Human Approval → Test Hardening → PR Creation → PR Review Response, with human approval gates at phases 2, 4, and 6.
- **TDD pattern** — Tester commits failing tests first; Developer makes them green; Reviewer reviews the combined diff before squash-merge. Every task starts red.
- **Multi-repo support** — Parallel developer agents across repos, strictly sequential within each repo. Cross-repo boundaries resolved via contracts defined in the planning phase.
- **Phase 7: PR Review Response** — On-demand phase triggered after PR comments arrive. Reviewer classifies each comment as VALID / INVALID / PARTIAL; human selects which to address; Planner adds rework tasks and re-enters the Phase 3 loop.
- **Language-agnostic, discovery-driven** — `/init-workspace` discovers language, toolchain, build, test, and coverage commands via negotiate-and-confirm. Supports any language (frontend + backend).

### Work Item Providers

| Provider | Notes |
|----------|-------|
| Azure DevOps | Work items via MCP |
| Jira | Issues via MCP |
| GitLab | Issues via MCP |
| GitHub | Issues via MCP |
| Zoho | Mail Group Tasks via MCP |
| local-markdown | Local `.md` files — no external provider needed |

### Git / PR Providers

| Provider | Notes |
|----------|-------|
| Azure DevOps | Pull Requests via MCP |
| GitLab | Merge Requests via MCP |
| GitHub | Pull Requests via MCP |
| gh-cli | Pull Requests via `gh` CLI (no MCP required) |
| glab-cli | Merge Requests via `glab` CLI (no MCP required) |

### Guardrail Hooks

- `tracker-transition-guard` — enforces legal tracker status transitions
- `tracker-metrics-guard` — validates tracker metric fields on every write
- `tracker-update-reminder` — reminds the orchestrator to sync tracker status
- `sensitive-file-guard` — blocks writes to secrets and credentials files
- `validate-commit-msg` — enforces `#<STORY-ID> #<TASK-ID>` commit format
- `squash-merge-verify` — prevents squash-merge before Reviewer approval
- `agent-status-check` — verifies agents end responses with a `📋 AGENT STATUS` block
- `tester-activation-guard` — prevents the Developer from starting before failing tests are committed
- `stop-failure-recovery` — surfaces recovery instructions on unexpected agent stops
