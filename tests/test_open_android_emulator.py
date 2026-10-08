from pathlib import Path
from tempfile import TemporaryDirectory
import subprocess
import os
import unittest
from unittest.mock import patch

from tools.open_android_emulator import main, PROFILES


class AndroidEmulatorIdentityTests(unittest.TestCase):
    def launch(self, profile, *, observed_name=None, abis="x86_64,arm64-v8a",
               boot_only=False, cold=False, host_gpu="auto", keyboard="auto"):
        name, port = PROFILES[profile]
        self.commands = []
        with TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "emulator").mkdir()
            (root / "emulator/emulator").touch()
            avd = root / (name + ".avd")
            avd.mkdir()
            (root / (name + ".ini")).write_text("path=" + str(avd) + "\n")

            def run(command, **kwargs):
                self.commands.append(command)
                self.assertEqual(command[1:3], ["-s", "emulator-" + port])
                tail = command[3:]
                if tail == ["emu", "avd", "name"]:
                    stdout = "" if cold and len(self.commands) == 1 else (observed_name or name) + "\nOK\n"
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
                    "--avd-home", str(root), "--profile", profile, "--host-gpu", host_gpu,
                    "--keyboard", keyboard]
            if boot_only:
                argv.append("--boot-only")
            with patch("sys.argv", argv), \
                    patch("tools.open_android_emulator.subprocess.run", side_effect=run), \
                    patch("tools.open_android_emulator.subprocess.Popen") as start:
                try:
                    main()
                finally:
                    if cold:
                        start.assert_called_once()
                        self.spawned_command = start.call_args.args[0]
                        self.spawned_environment = start.call_args.kwargs["env"]
                    else:
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

    def test_cold_nvidia_offload_is_scoped_to_emulator_process(self):
        with patch.dict(os.environ, {"__GLX_VENDOR_LIBRARY_NAME": "mesa"}):
            self.launch("phone", cold=True, boot_only=True, host_gpu="nvidia")
            self.assertEqual(os.environ["__GLX_VENDOR_LIBRARY_NAME"], "mesa")
        env = self.spawned_environment
        self.assertEqual(env["__NV_PRIME_RENDER_OFFLOAD"], "1")
        self.assertEqual(env["__GLX_VENDOR_LIBRARY_NAME"], "nvidia")
        self.assertEqual(env["__VK_LAYER_NV_optimus"], "NVIDIA_only")
        command = self.spawned_command
        self.assertEqual(command[command.index("-port") + 1], "5582")
        self.assertEqual(command[command.index("-gpu") + 1], "host")
        self.assertIn("-use-keycode-forwarding", command)

    def test_cold_default_preserves_existing_gpu_environment(self):
        with patch.dict(os.environ, {"__GLX_VENDOR_LIBRARY_NAME": "mesa"}):
            self.launch("native", cold=True, boot_only=True)
        self.assertEqual(self.spawned_environment["__GLX_VENDOR_LIBRARY_NAME"], "mesa")
        self.assertNotIn("-use-keycode-forwarding", self.spawned_command)

    def test_phone_can_explicitly_keep_character_translation(self):
        self.launch("phone", cold=True, boot_only=True, keyboard="text")
        self.assertNotIn("-use-keycode-forwarding", self.spawned_command)

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
