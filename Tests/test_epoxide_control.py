#!/usr/bin/env python3
"""Guard the shortest Tonto IAM-to-HAR scientific control.

The default suite checks provenance, immutable fixture hashes, and the manual
contract without invoking Tonto.  Set ``LAMAGOET_RUN_EPOXIDE=1`` and provide
the executable and basis directory to run the numerical regression.
"""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import tempfile
import unittest

from lamagoet_qt.options_schema import complete_job_options


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "Tests" / "epoxide_control.json"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def model_statistics(listing: str, anchor: str) -> dict[str, float | int]:
    """Return the first principal statistics block following *anchor*."""

    anchor_offset = listing.index(anchor)
    label = "Model statistics based on structure factors:"
    body_start = listing.index(label, anchor_offset) + len(label)
    body_tail = listing[body_start:].lstrip("\r\n")
    body = body_tail.split("\n\n", 1)[0]

    def value(pattern: str, cast: type[float] | type[int]) -> float | int:
        match = re.search(pattern, body, flags=re.MULTILINE)
        if match is None:
            raise AssertionError(f"missing statistic {pattern!r} after {anchor!r}")
        return cast(match.group(1))

    return {
        "R_F": value(r"^R\(F\)\s+\.+\s+([0-9.]+)$", float),
        "wR_F2": value(r"^Rw\(F2\)\s+\.+\s+([0-9.]+)$", float),
        "reflections": value(r"^# of reflections,\s+N_r\s+\.+\s+(\d+)$", int),
        "parameters": value(r"^# of fit parameters,\s+N_p\s+\.+\s+(\d+)$", int),
        "GoF": value(r"^GoF\s+\(N_p\)\s+\.+\s+([0-9.]+)$", float),
    }


class EpoxideControlTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))

    def test_manifest_and_scientific_direction(self) -> None:
        self.assertEqual(self.manifest["schema_version"], 1)
        provenance = self.manifest["provenance"].lower()
        self.assertIn("retained", provenance)
        self.assertIn("not a claim", provenance)
        context = self.manifest["validation_context"]
        self.assertRegex(context["lamaGOET_revision"], r"^[0-9a-f]{40}$")
        self.assertRegex(context["tonto_revision"], r"^[0-9a-f]{40}$")
        self.assertEqual(context["tonto_version"], "26.09.20")

        expected = self.manifest["current_control"]["expected"]
        self.assertLess(expected["har"]["R_F"], expected["iam"]["R_F"])
        self.assertLess(expected["har"]["wR_F2"], expected["iam"]["wR_F2"])
        diagnostic = self.manifest["non_acceptance_diagnostic"]
        self.assertGreater(diagnostic["har"]["R_F"], expected["iam"]["R_F"])
        hashes = {
            item["sha256"]
            for item in self.manifest["historical_control"]["source_artifacts"].values()
        }
        self.assertEqual(len(hashes), 3)
        for digest in hashes:
            self.assertRegex(digest, r"^[0-9a-f]{64}$")

    def test_packaged_input_hashes(self) -> None:
        for fixture in self.manifest["fixtures"].values():
            path = ROOT / fixture["path"]
            self.assertTrue(path.is_file(), path)
            self.assertEqual(sha256(path), fixture["sha256"], path)

    def test_manual_uses_the_validated_control(self) -> None:
        getting_started = (ROOT / "docs/manual/getting-started.md").read_text(
            encoding="utf-8"
        )
        examples = (ROOT / "docs/manual/examples.md").read_text(encoding="utf-8")
        testing = (ROOT / "docs/TESTING.md").read_text(encoding="utf-8")
        for document in (getting_started, examples, testing):
            self.assertIn("def2-SVP", document)
            self.assertIn("MERG 2", document)
            self.assertIn("0.030272", document)
            self.assertIn("1,313", document)
        self.assertIn("cutoff 4", getting_started)
        self.assertIn("| F/σ cut | 4 |", examples)
        self.assertIn("F/σ cutoff 4", testing)
        self.assertNotIn("Method / basis | HF / STO-3G", examples)
        self.assertNotIn("set HF/STO-3G", getting_started)

    def test_live_tonto_control(self) -> None:
        if os.environ.get("LAMAGOET_RUN_EPOXIDE") != "1":
            self.skipTest("set LAMAGOET_RUN_EPOXIDE=1 for the live Tonto run")

        tonto = Path(os.environ.get("LAMAGOET_TONTO_BIN", ""))
        basis_dir = Path(os.environ.get("LAMAGOET_TONTO_BASIS_DIR", ""))
        self.assertTrue(tonto.is_file(), "LAMAGOET_TONTO_BIN is not a file")
        self.assertTrue(basis_dir.is_dir(), "LAMAGOET_TONTO_BASIS_DIR is not a directory")
        self.assertTrue((basis_dir / "def2-SVP").is_file(), "def2-SVP is unavailable")

        control = self.manifest["current_control"]
        settings = control["settings"]
        overrides = {
            "SCFCALCPROG": "Tonto",
            "TONTO": str(tonto.resolve()),
            "BASISSETDIR": str(basis_dir.resolve()),
            "TONTO_BASIS_DIR": str(basis_dir.resolve()),
            "BASISSETT": settings["basis"],
            "METHOD": settings["method"],
            "CIF": str((ROOT / self.manifest["fixtures"]["cif"]["path"]).resolve()),
            "HKL": str((ROOT / self.manifest["fixtures"]["hkl"]["path"]).resolve()),
            "JOBNAME": "epoxide_control",
            "WAVE": str(settings["wavelength_angstrom"]),
            "MERGCODE": str(settings["merg_code"]),
            "FCUT": str(settings["f_sigma_cutoff"]),
            "IAMTONTO": "true",
            "ONLYIAMTONTO": "false",
            "NUMPROC": "1",
            "NUMPROCTONTO": "1",
            "EXIT": "OK",
        }
        options = complete_job_options(overrides)

        with tempfile.TemporaryDirectory(prefix="lamagoet-epoxide-control-") as tmp:
            work = Path(tmp)
            job_options = work / "job_options.txt"
            job_options.write_text(
                "".join(
                    f"{name}={shlex.quote(str(value))}\n"
                    for name, value in options.items()
                ),
                encoding="utf-8",
            )
            process = subprocess.run(
                ["bash", str(ROOT / "lamaGOET.sh"), "--run-job-options", str(job_options)],
                cwd=work,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=300,
                check=False,
            )
            self.assertEqual(process.returncode, 0, process.stdout[-8000:])

            listing_path = work / "epoxide_control.lst"
            self.assertTrue(listing_path.is_file(), process.stdout[-4000:])
            listing = listing_path.read_text(encoding="utf-8", errors="replace")
            iam = model_statistics(
                listing,
                "IAM refinement\n==============\n\nStructure fit converged.",
            )
            har = model_statistics(
                listing,
                "Structure refinement results\n============================\n\nStructure refinement converged.",
            )

            tolerance = float(control["absolute_tolerance"])
            for stage, actual in (("iam", iam), ("har", har)):
                expected = control["expected"][stage]
                for key in ("R_F", "wR_F2", "GoF"):
                    self.assertAlmostEqual(
                        actual[key], expected[key], delta=tolerance, msg=f"{stage} {key}"
                    )
                for key in ("reflections", "parameters"):
                    self.assertEqual(actual[key], expected[key], f"{stage} {key}")

            self.assertLess(har["R_F"], iam["R_F"])
            self.assertLess(har["wR_F2"], iam["wR_F2"])

            generated = work / "1.tonto_cycle.epoxide_control" / "1.stdin"
            self.assertTrue(generated.is_file(), generated)
            stdin = generated.read_text(encoding="utf-8", errors="replace")
            self.assertIn(f"basis_directory= {basis_dir.resolve()}", stdin)
            self.assertIn("basis_name= def2-SVP", stdin)
            self.assertIn("merg_code= 2", stdin)
            self.assertIn("f_sigma_cutoff= 4", stdin)
            self.assertIn("IAM_refinement", stdin)


if __name__ == "__main__":
    unittest.main()
