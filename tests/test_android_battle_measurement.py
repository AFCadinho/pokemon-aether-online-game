import unittest

from tools.measure_android_battle import FrameSeries, PENDING, presentations, surface_name


class AndroidBattleMeasurementTests(unittest.TestCase):
    def test_uses_actual_present_time_and_rejects_unsignaled_fences(self):
        period, stamps = presentations(f"8333333\n10 20 30\n11 {PENDING} 31\n0 0 0\n12 20 32\n")
        self.assertEqual(period, 8333333)
        self.assertEqual(stamps, [20])

    def test_samsung_wrapper_selects_game_blast_surface(self):
        raw = "\n".join([
            "RequestedLayerState{Background for abc SurfaceView[com.pokeaether.game/Launcher]@0#2 parentId=1}",
            "RequestedLayerState{abc SurfaceView[com.pokeaether.game/Launcher]@0#1 parentId=0}",
            "RequestedLayerState{abc SurfaceView[com.pokeaether.game/Launcher]@0(BLAST)#3 parentId=1}",
            "Other app SurfaceView[other.game/Launcher]@0(BLAST)#4",
        ])
        self.assertEqual(surface_name(raw), "abc SurfaceView[com.pokeaether.game/Launcher]@0(BLAST)#3")
        with self.assertRaises(ValueError):
            surface_name(raw + "\nsecond SurfaceView[com.pokeaether.game/Other]@0(BLAST)#5")

    def test_overlapping_history_does_not_duplicate_frames(self):
        series = FrameSeries(10_000_000)
        series.add([0, 10_000_000, 20_000_000, 30_000_000])
        series.add([10_000_000, 20_000_000, 30_000_000, 80_000_000])
        series.add([10_000_000, 20_000_000, 30_000_000, 80_000_000])
        self.assertEqual(series.intervals_ns, [10_000_000, 10_000_000, 50_000_000])
        self.assertEqual(series.coverage_gaps, 0)
        self.assertAlmostEqual(series.summary()["observed_fps"], 3000 / 70)
        self.assertEqual(series.summary()["p95_ms"], 50)

    def test_lost_history_does_not_fabricate_a_stutter(self):
        series = FrameSeries(10_000_000)
        series.add([500_000_000, 510_000_000])
        self.assertEqual(series.coverage_gaps, 1)
        self.assertEqual(series.intervals_ns, [10_000_000])
        series.add([])
        self.assertEqual(series.empty_polls, 1)

    def test_slow_tail_and_display_rounding(self):
        series = FrameSeries(1)
        series.intervals_ns = [16_700_000] * 95 + [50_000_000] * 4 + [150_000_000]
        summary = series.summary()
        self.assertEqual(summary["p95_ms"], 16.7)
        self.assertEqual(summary["p99_ms"], 50)
        self.assertEqual(summary["max_ms"], 150)
        self.assertEqual(summary["over_16_667_ms"], 5)
        self.assertEqual(summary["over_100_ms"], 1)


if __name__ == "__main__":
    unittest.main()
