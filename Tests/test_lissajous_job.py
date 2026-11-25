"""Runner guards and exact 2D/3D mapping, without an expensive native fit."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from lamagoet_qt.curved_job import make_namelist, prepare, run, validate_options
from lamagoet_qt.job_options import load_job_options, save_job_options
from lamagoet_qt.options_schema import complete_job_options


class LissajousJobTest(unittest.TestCase):
    def options(self, **kwargs):
        return complete_job_options(dict(CURVED_MODEL='lissajous', LISSAJOUS_TARGET='C1',
            CURVED_LOCAL_U_CONFIRMED='true', TONTO_REFINEMENT_TARGET='f2', FCUT='0',
            CIF=str(Path(__file__).parent/'inputs/calc.cif'), HKL='data.hkl', TONTO='/bin/true') | kwargs)

    def test_native_mapping_and_roundtrip(self):
        for dim in ('2', '3'):
            o=self.options(LISSAJOUS_DIMENSIONS=dim)
            validate_options(o)
            nml=make_namelist(o)
            self.assertIn('&lissajous_adp',nml)
            self.assertIn('dimensions='+dim,nml)
            self.assertIn("target_label='C1'",nml)
            self.assertIn('initial_covariance_is_local=.true.',nml)
            self.assertNotIn('pivot',nml)
            self.assertNotIn('transverse_',nml)
            with tempfile.TemporaryDirectory() as folder:
                p=Path(folder)/'options';save_job_options(p,o)
                self.assertEqual(make_namelist(load_job_options(p)),nml)

    def test_capability_and_preservation(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);(root/'data.hkl').write_text('1 2 3 -4 2\n')
            p=root/'options';save_job_options(p,self.options())
            with self.assertRaisesRegex(ValueError,'does not provide --lissajous-adp'):
                prepare(p)
            self.assertFalse((root/'curved-refinement').exists())
            with patch('lamagoet_qt.curved_job.subprocess.run',return_value=subprocess.CompletedProcess([],0,'--lissajous-adp','')):
                out,rec=prepare(p)
                self.assertEqual(rec['command'],['/bin/true','--lissajous-adp','lissajous.nml'])
                self.assertEqual(rec['result_prefix'],'lissajous')
                self.assertEqual(rec['lissajous_configuration']['dimensions'],2)
                self.assertIn('1 2 3 -4 2',(out/'reflections.hkl').read_text())
                with self.assertRaises(FileExistsError):prepare(p)
            self.assertEqual((root/'data.hkl').read_text(),'1 2 3 -4 2\n')

    def test_total_U_and_target_guards(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);(root/'data.hkl').write_text('1 2 3 -4 2\n')
            p=root/'options'
            save_job_options(p,self.options(LISSAJOUS_TARGET='not_present'))
            with self.assertRaisesRegex(ValueError,'asymmetric-atom labels'):prepare(p)
            source=Path(self.options()['CIF']).read_text()
            for tag in ('_tonto_curved_model','_tonto_lissajous_dimensions'):
                cif=root/'total.cif';cif.write_text(source+'\n'+tag+' 2\n')
                save_job_options(p,self.options(CIF=str(cif)))
                with self.assertRaisesRegex(ValueError,'total-U CIF'):prepare(p)

    def test_failed_status_never_uses_other_summary(self):
        with tempfile.TemporaryDirectory() as folder:
            out=Path(folder);(out/'curved.summary').write_text('status converged\n')
            rec=dict(command=['fake'],job_timeout_seconds=10,result_prefix='lissajous')
            with patch('lamagoet_qt.curved_job.subprocess.run',return_value=subprocess.CompletedProcess([],0)):
                self.assertEqual(run(out,rec),2)
                for status,result in [('not_converged',2),('fixed_parameter_evaluation',2),('converged',0)]:
                    (out/'lissajous.summary').write_text('status '+status+'\n')
                    self.assertEqual(run(out,rec),result)


if __name__=='__main__':unittest.main()
