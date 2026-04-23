import sys
import shutil
import logging
import os
import requests

from .config import load_config
from .monitor import ClaudeMonitor


def _find_claude_binary():
    path = shutil.which("claude")
    if not path:
        print("[cca] Error: 'claude' not found in PATH")
        print("[cca] Install Claude Code: https://docs.anthropic.com/en/docs/claude-code")
        sys.exit(1)
    return path


def _check_ollama(config):
    try:
        resp = requests.get(f"{config['ollama_url']}/api/tags", timeout=5)
        resp.raise_for_status()
        models = [m["name"] for m in resp.json().get("models", [])]
        target = config["ollama_model"]
        if not any(target == m or m.startswith(target + ":") for m in models):
            print(f"[cca] Warning: model '{target}' not found in Ollama. Available: {', '.join(models) if models else 'none'}")
            print(f"[cca] Run: ollama pull {target}")
            return False
        return True
    except requests.ConnectionError:
        print("[cca] Error: Cannot connect to Ollama. Is it running?")
        print(f"[cca] Expected at {config['ollama_url']}")
        return False


def _setup_logging():
    log_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "cca.log")
    logging.basicConfig(
        filename=log_path,
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )


def _print_help():
    print("""Usage: cca [options] [claude-args...]

  cca                          Start Claude Code with auto-confirmation
  cca -c                       Continue last session
  cca --resume ID              Resume a specific session
  cca -p "query"               Non-interactive query (auto-confirm still active)
  cca --model sonnet           Use specific model
  cca --worktree feature-auth  Start in isolated git worktree

All arguments are forwarded to the 'claude' CLI.
See: claude --help for full flag reference.""")


def main():
    args = sys.argv[1:]
    if args and args[0] in ("-h", "--help"):
        _print_help()
        sys.exit(0)

    # Support both "cca claude [args]" and "cca [args]"
    if args and args[0] == "claude":
        claude_args = args[1:]
    else:
        claude_args = args

    claude_bin = _find_claude_binary()

    config = load_config()
    _setup_logging()

    print(f"[cca] Claude: {claude_bin}")
    print(f"[cca] Model: {config['ollama_model']}")
    if not _check_ollama(config):
        sys.exit(1)
    print("[cca] Ollama ready. Starting Claude Code...")
    print("[cca] Press Ctrl+C to exit\n")

    monitor = ClaudeMonitor(config)
    try:
        monitor.start(claude_args, claude_bin=claude_bin)
    except KeyboardInterrupt:
        print("\n[cca] Exiting...")
