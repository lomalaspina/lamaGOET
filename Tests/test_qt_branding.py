"""The splash screen and the window icon.

The splash is the drawing from the 2024 workshop notes: lamaGOET taking
wavefunctions from the quantum-chemistry programs and feeding them to Tonto.
The icon is the lamaGOET logo; without it the interface shows up as a generic
Python process in the macOS Dock and in the task switcher.
"""

import os
import sys
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO))
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("LAMAGOET_QT_NO_BOOTSTRAP", "true")

try:
    from PySide6.QtGui import QPixmap
    from PySide6.QtWidgets import QApplication
    from lamagoet_qt import main_window
except ImportError:  # pragma: no cover - PySide6 absent
    QApplication = None


@unittest.skipIf(QApplication is None, "PySide6 is not installed")
class BrandingTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])

    def test_both_images_are_present_and_loadable(self):
        for name in (main_window.SPLASH_IMAGE, main_window.LOGO_IMAGE):
            path = REPO / name
            with self.subTest(image=name):
                self.assertTrue(path.is_file(), f"{name} is missing")
                self.assertFalse(
                    QPixmap(str(path)).isNull(), f"{name} will not load"
                )

    def test_the_icon_loads(self):
        icon = main_window._application_icon()
        self.assertFalse(icon.isNull())
        self.assertTrue(icon.availableSizes())

    def test_linux_desktop_identity_matches_the_installed_entry(self):
        desktop = (REPO / "lamagoet.desktop").read_text(encoding="utf-8")
        self.assertEqual(main_window.DESKTOP_FILE_NAME, "lamagoet")
        self.assertIn("Name=lamaGOET\n", desktop)
        self.assertIn("Exec=lamaGOET_qt\n", desktop)
        self.assertIn("Icon=lamagoet\n", desktop)
        self.assertIn("StartupWMClass=lamaGOET\n", desktop)


    def test_the_splash_is_skipped_when_there_is_no_screen(self):
        """Off-screen runs, including this suite, must not try to show it."""
        self.assertIsNone(main_window._show_splash())

    def test_the_splash_can_be_turned_off(self):
        with mock.patch.object(
            QApplication, "platformName", return_value="cocoa"
        ), mock.patch.dict(os.environ, {"LAMAGOET_NO_SPLASH": "true"}, clear=False):
            self.assertIsNone(main_window._show_splash())

    def test_a_missing_image_does_not_stop_startup(self):
        """A missing file must degrade quietly, not raise."""
        with mock.patch.object(
            QApplication, "platformName", return_value="cocoa"
        ), mock.patch.object(main_window, "SPLASH_IMAGE", "no-such-image.png"):
            self.assertIsNone(main_window._show_splash())
        with mock.patch.object(main_window, "LOGO_IMAGE", "no-such-image.png"):
            self.assertTrue(main_window._application_icon().isNull())


if __name__ == "__main__":
    unittest.main()
