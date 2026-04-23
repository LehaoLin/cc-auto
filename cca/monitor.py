import os
import sys
import tty
import time
import shutil
import signal
import logging
import select
import threading

import pexpect

from .detector import PromptDetector, strip_ansi, has_yes_no_prompt
from .judge import judge_safety

logger = logging.getLogger("cca")

RETRY_TIMEOUT = 5


class ClaudeMonitor:
    def __init__(self, config):
        self.config = config
        self.buffer = ""
        self.context_window = config["context_window"]
        self.detector = PromptDetector(idle_timeout=config["idle_timeout"])
        self.child = None
        self._running = False
        self._judge_lock = threading.Lock()
        self._last_action_buffer_hash = None
        self._last_action_time = 0

    def start(self, extra_args=None):
        self._running = True
        cols, rows = shutil.get_terminal_size()
        cmd = "claude"
        args = extra_args or []
        self.child = pexpect.spawn(
            cmd,
            args=args,
            encoding="utf-8",
            codec_errors="replace",
            timeout=None,
            dimensions=(rows, cols),
            env=os.environ,
        )

        def _handle_winch(sig, frame):
            cols, rows = shutil.get_terminal_size()
            self.child.setwinsize(rows, cols)

        signal.signal(signal.SIGWINCH, _handle_winch)

        old_settings = tty.tcgetattr(sys.stdin.fileno())
        try:
            tty.setraw(sys.stdin.fileno())
            monitor_thread = threading.Thread(target=self._monitor_loop, daemon=True)
            monitor_thread.start()
            self._stdin_bridge()
        finally:
            tty.tcsetattr(sys.stdin.fileno(), tty.TCSADRAIN, old_settings)
            self._running = False
            if self.child.isalive():
                self.child.close(force=True)

    def _stdin_bridge(self):
        while self._running:
            try:
                r, _, _ = select.select([sys.stdin], [], [], 0.1)
                if r:
                    data = os.read(sys.stdin.fileno(), 4096)
                    if not data:
                        break
                    self.child.write(data.decode("utf-8", errors="replace"))
            except (OSError, ValueError):
                break

    def _monitor_loop(self):
        child_fd = self.child.fileno()
        while self._running:
            try:
                r, _, _ = select.select([child_fd], [], [], 0.1)
                if r:
                    data = os.read(child_fd, 4096)
                    if not data:
                        self._running = False
                        break
                    os.write(sys.stdout.fileno(), data)
                    chunk = data.decode("utf-8", errors="replace")
                    self.buffer += chunk
                    if len(self.buffer) > self.context_window * 2:
                        self.buffer = self.buffer[-self.context_window:]
                    self.detector.update_activity(self.buffer)
            except (OSError, ValueError):
                self._running = False
                break

            if not self._judge_lock.locked():
                result = self.detector.detect(self.buffer)
                if result:
                    self._handle_prompt(result)

            self._check_retry()

    def _check_retry(self):
        if self._judge_lock.locked():
            return
        if not self._last_action_buffer_hash:
            return
        current_hash = hash(self.buffer[-300:])
        elapsed = time.time() - self._last_action_time

        if current_hash != self._last_action_buffer_hash:
            self._last_action_buffer_hash = None
            return

        if elapsed >= RETRY_TIMEOUT:
            logger.info("Retry: TUI unchanged after action, re-judging...")
            self._handle_prompt("retry")

    def _handle_prompt(self, trigger):
        with self._judge_lock:
            current_buffer = self.buffer
            clean_buffer = strip_ansi(current_buffer)

            if not has_yes_no_prompt(clean_buffer):
                logger.info(f"Trigger '{trigger}' but no Yes/No prompt found, skipping")
                return

            logger.info(f"Prompt detected ({trigger}), judging safety...")

            logger.info(f"Buffer tail (clean): {clean_buffer[-500:]}")
            verdict = judge_safety(clean_buffer, self.config)
            if verdict is None:
                logger.info("Judge failed or timed out, skipping")
                return

            if verdict == "safe":
                logger.info("Verdict: SAFE -> pressing Enter")
                time.sleep(0.5)
                self.child.sendline("")
            else:
                logger.info("Verdict: DANGEROUS -> selecting No")
                time.sleep(0.5)
                no_num = self.detector.find_no_option_number(current_buffer)
                if no_num:
                    self.child.send(no_num)
                    time.sleep(0.5)
                    self.child.sendline("继续")
                    time.sleep(0.5)
                    self.child.send("\r")
                else:
                    logger.info("No 'No' option found, pressing Enter anyway")
                    self.child.sendline("")

            self._last_action_buffer_hash = hash(self.buffer[-300:])
            self._last_action_time = time.time()
            self.buffer = ""
            time.sleep(0.5)
