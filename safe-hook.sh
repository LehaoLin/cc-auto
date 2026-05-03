#!/bin/bash
# Claude Code PreToolUse hook — local safety gate
# Uses Ollama (qwen3.5:9b) for intelligent judgment
# Zero dependencies beyond bash + python3 (both shipped with macOS)
#
# This hook ONLY gates tool execution permissions (Bash, Edit, Write, etc.)
# It does NOT interfere with user choices (plan approval, mode selection, etc.)

set -euo pipefail

# Read JSON from stdin
INPUT=$(cat)

# Extract fields using python3 (available on all macOS)
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || echo "")
TOOL_INPUT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('tool_input',{})))" 2>/dev/null || echo "{}")

# Skip non-Bash tools (auto-allow Edit, Write, Read, etc.)
if [ "$TOOL_NAME" != "Bash" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Non-Bash tool, auto-allowed"}}'
  exit 0
fi

# Extract the command from tool_input
COMMAND=$(echo "$TOOL_INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('command',''))" 2>/dev/null || echo "")

# Skip empty commands
if [ -z "$COMMAND" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Empty command"}}'
  exit 0
fi

# Layer 1: Hard-block dangerous commands (deny)
if echo "$COMMAND" | grep -qEi 'rm\s+-rf|sudo\s|rm\s+/|git\s+push\s+--force|chmod\s+777|mkfs|dd\s+if=|shutdown|reboot'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Blocked dangerous command"}}'
  exit 0
fi

# Layer 2: Ollama intelligent judgment
# Escape command for JSON embedding
ESCAPED_CMD=$(echo "$COMMAND" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))" 2>/dev/null || echo '""')

RESP=$(curl -s --max-time 10 http://localhost:11434/api/generate \
  -d "{
    \"model\": \"qwen3.5:9b\",
    \"prompt\": \"Is this command safe to run? Answer only yes or no: ${ESCAPED_CMD}\",
    \"stream\": false
  }" 2>/dev/null || echo '{"response":"unknown"}')

RESULT=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('response','').strip().lower())" 2>/dev/null || echo "")

if [ "$RESULT" = "yes" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Ollama judged safe"}}'
elif [ "$RESULT" = "no" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Ollama judged unsafe"}}'
else
  # Ollama unsure/unreachable — ask user (not auto-allow)
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Ollama unsure, asking user"}}'
fi
