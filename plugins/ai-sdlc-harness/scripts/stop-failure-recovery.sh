#!/bin/bash
# ---
# name: stop-failure-recovery
# event: UserPromptSubmit
# matcher: ""
# scope: global (plugin-level)
# blocking: false
# description: >
#   When the previous turn ended with an API error (StopFailure), the
#   stop-failure-marker.sh hook wrote .claude/context/.stop-failure.
#   This hook fires on the next UserPromptSubmit, checks for that marker,
#   and — if found — outputs a recovery context block before Claude processes
#   the user's message. The marker is deleted immediately so it fires once.
# ---
#
# Exit 0 always. Stdout is appended to the user's prompt as additional context.

MARKER=".claude/context/.stop-failure"

if [ ! -f ".claude/context/provider-config.md" ]; then
    exit 0
fi

if [ ! -f "$MARKER" ]; then
    exit 0
fi

rm -f "$MARKER"

cat <<'EOF'
[SYSTEM — API ERROR RECOVERY: An API error ended the previous turn. Before responding to the user's message, check whether ai/tasks/ contains any .md tracker files. If none exist, skip this entirely and respond normally. Otherwise: read the most recent tracker in ai/tasks/. Identify tasks marked In Progress or In Review — these were likely active when the failure hit. Check 'git status --porcelain' for uncommitted changes. If .claude/context/repos-paths.md exists, also check each repo for uncommitted changes. Output: (1) which tasks were active (ID, status, description), (2) uncommitted changes with file counts, (3) recovery guidance: read the tracker, resume from the active task, verify uncommitted changes before committing. Do not restart completed tasks. Then respond to the user's message.]
EOF
