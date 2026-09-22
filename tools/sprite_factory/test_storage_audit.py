import unittest
from summarize_storage_audit import summarize


def texture(key, size):
    return {'sha256': key, 'payload_bytes': size * 2, 'zstd_bytes': size,
            'roles': ['other', 'roughness_texture']}


def row(name, textures):
    return {'species': name, 'source_sha256': name, 'control': False,
            'disk_bytes': 100, 'resaved_compressed_bytes': 100,
            'outer_zstd_bytes': 99, 'file_header': 'RSCC', 'textures': textures,
            'components': [], 'skeleton_serialized_bytes': 1}


class StorageAuditTest(unittest.TestCase):
    def test_duplicate_buckets_are_disjoint(self):
        report = {'catalog_sha256': 'test', 'entries': [
            row('one', [texture('a', 10), texture('a', 10), texture('b', 20)]),
            row('two', [texture('a', 10), texture('c', 30)])]}
        result = summarize(report)
        self.assertEqual(result['texture_within_model_duplicate_zstd_bytes'], 10)
        self.assertEqual(result['texture_between_model_duplicate_zstd_bytes'], 10)
        self.assertEqual(result['texture_global_unique_zstd_bytes'], 60)
        self.assertEqual(result['texture_roles']['roughness_texture']['count'], 5)
        self.assertEqual(result['disk_bytes'], 200)

    def test_shiny_delta_only_counts_new_unique_images(self):
        a, b = row('one', [texture('a', 10)]), row('one', [texture('a', 10), texture('b', 20), texture('b', 20)])
        a.update(control=True, variant='normal')
        b.update(control=True, variant='shiny')
        result = summarize({'catalog_sha256': 'test', 'entries': [a, b]})
        self.assertEqual(result['count'], 0)
        self.assertEqual(result['shiny_pairs'][0]['incremental_unique_texture_zstd_bytes'], 20)


if __name__ == '__main__':
    unittest.main()
