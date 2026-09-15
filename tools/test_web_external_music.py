import struct
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import build_web_preview as builder


class ExternalMusicPackTests(unittest.TestCase):
    def make_pack(self, root, names, version=3):
        header = bytearray(112 if version == 3 else 96)
        struct.pack_into('<II', header, 0, 0x43504447, version)
        if version == 3:
            struct.pack_into('<Q', header, 32, len(header))
        directory = struct.pack('<I', len(names))
        for name in names:
            encoded = name.encode() + b'\0'
            directory += struct.pack('<I', len(encoded)) + encoded + bytes(36)
        path = root / 'test.pck'
        path.write_bytes(header + directory)
        return path

    def test_directory_versions_and_effects_allowed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            names = ['assets/audio/sfx/item.wav', '.godot/imported/cry.ogg-123.oggvorbisstr']
            for version in (2, 3):
                pack = self.make_pack(root, names, version)
                self.assertEqual(builder.pack_entry_names(pack), names)
                with patch.object(builder, 'ROOT', root):
                    builder.validate_external_music_pack(pack)

    def test_raw_and_imported_music_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            music = root / 'assets/music'
            music.mkdir(parents=True)
            imported = '.godot/imported/theme.ogg-abc.oggvorbisstr'
            (music / 'theme.ogg.import').write_text('path="res://' + imported + '"')
            for name in ('assets/music/theme.ogg', imported):
                with patch.object(builder, 'ROOT', root):
                    with self.assertRaisesRegex(RuntimeError, 'embeds background music'):
                        builder.validate_external_music_pack(self.make_pack(root, [name]))


if __name__ == '__main__':
    unittest.main()
