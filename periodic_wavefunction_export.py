#!/usr/bin/env python3
"""Export periodic CP2K/Crystal23 orbitals to a validated TREXIO file.

Standard molecular WFN, WFX and NBO ``.47`` files have no cell, k-point or
Bloch-orbital fields.  This module therefore keeps the periodic wavefunction in
TREXIO.  CP2K orbitals are read from lamaGOET's existing ``MO_KP`` dump.
Crystal23 orbitals are reconstructed by solving

    F(k) C(k) = S(k) C(k) epsilon(k)

from the direct-lattice overlap and Fock/Kohn--Sham matrices in its XML file.
The preferred Crystal23 path takes the exact atom-resolved Gaussian basis from
the matching formatted GRED file.  A separately selected Tonto basis-library
file remains available only for legacy data sets; the XML contains AO labels
but does not contain radial exponents or contractions.
"""

from __future__ import annotations

import argparse
import dataclasses
import gzip
import json
import math
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

import numpy as np

from cp2k_tonto_bridge import AtomRecord, BridgeError, ShellRecord, read_mokp


EXPORT_VERSION = "1.1.0"


_ELEMENT_SYMBOLS = (
    "", "H", "He", "Li", "Be", "B", "C", "N", "O", "F", "Ne",
    "Na", "Mg", "Al", "Si", "P", "S", "Cl", "Ar", "K", "Ca",
    "Sc", "Ti", "V", "Cr", "Mn", "Fe", "Co", "Ni", "Cu", "Zn",
    "Ga", "Ge", "As", "Se", "Br", "Kr", "Rb", "Sr", "Y", "Zr",
    "Nb", "Mo", "Tc", "Ru", "Rh", "Pd", "Ag", "Cd", "In", "Sn",
    "Sb", "Te", "I", "Xe", "Cs", "Ba", "La", "Ce", "Pr", "Nd",
    "Pm", "Sm", "Eu", "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb",
    "Lu", "Hf", "Ta", "W", "Re", "Os", "Ir", "Pt", "Au", "Hg",
    "Tl", "Pb", "Bi", "Po", "At", "Rn", "Fr", "Ra", "Ac", "Th",
    "Pa", "U", "Np", "Pu", "Am", "Cm", "Bk", "Cf", "Es", "Fm",
    "Md", "No", "Lr", "Rf", "Db", "Sg", "Bh", "Hs", "Mt", "Ds",
    "Rg", "Cn", "Nh", "Fl", "Mc", "Lv", "Ts", "Og",
)


class ExportError(RuntimeError):
    """Raised when a periodic orbital export would be incomplete or invalid."""


@dataclasses.dataclass
class PeriodicOrbitals:
    source: str
    cell_bohr: np.ndarray
    atoms: list[AtomRecord]
    shells_by_atom: list[list[ShellRecord]]
    kpoints: np.ndarray
    weights: np.ndarray
    eigenvalues: np.ndarray  # (nk, nspin, nmo)
    occupations: np.ndarray  # (nk, nspin, nmo)
    coefficients: np.ndarray  # (nk, nspin, nao, nmo), TREXIO AO order
    description: str

    @property
    def nk(self) -> int:
        return int(self.kpoints.shape[0])

    @property
    def nspin(self) -> int:
        return int(self.eigenvalues.shape[1])

    @property
    def nmo(self) -> int:
        return int(self.eigenvalues.shape[2])

    @property
    def nao(self) -> int:
        return int(self.coefficients.shape[2])

    def validate(self) -> None:
        if self.cell_bohr.shape != (3, 3):
            raise ExportError(f"cell has shape {self.cell_bohr.shape}, expected (3, 3)")
        if self.kpoints.ndim != 2 or self.kpoints.shape[1] != 3:
            raise ExportError("k points must be an N by 3 array")
        if self.weights.shape != (self.nk,):
            raise ExportError("k-point weights do not match the k-point list")
        if not math.isclose(float(self.weights.sum()), 1.0, rel_tol=1e-8, abs_tol=1e-10):
            raise ExportError(f"k-point weights sum to {self.weights.sum():.16g}, expected one")
        if self.occupations.shape != self.eigenvalues.shape:
            raise ExportError("occupation and eigenvalue arrays have different shapes")
        expected = (self.nk, self.nspin, self.nao, self.nmo)
        if self.coefficients.shape != expected:
            raise ExportError(
                f"coefficient array has shape {self.coefficients.shape}, expected {expected}"
            )
        if len(self.atoms) != len(self.shells_by_atom):
            raise ExportError("atom and atom-basis counts differ")
        expanded = sum(
            2 * shell.l + 1
            for atom_shells in self.shells_by_atom
            for shell in atom_shells
        )
        if expanded != self.nao:
            raise ExportError(f"basis expands to {expanded} AOs, expected {self.nao}")
        if any(atom.z_eff != atom.z_nuc for atom in self.atoms):
            raise ExportError(
                "periodic wavefunction export is restricted to all-electron calculations; "
                "at least one atom has Z_eff different from Z_nuc"
            )
        if not np.all(np.isfinite(self.coefficients)):
            raise ExportError("MO coefficients contain non-finite values")


@dataclasses.dataclass(frozen=True)
class CrystalGredBasis:
    """The exact all-electron atom basis and primitive cell stored by GRED."""

    cell_bohr: np.ndarray
    atoms: list[AtomRecord]
    shells_by_atom: list[list[ShellRecord]]
    nao: int


def _cp2k_to_trexio_permutation(shells_by_atom: list[list[ShellRecord]]) -> np.ndarray:
    """Return CP2K m=-l..l AO indices in TREXIO 0,+1,-1,... order."""

    permutation: list[int] = []
    offset = 0
    for atom_shells in shells_by_atom:
        for shell in atom_shells:
            l = shell.l
            for k in range(1, 2 * l + 2):
                m = ((-1) ** k) * math.floor(k / 2)
                permutation.append(offset + l + m)
            offset += 2 * l + 1
    return np.asarray(permutation, dtype=np.int64)


def _crystal_to_trexio_permutation(shells_by_atom: list[list[ShellRecord]]) -> np.ndarray:
    """Map CRYSTAL's PX,PY,PZ ordering to TREXIO's m=0,+1,-1 order."""

    permutation: list[int] = []
    offset = 0
    for atom_shells in shells_by_atom:
        for shell in atom_shells:
            size = 2 * shell.l + 1
            if shell.l == 1:
                permutation.extend((offset + 2, offset, offset + 1))
            else:
                # CRYSTAL XML uses 0,+1,-1,+2,-2,... for d and higher shells.
                permutation.extend(range(offset, offset + size))
            offset += size
    return np.asarray(permutation, dtype=np.int64)


def read_cp2k_orbitals(mokp_path: Path) -> PeriodicOrbitals:
    metadata = read_mokp(mokp_path, retain_orbitals=True, build_density=False)
    if (
        metadata.eigenvalues_by_kpoint_spin is None
        or metadata.occupations_by_kpoint_spin is None
        or metadata.coefficients_by_kpoint_spin is None
    ):
        raise ExportError("the CP2K MOKP parser did not retain canonical orbitals")

    permutation = _cp2k_to_trexio_permutation(metadata.shells_by_atom)
    coefficients = metadata.coefficients_by_kpoint_spin[:, :, permutation, :].copy()

    # CP2K stores complex k-point coefficients in the gauge of atoms wrapped
    # to the centred cell, while MOKP records the raw particle positions.  This
    # is the same per-atom correction used by CP2K's native TREXIO writer.
    if not metadata.use_real_wfn:
        inv_cell = np.linalg.inv(metadata.cell_bohr)
        for iatom, atom in enumerate(metadata.atoms):
            position = np.asarray(atom.position_bohr, dtype=np.float64)
            fractional = position @ inv_cell
            atom_gauge = -np.rint(fractional)
            first = atom.first_ao - 1
            last = atom.last_ao
            # The atom AO range is contiguous in both the CP2K and TREXIO
            # permutations because ordering changes only within each shell.
            for ik, kpoint in enumerate(metadata.kpoints):
                phase = np.exp(-2j * np.pi * np.dot(kpoint, atom_gauge))
                coefficients[ik, :, first:last, :] *= phase

    description = (
        f"Periodic CP2K Bloch orbitals from {mokp_path.name}; "
        f"{metadata.nmo} bands per k point and spin."
    )
    if metadata.nmo < metadata.nao:
        description += (
            " The virtual space is truncated because NMO is smaller than the AO dimension; "
            "set CP2K ADDED_MOS to -1 for every available virtual orbital."
        )
    result = PeriodicOrbitals(
        source="CP2K",
        cell_bohr=metadata.cell_bohr,
        atoms=metadata.atoms,
        shells_by_atom=metadata.shells_by_atom,
        kpoints=metadata.kpoints,
        weights=metadata.weights,
        eigenvalues=metadata.eigenvalues_by_kpoint_spin,
        occupations=metadata.occupations_by_kpoint_spin,
        coefficients=coefficients,
        description=description,
    )
    result.validate()
    return result


_BASIS_HEADER_RE = re.compile(r"^\s*([A-Z][a-z]?)\s*:[^\s]+\s*$")
_SHELL_RE = re.compile(r"^\s*(\d+)\s+([spdfghSPDFGH])(?:\s+.*)?$")


def read_tonto_basis(path: Path, elements: set[str]) -> dict[str, list[ShellRecord]]:
    """Read the element blocks needed from a Tonto/Turbomole basis library."""

    lines = path.read_text(encoding="utf-8").splitlines()
    result: dict[str, list[ShellRecord]] = {}
    i = 0
    while i < len(lines):
        match = _BASIS_HEADER_RE.match(lines[i])
        if match is None:
            i += 1
            continue
        element = match.group(1)
        i += 1
        while i < len(lines) and lines[i].strip() != "{":
            i += 1
        i += 1
        shells: list[ShellRecord] = []
        while i < len(lines) and lines[i].strip() != "}":
            shell_match = _SHELL_RE.match(lines[i])
            if shell_match is None:
                i += 1
                continue
            nprim = int(shell_match.group(1))
            l = "spdfgh".index(shell_match.group(2).lower())
            exponents: list[float] = []
            coefficients: list[float] = []
            i += 1
            for _ in range(nprim):
                if i >= len(lines):
                    raise ExportError(f"truncated {element} shell in {path}")
                fields = lines[i].replace("D", "E").replace("d", "e").split()
                if len(fields) < 2:
                    raise ExportError(f"malformed primitive line in {path}: {lines[i]}")
                exponents.append(float(fields[0]))
                coefficients.append(float(fields[1]))
                i += 1
            shells.append(ShellRecord(l, tuple(exponents), tuple(coefficients)))
        if element in elements:
            result[element] = shells
        i += 1
    missing = sorted(elements - result.keys())
    if missing:
        raise ExportError(
            f"basis file {path} has no definitions for: {', '.join(missing)}"
        )
    return result


def resolve_basis_file(directory: Path, name: str) -> Path:
    direct = directory / name
    if direct.is_file():
        return direct
    matches = [entry for entry in directory.iterdir() if entry.name.lower() == name.lower()]
    if len(matches) == 1 and matches[0].is_file():
        return matches[0]
    raise ExportError(f"could not find basis {name!r} in {directory}")


class _GredCursor:
    """Small bounds-checked cursor over the formatted CRYAPI numeric stream."""

    def __init__(self, values: np.ndarray, path: Path):
        self.values = values
        self.path = path
        self.index = 0

    def take(self, count: int, section: str) -> np.ndarray:
        if count < 0 or self.index + count > self.values.size:
            raise ExportError(
                f"truncated Crystal23 GRED {section} in {self.path}: "
                f"need {count} values at offset {self.index}, "
                f"only {self.values.size - self.index} remain"
            )
        result = self.values[self.index : self.index + count]
        self.index += count
        return result

    def integers(self, count: int, section: str) -> np.ndarray:
        values = self.take(count, section)
        rounded = np.rint(values)
        if not np.all(np.isfinite(values)) or not np.allclose(
            values, rounded, rtol=0.0, atol=1.0e-8
        ):
            raise ExportError(f"non-integer value in Crystal23 GRED {section}")
        return rounded.astype(np.int64)


def _crystal_gred_contraction(
    angular: int, exponents: np.ndarray, coefficients: np.ndarray
) -> tuple[float, ...]:
    """Undo CRYSTAL's primitive normalization, up to a shell-wide factor.

    The remaining common contraction factor is immaterial because
    :func:`_basis_arrays` normalizes every contracted shell before writing it.
    This is the same transformation used by Tonto's native GRED reader.
    """

    if not np.all(np.isfinite(exponents)) or np.any(exponents <= 0.0):
        raise ExportError("Crystal23 GRED contains invalid Gaussian exponents")
    if not np.all(np.isfinite(coefficients)) or np.max(np.abs(coefficients)) <= 1.0e-14:
        raise ExportError("Crystal23 GRED contains an empty shell contraction")
    factor = math.sqrt(_double_factorial(angular)) / (
        4.0 * exponents
    ) ** (0.5 * angular + 0.75)
    return tuple(float(value) for value in coefficients * factor)


def read_crystal23_gred_basis(path: Path) -> CrystalGredBasis:
    """Read the exact atom-resolved all-electron Gaussian basis from GRED.

    Only the documented CRYAPI prefix through the shell-to-atom map is needed.
    The large direct-space matrices later in the file are deliberately not
    interpreted here; the matching XML remains the source of S(R) and F(R).
    """

    try:
        with path.open("r", encoding="utf-8", errors="strict") as stream:
            title = stream.readline()
            numeric_text = stream.read().replace("D", "E").replace("d", "e")
    except OSError as exc:
        raise ExportError(f"could not read Crystal23 GRED {path}: {exc}") from exc
    if not title:
        raise ExportError(f"empty Crystal23 GRED file: {path}")
    values = np.fromstring(numeric_text, sep=" ", dtype=np.float64)
    cursor = _GredCursor(values, path)
    dimensions = cursor.integers(3, "dimension header")
    luminf, lumtol, lumpar = map(int, dimensions)
    if luminf < 145 or lumtol <= 0 or lumpar <= 0:
        raise ExportError(f"invalid Crystal23 GRED dimensions in {path}")
    inf = cursor.integers(luminf, "INF control array")
    cursor.take(lumtol, "ITOL control array")
    cursor.take(lumpar, "PAR control array")

    n_sym = int(inf[1])
    n_stars = int(inf[4])
    n_basis = int(inf[6])
    n_shells = int(inf[19])
    n_atoms = int(inf[23])
    n_primitives = int(inf[74])
    n_lattice = int(inf[78])
    n_spin = int(inf[63]) + 1
    if min(n_sym, n_basis, n_shells, n_atoms, n_primitives, n_lattice) <= 0:
        raise ExportError(f"invalid Crystal23 GRED system dimensions in {path}")
    if int(inf[30]) != 0:
        raise ExportError(
            "Crystal23 periodic wavefunction export requires an all-electron basis (no ECP)"
        )
    if n_spin != 1:
        raise ExportError(
            "Crystal23 periodic wavefunction export currently supports closed-shell GRED only"
        )

    cell = cursor.take(9, "direct lattice").reshape((3, 3), order="F")
    cursor.take(9, "crystallographic-to-primitive transform")
    cursor.take(n_sym, "inverse symmetry operators")
    cursor.take(48 * 48, "symmetry multiplication table")
    cursor.take(9 * n_sym, "Cartesian symmetry operators")
    cursor.take(3 * n_sym, "symmetry translations")
    cursor.take(n_stars + 1, "direct-vector star radii")
    cursor.take(3 * n_lattice, "Cartesian direct vectors")
    cursor.take(n_stars + 1, "direct-vector star starts")
    cursor.take(n_stars + 1, "direct-vector star ranges")
    cursor.take(n_lattice, "inverse direct-vector indices")
    cursor.take(3 * n_lattice, "integer direct vectors")

    cursor.take(n_atoms, "nuclear charges")
    positions = cursor.take(3 * n_atoms, "atom positions").reshape(
        (3, n_atoms), order="F"
    )
    cursor.take(n_shells, "formal shell charges")
    cursor.take(n_shells, "adjoined shell exponents")
    cursor.take(3 * n_shells, "shell positions")
    primitive_exponents = cursor.take(n_primitives, "primitive exponents")
    contraction_s = cursor.take(n_primitives, "s contraction coefficients")
    contraction_sp = cursor.take(n_primitives, "sp contraction coefficients")
    contraction_high_l = cursor.take(
        n_primitives, "higher-l contraction coefficients"
    )
    cursor.take(n_primitives, "maximum contraction coefficients")
    cursor.take(n_primitives, "old-normalization p coefficients")
    cursor.take(n_primitives, "old-normalization higher-l coefficients")
    atomic_numbers = cursor.integers(n_atoms, "atomic numbers") % 100
    shell_first_for_atom = cursor.integers(
        n_atoms + 1, "first shell for atoms"
    )
    primitive_first_for_shell = cursor.integers(
        n_shells + 1, "first primitive for shells"
    )
    primitives_per_shell = cursor.integers(
        n_shells, "primitives per shell"
    )
    shell_kind = cursor.integers(n_shells, "shell types")
    lattice_aos = cursor.integers(n_shells, "atomic orbitals per shell")
    ao_first_for_shell = cursor.integers(
        n_shells + 1, "first atomic orbital per shell"
    )
    atom_for_shell = cursor.integers(n_shells, "shell-to-atom map")

    if np.any((atomic_numbers < 1) | (atomic_numbers >= len(_ELEMENT_SYMBOLS))):
        raise ExportError("Crystal23 GRED contains an unsupported atomic number")
    if primitive_first_for_shell[0] != 1 or primitive_first_for_shell[-1] != n_primitives + 1:
        raise ExportError("Crystal23 GRED primitive offsets are inconsistent")
    if shell_first_for_atom[0] != 1 or shell_first_for_atom[-1] != n_shells + 1:
        raise ExportError("Crystal23 GRED atom-shell offsets are inconsistent")
    if ao_first_for_shell[0] != 0 or ao_first_for_shell[-1] != n_basis:
        raise ExportError("Crystal23 GRED AO offsets are inconsistent")
    if np.any((atom_for_shell < 1) | (atom_for_shell > n_atoms)):
        raise ExportError("Crystal23 GRED shell-to-atom map is invalid")

    shells_by_atom: list[list[ShellRecord]] = [[] for _ in range(n_atoms)]
    for shell_index in range(n_shells):
        first = int(primitive_first_for_shell[shell_index]) - 1
        count = int(primitives_per_shell[shell_index])
        last = first + count
        if (
            count <= 0
            or first < 0
            or last > n_primitives
            or int(primitive_first_for_shell[shell_index + 1]) != last + 1
        ):
            raise ExportError("Crystal23 GRED primitive ranges are inconsistent")
        kind = int(shell_kind[shell_index])
        if kind < 0 or kind > 5:
            raise ExportError(f"unsupported Crystal23 GRED shell type {kind}")
        exponents = primitive_exponents[first:last]
        if kind == 0:
            parts = ((0, contraction_s[first:last]),)
        elif kind == 1:
            parts = (
                (0, contraction_s[first:last]),
                (1, contraction_sp[first:last]),
            )
        elif kind == 2:
            parts = ((1, contraction_sp[first:last]),)
        else:
            parts = ((kind - 1, contraction_high_l[first:last]),)
        expected_aos = sum(2 * angular + 1 for angular, _ in parts)
        if int(lattice_aos[shell_index]) != expected_aos:
            raise ExportError(
                "Crystal23 GRED shell type and AO count are inconsistent"
            )
        atom_index = int(atom_for_shell[shell_index]) - 1
        for angular, raw_coefficients in parts:
            shells_by_atom[atom_index].append(
                ShellRecord(
                    angular,
                    tuple(float(value) for value in exponents),
                    _crystal_gred_contraction(
                        angular, exponents, raw_coefficients
                    ),
                )
            )

    expanded = [sum(2 * shell.l + 1 for shell in shells) for shells in shells_by_atom]
    if sum(expanded) != n_basis or any(count <= 0 for count in expanded):
        raise ExportError(
            "Crystal23 GRED basis-function count disagrees with its shell metadata"
        )
    atoms: list[AtomRecord] = []
    first_ao = 1
    for index, (z, position, atom_nao) in enumerate(
        zip(atomic_numbers, positions.T, expanded, strict=True), start=1
    ):
        z_value = int(z)
        atoms.append(
            AtomRecord(
                index,
                _ELEMENT_SYMBOLS[z_value],
                z_value,
                z_value,
                tuple(float(value) for value in position),
                first_ao,
                first_ao + atom_nao - 1,
            )
        )
        first_ao += atom_nao
    return CrystalGredBasis(cell, atoms, shells_by_atom, n_basis)


def _parse_xml(path: Path) -> ET.Element:
    if path.suffix.lower() == ".gz":
        with gzip.open(path, "rb") as stream:
            return ET.parse(stream).getroot()
    return ET.parse(path).getroot()


def _required_text(root: ET.Element, xpath: str) -> str:
    node = root.find(xpath)
    if node is None or not (node.text or "").strip():
        raise ExportError(f"Crystal23 XML is missing {xpath}")
    return (node.text or "").strip()


def _float_vector(root: ET.Element, xpath: str, length: int = 3) -> np.ndarray:
    values = np.asarray(
        [float(value.replace("D", "E").replace("d", "e")) for value in _required_text(root, xpath).split()],
        dtype=np.float64,
    )
    if values.shape != (length,):
        raise ExportError(f"{xpath} has {values.size} values, expected {length}")
    return values


def _unzip_lower(values: np.ndarray, n: int) -> np.ndarray:
    expected = n * (n + 1) // 2
    if values.size != expected:
        raise ExportError(f"triangular matrix has {values.size} values, expected {expected}")
    matrix = np.zeros((n, n), dtype=np.float64)
    cursor = 0
    for i in range(n):
        matrix[i, : i + 1] = values[cursor : cursor + i + 1]
        cursor += i + 1
    return matrix


def _read_crystal_triangular_blocks(
    root: ET.Element, parent_tag: str, n: int
) -> dict[tuple[int, int, int], np.ndarray]:
    parent = root.find(f".//{parent_tag}")
    if parent is None:
        raise ExportError(f"Crystal23 XML has no {parent_tag}")
    raw: dict[tuple[int, int, int], np.ndarray] = {}
    for child in parent:
        if "__IVDL." not in child.tag:
            continue
        component_value = next(
            (value for key, value in child.attrib.items() if key.startswith("components_of_IVDL.")),
            None,
        )
        if component_value is None:
            raise ExportError(f"{child.tag} has no direct-lattice vector")
        lattice = tuple(int(value) for value in component_value.split())
        values = np.fromstring((child.text or "").replace("D", "E"), sep=" ")
        raw[lattice] = values
    if not raw:
        raise ExportError(f"Crystal23 XML has no matrix blocks in {parent_tag}")

    blocks: dict[tuple[int, int, int], np.ndarray] = {}
    for lattice, values in raw.items():
        opposite = tuple(-value for value in lattice)
        if opposite not in raw:
            raise ExportError(f"{parent_tag} has {lattice} but not its {-np.asarray(lattice)} pair")
        # Each CRYSTAL record contains the lower triangle of the matrix whose
        # direct-lattice vector labels that record.  Hermiticity supplies the
        # upper triangle of M(R) from M(-R)^T.  Keep the R label attached to
        # its own lower triangle; swapping these records reconstructs M(-R)
        # and consequently evaluates the Bloch operator at -k.
        lower = _unzip_lower(values, n)
        upper_source = _unzip_lower(raw[opposite], n)
        blocks[lattice] = lower + np.tril(upper_source, -1).T
    return blocks


def _fourier_matrix(
    blocks: dict[tuple[int, int, int], np.ndarray], kpoint: np.ndarray
) -> np.ndarray:
    matrix = np.zeros_like(next(iter(blocks.values())), dtype=np.complex128)
    for lattice, block in blocks.items():
        matrix += np.exp(2j * np.pi * np.dot(kpoint, lattice)) * block
    return 0.5 * (matrix + matrix.conj().T)


def _generalized_eigh(
    fock: np.ndarray,
    overlap: np.ndarray,
    overlap_cutoff: float | None = None,
) -> tuple[np.ndarray, np.ndarray]:
    if overlap_cutoff is None:
        try:
            chol = np.linalg.cholesky(overlap)
        except np.linalg.LinAlgError as exc:
            smallest = float(np.linalg.eigvalsh(overlap).min())
            raise ExportError(
                "Crystal23 overlap matrix is not positive definite "
                f"(minimum eigenvalue {smallest:.3e}); if the SCF explicitly "
                "used LDREMO, pass its n x 10^-5 threshold as --overlap-cutoff"
            ) from exc
        left = np.linalg.solve(chol, fock)
        transformed = np.linalg.solve(chol.conj(), left.T).T
        transformed = 0.5 * (transformed + transformed.conj().T)
        energies, vectors_orthogonal = np.linalg.eigh(transformed)
        coefficients = np.linalg.solve(chol.conj().T, vectors_orthogonal)
    else:
        if not math.isfinite(overlap_cutoff) or overlap_cutoff <= 0.0:
            raise ExportError("Crystal23 overlap cutoff must be a positive finite number")
        overlap_values, overlap_vectors = np.linalg.eigh(overlap)
        retained = overlap_values > overlap_cutoff
        if not np.any(retained):
            raise ExportError(
                "Crystal23 overlap cutoff removes every AO direction "
                f"(cutoff {overlap_cutoff:.3e})"
            )
        orthogonalizer = overlap_vectors[:, retained] / np.sqrt(
            overlap_values[retained]
        )[np.newaxis, :]
        transformed = orthogonalizer.conj().T @ fock @ orthogonalizer
        transformed = 0.5 * (transformed + transformed.conj().T)
        energies, vectors_orthogonal = np.linalg.eigh(transformed)
        coefficients = orthogonalizer @ vectors_orthogonal
    expected_identity = np.eye(coefficients.shape[1])
    error = float(
        np.max(
            np.abs(
                coefficients.conj().T @ overlap @ coefficients
                - expected_identity
            )
        )
    )
    if error > 1.0e-8:
        raise ExportError(f"reconstructed Crystal23 MOs are not S-orthonormal (error {error:.3e})")
    return energies, coefficients


def read_crystal23_orbitals(
    xml_path: Path,
    basis_path: Path | None = None,
    *,
    gred_path: Path | None = None,
    overlap_cutoff: float | None = None,
) -> PeriodicOrbitals:
    if (basis_path is None) == (gred_path is None):
        raise ExportError(
            "select exactly one Crystal23 radial-basis source: GRED or a legacy Tonto basis file"
        )
    root = _parse_xml(xml_path)
    nspin = int(_required_text(root, ".//NUMBER_OF_SPIN_COMPONENTS"))
    if nspin != 1:
        raise ExportError(
            "Crystal23 TREXIO reconstruction currently supports restricted one-spin XML files only"
        )
    nao = int(_required_text(root, ".//OUTPUT_DATA/ELECTRONIC_STRUCTURE/NUMBER_OF_ATOMIC_ORBITALS"))
    nband = int(_required_text(root, ".//NUMBER_OF_BANDS"))
    if nband != nao:
        raise ExportError(f"Crystal23 XML reports {nband} bands but {nao} AOs")
    nelectron = int(_required_text(root, ".//NUMBER_OF_ELECTRONS"))
    if nelectron % 2:
        raise ExportError("restricted Crystal23 XML has an odd electron count")

    cell = np.vstack(
        [
            _float_vector(root, ".//CELL_VECTOR_A"),
            _float_vector(root, ".//CELL_VECTOR_B"),
            _float_vector(root, ".//CELL_VECTOR_C"),
        ]
    )
    atom_parent = root.find(".//CARTESIAN_COORDINATES")
    if atom_parent is None:
        raise ExportError("Crystal23 XML has no Cartesian atom list")
    xml_atoms: list[AtomRecord] = []
    first_ao = 1
    atom_shell_counts: list[int] = []
    ao_parent = root.find(".//ATOMIC_ORBITALS")
    if ao_parent is None:
        raise ExportError("Crystal23 XML has no atomic-orbital list")
    for child in ao_parent:
        if child.tag.startswith("ATOMIC_ORBITALS_OF_ATOM."):
            atom_shell_counts.append(int(child.attrib["number_of_atomic_orbitals_per_atom"]))
    atom_nodes = [child for child in atom_parent if child.tag.startswith("ATOM.")]
    if len(atom_shell_counts) != len(atom_nodes):
        raise ExportError("Crystal23 XML atom and per-atom AO counts differ")
    for index, (node, atom_nao) in enumerate(zip(atom_nodes, atom_shell_counts, strict=True), start=1):
        symbol = node.attrib["atomic_symbol"].strip().capitalize()
        z = int(node.attrib["atomic_number"])
        position = tuple(float(value.replace("D", "E")) for value in (node.text or "").split())
        xml_atoms.append(AtomRecord(index, symbol, z, z, position, first_ao, first_ao + atom_nao - 1))
        first_ao += atom_nao

    if gred_path is not None:
        gred_basis = read_crystal23_gred_basis(gred_path)
        if gred_basis.nao != nao:
            raise ExportError(
                f"Crystal23 GRED has {gred_basis.nao} AOs but XML has {nao}"
            )
        if not np.allclose(gred_basis.cell_bohr, cell, rtol=0.0, atol=1.0e-8):
            raise ExportError("Crystal23 GRED and XML primitive cells differ")
        if len(gred_basis.atoms) != len(xml_atoms):
            raise ExportError("Crystal23 GRED and XML atom counts differ")
        for gred_atom, xml_atom in zip(gred_basis.atoms, xml_atoms, strict=True):
            if gred_atom.z_nuc != xml_atom.z_nuc or not np.allclose(
                gred_atom.position_bohr,
                xml_atom.position_bohr,
                rtol=0.0,
                atol=1.0e-8,
            ):
                raise ExportError(
                    "Crystal23 GRED and XML atom ordering or coordinates differ"
                )
        atoms = gred_basis.atoms
        shells_by_atom = gred_basis.shells_by_atom
        basis_description = f"exact atom-resolved basis from {gred_path.name}"
    else:
        assert basis_path is not None
        atoms = xml_atoms
        basis_by_element = read_tonto_basis(
            basis_path, {atom.element for atom in atoms}
        )
        shells_by_atom = [basis_by_element[atom.element] for atom in atoms]
        basis_description = f"legacy Tonto basis {basis_path.name}"
    expanded_by_atom = [sum(2 * shell.l + 1 for shell in shells) for shells in shells_by_atom]
    if expanded_by_atom != atom_shell_counts:
        raise ExportError(
            "selected Crystal23 basis does not match the XML AO layout: "
            f"basis {expanded_by_atom}, XML {atom_shell_counts}"
        )

    k_parent = root.find(".//IRREDUCIBLE_K_VECTORS")
    if k_parent is None:
        raise ExportError("Crystal23 XML has no irreducible k-point list")
    kpoints: list[list[float]] = []
    weights: list[float] = []
    for node in k_parent:
        if node.tag.startswith("K_VECTOR."):
            kpoints.append([float(value.replace("D", "E")) for value in (node.text or "").split()])
            weights.append(float(node.attrib["weight"].replace("D", "E")))
    kpoint_array = np.asarray(kpoints, dtype=np.float64)
    weight_array = np.asarray(weights, dtype=np.float64)

    overlap_blocks = _read_crystal_triangular_blocks(root, "DIRECT_OVERLAP_MATRIX", nao)
    fock_blocks = _read_crystal_triangular_blocks(
        root, "DIRECT_FOCK_KOHN-SHAM_MATRIX", nao
    )
    nk = len(kpoints)
    solved: list[tuple[np.ndarray, np.ndarray]] = []
    permutation = _crystal_to_trexio_permutation(shells_by_atom)
    noccupied = nelectron // 2
    for ik, kpoint in enumerate(kpoint_array):
        overlap = _fourier_matrix(overlap_blocks, kpoint)
        fock = _fourier_matrix(fock_blocks, kpoint)
        energies, crystal_coefficients = _generalized_eigh(
            fock, overlap, overlap_cutoff
        )
        solved.append((energies, crystal_coefficients))

    nmo = min(coefficients_at_k.shape[1] for _, coefficients_at_k in solved)
    if nmo < noccupied:
        raise ExportError(
            f"Crystal23 overlap projection leaves only {nmo} orbitals, "
            f"fewer than the {noccupied} occupied orbitals"
        )
    eigenvalues = np.zeros((nk, 1, nmo), dtype=np.float64)
    occupations = np.zeros((nk, 1, nmo), dtype=np.float64)
    coefficients = np.zeros((nk, 1, nao, nmo), dtype=np.complex128)
    for ik, (energies, crystal_coefficients) in enumerate(solved):
        eigenvalues[ik, 0, :] = energies[:nmo]
        occupations[ik, 0, :noccupied] = 2.0
        coefficients[ik, 0, :, :] = crystal_coefficients[permutation, :nmo]

    result = PeriodicOrbitals(
        source="Crystal23",
        cell_bohr=cell,
        atoms=atoms,
        shells_by_atom=shells_by_atom,
        kpoints=kpoint_array,
        weights=weight_array,
        eigenvalues=eigenvalues,
        occupations=occupations,
        coefficients=coefficients,
        description=(
            f"Periodic Crystal23 canonical orbitals reconstructed from {xml_path.name} "
            "using direct-lattice S and F/Kohn-Sham matrices and "
            f"{basis_description}."
        ),
    )
    if nmo < nao:
        result.description += (
            f" Crystal23 LDREMO overlap projection retained {nmo} of {nao} "
            "linearly independent orbital directions at every stored k point."
        )
    result.validate()
    return result


def _double_factorial(value: int) -> int:
    result = 1
    for term in range(value, 0, -2):
        result *= term
    return result


def _spherical_primitive_norm(l: int, exponent: float) -> float:
    numerator = 2.0 ** (2 * l + 3) * math.factorial(l + 1) * (2.0 * exponent) ** (l + 1.5)
    denominator = math.factorial(2 * l + 2) * math.sqrt(math.pi)
    return math.sqrt(numerator / denominator)


def _spherical_overlap(l: int, left: float, right: float) -> float:
    prefactor = math.sqrt(math.pi) / 2.0 ** (l + 2) * _double_factorial(2 * l + 1)
    return prefactor / (left + right) ** (l + 1.5)


def _basis_arrays(orbitals: PeriodicOrbitals) -> dict[str, np.ndarray]:
    nucleus_index: list[int] = []
    shell_ang_mom: list[int] = []
    shell_factor: list[float] = []
    r_power: list[int] = []
    shell_index: list[int] = []
    exponent: list[float] = []
    coefficient: list[float] = []
    prim_factor: list[float] = []
    ao_shell: list[int] = []
    ao_normalization: list[float] = []

    shell_number = 0
    for atom_index, atom_shells in enumerate(orbitals.shells_by_atom):
        for shell in atom_shells:
            nucleus_index.append(atom_index)
            shell_ang_mom.append(shell.l)
            shell_factor.append(1.0)
            r_power.append(0)
            primitive_norms = [
                _spherical_primitive_norm(shell.l, value) for value in shell.exponents
            ]
            normalized_coefficients = np.asarray(shell.coefficients) * primitive_norms
            overlap = np.asarray(
                [
                    [_spherical_overlap(shell.l, left, right) for right in shell.exponents]
                    for left in shell.exponents
                ]
            )
            contraction_norm = 1.0 / math.sqrt(
                float(normalized_coefficients @ overlap @ normalized_coefficients)
            )
            solid_harmonic_factor = contraction_norm * math.sqrt(
                (2 * shell.l + 1) / (4 * math.pi)
            )
            for exp_value, coeff_value, primitive_norm in zip(
                shell.exponents, shell.coefficients, primitive_norms, strict=True
            ):
                shell_index.append(shell_number)
                exponent.append(exp_value)
                coefficient.append(coeff_value)
                prim_factor.append(primitive_norm)
            ao_shell.extend([shell_number] * (2 * shell.l + 1))
            ao_normalization.extend([solid_harmonic_factor] * (2 * shell.l + 1))
            shell_number += 1

    return {
        "nucleus_index": np.asarray(nucleus_index, dtype=np.int64),
        "shell_ang_mom": np.asarray(shell_ang_mom, dtype=np.int64),
        "shell_factor": np.asarray(shell_factor, dtype=np.float64),
        "r_power": np.asarray(r_power, dtype=np.int64),
        "shell_index": np.asarray(shell_index, dtype=np.int64),
        "exponent": np.asarray(exponent, dtype=np.float64),
        "coefficient": np.asarray(coefficient, dtype=np.float64),
        "prim_factor": np.asarray(prim_factor, dtype=np.float64),
        "ao_shell": np.asarray(ao_shell, dtype=np.int64),
        "ao_normalization": np.asarray(ao_normalization, dtype=np.float64),
    }


def _electron_counts(orbitals: PeriodicOrbitals) -> tuple[int, int]:
    per_spin = np.einsum("k,ksm->s", orbitals.weights, orbitals.occupations)
    if orbitals.nspin == 1:
        total = float(per_spin[0])
        up = total / 2.0
        down = total / 2.0
    elif orbitals.nspin == 2:
        up, down = map(float, per_spin)
    else:
        raise ExportError(f"unsupported number of spin channels: {orbitals.nspin}")
    if not math.isclose(up, round(up), abs_tol=1e-7) or not math.isclose(down, round(down), abs_tol=1e-7):
        raise ExportError(f"weighted occupations give non-integral electron counts ({up}, {down})")
    return int(round(up)), int(round(down))


def write_trexio(orbitals: PeriodicOrbitals, output: Path, *, text_backend: bool = False) -> None:
    try:
        import trexio
    except ImportError as exc:
        raise ExportError(
            "TREXIO Python support is not installed; rerun install.sh or "
            "python -m pip install -r requirements-qt.txt"
        ) from exc

    orbitals.validate()
    if output.exists():
        raise ExportError(f"refusing to overwrite existing TREXIO output {output}")
    output.parent.mkdir(parents=True, exist_ok=True)
    backend = trexio.TREXIO_TEXT if text_backend else trexio.TREXIO_HDF5
    basis = _basis_arrays(orbitals)
    up, down = _electron_counts(orbitals)

    handle = trexio.File(str(output), mode="w", back_end=backend)
    try:
        trexio.write_metadata_code_num(handle, 2)
        trexio.write_metadata_code(handle, ["lamaGOET", orbitals.source])
        trexio.write_metadata_description(handle, orbitals.description)

        trexio.write_nucleus_num(handle, len(orbitals.atoms))
        trexio.write_nucleus_label(handle, [atom.element for atom in orbitals.atoms])
        trexio.write_nucleus_charge(handle, [float(atom.z_nuc) for atom in orbitals.atoms])
        trexio.write_nucleus_coord(handle, np.asarray([atom.position_bohr for atom in orbitals.atoms]))

        trexio.write_cell_a(handle, orbitals.cell_bohr[0])
        trexio.write_cell_b(handle, orbitals.cell_bohr[1])
        trexio.write_cell_c(handle, orbitals.cell_bohr[2])
        trexio.write_pbc_periodic(handle, 1)
        trexio.write_pbc_k_point_num(handle, orbitals.nk)
        trexio.write_pbc_k_point(handle, orbitals.kpoints)
        trexio.write_pbc_k_point_weight(handle, orbitals.weights)

        trexio.write_electron_up_num(handle, up)
        trexio.write_electron_dn_num(handle, down)

        trexio.write_basis_type(handle, "Gaussian")
        trexio.write_basis_shell_num(handle, len(basis["nucleus_index"]))
        trexio.write_basis_prim_num(handle, len(basis["exponent"]))
        trexio.write_basis_nucleus_index(handle, basis["nucleus_index"])
        trexio.write_basis_shell_ang_mom(handle, basis["shell_ang_mom"])
        trexio.write_basis_shell_factor(handle, basis["shell_factor"])
        trexio.write_basis_r_power(handle, basis["r_power"])
        trexio.write_basis_shell_index(handle, basis["shell_index"])
        trexio.write_basis_exponent(handle, basis["exponent"])
        trexio.write_basis_coefficient(handle, basis["coefficient"])
        trexio.write_basis_prim_factor(handle, basis["prim_factor"])

        trexio.write_ao_cartesian(handle, 0)
        trexio.write_ao_num(handle, orbitals.nao)
        trexio.write_ao_shell(handle, basis["ao_shell"])
        trexio.write_ao_normalization(handle, basis["ao_normalization"])

        # TREXIO stores one AO row per MO, ordered here by spin, k point and
        # band.  A single transpose/reshape avoids building two large Python
        # lists of per-orbital real and imaginary copies for dense k meshes.
        coefficient_rows = orbitals.coefficients.transpose(1, 0, 3, 2).reshape(
            orbitals.nspin * orbitals.nk * orbitals.nmo, orbitals.nao
        )
        energies = orbitals.eigenvalues.transpose(1, 0, 2).reshape(-1)
        occupations = orbitals.occupations.transpose(1, 0, 2).reshape(-1)
        spins = np.repeat(np.arange(orbitals.nspin), orbitals.nk * orbitals.nmo)
        mo_kpoints = np.tile(
            np.repeat(np.arange(orbitals.nk), orbitals.nmo), orbitals.nspin
        )
        mo_num = int(energies.size)
        trexio.write_mo_type(handle, "Canonical periodic Bloch orbitals")
        trexio.write_mo_num(handle, mo_num)
        trexio.write_mo_coefficient(handle, coefficient_rows.real)
        trexio.write_mo_coefficient_im(handle, coefficient_rows.imag)
        trexio.write_mo_energy(handle, energies)
        trexio.write_mo_occupation(handle, occupations)
        trexio.write_mo_spin(handle, spins)
        trexio.write_mo_k_point(handle, mo_kpoints)
    finally:
        handle.close()


def validate_trexio(path: Path, expected: PeriodicOrbitals | None = None) -> dict[str, object]:
    try:
        import trexio
    except ImportError as exc:
        raise ExportError("TREXIO Python support is not installed") from exc
    handle = trexio.File(str(path), mode="r", back_end=trexio.TREXIO_AUTO)
    try:
        summary = {
            "nucleus_num": int(trexio.read_nucleus_num(handle)),
            "ao_num": int(trexio.read_ao_num(handle)),
            "k_point_num": int(trexio.read_pbc_k_point_num(handle)),
            "mo_num": int(trexio.read_mo_num(handle)),
            "electron_up": int(trexio.read_electron_up_num(handle)),
            "electron_down": int(trexio.read_electron_dn_num(handle)),
        }
        coefficients = np.asarray(trexio.read_mo_coefficient(handle))
        coefficients_im = np.asarray(trexio.read_mo_coefficient_im(handle))
        if coefficients.shape != coefficients_im.shape:
            raise ExportError("TREXIO real and imaginary MO arrays have different shapes")
        if not np.all(np.isfinite(coefficients)) or not np.all(np.isfinite(coefficients_im)):
            raise ExportError("TREXIO MO arrays contain non-finite values")
        if expected is not None:
            wanted = {
                "nucleus_num": len(expected.atoms),
                "ao_num": expected.nao,
                "k_point_num": expected.nk,
                "mo_num": expected.nk * expected.nspin * expected.nmo,
            }
            for key, value in wanted.items():
                if summary[key] != value:
                    raise ExportError(f"TREXIO {key} is {summary[key]}, expected {value}")
        return summary
    finally:
        handle.close()


def _write_manifest(output: Path, orbitals: PeriodicOrbitals, validation: dict[str, object]) -> Path:
    manifest = output.with_name(output.name + ".json")
    content = {
        "format": "TREXIO periodic wavefunction",
        "exporter_version": EXPORT_VERSION,
        "source": orbitals.source,
        "description": orbitals.description,
        "trexio_file": output.name,
        "validation": validation,
        "complete_virtual_space": orbitals.nmo == orbitals.nao,
        "molecular_wfn_wfx_47_written": False,
        "molecular_format_note": (
            "WFN, WFX and NBO .47 are finite molecular formats and cannot exactly encode "
            "this cell, k-point weights and complex Bloch coefficients."
        ),
    }
    manifest.write_text(json.dumps(content, indent=2) + "\n", encoding="utf-8")
    return manifest


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--text", action="store_true", help="write the TREXIO text backend")
    subparsers = parser.add_subparsers(dest="command", required=True)
    cp2k = subparsers.add_parser("cp2k", help="export a CP2K MO_KP .mokp file")
    cp2k.add_argument("--mokp", required=True, type=Path)
    cp2k.add_argument("--output", required=True, type=Path)
    crystal = subparsers.add_parser(
        "crystal23", help="reconstruct orbitals from Crystal23 CRYAPI data"
    )
    crystal.add_argument("--xml", required=True, type=Path)
    basis_source = crystal.add_mutually_exclusive_group(required=True)
    basis_source.add_argument(
        "--gred",
        type=Path,
        help="matching formatted GRED file carrying the exact atom-resolved basis",
    )
    basis_source.add_argument(
        "--basis-file",
        type=Path,
        help="legacy exact-matching Tonto basis-library file",
    )
    crystal.add_argument(
        "--overlap-cutoff",
        type=float,
        help="rank threshold used by an explicitly LDREMO-conditioned Crystal23 SCF",
    )
    crystal.add_argument("--output", required=True, type=Path)
    validate = subparsers.add_parser("validate", help="validate an existing TREXIO file")
    validate.add_argument("path", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    arguments = _parser().parse_args(argv)
    try:
        if arguments.command == "validate":
            print(json.dumps(validate_trexio(arguments.path), indent=2))
            return 0
        if arguments.command == "cp2k":
            orbitals = read_cp2k_orbitals(arguments.mokp)
        else:
            basis_path = arguments.basis_file
            if basis_path is not None and not basis_path.is_file():
                basis_path = resolve_basis_file(basis_path.parent, basis_path.name)
            orbitals = read_crystal23_orbitals(
                arguments.xml,
                basis_path,
                gred_path=arguments.gred,
                overlap_cutoff=arguments.overlap_cutoff,
            )
        write_trexio(orbitals, arguments.output, text_backend=arguments.text)
        validation = validate_trexio(arguments.output, orbitals)
        manifest = _write_manifest(arguments.output, orbitals, validation)
        print(f"Wrote {arguments.output}")
        print(f"Validated {validation['mo_num']} periodic MOs on {validation['k_point_num']} k points")
        print(f"Wrote {manifest}")
        if orbitals.nmo < orbitals.nao:
            if orbitals.source == "CP2K":
                warning = (
                    "the CP2K virtual space is truncated; use CP2K ADDED_MOS=-1 "
                    "for all available virtual orbitals"
                )
            else:
                warning = (
                    "the Crystal23 TREXIO contains the common LDREMO-retained "
                    "orbital subspace; discarded linearly dependent directions "
                    "were not represented as invented virtual orbitals"
                )
            print(f"WARNING: {warning}.", file=sys.stderr)
        return 0
    except (BridgeError, ExportError, OSError, ET.ParseError, ValueError) as exc:
        print(f"periodic_wavefunction_export: error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
