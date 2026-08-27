#!/usr/bin/env python3
"""Regression tests for CP2K/Crystal23 periodic TREXIO export."""

from __future__ import annotations

from pathlib import Path
import sys
import tempfile
import unittest

import numpy as np


REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO))

from periodic_wavefunction_export import (  # noqa: E402
    read_crystal23_orbitals,
    validate_trexio,
    write_trexio,
)


MINIMAL_XML = """<ROOT>
<GEOMETRY><PERIODICITY><CELL>
<CELL_VECTOR_A> 4 0 0 </CELL_VECTOR_A>
<CELL_VECTOR_B> 0 4 0 </CELL_VECTOR_B>
<CELL_VECTOR_C> 0 0 4 </CELL_VECTOR_C>
</CELL></PERIODICITY><ATOMS>
<CARTESIAN_COORDINATES><ATOM.1 atomic_symbol="H" atomic_number="1"> 0 0 0 </ATOM.1></CARTESIAN_COORDINATES>
</ATOMS></GEOMETRY>
<BASIS_SET><ATOMIC_ORBITALS>
<ATOMIC_ORBITALS_OF_ATOM.1 number_of_atomic_orbitals_per_atom="1"><TYPE>S</TYPE></ATOMIC_ORBITALS_OF_ATOM.1>
</ATOMIC_ORBITALS></BASIS_SET>
<METHOD><BRILLOUIN_ZONE><IRREDUCIBLE_K_VECTORS>
<K_VECTOR.1 weight="1.0"> 0 0 0 </K_VECTOR.1>
</IRREDUCIBLE_K_VECTORS></BRILLOUIN_ZONE></METHOD>
<OUTPUT_DATA><ELECTRONIC_STRUCTURE>
<NUMBER_OF_ELECTRONS>2</NUMBER_OF_ELECTRONS>
<NUMBER_OF_SPIN_COMPONENTS>1</NUMBER_OF_SPIN_COMPONENTS>
<NUMBER_OF_ATOMIC_ORBITALS>1</NUMBER_OF_ATOMIC_ORBITALS>
<NUMBER_OF_BANDS>1</NUMBER_OF_BANDS>
</ELECTRONIC_STRUCTURE>
<DIRECT_OVERLAP_MATRIX><DIRECT_OVERLAP_MATRIX_INFO />
<DIRECT_OVERLAP_MATRIX__IVDL.1 components_of_IVDL.1="0 0 0"> 1.0 </DIRECT_OVERLAP_MATRIX__IVDL.1>
</DIRECT_OVERLAP_MATRIX>
<DIRECT_FOCK_KOHN-SHAM_MATRIX><DIRECT_FOCK_KOHN-SHAM_MATRIX_INFO />
<DIRECT_FOCK_KOHN-SHAM_MATRIX__IVDL.1 components_of_IVDL.1="0 0 0"> -0.5 </DIRECT_FOCK_KOHN-SHAM_MATRIX__IVDL.1>
</DIRECT_FOCK_KOHN-SHAM_MATRIX>
</OUTPUT_DATA></ROOT>
"""

MINIMAL_BASIS = """{
keys= { turbomole= }
data= {
H:test
{
  1 s
  1.0 1.0
}
}
}
"""


class PeriodicWavefunctionExportTest(unittest.TestCase):
    def test_crystal_generalized_eigenproblem_and_trexio_roundtrip(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            xml = root / "test.xml"
            basis = root / "test-basis"
            output = root / "test.trexio"
            xml.write_text(MINIMAL_XML, encoding="utf-8")
            basis.write_text(MINIMAL_BASIS, encoding="utf-8")

            orbitals = read_crystal23_orbitals(xml, basis)
            self.assertEqual(orbitals.coefficients.shape, (1, 1, 1, 1))
            self.assertAlmostEqual(float(orbitals.eigenvalues[0, 0, 0]), -0.5)
            self.assertAlmostEqual(float(orbitals.occupations[0, 0, 0]), 2.0)

            write_trexio(orbitals, output)
            summary = validate_trexio(output, orbitals)
            self.assertEqual(summary["nucleus_num"], 1)
            self.assertEqual(summary["ao_num"], 1)
            self.assertEqual(summary["k_point_num"], 1)
            self.assertEqual(summary["mo_num"], 1)
            self.assertEqual(summary["electron_up"], 1)
            self.assertEqual(summary["electron_down"], 1)

    def test_real_diamond_crystal_xml_reproduces_printed_band_edges(self):
        xml = Path(
            "/home/lorraine/private_Tonto/Lolo_tests/diamond/merged2/"
            "diamond_periodic_crystal23/GenerateXML.XML"
        )
        basis = Path("/home/lorraine/private_Tonto/basis_sets/pob-TZVP-rev2")
        if not xml.is_file() or not basis.is_file():
            self.skipTest("local Crystal23 diamond validation data are not present")
        orbitals = read_crystal23_orbitals(xml, basis)
        # Crystal23 my_job.out prints Gamma band 6 = -1.2498752E-01 and
        # Gamma band 7 = 7.9877576E-02 Hartree for this final XML.
        # The XML matrices are printed after finite-tolerance SCF convergence,
        # so rediagonalization agrees with the last SCF table to about 1e-6 Ha.
        self.assertAlmostEqual(float(orbitals.eigenvalues[0, 0, 5]), -0.12498752, places=5)
        self.assertAlmostEqual(float(orbitals.eigenvalues[0, 0, 6]), 0.079877576, places=5)
        overlap_error = np.max(
            np.abs(np.imag(orbitals.coefficients[0, 0, :, :]))
        )
        self.assertLess(float(overlap_error), 1.0e-10)


if __name__ == "__main__":
    unittest.main()
