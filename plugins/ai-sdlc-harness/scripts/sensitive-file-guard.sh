#!/bin/bash
# ---
# name: sensitive-file-guard
# event: PreToolUse
# matcher: "Write|Edit"
# scope: global (plugin-level)
# blocking: true
# description: >
#   Blocks writes/edits to potentially sensitive files (.env, .secret, .key,
#   .pfx, .pem). Catches catastrophic failure modes where the model would
#   accidentally commit credentials to the repo.
# ---
#
# Exit 0 = allow, Exit 2 = block (stderr fed back to Claude as error)

if [ ! -f ".claude/context/provider-config.md" ]; then
    exit 0
fi

INPUT=$(cat)

PYTHON=""
for candidate in python3 python; do
    p=$(command -v "$candidate" 2>/dev/null)
    if [ -n "$p" ] && "$p" --version >/dev/null 2>&1; then
        PYTHON="$p"
        break
    fi
done
if [ -z "$PYTHON" ]; then
    echo "BLOCKED: Python is required for sensitive file protection but was not found." >&2
    echo "Install Python 3 or ensure it is on PATH." >&2
    exit 2
fi

FILE_PATH=$(echo "$INPUT" | "$PYTHON" -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

if echo "$FILE_PATH" | grep -qE '\.(env|secret|key|pfx|pem)$'; then
    echo "BLOCKED: Refusing to write a potentially sensitive file: $FILE_PATH" >&2
    echo "Credentials, keys, and secrets must never be committed. If this is intentional," >&2
    echo "add the file outside the repo or through your secret manager, not via the agent." >&2
    exit 2
fi

exit 0
