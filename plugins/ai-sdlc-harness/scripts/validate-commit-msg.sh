#!/bin/bash
# ---
# name: validate-commit-msg
# event: PreToolUse
# matcher: "Bash"
# scope: global
# blocking: true
# description: >
#   Validate that git commit commands include proper work item IDs.
#   Format required: #<STORY-ID> #<TASK-ID>: description (both IDs mandatory).
#   Only activates for git commit commands.
# ---
#
# Exit 0 = allow, Exit 2 = block (stderr fed to Claude)

# ─── Scope guard ─────────────────────────────────────────────────────────────
# Only run inside an initialised SDLC harness workspace. If the cwd has no
# .claude/context/provider-config.md, the plugin is not active here — exit
# silently so this hook does not interfere with unrelated Claude Code sessions.
if [ ! -f ".claude/context/provider-config.md" ]; then
    exit 0
fi

INPUT=$(cat)

# Parse JSON without jq — use python3 or python, whichever is available
# Require Python — guardrails must not silently degrade
PYTHON=""
for candidate in python3 python; do
    p=$(command -v "$candidate" 2>/dev/null)
    if [ -n "$p" ] && "$p" --version >/dev/null 2>&1; then
        PYTHON="$p"
        break
    fi
done
if [ -z "$PYTHON" ]; then
    echo "BLOCKED: Python is required for commit message validation but was not found." >&2
    echo "Install Python 3 or ensure it is on PATH." >&2
    exit 2
fi

COMMAND=$(echo "$INPUT" | "$PYTHON" -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Only check git commit commands
if ! echo "$COMMAND" | grep -qE '^\s*git\s+commit'; then
    exit 0
fi

# Extract the commit message — supports both -m "msg" and heredoc formats
COMMIT_MSG=$(echo "$COMMAND" | "$PYTHON" -c "
import sys, re

cmd = sys.stdin.read()

# Strategy 1: Simple -m 'msg' or -m \"msg\"
m = re.search(r'-m\s+[\"\\x27]([^\"\\x27]+)[\"\\x27]', cmd)
if m:
    print(m.group(1).strip())
    sys.exit(0)

# Strategy 2: Heredoc — git commit -m \"\$(cat <<'EOF' ... EOF )\"
m = re.search(r\"<<'?EOF'?\\s*\\n(.*?)\\n\\s*EOF\", cmd, re.DOTALL)
if m:
    for line in m.group(1).strip().splitlines():
        line = line.strip()
        if line:
            print(line)
            break
    sys.exit(0)

# Strategy 3: -m with command substitution containing a bare string
m = re.search(r'-m\s+\"\\\$\(cat\s+<<', cmd)
if m:
    # Heredoc detected but couldn't parse content — extract first non-empty line after <<EOF
    lines = cmd.split('\\n')
    in_heredoc = False
    for line in lines:
        if re.search(r\"<<'?EOF'?\", line):
            in_heredoc = True
            continue
        if in_heredoc:
            stripped = line.strip()
            if stripped and stripped != 'EOF' and not stripped.endswith(\")\\\"\"):
                print(stripped)
                break
    sys.exit(0)
" 2>/dev/null)

# If we still couldn't extract a message, allow through (non-standard format)
if [ -z "$COMMIT_MSG" ]; then
    exit 0
fi

# Validate format: #<STORY-ID> #<TASK-ID>: description
# Story ID can be:
#   - Numeric (ADO, GitHub, GitLab):  123456
#   - Jira key (PROJECT-123):         PROJ-123
# Task ID comes from the planner (T1, T2, T-TEST-AuthService, etc.)
if ! echo "$COMMIT_MSG" | grep -qE '^#[A-Za-z0-9_-]+[[:space:]]+#(T[A-Za-z0-9_-]+|[0-9]+)([[:space:]]+(test|impl))?:[[:space:]]+.+'; then
    echo "BLOCKED: Commit message does not follow the required convention." >&2
    echo "" >&2
    echo "Required format: #<STORY-ID> #<TASK-ID>: description in lowercase imperative mood" >&2
    echo "Both Story ID and Task ID (from the planner, e.g. T1, T2, T-TEST-AuthService) are required." >&2
    echo "Examples:" >&2
    echo "  #123456 #T1: fix duplicate config module name error        (ADO / GitHub / GitLab)" >&2
    echo "  #PROJ-123 #T1: add subscription handler                    (Jira)" >&2
    echo "  #123456 #T-TEST-AuthService: add unit tests for token refresh" >&2
    echo "" >&2
    echo "Your message: $COMMIT_MSG" >&2
    exit 2
fi

# Check that description after colon starts with lowercase
DESCRIPTION=$(echo "$COMMIT_MSG" | sed 's/^#[^ ]* #[^ ]*: //')
if echo "$DESCRIPTION" | grep -qE '^[A-Z]'; then
    echo "BLOCKED: Commit description must start with lowercase (imperative mood)." >&2
    echo "Your description: $DESCRIPTION" >&2
    echo "Example: fix duplicate bicep module name error (not 'Fix...' or 'Fixed...')" >&2
    exit 2
fi

exit 0
