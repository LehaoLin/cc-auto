# cc-auto — Claude Code Safety Hook

[English](README.md) | [简体中文](README_zh.md)

cc-auto adds a local safety gate to Claude Code using a bash hook and Ollama. It intercepts Bash tool calls and judges whether they are safe before execution.

> `cca` works exactly like `claude`, but with Ollama safety hook active.

## How It Works

```
cca [args...]
 │
 ▼
claude --settings hook-settings.json [args...]
 │
 ▼ (every Bash tool call)
safe-hook.sh
 ├── Layer 1: Hard-block (rm -rf, sudo, etc.) → DENY
 ├── Layer 2: Ollama (qwen3.5:9b) judges → ALLOW / DENY
 └── Ollama unsure → ASK user
```

- **Only gates Bash tool calls** — Edit, Write, Read, etc. are auto-allowed
- **Does NOT interfere with user choices** — plan approval, mode selection, etc. are untouched
- **Fail-open** — if Ollama is unreachable, falls back to asking the user

## Prerequisites

- macOS (uses `python3` which ships with the system)
- [Ollama](https://ollama.ai/) running locally

```bash
ollama pull qwen3.5:9b
```

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/LehaoLin/cc-auto.git
cd cc-auto

# 2. Pull the Ollama model
ollama pull qwen3.5:9b

# 3. Install cca command (one-time setup)
#    Creates a symlink — no files copied to ~/.local/bin
mkdir -p ~/.local/bin
ln -sf "$(pwd)/cca" ~/.local/bin/cca

# Make sure ~/.local/bin is in your PATH
# (skip if already configured)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# 4. Use cca just like claude
cca                        # interactive mode
cca -c                     # continue last session
cca --resume ID            # resume a specific session
cca -p "fix the bug"       # one-shot mode
cca --model sonnet         # specify model
cca --worktree feature-auth  # isolated git worktree
```

## Project Structure

```
├── cca                 # Wrapper script (drop-in replacement for claude)
├── safe-hook.sh        # PreToolUse hook script (two-layer safety)
├── hook-settings.json  # Hook configuration (loaded via --settings)
├── LICENSE
└── README.md
```

## Customization

### Change the Ollama model

Edit `safe-hook.sh`, line with `"model": "qwen3.5:9b"` — replace with any model you have pulled.

### Add more dangerous patterns

Edit the `grep -qEi` line in Layer 1 of `safe-hook.sh`.

### Gate more tools

Change the `if [ "$TOOL_NAME" != "Bash" ]` check in `safe-hook.sh` to include other tool names.

## Contributing

Issues and PRs welcome!

## License

MIT
