"""Read-only inventory of CIF geometry; not a beam-direction reconstruction.

Keep each CIF data block separate. A UB matrix, scan plan and crystal shape do
not identify the measurement orientation of an individual merged reflection.
No returned information changes the extinction model or refinement options.
"""

from dataclasses import dataclass
import math
from pathlib import Path
import re

import gemmi


def _tag(tag: str) -> str:
    tag = tag.lower().replace(".", "_")
    return re.sub(r"_ub\[([123])\]\[([123])\]$", r"_ub_\1\2", tag)


def _number(value: str | None) -> float | None:
    if value is None:
        return None
    result = gemmi.cif.as_number(value)
    return result if math.isfinite(result) else None


def _indexed_rows(loop, prefix: str, extra: tuple[str, ...]) -> tuple[int, int]:
    columns = {_tag(tag): index for index, tag in enumerate(loop.tags)}
    indices = tuple(prefix + "_index_" + axis for axis in "hkl")
    if not all(tag in columns for tag in indices):
        return 0, 0
    count = complete = 0
    for start in range(0, len(loop.values), loop.width()):
        row = loop.values[start:start + loop.width()]
        hkl = [_number(row[columns[tag]]) for tag in indices]
        if any(value is None or not value.is_integer() for value in hkl):
            continue
        count += 1
        if all(tag in columns and _number(row[columns[tag]]) is not None
               for tag in extra):
            complete += 1
    return count, complete


@dataclass(frozen=True)
class GeometryInventory:
    block: str
    ub_status: str
    ub: tuple[tuple[float, ...], ...] | None
    orientation_convention: str
    run_list_present: bool
    measured_rows: int
    angle_rows: int
    orientation_rows: int
    face_rows: int
    oxford_faces_present: bool
    absorption_coefficient: float | None

    def summary(self) -> str:
        result = (
            f"Block {self.block}: UB {self.ub_status}; "
            f"matrix convention: {self.orientation_convention or 'not supplied'}. "
            f"Run-list text {'present (not interpreted)' if self.run_list_present else 'not found'}. "
            f"Indexed measurement rows: {self.measured_rows}; "
            f"rows with omega/phi/chi-or-kappa: {self.angle_rows}. "
            f"Orientation-reference rows (not the measurement set): {self.orientation_rows}. "
            f"Faces with positive perpendicular distances: {self.face_rows}; "
            f"absorption coefficient: {self.absorption_coefficient if self.absorption_coefficient is not None else 'not supplied'} mm^-1."
        )
        if self.oxford_faces_present:
            result += " Oxford-specific face fields detected; conventions not interpreted."
        return result


def scan_cif_geometry(path: str | Path) -> tuple[GeometryInventory, ...]:
    """Inventory numeric UB, angle rows, scan-plan text and face metadata.

    Scalar UB aliases in coreCIF1 and dotted forms are accepted. Finite,
    nonsingular UB means only a structurally valid matrix, not an independently
    validated orientation. Run lists are free text and are not observation IDs.
    """
    reports = []
    for block in gemmi.cif.read_file(str(path)):
        scalars = {_tag(item.pair[0]): item.pair[1]
                   for item in block if item.pair is not None}
        tags = [f"_diffrn_orient_matrix_ub_{i}{j}"
                for i in range(1, 4) for j in range(1, 4)]
        values = [_number(scalars.get(tag)) for tag in tags]
        present = sum(tag in scalars for tag in tags)
        valid = sum(value is not None for value in values)
        matrix = None
        status = "absent"
        if present:
            status = f"incomplete/invalid ({valid}/9 numeric entries)"
        if valid == 9:
            candidate = tuple(tuple(values[3*i:3*i+3]) for i in range(3))
            scale = max(abs(value) for value in values)
            a, b, c = (tuple(value / scale for value in row)
                       for row in candidate) if scale else ((0.,)*3,)*3
            determinant = (a[0]*(b[1]*c[2]-b[2]*c[1])
                           - a[1]*(b[0]*c[2]-b[2]*c[0])
                           + a[2]*(b[0]*c[1]-b[1]*c[0]))
            if abs(determinant) <= 1e-12:
                status = "singular/ill-conditioned (not usable)"
            else:
                matrix = candidate
                status = "present (9/9 finite, nonsingular; convention unverified)"
        measured = angles = orient = faces = 0
        oxford = False
        for item in block:
            loop = item.loop
            if loop is None:
                continue
            columns = {_tag(tag): index for index, tag in enumerate(loop.tags)}
            p = "_diffrn_refln"
            third = "chi" if p + "_angle_chi" in columns else "kappa"
            extra = tuple(p + "_angle_" + angle for angle in ("omega", "phi", third))
            count, complete = _indexed_rows(loop, p, extra)
            measured += count
            angles += complete
            count, _ = _indexed_rows(loop, "_diffrn_orient_refln", ())
            orient += count
            face_tags = tuple("_exptl_crystal_face_index_" + axis for axis in "hkl")
            distance = "_exptl_crystal_face_perp_dist"
            if all(tag in columns for tag in (*face_tags, distance)):
                for start in range(0, len(loop.values), loop.width()):
                    row = loop.values[start:start + loop.width()]
                    hkl = [_number(row[columns[tag]]) for tag in face_tags]
                    dist = _number(row[columns[distance]])
                    if (all(value is not None for value in hkl)
                            and any(value != 0 for value in hkl)
                            and dist is not None and dist > 0):
                        faces += 1
            oxford |= any(tag.startswith("_exptl_oxdiff_crystal_face_")
                          for tag in columns)
        details = gemmi.cif.as_string(scalars.get("_diffrn_measurement_details", "?"))
        convention = gemmi.cif.as_string(scalars.get("_diffrn_orient_matrix_type", "?"))
        mu = _number(scalars.get("_exptl_absorpt_coefficient_mu"))
        reports.append(GeometryInventory(
            block.name, status, matrix, convention,
            bool(re.search(r"\blist\s+of\s+runs\b", details, re.I)),
            measured, angles, orient, faces, oxford,
            mu if mu is not None and mu >= 0 else None,
        ))
    return tuple(reports)
