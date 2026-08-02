#!/usr/bin/env python3
"""Static contracts for the two shell runners.

These tests intentionally inspect the generated-input commands rather than
executing chemistry programs.  The full NH3 calculations are a separate
integration suite, but these checks catch the dispatch and omitted-keyword
failures before expensive external programs are started.
"""

from pathlib import Path
import re
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
                partition = re.search(
                    r"(?s)partition_model= oc-crystal23.*?partition_model= oc-hirshfeld",
                    body,
                )
                self.assertIsNotNone(partition)
                self.assertNotIn("dft_exchange_functional", partition.group(0))

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


if __name__ == "__main__":
    unittest.main()
