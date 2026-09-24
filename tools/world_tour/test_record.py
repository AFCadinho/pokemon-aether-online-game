import copy
import json
from pathlib import Path
import unittest

from record import validate
from catalog import coverage, check_coverage


class RouteValidationTests(unittest.TestCase):
    def setUp(self):
        self.route = json.loads(Path(__file__).with_name("route.json").read_text())

    def test_default_route(self):
        validate(self.route)
        self.assertEqual(self.route["shot_seconds"], 4)
        self.assertEqual(self.route["transition_seconds"], 1)
        self.assertEqual(len(self.route["shots"]), 17)

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

    def test_every_outdoor_catalog_map_is_represented(self):
        groups, unbuilt = coverage()
        self.assertEqual(set(groups) - set(self.route.get("excluded_visuals", {})) | set(self.route.get("additional_visuals", {})), {s["scene"] for s in self.route["shots"]})
        self.assertEqual(unbuilt, self.route["unbuilt_areas"])
        for scene, area_ids in groups.items():
            if scene in self.route.get("excluded_visuals", {}):
                continue
            recorded = set().union(*(set(s["areas"]) for s in self.route["shots"] if s["scene"] == scene))
            self.assertEqual(recorded, set(area_ids))

    def test_removed_map_is_reported(self):
        self.route["shots"] = self.route["shots"][1:]
        with self.assertRaisesRegex(ValueError, "missing map visuals"):
            check_coverage(self.route)

    def test_rejects_interiors_in_outdoor_tour(self):
        extra = self.route["shots"][0].copy()
        extra["scene"] = "res://generated/tiled_visuals/pokemon_center/pokemon_center.visual.tscn"
        self.route["shots"].append(extra)
        with self.assertRaisesRegex(ValueError, "non-outdoor"):
            check_coverage(self.route)

    def test_caves_and_buildings_are_excluded(self):
        groups, _ = coverage()
        ids = set().union(*map(set, groups.values()))
        self.assertIn("kanto_viridian_forest", ids)
        self.assertIn("kanto_route_9", ids)
        self.assertNotIn("kanto_mt_moon_1f", ids)
        self.assertIn("res://generated/tiled_visuals/mt_moon_1f/mt_moon_1f.visual.tscn", self.route["additional_visuals"])
        self.assertIn("kanto_mt_moon_1f", set().union(*(set(s["areas"]) for s in self.route["shots"])))
        self.assertNotIn("kanto_cerulean_cave", ids)
        self.assertNotIn("kanto_players_house", ids)

    def test_open_field_is_intentionally_omitted(self):
        scene = "res://generated/tiled_visuals/open_field/open_field.visual.tscn"
        self.assertIn(scene, self.route["excluded_visuals"])
        self.assertNotIn(scene, {s["scene"] for s in self.route["shots"]})
        self.route["excluded_visuals"].clear()
        with self.assertRaisesRegex(ValueError, "missing map visuals"):
            check_coverage(self.route)

    def test_excluded_visual_cannot_accidentally_return(self):
        extra = self.route["shots"][0].copy()
        extra["scene"] = next(iter(self.route["excluded_visuals"]))
        self.route["shots"].append(extra)
        with self.assertRaisesRegex(ValueError, "still present"):
            check_coverage(self.route)


if __name__ == "__main__":
    unittest.main()
