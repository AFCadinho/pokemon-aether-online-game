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
        details["move_captures"] = [{"index": i, "elapsed": 1.1, "impact": 1.0, "visible_pieces": 10} for i in range(4)]
        details["phases"] = [dict(copy.deepcopy(row), index=i, seconds=30.01,
            stage_instance=100 + i, gameplay={"complete": True, "cycle": i,
                "moves": [{"move": move, "seconds": 3, "effect_frames": 120, "visible_frames": 100,
                           "hit_seen": True, "cleaned": True, "timings": copy.deepcopy(metric)}
                          for move in ("Flamethrower", "Thunderbolt", "Rock Slide", "Draco Meteor")],
                "tabs": [{"tab": tab, "visible": True} for tab in range(8)]}) for i in range(3)]
        return fixture, details

    def test_animated_moves_menus_and_reconstructed_arenas(self):
        fixture, details = self.gameplay_result()
        self.assertEqual(validate(details, fixture), [])

    def profile_result(self):
        fixture, details = self.gameplay_result()
        fixture["profile_hitches"] = True
        details["profile_factory_match"] = True
        for phase in details["phases"]:
            phase["hitch_profile"] = {"dropped": 0, "effects": [
                {"move": move, "process_cpu_ms": {"count": 60, "p50": .1, "p95": 2, "max": 50}}
                for move in ("Flamethrower", "Thunderbolt", "Rock Slide", "Draco Meteor")], "events": [
                    {"kind": "span", "label": label, "from_usec": 100000, "to_usec": 250000, "ms": 150}
                    for label in ("router_load_new", "menu_load", "menu_instantiate", "menu_add_ready", "menu_open_new",
                                  "menu_close_new", "menu_open_retained", "menu_close_retained")]}
            phase["gameplay"].update(menu_instance=100, reopened_menu_instance=100,
                reopen_tabs=[{"tab": tab, "visible": True} for tab in range(8)])
        return fixture, details

    def test_complete_hitch_spans_effect_probes_and_menu_reuse(self):
        fixture, details = self.profile_result()
        self.assertEqual(validate(details, fixture), [])

    def visibility_result(self):
        fixture, details = self.profile_result()
        fixture["hitch_visibility_control"] = True
        phase = copy.deepcopy(details["phases"][0])
        phase.update(index=3, stage_instance=103)
        phase["gameplay"]["cycle"] = 3
        details["phases"].append(phase)
        for index, phase in enumerate(details["phases"]):
            visible = index in (0, 3)
            phase["hitch_profile"]["effects_visible"] = visible
            for move in phase["gameplay"]["moves"]:
                move.update(render_visible_frames=100 if visible else 0, suppressed_frames=0 if visible else 100)
        return fixture, details

    def test_visible_hidden_hidden_visible_with_live_geometry(self):
        fixture, details = self.visibility_result()
        self.assertEqual(validate(details, fixture), [])

    def test_visibility_order_rendered_hidden_effects_or_inactive_controls_rejected(self):
        for change in (lambda d: d["phases"][1]["hitch_profile"].update(effects_visible=True),
                       lambda d: d["phases"][1]["gameplay"]["moves"][0].update(render_visible_frames=1),
                       lambda d: d["phases"][1]["gameplay"]["moves"][0].update(suppressed_frames=0),
                       lambda d: d["phases"][3]["gameplay"]["moves"][0].update(render_visible_frames=0),
                       lambda d: d.update(profile_factory_match=False),
                       lambda d: d["phases"].pop()):
            fixture, details = self.visibility_result()
            change(details)
            self.assertTrue(validate(details, fixture))

    def entry_result(self, enabled=True):
        fixture, details = self.gameplay_result()
        fixture.update(mode="battle-entry", entry_warmup=enabled)
        keys = ["flamethrower", "thunderbolt", "rockslide", "dracometeor"]
        for kind, phase in zip(["covered_wild", "early_wild", "preview_trainer"], details["phases"]):
            phase["entry"] = {"case": kind, "ready": True, "warmup_enabled": enabled,
                "input_held_during_preparation": True, "samples_hidden": True, "available_keys": keys,
                "elapsed_ms": 6000, "early_visible_before_response": kind == "early_wild", "selected_slot": 2,
                "previews_have_no_casts": True, "actors": ["dragonite", "charizard"],
                "prepared": {key: 9000 + i for i, key in enumerate(keys)} if enabled else {},
                "warmup": [{"mode": "hidden", "elapsed_ms": 900, "effects": 4,
                    "samples": [{"key": key, "instance": 9000 + i, "active_samples": 5, "drawn_samples": 0}
                                for i, key in enumerate(keys)]}] if enabled else []}
            for i, move in enumerate(phase["gameplay"]["moves"]): move["prepared_instance"] = 9000 + i if enabled else 0
        return fixture, details

    def test_ordinary_entry_with_real_request_and_prepared_factory_handoff(self):
        for enabled in (False, True):
            fixture, details = self.entry_result(enabled)
            self.assertEqual(validate(details, fixture), [])

    def test_rejects_early_input_wrong_lead_missing_request_or_wrong_handoff(self):
        for change in (lambda d: d["phases"][0]["entry"].update(ready=False),
                       lambda d: d["phases"][0]["entry"].update(input_held_during_preparation=False),
                       lambda d: d["phases"][0]["entry"].update(samples_hidden=False),
                       lambda d: d["phases"][0]["entry"].update(available_keys=[]),
                       lambda d: d["phases"][0]["entry"].update(warmup_enabled=False),
                       lambda d: d["phases"][0]["entry"].update(warmup=[]),
                       lambda d: d["phases"][0]["entry"]["warmup"][0].update(elapsed_ms=float("nan")),
                       lambda d: d["phases"][0]["entry"]["warmup"][0]["samples"][0].update(drawn_samples=1),
                       lambda d: d["phases"][1]["entry"].update(early_visible_before_response=False),
                       lambda d: d["phases"][2]["entry"].update(selected_slot=1),
                       lambda d: d["phases"][2]["entry"].update(actors=["charizard", "dragonite"]),
                       lambda d: d["phases"][2]["entry"].update(previews_have_no_casts=False),
                       lambda d: d["phases"][0]["gameplay"]["moves"][0].update(prepared_instance=123)):
            fixture, details = self.entry_result()
            change(details)
            self.assertTrue(validate(details, fixture))

    def test_entry_warmup_build_flag_is_restricted_to_private_quality_apk(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "forbidden"
            run = subprocess.run([sys.executable, "tools/export_battle_entry_web_qa.py", "--suite", "battle-entry",
                                  "--entry-move-warmup", "--output", str(output)], capture_output=True, text=True)
            self.assertEqual(run.returncode, 2)
            self.assertIn("limited to the separate Android quality APK", run.stderr)
            self.assertFalse(output.exists())

    def prepared_result(self, mode="covered"):
        fixture, details = self.profile_result()
        fixture["first_cast_preparation"] = mode
        for row in details["phases"]:
            row["cast_preparation"] = {"mode": mode, "elapsed_ms": 1200, "effects": 4,
                "complete_keys": ["flamethrower", "thunderbolt", "rockslide", "dracometeor"],
                "samples": [{"key": key, "instance": 1000 + i, "active_samples": 5,
                    "drawn_samples": 5 if mode == "covered" else 0, "max_sample_ms": 80, "pieces": 40}
                    for i, key in enumerate(["flamethrower", "thunderbolt", "rockslide", "dracometeor"])]}
            for i, move in enumerate(row["gameplay"]["moves"]): move["prepared_instance"] = 1000 + i
        return fixture, details

    def test_hidden_and_covered_same_instance_preparation(self):
        for mode in ("hidden", "covered"):
            fixture, details = self.prepared_result(mode)
            self.assertEqual(validate(details, fixture), [])

    def test_slow_complete_preparation_is_kept_as_timing_evidence(self):
        fixture, details = self.prepared_result()
        details["phases"][0]["cast_preparation"]["elapsed_ms"] = 4000
        self.assertEqual(validate(details, fixture), [])

    def test_rejects_incomplete_preparation_wrong_instance_or_missing_draw_proof(self):
        for change in (lambda p: p["cast_preparation"].update(mode="hidden"),
                       lambda p: p["cast_preparation"].update(elapsed_ms=float("nan")),
                       lambda p: p["cast_preparation"]["complete_keys"].pop(),
                       lambda p: p["cast_preparation"]["samples"].pop(),
                       lambda p: p["cast_preparation"]["samples"][0].update(drawn_samples=0),
                       lambda p: p["cast_preparation"]["samples"][0].update(active_samples=0),
                       lambda p: p["cast_preparation"]["samples"][0].update(max_sample_ms=float("inf")),
                       lambda p: p["gameplay"]["moves"][0].update(prepared_instance=123)):
            fixture, details = self.prepared_result()
            change(details["phases"][0])
            self.assertTrue(validate(details, fixture))
        fixture, details = self.prepared_result("hidden")
        details["phases"][0]["cast_preparation"]["samples"][0]["drawn_samples"] = 1
        self.assertTrue(validate(details, fixture))

    def test_missing_truncated_invalid_profiles_or_new_instead_of_reused_menu_rejected(self):
        for change in (lambda p: p["hitch_profile"].update(dropped=1),
                       lambda p: p["hitch_profile"]["events"].clear(),
                       lambda p: p["hitch_profile"]["events"].pop(),
                       lambda p: p["hitch_profile"]["events"][0].update(ms=float("inf")),
                       lambda p: p["hitch_profile"]["events"][0].update(to_usec=0),
                       lambda p: p["hitch_profile"]["effects"][0]["process_cpu_ms"].update(max=float("nan")),
                       lambda p: p["hitch_profile"]["effects"].pop(),
                       lambda p: p["gameplay"].update(reopened_menu_instance=101),
                       lambda p: p["gameplay"]["reopen_tabs"].pop()):
            fixture, details = self.profile_result()
            change(details["phases"][0])
            self.assertTrue(validate(details, fixture))

    def test_missing_animations_impacts_cleanup_tabs_or_reload_rejected(self):
        for change in (lambda d: d["phases"][1].update(stage_instance=100),
                       lambda d: d["move_captures"].pop(),
                       lambda d: d["move_captures"][0].update(elapsed=0),
                       lambda d: d["move_captures"][0].update(visible_pieces=0),
                       lambda d: d["phases"][0]["gameplay"].update(complete=False),
                       lambda d: d["phases"][0]["gameplay"]["moves"].pop(),
                       lambda d: d["phases"][0]["gameplay"]["moves"][0].update(hit_seen=False),
                       lambda d: d["phases"][0]["gameplay"]["moves"][0].update(cleaned=False),
                       lambda d: d["phases"][0]["gameplay"]["moves"][0].update(effect_frames=0),
                       lambda d: d["phases"][0]["gameplay"]["moves"][0].update(visible_frames=0),
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
