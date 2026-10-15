import copy
import unittest

from tools.run_android_quality_benchmark import ORDERS, PACKAGE, fixture_pins, require_debug_manifest, validate


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


if __name__ == "__main__":
    unittest.main()
