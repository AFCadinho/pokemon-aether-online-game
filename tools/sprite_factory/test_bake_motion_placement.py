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


if __name__ == "__main__":
    unittest.main()
