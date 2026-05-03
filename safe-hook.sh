#!/bin/bash
# Claude Code PreToolUse hook — local safety gate
# Uses Ollama (qwen3.5:9b) for intelligent judgment
# Zero dependencies beyond bash + python3 (both shipped with macOS)
#
# Policy:
#   - Project-level operations: ALLOW (rm, mv, cp, mkdir, etc. within project)
#   - Git commands: ALWAYS ALLOW
#   - Common dev tools: ALWAYS ALLOW (ls, cat, grep, find, npm, pip, python, make, etc.)
#   - System-level dangerous ops: DENY (sudo, rm -rf /, mkfs, dd, shutdown, etc.)
#   - Unknown commands: ask Ollama

set -euo pipefail

# Read JSON from stdin
INPUT=$(cat)

# Extract fields using python3
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || echo "")
TOOL_INPUT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('tool_input',{})))" 2>/dev/null || echo "{}")

# Skip non-Bash tools
if [ "$TOOL_NAME" != "Bash" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Non-Bash tool, auto-allowed"}}'
  exit 0
fi

# Extract the command
COMMAND=$(echo "$TOOL_INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('command',''))" 2>/dev/null || echo "")

if [ -z "$COMMAND" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Empty command"}}'
  exit 0
fi

# Layer 1: Hard-block system-level dangerous commands
if echo "$COMMAND" | grep -qEi 'sudo\s|rm\s+-rf\s+/|git\s+push\s+--force|chmod\s+777\s/|mkfs\.|dd\s+if=.*/dev|shutdown|reboot|init\s+[06]|:(){ :\|&};:|curl.*\|\s*bash|wget.*\|\s*bash'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Blocked: system-level dangerous command"}}'
  exit 0
fi

# Layer 1.5: Hard-allow common safe commands (no Ollama needed)
if echo "$COMMAND" | grep -qEi '^(git\s|ls|cat|head|tail|grep|find|echo|pwd|cd|mkdir|cp|mv|rm|touch|chmod|chown|which|env|export|source|python3?\s|pip3?\s|npm|node|npx|yarn|pnpm|cargo|go\s|make|cmake|gcc|g\+\+|java|javac|ruby|bundle|brew|apt|docker|kubectl|curl\s|wget\s|ssh|scp|rsync|tar|zip|unzip|diff|sort|uniq|wc|awk|sed|tr|tee|xargs|test|true|false|date|cal|man|info|help|alias|type|hash|history|jobs|kill|wait|sleep|read|printf|test)'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Common safe command, auto-allowed"}}'
  exit 0
fi

# Layer 2: Ollama intelligent judgment for unknown commands
ESCAPED_CMD=$(echo "$COMMAND" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))" 2>/dev/null || echo '""')

RESP=$(curl -s --max-time 10 http://localhost:11434/api/generate \
  -d "{
    \"model\": \"qwen3.5:9b\",
    \"prompt\": \"Is this command safe to run on a developer machine? Answer only yes or no: ${ESCAPED_CMD}\",
    \"stream\": false
  }" 2>/dev/null || echo '{"response":"unknown"}')

RESULT=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('response','').strip().lower())" 2>/dev/null || echo "")

if [ "$RESULT" = "yes" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Ollama judged safe"}}'
elif [ "$RESULT" = "no" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Ollama judged unsafe"}}'
else
  # Ollama unsure — default to allow (fail-open)
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Ollama unsure, defaulting to allow"}}'
fi
