#!/bin/bash
# ---
# name: tracker-metrics-guard
# event: PreToolUse
# matcher: "Edit"
# scope: global
# blocking: false (advisory only — warns but never blocks)
# description: >
#   Warn when timestamp values written to the Workflow Metrics and Task
#   Metrics sections of the task tracker do not use the full YYYY-MM-DD HH:MM UTC
#   format. Emits a stdout advisory but always exits 0 so the edit proceeds.
# ---
#
# Valid formats:
#   2026-04-05 14:30 UTC     ← full datetime, required
#   --                       ← placeholder, allowed
#   local-test               ← special CI value, allowed
#
# Invalid formats (warned, not blocked):
#   2026-04-05               ← date only — time missing
#   2026-04-05T14:30         ← ISO 8601 separator instead of space
#   2026-04-05 14:30         ← missing UTC suffix
#
# Exit 0 = always (advisory only)

# ─── Scope guard ─────────────────────────────────────────────────────────────
# Only run inside an initialised SDLC harness workspace. If the cwd has no
# .claude/context/provider-config.md, the plugin is not active here — exit
# silently so this hook does not interfere with unrelated Claude Code sessions.
if [ ! -f ".claude/context/provider-config.md" ]; then
    exit 0
fi

PYTHON=""
for candidate in python3 python; do
    p=$(command -v "$candidate" 2>/dev/null)
    if [ -n "$p" ] && "$p" --version >/dev/null 2>&1; then
        PYTHON="$p"
        break
    fi
done

INPUT=$(cat)

# Can't validate without Python — fail open to avoid blocking legit edits
if [ -z "$PYTHON" ]; then
    exit 0
fi

TOOL_NAME=$(echo "$INPUT" | "$PYTHON" -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_name', ''))
" 2>/dev/null)

# Only check Edit operations
if [ "$TOOL_NAME" != "Edit" ]; then
    exit 0
fi

FILE_PATH=$(echo "$INPUT" | "$PYTHON" -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('file_path', ''))
" 2>/dev/null)

# Only check tracker files
if ! echo "$FILE_PATH" | grep -qP '(^|/)ai/tasks/'; then
    exit 0
fi

NEW_STRING=$(echo "$INPUT" | "$PYTHON" -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('new_string', ''))
" 2>/dev/null)

# Find any date pattern NOT immediately followed by ' HH:MM UTC'
# Valid:   2026-04-05 14:30 UTC   → lookahead succeeds → negative lookahead blocks match → no match
# Invalid: 2026-04-05             → lookahead fails    → negative lookahead passes → match → blocked
# Invalid: 2026-04-05 14:30       → lookahead fails (no UTC) → match → blocked
# Invalid: 2026-04-05T14:30       → T is not \s → lookahead fails → match → warned
INVALID=$(echo "$NEW_STRING" | grep -oP '\d{4}-\d{2}-\d{2}(?!\s+\d{2}:\d{2}\s+UTC)' 2>/dev/null | head -1)

if [ -n "$INVALID" ]; then
    echo "ADVISORY: Timestamp '$INVALID' in tracker metrics may be incomplete."
    echo "  Required format:  YYYY-MM-DD HH:MM UTC"
    echo "  Example:          $(date -u '+%Y-%m-%d %H:%M') UTC"
    echo "  Allowed values:   --  (placeholder)  |  local-test  (CI/test runs)"
    echo "  File: $FILE_PATH"
fi

exit 0
