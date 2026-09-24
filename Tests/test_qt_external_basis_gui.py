#!/usr/bin/env python3
"""Qt option-state regressions for program-specific external basis files."""

from __future__ import annotations

import os
from pathlib import Path
import tempfile
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

try:
    from PySide6.QtWidgets import QApplication
except ImportError:  # pragma: no cover - optional GUI dependency
    QApplication = None

from lamagoet_qt.job_options import save_job_options
from lamagoet_qt.main_window import MainWindow


@unittest.skipIf(QApplication is None, "PySide6 is not installed")
class ExternalBasisGuiTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])

    def _window(self, program: str, old_basis: str, filename: str):
        temporary = tempfile.TemporaryDirectory()
        directory = Path(temporary.name)
        (directory / filename).write_text("external basis fixture\n", encoding="utf-8")
        options = directory / "job_options.txt"
        values = {
            "SCFCALCPROG": program,
            "GAUSGEN": "true",
            "BASISSETG": old_basis,
            "BASISSETT": old_basis,
        }
        save_job_options(options, values)
        window = MainWindow(options)
        self.addCleanup(window.close)
        self.addCleanup(temporary.cleanup)
        return window

    def test_occ_old_gen_options_reload_as_json_without_legacy_prompt(self):
        window = self._window("OCC", "gen", "basis_gen.json")
        self.assertTrue(window.basis_definition_path.text().endswith("basis_gen.json"))
        self.assertEqual(window.basis.currentText(), "./basis_gen.json")
        self.assertEqual(window._current_values()["BASISSETG"], "./basis_gen.json")
        self.assertFalse(window.bse_button.isHidden())

    def test_orca_external_options_reload_as_native_staged_file(self):
        window = self._window("Orca", "gen", "basis_gen.txt")
        self.assertTrue(window.basis_definition_path.text().endswith("basis_gen.txt"))
        self.assertEqual(window.basis.currentText(), "External")
        self.assertEqual(window._current_values()["BASISSETG"], "External")

    def test_tonto_external_options_reload_native_library_and_directory(self):
        window = self._window("Tonto", "STO-3G", "basis_gen")
        self.assertTrue(window.basis_definition_path.text().endswith("basis_gen"))
        self.assertEqual(window.basis.currentText(), "basis_gen")
        values = window._current_values()
        self.assertEqual(values["BASISSETT"], "basis_gen")
        self.assertEqual(values["BASISSETDIR"], ".")

    def test_elmodb_does_not_offer_unsupported_bse_export(self):
        with tempfile.TemporaryDirectory() as directory:
            window = MainWindow(Path(directory) / "job_options.txt")
            self.addCleanup(window.close)
            window.program.setCurrentIndex(window.program.findData("elmodb"))
            self.assertTrue(window.bse_button.isHidden())


if __name__ == "__main__":
    unittest.main()
