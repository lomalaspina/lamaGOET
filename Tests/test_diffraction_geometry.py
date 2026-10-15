#!/usr/bin/env python3
"""CIF metadata must not be mistaken for per-observation beam geometry."""
from pathlib import Path
import tempfile
import unittest

from lamagoet_qt.diffraction_geometry import scan_cif_geometry


def ub(prefix="_diffrn_orient_matrix_UB_"):
    return "\n".join(f"{prefix}{i}{j} {0.1 if i == j else 0.0}"
                     for i in range(1, 4) for j in range(1, 4)) + "\n"


class GeometryTests(unittest.TestCase):
    def scan(self, text):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "geometry.cif"
            path.write_text(text, encoding="utf-8")
            original = path.read_bytes()
            reports = scan_cif_geometry(path)
            self.assertEqual(path.read_bytes(), original)
            return reports

    def test_ub_and_run_plan_are_not_observation_angles(self):
        report, = self.scan("data_test\n" + ub() + r"""
_diffrn_measurement_details
;
List of Runs (angles in degrees, time in seconds):
  1  \w -23.00 94.00 0.50 0.60 -- 13.08 16.00 5.00 234
  2  \w -67.00 26.00 0.50 0.60 -- 13.08-16.00-164.00 186
;
""")
        self.assertEqual(report.ub[0], (0.1, 0.0, 0.0))
        self.assertTrue(report.run_list_present)
        self.assertEqual(report.measured_rows, 0)
        self.assertEqual(report.angle_rows, 0)
        self.assertIn("not interpreted", report.summary())

    def test_block_isolation_and_aliases(self):
        reports = self.scan("data_first\n" + ub("_diffrn_orient_matrix.UB_")
                            + "data_second\n_diffrn_orient_matrix_UB_11 0.1(2)\n")
        self.assertIsNotNone(reports[0].ub)
        self.assertIsNone(reports[1].ub)
        self.assertIn("1/9", reports[1].ub_status)
        report, = self.scan("data_brackets\n" + "\n".join(
            f"_diffrn_orient_matrix.UB[{i}][{j}] {0.1 if i==j else 0}"
            for i in range(1, 4) for j in range(1, 4)))
        self.assertIsNotNone(report.ub)

    def test_missing_nonfinite_and_singular_ub(self):
        report, = self.scan("data_empty\n_note 'No geometry'\n")
        self.assertEqual(report.ub_status, "absent")
        for bad in ("?", ".", "NaN", "Inf"):
            report, = self.scan("data_bad\n" + ub().replace("UB_11 0.1", "UB_11 " + bad))
            self.assertIsNone(report.ub)
            self.assertIn("8/9", report.ub_status)
        report, = self.scan("data_zero\n" + ub().replace("0.1", "0.0"))
        self.assertIn("singular", report.ub_status)

    def test_angles_reference_rows_and_shape_are_distinct(self):
        report, = self.scan("""data_details
_diffrn_orient_matrix_type 'instrument-specific convention'
_exptl_absorpt_coefficient_mu 1.23(4)
loop_
_diffrn_orient_refln_index_h
_diffrn_orient_refln_index_k
_diffrn_orient_refln_index_l
1 0 0
loop_
_diffrn_refln_index_h
_diffrn_refln_index_k
_diffrn_refln_index_l
_diffrn_refln_angle_omega
_diffrn_refln_angle_phi
_diffrn_refln_angle_kappa
1 2 3 10 20 30
1 2 3 40 20 30
2 2 3 ? 20 30
? 2 3 40 20 30
loop_
_exptl_crystal_face_index_h
_exptl_crystal_face_index_k
_exptl_crystal_face_index_l
_exptl_crystal_face_perp_dist
1 0 0 0.1
-1 0 0 0.2
0 0 0 0.3
0 1 0 ?
0 -1 0 -0.2
loop_
_exptl_oxdiff_crystal_face_x
_exptl_oxdiff_crystal_face_y
_exptl_oxdiff_crystal_face_z
1 0 0
""")
        self.assertEqual(report.measured_rows, 3)
        self.assertEqual(report.angle_rows, 2)
        self.assertEqual(report.orientation_rows, 1)
        self.assertEqual(report.face_rows, 2)
        self.assertTrue(report.oxford_faces_present)
        self.assertEqual(report.absorption_coefficient, 1.23)

    def test_commented_tags_do_not_count(self):
        report, = self.scan("data_comments\n# _diffrn_orient_matrix_UB_11 0.1\n")
        self.assertEqual(report.ub_status, "absent")


if __name__ == "__main__":
    unittest.main()
