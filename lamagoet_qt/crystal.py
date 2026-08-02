"""Small, dependency-free CIF model used by the lamaGOET Qt viewer.

This is not intended to replace a complete crystallographic CIF library.  It
deliberately supports the coordinate, cell and explicit symmetry constructs
needed for interactive packing/growing.  Unsupported or ambiguous input raises
``CifError`` instead of silently changing the structure.
"""

from __future__ import annotations

import ast
from collections import deque
from dataclasses import dataclass
from fractions import Fraction
import math
from pathlib import Path
import re
import shlex
from typing import Iterable, Sequence


Vector = tuple[float, float, float]
Matrix = tuple[Vector, Vector, Vector]
AdpValues = tuple[float, float, float, float, float, float]


class CifError(RuntimeError):
    pass


def _vadd(a: Vector, b: Vector) -> Vector:
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def _vsub(a: Vector, b: Vector) -> Vector:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _vscale(a: Vector, scale: float) -> Vector:
    return (a[0] * scale, a[1] * scale, a[2] * scale)


def _dot(a: Vector, b: Vector) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _cross(a: Vector, b: Vector) -> Vector:
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def _distance(a: Vector, b: Vector) -> float:
    difference = _vsub(a, b)
    return math.sqrt(_dot(difference, difference))


def _matrix_multiply(left: Matrix, right: Matrix) -> Matrix:
    return tuple(
        tuple(
            sum(left[row][inner] * right[inner][column] for inner in range(3))
            for column in range(3)
        )
        for row in range(3)
    )  # type: ignore[return-value]


def _matrix_transpose(matrix: Matrix) -> Matrix:
    return tuple(
        tuple(matrix[column][row] for column in range(3)) for row in range(3)
    )  # type: ignore[return-value]


def _matrix_from_adp(values: AdpValues) -> Matrix:
    u11, u22, u33, u12, u13, u23 = values
    return ((u11, u12, u13), (u12, u22, u23), (u13, u23, u33))


def _adp_from_matrix(matrix: Matrix) -> AdpValues:
    return (
        matrix[0][0],
        matrix[1][1],
        matrix[2][2],
        matrix[0][1],
        matrix[0][2],
        matrix[1][2],
    )


def ellipsoid_probability_radius(probability: float) -> float:
    """Radius multiplier for a 3-D normal probability ellipsoid."""

    target = min(0.999999, max(0.000001, probability / 100.0))

    def cdf(value: float) -> float:
        root = math.sqrt(value / 2.0)
        return math.erf(root) - math.sqrt(2.0 * value / math.pi) * math.exp(
            -value / 2.0
        )

    low, high = 0.0, 40.0
    for _ in range(80):
        middle = (low + high) / 2.0
        if cdf(middle) < target:
            low = middle
        else:
            high = middle
    return math.sqrt((low + high) / 2.0)


def adp_principal_axes(
    values: AdpValues,
) -> tuple[Vector, tuple[Vector, Vector, Vector]] | None:
    """Return eigenvalues and principal-axis vectors for a Cartesian U tensor.

    The three vectors are returned as columns (one vector per eigenvalue).  A
    compact Jacobi diagonalisation keeps the viewer independent of NumPy while
    following the same sphere-to-principal-axes construction used by
    crystallographic OpenGL viewers such as MoleCoolQt.  Non-positive tensors
    do not describe a physical probability ellipsoid and return ``None``.
    """

    matrix = [list(row) for row in _matrix_from_adp(values)]
    vectors = [[1.0 if row == column else 0.0 for column in range(3)] for row in range(3)]

    for _ in range(32):
        p, q = max(
            ((0, 1), (0, 2), (1, 2)),
            key=lambda pair: abs(matrix[pair[0]][pair[1]]),
        )
        off_diagonal = matrix[p][q]
        scale = max(abs(matrix[p][p]), abs(matrix[q][q]), 1.0)
        if abs(off_diagonal) <= 1.0e-14 * scale:
            break

        angle = 0.5 * math.atan2(
            2.0 * off_diagonal, matrix[q][q] - matrix[p][p]
        )
        cosine = math.cos(angle)
        sine = math.sin(angle)
        app, aqq = matrix[p][p], matrix[q][q]
        matrix[p][p] = (
            cosine * cosine * app
            - 2.0 * sine * cosine * off_diagonal
            + sine * sine * aqq
        )
        matrix[q][q] = (
            sine * sine * app
            + 2.0 * sine * cosine * off_diagonal
            + cosine * cosine * aqq
        )
        matrix[p][q] = matrix[q][p] = 0.0

        for index in range(3):
            if index in (p, q):
                continue
            aip, aiq = matrix[index][p], matrix[index][q]
            matrix[index][p] = matrix[p][index] = cosine * aip - sine * aiq
            matrix[index][q] = matrix[q][index] = sine * aip + cosine * aiq

        for row in range(3):
            vip, viq = vectors[row][p], vectors[row][q]
            vectors[row][p] = cosine * vip - sine * viq
            vectors[row][q] = sine * vip + cosine * viq

    eigenpairs = sorted(
        (
            matrix[index][index],
            tuple(vectors[row][index] for row in range(3)),
        )
        for index in range(3)
    )
    if eigenpairs[0][0] <= 1.0e-10:
        return None

    eigenvalues: Vector = tuple(pair[0] for pair in eigenpairs)  # type: ignore[assignment]
    axes = [pair[1] for pair in eigenpairs]
    handedness = _dot(axes[0], _cross(axes[1], axes[2]))
    if handedness < 0.0:
        axes[2] = _vscale(axes[2], -1.0)
    return eigenvalues, tuple(axes)  # type: ignore[return-value]


def _number(value: str) -> float:
    cleaned = re.sub(r"\([^)]*\)$", "", value.strip())
    if cleaned in {"", ".", "?"}:
        raise CifError(f"missing numeric CIF value {value!r}")
    return float(cleaned)


def _tokenize(text: str) -> list[str]:
    result: list[str] = []
    lines = text.splitlines()
    line_number = 0
    while line_number < len(lines):
        raw = lines[line_number]
        line_number += 1
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        if raw.startswith(";"):
            block: list[str] = []
            while line_number < len(lines) and not lines[line_number].startswith(";"):
                block.append(lines[line_number])
                line_number += 1
            if line_number == len(lines):
                raise CifError("unterminated CIF semicolon text field")
            line_number += 1
            result.append("\n".join(block))
            continue
        lexer = shlex.shlex(raw, posix=True)
        lexer.whitespace_split = True
        lexer.commenters = "#"
        result.extend(lexer)
    return result


def _parse(text: str) -> tuple[dict[str, str], list[tuple[list[str], list[list[str]]]]]:
    tokens = _tokenize(text)
    scalars: dict[str, str] = {}
    loops: list[tuple[list[str], list[list[str]]]] = []
    cursor = 0
    while cursor < len(tokens):
        token = tokens[cursor]
        lower = token.lower()
        if lower == "loop_":
            cursor += 1
            tags: list[str] = []
            while cursor < len(tokens) and tokens[cursor].startswith("_"):
                tags.append(tokens[cursor].lower())
                cursor += 1
            if not tags:
                raise CifError("loop_ without column tags")
            values: list[str] = []
            while cursor < len(tokens):
                candidate = tokens[cursor]
                candidate_lower = candidate.lower()
                if (
                    candidate.startswith("_")
                    or candidate_lower == "loop_"
                    or candidate_lower.startswith("data_")
                ):
                    break
                values.append(candidate)
                cursor += 1
            if len(values) % len(tags):
                raise CifError("CIF loop contains an incomplete row")
            rows = [
                values[index : index + len(tags)]
                for index in range(0, len(values), len(tags))
            ]
            loops.append((tags, rows))
        elif token.startswith("_"):
            if cursor + 1 >= len(tokens):
                raise CifError(f"missing value for {token}")
            scalars[lower] = tokens[cursor + 1]
            cursor += 2
        else:
            cursor += 1
    return scalars, loops


@dataclass(frozen=True)
class _LinearForm:
    coefficients: tuple[Fraction, Fraction, Fraction]
    constant: Fraction

    @classmethod
    def scalar(cls, value: Fraction) -> "_LinearForm":
        return cls((Fraction(0), Fraction(0), Fraction(0)), value)

    @property
    def is_scalar(self) -> bool:
        return all(value == 0 for value in self.coefficients)

    def add(self, other: "_LinearForm", sign: int = 1) -> "_LinearForm":
        return _LinearForm(
            tuple(
                left + sign * right
                for left, right in zip(self.coefficients, other.coefficients)
            ),
            self.constant + sign * other.constant,
        )

    def scale(self, scale: Fraction) -> "_LinearForm":
        return _LinearForm(
            tuple(value * scale for value in self.coefficients),
            self.constant * scale,
        )


def _linear_form(node: ast.AST) -> _LinearForm:
    if isinstance(node, ast.Expression):
        return _linear_form(node.body)
    if isinstance(node, ast.Name) and node.id.lower() in {"x", "y", "z"}:
        coefficients = [Fraction(0), Fraction(0), Fraction(0)]
        coefficients[{"x": 0, "y": 1, "z": 2}[node.id.lower()]] = Fraction(1)
        return _LinearForm(tuple(coefficients), Fraction(0))
    if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
        return _LinearForm.scalar(Fraction(str(node.value)))
    if isinstance(node, ast.UnaryOp):
        value = _linear_form(node.operand)
        if isinstance(node.op, ast.UAdd):
            return value
        if isinstance(node.op, ast.USub):
            return value.scale(Fraction(-1))
    if isinstance(node, ast.BinOp):
        left = _linear_form(node.left)
        right = _linear_form(node.right)
        if isinstance(node.op, ast.Add):
            return left.add(right)
        if isinstance(node.op, ast.Sub):
            return left.add(right, -1)
        if isinstance(node.op, ast.Mult):
            if left.is_scalar:
                return right.scale(left.constant)
            if right.is_scalar:
                return left.scale(right.constant)
        if isinstance(node.op, ast.Div) and right.is_scalar and right.constant:
            return left.scale(Fraction(1) / right.constant)
    raise CifError(
        "unsupported or nonlinear expression in CIF symmetry operation: "
        + ast.dump(node, include_attributes=False)
    )


@dataclass(frozen=True)
class SymmetryOperation:
    matrix: Matrix
    translation: Vector
    source: str

    def apply(self, fractional: Vector, *, wrap: bool = True) -> Vector:
        result = tuple(
            _dot(row, fractional) + shift
            for row, shift in zip(self.matrix, self.translation)
        )
        if wrap:
            result = tuple(value - math.floor(value + 1.0e-12) for value in result)
        return result


def _symmetry_operation(source: str) -> SymmetryOperation:
    expression = source.strip().strip("'\"")
    components = [component.strip() for component in expression.split(",")]
    if len(components) != 3:
        raise CifError(f"invalid symmetry operation {source!r}")
    forms: list[_LinearForm] = []
    for component in components:
        try:
            forms.append(_linear_form(ast.parse(component, mode="eval")))
        except SyntaxError as exc:
            raise CifError(f"invalid symmetry operation {source!r}") from exc
    matrix: Matrix = tuple(
        tuple(float(value) for value in form.coefficients) for form in forms
    )  # type: ignore[assignment]
    translation: Vector = tuple(float(form.constant) for form in forms)  # type: ignore[assignment]
    return SymmetryOperation(matrix, translation, expression)


@dataclass(frozen=True)
class Cell:
    a: float
    b: float
    c: float
    alpha: float
    beta: float
    gamma: float
    vectors: Matrix

    @classmethod
    def from_parameters(
        cls, a: float, b: float, c: float, alpha: float, beta: float, gamma: float
    ) -> "Cell":
        ar, br, gr = map(math.radians, (alpha, beta, gamma))
        sin_gamma = math.sin(gr)
        if abs(sin_gamma) < 1.0e-12:
            raise CifError("singular unit-cell gamma angle")
        avec: Vector = (a, 0.0, 0.0)
        bvec: Vector = (b * math.cos(gr), b * sin_gamma, 0.0)
        cx = c * math.cos(br)
        cy = c * (math.cos(ar) - math.cos(br) * math.cos(gr)) / sin_gamma
        cz2 = c * c - cx * cx - cy * cy
        if cz2 < -1.0e-8:
            raise CifError("unit-cell parameters do not form a valid Cartesian cell")
        cvec: Vector = (cx, cy, math.sqrt(max(0.0, cz2)))
        return cls(a, b, c, alpha, beta, gamma, (avec, bvec, cvec))

    def fractional_to_cartesian(self, fractional: Vector) -> Vector:
        return tuple(
            fractional[0] * self.vectors[0][axis]
            + fractional[1] * self.vectors[1][axis]
            + fractional[2] * self.vectors[2][axis]
            for axis in range(3)
        )  # type: ignore[return-value]

    def cartesian_to_fractional(self, cartesian: Vector) -> Vector:
        avec, bvec, cvec = self.vectors
        volume = _dot(avec, _cross(bvec, cvec))
        if abs(volume) < 1.0e-12:
            raise CifError("singular unit cell")
        return (
            _dot(cartesian, _cross(bvec, cvec)) / volume,
            _dot(cartesian, _cross(cvec, avec)) / volume,
            _dot(cartesian, _cross(avec, bvec)) / volume,
        )

    @property
    def reciprocal_lengths(self) -> Vector:
        avec, bvec, cvec = self.vectors
        volume = abs(_dot(avec, _cross(bvec, cvec)))
        if volume < 1.0e-12:
            raise CifError("singular unit cell")
        return (
            math.sqrt(_dot(_cross(bvec, cvec), _cross(bvec, cvec))) / volume,
            math.sqrt(_dot(_cross(cvec, avec), _cross(cvec, avec))) / volume,
            math.sqrt(_dot(_cross(avec, bvec), _cross(avec, bvec))) / volume,
        )

    @property
    def direct_matrix(self) -> Matrix:
        """Return the fractional-to-Cartesian matrix with basis vectors as columns."""

        return tuple(
            tuple(self.vectors[column][row] for column in range(3))
            for row in range(3)
        )  # type: ignore[return-value]

    def uij_to_fractional_covariance(self, values: AdpValues) -> Matrix:
        """Convert CIF Uij values to the fractional-coordinate covariance tensor."""

        reciprocal = self.reciprocal_lengths
        tensor = _matrix_from_adp(values)
        return tuple(
            tuple(
                tensor[row][column] * reciprocal[row] * reciprocal[column]
                for column in range(3)
            )
            for row in range(3)
        )  # type: ignore[return-value]

    def fractional_covariance_to_uij(self, covariance: Matrix) -> AdpValues:
        reciprocal = self.reciprocal_lengths
        tensor = tuple(
            tuple(
                covariance[row][column]
                / (reciprocal[row] * reciprocal[column])
                for column in range(3)
            )
            for row in range(3)
        )
        return _adp_from_matrix(tensor)  # type: ignore[arg-type]

    def fractional_covariance_to_cartesian(self, covariance: Matrix) -> Matrix:
        direct = self.direct_matrix
        return _matrix_multiply(
            _matrix_multiply(direct, covariance), _matrix_transpose(direct)
        )

    def transform_uij(
        self, values: AdpValues, operation: SymmetryOperation
    ) -> tuple[AdpValues, AdpValues]:
        """Apply a CIF symmetry rotation and return (CIF Uij, Cartesian U)."""

        fractional = self.uij_to_fractional_covariance(values)
        rotated = _matrix_multiply(
            _matrix_multiply(operation.matrix, fractional),
            _matrix_transpose(operation.matrix),
        )
        transformed_uij = self.fractional_covariance_to_uij(rotated)
        cartesian = self.fractional_covariance_to_cartesian(rotated)
        return transformed_uij, _adp_from_matrix(cartesian)


@dataclass(frozen=True)
class AtomSite:
    label: str
    element: str
    fractional: Vector
    occupancy: float = 1.0
    u_iso: float | None = None
    u_aniso: AdpValues | None = None
    disorder_group: int = 0


@dataclass(frozen=True)
class DisplayAtom:
    label: str
    element: str
    fractional: Vector
    cartesian: Vector
    source_index: int
    symmetry_index: int
    translation: tuple[int, int, int] = (0, 0, 0)
    occupancy: float = 1.0
    u_iso: float | None = None
    u_aniso: AdpValues | None = None
    u_cartesian: AdpValues | None = None
    disorder_group: int = 0


_SYMMETRY_TAGS = (
    "_space_group_symop_operation_xyz",
    "_space_group_symop.operation_xyz",
    "_symmetry_equiv_pos_as_xyz",
    "_symmetry_equiv.pos_as_xyz",
)


def _element(value: str) -> str:
    match = re.match(r"([A-Za-z]{1,2})", value.strip())
    if not match:
        raise CifError(f"cannot determine element from atom label {value!r}")
    raw = match.group(1)
    return raw[0].upper() + raw[1:].lower()


def _periodically_equal(left: Vector, right: Vector, tolerance: float = 1.0e-6) -> bool:
    for a, b in zip(left, right):
        difference = abs(a - b)
        difference = min(difference, abs(1.0 - difference))
        if difference > tolerance:
            return False
    return True


@dataclass
class CrystalStructure:
    cell: Cell
    asymmetric_atoms: list[AtomSite]
    symmetry_operations: list[SymmetryOperation]
    space_group_name: str = "P 1"
    space_group_number: str = "1"
    source_path: Path | None = None
    space_group_hall: str = "P 1"

    @classmethod
    def from_cif(cls, path: str | Path) -> "CrystalStructure":
        cif_path = Path(path)
        scalars, loops = _parse(
            cif_path.read_text(encoding="utf-8", errors="replace")
        )
        cell_tags = (
            "_cell_length_a",
            "_cell_length_b",
            "_cell_length_c",
            "_cell_angle_alpha",
            "_cell_angle_beta",
            "_cell_angle_gamma",
        )
        missing = [tag for tag in cell_tags if tag not in scalars]
        if missing:
            raise CifError("missing unit-cell values: " + ", ".join(missing))
        cell = Cell.from_parameters(*(_number(scalars[tag]) for tag in cell_tags))

        operations: list[SymmetryOperation] = []
        for tags, rows in loops:
            symmetry_tag = next((tag for tag in _SYMMETRY_TAGS if tag in tags), None)
            if symmetry_tag:
                column = tags.index(symmetry_tag)
                operations = [_symmetry_operation(row[column]) for row in rows]
                break
        if not operations:
            scalar_symmetry = next(
                (scalars[tag] for tag in _SYMMETRY_TAGS if tag in scalars), None
            )
            if scalar_symmetry:
                operations = [_symmetry_operation(scalar_symmetry)]
        if not operations:
            p1_values = " ".join(
                scalars.get(tag, "")
                for tag in (
                    "_space_group_name_h-m_alt",
                    "_symmetry_space_group_name_h-m",
                    "_space_group_it_number",
                    "_symmetry_int_tables_number",
                )
            )
            if not re.search(r"(^|\s|')p\s*1($|\s|')|(^|\s)1($|\s)", p1_values, re.I):
                raise CifError(
                    "CIF contains no explicit symmetry operations and is not clearly P1"
                )
            operations = [_symmetry_operation("x,y,z")]

        atom_loop = None
        for tags, rows in loops:
            if {
                "_atom_site_fract_x",
                "_atom_site_fract_y",
                "_atom_site_fract_z",
            } <= set(tags) or {
                "_atom_site_cartn_x",
                "_atom_site_cartn_y",
                "_atom_site_cartn_z",
            } <= set(tags):
                atom_loop = (tags, rows)
                break
        if atom_loop is None:
            raise CifError("CIF has no atom-site coordinate loop")
        tags, rows = atom_loop
        columns = {tag: index for index, tag in enumerate(tags)}
        fractional_input = "_atom_site_fract_x" in columns
        coordinate_tags = (
            ("_atom_site_fract_x", "_atom_site_fract_y", "_atom_site_fract_z")
            if fractional_input
            else ("_atom_site_cartn_x", "_atom_site_cartn_y", "_atom_site_cartn_z")
        )
        label_tag = next(
            (
                tag
                for tag in ("_atom_site_label", "_atom_site_cartn_label")
                if tag in columns
            ),
            None,
        )
        symbol_tag = (
            "_atom_site_type_symbol"
            if "_atom_site_type_symbol" in columns
            else label_tag
        )
        if symbol_tag is None:
            raise CifError("atom loop has neither labels nor element symbols")
        occupancy_tag = next(
            (
                tag
                for tag in ("_atom_site_occupancy", "_atom_site_cartn_occupancy")
                if tag in columns
            ),
            None,
        )
        uiso_tag = next(
            (
                tag
                for tag in ("_atom_site_u_iso_or_equiv", "_atom_site_b_iso_or_equiv")
                if tag in columns
            ),
            None,
        )
        disorder_tag = (
            "_atom_site_disorder_group"
            if "_atom_site_disorder_group" in columns
            else None
        )
        atoms: list[AtomSite] = []
        for row_number, row in enumerate(rows, 1):
            raw_symbol = row[columns[symbol_tag]]
            element = _element(raw_symbol)
            label = (
                row[columns[label_tag]]
                if label_tag
                else f"{element}{row_number}"
            )
            coordinates: Vector = tuple(
                _number(row[columns[tag]]) for tag in coordinate_tags
            )  # type: ignore[assignment]
            fractional = (
                coordinates
                if fractional_input
                else cell.cartesian_to_fractional(coordinates)
            )
            occupancy = (
                _number(row[columns[occupancy_tag]]) if occupancy_tag else 1.0
            )
            u_iso = None
            if uiso_tag and row[columns[uiso_tag]] not in {".", "?"}:
                u_iso = _number(row[columns[uiso_tag]])
                if "_b_" in uiso_tag:
                    u_iso /= 8.0 * math.pi * math.pi
            disorder_group = 0
            if disorder_tag and row[columns[disorder_tag]] not in {".", "?"}:
                try:
                    disorder_group = int(float(row[columns[disorder_tag]]))
                except ValueError:
                    disorder_group = 0
            atoms.append(
                AtomSite(
                    label,
                    element,
                    fractional,
                    occupancy,
                    u_iso,
                    None,
                    disorder_group,
                )
            )
        if not atoms:
            raise CifError("CIF atom loop is empty")

        anisotropic: dict[
            str, tuple[float, float, float, float, float, float]
        ] = {}
        for aniso_tags, aniso_rows in loops:
            if "_atom_site_aniso_label" not in aniso_tags:
                continue
            aniso_columns = {
                tag: index for index, tag in enumerate(aniso_tags)
            }
            u_tags = tuple(
                f"_atom_site_aniso_u_{left}{right}"
                for left, right in ((1, 1), (2, 2), (3, 3), (1, 2), (1, 3), (2, 3))
            )
            b_tags = tuple(tag.replace("_u_", "_b_") for tag in u_tags)
            selected_tags = u_tags if set(u_tags) <= set(aniso_tags) else b_tags
            if not set(selected_tags) <= set(aniso_tags):
                continue
            scale = 1.0 if selected_tags is u_tags else 1.0 / (8.0 * math.pi * math.pi)
            for row in aniso_rows:
                label = row[aniso_columns["_atom_site_aniso_label"]]
                try:
                    anisotropic[label] = tuple(
                        _number(row[aniso_columns[tag]]) * scale
                        for tag in selected_tags
                    )  # type: ignore[assignment]
                except CifError:
                    continue
            break
        if anisotropic:
            atoms = [
                AtomSite(
                    atom.label,
                    atom.element,
                    atom.fractional,
                    atom.occupancy,
                    atom.u_iso,
                    anisotropic.get(atom.label),
                    atom.disorder_group,
                )
                for atom in atoms
            ]

        space_group_name = next(
            (
                scalars[tag]
                for tag in (
                    "_space_group_name_h-m_alt",
                    "_symmetry_space_group_name_h-m",
                    "_space_group_name_h-m_ref",
                )
                if tag in scalars
            ),
            "P 1",
        )
        space_group_number = next(
            (
                scalars[tag]
                for tag in (
                    "_space_group_it_number",
                    "_symmetry_int_tables_number",
                )
                if tag in scalars
            ),
            "1",
        )
        space_group_hall = next(
            (
                scalars[tag]
                for tag in (
                    "_space_group_name_hall",
                    "_symmetry_space_group_name_hall",
                )
                if tag in scalars
            ),
            space_group_name,
        )
        return cls(
            cell,
            atoms,
            operations,
            space_group_name,
            space_group_number,
            cif_path.resolve(),
            space_group_hall,
        )

    def asymmetric_unit(self) -> list[DisplayAtom]:
        identity = SymmetryOperation(
            ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)),
            (0.0, 0.0, 0.0),
            "x,y,z",
        )
        result: list[DisplayAtom] = []
        for index, atom in enumerate(self.asymmetric_atoms):
            uij = atom.u_aniso
            u_cartesian = None
            if uij:
                uij, u_cartesian = self.cell.transform_uij(uij, identity)
            result.append(
                DisplayAtom(
                    atom.label,
                    atom.element,
                    atom.fractional,
                    self.cell.fractional_to_cartesian(atom.fractional),
                    index,
                    0,
                    (0, 0, 0),
                    atom.occupancy,
                    atom.u_iso,
                    uij,
                    u_cartesian,
                    atom.disorder_group,
                )
            )
        return result
    def unit_cell(self) -> list[DisplayAtom]:
        result: list[DisplayAtom] = []
        for source_index, atom in enumerate(self.asymmetric_atoms):
            for symmetry_index, operation in enumerate(self.symmetry_operations):
                fractional = operation.apply(atom.fractional)
                if any(
                    existing.element == atom.element
                    and _periodically_equal(existing.fractional, fractional)
                    for existing in result
                ):
                    continue
                uij = atom.u_aniso
                u_cartesian = None
                if uij:
                    uij, u_cartesian = self.cell.transform_uij(uij, operation)
                result.append(
                    DisplayAtom(
                        atom.label,
                        atom.element,
                        fractional,
                        self.cell.fractional_to_cartesian(fractional),
                        source_index,
                        symmetry_index,
                        (0, 0, 0),
                        atom.occupancy,
                        atom.u_iso,
                        uij,
                        u_cartesian,
                        atom.disorder_group,
                    )
                )
        return result

    def translated(
        self,
        atoms: Sequence[DisplayAtom],
        translations: Iterable[tuple[int, int, int]],
    ) -> list[DisplayAtom]:
        result: list[DisplayAtom] = []
        for translation in translations:
            shift: Vector = tuple(float(value) for value in translation)  # type: ignore[assignment]
            for atom in atoms:
                fractional = _vadd(atom.fractional, shift)
                result.append(
                    DisplayAtom(
                        atom.label,
                        atom.element,
                        fractional,
                        self.cell.fractional_to_cartesian(fractional),
                        atom.source_index,
                        atom.symmetry_index,
                        translation,
                        atom.occupancy,
                        atom.u_iso,
                        atom.u_aniso,
                        atom.u_cartesian,
                        atom.disorder_group,
                    )
                )
        return result

    def supercell(self, shell: int = 1) -> list[DisplayAtom]:
        translations = (
            (x, y, z)
            for x in range(-shell, shell + 1)
            for y in range(-shell, shell + 1)
            for z in range(-shell, shell + 1)
        )
        return self.translated(self.unit_cell(), translations)

    def _neighbourhood(
        self, seeds: Sequence[DisplayAtom], shell: int = 1
    ) -> list[DisplayAtom]:
        """Return whole-cell images around the geometry currently on screen."""

        active = list(seeds) or self.asymmetric_unit()
        lower = tuple(
            min(math.floor(atom.fractional[axis]) for atom in active) - shell
            for axis in range(3)
        )
        upper = tuple(
            max(math.floor(atom.fractional[axis]) for atom in active) + shell
            for axis in range(3)
        )
        translations = (
            (x, y, z)
            for x in range(lower[0], upper[0] + 1)
            for y in range(lower[1], upper[1] + 1)
            for z in range(lower[2], upper[2] + 1)
        )
        return self.translated(self.unit_cell(), translations)

    @staticmethod
    def _matching_indices(
        candidates: Sequence[DisplayAtom], seeds: Sequence[DisplayAtom]
    ) -> set[int]:
        return {
            index
            for index, candidate in enumerate(candidates)
            if any(
                (
                    seed.translation == (0, 0, 0)
                    and candidate.translation == (0, 0, 0)
                    and candidate.source_index == seed.source_index
                    and candidate.symmetry_index == seed.symmetry_index
                    and _periodically_equal(candidate.fractional, seed.fractional)
                )
                or (
                    candidate.element == seed.element
                    and _distance(candidate.cartesian, seed.cartesian) <= 1.0e-6
                )
                for seed in seeds
            )
        }

    @staticmethod
    def _unique_atoms(atoms: Iterable[DisplayAtom]) -> list[DisplayAtom]:
        result: list[DisplayAtom] = []
        seen: set[tuple[str, float, float, float]] = set()
        for atom in atoms:
            key = (
                atom.element,
                round(atom.cartesian[0], 7),
                round(atom.cartesian[1], 7),
                round(atom.cartesian[2], 7),
            )
            if key not in seen:
                seen.add(key)
                result.append(atom)
        return result

    def complete_molecules(
        self, seeds: Sequence[DisplayAtom] | None = None
    ) -> list[DisplayAtom]:
        """Complete the CIF fragment using Tonto's defragment connectivity model.

        Tonto starts with the supplied fragment atoms and recursively follows its
        unit-cell covalent-connection table.  We mirror its CCDC covalent radii,
        additive 0.4 Angstrom bond range, H--H lower bound, disorder-group rule,
        and neighbouring-cell search.  A two-cell halo also lets us identify an
        extended covalent network instead of presenting a truncated "molecule".
        """

        active = list(seeds) if seeds is not None else self.asymmetric_unit()
        shell = 2
        candidates = self._neighbourhood(active, shell)
        bonds = infer_bonds(candidates)
        neighbours: list[list[int]] = [[] for _ in candidates]
        for left, right in bonds:
            neighbours[left].append(right)
            neighbours[right].append(left)
        selected = self._matching_indices(candidates, active)
        queue = deque(selected)
        while queue:
            current = queue.popleft()
            for neighbour in neighbours[current]:
                if neighbour not in selected:
                    selected.add(neighbour)
                    queue.append(neighbour)
        lower = tuple(min(atom.translation[axis] for atom in candidates) for axis in range(3))
        upper = tuple(max(atom.translation[axis] for atom in candidates) for axis in range(3))
        if any(
            any(
                candidates[index].translation[axis] in {lower[axis], upper[axis]}
                for axis in range(3)
            )
            for index in selected
        ):
            raise CifError(
                "The selected fragment is part of an extended covalent network; "
                "it cannot be completed as a finite molecule."
            )
        return [candidates[index] for index in sorted(selected)]

    def within_radius(
        self,
        center: DisplayAtom,
        radius: float,
        seeds: Sequence[DisplayAtom] | None = None,
    ) -> list[DisplayAtom]:
        active = list(seeds) if seeds is not None else self.asymmetric_unit()
        added = [
            atom
            for atom in self._neighbourhood([center], 1)
            if _distance(atom.cartesian, center.cartesian) <= radius + 1.0e-8
        ]
        return self._unique_atoms([*active, *added])

    def short_contacts(
        self,
        cutoff: float = 3.5,
        seeds: Sequence[DisplayAtom] | None = None,
    ) -> list[DisplayAtom]:
        active = list(seeds) if seeds is not None else self.asymmetric_unit()
        candidates = self._neighbourhood(active, 1)
        selected: set[int] = set()
        for index, candidate in enumerate(candidates):
            if any(
                _distance(candidate.cartesian, seed.cartesian) <= cutoff
                for seed in active
            ):
                selected.add(index)
        return [candidates[index] for index in sorted(selected)]

    def vdw_contacts(
        self,
        tolerance: float = 0.2,
        seeds: Sequence[DisplayAtom] | None = None,
    ) -> list[DisplayAtom]:
        active = list(seeds) if seeds is not None else self.asymmetric_unit()
        candidates = self._neighbourhood(active, 1)
        selected: set[int] = set()
        for index, candidate in enumerate(candidates):
            candidate_radius = _VDW_RADII.get(candidate.element, 1.8)
            if any(
                _distance(candidate.cartesian, seed.cartesian)
                <= candidate_radius + _VDW_RADII.get(seed.element, 1.8) + tolerance
                for seed in active
            ):
                selected.add(index)
        return [candidates[index] for index in sorted(selected)]


# CCDC radii used by Tonto's ATOM:is_bonded_to routine (Angstrom).
_ELEMENTS = (
    "H He Li Be B C N O F Ne Na Mg Al Si P S Cl Ar K Ca "
    "Sc Ti V Cr Mn Fe Co Ni Cu Zn Ga Ge As Se Br Kr Rb Sr Y Zr "
    "Nb Mo Tc Ru Rh Pd Ag Cd In Sn Sb Te I Xe Cs Ba La Ce Pr Nd "
    "Pm Sm Eu Gd Tb Dy Ho Er Tm Yb Lu Hf Ta W Re Os Ir Pt Au Hg "
    "Tl Pb Bi Po At Rn Fr Ra Ac Th Pa U Np Pu Am Cm Bk Cf Es Fm "
    "Md No Lr Rf Db Sg Bh Hs Mt Ds"
).split()
_CCDC_RADII = (
    0.23, 1.50, 1.28, 0.96, 0.83, 0.68, 0.68, 0.68, 0.64, 1.50,
    1.66, 1.41, 1.21, 1.20, 1.05, 1.02, 0.99, 1.51, 2.03, 1.76,
    1.70, 1.60, 1.53, 1.39, 1.61, 1.52, 1.26, 1.24, 1.32, 1.22,
    1.22, 1.17, 1.21, 1.22, 1.21, 1.50, 2.20, 1.95, 1.90, 1.75,
    1.64, 1.54, 1.47, 1.46, 1.45, 1.39, 1.45, 1.44, 1.42, 1.39,
    1.39, 1.47, 1.40, 1.50, 2.44, 2.15, 2.07, 2.04, 2.03, 2.01,
    1.99, 1.98, 1.98, 1.96, 1.94, 1.92, 1.92, 1.89, 1.90, 1.87,
    1.87, 1.75, 1.70, 1.62, 1.51, 1.44, 1.41, 1.36, 1.50, 1.32,
    1.45, 1.46, 1.48, 1.40, 1.21, 1.50, 2.60, 2.21, 2.15, 2.06,
    2.00, 1.96, 1.90, 1.87, 1.80, 1.69, 1.54, 1.83, 1.50, 1.50,
    1.50, 1.50, 1.50, 1.50, 1.50, 1.50, 1.50, 1.50, 1.50, 1.50,
)
_COVALENT_RADII = dict(zip(_ELEMENTS, _CCDC_RADII))
_TONTO_BOND_RANGE = 0.4

_VDW_RADII = {
    "H": 1.20,
    "He": 1.40,
    "Li": 1.82,
    "Be": 1.53,
    "B": 1.92,
    "C": 1.70,
    "N": 1.55,
    "O": 1.52,
    "F": 1.47,
    "Ne": 1.54,
    "Na": 2.27,
    "Mg": 1.73,
    "Al": 1.84,
    "Si": 2.10,
    "P": 1.80,
    "S": 1.80,
    "Cl": 1.75,
    "Ar": 1.88,
    "K": 2.75,
    "Ca": 2.31,
    "Fe": 2.00,
    "Co": 2.00,
    "Ni": 1.63,
    "Cu": 1.40,
    "Zn": 1.39,
    "Br": 1.85,
    "I": 1.98,
}


def crystal23_spacegroup_record(
    structure: CrystalStructure, setting: str
) -> str:
    """Return the three-column record consumed by the legacy Crystal runner."""

    if setting not in {"h", "r"}:
        raise CifError(f"unsupported Crystal23 setting {setting!r}")
    number = structure.space_group_number.strip() or "1"
    name = structure.space_group_name.strip() or "P 1"
    hall = structure.space_group_hall.strip() or name
    rhombohedral = name.upper().startswith("R")
    token = f"{number}:{setting}" if rhombohedral else number
    it_symbol = f"{name}:{setting}" if rhombohedral else name
    return f"{token} = {it_symbol} = {hall}\n"


def infer_bonds(atoms: Sequence[DisplayAtom]) -> list[tuple[int, int]]:
    """Return the same covalent connections used by Tonto defragment."""

    result: list[tuple[int, int]] = []
    if not atoms:
        return result
    maximum_radius = max(
        _COVALENT_RADII.get(atom.element, 1.50) for atom in atoms
    )
    bucket_size = 2.0 * maximum_radius + _TONTO_BOND_RANGE
    buckets: dict[tuple[int, int, int], list[int]] = {}
    for index, atom in enumerate(atoms):
        key = tuple(
            math.floor(coordinate / bucket_size) for coordinate in atom.cartesian
        )
        buckets.setdefault(key, []).append(index)

    for left, atom_left in enumerate(atoms):
        left_key = tuple(
            math.floor(coordinate / bucket_size)
            for coordinate in atom_left.cartesian
        )
        left_radius = _COVALENT_RADII.get(atom_left.element, 1.50)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    neighbours = buckets.get(
                        (
                            left_key[0] + dx,
                            left_key[1] + dy,
                            left_key[2] + dz,
                        ),
                        (),
                    )
                    for right in neighbours:
                        if right <= left:
                            continue
                        atom_right = atoms[right]
                        if (
                            atom_left.disorder_group
                            * atom_right.disorder_group
                            > 0
                            and atom_left.disorder_group
                            != atom_right.disorder_group
                        ):
                            continue
                        right_radius = _COVALENT_RADII.get(
                            atom_right.element, 1.50
                        )
                        bond = left_radius + right_radius
                        minimum = max(bond - _TONTO_BOND_RANGE, 0.0)
                        if atom_left.element == atom_right.element == "H":
                            minimum = 0.7
                        maximum = bond + _TONTO_BOND_RANGE
                        distance = _distance(
                            atom_left.cartesian, atom_right.cartesian
                        )
                        if minimum < distance < maximum:
                            result.append((left, right))
    return result


def write_grown_cif(
    path: str | Path,
    structure: CrystalStructure,
    atoms: Sequence[DisplayAtom],
    *,
    source_description: str = "manual grow",
) -> Path:
    """Write visible atoms while retaining the source cell and space group."""

    output = Path(path)
    if structure.source_path and output.resolve() == structure.source_path.resolve():
        raise CifError("the grown structure must be saved to a new CIF")
    if not atoms:
        raise CifError("there are no visible atoms to export")
    lines = [
        "data_lamagoet_grown",
        "",
        "_audit_creation_method 'lamaGOET Qt structure viewer'",
        f"_audit_creation_note '{source_description.replace(chr(39), chr(39) * 2)}'",
        f"_space_group_name_H-M_alt '{structure.space_group_name}'",
        f"_space_group_IT_number {structure.space_group_number}",
        f"_cell_length_a {structure.cell.a:.10f}",
        f"_cell_length_b {structure.cell.b:.10f}",
        f"_cell_length_c {structure.cell.c:.10f}",
        f"_cell_angle_alpha {structure.cell.alpha:.10f}",
        f"_cell_angle_beta {structure.cell.beta:.10f}",
        f"_cell_angle_gamma {structure.cell.gamma:.10f}",
        "",
        "loop_",
        "_space_group_symop_id",
        "_space_group_symop_operation_xyz",
    ]
    lines.extend(
        f"{index} '{operation.source}'"
        for index, operation in enumerate(structure.symmetry_operations, 1)
    )
    lines.extend(
        [
        "",
        "loop_",
        "_atom_site_label",
        "_atom_site_type_symbol",
        "_atom_site_fract_x",
        "_atom_site_fract_y",
        "_atom_site_fract_z",
        "_atom_site_occupancy",
        "_atom_site_U_iso_or_equiv",
        ]
    )
    counters: dict[str, int] = {}
    exported: list[tuple[str, DisplayAtom]] = []
    for atom in atoms:
        counters[atom.element] = counters.get(atom.element, 0) + 1
        label = f"{atom.element}{counters[atom.element]}"
        exported.append((label, atom))
        x, y, z = atom.fractional
        u_iso = "." if atom.u_iso is None else f"{atom.u_iso:.8f}"
        lines.append(
            f"{label:<8s} {atom.element:<3s} {x: .12f} {y: .12f} {z: .12f} "
            f"{atom.occupancy:.6f} {u_iso}"
        )
    anisotropic = [(label, atom) for label, atom in exported if atom.u_aniso]
    if anisotropic:
        lines.extend(
            [
                "",
                "loop_",
                "_atom_site_aniso_label",
                "_atom_site_aniso_U_11",
                "_atom_site_aniso_U_22",
                "_atom_site_aniso_U_33",
                "_atom_site_aniso_U_12",
                "_atom_site_aniso_U_13",
                "_atom_site_aniso_U_23",
            ]
        )
        for label, atom in anisotropic:
            values = " ".join(f"{value:.8f}" for value in atom.u_aniso or ())
            lines.append(f"{label:<8s} {values}")
    lines.append("")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    return output.resolve()
