#!/usr/bin/env python3
"""Execute the final-map input writers without launching chemistry programs."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from test_runner_regressions import RUNNERS, function_body


@unittest.skipUnless(os.name == "posix" and shutil.which("bash"), "requires bash")
class FinalResidualInputs(unittest.TestCase):
    def generated_input(self, runner, program, interface, dispersion):
        text = runner.read_text(encoding="utf-8")
        names = ("GET_RESIDUALS", "READ_CRYSTAL_WFN",
                 "CRYSTAL_GRED_IMPORT_SUPPORTED", "CRYSTAL_GRED_TONTO_PROATOM_BASIS",
                 "DISPERSION_COEF", "PREPARE_DISPERSION_COEFFICIENTS")
        definitions = "\n".join(name + "(){\n" + function_body(text, name)
                                for name in names)
        # Stop at the executable boundary, after writing the actual input.
        # No Crystal or Tonto executable and no supplied sample is used.
        stubs = r'''
_lower(){ printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
TONTO_HEADER(){ : > stdin; }
TONTO_FINAL_WAVEFUNCTION_EXPORTS_AVAILABLE(){ return 1; }
DEFINE_JOB_NAME(){ :; }
PROCESS_FINAL_REFINED_CIF(){
    echo 'CIF= { file_name= final.cif }' >> stdin
    if [[ "$SCFCALCPROG" != Crystal14 ]]; then
        echo process_CIF >> stdin
    fi
}
READ_GAUSSIAN_FCHK(){ echo read_g09_fchk_file >> stdin; }
READ_ORCA_FCHK(){ echo read_molden_file >> stdin; }
READ_ELMO_FCHK(){ echo read_g09_fchk_file >> stdin; }
NOT_TONTO_BASIS_SET(){ echo 'basis_name= fixture' >> stdin; }
TONTO_BASIS_SET(){ :; }
CHARGE_MULT(){ :; }
CRYSTAL_BLOCK(){ echo 'crystal= { xray_data= { } }' >> stdin; }
RESIDUAL_DENSITY_GRID(){ :; }
APPEND_SHELXL_RESIDUAL_MAP(){ :; }
WRITE_ANHARMONIC_PDF_OPTIONS(){ :; }
BECKE_GRID(){ echo 'becke_grid= { accuracy= extreme }' >> stdin; }
TONTO_OBSERVED_DENSITY_INPUT(){ return 1; }
fake_tonto(){ return 73; }
JOBNAME=fixture
J=4
TONTO=fake_tonto
NUMPROCTONTO=1
METHOD=rhf
MULTIPLICITY=1
BASISSETDIR=/unused/basis
DISPERSION_COEFFICIENTS='O 0.0106 0.0060 Si 0.0817 0.0704'
SCCHARGES=false
USEBECKE=true
GET_RESIDUALS
status=$?
[[ $status == 1 ]] || exit 72
'''
        with tempfile.TemporaryDirectory(prefix="lamagoet-final-input-") as folder:
            environment = dict(os.environ, SCFCALCPROG=program,
                               LAMAGOET_CRYSTAL_DENSITY_INTERFACE=interface,
                               DISP=dispersion)
            result = subprocess.run(["bash", "-c", definitions + stubs],
                                    cwd=folder, env=environment,
                                    text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("final Tonto residual-density calculation failed", result.stderr)
            self.assertNotIn("command not found", result.stderr)
            return (Path(folder) / "stdin").read_text()

    def test_dispersion_follows_loaded_crystal_atoms(self):
        for runner in RUNNERS:
            for interface in ("gred", "xml"):
                for dispersion in ("yes", "no"):
                    with self.subTest(runner=runner.name, interface=interface, dispersion=dispersion):
                        text = self.generated_input(runner, "Crystal14", interface, dispersion)
                        load = text.index("process_cif_and_c23_" + interface)
                        crystal = text.index("crystal= {")
                        self.assertLess(load, crystal)
                        if dispersion == "yes":
                            self.assertEqual(text.count("dispersion_coefficients="), 1)
                            self.assertLess(load, text.index("dispersion_coefficients="))
                            self.assertLess(text.index("dispersion_coefficients="), crystal)
                        else:
                            self.assertNotIn("dispersion_coefficients=", text)

    def test_molecular_dispersion_still_follows_cif_loading(self):
        for runner in RUNNERS:
            for program in ("Gaussian", "Orca", "OCC", "elmodb", "Tonto"):
                with self.subTest(runner=runner.name, program=program):
                    text = self.generated_input(runner, program, "gred", "yes")
                    self.assertEqual(text.count("dispersion_coefficients="), 1)
                    self.assertLess(text.index("process_CIF"), text.index("dispersion_coefficients="))
                    self.assertLess(text.index("dispersion_coefficients="), text.index("crystal= {"))


if __name__ == "__main__":
    unittest.main()
