"""Lossless displacement-model handoff between outer HAR cycles.

This is a data interface, not an SCF or least-squares implementation. A display
CIF contains TOTAL moments. A new density/fit cycle needs the fitted mean
coordinates, LOCAL Gaussian tensors and the angular parameters separately.
Only accepted converged native artifacts can supply that restart. No cloud is
fitted to an ellipsoid and no tensor is subtracted from another or clipped.
"""
from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import re

import numpy as np

from .adp_cloud import CloudModel, model_paths

BOHR = 0.5291772108
PAIRS = ((0, 0), (1, 1), (2, 2), (0, 1), (0, 2), (1, 2))


def _finite(value, shape=None):
    x = np.asarray(value, dtype=float)
    if not np.all(np.isfinite(x)) or (shape is not None and x.shape != shape):
        raise ValueError("Invalid finite angular HAR-cycle state")
    return x


def _same(a, b, message, atol=2e-11):
    if np.shape(a) != np.shape(b) or not np.allclose(a, b, atol=atol, rtol=2e-12):
        raise ValueError(message)


@dataclass
class AngularCycleState:
    """Full joint parameter order agrees with curved.covariance (atomic units)."""

    labels: list[str]
    targets: list[dict]
    parameters: np.ndarray
    covariance: np.ndarray
    geometry_cif: str
    provenance: dict


def read_accepted_cycle(directory):
    """Validate native output and construct the next LOCAL-U input in memory.

    The caller must also require successful process completion and a certified
    density source. This helper never promotes a failed result or an evaluation
    to a refinement, and does not claim outer HAR convergence.
    """
    import gemmi

    directory = Path(directory)
    summary_text = (directory / "curved.summary").read_text()
    if summary_text.splitlines()[:1] != ["status converged"]:
        raise ValueError("Only a converged angular refinement can advance a HAR cycle")
    summary = dict(line.split(maxsplit=1) for line in summary_text.splitlines() if " " in line)
    scale = float(summary["intensity_scale"])
    if not np.isfinite(scale) or scale <= 0:
        raise ValueError("Invalid accepted intensity scale")
    artifact_paths = model_paths(directory / "curved.model.json")
    clouds = []
    for label, path in artifact_paths:
        cloud = CloudModel(json.loads(path.read_text()))
        if cloud.data.get("fit_status") != "converged" or cloud.data["target_label"] != label:
            raise ValueError("Angular model identity/status differs from its accepted cycle")
        clouds.append(cloud)
    base = clouds[0]
    atoms = base.data["atoms"]
    labels = [a["label"] for a in atoms]
    if not labels or len(set(labels)) != len(labels):
        raise ValueError("Repeated or missing cycle atom identities")
    # The native writer's labels are strict tokens, not arbitrary CIF syntax.
    if any(not re.fullmatch(r"[A-Za-z0-9_.()\-]+", label) for label in labels):
        raise ValueError("Unsupported native atom label")
    positions = _finite([a["mean_cartesian"] for a in atoms], (len(atoms), 3))
    local = _finite([a["total_covariance"] for a in atoms], (len(atoms), 3, 3)).copy()
    atom_index = {label: i for i, label in enumerate(labels)}
    targets, angles = [], []
    for cloud in clouds:
        data = cloud.data
        if data["atoms"] != atoms:
            raise ValueError("Joint angular artifacts disagree on the accepted atom state")
        _same(cloud.direct, base.direct, "Angular artifacts disagree on the cell")
        if data["spacegroup_operations"] != base.data["spacegroup_operations"]:
            raise ValueError("Angular artifacts disagree on symmetry")
        if data["pivot_label"] not in atom_index or data["target_label"] not in atom_index:
            raise ValueError("Missing angular target or pivot in the accepted atom mapping")
        i, p = atom_index[data["target_label"]], atom_index[data["pivot_label"]]
        _same(cloud.mean, positions[i], "Angular target representative changed")
        _same(data["pivot_cartesian"], positions[p], "Angular pivot representative changed")
        _same(cloud.total_u, local[i], "Display tensor differs from the angular total moment")
        local[i] = cloud.local_u
        values = _finite(data["parameters_rad"])
        model = {"planar_arc": "planar", "transverse_surface": "surface", "harmonic_surface": "harmonic_surface"}.get(data["model"])
        counts = {'planar':4,'surface':7,'harmonic_surface':3}
        if model is None or values.shape != (counts[model],):
            raise ValueError("Invalid angular model/parameter count")
        vector = lambda x: " ".join(f"{v:.17g}" for v in x)
        targets.append(dict(target=data["target_label"], pivot=data["pivot_label"], model=model,
                            transverse_1=vector([values[0],0,0] if model=='harmonic_surface' else values[:3]),
                            transverse_2=vector([values[1],0,0] if model=='harmonic_surface' else values[3:6] if model == "surface" else np.zeros(3)),
                            plane_angle=f"{values[-1]:.17g}",
                            reference=vector(_finite(data["reference_cartesian"], (3,))),
                            pivot_shift=vector(_finite(data["pivot_shift_cartesian"], (3,)))))
        angles.extend(values)
    # Validate all tensors, including unselected atoms. Do not rescue a bad fit
    # by clipping an eigenvalue or by using its total rather than local tensor.
    for tensor in local:
        _same(tensor, tensor.T, "Non-symmetric local ADP")
        if np.linalg.eigvalsh(tensor).min() <= 0:
            raise ValueError("Non-positive local ADP in accepted cycle")
    structural = np.column_stack((positions / BOHR,
                                 np.array([[u[i, j] / BOHR**2 for i, j in PAIRS] for u in local])))
    parameters = np.r_[structural.ravel(), angles, scale]
    covariance_path = directory / "curved.covariance"
    covariance_text = covariance_path.read_text()
    order = re.findall(r"^# atom \d+ (.+)$", covariance_text, re.M)
    if order != labels:
        raise ValueError("Covariance atom ordering differs from the cycle state")
    blocks = re.findall(r"^# angular target (\S+) first (\d+) last (\d+)$", covariance_text, re.M)
    first = 9 * len(labels) + 1
    expected = []
    for row in targets:
        last = first + {'planar':4,'surface':7,'harmonic_surface':3}[row['model']] - 1
        expected.append((row["target"], str(first), str(last)))
        first = last + 1
    # Older single-target artifacts have no separate angle-label row. Their
    # explicit order header, single target and matrix dimensions unambiguously
    # define the block; never infer a missing ordering for multiple targets.
    legacy_single = (not blocks and len(targets) == 1 and
                     "# Order: each labelled atom x y z U11 U22 U33 U12 U13 U23 (bohr,bohr^2); angular radians; intensity scale" in covariance_text)
    if blocks != expected and not legacy_single:
        raise ValueError("Covariance angular ordering differs from the cycle state")
    covariance = _finite(np.loadtxt(covariance_path), (len(parameters), len(parameters)))
    _same(covariance, covariance.T, "Non-symmetric full joint covariance", atol=1e-12)
    if np.any(np.diag(covariance) < 0):
        raise ValueError("Negative parameter variance in accepted cycle")

    original = gemmi.cif.read_file(str(directory / "curved.cif")).sole_block()
    cell = gemmi.UnitCell(*(float(original.find_value("_cell_" + tag)) for tag in
                          ("length_a", "length_b", "length_c", "angle_alpha", "angle_beta", "angle_gamma")))
    direct = np.array(cell.orth.mat)
    _same(direct, base.direct, "Display CIF and native Cartesian cell frames disagree")
    inverse = np.linalg.inv(direct)
    reciprocal = np.linalg.norm(inverse, axis=1)
    site = original.find("_atom_site_", ["label", "type_symbol", "fract_x", "fract_y", "fract_z",
                                        "U_iso_or_equiv", "adp_type", "occupancy"])
    if [row[0] for row in site] != labels:
        raise ValueError("Display CIF atom ordering differs from the accepted cycle")
    display_aniso = {}
    for row in original.find("_atom_site_aniso_", ["label", "U_11", "U_22", "U_33", "U_12", "U_13", "U_23"]):
        if row[0] in display_aniso or row[0] not in atom_index:
            raise ValueError("Duplicate or unknown display ADP label")
        tensor = np.zeros((3, 3))
        for k, (a, b) in enumerate(PAIRS, 1):
            tensor[a, b] = tensor[b, a] = float(row[k])
        display_aniso[row[0]] = direct @ (tensor * np.outer(reciprocal, reciprocal)) @ direct.T
    # Reconstruct only the geometry block. Deliberately omit final statistics,
    # total-U claims and reflection tables from the next SCF input.
    doc = gemmi.cif.Document()
    block = doc.add_new_block("angular_HAR_cycle_local_input")
    for tag in ("length_a", "length_b", "length_c", "angle_alpha", "angle_beta", "angle_gamma"):
        block.set_pair("_cell_" + tag, original.find_value("_cell_" + tag))
    block.set_pair("_space_group_IT_number", original.find_value("_space_group_IT_number"))
    block.set_pair("_tonto_angular_covariance_role", "local_Gaussian_not_total")
    sym = block.init_loop("_space_group_symop_", ["operation_xyz"])
    operations = list(original.find_values("_space_group_symop_operation_xyz"))
    expected_ops = _finite(base.data["spacegroup_operations"])
    actual_ops = []
    for text in operations:
        op = gemmi.Op(gemmi.cif.as_string(text))
        matrix = np.eye(4)
        matrix[:3, :3] = np.array(op.rot) / op.DEN
        matrix[:3, 3] = np.array(op.tran) / op.DEN
        actual_ops.append(matrix)
        sym.add_row([text])
    _same(actual_ops, expected_ops, "Display CIF and angular model symmetry disagree")
    atom_loop = block.init_loop("_atom_site_", ["label", "type_symbol", "fract_x", "fract_y", "fract_z",
                                               "U_iso_or_equiv", "adp_type", "occupancy"])
    aniso = block.init_loop("_atom_site_aniso_", ["label", "U_11", "U_22", "U_33", "U_12", "U_13", "U_23"])
    for i, row in enumerate(site):
        frac = inverse @ positions[i]
        _same(frac, [float(row[k]) for k in (2, 3, 4)], "Display CIF changed an atom representative")
        if row[1] != atoms[i]["element"] or abs(float(row[7]) - float(atoms[i]["occupancy"])) > 1e-12:
            raise ValueError("Display CIF changed chemical identity or site occupancy")
        if row[6] not in {"Uani", "Uiso"}:
            raise ValueError("Unrecognized ADP type in accepted cycle")
        total = _finite(atoms[i]["total_covariance"], (3, 3))
        _same(float(row[5]), np.trace(total) / 3, "Display equivalent U differs from the total moment")
        if row[6] == "Uani":
            if row[0] not in display_aniso:
                raise ValueError("Missing anisotropic display ADP")
            _same(display_aniso[row[0]], total, "Display anisotropic U differs from the total moment")
        if row[6] == "Uiso":
            _same(local[i], np.eye(3) * np.trace(local[i]) / 3, "Isotropic ADP flag contradicts its tensor")
        atom_loop.add_row([row[0], row[1], *(f"{v:.17g}" for v in frac),
                           f"{np.trace(local[i]) / 3:.17g}", row[6], row[7]])
        if row[6] == "Uani":
            tensor = (inverse @ local[i] @ inverse.T) / np.outer(reciprocal, reciprocal)
            aniso.add_row([row[0], *(f"{tensor[a,b]:.17g}" for a, b in PAIRS)])
    paths = [directory / name for name in ("curved.summary", "curved.cif", "curved.covariance", "curved.model.json")]
    paths += [path for _, path in artifact_paths if path not in paths]
    provenance = dict(schema="tonto.angular-har-cycle-state", version=1, outer_convergence_claim=False,
                      legacy_single_target_covariance=legacy_single,
                      source_directory=str(directory.resolve()),
                      sha256={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in paths})
    return AngularCycleState(labels, targets, parameters, covariance, doc.as_string(), provenance)


def cycle_shift(previous, current):
    """Report an outer-cycle displacement in joint fitted-parameter units.

    This is a diagnostic only. Inner convergence and density-source convergence
    are mandatory separately; a tiny shift cannot certify either one.
    """
    if previous.labels != current.labels:
        raise ValueError("HAR-cycle atom identities/order changed")
    frame_keys = ("target", "pivot", "model", "reference", "pivot_shift")
    if [[r[k] for k in frame_keys] for r in previous.targets] != [[r[k] for k in frame_keys] for r in current.targets]:
        raise ValueError("HAR-cycle target, pivot or angular frame changed")
    delta = current.parameters - previous.parameters
    esd = np.sqrt(np.diag(current.covariance))
    fixed = esd == 0
    if np.any(np.abs(delta[fixed]) > 2e-12):
        raise ValueError("A zero-variance constrained parameter moved between HAR cycles")
    free = ~fixed
    if not np.any(free):
        raise ValueError("No estimable parameters for a HAR-cycle convergence check")
    corr = current.covariance[np.ix_(free, free)] / np.outer(esd[free], esd[free])
    eigenvalues, eigenvectors = np.linalg.eigh(corr)
    cutoff = len(eigenvalues) * np.finfo(float).eps * max(eigenvalues.max(), 1)
    if eigenvalues.min() < -10 * cutoff:
        raise ValueError("Joint covariance is not positive semidefinite")
    identified = eigenvalues > cutoff
    scaled = delta[free] / esd[free]
    components = eigenvectors.T @ scaled
    if np.linalg.norm(components[~identified]) > 1e-7 * max(1, np.linalg.norm(scaled)):
        raise ValueError("HAR-cycle change lies outside the supported covariance subspace")
    return dict(max_shift_over_esd=float(np.max(np.abs(scaled))),
                joint_mahalanobis_shift=float(np.sqrt(np.sum(components[identified]**2 / eigenvalues[identified]))),
                covariance_rank=int(identified.sum()), outer_convergence_claim=False)
