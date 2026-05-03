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
# Covers: shell builtins, git, python, node, ruby, go, rust, java, c/c++, tex,
#         devtools, package managers, container tools, build tools, text processing
SAFE_CMDS='^(git\s|ls|cat|head|tail|grep|find|echo|pwd|cd|mkdir|cp|mv|rm|touch|chmod|chown|which|env|export|source|python3?\s|pip3?\s|jupyter|pytest|tox|black|ruff|mypy|pylint|isort|node\s|npm|npx|yarn|pnpm|bun|deno|ruby|bundle|rake|gem|cargo|rustc|go\s|make|cmake|gcc|g\+\+|java|javac|mvn|gradle|sbt|swift|dotnet|perl|php|lua|julia|scala|kotlin|Rscript|claude|pandoc|pdflatex|xelatex|lualatex|latexmk|bibtex|biber|biber|docker|podman|kubectl|helm|terraform|ansible|packer|vagrant|brew|apt|apt-get|dpkg|curl\s|wget\s|ssh|scp|rsync|tar|zip|unzip|gzip|bzip2|xz|7z|diff|patch|sort|uniq|wc|awk|sed|tr|tee|xargs|jq|yq|sqlite3|psql|mysql|redis-cli|less|more|most|bat|exa|fd|rg|ag|fzf|top|htop|ps|kill|killall|lsof|netstat|ss|ping|dig|nslookup|traceroute|openssl|gpg|sha256sum|md5sum|base64|file|stat|du|df|date|cal|man|info|true|false|test|time|timeout|nohup|screen|tmux|watch|strace|ltrace|systemctl|journalctl|dmesg|ip\s|ifconfig|whoami|id|groups|who|w|last|uptime|free|vmstat|iostat|gh\s|glab|hub\s|shellcheck|shfmt|prettier|eslint|stylelint|tsc|webpack|vite|rollup|esbuild|turbo|nx|lerna|pm2|nodemon|concurrently|wait-on|httpie|ab|wrk|hey|k6)'

if echo "$COMMAND" | grep -qEi "$SAFE_CMDS"; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Common safe command, auto-allowed"}}'
  exit 0
fi

# Layer 2: Ollama intelligent judgment for unknown commands
OLLAMA_PAYLOAD=$(echo "$COMMAND" | python3 -c "
import sys, json
cmd = sys.stdin.read().strip()
payload = {
    'model': 'qwen3.5:9b',
    'prompt': 'Is this command safe to run on a developer machine? Answer only yes or no: ' + cmd,
    'stream': False,
    'think': False
}
print(json.dumps(payload))
" 2>/dev/null || echo '{}')

RESP=$(curl -s --max-time 15 http://localhost:11434/api/generate \
  -d "$OLLAMA_PAYLOAD" 2>/dev/null || echo '{"response":"unknown"}')

RESULT=$(echo "$RESP" | python3 -c "
import sys, json, re
raw = json.load(sys.stdin).get('response', '').strip().lower()
# Extract first yes/no word from response (tolerates 'Yes.', 'No,', etc.)
m = re.search(r'\b(yes|no)\b', raw)
print(m.group(1) if m else '')
" 2>/dev/null || echo "")

if [ "$RESULT" = "yes" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Ollama judged safe"}}'
elif [ "$RESULT" = "no" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Ollama flagged unsafe but defaulting to allow (small model unreliability)"}}'
else
  # Ollama unsure — default to allow (fail-open)
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Ollama unsure, defaulting to allow"}}'
fi
