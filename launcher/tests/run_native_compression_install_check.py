#!/usr/bin/env python3
"""Offline HTTP qualification using actual launcher code and isolated release pins.

Invoke through slot-env. The tiny project references tracked code/data in place
and owns its import cache. No credentials, caches or player userdata are copied.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import threading
import time
from http.server import ThreadingHTTPServer

from asset_bundle_http_server import Handler


class NativeHandler(Handler):
    def _serve(self, body):
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
    args = parser.parse_args()
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
    fixture = json.loads(args.fixture.read_text())
    NativeHandler.files = {url: Path(path) for url, path in fixture["routes"].items()}
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
    try:
        reports = []
        for phase in ["policy", "original", "native-256k", "native-1m", "rollback"]:
            project = output / (phase + "-project")
            project.mkdir()
            selected = fixture["stages"][0] if phase in ["policy", "rollback"] else next(s for s in fixture["stages"] if s["label"] == phase)
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
                    target.symlink_to(source)
                uid = Path(str(source) + ".uid")
                if uid.exists():
                    Path(str(target) + ".uid").symlink_to(uid)
            (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Native bundle launcher fixture"\n')
            env["POKEAETHER_NATIVE_PHASE"] = phase
            with (output / (phase + "-import.log")).open("w") as log:
                subprocess.run([godot, "--headless", "--path", str(project), "--editor", "--import"],
                               env=env, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=120)
            with (output / (phase + "-launcher.log")).open("w") as log:
                subprocess.run([godot, "--headless", "--path", str(project), "--script",
                    "res://tests/native_compression_install_check.gd"], env=env,
                    stdout=log, stderr=subprocess.STDOUT, check=True, timeout=360)
            result = json.loads((output / ("installed/" + phase + "-report.json")).read_text())
            if not result["complete"] or result.get("failure"):
                raise ValueError("Launcher qualification did not complete: " + phase)
            reports.append(result)
        (output / "report.json").write_text(json.dumps({"complete": True, "production_approved": False, "phases": reports}, indent=2) + "\n")
        print("NATIVE_HTTP_INSTALLATION_OK", flush=True)
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)


if __name__ == "__main__":
    main()
