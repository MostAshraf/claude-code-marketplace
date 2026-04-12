#!/bin/bash
# ---
# name: tester-activation-guard
# event: SubagentStart
# matcher: "tester"
# scope: global
# blocking: true
# description: >
#   Mode-aware guard for the Tester agent.
#
#   auto-tdd mode (Phase 3):
#     Allow when tracker has at least one task in 🔧 In Progress.
#     The orchestrator only launches the tester when a task is already In Progress,
#     so this is a sanity check rather than a hard block.
#
#   auto-harden mode (Phase 5):
#     Block unless ALL development tasks (T1, T2, ...) are ✅ Done.
#     Same logic as the original guard.
#
#   Mode detection: reads the CLAUDE_SUBAGENT_PROMPT env var (populated by the harness).
#   Falls back to auto-harden semantics if mode is undetectable (safe default).
# ---
#
# Exit 0 = allow, Exit 2 = block

# ─── Scope guard ─────────────────────────────────────────────────────────────
# Only run inside an initialised SDLC harness workspace. If the cwd has no
# .claude/context/provider-config.md, the plugin is not active here — exit
# silently so this hook does not interfere with unrelated Claude Code sessions.
if [ ! -f ".claude/context/provider-config.md" ]; then
    exit 0
fi

TASKS_DIR="ai/tasks"

# ---------------------------------------------------------------------------
# Helper: detect mode from the subagent prompt injected by the orchestrator.
# The orchestrator passes "mode: auto-tdd" or "mode: auto-harden" in the prompt.
# ---------------------------------------------------------------------------
detect_mode() {
    # CLAUDE_SUBAGENT_PROMPT is set by the harness when SubagentStart fires
    if [ -n "$CLAUDE_SUBAGENT_PROMPT" ]; then
        if echo "$CLAUDE_SUBAGENT_PROMPT" | grep -qi 'auto-tdd'; then
            echo "auto-tdd"
            return
        fi
        if echo "$CLAUDE_SUBAGENT_PROMPT" | grep -qi 'auto-harden'; then
            echo "auto-harden"
            return
        fi
    fi
    # Safe default: apply the strictest check
    echo "auto-harden"
}

MODE=$(detect_mode)

# ---------------------------------------------------------------------------
# Common: verify tracker directory and files exist
# ---------------------------------------------------------------------------
if [ ! -d "$TASKS_DIR" ]; then
    echo "BLOCKED: No task tracker directory found at $TASKS_DIR." >&2
    echo "The Planner agent must create tracker files before testing can begin." >&2
    exit 2
fi

TRACKER_FILES=$(find "$TASKS_DIR" -name "*.md" -type f 2>/dev/null | sort -r)

if [ -z "$TRACKER_FILES" ]; then
    echo "BLOCKED: No task tracker files found. Cannot verify workflow state." >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# auto-tdd mode: allow if at least one task is 🔧 In Progress
# ---------------------------------------------------------------------------
if [ "$MODE" = "auto-tdd" ]; then
    IN_PROGRESS_FOUND=false

    for FILE in $TRACKER_FILES; do
        HAS_REPO_COL=false
        if grep -qP '^\|[ \t]*Repo[ \t]*\|' "$FILE" 2>/dev/null; then
            HAS_REPO_COL=true
        fi

        while IFS= read -r line; do
            TASK_ID=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
            if [ "$HAS_REPO_COL" = true ]; then
                STATUS=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $5); print $5}')
            else
                STATUS=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $4); print $4}')
            fi

            if echo "$TASK_ID" | grep -qP '^T\d+$'; then
                if echo "$STATUS" | grep -q "🔧"; then
                    IN_PROGRESS_FOUND=true
                fi
            fi
        done < <(grep -P '^\|.*T\d+' "$FILE" 2>/dev/null)
    done

    if [ "$IN_PROGRESS_FOUND" = false ]; then
        echo "BLOCKED (auto-tdd): No task is currently 🔧 In Progress." >&2
        echo "The orchestrator must update the tracker to In Progress before launching the Tester." >&2
        exit 2
    fi

    echo "✅ Tester activation check passed (auto-tdd) — task is In Progress."
    exit 0
fi

# ---------------------------------------------------------------------------
# auto-harden mode: block unless ALL dev tasks are ✅ Done
# ---------------------------------------------------------------------------
ALL_DONE=true
INCOMPLETE_TASKS=""

for FILE in $TRACKER_FILES; do
    HAS_REPO_COL=false
    if grep -qP '^\|[ \t]*Repo[ \t]*\|' "$FILE" 2>/dev/null; then
        HAS_REPO_COL=true
    fi

    while IFS= read -r line; do
        TASK_ID=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
        if [ "$HAS_REPO_COL" = true ]; then
            STATUS=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $5); print $5}')
        else
            STATUS=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $4); print $4}')
        fi

        # Skip any T-TEST rows (legacy trackers may still have them)
        if echo "$TASK_ID" | grep -qiP '^T-TEST'; then
            continue
        fi

        if echo "$TASK_ID" | grep -qP '^T\d+$'; then
            if ! echo "$STATUS" | grep -q "✅"; then
                ALL_DONE=false
                INCOMPLETE_TASKS="$INCOMPLETE_TASKS\n  - $TASK_ID: $STATUS"
            fi
        fi
    done < <(grep -P '^\|.*T\d+' "$FILE" 2>/dev/null)
done

if [ "$ALL_DONE" = false ]; then
    echo "BLOCKED (auto-harden): Cannot start Test Hardening — not all development tasks are complete." >&2
    echo "" >&2
    echo "Incomplete tasks:$INCOMPLETE_TASKS" >&2
    echo "" >&2
    echo "All development tasks (T1, T2, ...) must be ✅ Done before Test Hardening begins." >&2
    echo "Return to Phase 3 to complete the remaining tasks." >&2
    exit 2
fi

echo "✅ Tester activation check passed (auto-harden) — all development tasks are Done."
exit 0
