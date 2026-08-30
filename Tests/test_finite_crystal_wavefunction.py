#!/usr/bin/env python3
"""Regression tests for the finite crystal-cluster wavefunction generator."""

from __future__ import annotations

from pathlib import Path
import tempfile
import unittest

from finite_crystal_wavefunction import (
    _method_block,
    _write_tonto_input,
    build_cluster,
)
from lamagoet_qt.crystal import CrystalStructure


DIAMOND_CIF = """data_diamond
_cell_length_a 3.567
_cell_length_b 3.567
_cell_length_c 3.567
_cell_angle_alpha 90
_cell_angle_beta 90
_cell_angle_gamma 90
_space_group_name_H-M_alt 'P 1'
loop_
_space_group_symop_operation_xyz
'x,y,z'
loop_
_atom_site_label
_atom_site_type_symbol
_atom_site_fract_x
_atom_site_fract_y
_atom_site_fract_z
C1 C 0.00 0.00 0.00
C2 C 0.25 0.25 0.25
C3 C 0.00 0.50 0.50
C4 C 0.25 0.75 0.75
C5 C 0.50 0.00 0.50
C6 C 0.75 0.25 0.75
C7 C 0.50 0.50 0.00
C8 C 0.75 0.75 0.25
"""


class FiniteCrystalWavefunctionTests(unittest.TestCase):
    def test_diamond_is_network_and_severed_bonds_are_capped(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "diamond.cif"
            path.write_text(DIAMOND_CIF, encoding="utf-8")
            structure = CrystalStructure.from_cif(path)
            atoms, metadata = build_cluster(structure, 1, 1.0, 2.0, True)
        self.assertTrue(metadata["network"])
        self.assertEqual(metadata["real_atom_count"], 5)
        self.assertEqual(metadata["cap_atom_count"], 12)
        self.assertEqual(sum(atom.element == "H" and atom.cap for atom in atoms), 12)

    def test_pbe_tonto_input_uses_native_pbe_functionals(self) -> None:
        self.assertEqual(_method_block("PBE", 1), ("rks", [
            "      dft_exchange_functional= pbex",
            "      dft_correlation_functional= pbec",
        ]))

    def test_generated_input_requests_all_three_finite_exports(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "stdin"
            _write_tonto_input(
                path,
                "test",
                [],
                Path("/basis"),
                "full-electron",
                "RHF",
                0,
                1,
                1.0e-7,
            )
            text = path.read_text(encoding="utf-8")
        self.assertIn("put_nbo_file_47", text)
        self.assertIn("write_aim2000_wfn_file", text)
        self.assertIn("write_full_wfx_file", text)
        self.assertIn("make_fock_matrix", text)


if __name__ == "__main__":
    unittest.main()
