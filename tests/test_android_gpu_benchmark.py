import copy
import unittest

from tools.run_android_gpu_benchmark import MATRIX, comparisons, validate, require_debug_manifest


class GPUResultValidationTests(unittest.TestCase):
    def test_only_separate_debug_package_may_be_installed(self):
        raw = ('  E: manifest (line=2)\n    A: package="com.pokeaether.androidgpuqa"\n'
               '    E: application (line=22)\n      A: android:debuggable(0x0101000f)=(type 0x12)0xffffffff\n')
        require_debug_manifest(raw)
        for invalid in [raw.replace("androidgpuqa", "game"), raw.replace("0xffffffff", "0x0"), raw.replace("debuggable", "other")]:
            with self.assertRaises(ValueError): require_debug_manifest(invalid)

    def setUp(self):
        self.fixture = {"run_id": "fresh", "rounds": 2, "phase_seconds": 15}
        order = MATRIX + list(reversed(MATRIX)) + ["moves_first", "moves_repeat"]
        self.details = {"run_id": "fresh", "complete": True, "failures": [], "engine_errors": [],
                        "render_size": [2340, 1080], "phases": []}
        for index, variant in enumerate(order):
            metric = {"count": 400, "p50": 20, "p95": 22, "p99": 23, "max": 25}
            self.details["phases"].append({"label": f"0:{index}:{variant}", "variant": variant, "seconds": 15.01,
                "pipeline_start": [1, 2, 3, 4], "pipeline_end": [1, 2, 3, 4],
                "timings": {name: metric.copy() for name in ["engine_frame_ms", "main_gpu_ms", "response_gpu_ms"]},
                "viewports": {name: {"size": [2340, 1080], "msaa": {"msaa_2": 1, "msaa_off": 0}.get(variant, 2)} for name in ["main", "response"]}})

    def test_complete_counterbalanced_workload(self):
        self.assertEqual(validate(self.details, self.fixture), [])
        self.assertEqual(len(comparisons(self.details)), 8)

    def test_stale_partial_and_foreign_artifacts_are_rejected(self):
        for mutation in [lambda x: x.update(run_id="old"), lambda x: x.update(complete=False),
                         lambda x: x["phases"].pop(), lambda x: x["phases"][0].update(label="../../private")]:
            details = copy.deepcopy(self.details)
            mutation(details)
            self.assertTrue(validate(details, self.fixture))

    def test_unavailable_gpu_and_incomplete_sampling(self):
        for value in [0, float("nan"), float("inf")]:
            details = copy.deepcopy(self.details)
            details["phases"][0]["timings"]["main_gpu_ms"]["p50"] = value
            self.assertTrue(validate(details, self.fixture))
        self.details["phases"][0]["timings"]["engine_frame_ms"]["count"] = 1
        self.assertTrue(validate(self.details, self.fixture))

    def test_baseline_must_restore_native_raster_and_msaa(self):
        for key, value in [("msaa", 0), ("size", [1152, 648])]:
            details = copy.deepcopy(self.details)
            details["phases"][2]["viewports"]["main"][key] = value
            self.assertTrue(validate(details, self.fixture))

    def test_pipeline_growth_invalidates_idle_but_is_expected_for_first_moves(self):
        self.details["phases"][-2]["pipeline_end"][3] += 1
        self.assertEqual(validate(self.details, self.fixture), [])
        self.details["phases"][0]["pipeline_end"][3] += 1
        self.assertIn("Idle timing includes pipeline compilation", validate(self.details, self.fixture))

    def test_comparison_uses_two_adjacent_baselines_and_reports_drift(self):
        self.details["phases"][0]["timings"]["main_gpu_ms"]["p50"] = 20
        self.details["phases"][1]["timings"]["main_gpu_ms"]["p50"] = 12
        self.details["phases"][2]["timings"]["main_gpu_ms"]["p50"] = 28
        first = comparisons(self.details)[0]
        self.assertEqual(first["adjacent_baseline_gpu_ms"], 24)
        self.assertEqual(first["gpu_reduction_percent"], 50)
        self.assertAlmostEqual(first["baseline_drift_percent"], 40)


if __name__ == "__main__":
    unittest.main()
