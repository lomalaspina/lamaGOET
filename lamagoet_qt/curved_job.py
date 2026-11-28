"""Explicit, bounded opt-in runner for the Multi-harmonic angular ADP command.

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


def default_starts_enabled(o):
    """Legacy automatic setup chose starts too; manual jobs retain their values."""
    return enabled(o.get("CURVED_DEFAULT_STARTS", o.get("CURVED_AUTO_GEOMETRY", "false")))


def suggested_angular_starts(model):
    """Nonzero numerical seeds, not restraints or optimized physical amplitudes.

    Higher harmonics start away from a singular all-zero chart. Each target's
    model selects its own seeds; no value depends on the experimental residuals.
    """
    if model == "harmonic_surface":
        return dict(transverse_1="0.05 0 0", transverse_2="0.03 0 0", plane_angle="0")
    if model == 'free_surface':
        return dict(transverse_1="0.05 0.01 0.005",transverse_2="0.03 0.006 0.003",plane_angle="0",
                    orientation="0 0 0",mean_length="1")
    if model in {"planar", "surface"}:
        return dict(transverse_1="0.05 0.01 0.005", transverse_2="0.03 0.006 0.003", plane_angle="0")
    raise ValueError("Unsupported angular starting-value model")


def number(value):
    value = float(str(value).replace("D", "E").replace("d", "e"))
    if not math.isfinite(value):
        raise ValueError("Multi-harmonic angular model numbers must be finite")
    return value


def vector(value):
    result = [number(x) for x in str(value).replace(",", " ").split()]
    if len(result) != 3:
        raise ValueError("Multi-harmonic angular model vectors need exactly three numbers")
    return result


def token(value, label):
    if not re.fullmatch(r"[A-Za-z0-9_+.*-]+", str(value)):
        raise ValueError(f"Invalid {label}: use a single unquoted label/name")
    return str(value)


def angular_targets(o):
    """Primary target plus explicit independent additional targets in order.

    A common pivot is allowed; repeated targets are not. This defines marginal
    atomic distributions, not phase-locked molecular normal modes.
    """
    fields = {"target": "CURVED_TARGET", "pivot": "CURVED_PIVOT", "model": "CURVED_MODEL",
              "transverse_1": "CURVED_TRANSVERSE_1", "transverse_2": "CURVED_TRANSVERSE_2",
              "plane_angle": "CURVED_PLANE_ANGLE", "reference": "CURVED_REFERENCE", "pivot_shift": "CURVED_PIVOT_SHIFT"}
    primary = {key: o.get(option, "") for key, option in fields.items()}
    if primary['model']=='free_surface':
        primary.update(orientation=o.get('CURVED_ORIENTATION','0 0 0'),mean_length=o.get('CURVED_MEAN_LENGTH','1'))
    try:
        extra = json.loads(o.get("CURVED_ADDITIONAL_TARGETS", "[]"))
    except (ValueError, TypeError) as exc:
        raise ValueError("Additional angular targets must be a JSON list of target definitions") from exc
    if not isinstance(extra, list) or len(extra) > 63:
        raise ValueError("Choose between 1 and 64 independent angular targets")
    targets = [primary]
    for row in extra:
        allowed=set(fields)
        if isinstance(row,dict) and row.get('model')=='free_surface':
            allowed|={'orientation','mean_length'}
        if not isinstance(row, dict) or set(row)-allowed or not {'target','model'}<=set(row):
            raise ValueError("Each additional target needs label, pivot, model, two transverse vectors, angle, reference and image shift")
        if row['model']=='free_surface':
            row=dict(pivot='',reference='0 0 1',pivot_shift='0 0 0',plane_angle='0',
                     transverse_1='0.05 0.01 0.005',transverse_2='0.03 0.006 0.003',
                     orientation='0 0 0',mean_length='1')|row
        elif set(row)!=set(fields):
            raise ValueError("Bond-anchored targets require all reference fields")
        targets.append(row.copy())
    if default_starts_enabled(o):
        for row in targets:
            row.update(suggested_angular_starts(row["model"]))
    seen = set()
    for row in targets:
        target = token(row["target"], "angular target")
        if row['model']=='free_surface':
            # These are not physical inputs to the target-only model. Older
            # stored bond settings survive in the UI, never in its native input.
            row.update(pivot='',reference='0 0 1',pivot_shift='0 0 0',plane_angle='0')
            rotation=vector(row['orientation'])
            if sum(v*v for v in rotation)>=math.pi**2:
                raise ValueError("Free orientation must be inside the rotation-vector pi chart")
            length=number(row['mean_length'])
            if not math.exp(-20)*.5291772108<=length<=math.exp(20)*.5291772108:
                raise ValueError("Mean radial length must be positive and inside the native log-length chart")
        pivot = str(row["pivot"]).strip()
        if row['model']!='free_surface' and (pivot or not enabled(o.get("CURVED_AUTO_GEOMETRY"))):
            pivot = token(pivot, "angular pivot")
        if target == pivot:
            raise ValueError("Multi-harmonic angular target and pivot must be different atoms")
        if target in seen:
            raise ValueError(f"Repeated angular target {target}; symmetry equivalents are generated automatically")
        seen.add(target)
        if row["model"] not in {"harmonic_surface", "planar", "surface", "free_surface"}:
            raise ValueError("Unknown angular target model")
        for key in ("transverse_1", "transverse_2", "reference", "pivot_shift"):
            vector(row[key])
        if sum(x*x for x in vector(row["reference"])) == 0:
            raise ValueError("Multi-harmonic angular reference direction cannot be zero")
        number(row["plane_angle"])
        if row['model']=='harmonic_surface':
            if any(vector(row[key])[i] != 0 for key in ('transverse_1','transverse_2') for i in (1,2)):
                raise ValueError("The nine-parameter harmonic model requires T2=T3=0 in both directions; coefficients are not silently discarded")
    return targets


def angular_bond_candidates(structure, target_label):
    """All covalent neighbours, for any element/coordination, with image audit.

    Uses the viewer's Tonto-compatible connectivity, not a terminal-atom filter
    or a claim that the closest bond is the preferred physical bending axis.
    Native pivots support translations but not a general rotated image.
    """
    import numpy as np
    from .crystal import infer_bonds, _COVALENT_RADII, _TONTO_BOND_RANGE
    atoms = {atom.label: atom for atom in structure.asymmetric_unit()}
    if target_label not in atoms:
        raise ValueError(f"Unknown angular target {target_label}")
    direct = np.array(structure.cell.direct_matrix)
    inverse = np.linalg.inv(direct)
    radius = 2*max(_COVALENT_RADII.get(a.element,1.5) for a in atoms.values())+_TONTO_BOND_RANGE
    shell = max(1, int(np.ceil(radius*np.max(np.linalg.norm(inverse,axis=1)))))
    if shell > 3:
        raise ValueError("Automatic angular geometry does not support this unusually short/skew cell; select the image explicitly in Advanced settings")
    target = atoms[target_label]
    near = [target] + [a for a in structure._neighbourhood([target], shell)
                       if np.linalg.norm(np.array(a.cartesian)-target.cartesian)>1e-7]
    candidates = [near[right] for left,right in infer_bonds(near) if left==0]
    unique = {}
    for atom in candidates:
        unique[(atom.label,tuple(np.round(atom.cartesian,7)))] = atom
    result=[]
    for pivot in unique.values():
        translation=np.array(pivot.fractional)-atoms[pivot.label].fractional
        rotated=np.max(abs(translation-np.rint(translation)))>1e-7
        result.append(dict(pivot=pivot.label, distance=float(np.linalg.norm(np.array(pivot.cartesian)-target.cartesian)),
                           shift=(direct@np.rint(translation)).tolist() if not rotated else None,
                           supported=not rotated and pivot.label!=target_label,
                           reason="rotated symmetry mate" if rotated else "same asymmetric atom" if pivot.label==target_label else "lattice image"))
    return sorted(result,key=lambda row:(row['pivot'],row['distance'],str(row['shift'])))


def resolve_angular_geometry(o, structure):
    """Resolve a chosen or unique bond for terminal OR multiply bonded atoms."""
    rows = angular_targets(o)
    if not enabled(o.get("CURVED_AUTO_GEOMETRY")):
        return rows
    import numpy as np
    atoms = {atom.label: atom for atom in structure.asymmetric_unit()}
    for row in rows:
        if row['model']=='free_surface':
            if row['target'] not in atoms:raise ValueError(f"Unknown angular target {row['target']}")
            continue
        candidates = angular_bond_candidates(structure,row['target'])
        target = atoms[row['target']]
        if row['pivot']:
            candidates = [a for a in candidates if a['pivot']==row['pivot']]
        # Distinct symmetry images of the same label still represent different
        # choices of pivot. A nearest-distance tie must not silently choose one.
        if len(candidates) != 1:
            labels = ', '.join(sorted({a['pivot'] for a in candidates})) or 'none'
            raise ValueError(f"{row['target']}: automatic bond pivot is ambiguous or absent ({labels}). "
                             "Choose a bonded neighbour in the atom/bond selector. Multiple bonds do not define a unique angular pivot.")
        pivot=candidates[0];source=atoms[pivot['pivot']]
        if not pivot['supported']:
            raise ValueError(f"{row['target']}: bonded pivot requires a {pivot['reason']}, not a distinct translated atom. "
                             "That pivot chain rule is not supported by this native command; do not substitute a constant shift.")
        shift=np.array(pivot['shift'])
        bond=np.array(target.cartesian)-np.array(source.cartesian)-shift
        if np.linalg.norm(bond)<1e-7:raise ValueError("Coincident angular target and pivot")
        reference=np.eye(3)[np.argmin(abs(bond/np.linalg.norm(bond)))]
        row.update(pivot=pivot['pivot'],pivot_shift=' '.join(f'{x:.17g}' for x in shift),
                   reference=' '.join(f'{x:.17g}' for x in reference))
    return rows


def validate_options(o):
    """Validate scientific scope before writing any calculation files."""
    if o.get("CURVED_MODEL", "off") == "off":
        return
    is_lissajous = o['CURVED_MODEL'] == 'lissajous'
    is_positive = o['CURVED_MODEL'] in {'shared_u_mixture', 'independent_overtone'}
    if is_positive:
        from .positive_options import require_production_route
        require_production_route(o)
    elif is_lissajous:
        from .lissajous_options import require_production_route
        require_production_route(o)
    elif o["CURVED_MODEL"] not in {"harmonic_surface", "planar", "surface", "free_surface"}:
        raise ValueError("Unknown Multi-harmonic angular ADP model")
    else:
        angular_targets(o)
    if not enabled(o.get("CURVED_LOCAL_U_CONFIRMED")):
        raise ValueError("Confirm that the starting CIF contains LOCAL Gaussian U, not total angular-model U")
    if not (is_lissajous or is_positive):
        for key in ("CURVED_TRANSVERSE_1", "CURVED_TRANSVERSE_2"):
            vector(o[key])
    if o['CURVED_MODEL'] not in {'free_surface', 'lissajous', 'shared_u_mixture', 'independent_overtone'}:
        vector(o['CURVED_PIVOT_SHIFT'])
        if sum(x*x for x in vector(o["CURVED_REFERENCE"])) == 0:
            raise ValueError("Multi-harmonic angular reference direction cannot be zero")
        number(o["CURVED_PLANE_ANGLE"])
    for key, upper in (("CURVED_MAX_CYCLES", 10000), ("CURVED_TIME_LIMIT", 86400), ("CURVED_JOB_TIMEOUT", 604800)):
        if not 1 <= int(o[key]) <= upper:
            raise ValueError(f"{key} must be between 1 and {upper}")
    output = o["CURVED_OUTPUT"]
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", output) or output in {".", ".."}:
        raise ValueError("Multi-harmonic angular output must be a new simple subdirectory name")
    if o.get("TONTO_REFINEMENT_TARGET") != "f2":
        raise ValueError("Multi-harmonic angular refinement requires the F² target; select F² explicitly")
    if o.get("TONTO_WEIGHTING_SCHEME") not in {"sigma", "shelxl"}:
        raise ValueError("Multi-harmonic angular refinement supports sigma or SHELXL weights")
    if enabled(o.get("EXTI")):
        raise ValueError("Multi-harmonic angular refinement currently requires zero fixed extinction")
    if o.get("H_POSITION_MODEL", "refine") not in {"refine", "free", "fixed"}:
        raise ValueError("Multi-harmonic angular refinement does not yet support riding H atoms")
    for key in ("REFANHARM", "REFNOTHING", "REFUISO", "POSONLY", "ADPSONLY", "XWR", "XCW",
                "CALCULATE_FLACK_PARAMETER", "USENOSPHERA2", "GAUSGEN", "COMPLETESTRUCT", "XCWONLY",
                "EXPLICITMOL", "DEFRAG", "DEFRAGEXPL", "DEFRAGNETW", "OUTPUT_ANHARMONIC_PDF_CUBES",
                "INITADP", "POWDER_HAR", "FINITE_WAVEFUNCTION_EXPORT", "PERIODIC_WAVEFUNCTION_EXPORT",
                "OUTPUT_HIRSHFELD_ATOM_CUBES", "SHELXL_RESIDUAL_MAP", "RESDENS", "PLOT_TONTO"):
        if enabled(o.get(key)):
            raise ValueError(f"Multi-harmonic angular job does not support {key}; disable it explicitly")
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
            raise ValueError("Multi-harmonic angular HAR requires Tonto and a restricted singlet molecular SCF")
        if o.get("METHOD", "").lower() not in {"rhf", "pbe", "blyp", "b3lyp"}:
            raise ValueError("Multi-harmonic angular HAR supports native RHF/PBE/BLYP/B3LYP only")
        if not enabled(o.get("CURVED_MOLECULE_CONFIRMED")):
            raise ValueError("Confirm a complete molecular fragment in the CIF before single-density HAR")
        if enabled(o.get("SCCHARGES")) or enabled(o.get("GAUSSREL")):
            raise ValueError("This GUI route currently supports nonrelativistic, unembedded molecular HAR only")
        if o.get("PARTITION_MODEL", "oc-hirshfeld") != "oc-hirshfeld" or o.get("STOCKHOLDER_MODEL", "cluster") != "cluster":
            raise ValueError("Multi-harmonic angular molecular HAR requires conventional molecular Hirshfeld partitioning")
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


def make_namelist(o, targets=None):
    if o.get('CURVED_MODEL') in {'shared_u_mixture', 'independent_overtone'}:
        from .positive_options import make_namelist as positive_namelist
        return positive_namelist(o)
    if o.get('CURVED_MODEL') == 'lissajous':
        from .lissajous_options import make_namelist as lissajous_namelist
        return lissajous_namelist(o)
    explicit_targets = targets is not None
    if targets is None:
        if enabled(o.get("CURVED_AUTO_GEOMETRY")) and any(r['model']!='free_surface' for r in angular_targets(o)):
            raise ValueError("Automatic angular geometry must be resolved from the CIF before writing native input")
        targets = angular_targets(o)
    if explicit_targets or len(targets) > 1 or enabled(o.get("CURVED_AUTO_GEOMETRY")) or default_starts_enabled(o) or targets[0]['model']=='free_surface':
        lines = ["&curved_adp", f" electronic_source='{o['CURVED_ELECTRONIC_SOURCE']}',",
                 f" n_targets={len(targets)}, initial_covariance_is_local=.true.,"]
        for i, row in enumerate(targets, 1):
            lines.append(f" target_labels({i})='{row['target']}', pivot_labels({i})='{row['pivot']}', target_models({i})='{row['model']}',")
            vectors=[("transverse_1", "target_transverse_1"), ("transverse_2", "target_transverse_2")]
            if row['model']=='free_surface':
                vectors.append(('orientation','target_orientation_vectors'))
                lines.append(f" target_mean_lengths_angstrom({i})={number(row['mean_length']):.17g},")
            else:
                vectors += [("reference", "target_references"), ("pivot_shift", "target_pivot_shifts")]
                lines.append(f" target_plane_angles({i})={number(row['plane_angle']):.17g},")
            for key, native in vectors:
                lines.append(f" {native}(:,{i})=" + ",".join(f"{x:.17g}" for x in vector(row[key])) + ",")
        lines += [f" max_cycles={int(o['CURVED_MAX_CYCLES'])}, time_limit_seconds={int(o['CURVED_TIME_LIMIT'])}", "/"]
        return "\n".join(lines) + "\n"
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
        raise ValueError("Multi-harmonic angular model is not selected")
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
        raise ValueError(f"Multi-harmonic angular input CIF: {exc}") from exc
    atoms = {a.label: a for a in structure.asymmetric_atoms}
    if len(atoms) != len(structure.asymmetric_atoms):
        raise ValueError("Duplicate atom labels in the input CIF")
    is_lissajous = o['CURVED_MODEL'] == 'lissajous'
    is_positive = o['CURVED_MODEL'] in {'shared_u_mixture', 'independent_overtone'}
    if is_positive:
        from .positive_options import configuration
        config = configuration(o)
        targets = [dict(target=config['target_label'], model=config['model'])]
    elif is_lissajous:
        from .lissajous_options import configuration
        config = configuration(o)
        targets = [dict(target=config['target_label'], model='lissajous')]
    else:
        targets = resolve_angular_geometry(o, structure)
    for row in targets:
        labels={row['target']} if row['model'] in {'free_surface', 'lissajous', 'shared_u_mixture', 'independent_overtone'} else {row['target'],row['pivot']}
        if not labels <= atoms.keys():
            raise ValueError("Every target and pivot must match distinct asymmetric-atom labels in the CIF")
        if atoms[row["target"]].u_aniso is None:
            raise ValueError(f"Angular target {row['target']} needs a LOCAL anisotropic Gaussian U in the input CIF")
        # An H target cannot be silently isotropized by the global H control.
        if atoms[row["target"]].element == "H" and enabled(o.get("HADP")):
            raise ValueError("Disable isotropic H ADPs when selecting hydrogen angular targets")
    cif_text = cif.read_text(errors="replace").lower()
    if any(tag in cif_text for tag in ('_tonto_curved', '_tonto_lissajous', '_tonto_positive')):
        raise ValueError("Do not restart from a non-Gaussian model's total-U CIF; use the exact native restart interface")
    stdin, namelist = make_stdin(o), make_namelist(o,targets)
    reflections = None if enabled(o.get("ISFCF")) else reflection_text(hkl, enabled(o.get("ONF")))
    executable = Path(o["TONTO"]).expanduser()
    if executable.is_absolute():
        exe = str(executable)
    else:
        exe = str((root / executable).resolve()) if (root / executable).is_file() else shutil.which(str(executable))
    if not exe or not os.access(exe, os.X_OK):
        raise ValueError("Tonto executable was not found or is not executable")
    if is_lissajous or is_positive:
        required_option = '--positive-adp' if is_positive else '--lissajous-adp'
        capability = subprocess.run([exe, '--help'], capture_output=True, text=True, timeout=15,
                                    env=dict(os.environ, OMP_NUM_THREADS='1', OPENBLAS_NUM_THREADS='1'))
        if capability.returncode != 0 or required_option not in capability.stdout + capability.stderr:
            raise ValueError(f'This Tonto executable does not provide {required_option}; update the executable. '
                             'No ordinary ADP calculation will be substituted.')
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
    prefix = 'positive' if is_positive else 'lissajous' if is_lissajous else 'curved'
    (out / (prefix + '.nml')).write_text(namelist)
    shutil.copy2(option_path, out / "job_options.snapshot.txt")
    command = [exe, '--' + prefix + '-adp', prefix + '.nml']
    record = {"status": "prepared", "created_utc": datetime.now(timezone.utc).isoformat(), "command": command,
              "angular_targets": targets,
              "result_prefix": prefix,
              "source_cif": str(cif), "source_hkl": str(hkl), "electronic_source": o["CURVED_ELECTRONIC_SOURCE"],
              "job_timeout_seconds": int(o["CURVED_JOB_TIMEOUT"]), "address_limit_GiB": 10, "threads": 1,
              "sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir() if p.is_file()},
              "executable_sha256": hashlib.sha256(Path(exe).read_bytes()).hexdigest()}
    if is_lissajous:
        record['lissajous_configuration'] = config
    if is_positive:
        record['positive_configuration'] = config
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
        summary_path = out / (record.get('result_prefix', 'curved') + '.summary')
        summary = summary_path.read_text() if summary_path.exists() else ""
        fields = dict(line.split(" ", 1) for line in summary.splitlines() if " " in line)
        native_status = fields.get("status", "")
        allowed = {"converged"}
        if record.get("result_prefix") == "positive":
            allowed.add("constrained_converged")
        success = done.returncode == 0 and native_status in allowed
        record.update(status=native_status if success else "failed_or_not_converged", returncode=done.returncode)
        if record.get("result_prefix") == "positive":
            record["uncertainty_status"] = fields.get("uncertainty_status", "unknown")
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
        print(f"Multi-harmonic angular ADP inputs/results: {out}", flush=True)
        return 0 if args.prepare_only else run(out, record)
    except (ValueError, OSError, subprocess.TimeoutExpired) as exc:
        print(f"Multi-harmonic angular ADP job stopped: {exc}", flush=True)
        return 2
