import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from tools.run_android_quality_benchmark import ORDERS, PACKAGE, fixture_pins, require_debug_manifest, save_progress, validate


class AndroidQualityResultTests(unittest.TestCase):
    def setUp(self):
        self.fixture = {"schema": 1, "run_id": "fresh", "phase_seconds": 15, "order": "descending", "port": 40000}
        self.details = {"run_id": "fresh", "complete": True, "failures": [], "engine_errors": [],
                        "native_size": [2400, 1080], "phases": [],
                        "lifecycle": {"pauses": 1, "resumes": 1, "opt_out_cleared": True}}
        for i, preset in enumerate(ORDERS["descending"]):
            size = {"low": [1200, 540], "medium": [1600, 720], "high": [2400, 1080], "ultra": [2400, 1080]}[preset]
            metric = {"count": 900, "p50": 16.7, "p95": 18.0, "max": 25.0}
            self.details["phases"].append({"index": i, "preset": preset, "seconds": 15.01,
                "render_size": size, "response_size": size, "msaa": {"low": 0, "medium": 1, "high": 1, "ultra": 2}[preset],
                "native": {"androidApi": 37, "processPssBytes": 100000000},
                "timings": {key: dict(metric) for key in ("frame_ms", "main_gpu_ms", "response_gpu_ms")}})

    def test_complete_real_profiles_and_lifecycle(self):
        self.assertEqual(validate(self.details, self.fixture), [])

    def test_fixture_includes_actual_actors_and_transformation_art(self):
        keys = [row[0] for row in fixture_pins()]
        for actor, form in (("charizard", "base"), ("charizard", "mega-x"),
                            ("charizard", "mega-y"), ("dragonite", "base"), ("dragonite", "mega")):
            self.assertEqual(sum(key.startswith(f"optional-assets/pokemon_3d/{actor}/{form}/") for key in keys), 1)

    def test_only_the_separate_debug_identity_can_be_installed(self):
        manifest = ('    A: package="' + PACKAGE + '"\n'
                    '    E: application (line=22)\n'
                    '      A: android:debuggable(0x0101000f)=(type 0x12)0xffffffff\n')
        require_debug_manifest(manifest)
        for bad in (manifest.replace(PACKAGE, "com.pokeaether.game"), manifest.replace("0xffffffff", "0x0")):
            with self.assertRaises(ValueError):
                require_debug_manifest(bad)

    def test_rejects_stale_partial_and_wrong_profile_results(self):
        for change in (lambda d: d.update(run_id="old"), lambda d: d.update(complete=False),
                       lambda d: d["phases"].pop(), lambda d: d["phases"][2].update(msaa=2),
                       lambda d: d["phases"][3].update(response_size=[2400, 1080]),
                       lambda d: d["phases"][0]["native"].clear(),
                       lambda d: d["lifecycle"].update(opt_out_cleared=False)):
            detail = copy.deepcopy(self.details)
            change(detail)
            self.assertTrue(validate(detail, self.fixture))

    def test_slow_finite_frames_are_evidence_not_an_automatic_invalid_run(self):
        detail = copy.deepcopy(self.details)
        for phase in detail["phases"]:
            phase["timings"]["frame_ms"].update(count=10, p50=1000, p95=1500, max=2000)
        self.assertEqual(validate(detail, self.fixture), [])

    def test_rejects_nonfinite_samples(self):
        detail = copy.deepcopy(self.details)
        detail["phases"][0]["timings"]["frame_ms"]["p95"] = float("nan")
        self.assertTrue(validate(detail, self.fixture))

    def soak_result(self):
        fixture = dict(self.fixture, mode="soak", preset="ultra", phase_seconds=30)
        details = copy.deepcopy(self.details)
        row = details["phases"][0]
        details["phases"] = [dict(copy.deepcopy(row), index=i, seconds=30.01,
            stage_instance=1234, preparation_ms=0, elapsed_seconds=(i + 1) * 30.01) for i in range(40)]
        return fixture, details

    def test_twenty_minute_single_stage_soak(self):
        fixture, details = self.soak_result()
        self.assertEqual(validate(details, fixture), [])

    def test_shortened_recreated_or_reprepared_soak_is_rejected(self):
        for change in (lambda d: d["phases"].pop(),
                       lambda d: d["phases"][20].update(stage_instance=5678),
                       lambda d: d["phases"][-1].update(elapsed_seconds=1199),
                       lambda d: d["phases"][20].update(preparation_ms=3000),
                       lambda d: d["phases"][20].update(seconds=0)):
            fixture, details = self.soak_result()
            change(details)
            self.assertTrue(validate(details, fixture))

    def warm_result(self):
        fixture = dict(self.fixture, mode="warm-compare", phase_seconds=30)
        details = copy.deepcopy(self.details)
        rows = [details["phases"][i] for i in (1, 2, 2, 1)]
        details.update(preheat_ready=True, preheat_stage=101,
            preheat=[{"elapsed_seconds": 360, "fps": 52, "native": {"thermalStatus": 2}}])
        details["phases"] = [dict(copy.deepcopy(row), index=i, seconds=30.01,
            preparation_ms=0 if i in (0, 2) else 3000,
            stage_instance=(101, 202, 202, 303)[i], native_start={"thermalStatus": 2}) for i, row in enumerate(rows)]
        for row in details["phases"]:
            row["native"]["thermalStatus"] = 2
        return fixture, details

    def test_complete_bounded_warm_comparison(self):
        fixture, details = self.warm_result()
        self.assertEqual(validate(details, fixture), [])

    def test_cold_unbounded_wrong_order_or_recreated_comparison_rejected(self):
        for change in (lambda d: d.update(preheat_ready=False),
                       lambda d: d["preheat"][-1].update(elapsed_seconds=700),
                       lambda d: d["preheat"][-1]["native"].update(thermalStatus=1),
                       lambda d: d["preheat"][-1].update(fps=60),
                       lambda d: d["phases"][0].update(stage_instance=999),
                       lambda d: d["phases"][2].update(stage_instance=404),
                       lambda d: d["phases"][0]["native_start"].update(thermalStatus=0),
                       lambda d: d["phases"][-1]["native"].update(thermalStatus=4),
                       lambda d: d["phases"][1].update(preset="high"),
                       lambda d: d["phases"][1].update(seconds=15)):
            fixture, details = self.warm_result()
            change(details)
            self.assertTrue(validate(details, fixture))

    def test_cooling_is_recorded_not_misreported_as_an_invalid_measurement(self):
        fixture, details = self.warm_result()
        for row in details["phases"][1:]:
            row["native_start"]["thermalStatus"] = 1
            row["native"]["thermalStatus"] = 1
        self.assertEqual(validate(details, fixture), [])

    def gameplay_result(self):
        fixture = dict(self.fixture, mode="gameplay", phase_seconds=30)
        details = copy.deepcopy(self.details)
        row = details["phases"][2]
        metric = copy.deepcopy(row["timings"])
        details["phases"] = [dict(copy.deepcopy(row), index=i, seconds=30.01,
            stage_instance=100 + i, gameplay={"complete": True, "cycle": i,
                "moves": [{"move": move, "seconds": 3, "effect_frames": 120,
                           "hit_seen": True, "cleaned": True, "timings": copy.deepcopy(metric)}
                          for move in ("Flamethrower", "Thunderbolt", "Rock Slide", "Draco Meteor")],
                "tabs": [{"tab": tab, "visible": True} for tab in range(8)]}) for i in range(3)]
        return fixture, details

    def test_animated_moves_menus_and_reconstructed_arenas(self):
        fixture, details = self.gameplay_result()
        self.assertEqual(validate(details, fixture), [])

    def test_missing_animations_impacts_cleanup_tabs_or_reload_rejected(self):
        for change in (lambda d: d["phases"][1].update(stage_instance=100),
                       lambda d: d["phases"][0]["gameplay"].update(complete=False),
                       lambda d: d["phases"][0]["gameplay"]["moves"].pop(),
                       lambda d: d["phases"][0]["gameplay"]["moves"][0].update(hit_seen=False),
                       lambda d: d["phases"][0]["gameplay"]["moves"][0].update(cleaned=False),
                       lambda d: d["phases"][0]["gameplay"]["moves"][0].update(effect_frames=0),
                       lambda d: d["phases"][0]["gameplay"]["moves"][0]["timings"]["frame_ms"].update(p95=float("nan")),
                       lambda d: d["phases"][0]["gameplay"]["tabs"].pop()):
            fixture, details = self.gameplay_result()
            change(details)
            self.assertTrue(validate(details, fixture))

    def test_interrupted_host_preserves_partial_evidence_as_unusable(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            code = '''
import signal, sys
from pathlib import Path
from tools.run_android_quality_benchmark import interrupt_run, save_progress
report = {"usable": False, "running": True, "errors": []}
signal.signal(signal.SIGTERM, interrupt_run)
try:
    save_progress(Path(sys.argv[1]), report, {"complete": False}, [{"reportId": "partial"}])
    signal.raise_signal(signal.SIGTERM)
except RuntimeError as error:
    report["errors"].append(str(error))
finally:
    report["running"] = False
    save_progress(Path(sys.argv[1]), report, {"complete": False}, [{"reportId": "partial"}])
'''
            subprocess.run([sys.executable, "-c", code, directory], check=True)
            report = json.loads((path / "report.json").read_text())
            self.assertFalse(report["usable"] or report["running"])
            self.assertIn("signal 15", report["errors"][0])
            self.assertEqual(json.loads((path / "telemetry.json").read_text())["reports"], [{"reportId": "partial"}])
            self.assertFalse(json.loads((path / "details.json").read_text())["complete"])
            self.assertEqual(list(path.glob("*.partial")), [])


if __name__ == "__main__":
    unittest.main()
