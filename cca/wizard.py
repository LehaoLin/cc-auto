import getpass
from .config import load_config, save_config


def _prompt_with_default(label, current_value, is_secret=False):
    hint = current_value or "(not set)"
    display_hint = hint if not is_secret else ("****" if current_value else "(not set)")
    prompt_text = f"  {label} [{display_hint}]: "
    if is_secret:
        raw = getpass.getpass(prompt_text)
    else:
        raw = input(prompt_text)
    return raw.strip() if raw.strip() else current_value


def run_wizard():
    try:
        config = load_config()
    except KeyboardInterrupt:
        print("\n[cca] Cancelled.")
        return None

    print("[cca] API Configuration Wizard")
    print()
    print("  Select API provider:")
    print("  1. Ollama (local)")
    print("  2. External API (OpenAI-compatible)")
    print()

    while True:
        try:
            choice = input("  Enter number [1/2]: ").strip()
        except KeyboardInterrupt:
            print("\n[cca] Cancelled.")
            return None
        if choice in ("1", "2"):
            break
        print("  Please enter 1 or 2.")

    if choice == "1":
        config["provider"] = "ollama"
        config["ollama_model"] = _prompt_with_default(
            "Ollama model name", config.get("ollama_model", "")
        )
        config["ollama_url"] = _prompt_with_default(
            "Ollama URL", config.get("ollama_url", "")
        )
    else:
        config["provider"] = "openai"
        config["api_url"] = _prompt_with_default(
            "API URL (e.g. https://api.openai.com/v1/chat/completions)",
            config.get("api_url", ""),
        )
        config["api_model"] = _prompt_with_default(
            "Model name", config.get("api_model", "")
        )
        config["api_key"] = _prompt_with_default(
            "API key (optional, press Enter to skip)",
            config.get("api_key", ""),
            is_secret=True,
        )

    save_config(config)

    provider = config["provider"]
    if provider == "ollama":
        detail = f"{config['ollama_url']} / {config['ollama_model']}"
    else:
        detail = f"{config['api_url']} / {config['api_model']}"
    print(f"\n[cca] Configuration saved. Provider: {provider} ({detail})")
    return config
