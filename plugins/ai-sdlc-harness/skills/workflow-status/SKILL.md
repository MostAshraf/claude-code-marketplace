---
name: workflow-status
description: "Display current workflow status dashboard — read-only overview of story progress, task states, branch info, and worktree status"
allowed-tools: Bash, Read, Grep, Glob
---

# /workflow-status — Workflow Status Dashboard

**Usage:** `/workflow-status`

This is a **read-only** skill. It does NOT modify any files — it only reads and displays information.

## Instructions

When invoked, gather and display a structured dashboard of the current workflow state. Follow these steps exactly:

### Step 1: Identify Active Tracker

```bash
ls -t ai/tasks/*.md 2>/dev/null | head -5
```

Read the most recent tracker file. If no tracker files exist, report: "No active workflow found. Use `/dev-workflow <Work-Item-ID>` to start one."

### Step 2: Extract Story Metadata

From the tracker filename (`<date>_<story-id>_<slug>_<session>.md`), extract:
- **Story ID**
- **Date started**
- **Slug** (brief description)

### Step 3: Read the Tracker

Read the full tracker file. Extract:
- All task rows (ID, **Repo**, description, status, assignee)
- Count tasks by status: ⏳ Pending, 🔧 In Progress, 🔄 In Review, ✅ Done
- If the tracker has a **Repo** column, also group tasks by repo

### Step 4: Determine Current Phase

Based on task statuses, determine the workflow phase:

| Condition | Phase |
|-----------|-------|
| No dev tasks exist | Phase 1-2: Planning |
| Any task 🔧 or 🔄 | Phase 3: Development Loop |
| All dev tasks ✅, no test task | Phase 4: Human Approval |
| All dev tasks ✅, test task exists but not ✅ | Phase 5: Testing |
| All tasks ✅ (including test) | Phase 6: PR Creation |

### Step 5: Git Status (Multi-Repo)

Read `.claude/context/repos-paths.md` to get repo paths.

If the tracker has a **Repo Status** section, gather git context per-repo:

```bash
# For each affected repo:
git -C <repo-path> rev-parse --abbrev-ref HEAD
git -C <repo-path> log --oneline -3
git -C <repo-path> worktree list
git -C <repo-path> status --porcelain | head -5
```

For single-repo stories or legacy trackers, use the current directory:
```bash
git rev-parse --abbrev-ref HEAD
git log --oneline -3
git worktree list
git status --porcelain | head -10
```

### Step 6: Locate Plan File

```bash
ls -t ai/plans/*.md 2>/dev/null | head -1
```

### Step 7: Present Dashboard

Format the output as follows:

```
╔══════════════════════════════════════════════════════════════╗
║                 📊 WORKFLOW STATUS DASHBOARD                 ║
╚══════════════════════════════════════════════════════════════╝

📌 Story:    #<STORY-ID> — <slug>
📅 Started:  <date>
🔄 Phase:    <current phase>
🔀 Branch:   <current branch>

─── Task Progress ─────────────────────────────────────────────
  ✅ Done:        X / Y
  🔧 In Progress: X / Y
  🔄 In Review:   X / Y
  ⏳ Pending:     X / Y
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Progress:       [████████░░] XX%

─── Task Details ──────────────────────────────────────────────
  T1  | AuthService     | <description>      | ✅ Done
  T2  | AuthService     | <description>      | 🔧 In Progress
  T3  | BillingService  | <description>      | ⏳ Pending
  ...
  (Repo column shown for multi-repo stories)

─── Per-Repo Git Context ──────────────────────────────────────
  📦 AuthService (/home/dev/repos/auth-service)
    Branch:    backend/feature/12345-slug
    Worktree:  <active worktree path or "None">
    Last commit: <hash> <message>
    Uncommitted: <count> file(s) or "Clean"

  📦 BillingService (/home/dev/repos/billing-service)
    Branch:    backend/feature/12345-slug
    Worktree:  <active worktree path or "None">
    Last commit: <hash> <message>
    Uncommitted: <count> file(s) or "Clean"
  (Single-repo stories show one repo section)

─── Files ─────────────────────────────────────────────────────
  📄 Tracker: <path>
  📝 Plan:    <path>
───────────────────────────────────────────────────────────────
```

### Important Notes

- This skill is **read-only** — do NOT modify any files.
- If multiple tracker files exist, show the most recent one.
- If the user asks follow-up questions about specific tasks, read the tracker for details.
- The progress bar should visually represent the percentage of ✅ Done tasks out of total tasks.
