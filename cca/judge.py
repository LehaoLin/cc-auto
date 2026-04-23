import requests
from .prompt import SYSTEM_PROMPT, USER_PROMPT_TEMPLATE

_TIMEOUT = 10


def judge_safety(output, config):
    url = f"{config['ollama_url']}/api/chat"
    payload = {
        "model": config["ollama_model"],
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": USER_PROMPT_TEMPLATE.format(output=output)},
        ],
        "stream": False,
        "options": {"temperature": 0},
    }
    try:
        resp = requests.post(url, json=payload, timeout=_TIMEOUT)
        resp.raise_for_status()
        content = resp.json()["message"]["content"].strip().lower()
        if "dangerous" in content:
            return "dangerous"
        return "safe"
    except Exception:
        return None
