import unittest
from prepare_forest_review import selected


class SelectionTests(unittest.TestCase):
    def test_required_art_and_native_terrain(self):
        for path in ['scenes/levels/forest.tscn', 'scenes/objects/tree.tscn',
                     'assets/glb/tree/tree.glb', 'resources/terrabrush/Heightmap_0_0.res',
                     'addons/terrabrush/bin/libterrabrush.linux.debug.x86_64.so', 'LICENSE']:
            self.assertTrue(selected(path), path)

    def test_excluded_content(self):
        for path in ['assets/wav/music.wav', 'scenes/levels/forest.gd',
                     'assets/glb/easter_egg/easter_egg.glb', 'assets/blend/tree/tree.blend',
                     'addons/jonnies_first_person/player.tscn', 'project.godot',
                     'assets/glb/tree/tree.glb.import', 'resources/meshes/grass.res.depren',
                     'addons/terrabrush/bin/libterrabrush.windows.debug.x86_64.dll']:
            self.assertFalse(selected(path), path)


if __name__ == '__main__':
    unittest.main()
