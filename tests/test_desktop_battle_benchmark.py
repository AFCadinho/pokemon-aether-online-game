import copy
import unittest

from tests import test_android_quality_benchmark as android_fixtures
from tools.run_desktop_battle_benchmark import validate


class DesktopBenchmarkTests(unittest.TestCase):
    def result(self, enabled=True):
        source = android_fixtures.AndroidQualityResultTests()
        source.setUp()
        fixture, details = source.entry_result(enabled)
        fixture.update(mode="entry", expected_adapter="NVIDIA GeForce RTX 3070 Laptop GPU", warmup=enabled, order=["medium"] * 3, seconds=30)
        details.update(renderer="forward_plus", adapter="NVIDIA GeForce RTX 3070 Laptop GPU")
        for row in details["phases"]:
            row.update(seconds=30.01, render_size=[1440,810], response_size=[1440,810])
            row["entry"]["arena_native_size"] = [1920,1080]
            for metric in row["timings"].values(): metric["p99"] = metric["p95"]
            for move in row["gameplay"]["moves"]:
                move["render_visible_frames"] = 20
                for metric in move["timings"].values(): metric["p99"] = metric["p95"]
        return fixture, details

    def test_entry_on_and_off_keep_actual_request_and_cast_ownership(self):
        for enabled in (False, True):
            fixture, details = self.result(enabled)
            self.assertEqual(validate(details, fixture), [])

    def test_wrong_renderer_gpu_pass_request_or_prepared_identity_is_rejected(self):
        for change in (lambda d: d.update(renderer="gl_compatibility"),
                       lambda d: d.update(adapter="llvmpipe"),
                       lambda d: d["phases"][0].update(response_size=[1280,720]),
                       lambda d: d["phases"][0]["entry"].update(selected_slot=1, case="preview_trainer"),
                       lambda d: d["phases"][0]["entry"].update(available_keys=[]),
                       lambda d: d["phases"][0]["gameplay"]["moves"][0].update(prepared_instance=123),
                       lambda d: d["phases"][0]["timings"]["frame_ms"].update(p99=float("nan"))):
            fixture, details = self.result()
            change(details)
            self.assertTrue(validate(details, fixture))

    def test_all_relative_desktop_profiles_and_reconstructed_battles(self):
        fixture, details = self.result(False)
        fixture.update(mode="profiles", order=["low", "medium", "high", "ultra"])
        template = copy.deepcopy(details["phases"][0])
        details["phases"] = []
        for i, preset in enumerate(fixture["order"]):
            row = copy.deepcopy(template)
            size = {"low": [960,540], "medium": [1440,810], "high": [1920,1080], "ultra": [1920,1080]}[preset]
            row.update(index=i, preset=preset, msaa={"low": 0, "medium": 1, "high": 1, "ultra": 2}[preset], render_size=size, response_size=size, stage_instance=100+i)
            details["phases"].append(row)
        self.assertEqual(validate(details, fixture), [])

    def test_soak_must_finish_twenty_windows_on_one_battle(self):
        fixture, details = self.result(False)
        fixture.update(mode="soak", order=["medium"] * 20)
        template = details["phases"][0]
        details["phases"] = [dict(copy.deepcopy(template), index=i, stage_instance=100) for i in range(20)]
        self.assertEqual(validate(details, fixture), [])
        details["phases"][12]["stage_instance"] = 200
        self.assertTrue(validate(details, fixture))
        details["phases"].pop()
        self.assertTrue(validate(details, fixture))


if __name__ == "__main__":
    unittest.main()
