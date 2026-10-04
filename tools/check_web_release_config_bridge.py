#!/usr/bin/env python3
"""Exercise the real Godot web bridge and HOME URL resolver in Chromium, locally."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import argparse
import os
from pathlib import Path
import subprocess
import threading


ROOT = Path(__file__).resolve().parents[1]

PROBE = '''extends Node
const Runtime := preload("res://web_runtime.gd")

class IconLoader extends RefCounted:
{icon_resolver}

func _ready() -> void:
	JavaScriptBridge.eval('window.POKEAETHER_WEB_RELEASE = Object.freeze({{buildId:"test-build-42-1",spriteStyles:{{animated:{{front:"https://assets.example.invalid/front"}}}}}})', true)
	var unsupported: Variant = JavaScriptBridge.eval("window.POKEAETHER_WEB_RELEASE", true)
	var config := Runtime.web_release_config()
	var icon_url: String = IconLoader.new()._asset_url("home-icons/catalog.json")
	var expected := Runtime.api_base_url().trim_suffix("/api") + "/web/releases/test-build-42-1/home-icons/catalog.json"
	var result := {{"plainObjectReturnsNull": unsupported == null,
		"releaseConfigLoads": config.get("buildId", "") == "test-build-42-1",
		"nestedConfigLoads": config.get("spriteStyles", {{}}).has("animated"),
		"homeUrlUsesBuild": icon_url == expected, "homeUrl": icon_url}}
	JavaScriptBridge.eval("delete window.POKEAETHER_WEB_RELEASE", true)
	result["missingConfigIsEmpty"] = Runtime.web_release_config().is_empty()
	JavaScriptBridge.eval("window.POKEAETHER_WEB_RELEASE = [1, 2, 3]", true)
	result["nonObjectConfigIsEmpty"] = Runtime.web_release_config().is_empty()
	JavaScriptBridge.eval("document.body.dataset.releaseConfigProbe = " + JSON.stringify(JSON.stringify(result)), true)
'''

NODE_PROBE = '''const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({executablePath: process.env.POKEAETHER_CHROME_PATH || undefined,
    args: ['--enable-unsafe-swiftshader']});
  try {
    const page = await browser.newPage();
    const origin = new URL(process.argv[1]).origin;
    await page.route('**/*', route => new URL(route.request().url()).origin === origin
      ? route.continue() : route.abort());
    await page.goto(process.argv[1]);
    await page.waitForFunction(() => document.body.dataset.releaseConfigProbe, null, {timeout: 60000});
    const result = JSON.parse(await page.locator('body').getAttribute('data-release-config-probe'));
    require('fs').writeFileSync(process.argv[2], JSON.stringify(result, null, 2));
    console.log(JSON.stringify(result));
    if (Object.entries(result).some(([key, value]) => key !== 'homeUrl' && value !== true)) process.exitCode = 1;
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
'''


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--runtime-ref", help="Optional Git revision to reproduce a previous bridge implementation.")
    args = parser.parse_args()
    if ROOT.parent.name.startswith("slot-") and os.environ.get("POKEAETHER_SLOT") != ROOT.parent.name:
        parser.error("Run through ops/worktrees/slot-env SLOT -- COMMAND.")
    fixture = ROOT / "builds/web-release-config-bridge"
    fixture.mkdir(parents=True, exist_ok=True)
    runtime = (ROOT / "scripts/services/web_runtime.gd").read_text()
    if args.runtime_ref:
        runtime = subprocess.check_output(["git", "show", args.runtime_ref + ":scripts/services/web_runtime.gd"],
                                          cwd=ROOT, text=True)
    (fixture / "web_runtime.gd").write_text(runtime)
    service = (ROOT / "scripts/services/web_home_icon_service.gd").read_text()
    resolver = service.split("func _asset_url(", 1)[1].split("\nfunc _download(", 1)[0]
    resolver = "\n".join("\t" + line for line in ("func _asset_url(" + resolver).splitlines())
    (fixture / "probe.gd").write_text(PROBE.format(icon_resolver=resolver))
    (fixture / "probe.tscn").write_text('[gd_scene load_steps=2 format=3]\n'
        '[ext_resource type="Script" path="res://probe.gd" id="1"]\n'
        '[node name="Probe" type="Node"]\nscript = ExtResource("1")\n')
    (fixture / "project.godot").write_text('config_version=5\n[application]\n'
        'run/main_scene="res://probe.tscn"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    (fixture / "export_presets.cfg").write_text('[preset.0]\nname="Web Probe"\nplatform="Web"\n'
        'export_filter="all_resources"\n[preset.0.options]\nvariant/extensions_support=false\n'
        'variant/thread_support=false\n')
    with (fixture / "export.log").open("w") as log:
        subprocess.run([args.godot, "--headless", "--path", str(fixture), "--import", "--quit"],
                       stdout=log, stderr=subprocess.STDOUT, timeout=60, check=True)
        subprocess.run([args.godot, "--headless", "--path", str(fixture), "--export-release", "Web Probe",
                        str(fixture / "index.html")], stdout=log, stderr=subprocess.STDOUT, timeout=60, check=True)
    server = ThreadingHTTPServer(("127.0.0.1", 0), partial(QuietHandler, directory=str(fixture)))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        subprocess.run(["node", "-e", NODE_PROBE, f"http://127.0.0.1:{server.server_port}/index.html",
                        str(fixture / "result.json")], cwd=ROOT, timeout=90, check=True)
    finally:
        server.shutdown()
        server.server_close()
    print("web_release_config_bridge: PASS (real web bridge and versioned HOME icon URL)")


if __name__ == "__main__":
    main()
