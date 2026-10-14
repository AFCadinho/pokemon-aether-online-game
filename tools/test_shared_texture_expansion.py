"""Guard sharing boundaries: exact consumers and no double-counted Minior saving."""
import unittest

from study_shared_texture_expansion import consumer_groups


def asset(*paths):
    return {'pair_manifest': {'files': [{'path': p, 'bytes': 100} for p in paths]}}


def group(state, *consumers):
    return {'state_signature': state, 'references': [
        {'asset_id': key, 'path': path, 'bytes': 100} for key, path in consumers]}


class ConsumerBoundaries(unittest.TestCase):
    def test_pool_does_not_add_textures_for_different_consumers(self):
        assets = {'a': asset('x', 'y'), 'b': asset('x'), 'c': asset('y')}
        result = consumer_groups([group('one', ('a', 'x'), ('b', 'x')),
                                  group('two', ('a', 'y'), ('c', 'y'))], assets)
        self.assertEqual(set(result), {('a', 'b'), ('a', 'c')})
        self.assertEqual([g['state_signature'] for g in result[('a', 'b')]], ['one'])

    def test_already_pooled_members_are_not_counted_again(self):
        assets = {'a': asset(), 'b': asset('x')}
        self.assertEqual(consumer_groups([group('one', ('a', 'x'), ('b', 'x'))], assets), {})

    def test_internal_duplicate_alone_is_not_cross_model_sharing(self):
        self.assertEqual(consumer_groups([group('one', ('a', 'x'), ('a', 'y'))],
                                        {'a': asset('x', 'y')}), {})

    def test_size_drift_is_rejected(self):
        changed = group('one', ('a', 'x'), ('b', 'x'))
        changed['references'][0]['bytes'] = 101
        with self.assertRaisesRegex(ValueError, 'Changed texture size'):
            consumer_groups([changed], {'a': asset('x'), 'b': asset('x')})


if __name__ == '__main__':
    unittest.main()
