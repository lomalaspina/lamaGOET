#!/usr/bin/env python3
"""Execute native/legacy CP2K input contracts without starting a chemistry job."""

from pathlib import Path
import os
import shlex
import shutil
import subprocess
import tempfile
import unittest

from Tests.test_runner_regressions import function_body


ROOT = Path(__file__).resolve().parents[1]
TEXT = (ROOT / "lamaGOET.sh").read_text(encoding="utf-8")


def definitions(*names):
    result = '_lower(){ tr "[:upper:]" "[:lower:]" <<< "$1"; }\n'
    result += '_cp2k_error(){ printf "%s\\n" "$*" >&2; }\n'
    result += '_cp2k_log_detail(){ :; }\n'
    result += '_cp2k_require_file(){ test -s "$1"; }\n'
    return result + "".join(name + "(){\n" + function_body(TEXT, name) for name in names)


@unittest.skipUnless(os.name == "posix" and shutil.which("bash"), "requires bash")
class NativeCP2KInterfaceTest(unittest.TestCase):
    def run_script(self, source, directory):
        return subprocess.run(
            ["bash", "-eu", "-c", source], cwd=directory,
            text=True, capture_output=True,
        )

    def test_native_prints_complete_real_space_p_s_and_fock(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_script(
                definitions("_cp2k_write_input")
                + "METHOD=BLYP\n_cp2k_write_input test.inp job basis 0 1 BLYP subsys ATOMIC\n",
                directory,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            text = (Path(directory) / "test.inp").read_text()
        for kind in ("P", "S", "KS"):
            self.assertIn(f"&{kind}_CSR_WRITE ON", text)
        self.assertEqual(text.count("REAL_SPACE T"), 3)
        self.assertEqual(text.count("THRESHOLD 0.0"), 3)
        self.assertEqual(text.count("UPPER_TRIANGULAR F"), 3)
        self.assertEqual(text.count("COMMON_ITERATION_LEVELS 100"), 3)
        self.assertEqual(text.count("FILENAME ./native"), 3)
        self.assertIn("FULL_GRID TRUE", text)
        self.assertIn("AO_EXPORT_TYPE GTO_BASIS", text)
        self.assertNotIn("FILENAME =native", text)

    def test_xml_print_is_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_script(
                definitions("_cp2k_write_input")
                + "METHOD=BLYP\nCP2K_DENSITY_INTERFACE=xml\n"
                + "_cp2k_write_input test.inp job basis 0 1 BLYP subsys ATOMIC\n",
                directory,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            text = (Path(directory) / "test.inp").read_text()
        self.assertNotIn("_CSR_WRITE", text)
        self.assertIn("&MO_KP ON", text)

    def test_native_is_explicitly_closed_shell_and_invalid_selector_fails(self):
        for interface, multiplicity, method, expected in (
            ("native", 1, "BLYP", 0),
            ("native", 3, "BLYP", 1),
            ("native", 1, "uBLYP", 1),
            ("xml", 3, "uBLYP", 0),
            ("typo", 1, "BLYP", 1),
        ):
            with self.subTest(interface=interface, multiplicity=multiplicity, method=method):
                with tempfile.TemporaryDirectory() as directory:
                    result = self.run_script(
                        definitions("CP2K_VALIDATE_LAMAGOET_MODE")
                        + f"CP2K_DENSITY_INTERFACE={interface}\n"
                        + f"CP2K_CELL_MULTIPLICITY={multiplicity}\nMETHOD={method}\n"
                        + "CP2K_VALIDATE_LAMAGOET_MODE\n", directory,
                    )
                self.assertEqual(result.returncode, expected, result.stderr)

    def prepare_setup(self, directory, interface="native", fock=True):
        directory = Path(directory)
        cycle = directory / "cycle with spaces"
        cycle.mkdir()
        reference = directory / "Thakkar"
        reference.write_text("slater basis\n")
        for name in ("job.mokp", "job.out", "job.xml"):
            (cycle / name).write_text("fixture\n")
        for kind in (("P", "S", "KS") if fock else ("P", "S")):
            (cycle / f"native-{kind}_SPIN_1_R_1.csr").write_text("matrix\n")
        if interface == "xml":
            (cycle / "cp2k-generated").write_text("gaussian basis\n")
        assignments = {
            "CP2K_DENSITY_INTERFACE": interface,
            "CP2K_CSR_PREFIX": str(cycle / "native-"),
            "CP2K_MOKP_FILE": str(cycle / "job.mokp"),
            "CP2K_LAST_OUTPUT": str(cycle / "job.out"),
            "CP2K_TONTO_BASIS_DIR": str(cycle),
            "CP2K_TONTO_BASIS_NAME": "cp2k-native" if interface == "native" else "cp2k-generated",
            "CP2K_TONTO_BASIS_FILE": str(cycle / ("cp2k-native" if interface == "native" else "cp2k-generated")),
            "CP2K_PERIODIC_XML": str(cycle / "job.xml"),
            "CP2K_TONTO_SLATER_BASIS_FILE": str(reference),
        }
        return (
            definitions("_cp2k_require_native_matrices", "CP2K_TONTO_PERIODIC_SETUP")
            + "".join(f"{key}={shlex.quote(value)}\n" for key, value in assignments.items())
        )

    def test_native_setup_does_not_need_xml_or_generated_basis_and_is_repeatable(self):
        with tempfile.TemporaryDirectory() as directory:
            script = self.prepare_setup(directory)
            (Path(directory) / "cycle with spaces" / "job.xml").unlink()
            result = self.run_script(
                script + "CP2K_TONTO_PERIODIC_SETUP\nCP2K_TONTO_PERIODIC_SETUP\n", directory,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            text = (Path(directory) / "stdin").read_text()
            self.assertFalse((Path(directory) / "cycle with spaces" / "cp2k-native").exists())
        self.assertEqual(text.count("process_cif_and_cp2k_native"), 2)
        self.assertIn("cp2k_csr_prefix=", text)
        self.assertIn("cp2k_output_file_name=", text)
        self.assertIn("cp2k_mokp_file_name=", text)
        self.assertNotIn("c23_xml_file_name", text)
        self.assertNotIn("\n   basis_name=", text)

    def test_missing_fock_stops_before_refinement_input(self):
        with tempfile.TemporaryDirectory() as directory:
            script = self.prepare_setup(directory, fock=False)
            result = self.run_script(script + "CP2K_TONTO_PERIODIC_SETUP\n", directory)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((Path(directory) / "stdin").exists())
        self.assertIn("Kohn-Sham/Fock", result.stderr)
        self.assertIn("no XML fallback", result.stderr)

    def test_legacy_setup_still_uses_xml_and_generated_basis(self):
        with tempfile.TemporaryDirectory() as directory:
            script = self.prepare_setup(directory, interface="xml", fock=False)
            result = self.run_script(script + "CP2K_TONTO_PERIODIC_SETUP\n", directory)
            self.assertEqual(result.returncode, 0, result.stderr)
            text = (Path(directory) / "stdin").read_text()
        self.assertIn("basis_name= cp2k-generated", text)
        self.assertIn("process_cif_and_c23_xml", text)
        self.assertNotIn("process_cif_and_cp2k_native", text)

    def test_native_cycle_never_loads_the_xml_bridge_or_requires_a_kp_restart(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            for name in ("basis", "geometry.cif", "cif_converter.py", "job.lst"):
                (directory / name).write_text("fixture\n")
            source = definitions(
                "CP2K_VALIDATE_LAMAGOET_MODE", "_cp2k_write_input",
                "_cp2k_require_native_matrices", "TONTO_TO_CP2K",
            )
            source += """
_cp2k_require_command(){ :; }
_cp2k_resolve_executable(){ printf '/bin/true\n'; }
_cp2k_abspath(){ realpath "$1"; }
_cp2k_geometry_cif(){ printf '%s/geometry.cif\n' "$PWD"; }
_cp2k_functional(){ printf 'BLYP\n'; }
_cp2k_log(){ :; }
python3(){
    [[ "$1" == "$CP2K_CIF_TO_SUBSYS" ]] || return 92
    printf '%s\n' "$1" >> "$PYTHON_CALLS"
}
_cp2k_run(){
    printf 'ENERGY| Total FORCE_EVAL  -56.1\nPROGRAM ENDED AT\n' > "$3"
    printf 'MO_KP fixture\n' > job.mokp
    for kind in P S KS; do
        printf 'CSR fixture\n' > "native-${kind}_SPIN_1_R_1.csr"
    done
}
I=0
METHOD=BLYP
JOBNAME=job
CP2K_DENSITY_INTERFACE=native
CP2K_BASIS_SET_FILE="$PWD/basis"
CP2K_BASIS_SET=all-electron
CP2K_CIF_TO_SUBSYS="$PWD/cif_converter.py"
CP2K_TONTO_BRIDGE="$PWD/absent_bridge.py"
LAMAGOET_SCRIPT_DIR="$PWD"
PYTHON_CALLS="$PWD/python_calls"
TONTO_TO_CP2K
printf '%s\n' "$CP2K_LAST_CYCLE_DIR" "$CP2K_CSR_PREFIX" "$CP2K_MOKP_FILE"
"""
            result = self.run_script(source, directory)
            self.assertEqual(result.returncode, 0, result.stderr)
            cycle = directory / "1.CP2K.cycle.job"
            self.assertIn(str(cycle), result.stdout)
            self.assertIn(str(cycle / "native-"), result.stdout)
            self.assertEqual(
                (directory / "python_calls").read_text().splitlines(),
                [str(directory / "cif_converter.py")],
            )
            self.assertFalse(list(cycle.glob("*.xml")))
            self.assertFalse(list(cycle.glob("*.kp")))
            self.assertFalse((cycle / "cp2k-native").exists())


if __name__ == "__main__":
    unittest.main()
