"""Exact positive-mixture cloud contract; synthetic, not an experimental fit."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
from Tests.test_adp_cloud import artifact
from lamagoet_qt.adp_cloud import CloudModel


def mixture_artifact(w=.3, d=(.55, .08, -.06), inverted=False):
    d = np.asarray(d)
    rotations = np.array([np.eye(3), -np.eye(3)] if inverted else [np.eye(3)])
    nodes = np.concatenate([np.array([(1-w)*d, -w*d]) @ r.T for r in rotations])
    weights = np.tile([w, 1-w], len(rotations)) / len(rotations)
    data = artifact(nodes, rotations.tolist())
    data.pop('node_weight');data.pop('pivot_label')
    data.update(schema='tonto.shared-u-mixture-adp', model='shared_u_two_gaussian_mixture',
                averaging='full_site_probability_average', mixture_weight=w,
                separation_A=d.tolist(), shape_parameters=[*d, float(np.log(w/(1-w)))],
                shape_parameter_units=['angstrom']*3+['dimensionless'], component_weights=weights.tolist())
    total = np.array(data['local_covariance']) + nodes.T @ (weights[:, None]*nodes)
    data['total_covariance'] = total.tolist();data['atoms'][0]['total_covariance'] = total.tolist()
    return data


class MixtureCloudTests(unittest.TestCase):
    def test_density_and_moments(self):
        xyz = np.random.default_rng(1112).normal(size=(123, 3))*.2
        for inverted in (False, True):
            model = CloudModel(mixture_artifact(inverted=inverted))
            expected = sum(w * model.norm * np.exp(-.5*np.sum((xyz-node)**2, axis=1)/.04)
                           for w, node in zip(model.weights, model.nodes))
            np.testing.assert_allclose(model.density(xyz), expected, atol=2e-14, rtol=2e-14)
            self.assertTrue(np.all(expected > 0))
            k3 = np.einsum('n,ni,nj,nk->ijk', model.weights, model.nodes, model.nodes, model.nodes)
            d = np.array(model.data['separation_A']);w = model.data['mixture_weight']
            target = np.zeros((3, 3, 3)) if inverted else w*(1-w)*(1-2*w)*np.einsum('i,j,k->ijk', d,d,d)
            np.testing.assert_allclose(k3, target, atol=2e-17)
            if inverted:np.testing.assert_allclose(model.density(xyz), model.density(-xyz), atol=2e-14)

    def test_two_grid_integral_and_surface(self):
        model = CloudModel(mixture_artifact())
        for spacing in (.08, .04):
            axis = np.arange(-1.9, 2.0, spacing)
            points = np.stack(np.meshgrid(axis, axis, axis, indexing='ij'), axis=-1).reshape(-1,3)
            density = model.density(points)
            self.assertGreaterEqual(density.min(), 0)
            self.assertLess(abs(density.sum()*spacing**3 - 1), 1e-10)
        mesh = model.surface(.5)
        self.assertLess(abs(mesh.integrated_mass-1), 2e-4)
        self.assertLess(abs(mesh.enclosed_mass-.5), .003)

    def test_special_points_are_valid_distributions(self):
        # A viewer makes NO identifiability claim about these parameter points.
        xyz = np.random.default_rng(18).normal(size=(9,3))*.1
        for w in (.3, .5):
            model = CloudModel(mixture_artifact(w=w, d=(0,0,0)))
            normal = CloudModel(artifact())
            np.testing.assert_allclose(model.density(xyz), normal.density(xyz), rtol=2e-15)
        model = CloudModel(mixture_artifact(w=.5))
        np.testing.assert_allclose(model.density(xyz), model.density(-xyz), rtol=2e-14)

    def test_metadata_rejections(self):
        mutations = {'mixture_weight': .7, 'shape_parameters':[.55,.08,-.06,0],
                     'component_weights':[.5,.5], 'node_weight':.5,
                     'separation_A':[.56,.08,-.06], 'averaging':'shared_phase',
                     'shape_parameter_units':['bohr']*3+['dimensionless'],
                     'model':'other', 'local_covariance':(-np.eye(3)).tolist()}
        for key,value in mutations.items():
            with self.subTest(key=key),self.assertRaises(ValueError):
                data=mixture_artifact();data[key]=value;CloudModel(data)
        for rotations in ([(-np.eye(3)).tolist()], [np.eye(3).tolist()]*2,
                          [np.eye(3).tolist(), [[0,-1,0],[1,0,0],[0,0,1]]]):
            data=mixture_artifact();data['site_rotations']=rotations
            with self.assertRaises(ValueError):CloudModel(data)
        data=mixture_artifact(inverted=True);data['displacement_nodes'][0][0]+=.001
        with self.assertRaises(ValueError):CloudModel(data)
        data=mixture_artifact(w=1e-16);data['shape_parameters'][3]=-10000
        with self.assertRaises(ValueError):CloudModel(data)
        for key,value in [('mean_cartesian',[1,0,0]), ('total_covariance',np.eye(3).tolist())]:
            data=mixture_artifact();data['atoms'][0][key]=value
            with self.assertRaises(ValueError):CloudModel(data)

    def test_qt_model_label_and_rendering(self):
        from PySide6.QtWidgets import QApplication
        from lamagoet_qt.adp_cloud_dialog import AdpCloudDialog
        app = QApplication.instance() or QApplication([])
        model=CloudModel(mixture_artifact());mesh=model.surface(.5)
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'mixture.model.json';path.write_text(json.dumps(model.data))
            with patch.object(AdpCloudDialog,'rebuild'):
                dialog=AdpCloudDialog(path)
            self.assertIn('Shared-U two-Gaussian ADP',dialog.windowTitle())
            dialog._completed(mesh);dialog.show();app.processEvents()
            self.assertFalse(dialog.viewer.grab().isNull())
            self.assertIn('Cl1',dialog.viewer.probability_meshes)
            self.assertIn('synthetic_validation_not_experiment',dialog.source.text())
            dialog.close()


if __name__=='__main__':unittest.main()
