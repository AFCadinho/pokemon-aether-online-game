#!/usr/bin/env python3
"""Offline HTTP qualification using actual launcher code and isolated release pins.

Invoke through slot-env. The tiny project references tracked code/data in place
and owns its import cache. No credentials, caches or player userdata are copied.
"""
import argparse
import hashlib
import json
import os
import platform
import shutil
from pathlib import Path
import subprocess
import threading
import time
from http.server import ThreadingHTTPServer

from asset_bundle_http_server import Handler


class NativeHandler(Handler):
    paced = False

    def log_message(self, _format, *_args):
        pass

    def _serve(self, body):
        if self.paced and self.path.split("?", 1)[0] != "/fault/slow-cancel.zip":
            # Same Range response headers as Handler, but give the real UI
            # time to pause a transfer before it completes on localhost.
            original = self.wfile

            class PacedWriter:
                def write(self, payload):
                    for offset in range(0, len(payload), 262144):
                        original.write(payload[offset:offset + 262144])
                        original.flush()
                        time.sleep(0.01)
                    return len(payload)

                def __getattr__(self, name):
                    return getattr(original, name)

            self.wfile = PacedWriter()
            try:
                return super()._serve(body)
            except (BrokenPipeError, ConnectionResetError):
                return
            finally:
                self.wfile = original
        if self.path.split("?", 1)[0] != "/fault/slow-cancel.zip":
            try:
                return super()._serve(body)
            except (BrokenPipeError, ConnectionResetError):
                return  # A cancelled connection is intentional in this fixture.
        payload = self.files["/fault/slow-cancel.zip"].read_bytes()
        self.send_response(200)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        if body:
            try:
                for offset in range(0, len(payload), 262144):
                    self.wfile.write(payload[offset:offset + 262144])
                    self.wfile.flush()
                    time.sleep(0.05)
            except (BrokenPipeError, ConnectionResetError):
                pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("fixture", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--streaming", action="store_true", help="Exercise the actual Downloads UI and restart recovery")
    parser.add_argument("--materialize-sources", action="store_true", help="Write only allowlisted source files into fresh projects; no symlink privileges needed")
    parser.add_argument("--expected-platform", choices=["Linux", "Windows", "Darwin"])
    parser.add_argument("--expected-architecture", choices=["x86_64", "arm64"])
    args = parser.parse_args()
    if args.expected_platform and platform.system() != args.expected_platform:
        raise ValueError("Qualification must run on the requested native platform")
    host_arch = {"AMD64": "x86_64", "aarch64": "arm64"}.get(platform.machine(), platform.machine())
    if args.expected_architecture and host_arch != args.expected_architecture:
        raise ValueError("Qualification must run on the requested native architecture")
    launcher = Path(__file__).resolve().parents[1]
    frontend = launcher.parent
    output = args.output.resolve()
    output.relative_to(frontend / ".tmp")
    output.mkdir(parents=True, exist_ok=False)
    files = ["scripts/release_asset_bundles.gd", "scripts/asset_bundle_store.gd",
        "scripts/asset_bundle_index.gd", "scripts/resumable_download_service.gd",
        "scripts/model_pack_manifest.gd", "tests/native_compression_install_check.gd"]
    files += [str(p.relative_to(launcher)) for p in (launcher / "data").glob("approved_3d_release_v*.json")]
    files += ["data/reviewed_model_catalog.json", "data/screened_model_catalog.json"]
    if args.streaming:
        tracked = subprocess.check_output(["git", "-C", str(frontend), "ls-files", "-z", "--",
            "launcher/scripts", "launcher/scenes", "launcher/assets", "launcher/localization"])
        files += [str(Path(p).relative_to("launcher")) for p in tracked.decode().split("\0")
                  if p and Path(p).suffix not in [".uid", ".import"]]
        files += ["tests/fixtures/offline_bulk_launcher.gd", "tests/native_streaming_collection_check.gd"]
        files = sorted(set(files))
    fixture = json.loads(args.fixture.read_text())
    NativeHandler.files = {url: Path(path) for url, path in fixture["routes"].items()}
    NativeHandler.paced = args.streaming
    native_index = json.loads(Path(fixture["stages"][-1]["index_path"]).read_text())
    cancelled_asset = next(a for a in native_index["assets"] if a["asset_id"] == fixture["failure_asset_id"])
    NativeHandler.files["/fault/slow-cancel.zip"] = NativeHandler.files["/" + cancelled_asset["object_key"]]
    server = ThreadingHTTPServer(("127.0.0.1", 0), NativeHandler)
    server.daemon_threads = True
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    env = os.environ.copy()
    env.update(POKEAETHER_NATIVE_HTTP_BASE=f"http://127.0.0.1:{server.server_port}",
        POKEAETHER_NATIVE_FIXTURE=str(args.fixture.resolve()),
        POKEAETHER_NATIVE_INSTALL_OUTPUT=str(output / "installed"))
    godot = os.environ.get("GODOT_BIN", "godot")
    version = subprocess.check_output([godot, "--log-file", str(output / "version-engine.log"), "--version"], text=True).strip()
    if not version.startswith("4.6.2.stable."):
        raise ValueError("Qualification requires the pinned Godot 4.6.2 stable engine")
    try:
        reports = []
        phases = ["policy", "original-pause", "original", "native-256k", "rollback"] if args.streaming else ["policy", "original", "native-256k", "native-1m", "rollback"]
        for phase in phases:
            project = output / (phase + "-project")
            project.mkdir()
            selected = fixture["stages"][0] if phase in ["policy", "original-pause", "rollback"] else next(s for s in fixture["stages"] if s["label"] == phase)
            for relative in files:
                source = launcher / relative
                target = project / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                if phase != "policy" and relative == "data/approved_3d_release_v10.json":
                    descriptor = selected["descriptor"]
                    pins = {"schema": 1, "revision": descriptor["revision"], "requiredAssetIds": descriptor["requiredAssetIds"],
                        "index": {"sha256": descriptor["sha256"], "size_bytes": descriptor["sizeBytes"], "object_key": descriptor["object_key"]}}
                    target.write_text(json.dumps(pins) + "\n")
                elif phase != "policy" and relative == "data/reviewed_model_catalog.json":
                    approval = json.loads(source.read_text())
                    for identity, model in selected["models"].items():
                        model = dict(model)
                        model["previous_sha256"] = list({s["models"][identity]["sha256"] for s in fixture["stages"]} - {model["sha256"]})
                        approval["models"][identity] = model
                    target.write_text(json.dumps(approval) + "\n")
                else:
                    if args.materialize_sources:
                        shutil.copyfile(source, target) # Only the explicit tracked source allowlist above.
                    else:
                        target.symlink_to(source)
                uid = Path(str(source) + ".uid")
                if uid.exists():
                    if args.materialize_sources:
                        shutil.copyfile(uid, Path(str(target) + ".uid"))
                    else:
                        Path(str(target) + ".uid").symlink_to(uid)
            project_settings = (launcher / "project.godot").read_text() if args.streaming else 'config_version=5\n[application]\nconfig/name="Native bundle launcher fixture"\n'
            if args.streaming:
                user_dir = "lossless-collection-" + hashlib.sha256(str(output).encode()).hexdigest()[:16]
                project_settings = project_settings.replace("[application]", '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir="' + user_dir + '"')
            (project / "project.godot").write_text(project_settings)
            env["POKEAETHER_NATIVE_PHASE"] = phase
            with (output / (phase + "-import.log")).open("w") as log:
                subprocess.run([godot, "--headless", "--path", str(project), "--log-file", str(output / (phase + "-import-engine.log")), "--editor", "--import"],
                               env=env, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=120)
            with (output / (phase + "-launcher.log")).open("w") as log:
                script = "native_streaming_collection_check.gd" if args.streaming else "native_compression_install_check.gd"
                subprocess.run([godot, "--headless", "--path", str(project), "--log-file", str(output / (phase + "-engine.log")), "--script",
                    "res://tests/" + script], env=env,
                    stdout=log, stderr=subprocess.STDOUT, check=True, timeout=360)
            result = json.loads((output / ("installed/" + phase + "-report.json")).read_text())
            log_text = (output / (phase + "-launcher.log")).read_text()
            if "\nERROR:" in log_text or "\nSCRIPT ERROR:" in log_text:
                raise ValueError("Launcher emitted an engine/script error: " + phase)
            if not result["complete"] or result.get("failure"):
                raise ValueError("Launcher qualification did not complete: " + phase)
            if args.streaming and phase != "policy" and result.get("engine_os") != {"Linux": "Linux", "Windows": "Windows", "Darwin": "macOS"}[platform.system()]:
                raise ValueError("The tested Godot executable is not native to this platform")
            if args.expected_architecture and phase != "policy" and result.get("engine_architecture") != args.expected_architecture:
                raise ValueError("The tested Godot architecture differs from the qualification target")
            reports.append(result)
        (output / "report.json").write_text(json.dumps({"complete": True, "production_approved": False,
            "host_os": platform.system(), "host_architecture": platform.machine(), "godot_version": version,
            "fixture_sha256": hashlib.sha256(args.fixture.read_bytes()).hexdigest(),
            "commit": subprocess.check_output(["git", "-C", str(frontend), "rev-parse", "HEAD"], text=True).strip(),
            "phases": reports}, indent=2) + "\n")
        print("NATIVE_HTTP_INSTALLATION_OK", flush=True)
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)


if __name__ == "__main__":
    main()
