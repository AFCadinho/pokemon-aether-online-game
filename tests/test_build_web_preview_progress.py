from contextlib import redirect_stdout
import io
from pathlib import Path
import sys
import tempfile
import unittest

from tools.build_web_preview import (
    MAX_EXCEPTION_BYTES,
    MAX_INITIAL_BYTES,
    copy_web_shell_assets,
    initial_size_limit,
    parse_export_progress,
    run_export,
)


class BuildWebPreviewProgressTests(unittest.TestCase):
    def test_normal_initial_size_limit_remains_312_mib(self):
        self.assertEqual(initial_size_limit(allow_exception=False, reason=None), (MAX_INITIAL_BYTES, None))
        self.assertEqual(MAX_INITIAL_BYTES, 312 * 1024 * 1024)

    def test_size_exception_is_opt_in_bounded_and_auditable(self):
        reason = 'Requested one-release browser exception for v0.3.87.'
        self.assertEqual(
            initial_size_limit(allow_exception=True, reason=reason),
            (MAX_EXCEPTION_BYTES, reason),
        )
        self.assertEqual(MAX_EXCEPTION_BYTES, 328 * 1024 * 1024)

    def test_size_exception_requires_reason(self):
        for reason in (None, '', 'too big'):
            with self.subTest(reason=reason), self.assertRaises(ValueError):
                initial_size_limit(allow_exception=True, reason=reason)

    def test_reason_without_exception_is_rejected(self):
        with self.assertRaises(ValueError):
            initial_size_limit(allow_exception=False, reason='one-off release')

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

    def test_shell_logo_is_copied_into_web_build(self):
        with tempfile.TemporaryDirectory() as directory:
            copied = copy_web_shell_assets(Path(directory))
            self.assertEqual(
                [path.name for path in copied],
                ['pokeaether-logo.webp', 'pokeaether-world-preview.webp'],
            )
            self.assertTrue(all(path.stat().st_size > 0 for path in copied))


if __name__ == '__main__':
    unittest.main()
