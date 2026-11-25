"""Dimension controls, common scientific settings and explicit launch contracts."""
import os
import unittest
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
from lamagoet_qt.lissajous_options import DEFAULTS, configuration, require_production_route
from lamagoet_qt.options_schema import complete_job_options
from lamagoet_qt.curved_job import validate_options


class LissajousOptionsTest(unittest.TestCase):
    def test_counts_and_units(self):
        for dim, count in [('2',6),('3',8)]:
            x=configuration(dict(LISSAJOUS_DIMENSIONS=dim))
            self.assertEqual(x['shape_parameter_count'],count)
            self.assertEqual(len(x['phases_rad']),int(dim)-1)
            self.assertFalse(x['absolute_frequencies_refined'])
            self.assertEqual(x['averaging'],'one_shared_uniform_phase')

    def test_bad_ratios(self):
        for dim, bad in [('2','2 4'),('2','1.5 2'),('2','1 1'),('2','1 17'),
                         ('3','2 4 6'),('3','1 2'),('3','1 1 2'),('3','0 2 3')]:
            with self.subTest(dim=dim,bad=bad),self.assertRaises(ValueError):
                configuration({'LISSAJOUS_DIMENSIONS':dim,f'LISSAJOUS_RATIO_{dim}D':bad})
        # Triple reduction is a joint gcd, not pairwise coprimality.
        self.assertEqual(configuration({'LISSAJOUS_DIMENSIONS':'3','LISSAJOUS_RATIO_3D':'2 3 4'})['winding_ratio'],[2,3,4])

    def test_invalid_values(self):
        for key,value in [('LISSAJOUS_AMPLITUDES_2D','0 .1'),('LISSAJOUS_AMPLITUDES_2D','nan .1'),
                          ('LISSAJOUS_PHASES_2D','4'),('LISSAJOUS_ORIENTATION','3 3 0')]:
            with self.subTest(key=key),self.assertRaises(ValueError):configuration({key:value})

    def test_required_target_and_common_scope(self):
        for dim in ('2','3'):
            with self.assertRaisesRegex(ValueError,'target atom'):
                validate_options(complete_job_options({'CURVED_MODEL':'lissajous','LISSAJOUS_DIMENSIONS':dim}))
            o=complete_job_options(dict(CURVED_MODEL='lissajous',LISSAJOUS_DIMENSIONS=dim,
                LISSAJOUS_TARGET='Cl1',CURVED_LOCAL_U_CONFIRMED='true',TONTO_REFINEMENT_TARGET='f2'))
            validate_options(o)
            for key,value in [('CURVED_LOCAL_U_CONFIRMED','false'),('TONTO_REFINEMENT_TARGET','f'),
                              ('REFANHARM','true'),('CURVED_ADDITIONAL_TARGETS','[{}]')]:
                with self.subTest(key=key),self.assertRaises(ValueError):validate_options(o|{key:value})

    def test_ui_roundtrip_and_legacy(self):
        from PySide6.QtWidgets import QApplication
        from lamagoet_qt.curved_controls import CurvedControls
        app=QApplication.instance() or QApplication([])
        w=CurvedControls();w.load({'CURVED_MODEL':'lissajous','LISSAJOUS_DIMENSIONS':'3',
                                'LISSAJOUS_TARGET':'Cl1',
                                'LISSAJOUS_AMPLITUDES_3D':'.12 .13 .14'})
        self.assertEqual(w.lissajous.configuration()['target_label'],'Cl1')
        self.assertEqual(w.lissajous.configuration()['amplitudes_A'],[.12,.13,.14])
        self.assertFalse(w.details.isHidden());self.assertFalse(w.lissajous.isHidden())
        self.assertFalse(w.source.isHidden());self.assertFalse(w.local.isHidden())
        self.assertFalse(w.fields['CURVED_OUTPUT'].isHidden())
        self.assertTrue(w.fields['CURVED_PIVOT'].isHidden())
        self.assertTrue(w.additional.isHidden())
        self.assertFalse(w.bounds['CURVED_TIME_LIMIT'].isHidden())
        self.assertTrue(w.lissajous.fields['LISSAJOUS_PHASES_2D'].isHidden())
        w.lissajous.dimensions.setCurrentIndex(0)
        self.assertEqual(w.lissajous.configuration()['shape_parameter_count'],6)
        o=w.values();w.load(o);self.assertEqual(w.values(),o)
        w.model.setCurrentIndex(w.model.findData('free_surface'))
        self.assertTrue(w.lissajous.isHidden());self.assertFalse(w.details.isHidden())
        w.load({'CURVED_MODEL':'off'});self.assertTrue(w.details.isHidden())
        w.close();app.processEvents()


if __name__=='__main__':unittest.main()
