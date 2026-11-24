"""Automatic setup chooses a frame/image, never an ambiguous physical model."""
import json
from pathlib import Path
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import numpy as np
from lamagoet_qt.curved_job import resolve_angular_geometry,make_namelist,validate_options
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
        o.update(CURVED_AUTO_GEOMETRY='false',CURVED_PIVOT='O6',CURVED_TRANSVERSE_1='.05 .01 0')
        with self.assertRaisesRegex(ValueError,'T2=T3'):validate_options(o)
        o.update(CURVED_TRANSVERSE_1='.05 0 0',CURVED_TRANSVERSE_2='.03 0 0')
        validate_options(o)

if __name__=='__main__':unittest.main()
