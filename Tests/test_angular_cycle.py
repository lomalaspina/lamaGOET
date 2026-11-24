"""Synthetic file-contract tests, NOT experimental convergence references.

All fixture data are constructed here. No failed calculation is relabelled or
used as a passing reference. The tests check local-vs-total covariance and
joint identity through a HAR-cycle handoff, not an SCF algorithm.
"""
from copy import deepcopy
from dataclasses import replace
import json
from pathlib import Path
import sys
import tempfile
import unittest

import gemmi
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lamagoet_qt.angular_cycle import BOHR, PAIRS, read_accepted_cycle, cycle_shift
from lamagoet_qt.curved_job import make_namelist
from lamagoet_qt.options_schema import OPTION_DEFAULTS


def fixture(path, *, single=False, oblique=True, compact=False):
    cell = gemmi.UnitCell(8.2, 9.1, 10.3, 87 if oblique else 90, 104.2 if oblique else 90, 96 if oblique else 90)
    direct = np.array(cell.orth.mat)
    inverse = np.linalg.inv(direct)
    norms = np.linalg.norm(inverse, axis=1)
    frac = np.array([[.2, .3, .4], [.1, .3, .4], [.2, .4, .4]])
    labels = ["O1", "H1", "H2"]
    local = np.array([np.eye(3)*.01, [[.02, .003, -.001], [.003, .03, .002], [-.001, .002, .04]], np.eye(3)*.025])
    nodes = np.array([[.1, 0, 0], [-.1, 0, 0], [0, .07, 0], [0, -.07, 0]])
    total = local.copy()
    target_indices = [1] if single else [1, 2]
    for i in target_indices:
        total[i] += nodes.T @ nodes / len(nodes)
    atoms = [dict(label=label, element="O" if i==0 else "H", mean_cartesian=(direct @ frac[i]).tolist(),
                  fractional=frac[i].tolist(), total_covariance=total[i].tolist(), occupancy=1.)
             for i, label in enumerate(labels)]
    configs = []
    for i in target_indices:
        params = [.11, .02, -.03, .07, -.01, .02, .21] if i==1 else [.09, -.02, .01, -.3]
        if compact: params=[.11,.07,.21]
        model = dict(schema="tonto.curved-adp", version=1, length_unit="angstrom", fit_status="converged",
                     electronic_model="synthetic_file_contract_NOT_experimental",
                     model="harmonic_surface" if compact else "transverse_surface" if i==1 else "planar_arc", parameters_rad=params,
                     reference_cartesian=[0., 0., 1.], pivot_shift_cartesian=[0., 0., 0.],
                     cell_direct=direct.tolist(), spacegroup_number=1,
                     spacegroup_operations=[np.eye(4).tolist()], target_label=labels[i], pivot_label="O1",
                     mean_cartesian=atoms[i]["mean_cartesian"], pivot_cartesian=atoms[0]["mean_cartesian"],
                     local_covariance=local[i].tolist(), total_covariance=total[i].tolist(),
                     site_rotations=[np.eye(3).tolist()], displacement_nodes=nodes.tolist(), node_weight=.25, atoms=atoms)
        name = "curved.model.json" if single else f"curved.target-{i}.json"
        (path/name).write_text(json.dumps(model))
        configs.append(dict(target_label=labels[i], model_file=name))
    if not single:
        (path/"curved.model.json").write_text(json.dumps(dict(schema="tonto.multi-angular-adp", version=1, targets=configs)))
    (path/"curved.summary").write_text("status converged\nintensity_scale 1.03\n")
    first_count=3 if compact else 7;second_count=3 if compact else 4
    dim = 27+first_count+(0 if single else second_count)+1
    cov = np.eye(dim)*.001
    if not single:
        cov[27,27+first_count]=cov[27+first_count,27]=.0003
    with (path/"curved.covariance").open("w") as stream:
        for i,label in enumerate(labels,1): stream.write(f"# atom {i} {label}\n")
        stream.write(f"# angular target H1 first 28 last {27+first_count}\n")
        if not single: stream.write(f"# angular target H2 first {28+first_count} last {27+first_count+second_count}\n")
        np.savetxt(stream,cov,fmt="%.17g")
    doc = gemmi.cif.Document(); block = doc.add_new_block("synthetic_display_TOTAL_U")
    for tag,value in zip(("length_a","length_b","length_c","angle_alpha","angle_beta","angle_gamma"),cell.parameters):
        block.set_pair("_cell_"+tag,f"{value:.17g}")
    block.set_pair("_space_group_IT_number","1")
    block.init_loop("_space_group_symop_",["operation_xyz"]).add_row(["'x,y,z'"])
    site=block.init_loop("_atom_site_",["label","type_symbol","fract_x","fract_y","fract_z","U_iso_or_equiv","adp_type","occupancy"])
    for i,atom in enumerate(atoms):
        site.add_row([atom['label'],atom['element'],*(f"{v:.17g}" for v in frac[i]),f"{np.trace(total[i])/3:.17g}","Uiso" if i==0 else "Uani","1"])
    aniso=block.init_loop("_atom_site_aniso_",["label","U_11","U_22","U_33","U_12","U_13","U_23"])
    for i in (1,2):
        u=(inverse@total[i]@inverse.T)/np.outer(norms,norms)
        aniso.add_row([labels[i],*(f"{u[a,b]:.17g}" for a,b in PAIRS)])
    doc.write_file(str(path/"curved.cif"))
    return local, total, cov


class CycleTest(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.root=Path(self.temp.name)

    def tearDown(self): self.temp.cleanup()

    def test_local_and_angular_state_roundtrip(self):
        for single,oblique in ((True,False),(True,True),(False,False),(False,True)):
            with self.subTest(single=single,oblique=oblique):
                folder=self.root/f'{single}-{oblique}';folder.mkdir()
                local,total,cov=fixture(folder,single=single,oblique=oblique)
                before={p.name:p.read_bytes() for p in folder.iterdir()}
                state=read_accepted_cycle(folder)
                block=gemmi.cif.read_string(state.geometry_cif).sole_block()
                cell=gemmi.UnitCell(*(float(block.find_value('_cell_'+x)) for x in
                                     ('length_a','length_b','length_c','angle_alpha','angle_beta','angle_gamma')))
                direct=np.array(cell.orth.mat); norm=np.linalg.norm(np.linalg.inv(direct),axis=1)
                for row in block.find('_atom_site_aniso_', ['label','U_11','U_22','U_33','U_12','U_13','U_23']):
                    i=state.labels.index(row[0]);ucif=np.zeros((3,3))
                    for k,(a,b) in enumerate(PAIRS,1):ucif[a,b]=ucif[b,a]=float(row[k])
                    recovered=direct@(ucif*np.outer(norm,norm))@direct.T
                    np.testing.assert_allclose(recovered,local[i],rtol=2e-14,atol=2e-16)
                np.testing.assert_allclose(state.parameters[:27].reshape(3,9)[:,3:]*BOHR**2,
                                           [[u[a,b] for a,b in PAIRS] for u in local],rtol=2e-14,atol=2e-16)
                np.testing.assert_array_equal(state.covariance,cov)
                if not single:self.assertNotEqual(state.covariance[27,34],0)
                options=dict(OPTION_DEFAULTS,CURVED_MODEL='surface',CURVED_ELECTRONIC_SOURCE='molecular_hirshfeld',CURVED_AUTO_GEOMETRY='true')
                text=make_namelist(options,state.targets)
                self.assertIn('target_transverse_1(:,1)=0.11,0.02',text)
                self.assertNotIn('target_transverse_1(:,1)=0.05',text)
                self.assertFalse(state.provenance['outer_convergence_claim'])
                self.assertEqual(cycle_shift(state,state)['max_shift_over_esd'],0.)
                self.assertEqual(before,{p.name:p.read_bytes() for p in folder.iterdir()})

    def test_failed_status_cannot_advance(self):
        fixture(self.root)
        for status in ('not_converged','fixed_parameter_evaluation'):
            (self.root/'curved.summary').write_text(f'status {status}\nintensity_scale 1.03\n')
            with self.assertRaisesRegex(ValueError,'converged'):read_accepted_cycle(self.root)

    def test_corrupt_identity_and_covariance_rejected(self):
        fixture(self.root)
        file=self.root/'curved.target-1.json';base=json.loads(file.read_text())
        for key,value in (('fit_status','not_converged'),('pivot_label','absent'),('target_label','H2'),
                          ('local_covariance', [[-.01,0,0],[0,.02,0],[0,0,.03]])):
            data=deepcopy(base);data[key]=value;file.write_text(json.dumps(data))
            with self.assertRaises(ValueError):read_accepted_cycle(self.root)
        file.write_text(json.dumps(base))
        covfile=self.root/'curved.covariance';text=covfile.read_text()
        covfile.write_text(text.replace('# atom 1 O1','# atom 1 H2'))
        with self.assertRaisesRegex(ValueError,'ordering'):read_accepted_cycle(self.root)
        covfile.write_text(text.replace('# angular target H2 first 35','# angular target H1 first 35'))
        with self.assertRaisesRegex(ValueError,'ordering'):read_accepted_cycle(self.root)

    def test_covariance_aware_cycle_diagnostic(self):
        fixture(self.root);state=read_accepted_cycle(self.root)
        moved=replace(state,parameters=state.parameters.copy())
        moved.parameters[27]+=.002;moved.parameters[34]-=.003
        result=cycle_shift(state,moved)
        delta=moved.parameters-state.parameters
        self.assertAlmostEqual(result['joint_mahalanobis_shift'],np.sqrt(delta@np.linalg.solve(state.covariance,delta)))
        self.assertAlmostEqual(result['max_shift_over_esd'],.003/np.sqrt(.001))
        self.assertFalse(result['outer_convergence_claim'])
        with self.assertRaisesRegex(ValueError,'identities'):cycle_shift(state,replace(moved,labels=list(reversed(state.labels))))
        changed=deepcopy(moved);changed.targets[0]['pivot']='H2'
        with self.assertRaisesRegex(ValueError,'frame'):cycle_shift(state,changed)
        changed=deepcopy(moved);changed.covariance[0,:]=0;changed.covariance[:,0]=0;changed.parameters[0]+=.01
        with self.assertRaisesRegex(ValueError,'zero-variance'):cycle_shift(state,changed)

    def test_narrow_legacy_single_target_compatibility(self):
        fixture(self.root,single=True)
        file=self.root/'curved.covariance'
        header='# Order: each labelled atom x y z U11 U22 U33 U12 U13 U23 (bohr,bohr^2); angular radians; intensity scale\n'
        file.write_text(header+file.read_text().replace('# angular target H1 first 28 last 34\n',''))
        self.assertTrue(read_accepted_cycle(self.root).provenance['legacy_single_target_covariance'])
        file.write_text(file.read_text().replace(header,''))
        with self.assertRaisesRegex(ValueError,'ordering'):read_accepted_cycle(self.root)

    def test_compact_cycle_preserves_fitted_values_with_auto_disabled(self):
        for single in (True,False):
            path=self.root/str(single);path.mkdir();fixture(path,single=single,compact=True)
            state=read_accepted_cycle(path)
            self.assertEqual(state.targets[0]['model'],'harmonic_surface')
            self.assertEqual(state.targets[0]['transverse_1'],'0.11 0 0')
            self.assertEqual(state.targets[0]['transverse_2'],'0.070000000000000007 0 0')
            self.assertEqual(len(state.parameters),27+(3 if single else 6)+1)
            options=dict(OPTION_DEFAULTS,CURVED_MODEL='harmonic_surface',CURVED_AUTO_GEOMETRY='false')
            text=make_namelist(options,state.targets)
            self.assertIn('target_transverse_1(:,1)=0.11,0,0',text)
            self.assertIn("target_labels(1)='H1'",text)
            self.assertEqual(cycle_shift(state,state)['max_shift_over_esd'],0)


if __name__=='__main__':unittest.main()
