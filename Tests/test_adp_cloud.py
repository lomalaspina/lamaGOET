"""Numerical rendering contracts; no scientific fit is performed here."""
import copy
import json
import math
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import numpy as np
from lamagoet_qt.adp_cloud import CloudModel


def artifact(nodes=None, rotations=None):
    nodes = np.zeros((1, 3)) if nodes is None else np.asarray(nodes)
    u = np.eye(3) * .04
    total = u + nodes.T @ nodes / len(nodes)
    return dict(schema="tonto.curved-adp", version=1, length_unit="angstrom", model="test_distribution",
                fit_status="synthetic_validation_not_experiment", target_label="Cl1", pivot_label="Cu1",
                cell_direct=(np.eye(3) * 5).tolist(), displacement_nodes=nodes.tolist(), node_weight=1 / len(nodes),
                local_covariance=u.tolist(), total_covariance=total.tolist(), mean_cartesian=[0, 0, 0],
                site_rotations=[np.eye(3).tolist()] if rotations is None else rotations,
                atoms=[dict(label="Cl1", element="Cl", mean_cartesian=[0, 0, 0], fractional=[0, 0, 0],
                            total_covariance=total.tolist(), occupancy=1)])


class CloudTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.model = CloudModel(artifact())
        cls.mesh = cls.model.surface(.5)

    def test_analytic_gaussian_limit(self):
        lo, hi = 0., 8.
        for _ in range(80):
            r = (lo + hi) / 2
            cdf = math.erf(r / math.sqrt(2)) - math.sqrt(2 / math.pi) * r * math.exp(-r * r / 2)
            if cdf < .5: lo = r
            else: hi = r
        expected = self.model.norm * math.exp(-r * r / 2)
        self.assertLess(abs(self.mesh.level / expected - 1), .02)
        self.assertLess(abs(self.mesh.integrated_mass - 1), 2e-4)
        tri = self.mesh.vertices[self.mesh.faces]
        volume = np.einsum("ij,ij->i", tri[:, 0], np.cross(tri[:, 1], tri[:, 2])).sum() / 6
        self.assertLess(abs(volume / (4 * math.pi * (.2 * r) ** 3 / 3) - 1), .04)
        self.assertTrue(np.isfinite(self.mesh.vertices).all())

    def test_mixture_is_not_ellipsoid(self):
        nodes = np.array([[-.45, 0, 0], [.45, 0, 0]])
        model = CloudModel(artifact(nodes, [np.eye(3).tolist(), (-np.eye(3)).tolist()]))
        p = model.density(np.array([[0, 0, 0], [.45, 0, 0], [-.45, 0, 0]]))
        self.assertGreater(p[1], p[0]);self.assertAlmostEqual(p[1], p[2], places=13)
        mesh = model.surface(.5)
        # Two separate lobes retain a gap at x=0; never force a convex envelope.
        self.assertGreater(np.min(abs(mesh.vertices[:, 0])), .02)

    def test_rejections(self):
        for key, value in (("version", 2), ("length_unit", "bohr"), ("node_weight", 2),
                           ("local_covariance", (-np.eye(3)).tolist()), ("total_covariance", np.eye(3).tolist()),
                           ("displacement_nodes", [[1, 0, 0]])):
            data = artifact();data[key] = value
            with self.assertRaises(ValueError): CloudModel(data)
        with self.assertRaises(ValueError): self.model.surface(.5, grids=(17,))

    def test_qt_draw_actual_and_equivalent(self):
        from PySide6.QtWidgets import QApplication
        from lamagoet_qt.adp_cloud_dialog import AdpCloudDialog
        app = QApplication.instance() or QApplication([])
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'curved.model.json';path.write_text(json.dumps(artifact()))
            with patch.object(AdpCloudDialog, 'rebuild'):
                dialog = AdpCloudDialog(path)
            dialog._completed(self.mesh);dialog.show();app.processEvents()
            self.assertTrue(dialog.viewer.show_probability_clouds)
            self.assertIn('Cl1', dialog.viewer.probability_meshes)
            self.assertFalse(dialog.viewer.grab().isNull())
            dialog.mode.setCurrentIndex(1);app.processEvents()
            self.assertFalse(dialog.viewer.show_probability_clouds)
            self.assertFalse(dialog.viewer.grab().isNull())
            dialog._failed('test');self.assertFalse(dialog.viewer.isEnabled())
            dialog.close()


if __name__ == '__main__':
    unittest.main()
