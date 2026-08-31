#!/usr/bin/env python3
import unittest

try:
    import basis_set_exchange  # noqa: F401
except ImportError:
    basis_set_exchange = None

from lamagoet_qt.basis_exchange import (
    _neutral_atom_subshell_occupancies,
    all_electron_basis_names,
    render_mixed_basis,
)


def crystal_element_shells(text, atomic_number):
    """Return ``(LAT, CHE)`` for one element block in rendered CRYSTAL text."""

    lines = text.splitlines()
    start = next(
        index
        for index, line in enumerate(lines)
        if line.split() and line.split()[0] == str(atomic_number)
    )
    header = lines[start].split()
    shell_count = int(header[1])
    result = []
    line_index = start + 1
    for _ in range(shell_count):
        fields = lines[line_index].split()
        primitive_count = int(fields[2])
        result.append((int(fields[1]), float(fields[3])))
        line_index += primitive_count + 1
    return result


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

    def test_mixed_gaussian_basis_keeps_one_delimiter_per_element(self):
        text, _ = render_mixed_basis(
            "Gaussian", {"H": "pob-TZVP-rev2", "N": "pob-TZVP-rev2"}
        )
        self.assertEqual(text.count("****"), 2)
        self.assertLess(text.index("H     0"), text.index("****"))
        self.assertLess(text.index("****"), text.index("N     0"))
        self.assertIn("****\nN     0", text)
        self.assertNotIn("****\n\nN     0", text)
        self.assertTrue(text.rstrip().endswith("****"))

    def test_mixed_crystal_basis_has_only_one_final_terminator(self):
        text, _ = render_mixed_basis(
            "Crystal14", {"H": "pob-TZVP-rev2", "N": "pob-TZVP-rev2"}
        )
        terminators = [
            index
            for index, line in enumerate(text.splitlines())
            if line.split() == ["99", "0"]
        ]
        self.assertEqual(len(terminators), 1)
        self.assertEqual(terminators[0], len(text.splitlines()) - 1)
        self.assertLess(text.index("1 4"), text.index("7 8"))
        self.assertLess(text.index("7 8"), text.index("99 0"))

    def test_crystal_def2_shell_charges_are_neutral_for_nh3_elements(self):
        text, _ = render_mixed_basis(
            "Crystal14", {"H": "def2-TZVP", "N": "def2-TZVP"}
        )
        hydrogen = crystal_element_shells(text, 1)
        nitrogen = crystal_element_shells(text, 7)

        self.assertEqual(hydrogen, [(0, 1.0), (0, 0.0), (0, 0.0), (2, 0.0)])
        self.assertEqual(sum(charge for _, charge in hydrogen), 1.0)
        self.assertEqual(nitrogen[:6], [
            (0, 2.0),
            (0, 2.0),
            (0, 0.0),
            (0, 0.0),
            (0, 0.0),
            (2, 3.0),
        ])
        self.assertEqual(sum(charge for _, charge in nitrogen), 7.0)

    def test_crystal_combined_sp_shell_receives_both_populations(self):
        text, _ = render_mixed_basis("Crystal14", {"C": "STO-3G"})
        self.assertEqual(crystal_element_shells(text, 6), [(0, 2.0), (1, 4.0)])

    def test_neutral_atom_promotions_keep_correct_total_and_cr_configuration(self):
        chromium = _neutral_atom_subshell_occupancies(24)
        self.assertEqual(chromium[(4, 0)], 1)
        self.assertEqual(chromium[(3, 2)], 5)
        self.assertEqual(sum(chromium.values()), 24)

    def test_neutral_atom_population_is_complete_through_crystal_z_limit(self):
        for atomic_number in range(1, 99):
            with self.subTest(atomic_number=atomic_number):
                populations = _neutral_atom_subshell_occupancies(atomic_number)
                self.assertEqual(sum(populations.values()), atomic_number)
                for (_, angular), population in populations.items():
                    self.assertGreaterEqual(population, 0)
                    self.assertLessEqual(population, 2 * (2 * angular + 1))


if __name__ == "__main__":
    unittest.main()
