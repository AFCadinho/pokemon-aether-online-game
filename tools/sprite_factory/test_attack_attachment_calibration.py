import math
import unittest

from calibrate_attack_attachment import bone_local, dot, ray, triangulate
from fit_attack_attachment import fit, solve


IDENTITY = [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]


class CalibrationTests(unittest.TestCase):
    def assertVector(self, actual, expected, tolerance=1e-5):
        for a, b in zip(actual, expected):
            self.assertAlmostEqual(a, b, delta=tolerance)

    def test_triangulation_and_parallel_rejection(self):
        point, residual = triangulate(([0, 0, 4], [0, 0, -1]), ([4, 0, 0], [-1, 0, 0]))
        self.assertVector(point, [0, 0, 0])
        self.assertAlmostEqual(residual, 0)
        with self.assertRaises(ValueError):
            triangulate(([0, 0, 4], [0, 0, -1]), ([4, 0, 0], [0, 0, -1]))
        with self.assertRaises(ValueError):
            triangulate(([0, 0, 4], [0, 0, 1]), ([4, 0, 0], [1, 0, 0]))

    def test_affine_inverse_rotation_scale_and_translation(self):
        transform = [0, 2, 0, -3, 0, 0, 0, 0, 4, 2, 3, 4]
        self.assertVector(bone_local(transform, [-4, 5, 16]), [1, 2, 3])

    def test_center_ray(self):
        capture = {'camera': IDENTITY[:9]+[0, 0, 4], 'fov': 35}
        origin, direction = ray(capture, [210, 180], 420, 360)
        self.assertVector(origin, [0, 0, 4])
        self.assertVector(direction, [0, 0, -1])

    def test_pivoted_system(self):
        self.assertVector(solve([[0, 2], [3, 4]], [4, 11]), [1, 2])

    def test_weighted_fit_tracks_independent_bone_poses(self):
        group = [{'bone': 'head', 'offset': [0, 0, 0], 'weight': 1},
                 {'bone': 'jaw', 'offset': [0, 0, 0], 'weight': 3}]
        expected = [0.3, 0.1, 0.2, 0.2, -0.1, 0.15]
        observations = []
        transforms = []
        for angle in [0, 0.6, 1.2]:
            c, s = math.cos(angle), math.sin(angle)
            jaw = [c, s, 0, -s, c, 0, 0, 0, 1, 0, -0.2, 0]
            bones = {'head': IDENTITY, 'jaw': jaw}
            point = [sum(weight*(transform[9+axis]+sum(transform[column*3+axis]*offset[column] for column in range(3)))
                         for weight, transform, offset in [(0.25, IDENTITY, expected[:3]), (0.75, jaw, expected[3:])])
                     for axis in range(3)]
            transforms.append((bones, point))
            for camera in [IDENTITY[:9]+[0, 0, 4], [0, 0, -1, 0, 1, 0, 1, 0, 0, 4, 0, 0]]:
                local = bone_local(camera, point)
                scale = math.tan(math.radians(35)/2)
                pixel = [(local[0]/(-local[2]*scale)*(360/420)+1)*210,
                         (1-local[1]/(-local[2]*scale))*180]
                observations.append(({'camera': camera, 'fov': 35, 'bones': bones}, pixel, 420, 360))
        fitted, residuals = fit(group, observations)
        self.assertLess(max(residuals), 1e-4)
        for bones, point in transforms:
            actual = [sum(weight*(bones[name][9+axis]+sum(bones[name][column*3+axis]*offset[column] for column in range(3)))
                          for weight, name, offset in [(0.25, 'head', fitted[:3]), (0.75, 'jaw', fitted[3:])])
                      for axis in range(3)]
            self.assertVector(actual, point, 1e-4)


if __name__ == '__main__':
    unittest.main()
