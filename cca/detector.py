import re
import time
import logging

logger = logging.getLogger("cca")

_ANSI_RE = re.compile(r"\x1b\[[0-9;]*[a-zA-Z]|\x1b\].*?\x07|\x1b\[.*?[a-zA-Z]")


def strip_ansi(text):
    return _ANSI_RE.sub("", text)


class PromptDetector:
    def __init__(self, idle_timeout=6):
        self.idle_timeout = idle_timeout
        self.last_output_time = time.time()
        self.last_output_hash = None

    def update_activity(self, output):
        current_hash = hash(output[-200:] if len(output) > 200 else output)
        if current_hash != self.last_output_hash:
            self.last_output_time = time.time()
            self.last_output_hash = current_hash

    def is_idle(self):
        return (time.time() - self.last_output_time) >= self.idle_timeout

    def detect(self, output):
        if not output:
            return None

        tail = output[-1500:] if len(output) > 1500 else output
        clean = strip_ansi(tail)

        if _detect_yes_no_prompt(clean):
            logger.info("Matched yes/no prompt")
            return "yes_no_prompt"

        if _detect_cancel_prompt(clean):
            logger.info("Matched cancel prompt")
            return "cancel_prompt"

        if self.is_idle():
            return "idle_timeout"

        return None

    def find_no_option_number(self, output):
        tail = output[-1500:] if len(output) > 1500 else output
        clean = strip_ansi(tail)
        return _find_no_option(clean)


def has_yes_no_prompt(text):
    return _detect_yes_no_prompt(text)


def _detect_yes_no_prompt(text):
    pattern = r"\d+\.\s*(Yes|No)"
    matches = re.findall(pattern, text, re.IGNORECASE)
    return len(matches) >= 2


def _detect_cancel_prompt(text):
    indicators = [
        "Esc to cancel",
        "Tab to amend",
        "enter to confirm",
        "to confirm",
    ]
    return any(ind in text for ind in indicators)


def _find_no_option(text):
    lines = text.split("\n")
    for line in reversed(lines):
        matches = re.finditer(r"(\d+)[\.\)]\s*(.*?No.*?)$", line, re.IGNORECASE)
        for m in matches:
            return m.group(1)
    return None
