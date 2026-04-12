#!/bin/bash
# ---
# name: tracker-transition-guard
# event: PreToolUse
# matcher: "Edit"
# scope: global
# blocking: true
# description: >
#   Validate that task tracker status transitions are legal. Prevents skipping
#   steps (e.g., Pending -> Done without going through In Progress -> In Review).
# ---
#
# Legal transitions:
#   Pending       -> In Progress
#   In Progress   -> In Review
#   In Review     -> Done           (only after reviewer approval)
#   In Review     -> In Progress    (changes requested — back to dev)
#   Done          -> In Progress    (rework)
#
# Exit 0 = allow, Exit 2 = block

# ─── Scope guard ─────────────────────────────────────────────────────────────
# Only run inside an initialised SDLC harness workspace. If the cwd has no
# .claude/context/provider-config.md, the plugin is not active here — exit
# silently so this hook does not interfere with unrelated Claude Code sessions.
if [ ! -f ".claude/context/provider-config.md" ]; then
    exit 0
fi

# Probe for Python
PYTHON=""
for candidate in python3 python; do
    p=$(command -v "$candidate" 2>/dev/null)
    if [ -n "$p" ] && "$p" --version >/dev/null 2>&1; then
        PYTHON="$p"
        break
    fi
done

INPUT=$(cat)

if [ -z "$PYTHON" ]; then
    echo "BLOCKED: Python is required for tracker transition validation but was not found." >&2
    echo "Install Python 3 or ensure it is on PATH." >&2
    exit 2
fi

FILE_PATH=$(echo "$INPUT" | "$PYTHON" -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null)
OLD_STRING=$(echo "$INPUT" | "$PYTHON" -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('old_string',''))" 2>/dev/null)
NEW_STRING=$(echo "$INPUT" | "$PYTHON" -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('new_string',''))" 2>/dev/null)

# Only check edits to tracker files (in ai/tasks/)
if ! echo "$FILE_PATH" | grep -qP '(^|/)ai/tasks/'; then
    exit 0
fi

# Only check if the edit involves a status change (contains status emojis)
HAS_STATUS_CHANGE=false
if echo "$NEW_STRING" | grep -qP '(⏳|🔧|🔄|✅)'; then
    HAS_STATUS_CHANGE=true
fi

if [ "$HAS_STATUS_CHANGE" = false ]; then
    exit 0
fi

# Extract the old status and new status from the edit
OLD_STATUS=""
NEW_STATUS=""

if echo "$OLD_STRING" | grep -q "⏳"; then OLD_STATUS="pending"; fi
if echo "$OLD_STRING" | grep -q "🔧"; then OLD_STATUS="in_progress"; fi
if echo "$OLD_STRING" | grep -q "🔄"; then OLD_STATUS="in_review"; fi
if echo "$OLD_STRING" | grep -q "✅"; then OLD_STATUS="done"; fi

if echo "$NEW_STRING" | grep -q "⏳"; then NEW_STATUS="pending"; fi
if echo "$NEW_STRING" | grep -q "🔧"; then NEW_STATUS="in_progress"; fi
if echo "$NEW_STRING" | grep -q "🔄"; then NEW_STATUS="in_review"; fi
if echo "$NEW_STRING" | grep -q "✅"; then NEW_STATUS="done"; fi

# If we couldn't detect both statuses, allow (might be a non-status edit)
if [ -z "$OLD_STATUS" ] || [ -z "$NEW_STATUS" ]; then
    exit 0
fi

# Same status — no transition, allow
if [ "$OLD_STATUS" = "$NEW_STATUS" ]; then
    exit 0
fi

# Validate the transition
VALID=false

case "$OLD_STATUS" in
    "pending")
        if [ "$NEW_STATUS" = "in_progress" ]; then VALID=true; fi
        ;;
    "in_progress")
        if [ "$NEW_STATUS" = "in_review" ]; then VALID=true; fi
        ;;
    "in_review")
        if [ "$NEW_STATUS" = "done" ]; then VALID=true; fi
        if [ "$NEW_STATUS" = "in_progress" ]; then VALID=true; fi  # changes requested
        ;;
    "done")
        # Done is terminal — no transitions out (except back to in_progress for rework)
        if [ "$NEW_STATUS" = "in_progress" ]; then VALID=true; fi
        ;;
esac

if [ "$VALID" = false ]; then
    # Build human-readable status names
    STATUS_NAME() {
        case "$1" in
            "pending") echo "⏳ Pending" ;;
            "in_progress") echo "🔧 In Progress" ;;
            "in_review") echo "🔄 In Review" ;;
            "done") echo "✅ Done" ;;
        esac
    }

    echo "BLOCKED: Illegal task tracker status transition." >&2
    echo "" >&2
    echo "  From: $(STATUS_NAME $OLD_STATUS)" >&2
    echo "  To:   $(STATUS_NAME $NEW_STATUS)" >&2
    echo "" >&2
    echo "Legal transitions:" >&2
    echo "  ⏳ Pending     → 🔧 In Progress" >&2
    echo "  🔧 In Progress → 🔄 In Review" >&2
    echo "  🔄 In Review   → ✅ Done (after reviewer approval)" >&2
    echo "  🔄 In Review   → 🔧 In Progress (changes requested)" >&2
    echo "  ✅ Done        → 🔧 In Progress (rework)" >&2
    echo "" >&2
    echo "File: $FILE_PATH" >&2
    exit 2
fi

exit 0
