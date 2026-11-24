"""Automatic setup chooses a frame/image, never an ambiguous physical model."""
import json
from pathlib import Path
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import numpy as np
from lamagoet_qt.curved_job import resolve_angular_geometry,make_namelist,validate_options,angular_bond_candidates
from lamagoet_qt.options_schema import OPTION_DEFAULTS,complete_job_options
from lamagoet_qt.crystal import Cell,AtomSite,CrystalStructure,_symmetry_operation

class AutoGeometryTests(unittest.TestCase):
    def options(self,**kwargs):
        return dict(OPTION_DEFAULTS,CURVED_MODEL='surface',CURVED_TARGET='H6A',CURVED_PIVOT='',
                    CURVED_AUTO_GEOMETRY='true',CURVED_LOCAL_U_CONFIRMED='true',TONTO_REFINEMENT_TARGET='f2',**kwargs)
    def structure(self,atoms,operations=('x,y,z',),angles=(90,90,90)):
        return CrystalStructure(Cell.from_parameters(10,10,10,*angles),
                                [AtomSite(label,element,xyz) for label,element,xyz in atoms],
                                [_symmetry_operation(op) for op in operations])
    def water(self):
        return self.structure([('O6','O',(.2,.2,.2)),('H6A','H',(.1,.2,.2)),('H6B','H',(.2,.3,.2))])
    def test_unique_terminal_target_only(self):
        o=self.options();validate_options(o)
        rows=resolve_angular_geometry(o,self.water())
        self.assertEqual(rows[0]['pivot'],'O6')
        self.assertEqual(rows[0]['pivot_shift'],'0 0 0')
        self.assertEqual(rows[0]['reference'],'0 1 0')
        self.assertIn("pivot_labels(1)='O6'",make_namelist(o,rows))
        with self.assertRaises(ValueError):make_namelist(o)
    def test_ambiguous_water_oxygen(self):
        o=self.options();o['CURVED_TARGET']='O6'
        with self.assertRaisesRegex(ValueError,'ambiguous'):resolve_angular_geometry(o,self.water())
    def test_explicit_pivot_resolves_choice(self):
        o=self.options();o.update(CURVED_TARGET='O6',CURVED_PIVOT='H6A')
        self.assertEqual(resolve_angular_geometry(o,self.water())[0]['pivot'],'H6A')
    def test_lattice_boundary_and_oblique_cell(self):
        o=self.options()
        for angles in ((90,90,90),(90,103,90)):
            structure=self.structure([('H6A','H',(.96,.2,.2)),('O6','O',(.06,.2,.2))],angles=angles)
            row=resolve_angular_geometry(o,structure)[0]
            self.assertTrue(np.allclose(list(map(float,row['pivot_shift'].split())),[10,0,0]))
    def test_rotated_symmetry_mate_rejected(self):
        structure=self.structure([('H6A','H',(.05,.2,.2)),('O6','O',(.85,.8,.8))],('x,y,z','-x,-y,-z'))
        with self.assertRaisesRegex(ValueError,'rotated symmetry mate'):resolve_angular_geometry(self.options(),structure)
    def test_two_targets_share_oxygen(self):
        o=self.options()
        o['CURVED_ADDITIONAL_TARGETS']=json.dumps([dict(target='H6B',pivot='',model='surface',
            transverse_1='.05 0 0',transverse_2='.03 0 0',plane_angle='0',reference='0 0 1',pivot_shift='0 0 0')])
        rows=resolve_angular_geometry(o,self.water())
        self.assertEqual([r['pivot'] for r in rows],['O6','O6'])
        self.assertEqual([r['target'] for r in rows],['H6A','H6B'])
    def test_legacy_explicit_geometry_preserved(self):
        old=complete_job_options({'CURVED_MODEL':'surface','CURVED_TARGET':'H6A','CURVED_PIVOT':'O6',
                                  'CURVED_REFERENCE':'1 2 3','CURVED_PIVOT_SHIFT':'4 5 6'})
        self.assertEqual(old['CURVED_AUTO_GEOMETRY'],'false')
        self.assertEqual(old['CURVED_DEFAULT_STARTS'],'false')
        rows=resolve_angular_geometry(old,self.water())
        self.assertEqual(rows[0]['reference'],'1 2 3');self.assertEqual(rows[0]['pivot_shift'],'4 5 6')
        self.assertEqual(complete_job_options({})['CURVED_AUTO_GEOMETRY'],'true')

    def test_compact_harmonic_setup_and_no_silent_truncation(self):
        o=self.options();o['CURVED_MODEL']='harmonic_surface'
        validate_options(o)
        rows=resolve_angular_geometry(o,self.water())
        self.assertEqual(rows[0]['transverse_1'],'0.05 0 0')
        self.assertEqual(rows[0]['transverse_2'],'0.03 0 0')
        self.assertIn("target_models(1)='harmonic_surface'",make_namelist(o,rows))
        o.update(CURVED_AUTO_GEOMETRY='false',CURVED_DEFAULT_STARTS='false',CURVED_PIVOT='O6',CURVED_TRANSVERSE_1='.05 .01 0')
        with self.assertRaisesRegex(ValueError,'T2=T3'):validate_options(o)
        o.update(CURVED_TRANSVERSE_1='.05 0 0',CURVED_TRANSVERSE_2='.03 0 0')
        validate_options(o)

    def test_editable_starts_keep_automatic_geometry(self):
        o=self.options();o.update(CURVED_DEFAULT_STARTS='false',CURVED_TRANSVERSE_1='.09 -.02 .008',
                                 CURVED_TRANSVERSE_2='.04 .009 -.003',CURVED_PLANE_ANGLE='.3')
        rows=resolve_angular_geometry(o,self.water())
        self.assertEqual(rows[0]['pivot'],'O6')
        self.assertEqual(rows[0]['reference'],'0 1 0')
        self.assertEqual(rows[0]['transverse_1'],'.09 -.02 .008')
        self.assertEqual(rows[0]['transverse_2'],'.04 .009 -.003')
        self.assertEqual(rows[0]['plane_angle'],'.3')
        self.assertIn('target_plane_angles(1)=0.299',make_namelist(o,rows))
        o['CURVED_MODEL']='harmonic_surface'
        with self.assertRaisesRegex(ValueError,'T2=T3'):validate_options(o)

    def test_default_starts_independent_of_manual_geometry(self):
        o=self.options();o.update(CURVED_AUTO_GEOMETRY='false',CURVED_PIVOT='O6',CURVED_REFERENCE='1 2 3',
                                 CURVED_PIVOT_SHIFT='4 5 6',CURVED_DEFAULT_STARTS='true')
        row=resolve_angular_geometry(o,self.water())[0]
        self.assertEqual(row['reference'],'1 2 3');self.assertEqual(row['pivot_shift'],'4 5 6')
        self.assertEqual(row['transverse_1'],'0.05 0.01 0.005')
        self.assertIn('target_transverse_1(:,1)=0.050',make_namelist(o))

    def test_legacy_automatic_job_retains_old_defaults(self):
        o=complete_job_options({'CURVED_MODEL':'surface','CURVED_AUTO_GEOMETRY':'true','CURVED_TARGET':'H6A'})
        self.assertEqual(o['CURVED_DEFAULT_STARTS'],'true')
        self.assertEqual(resolve_angular_geometry(o,self.water())[0]['transverse_1'],'0.05 0.01 0.005')

    def test_full_connectivity_not_terminal_or_element_filtered(self):
        candidates=angular_bond_candidates(self.water(),'O6')
        self.assertEqual([r['pivot'] for r in candidates],['H6A','H6B'])
        self.assertTrue(all(r['supported'] for r in candidates))
        # Four bonds about a central carbon; any explicit reference is allowed,
        # but the software must not select one merely because it sorts first.
        xyz=np.array([.5,.5,.5]);delta=.109/np.sqrt(3)
        atoms=[('C1','C',tuple(xyz))]+[(f'H{i}','H',tuple(xyz+delta*np.array(v)))
            for i,v in enumerate([(1,1,1),(-1,-1,1),(1,-1,-1),(-1,1,-1)],1)]
        structure=self.structure(atoms)
        self.assertEqual(len(angular_bond_candidates(structure,'C1')),4)
        o=self.options();o.update(CURVED_TARGET='C1')
        with self.assertRaisesRegex(ValueError,'ambiguous'):resolve_angular_geometry(o,structure)
        for pivot in ('H1','H2','H3','H4'):
            o['CURVED_PIVOT']=pivot
            self.assertEqual(resolve_angular_geometry(o,structure)[0]['pivot'],pivot)

    def test_no_bond_and_duplicate_images_do_not_invent_a_pivot(self):
        structure=self.structure([('He1','He',(.5,.5,.5))])
        self.assertEqual(angular_bond_candidates(structure,'He1'),[])
        o=self.options();o['CURVED_TARGET']='He1'
        with self.assertRaisesRegex(ValueError,'absent'):resolve_angular_geometry(o,structure)
        structure=self.structure([('H6A','H',(0,0,0)),('O6','O',(.1,0,0))],('x,y,z','-x,-y,-z'))
        self.assertEqual(len(angular_bond_candidates(structure,'H6A')),2)
        o=self.options();o['CURVED_PIVOT']='O6'
        with self.assertRaisesRegex(ValueError,'ambiguous'):resolve_angular_geometry(o,structure)

if __name__=='__main__':unittest.main()
