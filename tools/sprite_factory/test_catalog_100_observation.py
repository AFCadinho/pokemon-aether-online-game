"""Keep the large observation cohort explicit and reproducible."""
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent


class Catalog100ObservationTest(unittest.TestCase):
    def test_batch_is_a_unique_observation_cohort(self) -> None:
        batch = json.loads((ROOT / "catalog_100_observation_batch.json").read_text())
        entries = batch["entries"]
        self.assertEqual(100, len(entries))
        self.assertEqual(100, len({entry["species"] for entry in entries}))
        self.assertEqual(100, len({entry["pm"] for entry in entries}))
        self.assertTrue(all(isinstance(entry["pm"], int) and entry["pm"] > 0 for entry in entries))
        self.assertIn("observation", batch["purpose"])
        self.assertIn("no automatic approval", batch["purpose"])
        self.assertFalse(batch.get("runtime_approved", False))


if __name__ == "__main__":
    unittest.main()
