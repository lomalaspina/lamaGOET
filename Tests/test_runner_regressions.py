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
        rf"(?ms)^{re.escape(name)}\(\)\{{\n(.*?)(?=^[A-Z][A-Z0-9_]*\(\)\{{|\Z)",
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
                crystal = function_body(text, "CRYSTAL_BLOCK")
                self.assertRegex(
                    crystal,
                    r'if \[\[[^\n]*SCFCALCPROG[^\n]*"Tonto"[^\n]*\]\]; then\s+'
                    r'WRITE_DENSITY_PARTITION_MODEL',
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
                if program == "Tonto" and selected == "oc-observed":
                    self.assertIn("observed_density_shrinkage= 0.35", result.stdout)
                    self.assertNotIn("partition_model= oc-crystal23", result.stdout)
                elif program != "Tonto":
                    self.assertIn("stockholder_model= periodic", result.stdout)
                    self.assertNotIn("partition_model= oc-observed", result.stdout)
                    self.assertNotIn("observed_density_shrinkage", result.stdout)

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

    def test_summary_blocks_do_not_use_the_dead_heading(self):
        """The result-block extractions must key on a heading Tonto writes.

        Current Tonto emits "IAM refinement" and "Structure refinement
        results"; it does not emit "Rigid-atom fit results" anywhere.  An
        extraction keyed on the missing heading leaves its line number unset,
        so `for (d=b-2; d<c-1; ++d)` starts at -2 and copies the whole of
        stdout into the summary instead of one block.

        KNOWN GAP: the per-cycle convergence table (MAXSHIFT, MAXSHIFTATOM,
        MAXSHIFTPARAM and the row written for each cycle) still keys on that
        heading and therefore comes out blank.  Fixing it needs the right
        heading per refinement phase, which differs between an IAM and a HAR.
        Tracked separately; this test covers the block extractions only.
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



if __name__ == "__main__":
    unittest.main()

