"""Exercise real session files across killed Godot processes with synthetic auth."""
import os
from pathlib import Path
import selectors
import shutil
import subprocess
import tempfile
import time
import unittest


class RememberMeDiskRestartTests(unittest.TestCase):
    def test_abrupt_stop_and_interrupted_replacement_preserve_saved_login(self):
        frontend = Path(__file__).resolve().parents[1]
        log_root = os.environ.get("POKEAETHER_TEST_LOG_DIR")
        self.assertTrue(log_root, "Run through ops/worktrees/slot-env")
        scratch = tempfile.mkdtemp(prefix="remember-disk-", dir=log_root)
        env = dict(os.environ, POKEAETHER_REMEMBER_ME_TEST_DIR=scratch)
        command = [shutil.which("godot"), "--headless", "--path", str(frontend),
                   "--script", "res://tests/fixtures/remember_me_disk_restart_probe.gd", "--"]

        def run_and_kill(mode):
            process = subprocess.Popen(command + [mode], env=env, stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT, bufsize=0)
            try:
                with selectors.DefaultSelector() as selector:
                    selector.register(process.stdout, selectors.EVENT_READ)
                    deadline = time.monotonic() + 45
                    ready = False
                    while time.monotonic() < deadline and process.poll() is None:
                        if not selector.select(timeout=0.2):
                            continue
                        line = os.read(process.stdout.fileno(), 8192).decode("utf-8", errors="replace")
                        if "REMEMBER_DISK_READY" in line:
                            ready = True
                            break
                        self.assertNotIn("SCRIPT ERROR:", line)
                    self.assertTrue(ready, f"{mode} never reached persisted state")
                process.kill()
                process.wait(timeout=5)
                self.assertLess(process.returncode, 0, "Process must end without graceful shutdown")
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait(timeout=5)
                process.stdout.close()

        def run(mode):
            result = subprocess.run(command + [mode], env=env, capture_output=True, text=True, timeout=45)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertNotIn("SCRIPT ERROR:", result.stdout + result.stderr)

        run_and_kill("seed")
        run("restore")
        run("failed-write")
        run_and_kill("partial-update")
        run("restore")
        run_and_kill("unchecked")
        run("missing")


if __name__ == "__main__":
    unittest.main()
