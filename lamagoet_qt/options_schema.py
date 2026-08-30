"""Canonical lamaGOET job-option names and safe legacy defaults.

The shell runners contain many conditionals whose variables used to be
printed by gtkdialog even when their widgets were hidden.  Qt therefore must
write the complete schema as well: an omitted false value is not equivalent
to the literal string ``false`` in expressions such as ``[[ "$VALUE" ==
"false" ]]``.
"""

from __future__ import annotations

from collections import OrderedDict
from typing import Mapping


# Keep this list explicit.  It is the union of the 119 variables emitted by
# the original GUI supplied on 2026-07-31, the current Crystal guess control,
# the dispatch variables, cluster fields, and the monolithic CP2K controls.
OPTION_DEFAULTS: dict[str, str] = {
    "ACCURACY": "extreme",
    "ADDNUCINTER": "false",
    "ADPSONLY": "false",
    "ANHARMATOMS": "",
    "ATAIL": "100",
    "ATOMLIST": "",
    "ATOMUISOLIST": "",
    "BASISSETDIR": "/usr/local/bin/basis_sets",
    "BASISSETDIRXCW": "/usr/local/bin/basis_sets",
    "BASISSETG": "STO-3G",
    "BASISSETT": "STO-3G",
    "BASISSETTXCW": "STO-3G",
    "BECKEPRUNINGSCHEME": "none",
    "BHBOND": "1.190",
    "CENTERATOM": "1",
    "CHARGE": "0",
    "CHBOND": "1.083",
    "CIF": "",
    "COMPLETESTRUCT": "false",
    "CONVTOL": "0.01",
    "CONVTOLE": "0.00001",
    "CP2K_ADDED_MOS": "20",
    "CP2K_BASIS_MAP": "",
    "CP2K_BASIS_SET": "aug-SZV-MOLOPT-ae-SR",
    "CP2K_BASIS_SET_FILE": "",
    "CP2K_BIN": "cp2k.ssmp",
    "CP2K_CELL_CHARGE": "0",
    "CP2K_CELL_MULTIPLICITY": "1",
    "CP2K_CUTOFF": "1200",
    "CP2K_EPS_DEFAULT": "1.0E-12",
    "CP2K_EPS_SCF": "1.0E-8",
    "CP2K_KPOINT_GRID": "2 2 2",
    "CP2K_MAX_SCF": "100",
    "CP2K_MPI_RANKS": "",
    "CP2K_NUM_THREADS": "",
    "CP2K_REL_CUTOFF": "80",
    "CP2K_RUN_COMMAND": "",
    "CP2K_TERMINAL_VERBOSE": "true",
    "CP2K_TONTO_SLATER_BASIS_FILE": "",
    "CP2K_XC_FUNCTIONAL": "BLYP",
    "CRYSTAL_BIN": "runcry23",
    "CRYSTAL_SETTING": "auto",
    "DEFDEN": "false",
    "DEFRAG": "false",
    "DEFRAGEXPL": "false",
    "DEFRAGNETW": "false",
    "DEFRAGXCW": "false",
    "DENS": "false",
    "DFTXCPOT": "false",
    "DISP": "no",
    "ELMODB_BIN": "elmodb",
    "ELMOLIB": "/usr/local/bin/LIBRARIES",
    "EMAIL": "",
    "EXIT": "OK",
    "EXTI": "no",
    "EXTINCTION_ANISOTROPIC": "false",
    "EXTINCTION_DISTRIBUTION": "gaussian",
    "EXTINCTION_MEAN_PATH_MM": "0.3",
    "EXTINCTION_MODEL": "zachariasen",
    "EXTINCTION_TYPE": "type-1",
    "EXPLICITMOL": "false",
    "EXPLRADIUS": "3",
    "EXTRAKEY": "",
    "FCUT": "3",
    "FINITE_WAVEFUNCTION_ACTIVE_RADIUS": "2.0",
    "FINITE_WAVEFUNCTION_BASIS_DIR": "/usr/local/bin/basis_sets",
    "FINITE_WAVEFUNCTION_BASIS_NAME": "pob-TZVP-rev2",
    "FINITE_WAVEFUNCTION_BUFFER_RADII": "4.0,6.0",
    "FINITE_WAVEFUNCTION_CAP_BOUNDARIES": "true",
    "FINITE_WAVEFUNCTION_CENTER_ATOM": "1",
    "FINITE_WAVEFUNCTION_EXPORT": "false",
    "FINITE_WAVEFUNCTION_PREPARE_ONLY": "false",
    "FOURTHORD": "false",
    "FRTAIL": "200",
    "GAMESS": "gamess_int",
    "GAUSGEN": "false",
    "GAUSSEMPDISP": "false",
    "GAUSSIAN_BIN": "g09",
    "GAUSSREL": "false",
    "HADP": "no",
    "HAR_ENERGY_REPEAT_TOL": "1.0E-10",
    "HAR_SCF_RMSD_TOL": "1.0E-8",
    "HKL": "",
    "IAMTONTO": "false",
    "INITADP": "false",
    "INITADPFILE": "",
    "JANAEXE": "jana2006",
    "JOBNAME": "my_job",
    "LAMBDAINITIAL": "0",
    "LAMBDAMAX": "1",
    "LAMBDASTEP": "0.1",
    "LAPL": "false",
    "LINEDEP": "",
    "MANUALRESIDUE": "",
    "MAXCYCLE": "50",
    "MAXLSCYCLE": "30",
    "MAXPHARCYCLE": "10",
    "MAXXTALCYCLE": "",
    "MERGCODE": "2",
    "MEM": "1gb",
    "MEMPBS": "1gb",
    "METHOD": "rhf",
    "METHODXCW": "rhf",
    "MINCORCOEF": "",
    "MULTIPLICITY": "1",
    "NEGLAPL": "false",
    "NHBOND": "1.009",
    "NSA2ACC": "2",
    "NSSBOND": "0",
    "NTAIL": "0",
    "NUMPROC": "1",
    "NUMPROCTONTO": "1",
    "OBSERVED_DENSITY_MIN_TF": "0.1",
    "OBSERVED_DENSITY_SHRINKAGE": "0.5",
    "OBSERVED_ZERO_PHASE_SIGN": "0",
    "OCC_BIN": "occ",
    "OHBOND": "0.983",
    "ONF": "false",
    "ONF2": "false",
    "ONLYIAMTONTO": "false",
    "ORCA_BIN": "orca",
    "PARTITION_MODEL": "oc-hirshfeld",
    "PERIODIC_WAVEFUNCTION_EXPORT": "false",
    "PLOT_ANGS": "false",
    "PLOT_TONTO": "false",
    "POSADP": "true",
    "POSONLY": "false",
    "POWDER_HAR": "false",
    "PROMOL": "false",
    "PTSX": "10",
    "PTSY": "10",
    "PTSZ": "10",
    "REFANHARM": "false",
    "REFHADP": "true",
    "REFHPOS": "true",
    "REFNOTHING": "false",
    "REFUISO": "false",
    "RESDENS": "false",
    "SCCHARGES": "false",
    "SCCHARGESXCW": "false",
    "SCCRADIUS": "8",
    "SCCRADIUSXCW": "8",
    "SCDIPOLES": "false",
    "SCFCALC_BIN": "g09",
    "SCFCALCPROG": "Gaussian",
    "SEPARATION": "",
    "SHRINKA": "2",
    "SHRINKB": "2",
    "SSBONDATOMS": "",
    "STOCKHOLDER_MODEL": "cluster",
    "OUTPUT_HIRSHFELD_ATOM_CUBES": "false",
    "HIRSHFELD_ATOM_CUBE_LABEL": "",
    "SUPERCON": "false",
    "THIRDORD": "false",
    "TONTO": "tonto",
    "TONTO_BASIS_DIR": "",
    "USEALLPOINTS": "false",
    "USEBECKE": "false",
    "USECENTER": "false",
    "USEEQUIV": "false",
    "USEGAMESS": "false",
    "USEGUESS": "false",
    "USEHMSYM": "false",
    "USENOSPHERA2": "false",
    "USESEPARATION": "false",
    "WAVE": "0.71073",
    "WIDTHX": "10",
    "WIDTHY": "10",
    "WIDTHZ": "10",
    "WRITEHEADER": "false",
    "XAXIS": "1 2",
    "XCWONLY": "false",
    "XHALONG": "false",
    "XWR": "false",
    "YAXIS": "1 3",
}


PROGRAM_EXECUTABLE_OPTION = {
    "Gaussian": "GAUSSIAN_BIN",
    "Orca": "ORCA_BIN",
    "OCC": "OCC_BIN",
    "Crystal14": "CRYSTAL_BIN",
    "elmodb": "ELMODB_BIN",
    "optgaussian": "GAUSSIAN_BIN",
    "optorca": "ORCA_BIN",
}


def complete_job_options(values: Mapping[str, object]) -> "OrderedDict[str, object]":
    """Return a complete, alphabetically ordered runner configuration."""

    supplied = dict(values)
    # Accept the spelling used in one early Qt test file, but always write the
    # established runner name with its underscore.
    if "SCFCALC_BIN" not in supplied and supplied.get("SCFCALCBIN"):
        supplied["SCFCALC_BIN"] = supplied["SCFCALCBIN"]
    supplied.pop("SCFCALCBIN", None)

    merged: dict[str, object] = dict(OPTION_DEFAULTS)
    merged.update(supplied)
    program = str(merged.get("SCFCALCPROG") or "Gaussian")
    merged["SCFCALCPROG"] = program

    executable_option = PROGRAM_EXECUTABLE_OPTION.get(program)
    if executable_option:
        # Migrate an old selected executable into its persistent per-program
        # field.  Otherwise always derive SCFCALC_BIN from that field so a
        # program switch cannot retain the previous program's executable.
        if executable_option not in supplied and supplied.get("SCFCALC_BIN"):
            merged[executable_option] = supplied["SCFCALC_BIN"]
        merged["SCFCALC_BIN"] = merged.get(executable_option, "")
    elif program == "CP2K":
        merged["SCFCALC_BIN"] = merged.get("CP2K_BIN", "")
    elif program == "Tonto":
        # Tonto has no external SCF executable, but keeping this empty avoids
        # reporting a stale Gaussian/ORCA path in the job summary.
        merged["SCFCALC_BIN"] = ""

    return OrderedDict((name, merged[name]) for name in sorted(merged))
