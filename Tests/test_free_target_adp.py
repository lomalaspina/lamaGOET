"""Target-only controls, without a bond assumption or changed ordinary jobs."""
import json,os,sys,unittest
from pathlib import Path
from unittest.mock import patch
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from PySide6.QtWidgets import QApplication,QComboBox,QDialog
from lamagoet_qt.curved_controls import CurvedControls
from lamagoet_qt.curved_job import angular_targets,resolve_angular_geometry,validate_options,make_namelist
from lamagoet_qt.options_schema import OPTION_DEFAULTS
from lamagoet_qt.crystal import AtomSite,Cell,CrystalStructure,_symmetry_operation

class FreeTargetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.app=QApplication.instance() or QApplication([])
    def setUp(self):
        self.options=dict(OPTION_DEFAULTS,CURVED_MODEL='free_surface',CURVED_TARGET='O6',
            CURVED_LOCAL_U_CONFIRMED='true',TONTO_REFINEMENT_TARGET='f2')
        self.widget=CurvedControls();self.widget.load(self.options)
    def tearDown(self):self.widget.deleteLater()
    def structure(self):
        return CrystalStructure(Cell.from_parameters(10,10,10,90,90,90),
            [AtomSite('O6','O',(.2,.2,.2)),AtomSite('H6A','H',(.1,.2,.2)),AtomSite('H6B','H',(.2,.3,.2)),
             AtomSite('Na1','Na',(.7,.7,.7))],[_symmetry_operation('x,y,z')])
    def test_target_only_does_not_consult_bonds(self):
        with patch('lamagoet_qt.curved_job.angular_bond_candidates',side_effect=AssertionError('must not infer a bond')):
            rows=resolve_angular_geometry(self.options,self.structure())
        self.assertEqual(rows[0]['pivot'],'');validate_options(self.options)
        text=make_namelist(self.options,rows)
        self.assertIn("target_models(1)='free_surface'",text)
        self.assertIn('target_mean_lengths_angstrom(1)=1,',text)
        self.assertIn('target_orientation_vectors(:,1)=0,0,0,',text)
        self.assertNotIn('target_references',text);self.assertNotIn('target_pivot_shifts',text)
        self.assertNotIn('target_plane_angles',text)
    def test_only_target_needed_with_auto_off_too(self):
        o=dict(self.options,CURVED_AUTO_GEOMETRY='false',CURVED_DEFAULT_STARTS='false')
        validate_options(o);self.assertIn("pivot_labels(1)=''",make_namelist(o))
    def test_nonterminal_and_isolated_atoms_are_allowed(self):
        for name in ('O6','Na1'):
            with self.subTest(name=name):
                rows=resolve_angular_geometry(dict(self.options,CURVED_TARGET=name),self.structure())
                self.assertEqual(rows[0]['target'],name);self.assertEqual(rows[0]['pivot'],'')
    def test_legacy_bond_settings_do_not_leak_into_free_input(self):
        o=dict(self.options,CURVED_PIVOT='H6A',CURVED_REFERENCE='0 0 0',CURVED_PIVOT_SHIFT='NaN 0 0',CURVED_PLANE_ANGLE='invalid')
        validate_options(o);self.assertEqual(angular_targets(o)[0]['reference'],'0 0 1')
        self.assertNotIn('H6A',make_namelist(o))
    def test_manual_orientation_length_and_angular_starts_survive(self):
        o=dict(self.options,CURVED_DEFAULT_STARTS='false',CURVED_ORIENTATION='.2 -.1 .3',CURVED_MEAN_LENGTH='.8',
               CURVED_TRANSVERSE_1='.12 .03 -.01')
        self.widget.load(o);self.widget.load(self.widget.values())
        rows=angular_targets(self.widget.values())
        self.assertEqual(rows[0]['orientation'],'.2 -.1 .3');self.assertEqual(rows[0]['mean_length'],'.8')
        self.assertIn('target_mean_lengths_angstrom(1)=0.80000000000000004',make_namelist(o))
    def test_invalid_charts_rejected(self):
        for key,value in (('CURVED_ORIENTATION','3.141592653589793 0 0'),('CURVED_ORIENTATION','NaN 0 0'),
                          ('CURVED_MEAN_LENGTH','0'),('CURVED_MEAN_LENGTH','-1'),('CURVED_MEAN_LENGTH','1e100')):
            with self.subTest(key=key,value=value),self.assertRaises(ValueError):
                validate_options(dict(self.options,CURVED_DEFAULT_STARTS='false',**{key:value}))
    def test_free_control_hides_every_bond_setting(self):
        w=self.widget;w.advanced.setChecked(True)
        for key in ('CURVED_PIVOT','CURVED_REFERENCE','CURVED_PIVOT_SHIFT','CURVED_PLANE_ANGLE'):
            self.assertTrue(w.fields[key].isHidden())
        for key in ('CURVED_ORIENTATION','CURVED_MEAN_LENGTH'):
            self.assertFalse(w.fields[key].isHidden())
        self.assertTrue(w.auto_geometry.isHidden());self.assertEqual(w.choose_button.text(),'Choose target atom…')
        for col in (1,5,6,7):self.assertTrue(w.additional.isColumnHidden(col))
    def test_advanced_layout_does_not_overlap(self):
        w=self.widget;w.resize(1250,600);w.show();w.advanced.setChecked(True)
        self.app.processEvents();self.app.processEvents()
        table=w.additional.geometry()
        self.assertGreaterEqual(w.local.geometry().top(),table.bottom())
        self.assertGreaterEqual(w.scope_note.geometry().top(),w.starts_note.geometry().bottom())
    def test_atom_chooser_has_no_pivot(self):
        w=self.widget;w.structure_loader=self.structure
        def choose(dialog):
            combos=dialog.findChildren(QComboBox);self.assertEqual(len(combos),1)
            combos[0].setCurrentText('Na1');return QDialog.DialogCode.Accepted
        with patch.object(QDialog,'exec',choose):w.choose_bond()
        self.assertEqual(w.fields['CURVED_TARGET'].text(),'Na1')
    def test_additional_free_targets_and_mixed_models(self):
        row=dict(target='Na1',model='free_surface',orientation='.1 .2 .3',mean_length='.9')
        o=dict(self.options,CURVED_DEFAULT_STARTS='false',CURVED_ADDITIONAL_TARGETS=json.dumps([row]))
        rows=angular_targets(o);self.assertEqual(len(rows),2);self.assertEqual(rows[1]['pivot'],'')
        self.widget.load(o)
        self.assertEqual(angular_targets(self.widget.values()),rows)
        second=dict(target='H6A',pivot='O6',model='surface',transverse_1='.12 .02 .01',transverse_2='.08 .03 .01',
                    plane_angle='0',reference='0 0 1',pivot_shift='0 0 0')
        o['CURVED_ADDITIONAL_TARGETS']=json.dumps([second])
        resolved=resolve_angular_geometry(o,self.structure())
        self.assertEqual(resolved[0]['pivot'],'');self.assertEqual(resolved[1]['pivot'],'O6')
        text=make_namelist(o,resolved)
        self.assertNotIn('target_references(:,1)',text);self.assertIn('target_references(:,2)',text)
    def test_ordinary_default_is_still_off(self):self.assertEqual(OPTION_DEFAULTS['CURVED_MODEL'],'off')

if __name__=='__main__':unittest.main()
