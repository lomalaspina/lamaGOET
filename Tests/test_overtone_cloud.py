"""Independent-axis overtone probability clouds, never legacy Lissajous nodes."""
import unittest
import numpy as np
from Tests.test_adp_cloud import artifact
from lamagoet_qt.adp_cloud import CloudModel
from lamagoet_qt.overtone_cloud import check_overtone_density


def overtone_artifact(dim=3,inverted=False):
    data=artifact();data.pop('pivot_label');data.pop('node_weight');data.pop('displacement_nodes')
    a=np.array([.12,.09,.07])[:dim];d=np.zeros(dim);d[0]=.04
    angle=.27;r=np.array([[np.cos(angle),-np.sin(angle),0],[np.sin(angle),np.cos(angle),0],[0,0,1]])
    var=np.zeros(3);var[:dim]=(a*a+d*d)/2
    total=np.array(data['local_covariance'])+r@np.diag(var)@r.T
    data.update(schema='tonto.independent-overtone-adp',model='independent_axis_overtone',dimensions=dim,
                amplitudes_A=a.tolist(),overtones_A=d.tolist(),orientation_rad=[0,0,angle],
                overtone_enabled=[True]+[False]*(dim-1),phase_order=16,
                shape_parameters=[*a,d[0],0,0,angle],
                shape_parameter_units=['angstrom']*(dim+1)+['radian']*3,
                averaging='independent_uniform_axis_phases',absolute_frequencies_refined=False,
                total_covariance=total.tolist())
    data['atoms'][0]['total_covariance']=total.tolist()
    if inverted:data['site_rotations']=[np.eye(3).tolist(),(-np.eye(3)).tolist()]
    return data


class OvertoneCloudTests(unittest.TestCase):
    def test_moments_and_positive_density(self):
        points=np.random.default_rng(2026).normal(size=(50,3))*.2
        for dim in (2,3):
            for inverted in (False,True):
                model=CloudModel(overtone_artifact(dim,inverted))
                self.assertTrue(np.all(model.density(points)>0))
                k3=np.einsum('ni,nj,nk->ijk',model.nodes,model.nodes,model.nodes)/len(model.nodes)
                axis=np.array([np.cos(.27),np.sin(.27),0])
                expected=np.zeros((3,3,3)) if inverted else .75*.12**2*.04*np.einsum('i,j,k->ijk',axis,axis,axis)
                np.testing.assert_allclose(k3,expected,atol=3e-18)
                check_overtone_density(model,points,model.norm*.1)
                if inverted:np.testing.assert_allclose(model.density(points),model.density(-points),rtol=5e-14)

    def test_zero_overtone_characteristic_is_independent_not_shared(self):
        # Independent absolutely convergent J0 series for these |x|<1
        # probes; the viewer/test suite does not require scipy.
        def j0(x):
            value=term=1.
            for k in range(1,25):
                term*=-(x*x/4)/(k*k);value+=term
            return value
        data=overtone_artifact(3);data['overtones_A'][0]=0;data['shape_parameters'][3]=0
        angle=.27;r=np.array([[np.cos(angle),-np.sin(angle),0],[np.sin(angle),np.cos(angle),0],[0,0,1]])
        total=np.eye(3)*.04+r@np.diag(np.array(data['amplitudes_A'])**2/2)@r.T
        data['total_covariance']=total.tolist();data['atoms'][0]['total_covariance']=total.tolist()
        model=CloudModel(data);q=np.array([3.2,-2.3,1.7])
        actual=np.exp(1j*(model.nodes@q)).mean()
        expected=np.prod([j0(x) for x in (q@r)*np.array(data['amplitudes_A'])])
        self.assertLess(abs(actual-expected),2e-14)

    def test_unresolved_quadrature_rejected(self):
        data=overtone_artifact(2);data['local_covariance']=(np.eye(3)*1e-4).tolist()
        data['amplitudes_A']=[1.,.7];data['shape_parameters'][:2]=[1.,.7]
        angle=.27;r=np.array([[np.cos(angle),-np.sin(angle),0],[np.sin(angle),np.cos(angle),0],[0,0,1]])
        total=np.eye(3)*1e-4+r@np.diag([(1+.04**2)/2,.7**2/2,0])@r.T
        data['total_covariance']=total.tolist();data['atoms'][0]['total_covariance']=total.tolist()
        model=CloudModel(data)
        with self.assertRaisesRegex(ValueError,'phase quadrature did not converge'):
            check_overtone_density(model,model.nodes[:10],model.norm*.1)

    def test_metadata_rejections(self):
        mutations={'averaging':'one_shared_uniform_phase','winding_ratio':[1,2,3],
                   'absolute_frequencies_refined':True,'phase_order':15,'dimensions':True,
                   'overtone_enabled':[1,0,0],'amplitudes_A':[-.12,.09,.07],
                   'overtones_A':[.04,.02,0],'orientation_rad':[0,0,3.2],
                   'displacement_nodes':[[0,0,0]],'node_weight':1}
        for k,v in mutations.items():
            with self.subTest(key=k),self.assertRaises(ValueError):
                data=overtone_artifact();data[k]=v;CloudModel(data)

    def test_surface_mass_and_quadrature(self):
        model=CloudModel(overtone_artifact(2));mesh=model.surface(.5)
        self.assertLess(abs(mesh.integrated_mass-1),2e-4)
        self.assertLess(abs(mesh.enclosed_mass-.5),.003)
        self.assertIsNotNone(mesh.quadrature_relative_change)
        self.assertLess(mesh.quadrature_relative_change,1e-4)


if __name__=='__main__':unittest.main()
