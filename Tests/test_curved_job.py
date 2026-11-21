"""Selector round-trip, exact input mapping and fail-closed runner controls."""
import json
import os
from pathlib import Path
import subprocess
import shutil
import sys
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from lamagoet_qt.curved_job import validate_options, make_stdin, make_namelist, reflection_text, run
from lamagoet_qt.job_options import load_job_options, save_job_options
from lamagoet_qt.options_schema import OPTION_DEFAULTS


def main():
    o = dict(OPTION_DEFAULTS, CURVED_MODEL="surface", CURVED_TARGET="Cl1", CURVED_PIVOT="Cu1",
             CURVED_LOCAL_U_CONFIRMED="true", TONTO_REFINEMENT_TARGET="f2", FCUT="0", HADP="yes")
    validate_options(o)
    native = make_stdin(o).replace("= ", "=")
    assert "least_squares_target=f2" in native and "refine_H_U_iso=true" in native
    assert " scf\n" not in native and "refine_hirshfeld" not in native.lower()
    for key, value in (("CURVED_LOCAL_U_CONFIRMED", "false"), ("REFANHARM", "true"),
                       ("EXTI", "yes"), ("H_POSITION_MODEL", "riding"),
                       ("TONTO_REFINEMENT_TARGET", "f"), ("CURVED_REFERENCE", "0 0 0"),
                       ("CURVED_TRANSVERSE_1", "NaN 0 0"), ("CURVED_TARGET", "Cl1' /"),
                       ("CURVED_OUTPUT", "../old"), ("CURVED_TIME_LIMIT", "0"),
                       ("CURVED_PIVOT", "Cl1"), ("GAUSGEN", "true"), ("INITADP", "true")):
        try:
            validate_options(dict(o, **{key: value}))
        except ValueError:
            pass
        else:
            raise AssertionError(f"Invalid option accepted: {key}")
    shelxl = make_stdin(dict(o, TONTO_WEIGHTING_SCHEME="shelxl", FCUT="2")).replace("= ", "=")
    assert "i_sigma_cutoff=0" in shelxl
    assert "i_sigma_cutoff= 3" in make_stdin(dict(o, FCUT="3"))
    har = dict(o, CURVED_ELECTRONIC_SOURCE="molecular_hirshfeld", SCFCALCPROG="Tonto",
               CURVED_MOLECULE_CONFIRMED="true", METHOD="b3lyp")
    validate_options(har)
    assert "dft_exchange_functional= b3lypgx" in make_stdin(har)
    assert " scf\n" in make_stdin(har)
    for method, keyword in (("pbe", "pbex"), ("blyp", "becke88"), ("rhf", "kind=rhf")):
        validate_options(dict(har, METHOD=method))
        assert keyword in make_stdin(dict(har, METHOD=method)).replace("= ", "=")
    for key, value in (("MULTIPLICITY", "3"), ("SCCHARGES", "true"), ("GAUSSREL", "true"),
                       ("CURVED_MOLECULE_CONFIRMED", "false"), ("SCFCALCPROG", "Crystal14")):
        try:
            validate_options(dict(har, **{key: value}))
        except ValueError:
            pass
        else:
            raise AssertionError(f"Unsupported HAR setting: {key}")
    assert "electronic_source='iam'" in make_namelist(o)
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        path = root / "data.hkl"
        path.write_text("   1-123   2   -4.00    2.00\n   0   0   0    0.00    0.00\n")
        text = reflection_text(path)
        assert "1 -123 2 -4 2" in text
        path.write_text(text)
        assert reflection_text(path) == text
        path.write_text("1 2 3 -4 2 1\n2 3 4 8 2 2\n")
        try:
            reflection_text(path)
        except ValueError:
            pass
        else:
            raise AssertionError("Multiple batches discarded")
        options = root / "job_options.txt"
        save_job_options(options, o)
        assert load_job_options(options)["CURVED_TARGET"] == "Cl1"
        (root / "curved.summary").write_text("status not_converged\n")
        rec = {"command": ["fake-tonto", "--curved-adp", "curved.nml"], "job_timeout_seconds": 60}
        with patch("lamagoet_qt.curved_job.subprocess.run", return_value=subprocess.CompletedProcess([], 0)):
            assert run(root, rec) == 2  # Exit zero alone cannot bless a failed refinement.
            assert json.loads((root / "run.json").read_text())["status"] == "failed_or_not_converged"
            (root / "curved.summary").write_text("status converged\n")
            assert run(root, rec) == 0
        for name in ("lamaGOET.sh", "RUN_lamaGOET_release.sh"):
            source = (ROOT / name).read_text()
            assert '"${CURVED_MODEL:-off}" != "off"' in source and "curved_refinement.py" in source
        if os.name == "posix":
            # Mock only the expensive native executable. Exercise real shell
            # dispatch, option parsing, data staging and status collection.
            shutil.copy2(ROOT / "Tests/inputs/calc.cif", root / "input.cif")
            path.write_text("1 2 3 -4 2\n")
            fake = root / "fake-tonto"
            fake.write_text("#!/usr/bin/env python3\nfrom pathlib import Path\nimport sys\n"
                            "assert sys.argv[1:] == ['--curved-adp', 'curved.nml']\n"
                            "assert 'least_squares_target= f2' in Path('stdin').read_text()\n"
                            "Path('curved.summary').write_text('status converged\\n')\n")
            fake.chmod(0o700)
            for i, name in enumerate(("lamaGOET.sh", "RUN_lamaGOET_release.sh")):
                save_job_options(options, dict(o, CURVED_TARGET="C1", CURVED_PIVOT="C2",
                    CIF="input.cif", HKL="data.hkl", TONTO=str(fake), CURVED_OUTPUT=f"dispatch-{i}"))
                args = ["bash", str(ROOT / name)]
                if i == 0:
                    args += ["--run-job-options", str(options)]
                done = subprocess.run(args, cwd=root, capture_output=True, text=True, timeout=30)
                assert done.returncode == 0, done.stdout + done.stderr
                result = json.loads((root / f"dispatch-{i}/run.json").read_text())
                assert result["status"] == "converged"
                # Source data unchanged; a second launch must not overwrite.
                assert path.read_text() == "1 2 3 -4 2\n"
                again = subprocess.run(args, cwd=root, capture_output=True, text=True, timeout=30)
                assert again.returncode != 0
        try:
            from PySide6.QtWidgets import QApplication
        except ImportError:
            print("Qt controls skipped (not installed)")
        else:
            os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
            from lamagoet_qt.curved_controls import CurvedControls
            app = QApplication.instance() or QApplication([])
            widget = CurvedControls()
            assert widget.title() == "Multi-harmonic angular ADP refinement - opt-in"
            assert widget.model.itemText(widget.model.findData("planar")) == "One transverse direction (planar)"
            assert widget.model.itemText(widget.model.findData("surface")) == "Two transverse directions (surface)"
            widget.load(o)
            assert widget.values()["CURVED_TARGET"] == "Cl1"
            assert widget.values()["CURVED_MODEL"] == "surface"
            widget.load(OPTION_DEFAULTS)
            assert widget.values()["CURVED_MODEL"] == "off"
            assert not widget.local.isChecked()
    print("Multi-harmonic angular ADP selector, reflection preservation, scope guards and convergence-status checks passed")


if __name__ == "__main__":
    main()
