#!/usr/bin/env python3
from pathlib import Path
import re
import tempfile
import unittest

from lamagoet_qt.job_options import (
    cp2k_basis_names,
    load_job_options,
    save_job_options,
)
from lamagoet_qt.options_schema import OPTION_DEFAULTS


ORIGINAL_GUI_VARIABLES = set(
    """ACCURACY ADDNUCINTER ADPSONLY ANHARMATOMS ATAIL ATOMLIST
    ATOMUISOLIST BASISSETDIR BASISSETDIRXCW BASISSETG BASISSETT
    BASISSETTXCW BECKEPRUNINGSCHEME BHBOND CENTERATOM CHARGE CHBOND CIF
    COMPLETESTRUCT CONVTOL CONVTOLE DEFDEN DEFRAG DEFRAGEXPL DEFRAGNETW
    DEFRAGXCW DENS DFTXCPOT DISP ELMOLIB EXPLICITMOL EXPLRADIUS EXTRAKEY
    FCUT FOURTHORD FRTAIL GAMESS GAUSGEN GAUSSEMPDISP GAUSSREL HADP HKL
    IAMTONTO INITADP INITADPFILE JANAEXE JOBNAME LAMBDAINITIAL LAMBDAMAX
    LAMBDASTEP LAPL LINEDEP MANUALRESIDUE MAXCYCLE MAXLSCYCLE MAXPHARCYCLE
    MAXXTALCYCLE MEM METHOD METHODXCW MINCORCOEF MULTIPLICITY NEGLAPL
    NHBOND NSA2ACC NSSBOND NTAIL NUMPROC NUMPROCTONTO OHBOND ONF ONF2
    ONLYIAMTONTO PLOT_ANGS PLOT_TONTO POSADP POSONLY POWDER_HAR PROMOL PTSX
    PTSY PTSZ REFANHARM REFHADP REFHPOS REFNOTHING REFUISO RESDENS
    SCCHARGES SCCHARGESXCW SCCRADIUS SCCRADIUSXCW SCDIPOLES SCFCALC_BIN
    SEPARATION SHRINKA SHRINKB SSBONDATOMS SUPERCON THIRDORD TONTO
    USEALLPOINTS USEBECKE USECENTER USEEQUIV USEGAMESS USEHMSYM
    USEGUESS USENOSPHERA2 USESEPARATION WAVE WIDTHX WIDTHY WIDTHZ WRITEHEADER XAXIS
    XCWONLY XHALONG XWR YAXIS""".split()
)


class JobOptionsTest(unittest.TestCase):
    def test_cp2k_basis_aliases_come_from_selected_file(self):
        fixture = Path(__file__).resolve().parent / "cp2k_basis_sample"
        self.assertEqual(
            cp2k_basis_names(fixture),
            [
                "aug-SZV-MOLOPT-ae-SR",
                "aug-SZV-MOLOPT-ae-SR-q1",
                "DZVP-MOLOPT-GTH",
                "DZVP-MOLOPT-GTH-q4",
            ],
        )

    def test_missing_file_defaults_to_gaussian(self):
        with tempfile.TemporaryDirectory() as directory:
            values = load_job_options(Path(directory) / "missing.txt")
        self.assertEqual(values["SCFCALCPROG"], "Gaussian")
        self.assertEqual(values["SCFCALC_BIN"], "g09")
        self.assertEqual(values["TONTO"], "tonto")
        self.assertEqual(values["PLOT_TONTO"], "false")

    def test_schema_contains_every_original_gtkdialog_variable(self):
        self.assertFalse(ORIGINAL_GUI_VARIABLES - set(OPTION_DEFAULTS))

    def test_schema_tracks_current_embedded_gui_values(self):
        text = (Path(__file__).resolve().parents[1] / "lamaGOET.sh").read_text(
            encoding="utf-8"
        )
        variables = set(
            re.findall(r"<variable>\s*([A-Z][A-Z0-9_]*)\s*</variable>", text)
        )
        ui_only = {
            "BASIS_DIRECTORY_OPTIONS",
            "CP2K_SETTINGS_FRAME",
            "ELMODB_OPTIONS",
            "EXTERNAL_BASIS_OPTIONS",
            "INITADP_OPTIONS",
            "LEGACY_SCF_OPTIONS",
            "METHOD_OPTIONS",
            "TONTO_BASIS_OPTIONS",
        }
        self.assertFalse(variables - set(OPTION_DEFAULTS) - ui_only)

    def test_saved_options_are_complete_and_alphabetical(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "job_options.txt"
            save_job_options(path, {"SCFCALCPROG": "Tonto", "TONTO": "/opt/tonto"})
            names = [line.split("=", 1)[0] for line in path.read_text().splitlines()]
        self.assertEqual(names, sorted(names))
        self.assertTrue(ORIGINAL_GUI_VARIABLES <= set(names))

    def test_selected_program_gets_its_own_executable(self):
        cases = {
            "Gaussian": ("GAUSSIAN_BIN", "/apps/g16"),
            "Orca": ("ORCA_BIN", "/apps/orca"),
            "OCC": ("OCC_BIN", "/apps/occ"),
            "Crystal14": ("CRYSTAL_BIN", "/apps/runcry23"),
            "elmodb": ("ELMODB_BIN", "/apps/elmodb"),
        }
        for program, (field, executable) in cases.items():
            with self.subTest(program=program):
                with tempfile.TemporaryDirectory() as directory:
                    path = Path(directory) / "job_options.txt"
                    save_job_options(
                        path,
                        {"SCFCALCPROG": program, field: executable},
                    )
                    values = load_job_options(path)
                self.assertEqual(values["SCFCALC_BIN"], executable)

    def test_unknown_settings_are_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "job_options.txt"
            path.write_text(
                'SCFCALCPROG="CP2K"\n'
                'METHOD="BLYP"\n'
                'CUSTOM_CLUSTER_OPTION="keep me"\n',
                encoding="utf-8",
            )
            original = load_job_options(path)
            save_job_options(
                path,
                {"SCFCALCPROG": "Gaussian", "METHOD": "pbe0"},
                preserved=original,
            )
            result = load_job_options(path)
        self.assertEqual(result["SCFCALCPROG"], "Gaussian")
        self.assertEqual(result["METHOD"], "pbe0")
        self.assertEqual(result["CUSTOM_CLUSTER_OPTION"], "keep me")

    def test_shell_metacharacters_round_trip_as_data(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "job_options.txt"
            value = 'folder with spaces/$basis/"custom"`name`'
            save_job_options(path, {"CIF": value})
            result = load_job_options(path)
        self.assertEqual(result["CIF"], value)


if __name__ == "__main__":
    unittest.main()
