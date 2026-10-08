from pathlib import Path
from tempfile import TemporaryDirectory
import subprocess
import unittest
from unittest.mock import patch

from tools.open_android_emulator import main, PROFILES


class AndroidEmulatorIdentityTests(unittest.TestCase):
    def launch(self, profile, *, observed_name=None, abis="x86_64,arm64-v8a", boot_only=False):
        name, port = PROFILES[profile]
        self.commands = []
        with TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "emulator").mkdir()
            (root / "emulator/emulator").touch()
            (root / (name + ".ini")).touch()

            def run(command, **kwargs):
                self.commands.append(command)
                self.assertEqual(command[1:3], ["-s", "emulator-" + port])
                tail = command[3:]
                if tail == ["emu", "avd", "name"]:
                    stdout = (observed_name or name) + "\nOK\n"
                elif tail == ["shell", "getprop", "sys.boot_completed"]:
                    stdout = "1\n"
                elif tail == ["shell", "getprop", "ro.product.cpu.abilist"]:
                    stdout = abis + "\n"
                elif tail == ["shell", "pm", "path", "com.pokeaether.game"]:
                    stdout = "package:/data/app/game/base.apk\n"
                else:
                    stdout = "Starting: Intent\n"
                return subprocess.CompletedProcess(command, 0, stdout, "")

            argv = ["open_android_emulator", "--sdk", str(root),
                    "--avd-home", str(root), "--profile", profile]
            if boot_only:
                argv.append("--boot-only")
            with patch("sys.argv", argv), \
                    patch("tools.open_android_emulator.subprocess.run", side_effect=run), \
                    patch("tools.open_android_emulator.subprocess.Popen") as start:
                try:
                    main()
                finally:
                    start.assert_not_called()

    def test_phone_launches_on_its_own_serial(self):
        self.launch("phone")
        self.assertIn(["shell", "am", "start", "-n",
                       "com.pokeaether.game/com.godot.game.GodotAppLauncher"],
                      [command[3:] for command in self.commands])

    def test_native_qa_profile_still_accepts_x86_only(self):
        self.launch("native", abis="x86_64")

    def test_boot_only_does_not_require_or_launch_an_app(self):
        self.launch("phone", boot_only=True)
        self.assertFalse(any("pm" in command or "am" in command for command in self.commands))

    def test_refuses_foreign_device_before_launching(self):
        with self.assertRaises(SystemExit):
            self.launch("phone", observed_name="OtherDevice")
        self.assertEqual(len(self.commands), 1)

    def test_phone_without_arm_support_never_launches_game(self):
        with self.assertRaisesRegex(RuntimeError, "cannot run ARM64"):
            self.launch("phone", abis="x86_64")
        self.assertFalse(any("start" in command for command in self.commands))


if __name__ == "__main__":
    unittest.main()
