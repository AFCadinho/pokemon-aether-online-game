from contextlib import redirect_stdout
import io
from pathlib import Path
import sys
import tempfile
import unittest

from tools.build_web_preview import parse_export_progress, run_export


class BuildWebPreviewProgressTests(unittest.TestCase):
    def test_plain_progress_line(self):
        self.assertEqual(parse_export_progress('[  42% ] savepack | Storing File'), (42, 'savepack'))

    def test_ansi_progress_line(self):
        line = '\x1b[92m[ DONE ]\x1b[39m old phase\n\x1b[90m[  97% ]\x1b[1msavepack\x1b[22m | File'
        self.assertIsNone(parse_export_progress(line))
        self.assertEqual(
            parse_export_progress('\x1b[90m[  97% ]\x1b[1msavepack\x1b[22m | File'),
            (97, 'savepack'),
        )

    def test_non_progress_output_is_ignored(self):
        self.assertIsNone(parse_export_progress('Godot Engine v4.6.2'))

    def test_export_relays_progress(self):
        output = io.StringIO()
        with tempfile.TemporaryDirectory() as directory, redirect_stdout(output):
            returncode = run_export(
                [sys.executable, '-c', "print('[  12% ] export | Working', flush=True)"],
                Path(directory) / 'export.log',
            )
        self.assertEqual(returncode, 0)
        self.assertIn('Godot export: 12% (export)', output.getvalue())


if __name__ == '__main__':
    unittest.main()
