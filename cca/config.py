import os
import yaml

_DEFAULTS = {
    "provider": "ollama",
    "ollama_model": "gemma3:4b",
    "ollama_url": "http://localhost:11434",
    "api_url": "",
    "api_model": "",
    "api_key": "",
    "context_window": 2000,
    "idle_timeout": 6,
}

CONFIG_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "config.yaml")


def load_config():
    config = dict(_DEFAULTS)
    if os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH) as f:
            user_cfg = yaml.safe_load(f)
            if user_cfg:
                config.update(user_cfg)
    return config


def save_config(config):
    with open(CONFIG_PATH, "w") as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False)
