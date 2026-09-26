import unittest
from bake_motion_placement import bake


class BakeMotionTests(unittest.TestCase):
    def report(self):
        clip = {"duration": 2 / 60, "minimum_y_samples": [0.0, -0.2, 0.1]}
        return {"review_schema": 1, "errors": [], "entries": {"fixture": {
            "idle_verified": True, "candidate_lift": .1, "sha256": "test",
            "scale": 1, "yaw_degrees": 0,
            "clips": {key: clip for key in ("physical_attack", "special_attack", "damage", "sleep")}}}}

    def test_clearance_envelope_and_explicit_sleep(self):
        clips = bake(self.report(), [])["fixture"]["clips"]
        self.assertNotIn("sleep", clips)
        self.assertEqual(clips["damage"]["offsets"], [.13, .13, .13])
        self.assertEqual(bake(self.report(), ["fixture"])["fixture"]["clips"]["sleep"]["offsets"], [.13] * 3)
        self.assertNotIn("idle", clips)
        self.assertNotIn("faint_start", clips)

    def test_second_physical_attack_receives_clearance(self):
        report = self.report()
        report["entries"]["fixture"]["clips"]["physical_attack_2"] = {
            "duration": 2 / 60, "minimum_y_samples": [0.0, -0.3, 0.0]}
        clips = bake(report, [])["fixture"]["clips"]
        self.assertEqual(clips["physical_attack_2"]["offsets"], [.23, .23, .23])

    def test_mega_appeal_receives_start_pose_clearance(self):
        report = self.report()
        report["entries"]["fixture"]["clips"]["mega_appeal"] = {
            "duration": 2 / 60, "minimum_y_samples": [-1.5, -0.5, 0.1]}
        offsets = bake(report, [])["fixture"]["clips"]["mega_appeal"]["offsets"]
        self.assertEqual(offsets, [1.43, 1.43, .43])

    def test_sleep_rounding_stays_within_calibrated_lift(self):
        report = self.report()
        report["entries"]["fixture"]["candidate_lift"] = .02117747077718
        report["entries"]["fixture"]["clips"]["sleep"] = {
            "duration": 2 / 60, "minimum_y_samples": [.1, .1, .1]}
        offsets = bake(report, ["fixture"])["fixture"]["clips"]["sleep"]["offsets"]
        self.assertTrue(all(value >= -.02117747077718 for value in offsets))

    def test_reject_unverified_or_invalid_measurement(self):
        for mutate in (
            lambda r: r.update(errors=["failed"]),
            lambda r: r["entries"]["fixture"].update(idle_verified=False),
            lambda r: r["entries"]["fixture"]["clips"]["damage"].update(minimum_y_samples=[float("nan")] * 3),
        ):
            report = self.report()
            mutate(report)
            with self.assertRaises(ValueError):
                bake(report, [])
        with self.assertRaises(ValueError):
            bake(self.report(), ["unknown"])

    def test_faint_seam_and_stationary_loop(self):
        report = self.report()
        clips = report["entries"]["fixture"]["clips"]
        clips["faint_start"] = {"duration": 2 / 60, "minimum_y_samples": [.1, -.1, -.2]}
        clips["faint_loop"] = {"duration": 2 / 60, "minimum_y_samples": [-.2, -.25, -.2]}
        baked = bake(report, [])["fixture"]["clips"]
        self.assertEqual(baked["faint_start"]["offsets"][-1], baked["faint_loop"]["offsets"][0])
        self.assertEqual(len(set(baked["faint_loop"]["offsets"])), 1)
        clips["faint_loop"]["minimum_y_samples"][0] = -.3
        with self.assertRaises(ValueError):
            bake(report, [])


if __name__ == "__main__":
    unittest.main()
