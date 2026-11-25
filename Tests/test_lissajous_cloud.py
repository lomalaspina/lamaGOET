"""Portable Lissajous metadata: independent nodes, units and symmetry guards."""
import copy
import unittest
import numpy as np
from Tests.test_adp_cloud import artifact
from lamagoet_qt.adp_cloud import CloudModel


def lissajous_artifact(dim, inverted=False):
    n = 256
    tau = np.arange(n)*2*np.pi/n
    ratio = [1, 2] if dim == 2 else [1, 2, 3]
    amps = [.12, .09] if dim == 2 else [.12, .09, .07]
    phases = [.31] if dim == 2 else [.31, -.23]
    # Independent rotation about z; not the reader's Rodrigues expression.
    angle = .27
    q = np.array([[np.cos(angle),-np.sin(angle),0],
                  [np.sin(angle),np.cos(angle),0],[0,0,1]])
    nodes = np.zeros((n,3))
    for i in range(dim):
        nodes[:,i] = amps[i]*np.sin(ratio[i]*tau+(phases+[0])[i])
    nodes = nodes@q.T
    rotations = [np.eye(3)]
    if inverted:
        rotations.append(-np.eye(3));nodes = np.r_[nodes,-nodes]
    data = artifact(nodes, np.array(rotations).tolist())
    data.pop('pivot_label')
    data.update(schema='tonto.lissajous-adp', model='lissajous', dimensions=dim,
                averaging='one_shared_uniform_phase', absolute_frequencies_refined=False,
                fixed_last_phase_rad=0, winding_ratio=ratio, amplitudes_A=amps,
                phases_rad=phases, orientation_rad=[0,0,angle],
                shape_parameters=amps+phases+[0,0,angle],
                shape_parameter_units=['angstrom']*dim+['radian']*(dim+2))
    return data


class LissajousCloudTests(unittest.TestCase):
    def test_positive_and_site_symmetric(self):
        xyz = np.random.default_rng(78).normal(size=(40,3))*.2
        for dim in (2,3):
            for inverted in (False,True):
                with self.subTest(dim=dim,inverted=inverted):
                    model = CloudModel(lissajous_artifact(dim,inverted))
                    values = model.density(xyz)
                    self.assertTrue(np.all(np.isfinite(values)) and np.all(values>0))
                    if inverted:
                        np.testing.assert_allclose(values,model.density(-xyz),rtol=2e-14,atol=2e-14)

    def test_corrupted_metadata_rejected(self):
        mutations = {
            'schema': 'other', 'dimensions': True, 'winding_ratio': [2,4],
            'averaging': 'independent_phases', 'absolute_frequencies_refined': True,
            'fixed_last_phase_rad': .1, 'pivot_label': 'Cu1',
            'shape_parameter_units': ['radian']*6, 'phases_rad': [.41],
            'orientation_rad': [0,0,.37], 'amplitudes_A': [.1,.09],
        }
        for key,value in mutations.items():
            with self.subTest(key=key),self.assertRaises(ValueError):
                data=lissajous_artifact(2);data[key]=value;CloudModel(data)
        data=lissajous_artifact(3);data['displacement_nodes'][0][0]+=.001
        with self.assertRaises(ValueError):CloudModel(data)

    def test_zero_amplitude_evaluation_is_gaussian_not_free_fit(self):
        data=lissajous_artifact(3)
        data['amplitudes_A']=[0,0,0];data['shape_parameters'][:3]=[0,0,0]
        data['displacement_nodes']=np.zeros((256,3)).tolist()
        data['total_covariance']=copy.deepcopy(data['local_covariance'])
        data['atoms'][0]['total_covariance']=copy.deepcopy(data['local_covariance'])
        model=CloudModel(data)
        np.testing.assert_allclose(model.density(np.zeros((1,3))),[model.norm],rtol=2e-14)


if __name__=='__main__':unittest.main()
