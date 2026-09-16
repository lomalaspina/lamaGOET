#!/usr/bin/env python3
"""Validate retained scientific regression archives and their provenance.

This test does not run Tonto or an external electronic-structure program. It
prevents the historical numerical evidence from silently disappearing or
being relabelled as a current rerun. Live calculations are opt-in through
``Tests/run_scientific_regressions.sh``.
"""

from __future__ import annotations

import json
import math
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
INPUTS = ROOT / "Tests" / "inputs"
MANIFEST = ROOT / "Tests" / "scientific_regressions.json"

TAGS = {
    "R_factor_all": "_refine_ls_R_factor_all",
    "wR_factor_all": "_refine_ls_wR_factor_all",
    "goodness_of_fit_all": "_refine_ls_goodness_of_fit_all",
    "density_max": "_refine_diff_density_max",
    "density_min": "_refine_diff_density_min",
    "density_rms": "_refine_diff_density_rms",
    "reflections_total": "_reflns_number_total",
}


def cif_scalars(path: Path) -> dict[str, float | int]:
    values: dict[str, float | int] = {}
    wanted = {tag: key for key, tag in TAGS.items()}
    for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        fields = raw_line.split()
        if len(fields) < 2 or fields[0] not in wanted:
            continue
        key = wanted[fields[0]]
        token = re.sub(r"\([^)]*\)$", "", fields[1])
        values[key] = int(token) if key == "reflections_total" else float(token)
    return values


def option_value(path: Path, name: str) -> str:
    pattern = re.compile(rf"^\s*{re.escape(name)}\s*=\s*(.*?)\s*$")
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        match = pattern.match(line)
        if match:
            return match.group(1).strip().strip("\"'")
    return ""


class ScientificArchiveTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))

    def test_manifest_is_explicitly_archival(self) -> None:
        self.assertEqual(self.manifest["schema_version"], 1)
        provenance = self.manifest["provenance"].lower()
        self.assertIn("archive", provenance)
        self.assertIn("not a claim", provenance)

    def test_case_list_matches_historical_driver(self) -> None:
        listed = {
            line.strip()
            for line in (INPUTS / "run_tests.txt").read_text().splitlines()
            if line.strip()
        }
        self.assertEqual(set(self.manifest["cases"]), listed)

    def test_archived_outputs_and_values(self) -> None:
        for name, case in self.manifest["cases"].items():
            with self.subTest(case=name):
                directory = INPUTS / name
                for filename in (
                    "job_options.txt",
                    "my_job.archive.cif",
                    "my_job.archive.fcf",
                    "my_job.archive.fco",
                    "my_job.lst",
                ):
                    artifact = directory / filename
                    self.assertTrue(artifact.is_file(), artifact)
                    self.assertGreater(artifact.stat().st_size, 0, artifact)

                self.assertEqual(
                    option_value(directory / "job_options.txt", "SCFCALCPROG"),
                    case["program"],
                )
                actual = cif_scalars(directory / "my_job.archive.cif")
                self.assertEqual(set(actual), set(case["expected"]))
                for key, expected in case["expected"].items():
                    if isinstance(expected, int):
                        self.assertEqual(actual[key], expected)
                    else:
                        self.assertTrue(math.isfinite(float(actual[key])))
                        self.assertAlmostEqual(float(actual[key]), expected, places=7)

                listing = (directory / "my_job.lst").read_text(
                    encoding="utf-8", errors="replace"
                )
                self.assertIn("Residual density data", listing)


if __name__ == "__main__":
    unittest.main()
