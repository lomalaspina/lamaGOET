#!/usr/bin/env python3
"""GUESSP must never reuse an unverified or differently ordered restart."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from test_runner_regressions import RUNNERS, function_body

ROOT = Path(__file__).resolve().parent.parent
INPUT = """restart test
CRYSTAL
0 0 0
1
5 5 5 90 90 90
2
1 0.1 0.2 0.3
1 0.4 0.2 0.3
KEEPSYMM
NOSHIFT
BASISSET
POB-TZVP-REV2
DFT
PBE
END
SHRINK
4 4
TOLDEE
7
END
"""


@unittest.skipUnless(os.name == "posix" and shutil.which("bash"), "requires bash")
class RestartGuard(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="restart guard ")
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        (self.work / "job.d12").write_text(INPUT)
        (self.work / "job.f9").write_bytes(b"synthetic restart binary\0")
        (self.work / "job.out").write_text("== SCF ENDED - CONVERGENCE ON ENERGY\n")
        self.assertEqual(self.shell('_lamagoet_record_crystal_restart job "runcry23|1"').returncode, 0)

    def shell(self, code):
        return subprocess.run(["bash", "-c", 'source "$1"\n' + code, "test",
                               str(ROOT / "lamagoet_shell_env.sh")], cwd=self.work,
                              text=True, capture_output=True)

    def decision(self, context="runcry23|1"):
        result = self.shell(f'_lamagoet_can_reuse_crystal_restart job "{context}"\n'
                            'rc=$?\nprintf "%s\\n" "$LAMAGOET_CRYSTAL_RESTART_REASON"\nexit "$rc"')
        return result.returncode == 0, result.stdout

    def test_verified_unchanged_input_is_reusable(self):
        self.assertTrue(self.decision()[0])

    def test_only_title_whitespace_and_guessp_are_ignored(self):
        changed = INPUT.replace("restart test", "new title")
        changed = changed.replace("1 0.1 0.2 0.3", "  1   0.1  0.2   0.3  ")
        changed = changed[:-4] + "GUESSP\nEND\n"
        (self.work / "job.d12").write_text(changed)
        self.assertTrue(self.decision()[0])

    def test_changed_geometry_order_basis_and_settings_are_rejected(self):
        rows = INPUT.splitlines(keepends=True)
        swapped = rows.copy()
        swapped[6], swapped[7] = swapped[7], swapped[6]
        cases = {
            "same_element_swap": "".join(swapped),
            "different_element": INPUT.replace("1 0.1", "7 0.1"),
            "tiny_move_not_rounded_away": INPUT.replace("0.1 0.2", "0.100001 0.2"),
            "whole_cell_wrap": INPUT.replace("0.1 0.2", "1.1 0.2"),
            "basis": INPUT.replace("POB-TZVP-REV2", "DEF2-TZVP"),
            "cell": INPUT.replace("5 5 5 90", "5.1 5 5 90"),
            "symmetry": INPUT.replace("\n1\n5 5", "\n2\n5 5"),
            "method": INPUT.replace("PBE\n", "PBE0\n"),
            "screening": INPUT.replace("TOLDEE", "TOLINTEG\n8 8 8 8 16\nTOLDEE"),
        }
        for name, text in cases.items():
            with self.subTest(name=name):
                (self.work / "job.d12").write_text(text)
                allowed, reason = self.decision()
                self.assertFalse(allowed)
                self.assertIn("settings changed", reason)

    def test_restart_missing_or_replaced_cannot_reuse_old_record(self):
        path = self.work / "job.f9"
        path.write_bytes(b"different restart")
        self.assertFalse(self.decision()[0])
        path.unlink()
        self.assertFalse(self.decision()[0])

    def test_missing_truncated_or_unknown_provenance_fails_closed(self):
        path = self.work / ".lamagoet_crystal_mpi/job.restart-provenance"
        for value in ("", "LAMAGOET_CRYSTAL_RESTART_V1\n", "UNKNOWN_VERSION\n"):
            path.write_text(value)
            self.assertFalse(self.decision()[0])
        path.unlink()
        self.assertFalse(self.decision()[0])

    def test_launcher_or_parallelism_change_is_rejected(self):
        self.assertFalse(self.decision("runcry23|4")[0])
        self.assertFalse(self.decision("other-runner|1")[0])

    def test_failed_or_nan_scf_invalidates_old_record(self):
        for output in ("SCF failed\n", "== SCF ENDED - CONVERGENCE ON ENERGY\nNaN\n",
                       "== SCF ENDED - CONVERGENCE ON ENERGY\nERROR **** example\n"):
            (self.work / "job.out").write_text(output)
            self.assertNotEqual(self.shell('_lamagoet_record_crystal_restart job "runcry23|1"').returncode, 0)
            self.assertFalse(self.decision()[0])

    def test_invalidation_before_launch(self):
        self.assertEqual(self.shell('_lamagoet_invalidate_crystal_restart job').returncode, 0)
        self.assertFalse(self.decision()[0])

    def test_incomplete_input_does_not_produce_a_reusable_signature(self):
        (self.work / "job.d12").write_text(INPUT[:-4])
        self.assertFalse(self.decision()[0])

    def test_both_actual_runners_gate_keyword_and_argument_together(self):
        for runner in RUNNERS:
            with self.subTest(runner=runner.name):
                body = function_body(runner.read_text(), "TONTO_TO_CRYSTAL")
                self.assertEqual(body.count('_lamagoet_can_reuse_crystal_restart'), 1)
                guard = body.index('_lamagoet_can_reuse_crystal_restart')
                keyword = body.index("sed -i '$iGUESSP'")
                argument = body.index('crystal_restart=$JOBNAME')
                invalidate = body.index('_lamagoet_invalidate_crystal_restart')
                launch = body.index('_lamagoet_run_crystal23 ')
                record = body.index('_lamagoet_record_crystal_restart')
                self.assertLess(guard, keyword)
                self.assertLess(keyword, argument)
                self.assertLess(argument, invalidate)
                self.assertLess(invalidate, launch)
                self.assertLess(launch, record)
                self.assertNotIn('echo "GUESSP"', body)

    @unittest.skipUnless(shutil.which("bc"), "runner uses bc")
    def test_actual_runner_generates_matching_keyword_and_driver_argument(self):
        # Execute the real input-generation function, stopping at a stub driver.
        # This exercises both permitted reuse and same-element reorder fallback.
        (self.work / "stdout").write_text("\n".join([
            "a cell parameter ............ 5", "b cell parameter ............ 6",
            "c cell parameter ............ 7", "alpha angle ................. 90",
            "beta  angle ................. 90", "gamma angle ................. 90"]) + "\n")
        (self.work / "input.cif").write_text("_symmetry_Int_Tables_number 16\n")
        xyz = "2\ncomment\n1 0.1 0.2 0.3\n1 0.4 0.2 0.3\n"
        setup = '''
I=1 JOBNAME=job SPACEGROUPHM=unused CIF=input.cif
USEHMSYM=false XTALSETTING=0 SUPERCON=false GAUSGEN=false
BASISSETG=POB-TZVP-REV2 METHOD=pbe SHRINKA=4 SHRINKB=4
SCFCALC_BIN=runcry23 NUMPROC=1
_lamagoet_run_crystal23() { printf 'RESTART_ARGUMENT=%s\\n' "${4:-}"; exit 0; }
'''
        for runner in RUNNERS:
            with self.subTest(runner=runner.name):
                body = function_body(runner.read_text(), "TONTO_TO_CRYSTAL")
                function = "TONTO_TO_CRYSTAL() {\n" + body + "\n"
                (self.work / "job.xyz").write_text(xyz)
                result = self.shell(function + setup + '\nUSEGUESS=false\nTONTO_TO_CRYSTAL\n')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertNotIn("GUESSP", (self.work / "job.d12").read_text())
                self.assertEqual(self.shell('_lamagoet_record_crystal_restart job "runcry23|1"').returncode, 0)
                result = self.shell(function + setup + '\nUSEGUESS=true\nTONTO_TO_CRYSTAL\n')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("RESTART_ARGUMENT=job", result.stdout)
                self.assertTrue((self.work / "job.d12").read_text().endswith("GUESSP\nEND\n"))
                self.assertEqual(self.shell('_lamagoet_record_crystal_restart job "runcry23|1"').returncode, 0)
                (self.work / "job.xyz").write_text("2\ncomment\n1 0.4 0.2 0.3\n1 0.1 0.2 0.3\n")
                result = self.shell(function + setup + '\nUSEGUESS=true\nTONTO_TO_CRYSTAL\n')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("RESTART_ARGUMENT=\n", result.stdout)
                self.assertIn("Starting a fresh SCF guess", result.stderr)
                self.assertNotIn("GUESSP", (self.work / "job.d12").read_text())


if __name__ == "__main__":
    unittest.main()
