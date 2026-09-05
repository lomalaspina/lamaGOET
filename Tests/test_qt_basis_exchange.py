#!/usr/bin/env python3
import unittest
from decimal import Decimal

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
    def test_crystal_natrolite_def2_format_and_exact_contractions(self):
        """CRYSTAL23 manual 2.2.1: radial shell input, not AO components.

        Compare against raw BSE JSON, independently of BSE's CRYSTAL writer.
        Retain coefficient/exponent pairing, signs, complete contractions, all
        functions, neutral CHE and the single final mixed-basis terminator.
        This also protects the Natrolite format audit against regressions.
        """
        symbols = {1: "H", 8: "O", 11: "Na", 13: "Al", 14: "Si"}
        expected_aos = {1: 6, 8: 31, 11: 32, 13: 37, 14: 37}
        text, _ = render_mixed_basis(
            "Crystal14", {symbol: "def2-TZVP" for symbol in symbols.values()}
        )
        raw = basis_set_exchange.get_basis("def2-TZVP", elements=list(symbols))
        lines = text.splitlines()
        self.assertEqual(sum(line.split() == ["99", "0"] for line in lines), 1)
        self.assertEqual(lines[-1], "99 0")
        index = 0
        seen = set()
        decimal = lambda value: Decimal(value.replace("D", "E").replace("d", "e"))
        while index < len(lines) - 1:
            atom_header = lines[index].split()
            self.assertEqual(len(atom_header), 2)
            z, shell_count = map(int, atom_header)
            self.assertNotIn(z, seen)
            seen.add(z)
            index += 1
            shells = []
            charge = Decimal(0)
            aos = 0
            for _ in range(shell_count):
                header = lines[index].split()
                self.assertEqual(len(header), 5)
                ityb, lat, ng = map(int, header[:3])
                self.assertEqual(ityb, 0)
                # These def2-TZVP elements contain S/P/D/F only. CRYSTAL
                # internally expands D/F into five/seven spherical AOs.
                self.assertIn(lat, (0, 2, 3, 4))
                self.assertGreater(ng, 0)
                if lat <= 2:
                    self.assertLessEqual(ng, 10)
                elif lat == 3:
                    self.assertLessEqual(ng, 6)
                self.assertEqual(decimal(header[4]), 1)
                shell_charge = decimal(header[3])
                self.assertGreaterEqual(shell_charge, 0)
                self.assertLessEqual(shell_charge, {0: 2, 2: 6, 3: 10, 4: 14}[lat])
                charge += shell_charge
                aos += {0: 1, 2: 3, 3: 5, 4: 7}[lat]
                primitives = []
                for row in lines[index + 1:index + 1 + ng]:
                    fields = row.split()
                    self.assertEqual(len(fields), 2)
                    exponent, coefficient = map(decimal, fields)
                    self.assertGreater(exponent, 0)
                    primitives.append((exponent, coefficient))
                shells.append((0 if lat == 0 else lat - 1, primitives))
                index += ng + 1
            source_shells = []
            for shell in raw["elements"][str(z)]["electron_shells"]:
                self.assertEqual(len(shell["angular_momentum"]), 1)
                self.assertEqual(len(shell["coefficients"]), 1)
                source_shells.append((shell["angular_momentum"][0], [
                    (decimal(exponent), decimal(coefficient))
                    for exponent, coefficient in zip(
                        shell["exponents"], shell["coefficients"][0]
                    )
                ]))
            # BSE orders complete shells compact-to-diffuse for each angular
            # momentum; it may therefore permute the raw JSON shell list.
            # CRYSTAL input contains radial contractions, not explicit px/py/
            # pz or d/f Cartesian components that should be reordered here.
            self.assertCountEqual(shells, source_shells, symbols[z])
            self.assertEqual(charge, z)
            self.assertEqual(aos, expected_aos[z])
        self.assertEqual(seen, set(symbols))

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
