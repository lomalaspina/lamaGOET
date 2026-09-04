"""Guard against the two runners drifting apart.

lamaGOET.sh runs jobs on this computer; RUN_lamaGOET_release.sh runs them on a
cluster.  They contain the same ~50 functions and are about 98% identical.
Every bug fixed in one and not the other has produced a cluster job that
returned wrong numbers without complaining, three times so far.

Merging the two files would prevent this properly.  Until then, these tests
fail when a known fix is present in one runner and missing from the other.
"""

import re
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
RUNNERS = (REPO / "lamaGOET.sh", REPO / "RUN_lamaGOET_release.sh")


def read(runner):
    return runner.read_text(encoding="utf-8")


def live_lines(text):
    """Lines that are not entirely commented out."""
    return [l for l in text.splitlines() if not l.lstrip().startswith("#")]


class RunnerParityTest(unittest.TestCase):
    def test_both_define_the_same_functions(self):
        defined = {}
        for runner in RUNNERS:
            names = set(
                re.findall(r"^([A-Z_][A-Z_0-9]*)\(\)\s*\{", read(runner), re.M)
            )
            defined[runner.name] = names

        local, cluster = (defined[r.name] for r in RUNNERS)
        # The cluster runner hands CP2K jobs to lamaGOET.sh, so it legitimately
        # lacks the CP2K backend and the interactive helpers.
        cluster_only = cluster - local
        self.assertEqual(
            cluster_only,
            set(),
            f"RUN_lamaGOET_release.sh defines functions lamaGOET.sh does not: "
            f"{sorted(cluster_only)}",
        )

    def test_defragnetw_test_has_spaces(self):
        """`"$X"=="true"` is one non-empty word, so the branch is always taken."""
        for runner in RUNNERS:
            bad = [l for l in live_lines(read(runner)) if '"=="' in l]
            with self.subTest(runner=runner.name):
                self.assertEqual(
                    bad, [], f"{runner.name} has a string comparison with no "
                    f"spaces, which is always true: {bad[:1]}"
                )

    def test_point_charges_read_the_file_that_is_written(self):
        """gaussian-point-charges is created nowhere; cluster_charges is."""
        for runner in RUNNERS:
            bad = [
                l for l in live_lines(read(runner))
                if "gaussian-point-charges" in l
            ]
            with self.subTest(runner=runner.name):
                self.assertEqual(
                    bad, [],
                    f"{runner.name} reads gaussian-point-charges, which nothing "
                    f"creates, so the point charges are silently dropped: {bad[:1]}",
                )

    def test_final_residual_run_is_checked(self):
        for runner in RUNNERS:
            text = read(runner)
            with self.subTest(runner=runner.name):
                self.assertIn(
                    "Unit cell residual density:",
                    text,
                    f"{runner.name} does not check that the final Tonto run "
                    f"produced a residual density, so a failed run is reported "
                    f"as a completed refinement",
                )

    def test_xyz_edit_is_guarded(self):
        """sed -i on a missing file errors; the local runner guards it."""
        for runner in RUNNERS:
            text = read(runner)
            with self.subTest(runner=runner.name):
                self.assertIn(
                    'if [ -f "$JOBNAME.xyz" ]; then',
                    text,
                    f"{runner.name} edits $JOBNAME.xyz without checking it exists",
                )

    def test_reflection_data_rebuilt_before_final_residuals(self):
        """The refined CIF has the cell but not the reflection list."""
        for runner in RUNNERS:
            text = read(runner)
            hits = text.count("CRYSTAL_BLOCK\n")
            with self.subTest(runner=runner.name):
                self.assertGreaterEqual(
                    hits, 2,
                    f"{runner.name} calls CRYSTAL_BLOCK {hits} time(s); it is "
                    f"needed both for Crystal14 and to rebuild the reflection "
                    f"data before the final residual map",
                )

    def test_both_source_the_shell_environment(self):
        for runner in RUNNERS:
            with self.subTest(runner=runner.name):
                self.assertIn("lamagoet_shell_env.sh", read(runner))

    def test_periodic_xcw_is_available_in_both_runners(self):
        required = (
            "PERIODIC_XCW_PREPARE_INPUT_GEOMETRY",
            "PERIODIC_XCW_PREPARE_CUSTOM_BASIS",
            "PERIODIC_XCW_WRITE_TONTO_BASIS",
            "PERIODIC_XCW_PREPARE_CRYSTAL_REFERENCE",
            "PERIODIC_XCW_CRYSTAL_BLOCK",
            "PERIODIC_XCW_SCFDATA",
            "PERIODIC_XCW_BECKE_GRID",
            "PERIODIC_XCW",
        )
        for runner in RUNNERS:
            text = read(runner)
            with self.subTest(runner=runner.name):
                for function in required:
                    self.assertRegex(text, rf"(?m)^{function}\(\)\s*\{{")
                self.assertIn('"${XCW_MODE:-molecular}" == "periodic"', text)
                self.assertIn("r_free_selection= deterministic", text)
                self.assertIn("periodic_xcw_restart=", text)
                self.assertIn("periodic_xcw_write_checkpoint=", text)
                self.assertIn("periodic_xcw_KRED_file_name= GenerateXML_dat.KRED", text)
                self.assertIn("GenerateXML_dat.KRED.gz", text)

    def test_periodic_xcw_basis_selection_is_centralized(self):
        for runner in RUNNERS:
            text = read(runner)
            match = re.search(
                r"PERIODIC_XCW\(\)\{(?P<body>.*?)\n\}\s*\nXCW_SCF_BLOCK",
                text,
                re.S,
            )
            with self.subTest(runner=runner.name):
                self.assertIsNotNone(match)
                body = match.group("body")
                self.assertEqual(body.count("PERIODIC_XCW_WRITE_TONTO_BASIS"), 1)
                self.assertNotIn("NOT_TONTO_BASIS_SET", body)
                self.assertNotIn('echo "   basis_directory= $BASISSETDIR"', body)
                helper = re.search(
                    r"PERIODIC_XCW_WRITE_TONTO_BASIS\(\)\{(?P<body>.*?)\n\}",
                    text,
                    re.S,
                )
                self.assertIsNotNone(helper)
                self.assertEqual(
                    helper.group("body").count("NOT_TONTO_BASIS_SET"), 1
                )
                self.assertIn(
                    "PERIODIC_XCW_ACTIVE_TONTO_BASIS_DIR",
                    helper.group("body"),
                )


if __name__ == "__main__":
    unittest.main()
