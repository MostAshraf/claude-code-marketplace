#!/bin/bash
# ---
# name: squash-merge-verify
# event: PostToolUse
# matcher: "Bash"
# scope: global
# blocking: false (PostToolUse — exit 2 surfaces warning to model, does not block)
# description: >
#   After a git merge --squash command, verify the operation succeeded and
#   changes are staged on the current branch. If it failed (conflict, etc.),
#   inject recovery instructions. Only activates for merge --squash commands.
# ---
#
# Exit 0 = success (stdout injected as context)
# Exit 2 = block (merge conflict detected)

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
    echo "BLOCKED: Python is required for squash-merge verification but was not found." >&2
    echo "Install Python 3 or ensure it is on PATH." >&2
    exit 2
fi

COMMAND=$(echo "$INPUT" | "$PYTHON" -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)

# Only check git merge --squash commands (with or without -C <path>)
if ! echo "$COMMAND" | grep -qP '^\s*git\s+(-C\s+\S+\s+)?merge\s+--squash'; then
    exit 0
fi

# Extract -C <path> if present, to run verification commands in the correct repo
GIT_C_FLAG=""
REPO_DIR=""
if echo "$COMMAND" | grep -qP '^\s*git\s+-C\s+'; then
    REPO_DIR=$(echo "$COMMAND" | grep -oP '(?<=git\s-C\s)\S+' | head -1)
    GIT_C_FLAG="-C $REPO_DIR"
fi

# Check if we're in a merge conflict state
MERGE_MSG_PATH="${REPO_DIR:-.}/.git/MERGE_MSG"
# For worktrees, MERGE_MSG may be in the worktree's git dir
if [ -n "$REPO_DIR" ]; then
    GIT_DIR=$(git -C "$REPO_DIR" rev-parse --git-dir 2>/dev/null)
    MERGE_MSG_PATH="$GIT_DIR/MERGE_MSG"
fi

if [ -f "$MERGE_MSG_PATH" ] && git $GIT_C_FLAG diff --name-only --diff-filter=U 2>/dev/null | grep -q .; then
    echo "⚠️ SQUASH-MERGE CONFLICT DETECTED${REPO_DIR:+ (repo: $REPO_DIR)}" >&2
    echo "" >&2
    echo "The squash-merge did not apply cleanly. Conflicting files:" >&2
    git $GIT_C_FLAG diff --name-only --diff-filter=U 2>/dev/null >&2
    echo "" >&2
    echo "Recovery options:" >&2
    echo "  1. Abort: git ${GIT_C_FLAG:+$GIT_C_FLAG }merge --abort" >&2
    echo "  2. Resolve conflicts manually, then: git ${GIT_C_FLAG:+$GIT_C_FLAG }add <files> && git ${GIT_C_FLAG:+$GIT_C_FLAG }commit" >&2
    echo "" >&2
    echo "If this keeps failing, consider re-invoking the Developer on the feature branch" >&2
    echo "directly (without worktree isolation) to re-apply the changes." >&2
    exit 2
fi

# Verify that the squash-merge staged changes
CURRENT_BRANCH=$(git $GIT_C_FLAG rev-parse --abbrev-ref HEAD 2>/dev/null)
STAGED_COUNT=$(git $GIT_C_FLAG diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')

if [ "$STAGED_COUNT" -gt 0 ]; then
    echo "✅ Squash-merge verified: $STAGED_COUNT file(s) staged on branch $CURRENT_BRANCH${REPO_DIR:+ (repo: $REPO_DIR)}"
    echo "   Ready for: git ${GIT_C_FLAG:+$GIT_C_FLAG }commit -m \"#<STORY-ID> [#T<n>]: <task-title>\""
else
    # Check if there's nothing to merge (already up to date)
    if echo "$COMMAND" | grep -qP '--squash\s+\S+'; then
        BRANCH=$(echo "$COMMAND" | grep -oP '(?<=--squash\s)\S+' | head -1)
        echo "⚠️ Squash-merge produced no staged changes from branch $BRANCH${REPO_DIR:+ (repo: $REPO_DIR)}" >&2
        echo "This may mean the branch is already merged or has no new commits." >&2
        exit 2
    fi
fi

exit 0
