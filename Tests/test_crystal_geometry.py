#!/usr/bin/env python3
"""Cycle zero must retain identities, precision and the independent restart guard."""
import json
import os
from pathlib import Path
import sys
import tempfile
import subprocess
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lamagoet_tools import crystal_geometry as cg
from test_runner_regressions import RUNNERS, function_body

INPUT = """test
CRYSTAL
0 0 0
1
5 5 5 90 90 90
2
1 0.117100000000 0.365300000000 0.270600000000
7 0.210560000000 0.210560000000 0.210560000000
KEEPSYMM
NOSHIFT
BASISSET
POB-TZVP-REV2
DFT
B3LYP
END
SHRINK
6 6
END
"""
CIF = """data_test
loop_
_atom_site_Cryst_label
_atom_site_Cryst_x
_atom_site_Cryst_y
_atom_site_Cryst_z
H1 .117100000000 .365300000000 .270600000000
N1 .210560000000 .210560000000 .210560000000
loop_
_atom_site_aniso_label
_atom_site_aniso_U_11
H1 .0628
N1 .03603
"""
GUI = """3 1 1
5 0 0
0 5 0
0 0 5
1
1 0 0
0 1 0
0 0 1
0 0 0
2
1 .5855 1.8265 1.353
7 1.0528 1.0528 1.0528
1 1
"""


class Geometry(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.input = self.root / "job.d12"
        self.cif = self.root / "job.cif"
        self.record = self.root / "record.json"
        self.work = self.root / "cycle0"
        self.work.mkdir()
        self.input.write_text(INPUT)
        self.cif.write_text(CIF)

    def prepare_accept(self):
        cg.prepare(self.input, self.cif, self.work)
        (self.work / "geometry.gui").write_text(GUI)
        (self.work / "geometry.out").write_text("TESTGEOM completed\n")
        cg.accept(self.work, self.record)

    def test_geometry_only_and_originals_preserved(self):
        self.prepare_accept()
        text = (self.work / "geometry.d12").read_text()
        self.assertTrue(text.endswith("EXTPRT\nTESTGEOM\nEND\n"))
        for forbidden in ("BASISSET", "B3LYP", "SHRINK", "GUESSP"):
            self.assertNotIn(forbidden, text)
        self.assertEqual(self.input.read_text(), INPUT)
        self.assertEqual(self.cif.read_text(), CIF)
        record = json.loads(self.record.read_text())
        self.assertFalse(record["restart_certified"])
        self.assertEqual(record["geometry"]["primitive_volume_angstrom3"], 125)

    def test_order_is_restored_without_changing_geometry_or_cif(self):
        self.prepare_accept()
        rows = INPUT.splitlines(keepends=True)
        rows[6], rows[7] = rows[7], rows[6]
        self.input.write_text("".join(rows))
        cg.order(self.input, self.cif, self.record)
        self.assertEqual(self.input.read_text(), INPUT)
        self.assertEqual(self.cif.read_text(), CIF)

    def test_labels_track_same_element_atoms_and_moved_current_coordinates(self):
        self.input.write_text(INPUT.replace("7 0.210", "1 0.210"))
        self.cif.write_text(CIF.replace("N1", "H2"))
        cg.prepare(self.input, self.cif, self.work)
        (self.work / "geometry.gui").write_text(GUI.replace("7 1.0528", "1 1.0528"))
        (self.work / "geometry.out").write_text("TESTGEOM completed\n")
        cg.accept(self.work, self.record)
        expected = self.input.read_text().replace("0.117100000000", "1.118234567890")
        self.cif.write_text(self.cif.read_text().replace(".117100000000", ".118234567890"))
        rows = expected.splitlines(keepends=True)
        rows[6], rows[7] = rows[7], rows[6]
        self.input.write_text("".join(rows))
        cg.order(self.input, self.cif, self.record)
        self.assertEqual(self.input.read_text(), expected)

    def test_legacy_publication_rounding_and_precise_loop_precedence(self):
        self.cif.write_text(CIF.replace("_atom_site_Cryst_label", "_atom_site_label")
                           .replace("_atom_site_Cryst_", "_atom_site_fract_")
                           .replace(".210560000000", ".2106(2)"))
        self.assertEqual(len(cg.identify(self.input, self.cif)[1]), 2)
        self.cif.write_text(self.cif.read_text() + CIF.replace("data_test", ""))
        self.assertEqual(len(cg.identify(self.input, self.cif)[1]), 2)

    def test_grown_fragment_and_legacy_singleton_label(self):
        self.prepare_accept()
        self.cif.write_text(CIF.replace("N1", "N") + "\n")
        # More CIF fragment atoms than asymmetric input atoms is normal in HAR.
        text = self.cif.read_text().replace("loop_\n_atom_site_aniso_label", 
                   "H2 .3 .4 .5\nloop_\n_atom_site_aniso_label")
        self.cif.write_text(text)
        cg.order(self.input, self.cif, self.record)
        self.assertEqual(self.input.read_text(), INPUT)
        audit = json.loads(Path(str(self.input)+".atom-order.json").read_text())
        self.assertEqual(audit["current_label_for_initial_label"]["N1"], "N")

    @unittest.skipUnless(os.name == "posix", "bash workflow")
    def test_child_shell_reloads_helpers_despite_inherited_loaded_flag(self):
        source = Path(__file__).resolve().parents[1] / "lamagoet_shell_env.sh"
        code = '''source "$1"
bash -c 'source "$1"; declare -F _lamagoet_crystal_cycle_zero; declare -F _lamagoet_can_reuse_crystal_restart' child "$1"
'''
        p = subprocess.run(["bash", "-c", code, "test", str(source)], capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("_lamagoet_crystal_cycle_zero", p.stdout)

    @unittest.skipUnless(os.name == "posix", "bash workflow")
    def test_shell_helper_runs_geometry_once_then_orders_before_guard(self):
        self.input.rename(self.root / "job.d12")
        self.cif.rename(self.root / "job.fractional.cif1")
        (self.root / "fixture.gui").write_text(GUI)
        (self.root / "fixture.out").write_text("TESTGEOM completed\n")
        source = Path(__file__).resolve().parents[1] / "lamagoet_shell_env.sh"
        code = '''source "$1"
_lamagoet_run_crystal23() { cp "$FIX_GUI" geometry.gui; cp "$FIX_OUT" geometry.out; }
_lamagoet_crystal_cycle_zero job 1 /bin/true 1 || exit
'''
        env = dict(os.environ, FIX_GUI=str(self.root/"fixture.gui"), FIX_OUT=str(self.root/"fixture.out"))
        p = subprocess.run(["bash", "-c", code, "test", str(source)], cwd=self.root,
                           env=env, capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        rows = INPUT.splitlines(keepends=True)
        rows[6], rows[7] = rows[7], rows[6]
        self.input.write_text("".join(rows))
        (self.root / "job.f9").write_bytes(b"mock restart")
        (self.root / "job.out").write_text("SCF ENDED - CONVERGENCE ON ENERGY\n")
        # Record provenance from the initial ordered input, not the permuted file.
        self.input.write_text(INPUT)
        code = '''source "$1"
_lamagoet_record_crystal_restart job test || exit
'''
        p = subprocess.run(["bash", "-c", code, "test", str(source)], cwd=self.root, capture_output=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.input.write_text("".join(rows))
        code = '''source "$1"
_lamagoet_run_crystal23() { return 99; } # Must not be called again.
_lamagoet_crystal_cycle_zero job 2 /bin/true 1 || exit
_lamagoet_can_reuse_crystal_restart job test
'''
        p = subprocess.run(["bash", "-c", code, "test", str(source)], cwd=self.root, capture_output=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.input.read_text(), INPUT)
        # Older imports may rename labels. Never guess their identity: the
        # numerical input is retained but the prior restart is invalidated.
        cif = self.root / "job.fractional.cif1"
        cif.write_text(CIF.replace("N1", "unknown_label"))
        code = '''source "$1"
_lamagoet_crystal_cycle_zero job 2 /bin/true 1 || exit 99
if _lamagoet_can_reuse_crystal_restart job test; then exit 98; fi
'''
        p = subprocess.run(["bash", "-c", code, "test", str(source)], cwd=self.root, capture_output=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn(b"fresh SCF guess", p.stderr)
        self.assertEqual(self.input.read_text(), INPUT)
        audit = json.loads(Path(str(self.input)+".atom-order.json").read_text())
        self.assertEqual(audit["status"], "ordering_not_certified_fresh_scf_required")
    def test_missing_renamed_ambiguous_and_changed_element_fail_without_mutation(self):
        self.prepare_accept()
        for cif in (CIF.replace("N1", "N2"), CIF.replace("N1 .210560", "H1 .210560"),
                    CIF.replace(".117100000000", ".119100000000")):
            self.cif.write_text(cif)
            with self.assertRaises(ValueError):
                cg.order(self.input, self.cif, self.record)
            self.assertEqual(self.input.read_text(), INPUT)
        self.cif.write_text(CIF)
        changed = INPUT.replace("7 0.210", "8 0.210")
        self.input.write_text(changed)
        with self.assertRaises(ValueError):
            cg.order(self.input, self.cif, self.record)
        self.assertEqual(self.input.read_text(), changed)

    def test_missing_or_bad_export_never_creates_record(self):
        cg.prepare(self.input, self.cif, self.work)
        (self.work / "geometry.out").write_text("TESTGEOM completed\n")
        for bad in ("", GUI.replace("5 0 0", "0 0 0"), GUI.replace(".5855", "NaN"),
                    GUI.replace("7 1.0528", "8 1.0528")):
            (self.work / "geometry.gui").write_text(bad)
            with self.assertRaises(ValueError):
                cg.accept(self.work, self.record)
            self.assertFalse(self.record.exists())

    def test_centred_primitive_cell_is_not_expanded_to_conventional_atoms(self):
        gui = self.root / "fcc.gui"
        gui.write_text(GUI.replace("5 0 0\n0 5 0\n0 0 5", "0 2.82 2.82\n2.82 0 2.82\n2.82 2.82 0"))
        result = cg.inspect_gui(gui)
        self.assertEqual(len(result["primitive_atoms"]), 2)
        self.assertAlmostEqual(result["primitive_volume_angstrom3"], 5.64**3/4)

    def test_external_basis_and_geometry_directives(self):
        self.input.write_text(INPUT.replace("BASISSET\nPOB-TZVP-REV2", "END\nexternal basis"))
        cg.prepare(self.input, self.cif, self.work)
        self.assertNotIn("external basis", (self.work / "geometry.d12").read_text())
        self.input.write_text(INPUT.replace("NOSHIFT", "ATOMDISP"))
        with self.assertRaises(ValueError):
            cg.prepare(self.input, self.cif, self.work)

    def test_both_runners_prepare_geometry_before_restart_decision(self):
        for runner in RUNNERS:
            body = function_body(runner.read_text(), "TONTO_TO_CRYSTAL")
            self.assertEqual(body.count("_lamagoet_crystal_cycle_zero"), 1)
            self.assertLess(body.index("_lamagoet_crystal_cycle_zero"),
                            body.index("_lamagoet_can_reuse_crystal_restart"))


if __name__ == "__main__":
    unittest.main()
