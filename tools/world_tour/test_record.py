import copy
import json
from pathlib import Path
import unittest

from record import validate


class RouteValidationTests(unittest.TestCase):
    def setUp(self):
        self.route = json.loads(Path(__file__).with_name("route.json").read_text())

    def test_default_route(self):
        validate(self.route)

    def test_rejects_bad_timing_and_encoding_sizes(self):
        for key, value in (("fps", 0), ("width", 1279), ("height", -2),
                           ("shot_seconds", 8.01), ("transition_seconds", 8),
                           ("transition_seconds", float("nan"))):
            with self.subTest(key=key, value=value):
                route = copy.deepcopy(self.route)
                route[key] = value
                with self.assertRaises(ValueError):
                    validate(route)

    def test_rejects_gameplay_scenes_and_missing_visuals(self):
        for scene in ("res://scenes/interface/login_screen.tscn",
                      "res://generated/tiled_visuals/missing.visual.tscn",
                      "res://generated/tiled_visuals/../../../missing.visual.tscn"):
            with self.subTest(scene=scene):
                self.route["shots"][0]["scene"] = scene
                with self.assertRaises(ValueError):
                    validate(self.route)

    def test_rejects_invalid_camera_coordinates(self):
        for point in ([0], [float("inf"), 0], ["0", 2]):
            self.route["shots"][0]["from"] = point
            with self.assertRaises(ValueError):
                validate(self.route)

    def test_requires_multiple_shots(self):
        self.route["shots"] = self.route["shots"][:1]
        with self.assertRaises(ValueError):
            validate(self.route)


if __name__ == "__main__":
    unittest.main()
