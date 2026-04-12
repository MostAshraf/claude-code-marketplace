#!/bin/bash
# ---
# name: agent-status-check
# event: SubagentStop
# matcher: ""
# scope: global (plugin-level)
# blocking: true
# description: >
#   Enforces that every subagent response ends with a "📋 AGENT STATUS" block.
#   The literal emoji + phrase is required — downstream eval parsing depends on
#   it and the model drifts toward omitting the 📋 prefix otherwise.
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
    echo "HOOK ERROR: Neither python3 nor python found. Cannot parse hook input." >&2
    exit 2
fi

RESPONSE=$(echo "$INPUT" | "$PYTHON" -c "
import sys, json, os

d = json.load(sys.stdin)

# Dump raw payload for key discovery — delete once the correct key is confirmed.
try:
    with open('/tmp/agent-status-debug.json', 'w') as f:
        json.dump(d, f, indent=2)
except Exception:
    pass

def extract_text(content):
    '''Concatenate ALL text blocks from a content field (str or list).'''
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = [p.get('text', '') for p in content
                 if isinstance(p, dict) and p.get('type') == 'text']
        return '\n'.join(parts)
    return ''

# Try top-level string keys — includes known and plausible candidates.
for k in ('response', 'agent_response', 'final_response', 'text', 'output', 'result'):
    v = d.get(k)
    if isinstance(v, str) and v:
        print(v)
        sys.exit(0)

# Scan messages / transcript for the last assistant message and join all text parts.
msgs = d.get('messages') or d.get('transcript') or []
if isinstance(msgs, list):
    for m in reversed(msgs):
        if isinstance(m, dict) and m.get('role') == 'assistant':
            text = extract_text(m.get('content', ''))
            if text:
                print(text)
                sys.exit(0)
" 2>/dev/null)

if [ -z "$RESPONSE" ]; then
    echo "HOOK WARNING: agent-status-check could not extract response text from SubagentStop payload. Inspect /tmp/agent-status-debug.json to identify the correct key and update this script." >&2
    exit 0
fi

if ! printf '%s' "$RESPONSE" | grep -qF '📋 AGENT STATUS'; then
    cat >&2 <<EOF
BLOCKED: Agent response is missing the required "📋 AGENT STATUS" block.
Every subagent response must end with a status block prefixed by the 📋 emoji,
exactly: "📋 AGENT STATUS" followed by the contract fields. Add the block and retry.
EOF
    exit 2
fi

exit 0
