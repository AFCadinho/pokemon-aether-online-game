from pathlib import PurePosixPath, PureWindowsPath
import unittest

from run_native_compression_install_check import source_relative_path


class NativeFixturePathChecks(unittest.TestCase):
    def test_windows_pin_path_selects_generated_fixture_metadata(self):
        root = PureWindowsPath('D:/a/game/launcher')
        pin = root / 'data/approved_3d_release_v10.json'
        self.assertEqual(source_relative_path(pin, root), 'data/approved_3d_release_v10.json')

    def test_git_path_and_linux_file_path_have_the_same_spelling(self):
        git_path = PurePosixPath('launcher/scripts/launcher.gd')
        file_path = PurePosixPath('/home/runner/game/launcher/scripts/launcher.gd')
        self.assertEqual(source_relative_path(git_path, PurePosixPath('launcher')),
                         source_relative_path(file_path, PurePosixPath('/home/runner/game/launcher')))


if __name__ == '__main__':
    unittest.main()
