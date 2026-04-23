# cca - Claude Code Auto-Confirmation Tool

[English](README.md) | [简体中文](README_zh.md)

cca enables unattended Claude Code sessions by monitoring TUI output and using a local Ollama model to judge whether operations are safe, automatically confirming or rejecting them.

> *I genuinely love using Claude Code — it's the most capable coding agent I've worked with. Every time it autonomously completes a complex task, I feel like we're one step closer to AGI. The only thing that bothered me was the constant permission prompts during long sessions. So I built cca to scratch my own itch — and to let the agent run a little more freely, because I believe that's how we get there.*

## How It Works

The detection pipeline has two layers:

### Layer 1: Prompt Detection (Regex-based, zero latency)

A background thread streams the Claude Code TUI output through a sliding window buffer and detects confirmation prompts using pattern matching:

- **Yes/No prompt** — matches the numbered `1. Yes` / `2. No` selection UI
- **Cancel/confirm prompt** — matches keywords like "Esc to cancel", "enter to confirm", "Tab to amend"
- **Idle timeout** — triggers when TUI output hasn't changed for a configurable number of seconds

This layer runs on every read cycle with no model overhead.

### Layer 2: Safety Judgment (Ollama)

When a confirmation prompt is detected, the buffer context is sent to a local Ollama model which classifies the operation as **safe** or **dangerous**:

- **Safe** → automatically selects "Yes" (sends `1` + Enter)
- **Dangerous** → automatically selects "No" (finds the No option number, sends it + Enter)
- **Retry** — if the TUI hasn't changed 5 seconds after an action, re-judges the prompt

### Safety Classification Criteria

**DANGEROUS operations:**
- Deleting user files outside the project directory
- Modifying critical system files (`/etc/hosts`, `/etc/sudoers`)
- Running destructive commands targeting non-project files (`rm -rf` outside project, `dd`, `mkfs`)
- Force pushing to main/master branch
- Exposing secrets or credentials in public locations
- Any operation that could cause irreversible data loss outside the project

**SAFE operations:**
- Creating new files or directories
- Editing project source code files
- Running read-only commands (`ls`, `cat`, `grep`, `find`, `git status`, etc.)
- Running tests, linters, build commands within the project
- Installing project dependencies (`npm install`, `pip install`)
- Git operations: commit, push, pull, merge, rebase, reset, branch management
- Installing system packages (`brew install`, `apt install`, `npm install -g`)
- Modifying project-level config files (`.gitignore`, `.env`, `package.json`, etc.)
- Normal development workflow operations

## Prerequisites

- Python >= 3.9
- [uv](https://docs.astral.sh/uv/)
- [Ollama](https://ollama.ai/) running with a pulled model:

```bash
ollama pull gemma3:4b
```

## Quick Start

```bash
# Test run (within the project directory)
./test.sh          # macOS / Linux
.\test.ps1         # Windows
```

## Global Installation

After installation, run `cca` from any directory. Re-running the install command is safe and idempotent:

```bash
# macOS / Linux
./install.sh

# Windows
.\install.ps1
```

Usage:

```bash
cca                        # Start Claude Code with auto-confirmation
cca -c                     # Continue last session
cca --resume ID            # Resume a specific session
cca -p "query"             # Non-interactive query (auto-confirm still active)
cca --model sonnet         # Use specific model
cca --worktree feature-auth  # Start in isolated git worktree
cca claude [args...]       # Explicit form, same as above

cca -h                     # Show cca help
```

All arguments (except `-h`/`--help`) are forwarded to the `claude` CLI. See `claude --help` for full flag reference.

## Configuration

Edit `config.yaml` in the project directory:

```yaml
ollama_model: "gemma3:4b"      # Ollama model name
ollama_url: "http://localhost:11434"  # Ollama server address
context_window: 2000           # Sliding window size (characters)
idle_timeout: 6                # TUI idle timeout (seconds)
```

## Project Structure

```
cca/
├── __init__.py
├── __main__.py    # python -m cca entry point
├── cli.py         # CLI argument parsing
├── config.py      # Configuration loading
├── monitor.py     # PTY monitoring + key injection
├── detector.py    # Prompt detection + ANSI stripping
├── judge.py       # Ollama API calls
└── prompt.py      # Safety judgment prompt templates
```

## Logging

Runtime logs are written to `cca.log` in the project directory, useful for debugging detection and judgment behavior.

## Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  PTY (claude) │────▶│   Detector   │────▶│    Judge     │
│  TUI output   │     │  (regex)     │     │  (Ollama)    │
└──────────────┘     └──────────────┘     └──────┬───────┘
       ▲                                          │
       │            ┌──────────────┐              │
       └────────────│  Key Inject  │◀─────────────┘
                    │  (pexpect)   │   safe / dangerous
                    └──────────────┘
```

1. PTY spawns Claude Code, background thread reads TUI output
2. Detector scans buffer for confirmation prompts (regex, high-frequency)
3. When a prompt is found, Judge sends context to Ollama for safety classification
4. Based on the verdict, key injection presses the appropriate option

## License

MIT
