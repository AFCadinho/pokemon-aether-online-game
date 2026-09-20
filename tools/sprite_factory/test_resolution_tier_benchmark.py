import unittest

from PIL import Image, ImageDraw

from resolution_tier_benchmark import (
    _pack, _restore, _sample_indices, _scaled_rect, render_context, visible_psnr,
)


class ResolutionTierBenchmarkTests(unittest.TestCase):
    def test_scaled_rect_keeps_padding_inside_target(self):
        self.assertEqual(_scaled_rect([0, 0, 512, 512]), (0, 0, 384, 384))
        self.assertEqual(_scaled_rect([100, 120, 200, 240]), (72, 87, 228, 273))

    def test_pack_restore_preserves_resized_pixels(self):
        frames = []
        for offset in range(3):
            frame = Image.new("RGBA", (384, 384))
            ImageDraw.Draw(frame).ellipse((80 + offset, 60, 260, 330), fill=(220, 80, 20, 190))
            frames.append(frame)
        rect = (70, 50, 270, 340)
        restored = _restore(_pack(frames, 2, rect), 3, 2, rect)
        self.assertEqual([frame.tobytes() for frame in frames], [frame.tobytes() for frame in restored])

    def test_context_render_and_metric_are_deterministic(self):
        frame = Image.new("RGBA", (512, 512))
        ImageDraw.Draw(frame).rectangle((150, 100, 360, 410), fill=(80, 160, 240, 220))
        shown = render_context(frame, [150, 100, 211, 311], 2.5, "summary_zoom")
        psnr, maximum = visible_psnr(shown, shown.copy())
        self.assertEqual(psnr, 99.0)
        self.assertEqual(maximum, 0)

    def test_samples_include_endpoints(self):
        self.assertEqual(_sample_indices(3), {0, 1, 2})
        self.assertEqual(min(_sample_indices(20)), 0)
        self.assertEqual(max(_sample_indices(20)), 19)


if __name__ == "__main__":
    unittest.main()
