"""Explicit, bounded opt-in runner for the native curved ADP command.

Ordinary lamaGOET jobs never enter this module. Source data are copied into a
new directory; failed/nonconverged native runs remain failed, with artifacts.
No shell interpolation is used to construct the native command or input.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
from datetime import datetime, timezone

from .job_options import load_job_options


def enabled(value):
    return str(value).lower() in {"true", "yes", "1", "on"}


def number(value):
    value = float(str(value).replace("D", "E").replace("d", "e"))
    if not math.isfinite(value):
        raise ValueError("Curved-model numbers must be finite")
    return value


def vector(value):
    result = [number(x) for x in str(value).replace(",", " ").split()]
    if len(result) != 3:
        raise ValueError("Curved-model vectors need exactly three numbers")
    return result


def token(value, label):
    if not re.fullmatch(r"[A-Za-z0-9_+.*-]+", str(value)):
        raise ValueError(f"Invalid {label}: use a single unquoted label/name")
    return str(value)


def validate_options(o):
    """Validate scientific scope before writing any calculation files."""
    if o.get("CURVED_MODEL", "off") == "off":
        return
    if o["CURVED_MODEL"] not in {"planar", "surface"}:
        raise ValueError("Curved ADP model must be planar or surface")
    for key in ("CURVED_TARGET", "CURVED_PIVOT"):
        token(o.get(key, ""), key)
    if o["CURVED_TARGET"] == o["CURVED_PIVOT"]:
        raise ValueError("Curved target and pivot must be different atoms")
    if not enabled(o.get("CURVED_LOCAL_U_CONFIRMED")):
        raise ValueError("Confirm that the starting CIF contains LOCAL Gaussian U, not total curved U")
    for key in ("CURVED_TRANSVERSE_1", "CURVED_TRANSVERSE_2", "CURVED_REFERENCE", "CURVED_PIVOT_SHIFT"):
        vector(o[key])
    if sum(x*x for x in vector(o["CURVED_REFERENCE"])) == 0:
        raise ValueError("Curved reference direction cannot be zero")
    number(o["CURVED_PLANE_ANGLE"])
    for key, upper in (("CURVED_MAX_CYCLES", 10000), ("CURVED_TIME_LIMIT", 86400), ("CURVED_JOB_TIMEOUT", 604800)):
        if not 1 <= int(o[key]) <= upper:
            raise ValueError(f"{key} must be between 1 and {upper}")
    output = o["CURVED_OUTPUT"]
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", output) or output in {".", ".."}:
        raise ValueError("Curved output must be a new simple subdirectory name")
    if o.get("TONTO_REFINEMENT_TARGET") != "f2":
        raise ValueError("Curved refinement requires the F² target; select F² explicitly")
    if o.get("TONTO_WEIGHTING_SCHEME") not in {"sigma", "shelxl"}:
        raise ValueError("Curved refinement supports sigma or SHELXL weights")
    if enabled(o.get("EXTI")):
        raise ValueError("Curved refinement currently requires zero fixed extinction")
    if o.get("H_POSITION_MODEL", "refine") not in {"refine", "free", "fixed"}:
        raise ValueError("Curved refinement does not yet support riding H atoms")
    for key in ("REFANHARM", "REFNOTHING", "REFUISO", "POSONLY", "ADPSONLY", "XWR", "XCW",
                "CALCULATE_FLACK_PARAMETER", "USENOSPHERA2", "GAUSGEN", "COMPLETESTRUCT", "XCWONLY",
                "EXPLICITMOL", "DEFRAG", "DEFRAGEXPL", "DEFRAGNETW", "OUTPUT_ANHARMONIC_PDF_CUBES",
                "INITADP", "POWDER_HAR", "FINITE_WAVEFUNCTION_EXPORT", "PERIODIC_WAVEFUNCTION_EXPORT",
                "OUTPUT_HIRSHFELD_ATOM_CUBES", "SHELXL_RESIDUAL_MAP", "RESDENS", "PLOT_TONTO"):
        if enabled(o.get(key)):
            raise ValueError(f"Curved job does not support {key}; disable it explicitly")
    if int(o.get("MERGCODE", 2)) not in {0, 1, 2, 3, 4}:
        raise ValueError("Unsupported reflection merging code")
    if number(o["WAVE"]) <= 0:
        raise ValueError("Wavelength must be positive")
    number(o.get("FCUT", 0))
    if o["TONTO_WEIGHTING_SCHEME"] == "shelxl":
        for suffix in "ABCDEF":
            number(o[f"SHELXL_WEIGHT_{suffix}"])
    source = o.get("CURVED_ELECTRONIC_SOURCE", "iam")
    if source not in {"iam", "molecular_hirshfeld"}:
        raise ValueError("Choose IAM or single-density native molecular HAR")
    if source == "molecular_hirshfeld":
        if o.get("SCFCALCPROG") != "Tonto" or str(o.get("MULTIPLICITY")) != "1":
            raise ValueError("Curved HAR requires Tonto and a restricted singlet molecular SCF")
        if o.get("METHOD", "").lower() not in {"rhf", "pbe", "blyp", "b3lyp"}:
            raise ValueError("Curved HAR supports native RHF/PBE/BLYP/B3LYP only")
        if not enabled(o.get("CURVED_MOLECULE_CONFIRMED")):
            raise ValueError("Confirm a complete molecular fragment in the CIF before single-density HAR")
        if enabled(o.get("SCCHARGES")) or enabled(o.get("GAUSSREL")):
            raise ValueError("This GUI route currently supports nonrelativistic, unembedded molecular HAR only")
        if o.get("PARTITION_MODEL", "oc-hirshfeld") != "oc-hirshfeld" or o.get("STOCKHOLDER_MODEL", "cluster") != "cluster":
            raise ValueError("Curved molecular HAR requires conventional molecular Hirshfeld partitioning")
        token(o["BASISSETT"], "Tonto basis")
        int(o.get("CHARGE", 0))
        if str(o.get("LINEDEP", "")).strip() or o.get("BECKEPRUNINGSCHEME", "none") != "none":
            raise ValueError("Custom overlap cutoffs/grid pruning require the audited native command route")
        if o.get("ACCURACY", "high") not in {"very_low", "sg-1", "low", "medium", "high", "very_high", "extreme", "best"}:
            raise ValueError("Unsupported Becke-grid accuracy")


def reflection_text(path, on_f=False):
    """Read five-column/FIXED-format HKL or numeric native reflection_data.

    Preserve signed intensities, uncertainties, ordering and duplicates. Never
    pre-merge or discard weak/negative observations here. Native Tonto applies
    the explicitly selected merging and cutoff settings afterwards.
    """
    source = "\n".join(line.split("!", 1)[0] for line in path.read_text().splitlines())
    if "reflection_data" in source:
        match = re.search(r"keys\s*=\s*\{([^}]+)\}\s*data\s*=\s*\{([^}]+)\}", source, re.S)
        if not match:
            raise ValueError("Unrecognized native reflection_data layout")
        keys = re.findall(r"\w+(?=\s*=)", match[1])
        if keys not in (["h", "k", "l", "i_exp", "i_sigma"], ["h", "k", "l", "f_exp", "f_sigma"]):
            raise ValueError("Only h,k,l,I,sigma(I) or F,sigma(F) reflection columns are supported")
        on_f = keys[3] == "f_exp"
        source = match[2]
    records, batches = [], set()
    for line in source.splitlines():
        line = line.split("!", 1)[0].rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        fields = line.split()
        try:
            hkl = [int(x) for x in fields[:3]]
            if len(hkl) != 3 or len(fields) not in {5, 6}:
                raise ValueError()
            intensity, sigma = map(number, fields[3:5])
            batch = int(fields[5]) if len(fields) == 6 else 0
        except (ValueError, IndexError):
            # SHELX 3I4,2F8.2 with adjacent negative Miller indices.
            try:
                hkl = [int(line[i:i+4]) for i in (0, 4, 8)]
                intensity, sigma = number(line[12:20]), number(line[20:28])
                batch = int(line[28:32]) if line[28:32].strip() else 0
                if line[32:].strip():
                    raise ValueError()
            except (ValueError, IndexError) as exc:
                raise ValueError("Invalid reflection record: " + line[:80]) from exc
        if hkl == [0, 0, 0]:
            continue
        if sigma <= 0:
            raise ValueError("Reflection uncertainties must be strictly positive")
        batches.add(batch)
        records.append(" ".join(map(str, hkl)) + f" {intensity:.17g} {sigma:.17g}")
    if not records or len(batches) > 1:
        raise ValueError("Need observations with a single batch/scale, not an empty or multibatch file")
    pair = "f_exp= f_sigma=" if on_f else "i_exp= i_sigma="
    return "reflection_data= { keys= { h= k= l= " + pair + " } data= {\n" + "\n".join(records) + "\n} }\nREVERT\n"


def make_namelist(o):
    lines = ["&curved_adp", f" model='{o['CURVED_MODEL']}', electronic_source='{o['CURVED_ELECTRONIC_SOURCE']}',",
             f" target_label='{o['CURVED_TARGET']}', pivot_label='{o['CURVED_PIVOT']}',",
             " initial_covariance_is_local=.true.,"]
    for key, native in (("CURVED_TRANSVERSE_1", "transverse_1"), ("CURVED_TRANSVERSE_2", "transverse_2"),
                        ("CURVED_REFERENCE", "reference_cartesian"), ("CURVED_PIVOT_SHIFT", "pivot_shift_angstrom")):
        lines.append(" " + native + "=" + ",".join(f"{x:.17g}" for x in vector(o[key])) + ",")
    lines.extend([f" plane_angle={number(o['CURVED_PLANE_ANGLE']):.17g},",
                  f" max_cycles={int(o['CURVED_MAX_CYCLES'])}, time_limit_seconds={int(o['CURVED_TIME_LIMIT'])}", "/"])
    return "\n".join(lines) + "\n"


def make_stdin(o):
    har = o["CURVED_ELECTRONIC_SOURCE"] == "molecular_hirshfeld"
    lines = ["{", " name= curved_gui", " CIF= { file_name= geometry.cif }", " process_CIF",
             " crystal= { r_free_percentage=0 xray_data= {", f" wavelength={number(o['WAVE']):.17g} Angstrom",
             " read_fcf_file reflections.fcf" if enabled(o.get("ISFCF")) else " REDIRECT reflections.hkl",
             f" merg_code={int(o['MERGCODE'])}", " f_sigma_cutoff=0",
             f" i_sigma_cutoff={0 if o['TONTO_WEIGHTING_SCHEME']=='shelxl' else number(o['FCUT']):.17g}",
             " least_squares_target=f2", f" weighting_scheme={o['TONTO_WEIGHTING_SCHEME']}",
             " optimise_scale_factor=true refine_extinction=false",
             f" correct_dispersion={'true' if enabled(o['DISP']) else 'false'}",
             f" hydrogen_position_model={'fixed' if o['H_POSITION_MODEL']=='fixed' else 'free'}",
             f" refine_H_ADPs={'true' if enabled(o['REFHADP']) else 'false'}",
             f" refine_H_U_iso={'true' if enabled(o['HADP']) else 'false'}", " do_residual_cube=false"]
    if o["TONTO_WEIGHTING_SCHEME"] == "shelxl":
        lines += [f" shelxl_weight_{key.lower()}={number(o['SHELXL_WEIGHT_'+key]):.17g}" for key in "ABCDEF"]
    if har:
        lines += [" partition_model=oc-hirshfeld"]
    lines += [" } }"]
    if enabled(o["DISP"]):
        # Same element/f'/f'' triples serialized by lamaGOET's dispersion UI.
        fields = o.get("DISPERSION_COEFFICIENTS", "").split()
        if not fields or len(fields) % 3:
            raise ValueError("Resolve dispersion coefficients in the wavelength controls first")
        for i in range(0, len(fields), 3):
            if not re.fullmatch(r"[A-Z][a-z]?", fields[i]):
                raise ValueError("Invalid dispersion element")
            number(fields[i+1]); number(fields[i+2])
        lines += [" dispersion_coefficients= { " + " ".join(fields) + " }"]
    if enabled(o["HADP"]):
        lines += [" set_isotropic_H_adps"]
    if har:
        method = o["METHOD"].lower()
        functional = {"rhf": [], "pbe": ["dft_exchange_functional=pbex", "dft_correlation_functional=pbec"],
                      "blyp": ["dft_exchange_functional=becke88", "dft_correlation_functional=lyp"],
                      "b3lyp": ["dft_exchange_functional=b3lypgx", "dft_correlation_functional=b3lypgc"]}[method]
        lines += [f" basis_directory=basis_library basis_name={o['BASISSETT']}",
                  f" charge={int(o['CHARGE'])} multiplicity=1", f" becke_grid= {{ set_defaults accuracy={o['ACCURACY']} }}",
                  " scfdata= {", " kind=" + ("rhf" if method == "rhf" else "rks"), " initial_density=promolecule",
                  *functional, " relativity_kind=none use_direct_scf=true use_SC_cluster_charges=false",
                  " convergence=0.000001 diis={convergence_tolerance=0.000001} max_iterations=100", " }", " scf"]
    # Tonto's token reader needs whitespace after keyword '=' (Fortran
    # namelists, in contrast, do not). Preserve the two input syntaxes.
    text = re.sub(r"=(?=\S)", "= ", "\n".join(lines + ["}", ""]))
    return re.sub(r"([{}])", r" \1 ", text)


def prepare(option_path):
    option_path = Path(option_path).resolve()
    o = load_job_options(option_path)
    if o.get("CURVED_MODEL", "off") == "off":
        raise ValueError("Curved model is not selected")
    validate_options(o)
    root = option_path.parent
    def input_path(key):
        p = Path(o[key]).expanduser()
        p = p if p.is_absolute() else root / p
        if not p.is_file():
            raise ValueError(f"Missing {key} input: {p}")
        return p.resolve()
    cif, hkl = input_path("CIF"), input_path("HKL")
    from .crystal import CrystalStructure, CifError
    try:
        structure = CrystalStructure.from_cif(cif)
    except CifError as exc:
        raise ValueError(f"Curved input CIF: {exc}") from exc
    atoms = {a.label: a for a in structure.asymmetric_atoms}
    if len(atoms) != len(structure.asymmetric_atoms):
        raise ValueError("Duplicate atom labels in the input CIF")
    if not {o["CURVED_TARGET"], o["CURVED_PIVOT"]} <= atoms.keys():
        raise ValueError("Target and pivot must match distinct asymmetric-atom labels in the CIF")
    if atoms[o["CURVED_TARGET"]].u_aniso is None:
        raise ValueError("The curved target needs a LOCAL anisotropic Gaussian U in the input CIF")
    if "_tonto_curved" in cif.read_text(errors="replace").lower():
        raise ValueError("Do not restart from a curved total-U CIF; use the exact native restart interface")
    stdin, namelist = make_stdin(o), make_namelist(o)
    reflections = None if enabled(o.get("ISFCF")) else reflection_text(hkl, enabled(o.get("ONF")))
    executable = Path(o["TONTO"]).expanduser()
    if executable.is_absolute():
        exe = str(executable)
    else:
        exe = str((root / executable).resolve()) if (root / executable).is_file() else shutil.which(str(executable))
    if not exe or not os.access(exe, os.X_OK):
        raise ValueError("Tonto executable was not found or is not executable")
    basis = None
    if o["CURVED_ELECTRONIC_SOURCE"] == "molecular_hirshfeld":
        basis = Path(o.get("TONTO_BASIS_DIR") or o["BASISSETDIR"]).expanduser()
        basis = basis if basis.is_absolute() else root / basis
        if not basis.is_dir():
            raise ValueError("Missing Tonto basis library")
    out = root / o["CURVED_OUTPUT"]
    out.mkdir()  # exclusive creation; never replace a previous fit
    shutil.copy2(cif, out / "geometry.cif")
    if reflections is None:
        shutil.copy2(hkl, out / "reflections.fcf")
    else:
        (out / "reflections.hkl").write_text(reflections)
    if basis:
        (out / "basis_library").symlink_to(basis.resolve(), target_is_directory=True)
    (out / "stdin").write_text(stdin)
    (out / "curved.nml").write_text(namelist)
    shutil.copy2(option_path, out / "job_options.snapshot.txt")
    command = [exe, "--curved-adp", "curved.nml"]
    record = {"status": "prepared", "created_utc": datetime.now(timezone.utc).isoformat(), "command": command,
              "source_cif": str(cif), "source_hkl": str(hkl), "electronic_source": o["CURVED_ELECTRONIC_SOURCE"],
              "job_timeout_seconds": int(o["CURVED_JOB_TIMEOUT"]), "address_limit_GiB": 10, "threads": 1,
              "sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir() if p.is_file()},
              "executable_sha256": hashlib.sha256(Path(exe).read_bytes()).hexdigest()}
    (out / "run.json").write_text(json.dumps(record, indent=2) + "\n")
    return out, record


def run(out, record):
    def limits():
        import resource
        resource.setrlimit(resource.RLIMIT_AS, (10 * 1024**3, 10 * 1024**3))
    record.update(status="running", wrapper_pid=os.getpid(), started_utc=datetime.now(timezone.utc).isoformat())
    (out / "run.json").write_text(json.dumps(record, indent=2) + "\n")
    def interrupted(signum, frame):
        raise KeyboardInterrupt(f"Received signal {signum}")
    previous = signal.signal(signal.SIGTERM, interrupted)
    try:
        env = dict(os.environ, OMP_NUM_THREADS="1", OPENBLAS_NUM_THREADS="1", MKL_NUM_THREADS="1")
        with (out / "process.log").open("w") as log:
            done = subprocess.run(record["command"], cwd=out, stdout=log, stderr=subprocess.STDOUT, env=env,
                                  timeout=record["job_timeout_seconds"], preexec_fn=limits if os.name=="posix" else None)
        summary = (out / "curved.summary").read_text() if (out / "curved.summary").exists() else ""
        success = done.returncode == 0 and summary.splitlines()[:1] == ["status converged"]
        record.update(status="converged" if success else "failed_or_not_converged", returncode=done.returncode)
    except BaseException as exc:
        record.update(status="interrupted_or_failed", error=str(exc))
        raise
    finally:
        signal.signal(signal.SIGTERM, previous)
        record["finished_utc"] = datetime.now(timezone.utc).isoformat()
        (out / "run.json").write_text(json.dumps(record, indent=2) + "\n")
    return 0 if success else 2


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--job-options", required=True, type=Path)
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    try:
        out, record = prepare(args.job_options)
        print(f"Curved ADP inputs/results: {out}", flush=True)
        return 0 if args.prepare_only else run(out, record)
    except (ValueError, OSError, subprocess.TimeoutExpired) as exc:
        print(f"Curved ADP job stopped: {exc}", flush=True)
        return 2
