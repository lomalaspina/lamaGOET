"""Editable seeds remain separate from automatically inferred bond geometry."""
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from PySide6.QtCore import Qt
from PySide6.QtWidgets import QApplication,QComboBox,QDialog,QDialogButtonBox,QLabel
from lamagoet_qt.curved_controls import CurvedControls
from lamagoet_qt.curved_job import angular_targets
from lamagoet_qt.options_schema import OPTION_DEFAULTS
from lamagoet_qt.crystal import Cell,AtomSite,CrystalStructure,_symmetry_operation

class ControlsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.app=QApplication.instance() or QApplication([])
    def setUp(self):
        self.widget=CurvedControls()
        self.widget.load(dict(OPTION_DEFAULTS,CURVED_MODEL='surface'))
    def tearDown(self):self.widget.deleteLater()
    def water(self):
        return CrystalStructure(Cell.from_parameters(10,10,10,90,90,90),
            [AtomSite('O6','O',(.2,.2,.2)),AtomSite('H6A','H',(.1,.2,.2)),AtomSite('H6B','H',(.2,.3,.2))],
            [_symmetry_operation('x,y,z')])
    def test_defaults_and_independent_manual_starts(self):
        w=self.widget
        self.assertTrue(w.auto_geometry.isChecked());self.assertTrue(w.default_starts.isChecked())
        self.assertTrue(w.fields['CURVED_TRANSVERSE_1'].isHidden())
        w.default_starts.setChecked(False)
        self.assertTrue(w.auto_geometry.isChecked())
        self.assertFalse(w.fields['CURVED_TRANSVERSE_1'].isHidden())
        self.assertTrue(w.fields['CURVED_TRANSVERSE_1'].isEnabled())
        self.assertFalse(w.fields['CURVED_REFERENCE'].isEnabled())
        w.fields['CURVED_TRANSVERSE_1'].setText('.09 -.02 .008')
        w.fields['CURVED_PLANE_ANGLE'].setText('.3')
        options=w.values();w.load(options)
        self.assertEqual(w.fields['CURVED_TRANSVERSE_1'].text(),'.09 -.02 .008')
        self.assertEqual(w.fields['CURVED_PLANE_ANGLE'].text(),'.3')
        w.default_starts.setChecked(True)
        self.assertEqual(w.fields['CURVED_TRANSVERSE_1'].text(),'0.05 0.01 0.005')
    def test_default_display_and_written_values_match_model(self):
        w=self.widget;w.fields['CURVED_TARGET'].setText('H6A')
        for model in ('harmonic_surface','planar','surface'):
            w.model.setCurrentIndex(w.model.findData(model))
            row=angular_targets(w.values())[0]
            self.assertEqual(w.fields['CURVED_TRANSVERSE_1'].text(),row['transverse_1'])
            self.assertEqual(w.fields['CURVED_TRANSVERSE_2'].text(),row['transverse_2'])
    def test_additional_target_does_not_inherit_unrelated_pivot(self):
        w=self.widget;w.fields['CURVED_PIVOT'].setText('Cu1');w.add_target()
        self.assertEqual(w.additional.item(0,1).text(),'')
        self.assertFalse(w.additional.item(0,3).flags() & Qt.ItemFlag.ItemIsEditable)
        w.default_starts.setChecked(False)
        self.assertTrue(w.additional.item(0,3).flags() & Qt.ItemFlag.ItemIsEditable)
        self.assertFalse(w.additional.item(0,6).flags() & Qt.ItemFlag.ItemIsEditable)
    def test_legacy_manual_coefficients_are_not_reset_by_load(self):
        old=dict(CURVED_MODEL='surface',CURVED_TARGET='H6A',CURVED_PIVOT='O6',
                 CURVED_TRANSVERSE_1='.12 -.03 .001',CURVED_PLANE_ANGLE='.8')
        w=self.widget;w.load(old)
        self.assertFalse(w.default_starts.isChecked());self.assertFalse(w.auto_geometry.isChecked())
        self.assertEqual(w.fields['CURVED_TRANSVERSE_1'].text(),'.12 -.03 .001')
        self.assertEqual(w.fields['CURVED_PLANE_ANGLE'].text(),'.8')
    def test_nonterminal_selection_requires_choice_then_resolves(self):
        w=self.widget;w.structure_loader=self.water
        def choose(dialog):
            target,pivot=dialog.findChildren(QComboBox)
            target.setCurrentText('O6')
            ok=dialog.findChild(QDialogButtonBox).button(QDialogButtonBox.StandardButton.Ok)
            self.assertIsNone(pivot.currentData());self.assertFalse(ok.isEnabled())
            pivot.setCurrentIndex(pivot.findData('H6B'))
            self.assertTrue(ok.isEnabled())
            return QDialog.DialogCode.Accepted
        with patch.object(QDialog,'exec',choose):w.choose_bond()
        self.assertEqual(w.fields['CURVED_TARGET'].text(),'O6')
        self.assertEqual(w.fields['CURVED_PIVOT'].text(),'H6B')
    def test_additional_target_chooser(self):
        w=self.widget;w.structure_loader=self.water;w.add_target()
        def choose(dialog):
            target,pivot=dialog.findChildren(QComboBox)
            target.setCurrentText('H6A')
            self.assertEqual(pivot.currentData(),'O6')
            return QDialog.DialogCode.Accepted
        with patch.object(QDialog,'exec',choose):w.choose_bond(0)
        row=json.loads(w.values()['CURVED_ADDITIONAL_TARGETS'])[0]
        self.assertEqual((row['target'],row['pivot']),('H6A','O6'))
    def test_input_loader_uses_job_path_not_viewer_structure(self):
        from lamagoet_qt.main_window import MainWindow
        with tempfile.TemporaryDirectory() as temp:
            stub=SimpleNamespace(cif_path=SimpleNamespace(text=lambda:'input.cif'),option_path=Path(temp)/'job_options.txt')
            with patch('lamagoet_qt.main_window.CrystalStructure.from_cif',return_value=self.water()) as read:
                MainWindow._angular_input_structure(stub)
                read.assert_called_once_with(Path(temp)/'input.cif')

if __name__=='__main__':unittest.main()
