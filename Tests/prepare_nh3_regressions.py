#!/usr/bin/env python3
"""Prepare clean, complete job_options files from the supplied NH3 archives.

This does not run or delete anything.  It creates a new destination tree so
the archived failed outputs remain immutable evidence.
"""

from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from lamagoet_qt.job_options import load_job_options, save_job_options


ARCHIVES = {
    "cp2k_blyp": ("nh3_cp2k_BLYP_def2TZVP.zip", "CP2K"),
    "crystal_blyp": ("nh3_crystal23_BLYP_def2TZVP.zip", "Crystal14"),
    "crystal_pbe": ("nh3_crystal23_PBE_def2TZVP.zip", "Crystal14"),
    "gaussian_blyp": ("nh3_gaussian_CC_BLYP_def2TZVP.zip", "Gaussian"),
    "orca_blyp": ("nh3_orca_CC_BLYP_def2TZVP.zip", "Orca"),
    "tonto_blyp": ("nh3_tonto_CC_BLYP_def2TZVP.zip", "Tonto"),
}

EXECUTABLES = {
    "TONTO": "/usr/local/bin/tonto_Lolo_CP2K",
    "GAUSSIAN_BIN": "/usr/local/bin/g09",
    "ORCA_BIN": "/usr/local/orca504/orca",
    "CRYSTAL_BIN": "/usr/local/crystal23/utils23/runcry23",
    "CP2K_BIN": "/home/lorraine/cp2k-master/install/bin/cp2k.ssmp",
}


def archive_member(archive: Path, suffix: str) -> bytes:
    with zipfile.ZipFile(archive) as zipped:
        names = [name for name in zipped.namelist() if name.endswith(suffix)]
        if not names:
            raise FileNotFoundError(f"{archive.name} has no *{suffix}")
        return zipped.read(names[0])


def prepare(source: Path, destination: Path) -> Path:
    destination.mkdir(parents=True, exist_ok=False)
    cif = source / "NH3_cut.cif"
    crystal_cif = source / "testing_new_lamaGOET" / "NH3_pHAR.cif"
    if not crystal_cif.is_file():
        crystal_cif = source / "NH3_pHAR.cif"
    hkl = source / "NH3_XRD_data.hkl"
    crystal_basis_archive = source / ARCHIVES["crystal_blyp"][0]
    crystal_basis = archive_member(crystal_basis_archive, "/basis_gen.txt")
    crystal_cif_bytes = (
        None
        if crystal_cif.is_file()
        else archive_member(crystal_basis_archive, "/NH3_pHAR.cif")
    )

    for case, (archive_name, program) in ARCHIVES.items():
        case_dir = destination / case
        case_dir.mkdir()
        source_cif = crystal_cif if program == "Crystal14" else cif
        if source_cif.is_file():
            shutil.copy2(source_cif, case_dir / source_cif.name)
        else:
            (case_dir / source_cif.name).write_bytes(crystal_cif_bytes or b"")
        shutil.copy2(hkl, case_dir / hkl.name)
        options_path = case_dir / "job_options.txt"
        options_path.write_bytes(archive_member(source / archive_name, "/job_options.txt"))
        values = load_job_options(options_path)
        values.update(EXECUTABLES)
        values.update(
            {
                "SCFCALCPROG": program,
                "CIF": f"./{source_cif.name}",
                "HKL": f"./{hkl.name}",
                "NUMPROC": "1",
                "NUMPROCTONTO": "1",
                "PLOT_TONTO": "false",
                "POWDER_HAR": "false",
                "EXIT": "OK",
            }
        )
        if program == "Crystal14":
            (case_dir / "basis_gen.txt").write_bytes(crystal_basis)
            values["GAUSGEN"] = "true"
            values["BASISSETG"] = "gen"
            (case_dir / "spacegroup.txt").write_text(
                "198 = p 21 3 = p 2ac 2ab 3\n", encoding="utf-8"
            )
        if case == "cp2k_blyp":
            values.update(
                {
                    "CP2K_BASIS_SET_FILE": (
                        "/home/lorraine/cp2k-master/install/share/cp2k/data/"
                        "BASIS_AUG_MOLOPT"
                    ),
                    "CP2K_BASIS_SET": "aug-SZV-MOLOPT-ae-SR",
                    "CP2K_XC_FUNCTIONAL": "BLYP",
                }
            )
        save_job_options(options_path, values)
    return destination


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source",
        type=Path,
        default=Path("/home/lorraine/inputs/nh3_phar"),
    )
    parser.add_argument("--destination", type=Path)
    args = parser.parse_args()
    destination = args.destination or Path("/home/lorraine") / (
        "lamagoet-nh3-regression-" + datetime.now().strftime("%Y%m%d-%H%M%S")
    )
    print(prepare(args.source, destination))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
