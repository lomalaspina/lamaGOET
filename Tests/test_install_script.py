#!/usr/bin/env python3
"""Regression checks for the Debian/Ubuntu/WSL installer."""

from pathlib import Path
import subprocess
import unittest


REPO = Path(__file__).resolve().parents[1]


class InstallScriptTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.script = (REPO / "install.sh").read_text(encoding="utf-8")
        cls.desktop = (REPO / "lamagoet.desktop").read_text(encoding="utf-8")
        cls.documentation = (REPO / "docs" / "INSTALL.md").read_text(
            encoding="utf-8"
        )

    def test_installer_has_valid_bash_syntax(self):
        subprocess.run(["bash", "-n", str(REPO / "install.sh")], check=True)

    def test_installer_fails_fast_and_refreshes_packages(self):
        self.assertIn("set -Eeuo pipefail", self.script)
        self.assertIn("run_admin apt-get update", self.script)
        self.assertIn("DEBIAN_FRONTEND=noninteractive apt-get install -y", self.script)

    def test_installer_covers_qt_display_and_shell_dependencies(self):
        for package in (
            "bc",
            "gawk",
            "python3-venv",
            "libegl1",
            "libgl1",
            "libwayland-client0",
            "libxcb-cursor0",
            "libxcb-xkb1",
            "libxkbcommon-x11-0",
            "zenity",
        ):
            with self.subTest(package=package):
                self.assertIn(package, self.script)

    def test_installer_preserves_normal_user_ownership(self):
        self.assertIn('SUDO_USER', self.script)
        self.assertIn('run_user python3 "$localdir/GUI_lamaGOET_qt.py"', self.script)
        self.assertNotIn("sudo ./install.sh", self.documentation)

    def test_installer_verifies_qt_and_installs_desktop_identity(self):
        self.assertIn("--check-install", self.script)
        self.assertIn("/usr/local/share/pixmaps/lamagoet.png", self.script)
        self.assertIn("/usr/share/icons/hicolor/128x128/apps/lamagoet.png", self.script)
        self.assertIn("/usr/local/share/applications/lamagoet.desktop", self.script)
        self.assertIn("Exec=lamaGOET_qt\n", self.desktop)
        self.assertIn("Icon=lamagoet\n", self.desktop)
        self.assertIn("StartupWMClass=lamaGOET\n", self.desktop)


if __name__ == "__main__":
    unittest.main()
