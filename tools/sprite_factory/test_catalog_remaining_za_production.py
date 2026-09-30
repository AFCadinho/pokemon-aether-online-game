import unittest

from catalog_remaining_za_production import validate_identity


class IdentityTest(unittest.TestCase):
    def row(self):
        # Developer IDs diverge from national dex IDs in later generations.
        return {'species': 'clobbopus', 'legacy_source': {'member': 'Gen8/pm0964.blend'},
                'resource_id': 'pm0964', 'za_identity': 'pm0964_00_00'}

    def test_developer_mapping_is_used(self):
        validate_identity(self.row())
        row = self.row()
        row.update(resource_id='pm0852', za_identity='pm0852_00_00')
        with self.assertRaisesRegex(ValueError, 'developer number'):
            validate_identity(row)

    def test_alternate_form_is_not_silently_selected(self):
        row = self.row()
        row['za_identity'] = 'pm0964_01_00'
        with self.assertRaisesRegex(ValueError, 'default ZA form'):
            validate_identity(row)

    def test_species_cannot_escape_output_directory(self):
        row = self.row()
        row['species'] = '../other'
        with self.assertRaisesRegex(ValueError, 'directory identity'):
            validate_identity(row)


if __name__ == '__main__':
    unittest.main()
