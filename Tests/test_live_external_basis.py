#!/usr/bin/env python3
"""Opt-in live checks for external basis files against installed SCF engines.

Set ``LAMAGOET_RUN_LIVE_SCF_TESTS=1`` to run these calculations.  The source
KHMAL cases are read-only; every program runs in a temporary directory.
"""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from lamagoet_qt.basis_exchange import render_mixed_basis


RUN_LIVE = os.environ.get("LAMAGOET_RUN_LIVE_SCF_TESTS") == "1"
KHMAL_ROOT = Path("/home/lorraine/private_Tonto/Lolo_tests/Sep7/KHMAL")


@unittest.skipUnless(RUN_LIVE, "set LAMAGOET_RUN_LIVE_SCF_TESTS=1")
class LiveExternalBasisTest(unittest.TestCase):
    def test_gaussian_bse_cartesian_fchk_is_readable_by_tonto(self):
        executable = Path("/home/lorraine/g09/g09")
        profile = Path("/home/lorraine/g09/bsd/g09.profile")
        tonto = Path("/home/lorraine/private_Tonto/build/tonto")
        if not executable.is_file() or not profile.is_file():
            self.skipTest("Gaussian 09 test installation is not available")
        if not tonto.is_file():
            self.skipTest("private Tonto executable is not built")
        basis, _ = render_mixed_basis(
            "Gaussian", {"H": "def2-TZVP", "O": "def2-TZVP"}
        )
        gaussian_input = (
            "%mem=256MB\n"
            "#p rhf/gen nosymm 6D 10F FChk\n\n"
            "lamaGOET Gaussian BSE Cartesian FChk regression\n\n"
            "0 1\n"
            "O  0.000000  0.000000  0.000000\n"
            "H  0.758602  0.000000  0.504284\n"
            "H -0.758602  0.000000  0.504284\n\n"
            + basis
            + "\n"
        )
        with tempfile.TemporaryDirectory(prefix="lamagoet-g09-bse-fchk-") as directory:
            work = Path(directory)
            (work / "h2o.com").write_text(gaussian_input, encoding="utf-8")
            result = subprocess.run(
                ["bash", "-lc", f"source {profile} && {executable} h2o.com"],
                cwd=work,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=600,
                check=False,
            )
            log_text = (work / "h2o.log").read_text(
                encoding="utf-8", errors="replace"
            )
            fchk = work / "Test.FChk"
            self.assertEqual(result.returncode, 0, log_text[-8000:])
            self.assertIn("Normal termination of Gaussian", log_text)
            self.assertTrue(fchk.is_file(), "Gaussian did not write Test.FChk")
            fchk_text = fchk.read_text(encoding="utf-8")
            shell_header = next(
                line for line in fchk_text.splitlines() if line.startswith("Shell types")
            )
            shell_count = int(shell_header.rsplit("=", 1)[1])
            shell_values: list[int] = []
            shell_lines = iter(fchk_text.splitlines())
            for line in shell_lines:
                if line.startswith("Shell types"):
                    break
            for line in shell_lines:
                shell_values.extend(int(value) for value in line.split())
                if len(shell_values) >= shell_count:
                    break
            self.assertEqual(len(shell_values), shell_count)
            self.assertTrue(
                all(value >= -1 for value in shell_values),
                "Gaussian 6D 10F unexpectedly emitted pure high-L shells",
            )
            (work / "stdin").write_text(
                "{ name= gaussian_bse read_g09_fchk_file Test.FChk }\n",
                encoding="utf-8",
            )
            tonto_result = subprocess.run(
                [str(tonto)],
                cwd=work,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=300,
                check=False,
            )
        self.assertEqual(tonto_result.returncode, 0, tonto_result.stdout[-8000:])

    def test_gaussian09_dkh_uses_filtered_external_dk_basis(self):
        executable = Path("/home/lorraine/g09/g09")
        profile = Path("/home/lorraine/g09/bsd/g09.profile")
        if not executable.is_file() or not profile.is_file():
            self.skipTest("Gaussian 09 DKH test installation is not available")
        basis, _ = render_mixed_basis("Gaussian", {"H": "cc-pVDZ-DK"})
        gaussian_input = (
            "%mem=256MB\n"
            "#p rhf/gen int=dkh\n\n"
            "lamaGOET Gaussian DKH basis regression\n\n"
            "0 1\n"
            "H 0.0 0.0 0.0\n"
            "H 0.0 0.0 0.74\n\n"
            + basis
            + "\n"
        )
        with tempfile.TemporaryDirectory(prefix="lamagoet-g09-dkh-") as directory:
            work = Path(directory)
            (work / "h2.com").write_text(gaussian_input, encoding="utf-8")
            result = subprocess.run(
                [
                    "bash",
                    "-lc",
                    f"source {profile} && {executable} h2.com",
                ],
                cwd=work,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=600,
                check=False,
            )
            log_text = (work / "h2.log").read_text(
                encoding="utf-8", errors="replace"
            )
        self.assertEqual(result.returncode, 0, log_text[-8000:])
        self.assertIn("Using DK2 one-electron Hamiltonian", log_text)
        self.assertIn("Normal termination of Gaussian", log_text)

    def test_private_tonto_rejects_silent_dkh_fallback(self):
        executable = Path("/home/lorraine/private_Tonto/build/tonto")
        if not executable.is_file():
            self.skipTest("private Tonto executable is not built")
        tonto_input = """{
   name= dkh_guard
   basis_directory= /home/lorraine/private_Tonto/basis_sets
   basis_name= STO-3G
   charge= 0
   multiplicity= 1
   atoms= {
      keys= { label= { units= angstrom } pos= }
      data= {
         1  0.000000  0.000000  0.000000
         1  0.000000  0.000000  0.740000
      }
   }
   put
   scfdata= {
      initial_density= promolecule
      kind= rhf
      relativity_kind= dkh
   }
   scf
}
"""
        with tempfile.TemporaryDirectory(prefix="tonto-dkh-guard-") as directory:
            work = Path(directory)
            (work / "stdin").write_text(tonto_input, encoding="utf-8")
            subprocess.run(
                [str(executable)],
                cwd=work,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=300,
                check=False,
            )
            tonto_stdout = (work / "stdout").read_text(
                encoding="utf-8", errors="replace"
            )
        self.assertIn("DKH/IOTC is unavailable in this Tonto branch", tonto_stdout)
        self.assertNotIn("SCF results", tonto_stdout)

    def test_tonto_reads_native_bse_library_and_runs_scf(self):
        executable = Path("/home/lorraine/private_Tonto/build/tonto")
        if not executable.is_file():
            self.skipTest("private Tonto executable is not built")
        basis, _ = render_mixed_basis(
            "Tonto", {"H": "STO-3G"}
        )
        tonto_input = """{
   name= h2_bse
   basis_directory= .
   basis_name= basis_gen
   charge= 0
   multiplicity= 1
   atoms= {
      keys= { label= { units= angstrom } pos= }
      data= {
         1  0.000000  0.000000  0.000000
         1  0.000000  0.000000  0.740000
      }
   }
   put
   scfdata= {
      initial_density= promolecule
      kind= rhf
      direct= on
      convergence= 0.00001
      diis= { convergence_tolerance= 0.00001 }
      output= NO
      output_results= YES
   }
   scf
}
"""
        with tempfile.TemporaryDirectory(prefix="lamagoet-tonto-bse-") as directory:
            work = Path(directory)
            (work / "basis_gen").write_text(basis, encoding="utf-8")
            (work / "stdin").write_text(tonto_input, encoding="utf-8")
            result = subprocess.run(
                [str(executable)],
                cwd=work,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=300,
                check=False,
            )
            tonto_stdout = (work / "stdout").read_text(
                encoding="utf-8", errors="replace"
            )
        self.assertEqual(result.returncode, 0, tonto_stdout[-8000:])
        self.assertNotIn("Error in", tonto_stdout)
        self.assertIn("SCF results", tonto_stdout)

    def test_orca_khmal_accepts_native_bse_newgto_input(self):
        source = KHMAL_ROOT / "orca_periodic_PBE_jorge_TZP"
        executable = Path("/usr/local/orca504/orca")
        if not executable.is_file():
            self.skipTest("ORCA 5 executable is not installed")
        original = (source / "my_job.inp").read_text(
            encoding="utf-8", errors="replace"
        )
        prefix = original.split("$DATA", 1)[0].rstrip()
        basis, _ = render_mixed_basis(
            "Orca",
            {element: "jorge-TZP" for element in ("C", "H", "K", "O")},
        )
        with tempfile.TemporaryDirectory(prefix="lamagoet-orca-bse-") as directory:
            work = Path(directory)
            input_path = work / "my_job.inp"
            input_path.write_text(prefix + "\n" + basis, encoding="utf-8")
            result = subprocess.run(
                [str(executable), input_path.name],
                cwd=work,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=1800,
                check=False,
            )
        self.assertEqual(result.returncode, 0, result.stdout[-8000:])
        self.assertIn("ORCA TERMINATED NORMALLY", result.stdout)
        self.assertNotIn("Line 34 of my_job.inp (DATA)", result.stdout)

    def test_occ_khmal_accepts_bse_json_with_charge_and_multiplicity(self):
        source = KHMAL_ROOT / "occ_periodic_PBE_jorge_TZP"
        executable = shutil.which("occ")
        tonto = Path("/home/lorraine/private_Tonto/build/tonto")
        if executable is None:
            self.skipTest("OCC executable is not installed")
        if not tonto.is_file():
            self.skipTest("private Tonto executable is not built")
        with tempfile.TemporaryDirectory(prefix="lamagoet-occ-bse-") as directory:
            work = Path(directory)
            shutil.copy2(source / "my_job.xyz", work / "my_job.xyz")
            basis, _ = render_mixed_basis(
                "OCC",
                {element: "jorge-TZP" for element in ("C", "H", "K", "O")},
            )
            (work / "basis_gen.json").write_text(basis, encoding="utf-8")
            environment = os.environ.copy()
            if "OCC_DATA_PATH" not in environment:
                local_data = Path("/home/lorraine/occ/share")
                if local_data.is_dir():
                    environment["OCC_DATA_PATH"] = str(local_data)
            result = subprocess.run(
                [
                    executable,
                    "scf",
                    "my_job.xyz",
                    "--method",
                    "pbe",
                    "--basis",
                    "./basis_gen.json",
                    "--charge",
                    "5",
                    "--multiplicity",
                    "1",
                    "--spherical",
                    "-o",
                    "fchk",
                ],
                cwd=work,
                env=environment,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=1800,
                check=False,
            )
            outputs = tuple(work.glob("*.fchk"))
            fchk_text = outputs[0].read_text(encoding="utf-8") if outputs else ""
            if outputs:
                (work / "stdin").write_text(
                    "{ name= occ_bse read_g09_fchk_file " + outputs[0].name + " }\n",
                    encoding="utf-8",
                )
                tonto_result = subprocess.run(
                    [str(tonto)],
                    cwd=work,
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    timeout=300,
                    check=False,
                )
        self.assertEqual(result.returncode, 0, result.stdout[-8000:])
        self.assertIn("A job well done", result.stdout)
        self.assertTrue(outputs, "OCC did not write the requested formatted checkpoint")
        self.assertEqual(tonto_result.returncode, 0, tonto_result.stdout[-8000:])
        shell_header = next(
            line for line in fchk_text.splitlines() if line.startswith("Shell types")
        )
        shell_count = int(shell_header.rsplit("=", 1)[1])
        shell_values: list[int] = []
        shell_lines = iter(fchk_text.splitlines())
        for line in shell_lines:
            if line.startswith("Shell types"):
                break
        for line in shell_lines:
            shell_values.extend(int(value) for value in line.split())
            if len(shell_values) >= shell_count:
                break
        self.assertEqual(len(shell_values), shell_count)
        self.assertTrue(
            any(value < -1 for value in shell_values),
            "OCC did not retain the BSE basis's pure-spherical high-L shells",
        )


if __name__ == "__main__":
    unittest.main()
