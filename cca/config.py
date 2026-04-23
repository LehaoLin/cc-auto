import os
import yaml

_DEFAULTS = {
    "ollama_model": "gemma3:4b",
    "ollama_url": "http://localhost:11434",
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
