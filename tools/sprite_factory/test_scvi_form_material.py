import unittest

from scvi_form_material import sample


class PaletteSamplingTests(unittest.TestCase):
    def test_sparse_channel_retains_colour_between_form_keys(self):
        # The native green channel of cloak layer 3 has only samples 0 and 3.
        self.assertEqual(sample([(0, 1.0), (3, .25)], 1), 1.0)
        self.assertEqual(sample([(0, 1.0), (3, .25)], 2), 1.0)

    def test_exact_key_selects_form_instead_of_default_green(self):
        self.assertEqual(sample([(0, .04), (1, 0), (2, .745), (3, .117)], 2), .745)

    def test_rejects_missing_and_invalid_keys(self):
        for keys, index in [([], 1), ([(0, 1), (0, 2)], 0),
                            ([(0, 1), (3, float('nan'))], 1),
                            ([(0, 1), (3, 2)], 4)]:
            with self.assertRaises(ValueError):
                sample(keys, index)


if __name__ == '__main__':
    unittest.main()
