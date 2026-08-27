#!/usr/bin/env python3
"""Export periodic CP2K/Crystal23 orbitals to a validated TREXIO file.

Standard molecular WFN, WFX and NBO ``.47`` files have no cell, k-point or
Bloch-orbital fields.  This module therefore keeps the periodic wavefunction in
TREXIO.  CP2K orbitals are read from lamaGOET's existing ``MO_KP`` dump.
Crystal23 orbitals are reconstructed by solving

    F(k) C(k) = S(k) C(k) epsilon(k)

from the direct-lattice overlap and Fock/Kohn--Sham matrices in its XML file.
The Gaussian exponents/contractions for Crystal23 are taken from the exact
Tonto basis-library file selected by lamaGOET; the XML contains AO labels but
does not contain those radial basis data.
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


EXPORT_VERSION = "1.0.0"


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
        # CRYSTAL packs the upper triangle of M(R) in the R record and the
        # lower triangle in the -R record.  This is the same pairing used by
        # Tonto's historical unzip_triangles implementation.
        lower = _unzip_lower(raw[opposite], n)
        upper_source = _unzip_lower(values, n)
        blocks[lattice] = lower + np.tril(upper_source, -1).T
    return blocks


def _fourier_matrix(
    blocks: dict[tuple[int, int, int], np.ndarray], kpoint: np.ndarray
) -> np.ndarray:
    matrix = np.zeros_like(next(iter(blocks.values())), dtype=np.complex128)
    for lattice, block in blocks.items():
        matrix += np.exp(2j * np.pi * np.dot(kpoint, lattice)) * block
    return 0.5 * (matrix + matrix.conj().T)


def _generalized_eigh(fock: np.ndarray, overlap: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    try:
        chol = np.linalg.cholesky(overlap)
    except np.linalg.LinAlgError as exc:
        smallest = float(np.linalg.eigvalsh(overlap).min())
        raise ExportError(
            f"Crystal23 overlap matrix is not positive definite (minimum eigenvalue {smallest:.3e})"
        ) from exc
    left = np.linalg.solve(chol, fock)
    transformed = np.linalg.solve(chol.conj(), left.T).T
    transformed = 0.5 * (transformed + transformed.conj().T)
    energies, vectors_orthogonal = np.linalg.eigh(transformed)
    coefficients = np.linalg.solve(chol.conj().T, vectors_orthogonal)
    error = float(
        np.max(np.abs(coefficients.conj().T @ overlap @ coefficients - np.eye(overlap.shape[0])))
    )
    if error > 1.0e-8:
        raise ExportError(f"reconstructed Crystal23 MOs are not S-orthonormal (error {error:.3e})")
    return energies, coefficients


def read_crystal23_orbitals(xml_path: Path, basis_path: Path) -> PeriodicOrbitals:
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
    atoms: list[AtomRecord] = []
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
        atoms.append(AtomRecord(index, symbol, z, z, position, first_ao, first_ao + atom_nao - 1))
        first_ao += atom_nao

    basis_by_element = read_tonto_basis(basis_path, {atom.element for atom in atoms})
    shells_by_atom = [basis_by_element[atom.element] for atom in atoms]
    expanded_by_atom = [sum(2 * shell.l + 1 for shell in shells) for shells in shells_by_atom]
    if expanded_by_atom != atom_shell_counts:
        raise ExportError(
            "selected Tonto basis does not match the Crystal23 XML AO layout: "
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
    eigenvalues = np.zeros((nk, 1, nao), dtype=np.float64)
    occupations = np.zeros((nk, 1, nao), dtype=np.float64)
    coefficients = np.zeros((nk, 1, nao, nao), dtype=np.complex128)
    permutation = _crystal_to_trexio_permutation(shells_by_atom)
    noccupied = nelectron // 2
    for ik, kpoint in enumerate(kpoint_array):
        overlap = _fourier_matrix(overlap_blocks, kpoint)
        fock = _fourier_matrix(fock_blocks, kpoint)
        energies, crystal_coefficients = _generalized_eigh(fock, overlap)
        eigenvalues[ik, 0, :] = energies
        occupations[ik, 0, :noccupied] = 2.0
        coefficients[ik, 0, :, :] = crystal_coefficients[permutation, :]

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
            f"using direct-lattice S and F/Kohn-Sham matrices and basis {basis_path.name}."
        ),
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
    crystal = subparsers.add_parser("crystal23", help="reconstruct orbitals from Crystal23 XML")
    crystal.add_argument("--xml", required=True, type=Path)
    crystal.add_argument("--basis-file", required=True, type=Path)
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
            if not basis_path.is_file():
                basis_path = resolve_basis_file(basis_path.parent, basis_path.name)
            orbitals = read_crystal23_orbitals(arguments.xml, basis_path)
        write_trexio(orbitals, arguments.output, text_backend=arguments.text)
        validation = validate_trexio(arguments.output, orbitals)
        manifest = _write_manifest(arguments.output, orbitals, validation)
        print(f"Wrote {arguments.output}")
        print(f"Validated {validation['mo_num']} periodic MOs on {validation['k_point_num']} k points")
        print(f"Wrote {manifest}")
        if orbitals.nmo < orbitals.nao:
            print(
                "WARNING: the CP2K virtual space is truncated; use CP2K ADDED_MOS=-1 "
                "for all available virtual orbitals.",
                file=sys.stderr,
            )
        return 0
    except (BridgeError, ExportError, OSError, ET.ParseError, ValueError) as exc:
        print(f"periodic_wavefunction_export: error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
