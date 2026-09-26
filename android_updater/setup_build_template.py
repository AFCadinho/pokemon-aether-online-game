#!/usr/bin/env python3
"""Install the local Godot 4.6 Android template and apply the APK installer overlay."""

from pathlib import Path
import shutil
import sys
import zipfile


ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "android" / "build"
OVERLAY = ROOT / "android_updater"


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: setup_build_template.py /path/to/android_source.zip", file=sys.stderr)
        return 2
    template = Path(sys.argv[1]).resolve()
    if not template.is_file():
        print(f"Android build template missing: {template}", file=sys.stderr)
        return 1
    version_file = template.parent / "version.txt"
    if not version_file.is_file():
        print(f"Godot template version missing: {version_file}", file=sys.stderr)
        return 1
    (BUILD.parent / ".build_version").parent.mkdir(parents=True, exist_ok=True)
    (BUILD.parent / ".build_version").write_text(version_file.read_text().strip() + "\n")
    (BUILD / ".gdignore").touch()
    if not (BUILD / "build.gradle").is_file():
        BUILD.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(template) as archive:
            archive.extractall(BUILD)
    (BUILD / "gradlew").chmod(0o755)
    properties_path = BUILD / "gradle.properties"
    properties = properties_path.read_text()
    properties = properties.replace("org.gradle.jvmargs=-Xmx4536m", "org.gradle.jvmargs=-Xmx2048m")
    if "org.gradle.workers.max=" not in properties:
        properties += "\norg.gradle.workers.max=2\n"
    properties_path.write_text(properties)
    manifest_path = BUILD / "src/main/AndroidManifest.xml"
    manifest = manifest_path.read_text()
    permission = '    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />\n'
    if permission not in manifest:
        manifest = manifest.replace("    <application\n", permission + "\n    <application\n", 1)
    # Godot 4.6's own FileProvider covers app-private files under filesRoot.
    # Remove an overlay from earlier local setup runs if present.
    provider_start = manifest.find('        <provider\n            android:name="androidx.core.content.FileProvider"')
    if provider_start != -1:
        provider_end = manifest.find("        </provider>\n", provider_start)
        if provider_end != -1:
            manifest = manifest[:provider_start] + manifest[provider_end + len("        </provider>\n"):]
    manifest_path.write_text(manifest)
    java_target = BUILD / "src/main/java/com/pokeaether/game/ApkInstallBridge.java"
    java_target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(OVERLAY / "ApkInstallBridge.java", java_target)
    (BUILD / "src/main/res/xml/apk_provider_paths.xml").unlink(missing_ok=True)
    print(f"Android APK installer overlay ready: {BUILD}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
