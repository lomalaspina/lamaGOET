#!/usr/bin/env python3
"""Bridge CP2K periodic density data into Tonto's periodic-density interface.

The bridge combines two CP2K outputs:

* ``*-RESTART.kp``: CP2K's unformatted k-point restart.  This contains the
  real-space AO density matrices indexed by direct-lattice translations.
* ``*.mokp``: the text output produced by CP2K 2026.2+ ``&MO_KP`` with
  ``AO_EXPORT_TYPE GTO_BASIS``.  This provides the cell, atoms, effective
  nuclear charges and Gaussian basis definition in a portable format.

It writes:

* a Crystal23-compatible periodic-density XML file understood by the current
  Tonto ``process_CIF_AND_C23_XML`` implementation; and
* a Tonto basis-library file generated from the exact CP2K orbital basis.

CP2K and Molden/Tonto use different spherical-harmonic AO orderings.  The
permutation implemented here is the one used by CP2K's own Molden writer.
"""

from __future__ import annotations

import argparse
import dataclasses
import json
import math
import os
from pathlib import Path
import re
import struct
import sys
from typing import BinaryIO, Iterable, Iterator, Sequence

import numpy as np

BOHR_PER_ANGSTROM = 1.8897261254578281

# For each angular momentum l, this gives CP2K's 1-based internal AO indices
# in Molden output order.  Taken from CP2K src/molden_utils.F.
_CP2K_TO_MOLDEN_1BASED: dict[int, tuple[int, ...]] = {
    0: (1,),
    1: (3, 1, 2),
    2: (3, 4, 2, 5, 1),
    3: (4, 5, 3, 6, 2, 7, 1),
    4: (5, 6, 4, 7, 3, 8, 2, 9, 1),
    5: (6, 7, 5, 8, 4, 9, 3, 10, 2, 11, 1),
}

_ANGMOM_TO_L = {c: i for i, c in enumerate("spdfgh")}
_L_TO_ANGMOM = {v: k.upper() for k, v in _ANGMOM_TO_L.items()}


class BridgeError(RuntimeError):
    """Raised when CP2K/Tonto bridge input is inconsistent or unsupported."""


@dataclasses.dataclass(frozen=True)
class FortranFormat:
    marker_bytes: int
    endian: str  # '<' or '>'

    @property
    def marker_struct(self) -> struct.Struct:
        code = "i" if self.marker_bytes == 4 else "q"
        return struct.Struct(self.endian + code)

    @property
    def int_dtype(self) -> np.dtype:
        return np.dtype(self.endian + "i4")

    @property
    def float_dtype(self) -> np.dtype:
        return np.dtype(self.endian + "f8")


class FortranSequentialReader:
    """Reader for compiler-style sequential unformatted Fortran records."""

    def __init__(self, file: BinaryIO, fmt: FortranFormat):
        self.file = file
        self.fmt = fmt
        self.record_index = 0

    @classmethod
    def open(cls, path: Path) -> "FortranSequentialReader":
        file = path.open("rb")
        try:
            fmt = detect_fortran_format(file)
            file.seek(0)
            return cls(file, fmt)
        except Exception:
            file.close()
            raise

    def close(self) -> None:
        self.file.close()

    def __enter__(self) -> "FortranSequentialReader":
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()

    def read_record(self, *, allow_eof: bool = False) -> bytes | None:
        marker = self.file.read(self.fmt.marker_bytes)
        if marker == b"":
            if allow_eof:
                return None
            raise EOFError("unexpected end of file before a Fortran record")
        if len(marker) != self.fmt.marker_bytes:
            raise BridgeError("truncated leading Fortran record marker")

        (size,) = self.fmt.marker_struct.unpack(marker)
        if size < 0:
            raise BridgeError(
                "negative Fortran record length; chained/subrecord files are not supported"
            )
        payload = self.file.read(size)
        if len(payload) != size:
            raise BridgeError(
                f"truncated Fortran record {self.record_index}: expected {size} payload bytes"
            )
        tail = self.file.read(self.fmt.marker_bytes)
        if len(tail) != self.fmt.marker_bytes:
            raise BridgeError("truncated trailing Fortran record marker")
        (tail_size,) = self.fmt.marker_struct.unpack(tail)
        if tail_size != size:
            raise BridgeError(
                f"record marker mismatch at record {self.record_index}: {size} != {tail_size}"
            )
        self.record_index += 1
        return payload

    def read_ints(self, expected: int | None = None, *, allow_eof: bool = False) -> np.ndarray | None:
        record = self.read_record(allow_eof=allow_eof)
        if record is None:
            return None
        if len(record) % 4:
            raise BridgeError(f"integer record has {len(record)} bytes, not divisible by 4")
        values = np.frombuffer(record, dtype=self.fmt.int_dtype).astype(np.int64)
        if expected is not None and values.size != expected:
            raise BridgeError(
                f"expected {expected} integers in record, found {values.size}"
            )
        return values

    def read_doubles(self, expected: int | None = None) -> np.ndarray:
        record = self.read_record()
        assert record is not None
        if len(record) % 8:
            raise BridgeError(f"real record has {len(record)} bytes, not divisible by 8")
        values = np.frombuffer(record, dtype=self.fmt.float_dtype).astype(np.float64)
        if expected is not None and values.size != expected:
            raise BridgeError(
                f"expected {expected} real values in record, found {values.size}"
            )
        return values


def detect_fortran_format(file: BinaryIO) -> FortranFormat:
    """Detect 4/8-byte record markers and endian from CP2K's version record."""

    start = file.tell()
    probe = file.read(32)
    file.seek(start)
    candidates: list[FortranFormat] = []
    for marker_bytes in (4, 8):
        for endian in ("<", ">"):
            fmt = FortranFormat(marker_bytes, endian)
            if len(probe) < marker_bytes * 2 + 4:
                continue
            try:
                (n1,) = fmt.marker_struct.unpack(probe[:marker_bytes])
                payload_start = marker_bytes
                payload_end = payload_start + n1
                if n1 != 4 or payload_end + marker_bytes > len(probe):
                    continue
                (version,) = struct.unpack(endian + "i", probe[payload_start:payload_end])
                (n2,) = fmt.marker_struct.unpack(
                    probe[payload_end : payload_end + marker_bytes]
                )
                if n1 == n2 and version == 1:
                    candidates.append(fmt)
            except struct.error:
                continue
    if len(candidates) != 1:
        rendered = ", ".join(
            f"{c.marker_bytes}-byte/{'little' if c.endian == '<' else 'big'}" for c in candidates
        )
        raise BridgeError(
            "could not uniquely identify CP2K Fortran record format"
            + (f"; candidates: {rendered}" if rendered else "")
        )
    return candidates[0]


@dataclasses.dataclass
class KPHeader:
    version: int
    natom: int
    nao: int
    nset_max: int
    nshell_max: int
    nset_info: np.ndarray
    nshell_info: np.ndarray
    nso_info: np.ndarray

    def shell_l_by_atom(self) -> list[list[int]]:
        result: list[list[int]] = []
        for iatom in range(self.natom):
            shells: list[int] = []
            for iset in range(int(self.nset_info[iatom])):
                for ishell in range(int(self.nshell_info[iset, iatom])):
                    nso = int(self.nso_info[ishell, iset, iatom])
                    if nso <= 0 or nso % 2 == 0:
                        raise BridgeError(
                            f"invalid spherical shell size {nso} for atom {iatom + 1}"
                        )
                    l = (nso - 1) // 2
                    if 2 * l + 1 != nso:
                        raise BridgeError(f"cannot infer l from shell size {nso}")
                    shells.append(l)
            result.append(shells)
        return result

    def cp2k_to_molden_permutation(self) -> np.ndarray:
        perm: list[int] = []
        offset = 0
        for atom_shells in self.shell_l_by_atom():
            for l in atom_shells:
                try:
                    local = _CP2K_TO_MOLDEN_1BASED[l]
                except KeyError as exc:
                    raise BridgeError(
                        f"angular momentum l={l} is not supported; supported range is s through h"
                    ) from exc
                perm.extend(offset + i - 1 for i in local)
                offset += 2 * l + 1
        if offset != self.nao or len(perm) != self.nao:
            raise BridgeError(
                f"basis header expands to {offset} AOs but file declares {self.nao}"
            )
        return np.asarray(perm, dtype=np.int64)


@dataclasses.dataclass
class KPData:
    header: KPHeader
    nspin: int
    cells: list[tuple[int, int, int]]
    density_by_spin: list[list[np.ndarray]]
    fortran_format: FortranFormat

    def total_density(self) -> list[np.ndarray]:
        total: list[np.ndarray] = []
        for image_index in range(len(self.cells)):
            matrix = np.zeros((self.header.nao, self.header.nao), dtype=np.float64)
            for spin in self.density_by_spin:
                matrix += spin[image_index]
            total.append(matrix)
        return total

    def total_density_molden_order(self) -> list[np.ndarray]:
        perm = self.header.cp2k_to_molden_permutation()
        return [matrix[np.ix_(perm, perm)] for matrix in self.total_density()]


def read_kp(path: Path) -> KPData:
    with FortranSequentialReader.open(path) as reader:
        version_values = reader.read_ints(expected=1)
        assert version_values is not None
        version = int(version_values[0])
        if version != 1:
            raise BridgeError(f"unsupported CP2K .kp version {version}; expected version 1")

        dims = reader.read_ints(expected=4)
        assert dims is not None
        natom, nao, nset_max, nshell_max = map(int, dims)
        if min(natom, nao, nset_max, nshell_max) <= 0:
            raise BridgeError(f"invalid .kp dimensions: {tuple(map(int, dims))}")

        nset_info_raw = reader.read_ints(expected=natom)
        nshell_info_raw = reader.read_ints(expected=nset_max * natom)
        nso_info_raw = reader.read_ints(expected=nshell_max * nset_max * natom)
        assert nset_info_raw is not None
        assert nshell_info_raw is not None
        assert nso_info_raw is not None
        nset_info = nset_info_raw.astype(np.int64)
        nshell_info = nshell_info_raw.reshape((nset_max, natom), order="F")
        nso_info = nso_info_raw.reshape((nshell_max, nset_max, natom), order="F")
        header = KPHeader(
            version=version,
            natom=natom,
            nao=nao,
            nset_max=nset_max,
            nshell_max=nshell_max,
            nset_info=nset_info,
            nshell_info=nshell_info,
            nso_info=nso_info,
        )
        # Validate the AO expansion before allocating matrices.
        header.cp2k_to_molden_permutation()

        density_by_spin: list[list[np.ndarray]] = []
        common_cells: list[tuple[int, int, int]] | None = None
        expected_nspin: int | None = None
        expected_nimages: int | None = None

        while True:
            spin_header = reader.read_ints(expected=3, allow_eof=True)
            if spin_header is None:
                break
            ispin, nspin, nimages = map(int, spin_header)
            if expected_nspin is None:
                expected_nspin = nspin
                expected_nimages = nimages
                if nspin not in (1, 2):
                    raise BridgeError(f"unsupported number of spin channels: {nspin}")
                if nimages <= 0:
                    raise BridgeError(f"invalid number of density images: {nimages}")
            elif nspin != expected_nspin or nimages != expected_nimages:
                raise BridgeError("spin blocks disagree on nspin or nimages")
            if ispin != len(density_by_spin) + 1:
                raise BridgeError(
                    f"unexpected spin block index {ispin}; expected {len(density_by_spin) + 1}"
                )

            spin_cells: list[tuple[int, int, int]] = []
            matrices: list[np.ndarray] = []
            for expected_ic in range(1, nimages + 1):
                image_header = reader.read_ints(expected=4)
                assert image_header is not None
                ic = int(image_header[0])
                cell = tuple(int(x) for x in image_header[1:4])
                if ic != expected_ic:
                    raise BridgeError(
                        f"unexpected image index {ic} in spin {ispin}; expected {expected_ic}"
                    )
                matrix = np.empty((nao, nao), dtype=np.float64)
                # cp_fm_write_unformatted writes one full matrix column per record.
                for j in range(nao):
                    matrix[:, j] = reader.read_doubles(expected=nao)
                spin_cells.append(cell)
                matrices.append(matrix)

            if common_cells is None:
                common_cells = spin_cells
            elif spin_cells != common_cells:
                raise BridgeError("alpha and beta density blocks use different lattice images")
            density_by_spin.append(matrices)

        if expected_nspin is None or common_cells is None:
            raise BridgeError(".kp file contains no spin/image density blocks")
        if len(density_by_spin) != expected_nspin:
            raise BridgeError(
                f".kp file declares {expected_nspin} spin blocks but contains {len(density_by_spin)}"
            )
        if (0, 0, 0) not in common_cells:
            raise BridgeError(".kp file does not contain the reference-cell density block")

        return KPData(
            header=header,
            nspin=expected_nspin,
            cells=common_cells,
            density_by_spin=density_by_spin,
            fortran_format=reader.fmt,
        )


@dataclasses.dataclass(frozen=True)
class AtomRecord:
    atom_id: int
    element: str
    z_nuc: int
    z_eff: int
    position_bohr: tuple[float, float, float]
    first_ao: int
    last_ao: int


@dataclasses.dataclass(frozen=True)
class ShellRecord:
    l: int
    exponents: tuple[float, ...]
    coefficients: tuple[float, ...]

    def normalized_signature(self, digits: int = 12) -> tuple:
        return (
            self.l,
            tuple(round(x, digits) for x in self.exponents),
            tuple(round(x, digits) for x in self.coefficients),
        )


@dataclasses.dataclass
class MOKPMetadata:
    version: str
    natom: int
    nspins: int
    nao: int
    nkp: int
    cell_bohr: np.ndarray
    atoms: list[AtomRecord]
    shells_by_atom: list[list[ShellRecord]]

    def validate(self) -> None:
        if self.cell_bohr.shape != (3, 3):
            raise BridgeError("MOKP cell must be 3x3")
        if len(self.atoms) != self.natom:
            raise BridgeError(
                f"MOKP declares {self.natom} atoms but contains {len(self.atoms)} atom rows"
            )
        if len(self.shells_by_atom) != self.natom:
            raise BridgeError(
                f"MOKP contains basis blocks for {len(self.shells_by_atom)} atoms, expected {self.natom}"
            )
        ao_count = 0
        for atom, shells in zip(self.atoms, self.shells_by_atom, strict=True):
            shell_ao_count = sum(2 * shell.l + 1 for shell in shells)
            if shell_ao_count != atom.last_ao - atom.first_ao + 1:
                raise BridgeError(
                    f"atom {atom.atom_id} basis has {shell_ao_count} AOs but atom table range "
                    f"contains {atom.last_ao - atom.first_ao + 1}"
                )
            ao_count += shell_ao_count
        if ao_count != self.nao:
            raise BridgeError(f"MOKP basis expands to {ao_count} AOs but declares {self.nao}")


_DIMENSIONS_RE = re.compile(
    r"#\s*DIMENSIONS:\s*natom\s+nspins\s+nao\s+nkp\s*=\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)",
    re.IGNORECASE,
)
_VERSION_RE = re.compile(r"CP2K_KPOINT_MO_DUMP,\s*Version\s+([^\s]+)", re.IGNORECASE)


def _next_data_line(lines: Sequence[str], index: int) -> tuple[int, str]:
    while index < len(lines):
        value = lines[index].strip()
        if value and not value.startswith("#"):
            return index, value
        index += 1
    raise BridgeError("unexpected end of MOKP file")


def read_mokp(path: Path) -> MOKPMetadata:
    lines = path.read_text(encoding="utf-8").splitlines()
    version = "unknown"
    natom = nspins = nao = nkp = 0
    for line in lines[:40]:
        if match := _VERSION_RE.search(line):
            version = match.group(1)
        if match := _DIMENSIONS_RE.search(line):
            natom, nspins, nao, nkp = map(int, match.groups())
    if not all((natom, nspins, nao, nkp)):
        raise BridgeError("MOKP dimensions header was not found or contains zeros")

    cell_index = next(
        (i for i, line in enumerate(lines) if line.strip().upper().startswith("# CELL_VECTORS")),
        None,
    )
    if cell_index is None:
        raise BridgeError("MOKP CELL_VECTORS section not found")
    unit_line = lines[cell_index].upper()
    factor = BOHR_PER_ANGSTROM if "ANGSTROM" in unit_line else 1.0
    cell_rows: list[list[float]] = []
    cursor = cell_index + 1
    for _ in range(3):
        cursor, line = _next_data_line(lines, cursor)
        fields = line.split()
        if len(fields) < 3:
            raise BridgeError("invalid MOKP cell-vector row")
        cell_rows.append([float(fields[0]) * factor, float(fields[1]) * factor, float(fields[2]) * factor])
        cursor += 1
    # CP2K writes a, b, c as rows. Tonto XML likewise consumes three vectors.
    cell_bohr = np.asarray(cell_rows, dtype=np.float64)

    atom_index = next(
        (i for i, line in enumerate(lines) if line.strip().upper().startswith("# ATOM_LIST:")),
        None,
    )
    if atom_index is None:
        raise BridgeError("MOKP ATOM_LIST section not found")
    atom_units_ang = "[ANG" in lines[atom_index].upper()
    atom_factor = BOHR_PER_ANGSTROM if atom_units_ang else 1.0
    atoms: list[AtomRecord] = []
    cursor = atom_index + 1
    while cursor < len(lines) and len(atoms) < natom:
        line = lines[cursor].strip()
        cursor += 1
        if not line or line.startswith("#"):
            continue
        fields = line.split()
        if len(fields) < 9:
            raise BridgeError(f"invalid MOKP atom row: {line}")
        atoms.append(
            AtomRecord(
                atom_id=int(fields[0]),
                element=fields[1].capitalize(),
                z_nuc=int(fields[2]),
                z_eff=int(fields[3]),
                position_bohr=tuple(float(x) * atom_factor for x in fields[4:7]),
                first_ao=int(fields[7]),
                last_ao=int(fields[8]),
            )
        )

    gto_index = next(
        (i for i, line in enumerate(lines) if line.strip().upper().startswith("# GTO_BASIS")),
        None,
    )
    if gto_index is None:
        raise BridgeError(
            "MOKP GTO_BASIS section not found; run CP2K MO_KP with AO_EXPORT_TYPE GTO_BASIS"
        )

    shells_by_atom: list[list[ShellRecord]] = [[] for _ in range(natom)]
    cursor = gto_index + 1
    current_atom: int | None = None
    while cursor < len(lines):
        raw = lines[cursor]
        line = raw.strip()
        if line.upper().startswith("# BEGIN_KPOINT_SPIN"):
            break
        cursor += 1
        if not line or line.startswith("#"):
            continue
        fields = line.split()
        if len(fields) == 2 and all(re.fullmatch(r"[+-]?\d+", value) for value in fields):
            atom_id = int(fields[0])
            if not 1 <= atom_id <= natom:
                raise BridgeError(f"basis block references invalid atom {atom_id}")
            current_atom = atom_id - 1
            continue
        if current_atom is None:
            raise BridgeError(f"shell line before atom basis header: {line}")
        shell_letter = fields[0].lower()
        if shell_letter not in _ANGMOM_TO_L or len(fields) < 2:
            raise BridgeError(f"unsupported or malformed MOKP shell line: {line}")
        nprim = int(fields[1])
        if nprim <= 0:
            raise BridgeError(f"invalid primitive count in shell line: {line}")
        exponents: list[float] = []
        coefficients: list[float] = []
        for _ in range(nprim):
            cursor, primitive_line = _next_data_line(lines, cursor)
            primitive_fields = primitive_line.split()
            if len(primitive_fields) < 2:
                raise BridgeError(f"invalid primitive row: {primitive_line}")
            exponents.append(float(primitive_fields[0].replace("D", "E").replace("d", "e")))
            coefficients.append(float(primitive_fields[1].replace("D", "E").replace("d", "e")))
            cursor += 1
        shells_by_atom[current_atom].append(
            ShellRecord(
                l=_ANGMOM_TO_L[shell_letter],
                exponents=tuple(exponents),
                coefficients=tuple(coefficients),
            )
        )

    metadata = MOKPMetadata(
        version=version,
        natom=natom,
        nspins=nspins,
        nao=nao,
        nkp=nkp,
        cell_bohr=cell_bohr,
        atoms=atoms,
        shells_by_atom=shells_by_atom,
    )
    metadata.validate()
    return metadata


def validate_kp_mokp(kp: KPData, mokp: MOKPMetadata) -> None:
    if kp.header.natom != mokp.natom:
        raise BridgeError(
            f"atom count mismatch: KP={kp.header.natom}, MOKP={mokp.natom}"
        )
    if kp.header.nao != mokp.nao:
        raise BridgeError(f"AO count mismatch: KP={kp.header.nao}, MOKP={mokp.nao}")
    if kp.nspin != mokp.nspins:
        raise BridgeError(f"spin count mismatch: KP={kp.nspin}, MOKP={mokp.nspins}")

    kp_shells = kp.header.shell_l_by_atom()
    mokp_shells = [[shell.l for shell in shells] for shells in mokp.shells_by_atom]
    if kp_shells != mokp_shells:
        differences = [
            i + 1 for i, (left, right) in enumerate(zip(kp_shells, mokp_shells, strict=True)) if left != right
        ]
        raise BridgeError(
            "KP and MOKP shell ordering differs for atoms " + ", ".join(map(str, differences))
        )


def validate_density_translation_pairs(
    cells: Sequence[tuple[int, int, int]],
    matrices: Sequence[np.ndarray],
    *,
    atol: float = 1.0e-9,
    rtol: float = 1.0e-8,
) -> dict[str, float | int]:
    cell_to_index = {cell: i for i, cell in enumerate(cells)}
    max_abs = 0.0
    checked = 0
    missing = 0
    for i, cell in enumerate(cells):
        inverse = tuple(-value for value in cell)
        j = cell_to_index.get(inverse)
        if j is None:
            missing += 1
            continue
        residual = matrices[i] - matrices[j].T
        local = float(np.max(np.abs(residual))) if residual.size else 0.0
        max_abs = max(max_abs, local)
        checked += 1
        if not np.allclose(matrices[i], matrices[j].T, atol=atol, rtol=rtol):
            raise BridgeError(
                f"density blocks for R={cell} and -R={inverse} are not transpose pairs; "
                f"max |residual|={local:.3e}"
            )
    return {"transpose_pairs_checked": checked, "missing_inverse_cells": missing, "max_pair_residual": max_abs}


def write_tonto_basis_library(
    path: Path,
    mokp: MOKPMetadata,
    *,
    basis_name: str,
) -> None:
    """Write one Tonto basis definition per chemical element.

    Tonto's simple global ``basis_name`` selection assumes that atoms of the
    same element use the same basis.  We reject mixed same-element bases rather
    than silently assign the wrong basis.
    """

    by_element: dict[str, list[ShellRecord]] = {}
    signature_by_element: dict[str, tuple] = {}
    for atom, shells in zip(mokp.atoms, mokp.shells_by_atom, strict=True):
        signature = tuple(shell.normalized_signature() for shell in shells)
        previous = signature_by_element.get(atom.element)
        if previous is not None and previous != signature:
            raise BridgeError(
                f"atoms of element {atom.element} use different CP2K bases; "
                "the current generated Tonto library supports one basis per element"
            )
        signature_by_element[atom.element] = signature
        by_element.setdefault(atom.element, shells)

    lines: list[str] = [
        f'! BASIS="{basis_name}"',
        "! Generated by cp2k_tonto_bridge.py from CP2K MO_KP GTO_BASIS output.",
        "! Coefficients use the GAMESS-US/Tonto basis-library convention.",
        "",
        "{",
        "",
        "   keys= { gamess-us= }",
        "",
        "   data= {",
        "",
    ]
    for element in sorted(by_element, key=lambda e: mokp.atoms[[a.element for a in mokp.atoms].index(e)].z_nuc):
        lines.append(f"      {element}:{basis_name} {{")
        for shell in by_element[element]:
            try:
                letter = _L_TO_ANGMOM[shell.l]
            except KeyError as exc:
                raise BridgeError(f"cannot write Tonto shell l={shell.l}") from exc
            lines.append(f"       {letter}   {len(shell.exponents)}")
            for index, (exponent, coefficient) in enumerate(
                zip(shell.exponents, shell.coefficients, strict=True), start=1
            ):
                lines.append(f"        {index:4d} {exponent:22.14E} {coefficient:22.14E}")
        lines.extend(["      }", ""])
    lines.extend(["   }", "", "}", ""])
    path.write_text("\n".join(lines), encoding="utf-8")


def _format_matrix_column_major(matrix: np.ndarray, values_per_line: int = 5) -> Iterator[str]:
    flat = matrix.ravel(order="F")
    for start in range(0, flat.size, values_per_line):
        yield " ".join(f"{value:23.15E}" for value in flat[start : start + values_per_line])


def write_tonto_periodic_xml(
    path: Path,
    mokp: MOKPMetadata,
    cells: Sequence[tuple[int, int, int]],
    density_matrices_molden: Sequence[np.ndarray],
    *,
    invert_lattice_vectors: bool = False,
) -> None:
    if len(cells) != len(density_matrices_molden):
        raise BridgeError("cell and density-matrix counts differ")

    output_cells = [tuple(-x for x in cell) for cell in cells] if invert_lattice_vectors else list(cells)
    lines: list[str] = [
        '<?xml version="1.0"?>',
        "<!-- Generated from CP2K .kp + .mokp by cp2k_tonto_bridge.py -->",
        "<!-- Density matrices have been permuted from CP2K m=-l..+l order to Molden/Tonto order. -->",
        f"<!-- CP2K lattice-vector sign inverted: {str(invert_lattice_vectors).lower()} -->",
        "<CP2K_TONTO_PERIODIC_DENSITY>",
    ]
    for label, vector in zip(("A", "B", "C"), mokp.cell_bohr, strict=True):
        lines.extend(
            [
                f"  <CELL_VECTOR_{label}>",
                "    " + " ".join(f"{value:23.15E}" for value in vector),
                f"  </CELL_VECTOR_{label}>",
            ]
        )

    lines.append(f"  <NUMBER_OF_ATOMS> {mokp.natom} </NUMBER_OF_ATOMS>")
    lines.append("  <CARTESIAN_COORDINATES>")
    for atom in mokp.atoms:
        label = f"{atom.element}{atom.atom_id}"
        lines.append(f"    <ATOM.{atom.atom_id} LABEL {label}>")
        lines.append("      " + " ".join(f"{value:23.15E}" for value in atom.position_bohr))
        lines.append(f"    </ATOM.{atom.atom_id}>")
    lines.append("  </CARTESIAN_COORDINATES>")

    lines.append(f"  <NUMBER_OF_ATOMIC_ORBITALS> {mokp.nao} </NUMBER_OF_ATOMIC_ORBITALS>")
    lines.append(f"  <INTEGER_VECTORS_INFO COUNT {len(output_cells)}>")
    for index, cell in enumerate(output_cells, start=1):
        lines.append(f"    IVDL.{index} {cell[0]:d} {cell[1]:d} {cell[2]:d}")
    lines.append("  </INTEGER_VECTORS_INFO>")

    for index, matrix in enumerate(density_matrices_molden, start=1):
        lines.append(f"  <DIRECT_DENSITY_MATRIX__IVDL.{index}>")
        lines.extend("    " + row for row in _format_matrix_column_major(matrix))
        lines.append(f"  </DIRECT_DENSITY_MATRIX__IVDL.{index}>")
    lines.append("</CP2K_TONTO_PERIODIC_DENSITY>")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


def build_manifest(
    *,
    kp_path: Path,
    mokp_path: Path,
    xml_path: Path,
    basis_path: Path,
    basis_name: str,
    kp: KPData,
    mokp: MOKPMetadata,
    validation: dict[str, float | int],
    invert_lattice_vectors: bool,
    pseudopotential_allowed: bool,
) -> dict:
    return {
        "format": "cp2k-tonto-periodic-bridge",
        "format_version": 1,
        "inputs": {"kp": str(kp_path), "mokp": str(mokp_path)},
        "outputs": {
            "periodic_density_xml": str(xml_path),
            "tonto_basis_library": str(basis_path),
            "basis_name": basis_name,
        },
        "cp2k": {
            "mokp_version": mokp.version,
            "natom": mokp.natom,
            "nao": mokp.nao,
            "nspin": kp.nspin,
            "nimages": len(kp.cells),
            "fortran_record_marker_bytes": kp.fortran_format.marker_bytes,
            "fortran_endian": "little" if kp.fortran_format.endian == "<" else "big",
            "uses_pseudopotentials": any(atom.z_eff != atom.z_nuc for atom in mokp.atoms),
            "pseudopotential_allowed": pseudopotential_allowed,
        },
        "conversion": {
            "ao_order": "CP2K spherical m=-l..+l -> Molden/Tonto",
            "invert_lattice_vectors": invert_lattice_vectors,
        },
        "validation": validation,
    }


def convert(
    *,
    kp_path: Path,
    mokp_path: Path,
    xml_path: Path,
    basis_path: Path,
    basis_name: str,
    manifest_path: Path | None,
    allow_pseudopotential: bool,
    invert_lattice_vectors: bool,
    skip_pair_check: bool,
) -> dict:
    kp = read_kp(kp_path)
    mokp = read_mokp(mokp_path)
    validate_kp_mokp(kp, mokp)

    pseudo_atoms = [atom for atom in mokp.atoms if atom.z_eff != atom.z_nuc]
    if pseudo_atoms and not allow_pseudopotential:
        details = ", ".join(
            f"{atom.element}{atom.atom_id}(Z={atom.z_nuc},Zeff={atom.z_eff})" for atom in pseudo_atoms
        )
        raise BridgeError(
            "CP2K output uses pseudopotentials for "
            + details
            + ". The .kp AO density is then valence-only and is not a complete X-ray electron density. "
            "Use an all-electron GAPW setup (POTENTIAL ALL) or pass --allow-pseudopotential only for "
            "explicit experimental/diagnostic work."
        )

    density = kp.total_density_molden_order()
    validation: dict[str, float | int] = {
        "natom_match": 1,
        "nao_match": 1,
        "shell_order_match": 1,
    }
    if not skip_pair_check:
        validation.update(validate_density_translation_pairs(kp.cells, density))

    xml_path.parent.mkdir(parents=True, exist_ok=True)
    basis_path.parent.mkdir(parents=True, exist_ok=True)
    write_tonto_periodic_xml(
        xml_path,
        mokp,
        kp.cells,
        density,
        invert_lattice_vectors=invert_lattice_vectors,
    )
    write_tonto_basis_library(basis_path, mokp, basis_name=basis_name)

    manifest = build_manifest(
        kp_path=kp_path,
        mokp_path=mokp_path,
        xml_path=xml_path,
        basis_path=basis_path,
        basis_name=basis_name,
        kp=kp,
        mokp=mokp,
        validation=validation,
        invert_lattice_vectors=invert_lattice_vectors,
        pseudopotential_allowed=allow_pseudopotential,
    )
    if manifest_path is not None:
        manifest_path.parent.mkdir(parents=True, exist_ok=True)
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def make_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Convert CP2K periodic .kp density + .mokp basis metadata for Tonto HAR/pHAR."
    )
    parser.add_argument("--kp", type=Path, required=True, help="CP2K *-RESTART.kp file")
    parser.add_argument("--mokp", type=Path, required=True, help="CP2K MO_KP .mokp file")
    parser.add_argument("--xml", type=Path, required=True, help="output Tonto periodic-density XML")
    parser.add_argument("--basis", type=Path, required=True, help="output Tonto basis-library file")
    parser.add_argument(
        "--basis-name",
        default="cp2k-generated",
        help="basis name used inside the generated Tonto basis library",
    )
    parser.add_argument("--manifest", type=Path, help="optional JSON conversion manifest")
    parser.add_argument(
        "--allow-pseudopotential",
        action="store_true",
        help="allow valence-only pseudopotential AO density (not recommended for X-ray refinement)",
    )
    parser.add_argument(
        "--invert-lattice-vectors",
        action="store_true",
        help="write -R instead of R for every density translation (diagnostic convention switch)",
    )
    parser.add_argument(
        "--skip-pair-check",
        action="store_true",
        help="skip P(-R)=P(R)^T consistency validation",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = make_parser()
    args = parser.parse_args(argv)
    try:
        manifest = convert(
            kp_path=args.kp,
            mokp_path=args.mokp,
            xml_path=args.xml,
            basis_path=args.basis,
            basis_name=args.basis_name,
            manifest_path=args.manifest,
            allow_pseudopotential=args.allow_pseudopotential,
            invert_lattice_vectors=args.invert_lattice_vectors,
            skip_pair_check=args.skip_pair_check,
        )
    except (BridgeError, OSError, ValueError) as exc:
        parser.exit(2, f"cp2k_tonto_bridge: error: {exc}\n")
    print(json.dumps(manifest, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
