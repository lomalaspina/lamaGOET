"""Positive-model selectors, persistence, native mapping and fail-closed runner."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
from lamagoet_qt.positive_options import configuration,make_namelist
from lamagoet_qt.curved_job import validate_options,prepare,run
from lamagoet_qt.options_schema import complete_job_options
from lamagoet_qt.job_options import save_job_options,load_job_options

class PositiveOptionsTest(unittest.TestCase):
    def options(self,model='shared_u_mixture',**kw):
        return complete_job_options(dict(CURVED_MODEL=model,POSITIVE_TARGET='C1',CURVED_LOCAL_U_CONFIRMED='true',
            TONTO_REFINEMENT_TARGET='f2',FCUT='0',CIF=str(Path(__file__).parent/'inputs/calc.cif'),HKL='data.hkl',TONTO='/bin/true')|kw)
    def test_mapping_and_roundtrip(self):
        for model,dim,count in [('shared_u_mixture','3',4),('independent_overtone','2',6),('independent_overtone','3',7)]:
            o=self.options(model,OVERTONE_DIMENSIONS=dim)
            validate_options(o);c=configuration(o)
            self.assertEqual(c['shape_parameter_count'],count)
            nml=make_namelist(o);self.assertIn('&positive_adp',nml)
            self.assertNotIn('pivot',nml);self.assertNotIn('winding',nml);self.assertNotIn('phases_rad',nml)
            with tempfile.TemporaryDirectory() as d:
                p=Path(d)/'options';save_job_options(p,o)
                self.assertEqual(make_namelist(load_job_options(p)),nml)
    def test_special_points_not_assumed_singular(self):
        c=configuration(self.options(MIXTURE_POPULATION='.5'));self.assertEqual(c['population'],.5)
        c=configuration(self.options('independent_overtone',OVERTONE_COEFFICIENTS_3D='0 0 0'))
        self.assertEqual(c['overtones_A'],[0,0,0])
        c=configuration(self.options('independent_overtone',OVERTONE_AMPLITUDES_3D='0 .02 .03'))
        self.assertEqual(c['amplitudes_A'][0],0)  # Actual native rank decides; no GUI ESD.
    def test_invalid_inputs(self):
        for model,key,value in [
          ('shared_u_mixture','MIXTURE_POPULATION','0'),('shared_u_mixture','MIXTURE_POPULATION','1'),
          ('shared_u_mixture','MIXTURE_POPULATION','nan'),('shared_u_mixture','MIXTURE_AUTO_DIRECTION','yes'),
          ('shared_u_mixture','MIXTURE_SEPARATION','1 2'),
          ('independent_overtone','OVERTONE_DIMENSIONS','4'),
          ('independent_overtone','OVERTONE_AMPLITUDES_3D','-.1 .2 .3'),
          ('independent_overtone','OVERTONE_COEFFICIENTS_3D','.1 .1 0'),
          ('independent_overtone','OVERTONE_ORIENTATION','4 0 0'),
          ('independent_overtone','OVERTONE_ENABLED_3D','true no false')]:
            with self.subTest(key=key,value=value),self.assertRaises(ValueError):configuration(self.options(model,**{key:value}))
    def test_scope(self):
        for model in ('shared_u_mixture','independent_overtone'):
            for key,value in [('POSITIVE_TARGET',''),('REFANHARM','true'),('CURVED_LOCAL_U_CONFIRMED','false'),
                              ('CURVED_ADDITIONAL_TARGETS','[{}]'),('TONTO_REFINEMENT_TARGET','f'),
                              ('H_POSITION_MODEL','riding'),('XCW','true'),('EXTI','true')]:
                with self.subTest(model=model,key=key),self.assertRaises(ValueError):validate_options(self.options(model,**{key:value}))
    def test_prepare_and_input_preservation(self):
        for model in ('shared_u_mixture','independent_overtone'):
            with tempfile.TemporaryDirectory() as d:
                p=Path(d)/'options';(Path(d)/'data.hkl').write_text('1 2 3 -4 2\n')
                save_job_options(p,self.options(model))
                with self.assertRaisesRegex(ValueError,'does not provide --positive-adp'):prepare(p)
                self.assertFalse((Path(d)/'curved-refinement').exists())
                with patch('lamagoet_qt.curved_job.subprocess.run',return_value=subprocess.CompletedProcess([],0,'--positive-adp','')):
                    out,rec=prepare(p)
                    self.assertEqual(rec['command'],['/bin/true','--positive-adp','positive.nml'])
                    self.assertEqual(rec['positive_configuration']['model'],model)
                    self.assertIn('1 2 3 -4 2',(out/'reflections.hkl').read_text())
                    with self.assertRaises(FileExistsError):prepare(p)
                self.assertEqual((Path(d)/'data.hkl').read_text(),'1 2 3 -4 2\n')
    def test_total_U_guard_for_all_routes(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);(root/'data.hkl').write_text('1 2 3 -4 2\n')
            cif=root/'total.cif'
            cif.write_text(Path(self.options()['CIF']).read_text()+'\n_tonto_positive_model mixture\n')
            for model in ('shared_u_mixture','independent_overtone','lissajous'):
                p=root/'options';save_job_options(p,self.options(model,CIF=str(cif),LISSAJOUS_TARGET='C1'))
                with self.assertRaisesRegex(ValueError,'total-U CIF'):prepare(p)
    def test_authoritative_status(self):
        with tempfile.TemporaryDirectory() as d:
            out=Path(d);(out/'curved.summary').write_text('status converged\n')
            rec=dict(command=['fake'],job_timeout_seconds=10,result_prefix='positive')
            with patch('lamagoet_qt.curved_job.subprocess.run',return_value=subprocess.CompletedProcess([],0)):
                self.assertEqual(run(out,rec),2)
                for state,rc in [('fixed_parameter_evaluation',2),('not_converged',2),('converged',0)]:
                    (out/'positive.summary').write_text('status '+state+'\n');self.assertEqual(run(out,rec),rc)
    def test_controls_preserve_explicit_values_and_old_models(self):
        from PySide6.QtWidgets import QApplication
        from lamagoet_qt.curved_controls import CurvedControls
        app=QApplication.instance() or QApplication([]);w=CurvedControls()
        for model in ('shared_u_mixture','independent_overtone'):
            w.load(self.options(model,MIXTURE_POPULATION='.41',MIXTURE_AUTO_DIRECTION='false',OVERTONE_COEFFICIENTS_3D='-.012 0 0'))
            self.assertFalse(w.positive.isHidden());self.assertTrue(w.lissajous.isHidden())
            self.assertTrue(w.fields['CURVED_PIVOT'].isHidden());self.assertTrue(w.additional.isHidden())
            self.assertFalse(w.source.isHidden());self.assertFalse(w.fields['CURVED_OUTPUT'].isHidden())
            w.positive.advanced.setChecked(True)
            o=w.values();w.load(o);self.assertEqual(w.values(),o)
            self.assertEqual(w.positive.fields['MIXTURE_POPULATION'].text(),'.41')
            self.assertEqual(w.positive.fields['OVERTONE_COEFFICIENTS_3D'].text(),'-.012 0 0')
        w.model.setCurrentIndex(w.model.findData('lissajous'))
        self.assertTrue(w.positive.isHidden());self.assertFalse(w.lissajous.isHidden())
        w.load({'CURVED_MODEL':'off'});self.assertTrue(w.details.isHidden());self.assertTrue(w.positive.isHidden())
        w.close();app.processEvents()

if __name__=='__main__':unittest.main()
