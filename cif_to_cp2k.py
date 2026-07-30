#!/usr/bin/env python3
"""Create a full-cell CP2K ``&SUBSYS`` include from a crystallographic CIF.

The converter is intentionally conservative.  It reads unit-cell parameters,
atom coordinates and explicit CIF symmetry operations, expands the asymmetric
unit into a complete conventional cell, rejects partial occupancies, and emits
fractional CP2K coordinates.  Unsupported or ambiguous CIF constructs fail
loudly rather than producing a chemically incomplete periodic calculation.
"""

from __future__ import annotations

import argparse
import ast
from dataclasses import dataclass
from fractions import Fraction
import math
from pathlib import Path
import re
import shlex
from typing import Iterable, Sequence

import numpy as np


class CIFError(RuntimeError):
    """Raised when a CIF cannot be converted safely."""


def strip_esd(value: str) -> float:
    value = value.strip()
    if value in {"?", "."}:
        raise CIFError(f"missing numeric CIF value: {value}")
    value = re.sub(r"\([^)]*\)$", "", value)
    return float(value)


def tokenize_cif(text: str) -> list[str]:
    tokens: list[str] = []
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        raw = lines[i]
        stripped = raw.strip()
        i += 1
        if not stripped or stripped.startswith("#"):
            continue
        if raw.startswith(";"):
            block: list[str] = []
            while i < len(lines) and not lines[i].startswith(";"):
                block.append(lines[i])
                i += 1
            if i >= len(lines):
                raise CIFError("unterminated semicolon text field")
            i += 1
            tokens.append("\n".join(block))
            continue
        lexer = shlex.shlex(raw, posix=True)
        lexer.whitespace_split = True
        lexer.commenters = "#"
        tokens.extend(list(lexer))
    return tokens


def parse_cif(text: str) -> tuple[dict[str, str], list[tuple[list[str], list[list[str]]]]]:
    tokens = tokenize_cif(text)
    scalars: dict[str, str] = {}
    loops: list[tuple[list[str], list[list[str]]]] = []
    i = 0
    while i < len(tokens):
        token = tokens[i]
        lower = token.lower()
        if lower == "loop_":
            i += 1
            tags: list[str] = []
            while i < len(tokens) and tokens[i].startswith("_"):
                tags.append(tokens[i].lower())
                i += 1
            if not tags:
                raise CIFError("loop_ without tags")
            values: list[str] = []
            while i < len(tokens):
                next_token = tokens[i]
                next_lower = next_token.lower()
                if next_token.startswith("_") or next_lower == "loop_" or next_lower.startswith("data_"):
                    break
                values.append(next_token)
                i += 1
            if len(values) % len(tags):
                raise CIFError(
                    f"loop with {len(tags)} tags contains {len(values)} values"
                )
            rows = [values[j : j + len(tags)] for j in range(0, len(values), len(tags))]
            loops.append((tags, rows))
        elif token.startswith("_"):
            if i + 1 >= len(tokens):
                raise CIFError(f"missing value for CIF tag {token}")
            scalars[lower] = tokens[i + 1]
            i += 2
        else:
            i += 1
    return scalars, loops


def cell_vectors_from_parameters(
    a: float, b: float, c: float, alpha_deg: float, beta_deg: float, gamma_deg: float
) -> tuple[tuple[float, float, float], ...]:
    alpha = math.radians(alpha_deg)
    beta = math.radians(beta_deg)
    gamma = math.radians(gamma_deg)
    sin_gamma = math.sin(gamma)
    if abs(sin_gamma) < 1.0e-12:
        raise CIFError("cell gamma angle produces a singular Cartesian embedding")
    avec = (a, 0.0, 0.0)
    bvec = (b * math.cos(gamma), b * math.sin(gamma), 0.0)
    cx = c * math.cos(beta)
    cy = c * (math.cos(alpha) - math.cos(beta) * math.cos(gamma)) / sin_gamma
    cz2 = c * c - cx * cx - cy * cy
    if cz2 < -1.0e-8:
        raise CIFError("cell parameters produce a negative c_z^2")
    cvec = (cx, cy, math.sqrt(max(0.0, cz2)))
    return avec, bvec, cvec


def element_from_label(label: str) -> str:
    match = re.match(r"([A-Za-z]{1,2})", label.strip())
    if not match:
        raise CIFError(f"cannot infer element from atom label {label!r}")
    raw = match.group(1)
    return raw[0].upper() + raw[1:].lower()


@dataclass(frozen=True)
class LinearForm:
    coefficients: tuple[Fraction, Fraction, Fraction]
    constant: Fraction

    @classmethod
    def scalar(cls, value: Fraction) -> "LinearForm":
        return cls((Fraction(0), Fraction(0), Fraction(0)), value)

    @property
    def is_scalar(self) -> bool:
        return all(value == 0 for value in self.coefficients)

    def __add__(self, other: "LinearForm") -> "LinearForm":
        return LinearForm(
            tuple(a + b for a, b in zip(self.coefficients, other.coefficients, strict=True)),
            self.constant + other.constant,
        )

    def __sub__(self, other: "LinearForm") -> "LinearForm":
        return LinearForm(
            tuple(a - b for a, b in zip(self.coefficients, other.coefficients, strict=True)),
            self.constant - other.constant,
        )

    def scale(self, factor: Fraction) -> "LinearForm":
        return LinearForm(tuple(factor * value for value in self.coefficients), factor * self.constant)


@dataclass(frozen=True)
class SymmetryOperation:
    matrix: np.ndarray
    translation: np.ndarray
    source: str

    def apply(self, fractional: np.ndarray) -> np.ndarray:
        value = self.matrix @ fractional + self.translation
        value = value - np.floor(value)
        value[np.isclose(value, 1.0, atol=1.0e-12)] = 0.0
        return value


def _linear_form_from_ast(node: ast.AST) -> LinearForm:
    if isinstance(node, ast.Expression):
        return _linear_form_from_ast(node.body)
    if isinstance(node, ast.Name):
        names = {"x": 0, "y": 1, "z": 2}
        try:
            index = names[node.id.lower()]
        except KeyError as exc:
            raise CIFError(f"unsupported symbol in symmetry operation: {node.id}") from exc
        coefficients = [Fraction(0), Fraction(0), Fraction(0)]
        coefficients[index] = Fraction(1)
        return LinearForm(tuple(coefficients), Fraction(0))
    if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
        return LinearForm.scalar(Fraction(str(node.value)))
    if isinstance(node, ast.UnaryOp):
        value = _linear_form_from_ast(node.operand)
        if isinstance(node.op, ast.UAdd):
            return value
        if isinstance(node.op, ast.USub):
            return value.scale(Fraction(-1))
    if isinstance(node, ast.BinOp):
        left = _linear_form_from_ast(node.left)
        right = _linear_form_from_ast(node.right)
        if isinstance(node.op, ast.Add):
            return left + right
        if isinstance(node.op, ast.Sub):
            return left - right
        if isinstance(node.op, ast.Mult):
            if left.is_scalar:
                return right.scale(left.constant)
            if right.is_scalar:
                return left.scale(right.constant)
            raise CIFError("nonlinear product in symmetry operation")
        if isinstance(node.op, ast.Div):
            if not right.is_scalar or right.constant == 0:
                raise CIFError("symmetry-operation divisor must be a nonzero scalar")
            return left.scale(Fraction(1, 1) / right.constant)
    raise CIFError(f"unsupported syntax in symmetry operation: {ast.dump(node, include_attributes=False)}")


def parse_symmetry_operation(value: str) -> SymmetryOperation:
    source = value.strip().strip("'\"")
    components = [component.strip() for component in source.split(",")]
    if len(components) != 3:
        raise CIFError(f"symmetry operation must have three comma-separated components: {source!r}")
    forms: list[LinearForm] = []
    for component in components:
        try:
            tree = ast.parse(component.replace("^", "**"), mode="eval")
        except SyntaxError as exc:
            raise CIFError(f"invalid symmetry expression {component!r}") from exc
        forms.append(_linear_form_from_ast(tree))
    matrix = np.asarray([[float(value) for value in form.coefficients] for form in forms], dtype=float)
    translation = np.asarray([float(form.constant) for form in forms], dtype=float)
    determinant = float(np.linalg.det(matrix))
    if not math.isclose(abs(determinant), 1.0, abs_tol=1.0e-10):
        raise CIFError(f"symmetry operation has non-unimodular rotation: {source!r}")
    return SymmetryOperation(matrix=matrix, translation=translation, source=source)


_SYMOP_TAGS = (
    "_space_group_symop_operation_xyz",
    "_space_group_symop.operation_xyz",
    "_symmetry_equiv_pos_as_xyz",
    "_symmetry_equiv.pos_as_xyz",
)


def _space_group_is_p1(scalars: dict[str, str]) -> bool:
    for tag in ("_space_group_it_number", "_symmetry_int_tables_number"):
        if tag in scalars:
            try:
                return int(float(scalars[tag])) == 1
            except ValueError:
                pass
    for tag in (
        "_space_group_name_h-m_alt",
        "_symmetry_space_group_name_h-m",
        "_space_group_name_h-m_ref",
    ):
        if tag in scalars:
            normalized = re.sub(r"[\s'\"]+", "", scalars[tag]).lower()
            return normalized in {"p1", "p01"}
    return False


def symmetry_operations(
    scalars: dict[str, str], loops: Sequence[tuple[list[str], list[list[str]]]]
) -> list[SymmetryOperation]:
    operations: list[SymmetryOperation] = []
    for tags, rows in loops:
        tag_index = next((tags.index(tag) for tag in _SYMOP_TAGS if tag in tags), None)
        if tag_index is None:
            continue
        operations.extend(parse_symmetry_operation(row[tag_index]) for row in rows)
        break
    if not operations:
        scalar_value = next((scalars[tag] for tag in _SYMOP_TAGS if tag in scalars), None)
        if scalar_value is not None:
            operations.append(parse_symmetry_operation(scalar_value))
    if not operations:
        if not _space_group_is_p1(scalars):
            raise CIFError(
                "CIF has no explicit symmetry-operation list and is not demonstrably P1; "
                "a full periodic CP2K cell cannot be generated safely"
            )
        operations = [parse_symmetry_operation("x,y,z")]
    return operations


def locate_atom_loop(loops: Sequence[tuple[list[str], list[list[str]]]]):
    for tags, rows in loops:
        tagset = set(tags)
        fractional = {
            "_atom_site_fract_x",
            "_atom_site_fract_y",
            "_atom_site_fract_z",
        }
        cartesian = {
            "_atom_site_cartn_x",
            "_atom_site_cartn_y",
            "_atom_site_cartn_z",
        }
        if fractional <= tagset or cartesian <= tagset:
            return tags, rows, fractional <= tagset
    raise CIFError("no atom-site coordinate loop found")


def _periodic_positions_equal(left: np.ndarray, right: np.ndarray, tolerance: float) -> bool:
    difference = np.abs(left - right)
    difference = np.minimum(difference, 1.0 - difference)
    return bool(np.max(difference) <= tolerance)


def expand_atoms(
    *,
    tags: list[str],
    rows: list[list[str]],
    fractional_input: bool,
    cell: np.ndarray,
    operations: Sequence[SymmetryOperation],
    tolerance: float,
    allow_partial_occupancy: bool,
) -> tuple[list[tuple[str, np.ndarray]], int]:
    index = {tag: i for i, tag in enumerate(tags)}
    symbol_tag = "_atom_site_type_symbol" if "_atom_site_type_symbol" in index else None
    label_tag = next(
        (tag for tag in ("_atom_site_label", "_atom_site_cartn_label") if tag in index),
        None,
    )
    if symbol_tag is None and label_tag is None:
        raise CIFError("atom loop has neither a type symbol nor an atom label")
    coordinate_tags = (
        ("_atom_site_fract_x", "_atom_site_fract_y", "_atom_site_fract_z")
        if fractional_input
        else ("_atom_site_cartn_x", "_atom_site_cartn_y", "_atom_site_cartn_z")
    )
    occupancy_tag = next(
        (tag for tag in ("_atom_site_occupancy", "_atom_site_cartn_occupancy") if tag in index),
        None,
    )
    inverse_cell = np.linalg.inv(cell)
    asymmetric: list[tuple[str, np.ndarray]] = []
    for row_number, row in enumerate(rows, start=1):
        raw_symbol = row[index[symbol_tag]] if symbol_tag is not None else row[index[label_tag]]
        element = element_from_label(raw_symbol)
        occupancy = 1.0 if occupancy_tag is None else strip_esd(row[index[occupancy_tag]])
        if not math.isclose(occupancy, 1.0, abs_tol=1.0e-8) and not allow_partial_occupancy:
            raise CIFError(
                f"atom row {row_number} ({raw_symbol}) has occupancy {occupancy}; "
                "static periodic CP2K/HAR input requires an explicitly ordered full-occupancy model"
            )
        coordinates = np.asarray([strip_esd(row[index[tag]]) for tag in coordinate_tags], dtype=float)
        fractional = coordinates if fractional_input else coordinates @ inverse_cell
        fractional = fractional - np.floor(fractional)
        asymmetric.append((element, fractional))

    expanded: list[tuple[str, np.ndarray]] = []
    for element, position in asymmetric:
        for operation in operations:
            candidate = operation.apply(position)
            duplicate = any(
                old_element == element and _periodic_positions_equal(old_position, candidate, tolerance)
                for old_element, old_position in expanded
            )
            if not duplicate:
                expanded.append((element, candidate))
    if not expanded:
        raise CIFError("symmetry expansion produced no atoms")
    return expanded, len(asymmetric)


def read_expanded_structure(
    cif_path: Path,
    *,
    symmetry_tolerance: float = 1.0e-7,
    allow_partial_occupancy: bool = False,
) -> tuple[np.ndarray, list[tuple[str, np.ndarray]], int, int]:
    """Read a CIF and return its conventional cell and symmetry-expanded atoms.

    The returned cell vectors are rows in Angstrom and the atom positions are
    fractional coordinates.  Keeping this parser in one place ensures that
    CP2K input generation and the subsequent CP2K/Tonto atom-alignment check
    use exactly the same crystallographic interpretation.
    """

    scalars, loops = parse_cif(cif_path.read_text(encoding="utf-8", errors="replace"))
    required = [
        "_cell_length_a",
        "_cell_length_b",
        "_cell_length_c",
        "_cell_angle_alpha",
        "_cell_angle_beta",
        "_cell_angle_gamma",
    ]
    missing = [tag for tag in required if tag not in scalars]
    if missing:
        raise CIFError("missing unit-cell tags: " + ", ".join(missing))
    values = [strip_esd(scalars[tag]) for tag in required]
    cell = np.asarray(cell_vectors_from_parameters(*values), dtype=float)
    operations = symmetry_operations(scalars, loops)
    tags, rows, fractional_input = locate_atom_loop(loops)
    atoms, asymmetric_count = expand_atoms(
        tags=tags,
        rows=rows,
        fractional_input=fractional_input,
        cell=cell,
        operations=operations,
        tolerance=symmetry_tolerance,
        allow_partial_occupancy=allow_partial_occupancy,
    )
    return cell, atoms, asymmetric_count, len(operations)


def make_subsys(
    cif_path: Path,
    output_path: Path,
    *,
    default_basis: str,
    basis_map: dict[str, str],
    potential: str,
    symmetry_tolerance: float = 1.0e-7,
    allow_partial_occupancy: bool = False,
) -> None:
    cell, atoms, asymmetric_count, operation_count = read_expanded_structure(
        cif_path,
        symmetry_tolerance=symmetry_tolerance,
        allow_partial_occupancy=allow_partial_occupancy,
    )

    elements = sorted({element for element, _ in atoms})
    lines = [
        "! Generated by cif_to_cp2k.py",
        f"! Asymmetric/input atoms: {asymmetric_count}",
        f"! Explicit CIF symmetry operations: {operation_count}",
        f"! Unique atoms in conventional CP2K cell: {len(atoms)}",
        "&SUBSYS",
        "  &CELL",
    ]
    for key, vector in zip(("A", "B", "C"), cell, strict=True):
        lines.append(f"    {key} {vector[0]:.14f} {vector[1]:.14f} {vector[2]:.14f}")
    lines.extend(["    PERIODIC XYZ", "  &END CELL", "  &COORD", "    SCALED T"])
    for element, coordinates in atoms:
        lines.append(
            f"    {element:2s} {coordinates[0]:.14f} {coordinates[1]:.14f} {coordinates[2]:.14f}"
        )
    lines.append("  &END COORD")
    for element in elements:
        basis = basis_map.get(element, default_basis)
        if not basis:
            raise CIFError(f"no CP2K basis configured for element {element}")
        lines.extend(
            [
                f"  &KIND {element}",
                f"    ELEMENT {element}",
                f"    BASIS_SET {basis}",
                f"    POTENTIAL {potential}",
                "  &END KIND",
            ]
        )
    lines.extend(["&END SUBSYS", ""])
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(lines), encoding="utf-8")


def parse_basis_map(values: Sequence[str]) -> dict[str, str]:
    result: dict[str, str] = {}
    for value in values:
        if "=" not in value:
            raise argparse.ArgumentTypeError(f"basis mapping must be ELEMENT=BASIS, got {value!r}")
        element, basis = value.split("=", 1)
        element = element.strip().capitalize()
        basis = basis.strip()
        if not element or not basis:
            raise argparse.ArgumentTypeError(f"invalid basis mapping {value!r}")
        result[element] = basis
    return result


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Expand CIF symmetry and write a full-cell CP2K &SUBSYS include."
    )
    parser.add_argument("--cif", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--basis", required=True, help="default all-electron CP2K basis label")
    parser.add_argument("--basis-map", action="append", default=[], metavar="ELEMENT=BASIS")
    parser.add_argument(
        "--potential", default="ALL", help="CP2K potential label; ALL is required for all-electron HAR"
    )
    parser.add_argument("--symmetry-tolerance", type=float, default=1.0e-7)
    parser.add_argument(
        "--allow-partial-occupancy",
        action="store_true",
        help="allow partial occupancies (diagnostic only; ordered periodic model is preferred)",
    )
    args = parser.parse_args(argv)
    try:
        make_subsys(
            args.cif,
            args.output,
            default_basis=args.basis,
            basis_map=parse_basis_map(args.basis_map),
            potential=args.potential,
            symmetry_tolerance=args.symmetry_tolerance,
            allow_partial_occupancy=args.allow_partial_occupancy,
        )
    except (CIFError, OSError, ValueError, np.linalg.LinAlgError) as exc:
        parser.exit(2, f"cif_to_cp2k: error: {exc}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
