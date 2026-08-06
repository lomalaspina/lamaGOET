"""The file dialogs must reach /usr/local/bin and /opt on macOS.

Quantum-chemistry executables and basis-set directories live in places the
native macOS panel hides, so the Settings tab's Browse buttons appeared to
offer no way to select a Tonto binary.  These tests lock in the fix.
"""

import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

try:
    from PySide6.QtWidgets import QFileDialog
except ImportError:  # pragma: no cover - PySide6 absent
    QFileDialog = None


@unittest.skipIf(QFileDialog is None, "PySide6 is not installed")
class FileDialogOptionTest(unittest.TestCase):
    def _options(self, system):
        from lamagoet_qt import main_window

        with mock.patch.object(main_window.platform, "system", return_value=system):
            return main_window._dialog_options()

    def test_macos_asks_for_the_qt_dialog(self):
        self.assertEqual(
            self._options("Darwin"), QFileDialog.Option.DontUseNativeDialog
        )

    def test_linux_and_windows_keep_the_native_dialog(self):
        for system in ("Linux", "Windows"):
            with self.subTest(system=system):
                self.assertEqual(self._options(system), QFileDialog.Option(0))

    def test_every_file_dialog_passes_the_options(self):
        """A new dialog added without options= would silently regress macOS."""
        source = (
            Path(__file__).resolve().parents[1] / "lamagoet_qt" / "main_window.py"
        ).read_text(encoding="utf-8")

        calls = 0
        for name in ("getOpenFileName", "getSaveFileName", "getExistingDirectory"):
            start = 0
            while True:
                index = source.find(f"QFileDialog.{name}(", start)
                if index == -1:
                    break
                depth = 0
                open_paren = source.index("(", index)
                for position in range(open_paren, len(source)):
                    if source[position] == "(":
                        depth += 1
                    elif source[position] == ")":
                        depth -= 1
                        if depth == 0:
                            break
                call = source[index:position + 1]
                self.assertIn(
                    "options=_dialog_options()",
                    call,
                    f"QFileDialog.{name} at offset {index} does not pass "
                    "options=_dialog_options(); macOS users will not be able "
                    "to browse to /usr/local/bin.",
                )
                calls += 1
                start = position + 1

        self.assertGreaterEqual(calls, 10, "expected to find every dialog call")


if __name__ == "__main__":
    unittest.main()
