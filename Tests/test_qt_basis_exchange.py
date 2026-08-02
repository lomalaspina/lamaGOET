#!/usr/bin/env python3
import unittest

try:
    import basis_set_exchange  # noqa: F401
except ImportError:
    basis_set_exchange = None

from lamagoet_qt.basis_exchange import (
    all_electron_basis_names,
    render_mixed_basis,
)


@unittest.skipIf(basis_set_exchange is None, "basis_set_exchange is not installed")
class BasisExchangeTest(unittest.TestCase):
    def test_light_element_keeps_valid_def2_basis_but_filters_ecp_records(self):
        nitrogen = all_electron_basis_names("N")
        self.assertIn("def2-TZVP", nitrogen)
        self.assertGreater(len(nitrogen), 100)

    def test_mixed_cp2k_basis_has_element_map(self):
        text, mapping = render_mixed_basis(
            "CP2K", {"H": "def2-TZVP", "N": "def2-TZVP"}
        )
        self.assertIn("H def2-TZVP", text)
        self.assertIn("N def2-TZVP", text)
        self.assertEqual(mapping, "H=def2-TZVP N=def2-TZVP")

    def test_mixed_orca_basis_has_one_data_container(self):
        text, _ = render_mixed_basis(
            "Orca", {"H": "def2-TZVP", "N": "def2-TZVP"}
        )
        self.assertEqual(text.upper().count("$DATA"), 1)
        self.assertEqual(text.upper().count("$END"), 1)


if __name__ == "__main__":
    unittest.main()
