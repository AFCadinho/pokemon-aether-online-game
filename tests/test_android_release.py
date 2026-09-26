from pathlib import Path
from tempfile import TemporaryDirectory
import json
import unittest
import zipfile
from unittest.mock import patch

from tools.android_release import inspect, prepare, setting
import android_updater.setup_build_template as setup_build_template


class AndroidReleaseTests(unittest.TestCase):
    def test_setup_build_template_creates_missing_build_directory(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            template = root / "android_source.zip"
            (root / "version.txt").write_text("4.6.2.stable\n")
            with zipfile.ZipFile(template, "w") as archive:
                archive.writestr("build.gradle", "")
                archive.writestr("gradlew", "#!/bin/sh\n")
                archive.writestr("gradle.properties", "org.gradle.jvmargs=-Xmx4536m\n")
                archive.writestr("src/main/AndroidManifest.xml", "<manifest>\n    <application\n    </application>\n</manifest>\n")
            overlay = root / "overlay"
            overlay.mkdir()
            (overlay / "ApkInstallBridge.java").write_text("// test bridge\n")
            build = root / "android" / "build"
            self.assertFalse(build.exists())
            with patch.object(setup_build_template, "BUILD", build), \
                    patch.object(setup_build_template, "OVERLAY", overlay), \
                    patch("sys.argv", ["setup_build_template.py", str(template)]):
                self.assertEqual(setup_build_template.main(), 0)
            self.assertTrue((build / ".gdignore").is_file())
            self.assertTrue((build / "gradlew").stat().st_mode & 0o111)

    def test_prepare_stamps_matching_identity_and_rejects_old_code(self) -> None:
        with TemporaryDirectory() as directory:
            project = Path(directory) / "project.godot"
            presets = Path(directory) / "export_presets.cfg"
            project.write_text('[application]\nconfig/version="old"\nconfig/build_id="old"\nconfig/android_version_code=2\n')
            presets.write_text('[preset.7.options]\nversion/code=2\nversion/name="old"\npackage/unique_name="com.pokeaether.game"\n')
            with self.assertRaisesRegex(ValueError, "greater than 2"):
                prepare(project, presets, "0.3.84-alpha.3", 2, "build-3")
            prepare(project, presets, "0.3.84-alpha.3", 3, "build-3")
            self.assertEqual(setting(project, "application", "config/android_version_code"), "3")
            self.assertEqual(setting(project, "application", "config/build_id"), '"build-3"')
            self.assertEqual(setting(presets, "preset.7.options", "version/code"), "3")
            self.assertEqual(setting(presets, "preset.7.options", "version/name"), '"0.3.84-alpha.3"')

    def test_manifest_requires_matching_package_version_and_certificate(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            apk = root / "game-build-3-android.apk"
            apk.write_bytes(b"candidate-apk")
            output = root / "manifest-android.json"
            badging = "package: name='com.pokeaether.game' versionCode='3' versionName='0.3.84-alpha.3'\n"
            signature = f"Signer #1 certificate SHA-256 digest: {'a' * 64}\n"
            with patch("tools.android_release.subprocess.check_output", side_effect=[badging, signature]):
                manifest = inspect(apk, root / "aapt", root / "apksigner", "0.3.84-alpha.3",
                                   3, "build-3", "a" * 64, output)
            self.assertEqual(json.loads(output.read_text()), manifest)
            self.assertEqual(manifest["game"]["sizeBytes"], len(b"candidate-apk"))
            self.assertEqual(manifest["game"]["url"],
                             "https://updates.pokeaether.com/game/game-build-3-android.apk")
            with patch("tools.android_release.subprocess.check_output", side_effect=[badging, signature]):
                with self.assertRaisesRegex(ValueError, "signing certificate"):
                    inspect(apk, root / "aapt", root / "apksigner", "0.3.84-alpha.3",
                            3, "build-3", "b" * 64, output)
            with patch("tools.android_release.subprocess.check_output", return_value=badging.replace("versionCode='3'", "versionCode='2'")):
                with self.assertRaisesRegex(ValueError, "package or version"):
                    inspect(apk, root / "aapt", root / "apksigner", "0.3.84-alpha.3",
                            3, "build-3", "a" * 64, output)


if __name__ == "__main__":
    unittest.main()
