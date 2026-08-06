"""Exporting before growing must warn rather than copy the input unchanged.

The Export button writes whatever the structure view is showing.  Opening a
CIF shows its asymmetric unit, so a user who exports straight away gets their
own file back.  For NH3 that is a nitrogen and one hydrogen: not a molecule,
and a meaningless starting geometry for a quantum-chemistry calculation.
"""

import os
import sys
import unittest
from pathlib import Path
from unittest import mock

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("LAMAGOET_QT_NO_BOOTSTRAP", "true")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

try:
    from PySide6.QtWidgets import QApplication, QMessageBox
    from lamagoet_qt.main_window import MainWindow
except ImportError:  # pragma: no cover - PySide6 absent
    QApplication = None

REPO = Path(__file__).resolve().parents[1]
NH3 = REPO / "examples" / "2-NH3" / "nh3_third.cif"


@unittest.skipIf(QApplication is None, "PySide6 is not installed")
@unittest.skipUnless(NH3.is_file(), "the NH3 example is not present")
class ExportGuardTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])

    def _window(self, tmp):
        window = MainWindow(Path(tmp) / "job_options.txt", submission_mode="local")
        window.cif_path.setText(str(NH3))
        window._load_cif_from_field()
        return window

    def test_asymmetric_unit_of_nh3_is_not_a_molecule(self):
        """The premise: opening NH3 shows a third of the molecule."""
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            window = self._window(tmp)
            self.assertEqual(len(window.visible_atoms), 2)
            self.assertEqual(
                window.current_grow_description, window.UNGROWN_DESCRIPTION
            )

    def test_export_without_growing_warns_and_can_be_cancelled(self):
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            window = self._window(tmp)
            with mock.patch.object(
                QMessageBox, "warning", return_value=QMessageBox.StandardButton.Cancel
            ) as warned, mock.patch(
                "lamagoet_qt.main_window.QFileDialog.getSaveFileName"
            ) as save_dialog:
                window.export_grown_cif()

            warned.assert_called_once()
            save_dialog.assert_not_called()

    def test_export_after_growing_does_not_warn(self):
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            window = self._window(tmp)
            for index in range(window.grow_mode.count()):
                if window.grow_mode.itemData(index) == "molecules":
                    window.grow_mode.setCurrentIndex(index)
                    break
            window.apply_grow()

            # A complete ammonia molecule, not a third of one.
            self.assertEqual(len(window.visible_atoms), 4)
            self.assertNotEqual(
                window.current_grow_description, window.UNGROWN_DESCRIPTION
            )

            target = Path(tmp) / "grown.cif"
            with mock.patch.object(QMessageBox, "warning") as warned, mock.patch(
                "lamagoet_qt.main_window.QFileDialog.getSaveFileName",
                return_value=(str(target), ""),
            ), mock.patch.object(
                QMessageBox, "question", return_value=QMessageBox.StandardButton.No
            ):
                window.export_grown_cif()

            warned.assert_not_called()
            self.assertTrue(target.is_file())


if __name__ == "__main__":
    unittest.main()
