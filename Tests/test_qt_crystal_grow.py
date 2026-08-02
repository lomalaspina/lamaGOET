#!/usr/bin/env python3
from pathlib import Path
import math
import tempfile
import unittest

from lamagoet_qt.crystal import (
    adp_principal_axes,
    Cell,
    CifError,
    CrystalStructure,
    SymmetryOperation,
    crystal23_spacegroup_record,
    ellipsoid_probability_radius,
    write_grown_cif,
)


ROOT = Path(__file__).resolve().parents[1]
SOURCE_CIF = ROOT / "Tests" / "inputs" / "calc.cif"


class CrystalGrowTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.structure = CrystalStructure.from_cif(SOURCE_CIF)

    def test_explicit_symmetry_expands_the_unit_cell(self):
        self.assertEqual(len(self.structure.asymmetric_atoms), 25)
        self.assertEqual(len(self.structure.symmetry_operations), 4)
        self.assertEqual(len(self.structure.unit_cell()), 100)

    def test_all_grow_modes_produce_explicit_atoms(self):
        cell = self.structure.unit_cell()
        molecules = self.structure.complete_molecules()
        supercell = self.structure.supercell(1)
        radius = self.structure.within_radius(cell[0], 3.0)
        short_contacts = self.structure.short_contacts(3.0)
        vdw_contacts = self.structure.vdw_contacts(0.2)
        self.assertGreaterEqual(len(molecules), len(self.structure.asymmetric_atoms))
        self.assertEqual(len(supercell), 27 * len(cell))
        self.assertTrue(radius)
        self.assertTrue(short_contacts)
        self.assertTrue(vdw_contacts)
        self.assertIn(cell[0].source_index, {atom.source_index for atom in radius})

    def test_complete_molecule_matches_tonto_connectivity_for_fixture(self):
        completed = self.structure.complete_molecules()
        self.assertEqual(len(completed), 75)
        self.assertTrue(any(atom.translation != (0, 0, 0) for atom in completed))

    def test_grow_operations_are_cumulative(self):
        vdw = self.structure.vdw_contacts(0.2)
        completed = self.structure.complete_molecules(vdw)
        key = lambda atom: tuple(round(value, 7) for value in atom.cartesian)
        self.assertTrue({key(atom) for atom in vdw}.issubset({key(atom) for atom in completed}))

        contacts = self.structure.short_contacts(3.0, completed)
        self.assertTrue(
            {key(atom) for atom in completed}.issubset({key(atom) for atom in contacts})
        )

    def test_uij_is_transformed_to_physical_cartesian_covariance(self):
        cell = Cell.from_parameters(10, 10, 10, 90, 90, 90)
        swap_xy = SymmetryOperation(
            ((0.0, 1.0, 0.0), (1.0, 0.0, 0.0), (0.0, 0.0, 1.0)),
            (0.0, 0.0, 0.0),
            "y,x,z",
        )
        transformed, cartesian = cell.transform_uij(
            (0.01, 0.04, 0.09, 0.002, 0.003, 0.004), swap_xy
        )
        self.assertAlmostEqual(transformed[0], 0.04)
        self.assertAlmostEqual(transformed[1], 0.01)
        self.assertAlmostEqual(transformed[3], 0.002)
        self.assertAlmostEqual(cartesian[0], 0.04)
        self.assertAlmostEqual(cartesian[1], 0.01)

    def test_nonorthogonal_isotropic_uij_becomes_cartesian_sphere(self):
        cell = Cell.from_parameters(9.2, 10.1, 11.4, 72, 81, 67)
        a, b, c = cell.vectors

        def cross(left, right):
            return (
                left[1] * right[2] - left[2] * right[1],
                left[2] * right[0] - left[0] * right[2],
                left[0] * right[1] - left[1] * right[0],
            )

        reciprocal = (cross(b, c), cross(c, a), cross(a, b))

        def cosine(left, right):
            return sum(x * y for x, y in zip(left, right)) / (
                math.sqrt(sum(x * x for x in left))
                * math.sqrt(sum(y * y for y in right))
            )

        uiso = 0.025
        cif_uij = (
            uiso,
            uiso,
            uiso,
            uiso * cosine(reciprocal[0], reciprocal[1]),
            uiso * cosine(reciprocal[0], reciprocal[2]),
            uiso * cosine(reciprocal[1], reciprocal[2]),
        )
        identity = SymmetryOperation(
            ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)),
            (0.0, 0.0, 0.0),
            "x,y,z",
        )
        _, cartesian = cell.transform_uij(cif_uij, identity)
        for value in cartesian[:3]:
            self.assertAlmostEqual(value, uiso, places=10)
        for value in cartesian[3:]:
            self.assertAlmostEqual(value, 0.0, places=10)

    def test_ellipsoid_probability_uses_three_dimensional_contour(self):
        self.assertAlmostEqual(ellipsoid_probability_radius(50), 1.53817, places=4)
        self.assertGreater(
            ellipsoid_probability_radius(90),
            ellipsoid_probability_radius(50),
        )

    def test_adp_principal_axes_reconstruct_cartesian_tensor(self):
        values = (0.025, 0.041, 0.067, 0.006, -0.004, 0.009)
        decomposition = adp_principal_axes(values)
        self.assertIsNotNone(decomposition)
        eigenvalues, axes = decomposition or ((), ())
        expected = (
            (values[0], values[3], values[4]),
            (values[3], values[1], values[5]),
            (values[4], values[5], values[2]),
        )
        for row in range(3):
            for column in range(3):
                reconstructed = sum(
                    eigenvalues[axis] * axes[axis][row] * axes[axis][column]
                    for axis in range(3)
                )
                self.assertAlmostEqual(reconstructed, expected[row][column], places=11)

    def test_adp_principal_axes_reject_non_positive_tensor(self):
        self.assertIsNone(adp_principal_axes((0.02, -0.01, 0.03, 0.0, 0.0, 0.0)))

    def test_exported_geometry_retains_symmetry_and_can_be_reloaded(self):
        visible = self.structure.complete_molecules()
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "grown.cif"
            write_grown_cif(output, self.structure, visible)
            text = output.read_text(encoding="utf-8")
            self.assertIn("_space_group_IT_number 14", text)
            self.assertIn("p 1 21/n 1", text)
            reloaded = CrystalStructure.from_cif(output)
            self.assertEqual(len(reloaded.asymmetric_atoms), len(visible))
            self.assertEqual(
                len(reloaded.symmetry_operations),
                len(self.structure.symmetry_operations),
            )

    def test_original_cif_cannot_be_overwritten(self):
        with self.assertRaises(CifError):
            write_grown_cif(
                SOURCE_CIF, self.structure, self.structure.asymmetric_unit()
            )

    def test_crystal_spacegroup_record_preserves_legacy_column_contract(self):
        structure = CrystalStructure(
            self.structure.cell,
            self.structure.asymmetric_atoms,
            self.structure.symmetry_operations,
            "R 3",
            "146",
            None,
            "R 3",
        )
        self.assertEqual(
            crystal23_spacegroup_record(structure, "r"),
            "146:r = R 3:r = R 3\n",
        )
        self.assertEqual(
            crystal23_spacegroup_record(structure, "h"),
            "146:h = R 3:h = R 3\n",
        )


if __name__ == "__main__":
    unittest.main()
