#!/usr/bin/env python3
"""Static contracts for the two shell runners.

These tests intentionally inspect the generated-input commands rather than
executing chemistry programs.  The full NH3 calculations are a separate
integration suite, but these checks catch the dispatch and omitted-keyword
failures before expensive external programs are started.
"""

from pathlib import Path
import os
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
RUNNERS = (ROOT / "lamaGOET.sh", ROOT / "RUN_lamaGOET_release.sh")


def function_body(text: str, name: str) -> str:
    match = re.search(
        rf"(?ms)^{re.escape(name)}\(\)\s*\{{\n(.*?)(?=^[A-Za-z_][A-Za-z0-9_]*\(\)\s*\{{|\Z)",
        text,
    )
    if not match:
        raise AssertionError(f"runner function {name} was not found")
    return match.group(1)


class RunnerRegressionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.runner_text = {
            path.name: path.read_text(encoding="utf-8") for path in RUNNERS
        }

    def test_tonto_mode_requests_hirshfeld_refinement(self):
        for name, text in self.runner_text.items():
            with self.subTest(runner=name):
                body = function_body(text, "SCF_BLOCK_REST_TONTO")
                self.assertIn('echo "   refine_hirshfeld_atoms" >> stdin', body)
                self.assertIn('dft_exchange_functional= becke88', body)
                self.assertIn('dft_correlation_functional= lyp', body)
                self.assertIn('dft_exchange_functional= pbex', body)
                self.assertIn('dft_correlation_functional= pbec', body)
                self.assertIn('METHOD" == "upbe', body)

    def test_tonto_version_uses_supported_long_option(self):
        for name, text in self.runner_text.items():
            with self.subTest(runner=name):
                self.assertIn(
                    '"$TONTO" --version >> "$JOBNAME.lst"',
                    text,
                )
                self.assertNotRegex(text, r"\$TONTO\s+-v(?:\s|\))")

    def test_external_crystal_basis_never_becomes_tonto_gen_basis(self):
        for name, text in self.runner_text.items():
            with self.subTest(runner=name):
                body = function_body(text, "NOT_TONTO_BASIS_SET")
                self.assertIn("CRYSTAL_TONTO_BASIS_NAME", body)
                self.assertIn("${BASISSETT:-STO-3G}", body)
                self.assertRegex(body, r'""\|gen\|external\)')

    @unittest.skipUnless(
        os.name == "posix" and shutil.which("bash"),
        "generated Crystal23/Tonto basis test requires bash",
    )
    def test_external_crystal_basis_writes_named_tonto_reference(self):
        for runner, text in self.runner_text.items():
            definition = (
                '_lower(){ tr "[:upper:]" "[:lower:]" <<< "$1"; }\n'
                "NOT_TONTO_BASIS_SET(){\n"
                + function_body(text, "NOT_TONTO_BASIS_SET")
            )
            with self.subTest(runner=runner), tempfile.TemporaryDirectory() as directory:
                library = Path(directory) / "basis_sets"
                library.mkdir()
                (library / "def2-TZVP").write_text("basis\n", encoding="utf-8")
                script = (
                    definition
                    + '\nSCFCALCPROG="Crystal14"\n'
                    + 'GAUSGEN="true"\n'
                    + 'BASISSETG="gen"\n'
                    + 'BASISSETT="STO-3G"\n'
                    + 'CRYSTAL_TONTO_BASIS_NAME="def2-TZVP"\n'
                    + f'BASISSETDIR="{library}"\n'
                    + "NOT_TONTO_BASIS_SET\n"
                    + "cat stdin\n"
                )
                result = subprocess.run(
                    ["bash", "-c", script],
                    cwd=directory,
                    text=True,
                    capture_output=True,
                    check=True,
                )
            self.assertIn("basis_name= def2-TZVP", result.stdout)
            self.assertNotIn("basis_name= gen", result.stdout)

    def test_retained_diamond_46_ao_pair_has_one_crystal_terminator(self):
        example = (
            ROOT
            / "examples"
            / "periodic_xcw"
            / "diamond_core_decontracted_46"
        )
        crystal_records = [
            line.split()
            for line in (example / "crystal23_basis.txt").read_text(
                encoding="utf-8"
            ).splitlines()
            if line.strip() and not line.lstrip().startswith(("#", "!"))
        ]
        self.assertEqual(
            sum(record[:2] == ["99", "0"] for record in crystal_records),
            1,
        )
        self.assertEqual(crystal_records[-1][:2], ["99", "0"])
        sidecar = (example / "core-decontracted-carbon").read_text(
            encoding="utf-8"
        )
        self.assertIn("C:core-decontracted-carbon", sidecar)
        self.assertEqual(sidecar.count("1   s"), 8)

    def test_periodic_xcw_input_and_dispatch_are_explicit(self):
        for name, text in self.runner_text.items():
            with self.subTest(runner=name):
                geometry = function_body(text, "PERIODIC_XCW_PREPARE_INPUT_GEOMETRY")
                self.assertIn('echo "   process_CIF"', geometry)
                self.assertIn('echo "   put"', geometry)
                self.assertIn('echo "   write_xtal23_xyz_file"', geometry)
                reference = function_body(
                    text, "PERIODIC_XCW_PREPARE_CRYSTAL_REFERENCE"
                )
                self.assertIn("spacegroup.txt", reference)
                self.assertIn("cry23.bashrc", reference)
                self.assertIn("crystal_utils_dir", reference)
                self.assertIn("command -v runprop23", reference)
                self.assertIn('echo "NEWK"', reference)
                self.assertIn('echo "1 0"', reference)
                self.assertIn('echo "CRYAPI_OUT"', reference)
                self.assertIn("GenerateXML_dat.GRED", reference)
                self.assertIn("GenerateXML_dat.KRED", reference)
                body = function_body(text, "PERIODIC_XCW")
                self.assertRegex(
                    body,
                    r'CIF="\$xcw_cif"\s+PERIODIC_XCW_PREPARE_INPUT_GEOMETRY',
                )
                self.assertIn("c23_GRED_file_name= GenerateXML_dat.GRED", body)
                self.assertIn("process_cif_and_c23_gred", body)
                self.assertIn("periodic_xcw_KRED_file_name= GenerateXML_dat.KRED", body)
                self.assertIn("prepare_periodic_xcw_reference", body)
                self.assertIn("set_periodic_xcw_density", body)
                self.assertLess(
                    body.index("periodic_xcw_density_radius="),
                    body.index("set_periodic_xcw_density"),
                )
                self.assertIn("prepare_periodic_xcw_ks_grid", body)
                self.assertIn("periodic_xcw_restart=", body)
                self.assertIn("periodic_xcw_write_checkpoint=", body)
                self.assertIn("neutral, closed-shell Crystal23 reference", body)
                self.assertIn("GenerateXML_dat.GRED.gz", body)
                self.assertIn("GenerateXML_dat.KRED.gz", body)
                dispatch = function_body(text, "RUN_XWR")
                self.assertIn('${XCW_MODE:-molecular}', dispatch)
                self.assertIn("PERIODIC_XCW", dispatch)
                self.assertIn("XCW", dispatch)

    def test_crystal_har_uses_compact_gred_and_cp2k_keeps_legacy_xml(self):
        for name, text in self.runner_text.items():
            with self.subTest(runner=name):
                support = function_body(text, "CRYSTAL_GRED_IMPORT_SUPPORTED")
                self.assertIn("LAMAGOET_CRYSTAL_DENSITY_INTERFACE", support)
                self.assertIn('MULTIPLICITY:-1', support)
                self.assertIn("uhf|uks|ublyp", support)
                crystal = function_body(text, "READ_CRYSTAL_WFN")
                self.assertIn("if CRYSTAL_GRED_IMPORT_SUPPORTED", crystal)
                self.assertIn("c23_GRED_file_name= GenerateXML_dat.GRED", crystal)
                self.assertIn("process_cif_and_c23_gred", crystal)
                self.assertIn("c23_XML_file_name= GenerateXML.XML", crystal)
                self.assertIn("process_cif_and_c23_xml", crystal)
                if "CP2K_TONTO_PERIODIC_SETUP()" in text:
                    cp2k = function_body(text, "CP2K_TONTO_PERIODIC_SETUP")
                    self.assertIn("CP2K_DENSITY_INTERFACE", cp2k)
                    self.assertIn("process_cif_and_cp2k_native", cp2k)
                    self.assertIn("c23_xml_file_name= $CP2K_PERIODIC_XML", cp2k)
                    self.assertIn("process_cif_and_c23_xml", cp2k)
                retention = function_body(text, "CRYSTAL_XML_RETENTION_ENABLED")
                self.assertIn("LAMAGOET_KEEP_CRYSTAL_XML", retention)
                self.assertIn("! CRYSTAL_GRED_IMPORT_SUPPORTED", retention)

    @unittest.skipUnless(
        os.name == "posix" and shutil.which("bash"),
        "generated Crystal23 interface-selection test requires bash",
    )
    def test_crystal_har_interface_falls_back_to_xml_for_unsupported_cases(self):
        cases = (
            ({"METHOD": "BLYP", "MULTIPLICITY": "1"}, "GRED"),
            ({"METHOD": "UHF", "MULTIPLICITY": "1"}, "XML"),
            ({"METHOD": "BLYP", "MULTIPLICITY": "3"}, "XML"),
            (
                {
                    "METHOD": "BLYP",
                    "MULTIPLICITY": "1",
                    "LAMAGOET_CRYSTAL_DENSITY_INTERFACE": "xml",
                },
                "XML",
            ),
        )
        for runner, text in self.runner_text.items():
            definitions = (
                '_lower(){ tr "[:upper:]" "[:lower:]" <<< "$1"; }\n'
                "CRYSTAL_GRED_IMPORT_SUPPORTED(){\n"
                + function_body(text, "CRYSTAL_GRED_IMPORT_SUPPORTED")
                + "READ_CRYSTAL_WFN(){\n"
                + function_body(text, "READ_CRYSTAL_WFN")
            )
            for environment, expected in cases:
                with self.subTest(runner=runner, environment=environment):
                    with tempfile.TemporaryDirectory() as directory:
                        assignments = "".join(
                            f"{key}={value!r}\n" for key, value in environment.items()
                        )
                        script = (
                            definitions
                            + assignments
                            + "JOBNAME=test_job\n"
                            + "READ_CRYSTAL_WFN\n"
                            + "cat stdin\n"
                        )
                        result = subprocess.run(
                            ["bash", "-c", script],
                            cwd=directory,
                            text=True,
                            capture_output=True,
                            check=True,
                        )
                    self.assertIn(f"process_cif_and_c23_{expected.lower()}", result.stdout)
                    other = "XML" if expected == "GRED" else "GRED"
                    self.assertNotIn(
                        f"process_cif_and_c23_{other.lower()}", result.stdout
                    )

    @unittest.skipUnless(
        os.name == "posix" and shutil.which("bash"),
        "generated periodic-XCW input test requires bash",
    )
    def test_periodic_xcw_grid_has_validated_extreme_minimum(self):
        for runner, text in self.runner_text.items():
            definition = (
                "_lower(){ tr '[:upper:]' '[:lower:]' <<< \"$1\"; }\n"
                "PERIODIC_XCW_BECKE_GRID(){\n"
                + function_body(text, "PERIODIC_XCW_BECKE_GRID")
            )
            for requested, expected in (
                ("low", "extreme"),
                ("extreme", "extreme"),
                ("best", "best"),
            ):
                with self.subTest(
                    runner=runner, requested=requested
                ), tempfile.TemporaryDirectory() as directory:
                    script = (
                        definition
                        + f'\nACCURACY="{requested}"\n'
                        + 'JOBNAME="grid-test"\n'
                        + "PERIODIC_XCW_BECKE_GRID\n"
                        + "cat stdin\n"
                    )
                    result = subprocess.run(
                        ["bash", "-c", script],
                        cwd=directory,
                        text=True,
                        capture_output=True,
                        check=True,
                    )
                self.assertIn(f"accuracy= {expected}", result.stdout)
                self.assertIn("basis_function_cutoff= 1.0e-16", result.stdout)
                if requested == "low":
                    self.assertIn("promotes Becke accuracy", result.stderr)

    @unittest.skipUnless(
        os.name == "posix" and shutil.which("bash"),
        "generated periodic-XCW custom-basis test requires bash",
    )
    def test_periodic_xcw_custom_basis_pair_is_exact_and_additive(self):
        for runner, text in self.runner_text.items():
            definition = (
                "PERIODIC_XCW_PREPARE_CUSTOM_BASIS(){\n"
                + function_body(text, "PERIODIC_XCW_PREPARE_CUSTOM_BASIS")
                + "\nPERIODIC_XCW_WRITE_TONTO_BASIS(){\n"
                + function_body(text, "PERIODIC_XCW_WRITE_TONTO_BASIS")
            )
            with self.subTest(runner=runner), tempfile.TemporaryDirectory() as directory:
                work = Path(directory)
                library = work / "library"
                library.mkdir()
                (library / "Thakkar").write_text("atomic references\n")
                crystal = work / "crystal-basis.txt"
                crystal.write_text(
                    "6 2\n0 0 1 2.0 1.0\n1.0 1.0\n99 0\n",
                    encoding="utf-8",
                )
                sidecar = work / "core-decontracted-carbon"
                sidecar.write_text("exact Tonto sidecar\n", encoding="utf-8")
                script = (
                    definition
                    + f'\nBASISSETDIR="{library}"\n'
                    + f'PERIODIC_XCW_CRYSTAL_BASIS_FILE="{crystal}"\n'
                    + f'PERIODIC_XCW_TONTO_BASIS_FILE="{sidecar}"\n'
                    + 'PERIODIC_XCW_TONTO_BASIS_NAME="core-decontracted-carbon"\n'
                    + 'JOBNAME="paired"\n'
                    + "PERIODIC_XCW_PREPARE_CUSTOM_BASIS\n"
                    + "PERIODIC_XCW_WRITE_TONTO_BASIS\n"
                    + "cat stdin\n"
                    + 'test -s "periodic_xcw_basis_sets.paired/Thakkar"\n'
                    + 'test -s "periodic_xcw_basis_sets.paired/core-decontracted-carbon"\n'
                )
                result = subprocess.run(
                    ["bash", "-c", script],
                    cwd=directory,
                    text=True,
                    capture_output=True,
                    check=True,
                )
                generated = (work / "stdin").read_text(encoding="utf-8")
                self.assertIn("basis_name= core-decontracted-carbon", generated)
                self.assertIn("periodic_xcw_basis_sets.paired", generated)
                self.assertIn("custom basis pair", result.stdout)

    @unittest.skipUnless(
        os.name == "posix" and shutil.which("bash"),
        "generated periodic-XCW custom-basis test requires bash",
    )
    def test_periodic_xcw_rejects_nonfinal_or_repeated_crystal_terminator(self):
        for runner, text in self.runner_text.items():
            definition = (
                "PERIODIC_XCW_PREPARE_CUSTOM_BASIS(){\n"
                + function_body(text, "PERIODIC_XCW_PREPARE_CUSTOM_BASIS")
            )
            for contents in (
                "6 1\n99 0\nEND\n",
                "6 1\n99 0\n7 1\n99 0\n",
            ):
                with self.subTest(runner=runner), tempfile.TemporaryDirectory() as directory:
                    work = Path(directory)
                    library = work / "library"
                    library.mkdir()
                    crystal = work / "bad-crystal-basis.txt"
                    crystal.write_text(contents, encoding="utf-8")
                    sidecar = work / "basis-sidecar"
                    sidecar.write_text("sidecar\n", encoding="utf-8")
                    script = (
                        definition
                        + f'\nBASISSETDIR="{library}"\n'
                        + f'PERIODIC_XCW_CRYSTAL_BASIS_FILE="{crystal}"\n'
                        + f'PERIODIC_XCW_TONTO_BASIS_FILE="{sidecar}"\n'
                        + 'PERIODIC_XCW_TONTO_BASIS_NAME="basis-sidecar"\n'
                        + 'JOBNAME="bad"\n'
                        + "PERIODIC_XCW_PREPARE_CUSTOM_BASIS\n"
                    )
                    result = subprocess.run(
                        ["bash", "-c", script],
                        cwd=directory,
                        text=True,
                        capture_output=True,
                        check=False,
                    )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("exactly one final '99 0'", result.stderr)

    def test_cp2k_xwr_enters_periodic_xcw_only(self):
        text = self.runner_text["lamaGOET.sh"]
        validation = function_body(text, "CP2K_VALIDATE_LAMAGOET_MODE")
        self.assertNotIn("PLOT_TONTO XWR", validation)
        self.assertIn("CP2K XWR requires XCW_MODE=periodic", validation)
        cp2k_har = function_body(text, "CP2K_RUN_HAR")
        self.assertIn("Periodic CP2K HAR finished", cp2k_har)
        self.assertIn("RUN_XWR || return 1", cp2k_har)

    def test_extinction_selection_reaches_iam_and_har_inputs(self):
        for name, text in self.runner_text.items():
            with self.subTest(runner=name, block="IAM"):
                iam = function_body(text, "TONTO_IAM_BLOCK")
                self.assertIn("WRITE_EXTINCTION_OPTIONS", iam)
                self.assertNotIn("optimise_extinction= false", iam)
            with self.subTest(runner=name, block="HAR"):
                har = function_body(text, "CRYSTAL_BLOCK")
                self.assertIn("WRITE_EXTINCTION_OPTIONS", har)
                self.assertNotIn("optimise_extinction= false", har)
            with self.subTest(runner=name, block="model options"):
                options = function_body(text, "WRITE_EXTINCTION_OPTIONS")
                self.assertIn('refine_extinction= ${EXTI:-no}', options)
                self.assertIn(
                    'extinction_model= ${EXTINCTION_MODEL:-zachariasen}',
                    options,
                )
                self.assertIn(
                    'extinction_type= ${EXTINCTION_TYPE:-type-1}', options
                )
                self.assertIn(
                    "extinction_distribution= "
                    "${EXTINCTION_DISTRIBUTION:-gaussian}",
                    options,
                )
                self.assertIn(
                    "extinction_anisotropic= "
                    "${EXTINCTION_ANISOTROPIC:-false}",
                    options,
                )
                self.assertIn(
                    "extinction_mean_path_mm= "
                    "${EXTINCTION_MEAN_PATH_MM:-0.3}",
                    options,
                )

    @unittest.skipUnless(
        os.name == "posix" and shutil.which("bash"),
        "generated extinction input test requires bash",
    )
    def test_generated_extinction_model_options(self):
        for runner, text in self.runner_text.items():
            definition = (
                "WRITE_EXTINCTION_OPTIONS(){\n"
                + function_body(text, "WRITE_EXTINCTION_OPTIONS")
            )
            with self.subTest(runner=runner), tempfile.TemporaryDirectory() as directory:
                script = (
                    definition
                    + '\nEXTI="yes"\n'
                    + 'EXTINCTION_MODEL="becker-coppens"\n'
                    + 'EXTINCTION_TYPE="mixed"\n'
                    + 'EXTINCTION_DISTRIBUTION="lorentzian"\n'
                    + 'EXTINCTION_ANISOTROPIC="true"\n'
                    + 'EXTINCTION_MEAN_PATH_MM="0.425"\n'
                    + "WRITE_EXTINCTION_OPTIONS\ncat stdin\n"
                )
                result = subprocess.run(
                    ["bash", "-c", script],
                    cwd=directory,
                    text=True,
                    capture_output=True,
                    check=True,
                )
            generated = result.stdout
            self.assertIn("refine_extinction= yes", generated)
            self.assertIn("extinction_model= becker-coppens", generated)
            self.assertIn("extinction_type= mixed", generated)
            self.assertIn("extinction_distribution= lorentzian", generated)
            self.assertIn("extinction_anisotropic= true", generated)
            self.assertIn("extinction_mean_path_mm= 0.425", generated)

    def test_crystal_partition_selection_was_not_replaced_by_scf_input(self):
        for name, text in self.runner_text.items():
            with self.subTest(runner=name):
                body = function_body(text, "CRYSTAL_BLOCK")
                self.assertIn("WRITE_DENSITY_PARTITION_MODEL", body)
                self.assertIn("partition_model= oc-hirshfeld", body)
                partition = function_body(
                    text, "WRITE_DENSITY_PARTITION_MODEL"
                )
                self.assertNotIn("dft_exchange_functional", partition)
                self.assertIn(
                    'stockholder_model= ${STOCKHOLDER_MODEL:-cluster}',
                    partition,
                )

    def test_observed_density_controls_are_tonto_only(self):
        for name, text in self.runner_text.items():
            with self.subTest(runner=name):
                body = function_body(text, "WRITE_DENSITY_PARTITION_MODEL")
                periodic_guard = body.index(
                    'if [[ "$SCFCALCPROG" != "Tonto" ]]'
                )
                periodic_return = body.index("return 0", periodic_guard)
                observed = body.index("partition_model= oc-observed")
                self.assertLess(periodic_return, observed)
                self.assertIn("partition_model= oc-crystal23", body)
                self.assertIn("partition_model= oc-hirshfeld", body)
                self.assertIn("partition_model= oc-observed", body)
                self.assertIn(
                    "observed_density_shrinkage= "
                    "${OBSERVED_DENSITY_SHRINKAGE:-0.5}",
                    body,
                )
                self.assertIn(
                    "observed_density_min_TF= ${OBSERVED_DENSITY_MIN_TF:-0.1}",
                    body,
                )
                self.assertIn(
                    "observed_zero_phase_sign= ${OBSERVED_ZERO_PHASE_SIGN:-0}",
                    body,
                )
                self.assertIn(
                    "observed_density_reconstruct= "
                    "${OBSERVED_DENSITY_RECONSTRUCTION:-constrained}",
                    body,
                )
                self.assertIn(
                    "observed_density_motion_model= "
                    "${OBSERVED_DENSITY_MOTION_MODEL:-static}",
                    body,
                )
                self.assertIn(
                    "observed_density_prior= "
                    "${OBSERVED_DENSITY_PRIOR_STRENGTH:-0.0}",
                    body,
                )
                self.assertIn(
                    "observed_density_smoothness= "
                    "${OBSERVED_DENSITY_SMOOTHNESS:-0.01}",
                    body,
                )
                self.assertIn(
                    "observed_density_step= "
                    "${OBSERVED_DENSITY_STEP_SIZE:-0.25}",
                    body,
                )
                self.assertIn(
                    "observed_density_max_iter= "
                    "${OBSERVED_DENSITY_MAX_ITERATIONS:-12}",
                    body,
                )
                crystal = function_body(text, "CRYSTAL_BLOCK")
                self.assertIn(
                    "r_free_percentage= "
                    "${OBSERVED_DENSITY_R_FREE_PERCENTAGE:-10}",
                    crystal,
                )
                self.assertRegex(
                    crystal,
                    r'if \[\[[^\n]*SCFCALCPROG[^\n]*"Tonto"[^\n]*\]\]; then\s+'
                    r'WRITE_DENSITY_PARTITION_MODEL',
                )

    def test_observed_density_uses_atomic_references_without_molecular_scf(self):
        for name, text in self.runner_text.items():
            with self.subTest(runner=name):
                observed = function_body(text, "SCF_BLOCK_OBSERVED_TONTO")
                self.assertIn("BECKE_GRID", observed)
                self.assertIn('echo "   scfdata= {" >> stdin', observed)
                self.assertIn(
                    'echo "   refine_hirshfeld_atoms" >> stdin',
                    observed,
                )
                self.assertNotIn('echo "   scf" >> stdin', observed)

                dispatcher = function_body(text, "SCF_TO_TONTO")
                self.assertIn(
                    "if TONTO_OBSERVED_DENSITY_INPUT; then",
                    dispatcher,
                )
                self.assertGreaterEqual(
                    dispatcher.count("if ! TONTO_IAM_ONLY_INPUT; then"),
                    2,
                )

    @unittest.skipUnless(
        os.name == "posix" and shutil.which("bash"),
        "generated observed-density input test requires bash",
    )
    def test_generated_observed_density_reference_block_has_no_scf_command(self):
        for runner, text in self.runner_text.items():
            with self.subTest(runner=runner), tempfile.TemporaryDirectory() as directory:
                definition = (
                    "BECKE_GRID(){\n"
                    + function_body(text, "BECKE_GRID")
                    + "\nSCF_BLOCK_OBSERVED_TONTO(){\n"
                    + function_body(text, "SCF_BLOCK_OBSERVED_TONTO")
                )
                script = (
                    definition
                    + '\nACCURACY="extreme"\n'
                    + 'BECKEPRUNINGSCHEME="none"\n'
                    + 'LINEDEP=""\n'
                    + 'XCWONLY="false"\n'
                    + 'PLOT_TONTO="false"\n'
                    + 'POWDER_HAR="false"\n'
                    + "SCF_BLOCK_OBSERVED_TONTO\n"
                    + "cat stdin\n"
                )
                result = subprocess.run(
                    ["bash", "-c", script],
                    cwd=directory,
                    text=True,
                    capture_output=True,
                    check=True,
                )
                generated = result.stdout
                self.assertIn("accuracy= extreme", generated)
                self.assertEqual(generated.count("scfdata="), 1)
                self.assertIn("refine_hirshfeld_atoms", generated)
                self.assertNotIn(
                    "scf",
                    [line.strip() for line in generated.splitlines()],
                )

    @unittest.skipUnless(
        os.name == "posix" and shutil.which("bash"),
        "generated partition input test requires bash",
    )
    def test_generated_partition_input_respects_scf_program(self):
        cases = (
            ("Tonto", "oc-observed", "partition_model= oc-observed"),
            ("Tonto", "oc-crystal23", "partition_model= oc-hirshfeld"),
            ("Crystal14", "oc-observed", "partition_model= oc-crystal23"),
            ("CP2K", "oc-observed", "partition_model= oc-crystal23"),
        )
        for runner, text in self.runner_text.items():
            definition = (
                "WRITE_DENSITY_PARTITION_MODEL(){\n"
                + function_body(text, "WRITE_DENSITY_PARTITION_MODEL")
            )
            for program, selected, expected in cases:
                with self.subTest(
                    runner=runner, program=program, partition_model=selected
                ), tempfile.TemporaryDirectory() as directory:
                    script = (
                        definition
                        + f'\nSCFCALCPROG="{program}"\n'
                        + f'PARTITION_MODEL="{selected}"\n'
                        + 'STOCKHOLDER_MODEL="periodic"\n'
                        + 'OBSERVED_DENSITY_RECONSTRUCTION="legacy"\n'
                        + 'OUTPUT_HIRSHFELD_ATOM_CUBES="true"\n'
                        + 'HIRSHFELD_ATOM_CUBE_LABEL="N1"\n'
                        + 'OBSERVED_DENSITY_SHRINKAGE="0.35"\n'
                        + 'OBSERVED_DENSITY_MIN_TF="0.025"\n'
                        + 'OBSERVED_ZERO_PHASE_SIGN="-1"\n'
                        + "WRITE_DENSITY_PARTITION_MODEL\n"
                        + "cat stdin\n"
                    )
                    result = subprocess.run(
                        ["bash", "-c", script],
                        cwd=directory,
                        text=True,
                        capture_output=True,
                        check=True,
                    )
                self.assertIn(expected, result.stdout)
                self.assertIn(
                    "output_Hirshfeld_atom_cubes= true", result.stdout
                )
                self.assertIn(
                    "Hirshfeld_atom_cube_label= N1", result.stdout
                )
                if program == "Tonto" and selected == "oc-observed":
                    self.assertIn("observed_density_shrinkage= 0.35", result.stdout)
                    self.assertIn(
                        "observed_density_motion_model= static", result.stdout
                    )
                    self.assertIn("stockholder_model= periodic", result.stdout)
                    self.assertNotIn("partition_model= oc-crystal23", result.stdout)
                elif program != "Tonto":
                    self.assertIn("stockholder_model= periodic", result.stdout)
                    self.assertNotIn("partition_model= oc-observed", result.stdout)
                    self.assertNotIn("observed_density_shrinkage", result.stdout)

    @unittest.skipUnless(
        os.name == "posix" and shutil.which("bash"),
        "generated observed-density validation test requires bash",
    )
    def test_dynamic_observed_density_runner_validation(self):
        valid = {
            "SCFCALCPROG": "Tonto",
            "PARTITION_MODEL": "oc-observed",
            "OBSERVED_DENSITY_RECONSTRUCTION": "constrained",
            "OBSERVED_DENSITY_MOTION_MODEL": "dynamic",
            "POSADP": "false",
            "POSONLY": "true",
            "ADPSONLY": "false",
            "REFHPOS": "false",
            "REFUISO": "false",
            "REFHADP": "false",
            "HADP": "no",
            "REFANHARM": "false",
            "THIRDORD": "false",
            "FOURTHORD": "false",
        }
        invalid_overrides = (
            {"OBSERVED_DENSITY_MOTION_MODEL": "unknown"},
            {"SCFCALCPROG": "Gaussian"},
            {"PARTITION_MODEL": "oc-hirshfeld"},
            {"OBSERVED_DENSITY_RECONSTRUCTION": "legacy"},
            {"POSONLY": "false"},
            {"POSADP": "true"},
            {"ADPSONLY": "true"},
            {"REFHPOS": "true"},
            {"REFUISO": "true"},
            {"REFHADP": "true"},
            {"HADP": "yes"},
            {"REFANHARM": "true"},
            {"THIRDORD": "true"},
            {"FOURTHORD": "true"},
        )
        for runner, text in self.runner_text.items():
            definition = (
                "TONTO_OBSERVED_DENSITY_INPUT(){\n"
                + function_body(text, "TONTO_OBSERVED_DENSITY_INPUT")
                + "\nVALIDATE_OBSERVED_DENSITY_MOTION_MODEL(){\n"
                + function_body(text, "VALIDATE_OBSERVED_DENSITY_MOTION_MODEL")
            )

            def run_validation(values):
                assignments = "\n".join(
                    f'{name}="{value}"' for name, value in values.items()
                )
                return subprocess.run(
                    [
                        "bash",
                        "-c",
                        definition
                        + "\n"
                        + assignments
                        + "\nVALIDATE_OBSERVED_DENSITY_MOTION_MODEL\n",
                    ],
                    text=True,
                    capture_output=True,
                )

            with self.subTest(runner=runner, case="valid dynamic"):
                self.assertEqual(run_validation(valid).returncode, 0)
            with self.subTest(runner=runner, case="default static"):
                static = dict(valid)
                static.pop("OBSERVED_DENSITY_MOTION_MODEL")
                static["POSONLY"] = "false"
                static["POSADP"] = "true"
                static["REFHPOS"] = "true"
                static["REFHADP"] = "true"
                static["HADP"] = "yes"
                self.assertEqual(run_validation(static).returncode, 0)
            for override in invalid_overrides:
                case = dict(valid)
                case.update(override)
                with self.subTest(runner=runner, invalid=override):
                    self.assertNotEqual(run_validation(case).returncode, 0)

    def test_orca_inputs_request_the_selected_processor_count(self):
        for name, text in self.runner_text.items():
            with self.subTest(runner=name):
                self.assertGreaterEqual(text.count("%pal nprocs $NUMPROC end"), 2)

    def test_final_residual_function_does_not_write_unrefined_cif_statistics(self):
        for name, text in self.runner_text.items():
            with self.subTest(runner=name):
                body = function_body(text, "GET_RESIDUALS")
                self.assertNotIn('echo "   put_cif"', body)
                self.assertIn("put_minmax_residual_density", body)

    def test_known_option_name_mismatches_are_absent(self):
        for name, text in self.runner_text.items():
            with self.subTest(runner=name):
                active = "\n".join(
                    line for line in text.splitlines() if not line.lstrip().startswith("#")
                )
                self.assertNotRegex(active, r"\$USE_NOSPHERA2\b")
                self.assertNotRegex(active, r"\$POWDERHAR\b")
                self.assertNotIn('[[ "POWDER_HAR"', active)
                self.assertNotIn('$SCFCALCPROG" == "ORCA"', active)

    def test_cp2k_rebuilds_atom_mapping_before_every_fit(self):
        text = self.runner_text["lamaGOET.sh"]
        body = function_body(text, "SCF_TO_TONTO")
        start = body.index("periodic Hirshfeld fit")
        cp2k = body[start : start + 1200]
        self.assertLess(cp2k.index("phar_defragment"), cp2k.index("ha_fit"))
        self.assertIn("CP2K_ASSERT_TONTO_FIT", text)

    def test_cluster_cp2k_dispatches_to_monolithic_runner(self):
        text = self.runner_text["RUN_lamaGOET_release.sh"]
        self.assertIn('if [[ "${SCFCALCPROG:-}" == "CP2K" ]]', text)
        self.assertIn('exec bash "$LAMAGOET_MONOLITHIC" --run-job-options', text)



    def test_cycle_report_is_enabled_for_each_external_backend(self):
        programs = ("Gaussian", "Orca", "OCC", "Crystal14", "elmodb")
        for runner, text in self.runner_text.items():
            report = function_body(text, "REPORT_TONTO_HAR_CYCLE")
            cycle = function_body(text, "SCF_TO_TONTO")
            self.assertIn("REPORT_TONTO_HAR_CYCLE", cycle)
            definition = "REPORT_TONTO_HAR_CYCLE(){\n" + report
            for program in programs:
                with self.subTest(runner=runner, program=program):
                    script = (
                        definition
                        + f'\nSCFCALCPROG="{program}"\n'
                        + 'J=3\nMAXSHIFT=0.027620\n'
                        + "REPORT_TONTO_HAR_CYCLE\n"
                    )
                    result = subprocess.run(
                        ["bash", "-c", script],
                        text=True,
                        capture_output=True,
                        check=True,
                    )
                    self.assertEqual(
                        result.stdout,
                        "Tonto HAR cycle 3 complete: "
                        "maximum shift/esd = 0.027620\n",
                    )
            for program in ("CP2K", "Tonto"):
                with self.subTest(runner=runner, program=program):
                    script = (
                        definition
                        + f'\nSCFCALCPROG="{program}"\n'
                        + 'J=3\nMAXSHIFT=0.027620\n'
                        + "REPORT_TONTO_HAR_CYCLE\n"
                    )
                    result = subprocess.run(
                        ["bash", "-c", script],
                        text=True,
                        capture_output=True,
                        check=True,
                    )
                    self.assertEqual(result.stdout, "")

    def test_fit_table_summary_handles_signed_legacy_and_current_tables(self):
        cases = (
            (
                "legacy",
                "     1     1.800000  0.010000  0.020000   -3.200000   -0.040000   H1 pz      13       6\n"
                "     2     1.100000  0.009000  0.018000    0.100000    0.002000    N Uxx     13       6\n"
                "Rigid-atom fit results\n",
                ("2", "1.100000", "1.100000", "0.009000", "0.018000", "3.2", "H1", "pz", "13", "6"),
            ),
            (
                "current",
                "  4  2  1.500000  1.100000  0.009000  0.018000  -4.200000  -0.050000  H1 Uzz  13  6\n"
                "Structure refinement results\n",
                ("2", "1.500000", "1.100000", "0.009000", "0.018000", "4.2", "H1", "Uzz", "13", "6"),
            ),
        )
        for runner, text in self.runner_text.items():
            definition = "FIT_TABLE_SUMMARY(){\n" + function_body(
                text, "FIT_TABLE_SUMMARY"
            )
            for layout, sample, expected in cases:
                with self.subTest(runner=runner, layout=layout), tempfile.TemporaryDirectory() as directory:
                    Path(directory, "stdout").write_text(sample, encoding="utf-8")
                    result = subprocess.run(
                        ["bash", "-c", definition + "\nFIT_TABLE_SUMMARY\n"],
                        cwd=directory,
                        text=True,
                        capture_output=True,
                        check=True,
                    )
                    self.assertEqual(tuple(result.stdout.rstrip("\n").split("\t")), expected)

    def test_cp2k_output_is_routed_to_terminal_and_lst_as_requested(self):
        text = self.runner_text["lamaGOET.sh"]
        prepare = function_body(text, "TONTO_TO_CP2K")
        capture_row = function_body(text, "CP2K_CAPTURE_FIT_ROW")
        fit_row = function_body(text, "CP2K_WRITE_FIT_ROW")
        residuals = function_body(text, "CP2K_FINAL_RESIDUALS")
        run = function_body(text, "CP2K_RUN_HAR")

        self.assertIn(
            '_cp2k_log_detail "Preparing periodic geometry for CP2K cycle number',
            prepare,
        )
        self.assertIn(
            '_cp2k_log_detail "Captured Tonto fit cycle',
            capture_row,
        )
        self.assertIn(
            '_cp2k_log_detail "Recorded Tonto fit cycle',
            fit_row,
        )
        self.assertNotIn("# CP2K rows:", fit_row)
        self.assertNotIn("tee -a", residuals)
        self.assertIn('stdout >> "${JOBNAME}.lst"', residuals)

        starting = function_body(text, "CP2K_APPEND_STARTING_GEOMETRY")
        final = function_body(text, "CP2K_APPEND_FINAL_GEOMETRY")
        self.assertIn("Starting Geometry", starting)
        self.assertIn("Final Geometry", final)
        self.assertIn("Rigid-atom fit results", final)
        self.assertIn("Structure refinement results", final)
        self.assertLess(
            run.index("CP2K_APPEND_STARTING_GEOMETRY"),
            run.index("SCF_TO_TONTO"),
        )
        self.assertLess(
            run.index("CP2K_APPEND_FINAL_GEOMETRY"),
            run.index("CP2K_FINAL_RESIDUALS"),
        )
        self.assertLess(
            run.index("CP2K_CAPTURE_FIT_ROW"),
            run.index("CP2K_WRITE_FIT_ROW"),
        )
        self.assertGreaterEqual(run.count('CP2K_WRITE_FIT_ROW "$I"'), 2)

    def test_cp2k_fit_row_uses_the_following_final_geometry_energy(self):
        text = self.runner_text["lamaGOET.sh"]
        definitions = (
            "CP2K_CAPTURE_FIT_ROW(){\n"
            + function_body(text, "CP2K_CAPTURE_FIT_ROW")
            + "CP2K_WRITE_FIT_ROW(){\n"
            + function_body(text, "CP2K_WRITE_FIT_ROW")
        )
        sample = (
            "Begin rigid-atom fit\n"
            "     1     1.800000  0.010000  0.020000   -3.200000   -0.040000   H1 pz      13       6\n"
            "     2     1.100000  0.009000  0.018000    0.100000    0.002000    N Uxx     13       6\n"
            "Rigid-atom fit results\n"
        )
        with tempfile.TemporaryDirectory() as directory:
            Path(directory, "stdout").write_text(sample, encoding="utf-8")
            script = definitions + r'''
_cp2k_log_detail() { :; }
_cp2k_error() { printf '%s\n' "$*" >&2; }
JOBNAME=job
J=4
I=8
CP2K_CAPTURE_FIT_ROW "$I"
[[ ! -e job.lst ]]
I=9
CP2K_LAST_ENERGY=-10.250000000000
CP2K_LAST_RMSD=0.0000001
DE=-0.125000000000
CP2K_WRITE_FIT_ROW "$I"
[[ "$CP2K_FIT_ROW_PENDING" == false ]]
cat job.lst
'''
            result = subprocess.run(
                ["bash", "-c", script],
                cwd=directory,
                text=True,
                capture_output=True,
                check=True,
            )
        fields = result.stdout.split()
        self.assertEqual(fields[0], "4")
        self.assertEqual(fields[11], "-10.250000000000")
        self.assertEqual(fields[13], "-0.125000000000")


class IamResultsInSummaryTest(unittest.TestCase):
    """The IAM refinement must reach <job>.lst, not just stdout.

    Tonto heads the starting refinement "IAM refinement" and the Hirshfeld
    atom refinement "Structure refinement results".  Only the latter used to
    be copied into the summary, so a job started from a Tonto IAM lost the
    very numbers it was started for.
    """

    def test_both_runners_append_the_iam_block(self):
        for runner in RUNNERS:
            text = Path(runner).read_text(encoding="utf-8")
            with self.subTest(runner=runner):
                self.assertIn(
                    "APPEND_IAM_RESULTS(){",
                    text,
                    f"{runner} does not define APPEND_IAM_RESULTS",
                )
                self.assertIn(
                    "'^IAM refinement'",
                    text,
                    f"{runner} does not look for Tonto's IAM refinement heading",
                )
                # Defined once, called before every Final Geometry block.
                self.assertGreaterEqual(
                    text.count("APPEND_IAM_RESULTS\n"),
                    2,
                    f"{runner} defines APPEND_IAM_RESULTS but never calls it",
                )

    def test_summary_blocks_do_not_use_unguarded_heading_extraction(self):
        """Result-block extraction must not fall back to the whole stdout.

        Supported Tonto versions use either "Rigid-atom fit results" or
        "Structure refinement results". An unguarded extraction keyed to the
        other layout can copy the whole stdout into the summary instead of one
        result block.
        """
        for runner in RUNNERS:
            text = Path(runner).read_text(encoding="utf-8")
            live = [
                line
                for line in text.splitlines()
                if "/^Rigid-atom fit results/{b=NR}/^Wall-clock" in line
                and not line.lstrip().startswith("#")
            ]
            with self.subTest(runner=runner):
                self.assertEqual(
                    live,
                    [],
                    f"{runner} extracts a result block on a heading Tonto no "
                    f"longer writes: {live[:1]}",
                )


class FinalWavefunctionExportTest(unittest.TestCase):
    """Final orbital files must be requested only from canonical MO models."""

    def test_both_runners_request_and_validate_all_three_exports(self):
        for runner in RUNNERS:
            text = runner.read_text(encoding="utf-8")
            with self.subTest(runner=runner.name):
                append = function_body(text, "APPEND_FINAL_WAVEFUNCTION_EXPORTS")
                self.assertIn("put_nbo_file_47", append)
                self.assertIn("write_aim2000_wfn_file", append)
                self.assertIn("write_full_wfx_file", append)

                residuals = function_body(text, "GET_RESIDUALS")
                self.assertIn("TONTO_FINAL_WAVEFUNCTION_EXPORTS_AVAILABLE", residuals)
                self.assertIn("APPEND_FINAL_WAVEFUNCTION_EXPORTS", residuals)
                self.assertIn('"$JOBNAME.47"', residuals)
                self.assertIn('"$JOBNAME.wfn"', residuals)
                self.assertIn('"$JOBNAME.wfx"', residuals)
                self.assertIn('[[ ! -s "$wavefunction_artifact" ]]', residuals)

    @unittest.skipUnless(
        os.name == "posix" and shutil.which("bash"),
        "wavefunction export classification test requires bash",
    )
    def test_export_classification_distinguishes_molecular_and_periodic_models(self):
        for runner, text in self.runner_text().items():
            definitions = (
                "TONTO_OBSERVED_DENSITY_INPUT(){\n"
                + function_body(text, "TONTO_OBSERVED_DENSITY_INPUT")
                + "TONTO_FINAL_WAVEFUNCTION_EXPORTS_AVAILABLE(){\n"
                + function_body(text, "TONTO_FINAL_WAVEFUNCTION_EXPORTS_AVAILABLE")
            )
            script = definitions + r'''
check() {
    SCFCALCPROG=$1
    PARTITION_MODEL=$2
    if TONTO_FINAL_WAVEFUNCTION_EXPORTS_AVAILABLE; then
        printf '%s:%s=yes\n' "$SCFCALCPROG" "$PARTITION_MODEL"
    else
        printf '%s:%s=no\n' "$SCFCALCPROG" "$PARTITION_MODEL"
    fi
}
check Gaussian oc-hirshfeld
check Orca oc-hirshfeld
check OCC oc-hirshfeld
check elmodb oc-hirshfeld
check Tonto oc-hirshfeld
check Tonto oc-observed
check CP2K periodic
check Crystal14 periodic
'''
            result = subprocess.run(
                ["bash", "-c", script],
                text=True,
                capture_output=True,
                check=True,
            )
            with self.subTest(runner=runner):
                self.assertEqual(
                    result.stdout.splitlines(),
                    [
                        "Gaussian:oc-hirshfeld=yes",
                        "Orca:oc-hirshfeld=yes",
                        "OCC:oc-hirshfeld=yes",
                        "elmodb:oc-hirshfeld=yes",
                        "Tonto:oc-hirshfeld=yes",
                        "Tonto:oc-observed=no",
                        "CP2K:periodic=no",
                        "Crystal14:periodic=no",
                    ],
                )

    @unittest.skipUnless(
        os.name == "posix" and shutil.which("bash"),
        "Hirshfeld cube archive test requires bash",
    )
    def test_hirshfeld_atom_cubes_are_archived_per_tonto_cycle(self):
        for runner, text in self.runner_text().items():
            definition = (
                "_lamagoet_archive_hirshfeld_atom_cubes(){\n"
                + function_body(text, "_lamagoet_archive_hirshfeld_atom_cubes")
            )
            with self.subTest(runner=runner), tempfile.TemporaryDirectory() as directory:
                script = definition + r'''
OUTPUT_HIRSHFELD_ATOM_CUBES=true
JOBNAME=my_job
J=3
printf 'cube' > my_job.Hirshfeld_atom_density_cycle_0_N1,cell.cube
printf 'prior' > my_job.Hirshfeld_atom_IAM_prior_cycle_0_N1,cell.cube
printf 'residual' > my_job.Hirshfeld_atom_observed_residual_cycle_0_N1,cell.cube
printf 'table' > my_job.Hirshfeld_atom_observed_FF_correction_cycle_0_N1.dat
_lamagoet_archive_hirshfeld_atom_cubes
test -s 3.tonto_cycle.my_job/3.Hirshfeld_atom_density_cycle_0_N1,cell.cube
test -s 3.tonto_cycle.my_job/3.Hirshfeld_atom_IAM_prior_cycle_0_N1,cell.cube
test -s 3.tonto_cycle.my_job/3.Hirshfeld_atom_observed_residual_cycle_0_N1,cell.cube
test -s 3.tonto_cycle.my_job/3.Hirshfeld_atom_observed_FF_correction_cycle_0_N1.dat
'''
                subprocess.run(
                    ["bash", "-c", script],
                    cwd=directory,
                    text=True,
                    capture_output=True,
                    check=True,
                )

    @staticmethod
    def runner_text():
        return {
            path.name: path.read_text(encoding="utf-8") for path in RUNNERS
        }



if __name__ == "__main__":
    unittest.main()
