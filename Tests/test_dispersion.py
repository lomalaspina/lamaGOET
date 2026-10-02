#!/usr/bin/env python3
"""Focused anomalous-dispersion table and serialization checks."""

from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from lamagoet_qt.dispersion import (
    calculate_dispersion,
    find_fprime_data,
    parse_overrides,
    resolve_dispersion,
    serialize_coefficients,
    serialize_overrides,
)


class DispersionTest(unittest.TestCase):
    def test_brennan_cowan_reference_value_and_manual_override(self):
        iodine = calculate_dispersion("I", 0.71073, "brennan")
        self.assertAlmostEqual(iodine.fp, -0.4442290092, places=8)
        self.assertAlmostEqual(iodine.fpp, 1.8166328448, places=8)

        values = resolve_dispersion(
            ["N", "H", "N"],
            0.71073,
            "brennan",
            {"N": (0.125, 0.25)},
        )
        self.assertEqual([value.element for value in values], ["H", "N"])
        self.assertTrue(values[1].manual)
        self.assertEqual((values[1].fp, values[1].fpp), (0.125, 0.25))
        self.assertEqual(
            serialize_coefficients(values),
            "H 0 0 N 0.125 0.25",
        )

    def test_manual_override_json_round_trip(self):
        overrides = {"I": (-0.1572490578, 1.8168386984), "O": (0.0, 0.01)}
        self.assertEqual(parse_overrides(serialize_overrides(overrides)), overrides)

    @unittest.skipIf(
        find_fprime_data() is None,
        "no local Xsect.dat/xsect_n.dat table for the FPRIME regression",
    )
    def test_fprime_reference_values_when_table_is_installed(self):
        # Independently generated with the pinned upstream GSAS-II
        # GetXsectionCoeff/FPcalc implementation.  The matrix spans light,
        # main-group, transition-metal and actinide records and three energies.
        references = (
            ("C", 0.71073, 0.003330997962913419, 0.0016120410250708276),
            ("Si", 1.54184, 0.25417587099991473, 0.33072517464804885),
            ("Fe", 0.3, 0.1097699765743071, 0.162663231928645),
            ("I", 0.71073, -0.47814643998943274, 1.8168386721798004),
            ("U", 0.71073, -9.890550560617474, 9.690155656250129),
        )
        for element, wavelength, expected_fp, expected_fpp in references:
            with self.subTest(element=element, wavelength=wavelength):
                value = calculate_dispersion(element, wavelength, "fprime")
                self.assertAlmostEqual(value.fp, expected_fp, places=12)
                self.assertAlmostEqual(value.fpp, expected_fpp, places=12)


if __name__ == "__main__":
    unittest.main()
