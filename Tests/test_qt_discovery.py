"""Finding Tonto without making the user type paths.

Tonto's README never mentions `make install`, so it is normally run straight
from its build tree with the basis sets one directory above the binary.  If it
is installed, CMake puts the binary in bin/ and the basis sets in
share/tonto/.  lamaGOET's old default pointed at /usr/local/bin/basis_sets,
which neither layout produces.
"""

import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO))

from lamagoet_qt import discovery


def make_executable(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("#!/bin/sh\n")
    path.chmod(0o755)
    return path


def make_basis_sets(directory):
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "STO-3G").write_text("basis\n")
    # Resolved, because find_basis_sets resolves the binary path before
    # deriving candidates and macOS symlinks /var to /private/var.
    return directory.resolve()


class BasisSetDiscoveryTest(unittest.TestCase):
    def test_build_tree_layout(self):
        """~/tonto/release/tonto with ~/tonto/basis_sets one level up."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "tonto"
            binary = make_executable(root / "release" / "tonto")
            basis = make_basis_sets(root / "basis_sets")
            self.assertEqual(discovery.find_basis_sets(binary), basis)

    def test_installed_layout(self):
        """CMake's install: bin/tonto and share/tonto/basis_sets."""
        with tempfile.TemporaryDirectory() as tmp:
            prefix = Path(tmp) / "usr" / "local"
            binary = make_executable(prefix / "bin" / "tonto")
            basis = make_basis_sets(prefix / "share" / "tonto" / "basis_sets")
            self.assertEqual(discovery.find_basis_sets(binary), basis)

    def test_basis_sets_beside_the_binary(self):
        with tempfile.TemporaryDirectory() as tmp:
            binary = make_executable(Path(tmp) / "somewhere" / "tonto")
            basis = make_basis_sets(Path(tmp) / "somewhere" / "basis_sets")
            self.assertEqual(discovery.find_basis_sets(binary), basis)

    def test_an_empty_directory_is_not_accepted(self):
        """An empty basis_sets directory is worse than none."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "tonto"
            binary = make_executable(root / "release" / "tonto")
            (root / "basis_sets").mkdir(parents=True)
            with mock.patch.object(discovery, "_search_roots", return_value=[]):
                self.assertIsNone(discovery.find_basis_sets(binary))

    def test_a_bare_name_yields_nothing_from_the_binary(self):
        """"tonto" on PATH says nothing about where the basis sets are."""
        with mock.patch.object(discovery, "_search_roots", return_value=[]):
            self.assertIsNone(discovery.find_basis_sets("tonto"))

    def test_nothing_found_returns_none(self):
        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.object(
                discovery, "_search_roots", return_value=[Path(tmp)]
            ), mock.patch("shutil.which", return_value=None):
                self.assertIsNone(discovery.find_tonto_executable())
                self.assertIsNone(discovery.find_basis_sets(None))


class ExecutableDiscoveryTest(unittest.TestCase):
    def test_path_wins_over_searching(self):
        """If the user has put Tonto on PATH, respect that."""
        with mock.patch("shutil.which", return_value="/somewhere/on/path/tonto"):
            self.assertEqual(
                discovery.find_tonto_executable(),
                Path("/somewhere/on/path/tonto"),
            )

    def test_finds_a_build_tree(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "tonto"
            binary = make_executable(root / "release" / "tonto")
            with mock.patch("shutil.which", return_value=None), mock.patch.object(
                discovery, "_search_roots", return_value=[root]
            ):
                self.assertEqual(discovery.find_tonto_executable(), binary)

    def test_a_non_executable_file_is_ignored(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "tonto"
            (root / "release").mkdir(parents=True)
            (root / "release" / "tonto").write_text("not executable\n")
            with mock.patch("shutil.which", return_value=None), mock.patch.object(
                discovery, "_search_roots", return_value=[root]
            ):
                self.assertIsNone(discovery.find_tonto_executable())


if __name__ == "__main__":
    unittest.main()
