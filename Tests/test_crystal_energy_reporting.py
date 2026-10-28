#!/usr/bin/env python3
"""SCF reporting must not reuse the previous cycle or change convergence state."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from test_runner_regressions import RUNNERS, function_body

ROOT = Path(__file__).resolve().parent.parent


@unittest.skipUnless(os.name == "posix" and shutil.which("bash"), "requires bash")
class CrystalEnergyReporting(unittest.TestCase):
    def report(self, output):
        with tempfile.TemporaryDirectory(prefix="crystal-energy-") as directory:
            path = Path(directory) / "current scf.out"
            path.write_text(output)
            script = r'''
source "$1"
ENERGIA=old_energy
ENERGIA2=old_energy2
RMSD=old_density
RMSD2=old_density2
DE=old_delta
_lamagoet_report_crystal_energy "$2" 5
[[ "$ENERGIA" == old_energy && "$ENERGIA2" == old_energy2 &&
   "$RMSD" == old_density && "$RMSD2" == old_density2 && "$DE" == old_delta ]]
'''
            result = subprocess.run(["bash", "-c", script, "test",
                                     str(ROOT / "lamagoet_shell_env.sh"), str(path)],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            return result.stdout.strip()

    def test_current_converged_energy_and_delta(self):
        output = """ INFORMATION **** TOLDEE **** SCF TOL ON TOTAL ENERGY SET TO 8
 == SCF ENDED - CONVERGENCE ON ENERGY E(AU) -1.500000E+01 CYCLES 5
 TOTAL ENERGY(DFT)(AU)( 5) -1.500000E+01 DE 1.2E-08 tester 0.0
 == SCF ENDED - CONVERGENCE ON ENERGY E(AU) -1.600000E+01 CYCLES 12
 TOTAL ENERGY(DFT)(AU)( 12) -1.600000E+01 DE 9.5E-10 tester 8.3E-12
"""
        self.assertEqual(self.report(output), "Crystal cycle number 5, final energy is: "
                         "-1.600000E+01 hartree, final SCF delta E is: 9.5E-10 hartree")

    def test_absent_summary_delta_is_not_inherited(self):
        output = """ == SCF ENDED - CONVERGENCE ON ENERGY E(AU) -1.5E+01 CYCLES 5
 TOTAL ENERGY(HF)(AU)( 5) -1.5E+01 DE 1.2E-08
 == SCF ENDED - CONVERGENCE ON ENERGY E(AU) -1.6E+01 CYCLES 6
"""
        self.assertEqual(self.report(output),
                         "Crystal cycle number 5, final energy is: -1.6E+01 hartree")

    def test_missing_convergence_cannot_report_an_old_value(self):
        self.assertEqual(self.report(" TOTAL ENERGY(DFT)(AU)( 3) -1.4E+01 DE 0.3\n"),
                         "WARNING: no converged Crystal23 energy available for cycle 5")

    def test_both_runners_use_reporter_not_previous_energy(self):
        for runner in RUNNERS:
            with self.subTest(runner=runner.name):
                body = function_body(runner.read_text(), "TONTO_TO_CRYSTAL")
                self.assertIn('_lamagoet_report_crystal_energy "$JOBNAME.out" "$I"', body)
                self.assertNotIn('final energy is: $ENERGIA', body)


if __name__ == "__main__":
    unittest.main()
