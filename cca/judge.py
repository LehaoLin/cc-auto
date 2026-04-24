import logging
import requests
from .prompt import SYSTEM_PROMPT, USER_PROMPT_TEMPLATE

_TIMEOUT = 10
logger = logging.getLogger("cca")


def judge_safety(output, config):
    provider = config.get("provider", "ollama")
    if provider == "openai":
        return _judge_openai(output, config)
    return _judge_ollama(output, config)


def _judge_ollama(output, config):
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
        return _parse_verdict(content)
    except Exception:
        logger.debug("Ollama judge failed", exc_info=True)
        return None


def _judge_openai(output, config):
    url = config.get("api_url", "")
    if not url:
        return None

    headers = {"Content-Type": "application/json"}
    api_key = config.get("api_key", "")
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"

    payload = {
        "model": config.get("api_model", ""),
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": USER_PROMPT_TEMPLATE.format(output=output)},
        ],
        "temperature": 0,
    }
    try:
        resp = requests.post(url, json=payload, headers=headers, timeout=_TIMEOUT)
        resp.raise_for_status()
        content = resp.json()["choices"][0]["message"]["content"].strip().lower()
        return _parse_verdict(content)
    except Exception:
        logger.debug("OpenAI judge failed", exc_info=True)
        return None


def _parse_verdict(content):
    if "dangerous" in content:
        return "dangerous"
    return "safe"
