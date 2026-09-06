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
    _fourier_matrix,
    _parse_xml,
    _read_crystal_triangular_blocks,
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


PAIRED_TRIANGLES_XML = """<ROOT><DIRECT_OVERLAP_MATRIX>
<DIRECT_OVERLAP_MATRIX__IVDL.1 components_of_IVDL.1="1 0 0">
  1.0 2.0 3.0
</DIRECT_OVERLAP_MATRIX__IVDL.1>
<DIRECT_OVERLAP_MATRIX__IVDL.2 components_of_IVDL.2="-1 0 0">
  1.0 4.0 3.0
</DIRECT_OVERLAP_MATRIX__IVDL.2>
</DIRECT_OVERLAP_MATRIX></ROOT>
"""


def _read_kred_full_zone_orbitals(
    path: Path, nao: int
) -> list[tuple[np.ndarray, np.ndarray, np.ndarray]]:
    """Read the formatted CRYSTAL KRED contract needed by the regression."""

    values = np.fromstring(path.read_text(encoding="utf-8"), sep=" ")
    cursor = 0
    grid = np.rint(values[cursor : cursor + 3]).astype(np.int64)
    cursor += 3
    nk = int(round(values[cursor]))
    cursor += 1
    cursor += 9  # reciprocal lattice
    cursor += 3 * nk  # irreducible k points
    k_kind = np.rint(values[cursor : cursor + nk]).astype(np.int64)
    cursor += nk
    cursor += 9 * 48  # reciprocal-space symmetry rotations
    weights = values[cursor : cursor + nk]
    cursor += nk
    energies = values[cursor : cursor + nao * nk].reshape((nao, nk), order="F")
    cursor += nao * nk
    cursor += nao * nk  # occupation weights

    orbitals: list[tuple[np.ndarray, np.ndarray, np.ndarray]] = []
    n_full_k = int(np.prod(grid))
    for ik in range(nk):
        multiplicity = int(round(float(weights[ik]) * n_full_k))
        for _star in range(multiplicity):
            k_integer = np.rint(values[cursor : cursor + 3]).astype(np.int64)
            cursor += 3
            nvalue = (2 - int(k_kind[ik])) * nao * nao
            raw = values[cursor : cursor + nvalue]
            cursor += nvalue
            if k_kind[ik] == 0:
                coefficients_flat = raw[0::2] + 1j * raw[1::2]
            else:
                coefficients_flat = raw.astype(np.complex128)
            coefficients = coefficients_flat.reshape((nao, nao), order="F")
            kpoint = k_integer / grid
            kpoint -= np.rint(kpoint)
            orbitals.append((kpoint, energies[:, ik], coefficients))

    if len(orbitals) != n_full_k:
        raise AssertionError(f"KRED contains {len(orbitals)} full-zone points, expected {n_full_k}")
    if cursor != values.size:
        raise AssertionError(f"KRED parser left {values.size - cursor} numeric values unread")
    return orbitals


class PeriodicWavefunctionExportTest(unittest.TestCase):
    def test_crystal_triangle_record_supplies_lower_triangle_for_its_own_lattice_vector(self):
        with tempfile.TemporaryDirectory() as directory:
            xml = Path(directory) / "paired.xml"
            xml.write_text(PAIRED_TRIANGLES_XML, encoding="utf-8")
            blocks = _read_crystal_triangular_blocks(
                _parse_xml(xml), "DIRECT_OVERLAP_MATRIX", 2
            )

        np.testing.assert_allclose(
            blocks[(1, 0, 0)],
            np.asarray([[1.0, 4.0], [2.0, 3.0]]),
        )
        np.testing.assert_allclose(blocks[(-1, 0, 0)], blocks[(1, 0, 0)].T)

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

    def test_real_diamond_direct_matrices_match_native_kred_orbitals(self):
        root_path = Path(
            "/home/lorraine/private_Tonto/Lolo_tests/periodic_xcw_validation_20260901/"
            "diamond_standard_36_toldee8_reference"
        )
        xml = root_path / "GenerateXML.XML"
        kred = root_path / "GenerateXML_dat.KRED"
        if not xml.is_file() or not kred.is_file():
            self.skipTest("local Crystal23 diamond XML/KRED validation data are not present")

        root = _parse_xml(xml)
        nao = int(
            (root.find(".//OUTPUT_DATA/ELECTRONIC_STRUCTURE/NUMBER_OF_ATOMIC_ORBITALS").text or "")
            .strip()
        )
        overlap_blocks = _read_crystal_triangular_blocks(
            root, "DIRECT_OVERLAP_MATRIX", nao
        )
        fock_blocks = _read_crystal_triangular_blocks(
            root, "DIRECT_FOCK_KOHN-SHAM_MATRIX", nao
        )

        max_orthogonality_error = 0.0
        max_eigen_residual = 0.0
        max_spectral_fock_error = 0.0
        for kpoint, energies, coefficients in _read_kred_full_zone_orbitals(kred, nao):
            overlap = _fourier_matrix(overlap_blocks, kpoint)
            fock = _fourier_matrix(fock_blocks, kpoint)
            overlap_coefficients = overlap @ coefficients
            orthogonality = (
                coefficients.conj().T @ overlap_coefficients - np.eye(nao)
            )
            residual = (
                fock @ coefficients
                - overlap_coefficients * energies[np.newaxis, :]
            )
            spectral_fock = (
                overlap_coefficients * energies[np.newaxis, :]
            ) @ overlap_coefficients.conj().T
            max_orthogonality_error = max(
                max_orthogonality_error, float(np.max(np.abs(orthogonality)))
            )
            max_eigen_residual = max(
                max_eigen_residual,
                float(np.linalg.norm(residual) / np.linalg.norm(fock @ coefficients)),
            )
            max_spectral_fock_error = max(
                max_spectral_fock_error,
                float(np.linalg.norm(fock - spectral_fock) / np.linalg.norm(fock)),
            )

        self.assertLess(max_orthogonality_error, 1.0e-8)
        self.assertLess(max_eigen_residual, 5.0e-8)
        self.assertLess(max_spectral_fock_error, 5.0e-8)


if __name__ == "__main__":
    unittest.main()
