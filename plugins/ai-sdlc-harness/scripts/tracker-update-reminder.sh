#!/bin/bash
# ---
# name: tracker-update-reminder
# event: PostToolUse
# matcher: "Agent"
# scope: global
# blocking: false (informational only)
# description: >
#   After every agent invocation (developer, reviewer, tester), reads the
#   task tracker and checks whether the orchestrator updated it to reflect
#   the agent's result. If not, injects a precise reminder via
#   hookSpecificOutput.additionalContext telling the orchestrator exactly
#   what edit to make.
# ---
#
# Exit 0 = allow (always — this hook never blocks)
# Outputs JSON with hookSpecificOutput.additionalContext when a reminder is needed.

# ─── Scope guard ─────────────────────────────────────────────────────────────
# Only run inside an initialised SDLC harness workspace. If the cwd has no
# .claude/context/provider-config.md, the plugin is not active here — exit
# silently so this hook does not interfere with unrelated Claude Code sessions.
if [ ! -f ".claude/context/provider-config.md" ]; then
    exit 0
fi

set -euo pipefail

# --- Probe for Python ---
PYTHON=""
for candidate in python3 python; do
    p=$(command -v "$candidate" 2>/dev/null)
    if [ -n "$p" ] && "$p" --version >/dev/null 2>&1; then
        PYTHON="$p"
        break
    fi
done

if [ -z "$PYTHON" ]; then
    exit 0  # Fail open — can't check without Python
fi

# --- Read hook input ---
INPUT=$(cat)

# Extract tool_response (the agent's output text)
TOOL_RESPONSE=$(echo "$INPUT" | "$PYTHON" -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_response', ''))
" 2>/dev/null || echo "")

# Extract tool_input to get agent type/prompt
TOOL_INPUT=$(echo "$INPUT" | "$PYTHON" -c "
import sys, json
d = json.load(sys.stdin)
ti = d.get('tool_input', {})
# subagent_type field
print(ti.get('subagent_type', ''))
" 2>/dev/null || echo "")

# If no tool_response, nothing to check
if [ -z "$TOOL_RESPONSE" ]; then
    exit 0
fi

# --- Parse AGENT STATUS block ---
OUTCOME=""
VERDICT=""
TASK_ID=""
AGENT_TYPE=""

# Determine agent type from tool_input subagent_type or from the response text
if echo "$TOOL_INPUT" | grep -qi "developer"; then
    AGENT_TYPE="developer"
elif echo "$TOOL_INPUT" | grep -qi "reviewer"; then
    AGENT_TYPE="reviewer"
elif echo "$TOOL_INPUT" | grep -qi "tester"; then
    AGENT_TYPE="tester"
fi

# If subagent_type didn't match, try to infer from the response
if [ -z "$AGENT_TYPE" ]; then
    if echo "$TOOL_RESPONSE" | grep -qi "self-review\|production code\|worktree"; then
        AGENT_TYPE="developer"
    elif echo "$TOOL_RESPONSE" | grep -qi "spec compliance\|code quality\|verdict"; then
        AGENT_TYPE="reviewer"
    elif echo "$TOOL_RESPONSE" | grep -qi "tests written\|coverage\|test command"; then
        AGENT_TYPE="tester"
    fi
fi

if [ -z "$AGENT_TYPE" ]; then
    exit 0  # Can't determine agent type, skip
fi

# Extract AGENT STATUS fields using Python for robustness
# We pass BOTH tool_response and tool_input.prompt as separate args
TOOL_INPUT_PROMPT=$(echo "$INPUT" | "$PYTHON" -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('prompt', ''))
" 2>/dev/null || echo "")

STATUS_DATA=$(PROMPT="$TOOL_INPUT_PROMPT" echo "$TOOL_RESPONSE" | "$PYTHON" -c "
import sys, re, os

text = sys.stdin.read()
prompt = os.environ.get('PROMPT', '')

# Find the AGENT STATUS block
match = re.search(r'AGENT STATUS.*?(?=\n\n|\Z)', text, re.DOTALL)
if not match:
    sys.exit(0)

block = match.group(0)

# Extract fields
outcome_m = re.search(r'Outcome:\s*(\S+)', block)
verdict_m = re.search(r'Verdict:\s*(\S+)', block)

# Extract task ID — search in both the AGENT STATUS block AND the orchestrator prompt
task_m = re.search(r'(?:task|Task)\s+(T-TEST[^\s,|]*|T\d+)', block)
if not task_m:
    task_m = re.search(r'(T-TEST[^\s,|]*|T\d+)', block)
if not task_m and prompt:
    # Search the orchestrator's prompt for the task reference
    task_m = re.search(r'(?:task|Task)\s+(T-TEST[^\s,|]*|T\d+)', prompt)
    if not task_m:
        task_m = re.search(r'(T-TEST[^\s,|]*|T\d+)', prompt)

print(f'OUTCOME={outcome_m.group(1) if outcome_m else \"\"}')
print(f'VERDICT={verdict_m.group(1) if verdict_m else \"\"}')
print(f'TASK={task_m.group(1) if task_m else \"\"}')
" 2>/dev/null || echo "")

OUTCOME=$(echo "$STATUS_DATA" | grep '^OUTCOME=' | cut -d= -f2 || echo "")
VERDICT=$(echo "$STATUS_DATA" | grep '^VERDICT=' | cut -d= -f2 || echo "")
TASK_ID=$(echo "$STATUS_DATA" | grep '^TASK=' | cut -d= -f2 || echo "")

# If no outcome found, skip
if [ -z "$OUTCOME" ]; then
    exit 0
fi

# --- Find the tracker file ---
TRACKER_DIR="ai/tasks"
if [ ! -d "$TRACKER_DIR" ]; then
    exit 0  # No tracker directory
fi

TRACKER_FILE=$(ls -t "$TRACKER_DIR"/*.md 2>/dev/null | head -1)
if [ -z "$TRACKER_FILE" ]; then
    exit 0  # No tracker file
fi

# --- Read tracker and check current status ---
TRACKER_CONTENT=$(cat "$TRACKER_FILE" 2>/dev/null || echo "")
if [ -z "$TRACKER_CONTENT" ]; then
    exit 0
fi

# Determine what the tracker SHOULD show and what it currently shows
EXPECTED_STATUS=""
CURRENT_STATUS=""
REMINDER_TEXT=""

get_task_status() {
    # Extract the status for a given task ID from the tracker table
    local task_id="$1"
    local result
    result=$(echo "$TRACKER_CONTENT" | TASK_ID="$task_id" "$PYTHON" -c '
import sys, re, os
text = sys.stdin.read()
task_id = os.environ.get("TASK_ID", "")

pattern = rf"\|\s*{re.escape(task_id)}\s*\|[^|]*\|\s*([^|]+?)\s*\|"
m = re.search(pattern, text)
if m:
    status = m.group(1).strip()
    if "\u23f3" in status: print("pending")
    elif "\U0001f527" in status: print("in_progress")
    elif "\U0001f504" in status: print("in_review")
    elif "\u2705" in status: print("done")
    else: print("unknown:" + status)
else:
    print("not_found")
')
    echo "$result"
}

# Determine expected state based on agent type and outcome
case "$AGENT_TYPE" in
    developer)
        if [ "$OUTCOME" = "SUCCESS" ] || [ "$OUTCOME" = "DONE_WITH_CONCERNS" ]; then
            EXPECTED_STATUS="in_review"
        elif [ "$OUTCOME" = "PARTIAL" ] || [ "$OUTCOME" = "FAILED" ]; then
            # Don't remind on failure — orchestrator handles retry logic
            exit 0
        fi
        ;;
    reviewer)
        if [ "$VERDICT" = "APPROVED" ]; then
            EXPECTED_STATUS="done"
        elif [ "$VERDICT" = "CHANGES_REQUESTED" ]; then
            EXPECTED_STATUS="in_progress"
        else
            exit 0  # No clear verdict, skip
        fi
        ;;
    tester)
        if [ "$OUTCOME" = "SUCCESS" ] || [ "$OUTCOME" = "DONE_WITH_CONCERNS" ]; then
            EXPECTED_STATUS="in_review"
        else
            exit 0
        fi
        ;;
    *)
        exit 0
        ;;
esac

# Check if the task ID was found
if [ -z "$TASK_ID" ]; then
    # Try to infer from agent type
    case "$AGENT_TYPE" in
        tester) TASK_ID="T-TEST" ;;
        reviewer)
            # For reviewers, infer from whichever task is currently In Review
            TASK_ID=$(echo "$TRACKER_CONTENT" | "$PYTHON" -c "
import sys, re
text = sys.stdin.read()
m = re.search(r'\|\s*(T(?:-TEST)?[^\s|]*)\s*\|[^|]*\|\s*\U0001f504[^|]*\|', text)
print(m.group(1).strip() if m else '')
" 2>/dev/null || echo "")
            [ -z "$TASK_ID" ] && exit 0
            ;;
        *) exit 0 ;;  # Can't determine task, skip
    esac
fi

# Get current status of the task
CURRENT_STATUS=$(get_task_status "$TASK_ID")

# If task not found in tracker, skip (might be multi-repo with T-TEST-<RepoName>)
if [ "$CURRENT_STATUS" = "not_found" ]; then
    # Try T-TEST-<RepoName> pattern for tester
    if [ "$AGENT_TYPE" = "tester" ]; then
        # Look for any T-TEST task
        TEST_TASK=$(echo "$TRACKER_CONTENT" | "$PYTHON" -c "
import sys, re
text = sys.stdin.read()
m = re.search(r'\|\s*(T-TEST[^\s|]*)\s*\|', text)
print(m.group(1).strip() if m else '')
" 2>/dev/null || echo "")
        if [ -n "$TEST_TASK" ]; then
            TASK_ID="$TEST_TASK"
            CURRENT_STATUS=$(get_task_status "$TASK_ID")
        else
            exit 0
        fi
    else
        exit 0
    fi
fi

# If already in expected state, no reminder needed
if [ "$CURRENT_STATUS" = "$EXPECTED_STATUS" ]; then
    exit 0
fi

# --- Build the reminder ---
STATUS_LABEL=""
case "$EXPECTED_STATUS" in
    in_review) STATUS_LABEL="🔄 In Review" ;;
    in_progress) STATUS_LABEL="🔧 In Progress" ;;
    done) STATUS_LABEL="✅ Done" ;;
esac

CURRENT_LABEL=""
case "$CURRENT_STATUS" in
    pending) CURRENT_LABEL="⏳ Pending" ;;
    in_progress) CURRENT_LABEL="🔧 In Progress" ;;
    in_review) CURRENT_LABEL="🔄 In Review" ;;
    done) CURRENT_LABEL="✅ Done" ;;
    *) CURRENT_LABEL="$CURRENT_STATUS" ;;
esac

REMINDER_TEXT="TRACKER UPDATE NEEDED: The $AGENT_TYPE just completed for $TASK_ID but the tracker at $TRACKER_FILE still shows \"$CURRENT_LABEL\". Update $TASK_ID to \"$STATUS_LABEL\""

# Add timestamp instruction for status transitions that need it
case "$EXPECTED_STATUS" in
    in_review)
        REMINDER_TEXT="$REMINDER_TEXT.

Use: Edit the tracker row for $TASK_ID, changing the Status column from the current value to 🔄 In Review."
        ;;
    in_progress)
        if [ "$AGENT_TYPE" = "reviewer" ]; then
            REMINDER_TEXT="$REMINDER_TEXT (changes requested). Increment Review Rounds by 1 and record the reviewer's comments in the Notes column."
        fi
        ;;
    done)
        REMINDER_TEXT="$REMINDER_TEXT.

Also update the Task Metrics table for $TASK_ID:
- Set Completed to the output of: date -u +\"%Y-%m-%d %H:%M UTC\"
- Increment Review Rounds by 1

For reviewer approved: also record the commit hash and set Reviewer Verdict to ✅ Approved."
        ;;
esac

# Output JSON with additionalContext
"$PYTHON" -c "
import sys, json
reminder = sys.stdin.read().strip()
output = {
    'hookSpecificOutput': {
        'additionalContext': reminder
    }
}
print(json.dumps(output))
" <<< "$REMINDER_TEXT"

exit 0
