#!/usr/bin/env python3
"""Bridge CP2K periodic density data into Tonto's periodic-density interface.

The bridge combines two CP2K outputs:

* ``*-RESTART.kp``: CP2K's unformatted k-point restart.  Its image-vector
  list defines the real-space translations needed by the periodic AO basis.
  The packed matrices are used only for the unambiguous R=0 cross-check.
* ``*.mokp``: the text output produced by CP2K 2026.2+ ``&MO_KP`` with
  ``AO_EXPORT_TYPE GTO_BASIS``.  This provides the full-grid k-point MO
  coefficients, occupations, cell, atoms and Gaussian basis.  The bridge
  builds P(k)=C(k)f(k)C(k)^dagger and Fourier transforms it to P(R).

It writes:

* a Crystal23-compatible periodic-density XML file understood by the current
  Tonto ``process_CIF_AND_C23_XML`` implementation; and
* a Tonto basis-library file generated from the exact CP2K orbital basis.

CP2K and Molden/Tonto use different spherical-harmonic AO orderings.  The
permutation implemented here is the one used by CP2K's own Molden writer.
"""

from __future__ import annotations

import argparse
from collections import Counter
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

BRIDGE_VERSION = "4.4.0"
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
    nmo: int
    use_real_wfn: bool
    kpoints: np.ndarray
    weights: np.ndarray
    density_by_kpoint: list[np.ndarray]
    # Retain the canonical orbitals as well as the density assembled from
    # them.  The density bridge historically discarded these arrays after
    # forming P(k); periodic TREXIO export needs the original eigenvalues,
    # occupations and (possibly complex) Bloch coefficients.
    eigenvalues_by_kpoint_spin: np.ndarray | None = None
    occupations_by_kpoint_spin: np.ndarray | None = None
    coefficients_by_kpoint_spin: np.ndarray | None = None

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
        if self.nmo <= 0:
            raise BridgeError("MOKP NMO must be positive")
        if self.kpoints.shape != (self.nkp, 3):
            raise BridgeError(
                f"MOKP k-point array has shape {self.kpoints.shape}, expected {(self.nkp, 3)}"
            )
        if self.weights.shape != (self.nkp,):
            raise BridgeError(
                f"MOKP weight array has shape {self.weights.shape}, expected {(self.nkp,)}"
            )
        if self.density_by_kpoint and len(self.density_by_kpoint) != self.nkp:
            raise BridgeError(
                f"MOKP contains {len(self.density_by_kpoint)} k-point density matrices, expected {self.nkp}"
            )
        for ikp, matrix in enumerate(self.density_by_kpoint, start=1):
            if matrix.shape != (self.nao, self.nao):
                raise BridgeError(
                    f"MOKP density matrix for k-point {ikp} has shape {matrix.shape}, "
                    f"expected {(self.nao, self.nao)}"
                )
        orbital_shape = (self.nkp, self.nspins, self.nmo)
        if self.eigenvalues_by_kpoint_spin is not None:
            if self.eigenvalues_by_kpoint_spin.shape != orbital_shape:
                raise BridgeError(
                    "MOKP eigenvalue array has shape "
                    f"{self.eigenvalues_by_kpoint_spin.shape}, expected {orbital_shape}"
                )
        if self.occupations_by_kpoint_spin is not None:
            if self.occupations_by_kpoint_spin.shape != orbital_shape:
                raise BridgeError(
                    "MOKP occupation array has shape "
                    f"{self.occupations_by_kpoint_spin.shape}, expected {orbital_shape}"
                )
        coefficient_shape = (self.nkp, self.nspins, self.nao, self.nmo)
        if self.coefficients_by_kpoint_spin is not None:
            if self.coefficients_by_kpoint_spin.shape != coefficient_shape:
                raise BridgeError(
                    "MOKP coefficient array has shape "
                    f"{self.coefficients_by_kpoint_spin.shape}, expected {coefficient_shape}"
                )
        weight_sum = float(np.sum(self.weights))
        if not math.isclose(weight_sum, 1.0, rel_tol=1.0e-8, abs_tol=1.0e-10):
            raise BridgeError(f"MOKP k-point weights sum to {weight_sum:.16g}, expected 1")


_DIMENSIONS_RE = re.compile(
    r"#\s*DIMENSIONS:\s*natom\s+nspins\s+nao\s+nkp\s*=\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)",
    re.IGNORECASE,
)
_VERSION_RE = re.compile(r"CP2K_KPOINT_MO_DUMP,\s*Version\s+([^\s]+)", re.IGNORECASE)
_NMO_RE = re.compile(r"#\s*NMO\s*=\s*(\d+)", re.IGNORECASE)
_USE_REAL_WFN_RE = re.compile(r"#\s*USE_REAL_WFN\s*=\s*([TF])", re.IGNORECASE)
_BEGIN_KPOINT_SPIN_RE = re.compile(
    r"#\s*BEGIN_KPOINT_SPIN\s+ikp\s+ispin\s*=\s*(\d+)\s+(\d+)",
    re.IGNORECASE,
)
_END_KPOINT_SPIN_RE = re.compile(
    r"#\s*END_KPOINT_SPIN\s+ikp\s+ispin\s*=\s*(\d+)\s+(\d+)",
    re.IGNORECASE,
)


def _next_data_line(lines: Sequence[str], index: int) -> tuple[int, str]:
    while index < len(lines):
        value = lines[index].strip()
        if value and not value.startswith("#"):
            return index, value
        index += 1
    raise BridgeError("unexpected end of MOKP file")


def _collect_float_values(lines: Sequence[str], start: int, stop_marker: str) -> tuple[list[float], int]:
    values: list[float] = []
    cursor = start
    while cursor < len(lines):
        stripped = lines[cursor].strip()
        if stripped.upper().startswith(stop_marker.upper()):
            return values, cursor
        if stripped and not stripped.startswith("#"):
            values.extend(
                float(value.replace("D", "E").replace("d", "e"))
                for value in stripped.split()
            )
        cursor += 1
    raise BridgeError(f"MOKP marker {stop_marker!r} not found")


def _parse_sparse_coefficients(
    lines: Sequence[str],
    start: int,
    stop_markers: Sequence[str],
    *,
    nao: int,
    nmo: int,
) -> tuple[np.ndarray, int, str]:
    matrix = np.zeros((nao, nmo), dtype=np.float64)
    cursor = start
    upper_stops = tuple(marker.upper() for marker in stop_markers)
    while cursor < len(lines):
        stripped = lines[cursor].strip()
        upper = stripped.upper()
        matched = next((marker for marker in upper_stops if upper.startswith(marker)), None)
        if matched is not None:
            return matrix, cursor, matched
        if stripped and not stripped.startswith("#"):
            fields = stripped.split()
            if len(fields) != 3:
                raise BridgeError(f"invalid sparse MOKP coefficient row: {stripped}")
            imo = int(fields[0])
            iao = int(fields[1])
            if not 1 <= imo <= nmo or not 1 <= iao <= nao:
                raise BridgeError(f"MOKP coefficient index out of range: {stripped}")
            matrix[iao - 1, imo - 1] = float(
                fields[2].replace("D", "E").replace("d", "e")
            )
        cursor += 1
    raise BridgeError("unexpected end of MOKP sparse coefficient block")


def read_mokp(
    path: Path, *, retain_orbitals: bool = False, build_density: bool = True
) -> MOKPMetadata:
    lines = path.read_text(encoding="utf-8").splitlines()
    version = "unknown"
    natom = nspins = nao = nkp = nmo = 0
    use_real_wfn: bool | None = None
    for line in lines[:60]:
        if match := _VERSION_RE.search(line):
            version = match.group(1)
        if match := _DIMENSIONS_RE.search(line):
            natom, nspins, nao, nkp = map(int, match.groups())
        if match := _NMO_RE.search(line):
            nmo = int(match.group(1))
        if match := _USE_REAL_WFN_RE.search(line):
            use_real_wfn = match.group(1).upper() == "T"
    if not all((natom, nspins, nao, nkp, nmo)):
        raise BridgeError("MOKP dimensions/NMO header was not found or contains zeros")
    if use_real_wfn is None:
        raise BridgeError("MOKP USE_REAL_WFN header was not found")

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

    kpoint_index = next(
        (i for i, line in enumerate(lines) if line.strip().upper().startswith("# KPOINT_LIST:")),
        None,
    )
    if kpoint_index is None:
        raise BridgeError("MOKP KPOINT_LIST section not found")
    kpoints = np.zeros((nkp, 3), dtype=np.float64)
    weights = np.zeros(nkp, dtype=np.float64)
    cursor = kpoint_index + 1
    found_kpoints = 0
    while cursor < len(lines) and found_kpoints < nkp:
        line = lines[cursor].strip()
        cursor += 1
        if not line or line.startswith("#"):
            continue
        fields = line.split()
        if len(fields) != 5:
            raise BridgeError(f"invalid MOKP k-point row: {line}")
        ikp = int(fields[0])
        if ikp != found_kpoints + 1:
            raise BridgeError(f"unexpected MOKP k-point index {ikp}; expected {found_kpoints + 1}")
        kpoints[ikp - 1, :] = [float(value.replace("D", "E").replace("d", "e")) for value in fields[1:4]]
        weights[ikp - 1] = float(fields[4].replace("D", "E").replace("d", "e"))
        found_kpoints += 1

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

    density_by_kpoint = (
        [np.zeros((nao, nao), dtype=np.complex128) for _ in range(nkp)]
        if build_density
        else []
    )
    eigenvalues_by_kpoint_spin = (
        np.zeros((nkp, nspins, nmo), dtype=np.float64) if retain_orbitals else None
    )
    occupations_by_kpoint_spin = (
        np.zeros((nkp, nspins, nmo), dtype=np.float64) if retain_orbitals else None
    )
    coefficients_by_kpoint_spin = (
        np.zeros((nkp, nspins, nao, nmo), dtype=np.complex128)
        if retain_orbitals
        else None
    )
    seen_blocks: set[tuple[int, int]] = set()
    cursor = 0
    while cursor < len(lines):
        match = _BEGIN_KPOINT_SPIN_RE.match(lines[cursor].strip())
        if match is None:
            cursor += 1
            continue
        ikp, ispin = map(int, match.groups())
        if not 1 <= ikp <= nkp or not 1 <= ispin <= nspins:
            raise BridgeError(f"invalid MOKP k-point/spin block ({ikp}, {ispin})")
        if (ikp, ispin) in seen_blocks:
            raise BridgeError(f"duplicate MOKP k-point/spin block ({ikp}, {ispin})")
        seen_blocks.add((ikp, ispin))

        cursor += 1
        while cursor < len(lines) and not lines[cursor].strip().upper().startswith("# EIGENVALUES"):
            cursor += 1
        if cursor >= len(lines):
            raise BridgeError(f"MOKP EIGENVALUES marker missing for block ({ikp}, {ispin})")
        eigenvalues, cursor = _collect_float_values(lines, cursor + 1, "# OCCUPATIONS")
        if len(eigenvalues) != nmo:
            raise BridgeError(
                f"MOKP block ({ikp}, {ispin}) contains {len(eigenvalues)} eigenvalues, expected {nmo}"
            )
        occupations, cursor = _collect_float_values(lines, cursor + 1, "# MO_COEFF_RE")
        if len(occupations) != nmo:
            raise BridgeError(
                f"MOKP block ({ikp}, {ispin}) contains {len(occupations)} occupations, expected {nmo}"
            )
        coeff_re, cursor, stopped_at = _parse_sparse_coefficients(
            lines,
            cursor + 1,
            ("# MO_COEFF_IM", "# END_KPOINT_SPIN"),
            nao=nao,
            nmo=nmo,
        )
        coeff_im = np.zeros_like(coeff_re)
        if not use_real_wfn:
            if stopped_at != "# MO_COEFF_IM":
                raise BridgeError(f"MOKP imaginary MO coefficients missing for block ({ikp}, {ispin})")
            coeff_im, cursor, stopped_at = _parse_sparse_coefficients(
                lines,
                cursor + 1,
                ("# END_KPOINT_SPIN",),
                nao=nao,
                nmo=nmo,
            )
        if stopped_at != "# END_KPOINT_SPIN":
            raise BridgeError(f"MOKP end marker missing for block ({ikp}, {ispin})")
        end_match = _END_KPOINT_SPIN_RE.match(lines[cursor].strip())
        if end_match is None or tuple(map(int, end_match.groups())) != (ikp, ispin):
            raise BridgeError(f"MOKP end marker disagrees for block ({ikp}, {ispin})")

        coeff = coeff_re.astype(np.complex128)
        if not use_real_wfn:
            coeff += 1j * coeff_im
        occ = np.asarray(occupations, dtype=np.float64)
        if retain_orbitals:
            assert eigenvalues_by_kpoint_spin is not None
            assert occupations_by_kpoint_spin is not None
            assert coefficients_by_kpoint_spin is not None
            eigenvalues_by_kpoint_spin[ikp - 1, ispin - 1, :] = eigenvalues
            occupations_by_kpoint_spin[ikp - 1, ispin - 1, :] = occ
            coefficients_by_kpoint_spin[ikp - 1, ispin - 1, :, :] = coeff
        if build_density:
            weighted = coeff * occ[np.newaxis, :]
            density_by_kpoint[ikp - 1] += weighted @ coeff.conj().T
        cursor += 1

    expected_blocks = {(ikp, ispin) for ikp in range(1, nkp + 1) for ispin in range(1, nspins + 1)}
    missing_blocks = sorted(expected_blocks - seen_blocks)
    if missing_blocks:
        raise BridgeError(
            "MOKP is missing k-point/spin blocks: "
            + ", ".join(f"({ikp},{ispin})" for ikp, ispin in missing_blocks)
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
        nmo=nmo,
        use_real_wfn=use_real_wfn,
        kpoints=kpoints,
        weights=weights,
        density_by_kpoint=density_by_kpoint,
        eigenvalues_by_kpoint_spin=eigenvalues_by_kpoint_spin,
        occupations_by_kpoint_spin=occupations_by_kpoint_spin,
        coefficients_by_kpoint_spin=coefficients_by_kpoint_spin,
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


def _periodic_atom_matching(
    source_elements: Sequence[str],
    source_fractional: np.ndarray,
    reference_elements: Sequence[str],
    reference_fractional: np.ndarray,
    cell_bohr: np.ndarray,
    shift_fractional: np.ndarray,
    tolerance_bohr: float,
) -> tuple[bool, float]:
    """Return whether a unique element-aware periodic atom matching exists."""

    adjacency: list[list[tuple[int, float]]] = []
    max_distance = 0.0
    for element, position in zip(source_elements, source_fractional, strict=True):
        candidates: list[tuple[int, float]] = []
        for index, (reference_element, reference_position) in enumerate(
            zip(reference_elements, reference_fractional, strict=True)
        ):
            if element != reference_element:
                continue
            difference = position + shift_fractional - reference_position
            difference -= np.rint(difference)
            distance = float(np.linalg.norm(difference @ cell_bohr))
            if distance <= tolerance_bohr:
                candidates.append((index, distance))
        if not candidates:
            return False, math.inf
        candidates.sort(key=lambda item: item[1])
        adjacency.append(candidates)

    reference_for_source = [-1] * len(source_elements)
    source_for_reference = [-1] * len(reference_elements)

    def assign(source: int, visited: set[int]) -> bool:
        for reference, _distance in adjacency[source]:
            if reference in visited:
                continue
            visited.add(reference)
            previous = source_for_reference[reference]
            if previous == -1 or assign(previous, visited):
                source_for_reference[reference] = source
                reference_for_source[source] = reference
                return True
        return False

    for source in range(len(source_elements)):
        if not assign(source, set()):
            return False, math.inf

    for source, reference in enumerate(reference_for_source):
        difference = (
            source_fractional[source]
            + shift_fractional
            - reference_fractional[reference]
        )
        difference -= np.rint(difference)
        max_distance = max(
            max_distance, float(np.linalg.norm(difference @ cell_bohr))
        )
    return True, max_distance


def align_mokp_origin_to_cif(
    mokp: MOKPMetadata,
    reference_cif: Path,
    *,
    tolerance_bohr: float = 0.1,
) -> dict[str, float | int | list[float]]:
    """Align a CP2K periodic atom list to the CIF by one global translation.

    CP2K and the CIF may use origin-equivalent periodic coordinates.  Tonto's
    CIF/XML importer requires the same origin, so test the direct atom mapping
    first and then, only if necessary, find a single element-aware translation
    that maps the complete cell.  Any non-translational geometry difference is
    rejected rather than silently changing the CP2K density.
    """

    try:
        from cif_to_cp2k import CIFError, read_expanded_structure
    except ImportError as exc:
        raise BridgeError(
            "cif_to_cp2k.py is required for CIF/XML atom alignment"
        ) from exc

    try:
        cell_angstrom, reference_atoms, _asymmetric_count, _operation_count = (
            read_expanded_structure(reference_cif)
        )
    except (CIFError, OSError, ValueError, np.linalg.LinAlgError) as exc:
        raise BridgeError(f"could not read reference CIF {reference_cif}: {exc}") from exc

    reference_cell_bohr = cell_angstrom * BOHR_PER_ANGSTROM
    cell_difference = float(np.max(np.abs(mokp.cell_bohr - reference_cell_bohr)))
    if not np.allclose(
        mokp.cell_bohr,
        reference_cell_bohr,
        rtol=2.0e-7,
        atol=2.0e-6,
    ):
        raise BridgeError(
            "CP2K MOKP cell does not match the CIF cell "
            f"(maximum vector-component difference {cell_difference:.6g} bohr)"
        )

    source_elements = [atom.element for atom in mokp.atoms]
    reference_elements = [element for element, _position in reference_atoms]
    if Counter(source_elements) != Counter(reference_elements):
        raise BridgeError(
            "CP2K MOKP atoms do not match the CIF full-cell composition: "
            f"CP2K={dict(Counter(source_elements))}, "
            f"CIF={dict(Counter(reference_elements))}"
        )

    source_cartesian = np.asarray(
        [atom.position_bohr for atom in mokp.atoms], dtype=np.float64
    )
    source_fractional = source_cartesian @ np.linalg.inv(mokp.cell_bohr)
    reference_fractional = np.asarray(
        [position for _element, position in reference_atoms], dtype=np.float64
    )

    zero_shift = np.zeros(3, dtype=np.float64)
    matched, max_distance = _periodic_atom_matching(
        source_elements,
        source_fractional,
        reference_elements,
        reference_fractional,
        mokp.cell_bohr,
        zero_shift,
        tolerance_bohr,
    )
    best_shift = zero_shift
    origin_aligned = 0

    if not matched:
        candidates: list[np.ndarray] = []
        first_element = source_elements[0]
        first_position = source_fractional[0]
        for reference_element, reference_position in zip(
            reference_elements, reference_fractional, strict=True
        ):
            if reference_element != first_element:
                continue
            candidate = reference_position - first_position
            candidate -= np.rint(candidate)
            if not any(
                np.allclose(candidate, previous, rtol=0.0, atol=1.0e-10)
                for previous in candidates
            ):
                candidates.append(candidate)

        matches: list[tuple[float, float, np.ndarray]] = []
        for candidate in candidates:
            candidate_matched, candidate_distance = _periodic_atom_matching(
                source_elements,
                source_fractional,
                reference_elements,
                reference_fractional,
                mokp.cell_bohr,
                candidate,
                tolerance_bohr,
            )
            if candidate_matched:
                shift_cartesian = candidate @ mokp.cell_bohr
                matches.append(
                    (
                        candidate_distance,
                        float(np.linalg.norm(shift_cartesian)),
                        candidate,
                    )
                )
        if not matches:
            raise BridgeError(
                "CP2K MOKP atoms cannot be matched to the CIF atoms by one "
                "periodic origin translation; refusing to pass inconsistent "
                "geometry and density to Tonto"
            )
        max_distance, _shift_norm, best_shift = min(
            matches, key=lambda item: (item[0], item[1])
        )
        shift_cartesian = best_shift @ mokp.cell_bohr
        mokp.atoms = [
            dataclasses.replace(
                atom,
                position_bohr=tuple(
                    float(value)
                    for value in (
                        np.asarray(atom.position_bohr, dtype=np.float64)
                        + shift_cartesian
                    )
                ),
            )
            for atom in mokp.atoms
        ]
        origin_aligned = 1

    return {
        "cif_atom_match": 1,
        "cif_origin_aligned": origin_aligned,
        "cif_atom_match_max_distance_bohr": max_distance,
        "cif_cell_max_difference_bohr": cell_difference,
        "cif_origin_shift_fractional": [float(value) for value in best_shift],
    }


def complete_translation_cells(
    cells: Sequence[tuple[int, int, int]],
) -> tuple[list[tuple[int, int, int]], int]:
    """Return an inversion-complete, pair-adjacent translation list."""

    if len(set(cells)) != len(cells):
        raise BridgeError(".kp file contains duplicate lattice-image vectors")
    if (0, 0, 0) not in cells:
        raise BridgeError(".kp file does not contain the reference-cell density block")

    output: list[tuple[int, int, int]] = [(0, 0, 0)]
    seen = {(0, 0, 0)}
    synthesized = 0
    original = set(cells)
    for cell in cells:
        if cell in seen:
            continue
        inverse = tuple(-value for value in cell)
        output.append(cell)
        seen.add(cell)
        if inverse not in seen:
            output.append(inverse)
            seen.add(inverse)
            if inverse not in original:
                synthesized += 1
    return output, synthesized


def reconstruct_density_from_mokp(
    cells: Sequence[tuple[int, int, int]],
    mokp: MOKPMetadata,
) -> tuple[list[np.ndarray], dict[str, float | int]]:
    """Fourier transform the full-grid MOKP AO density matrices to ``P(R)``."""

    hermiticity_max = 0.0
    for ikp, matrix in enumerate(mokp.density_by_kpoint, start=1):
        residual = matrix - matrix.conj().T
        local = float(np.max(np.abs(residual))) if residual.size else 0.0
        hermiticity_max = max(hermiticity_max, local)
        if not np.allclose(matrix, matrix.conj().T, atol=1.0e-10, rtol=1.0e-9):
            raise BridgeError(
                f"MOKP AO density at k-point {ikp} is not Hermitian; max residual={local:.3e}"
            )

    result: list[np.ndarray] = []
    for cell in cells:
        matrix = np.zeros((mokp.nao, mokp.nao), dtype=np.float64)
        rvec = np.asarray(cell, dtype=np.float64)
        for kpoint, weight, density_k in zip(
            mokp.kpoints, mokp.weights, mokp.density_by_kpoint, strict=True
        ):
            angle = 2.0 * math.pi * float(np.dot(rvec, kpoint))
            matrix += float(weight) * (
                math.cos(angle) * density_k.real + math.sin(angle) * density_k.imag
            )
        result.append(matrix)

    return result, {
        "density_source_mokp_fourier": 1,
        "kpoint_weight_sum": float(np.sum(mokp.weights)),
        "kpoint_density_hermiticity_max_residual": hermiticity_max,
    }


def validate_reference_cell_against_kp(
    kp: KPData,
    output_cells: Sequence[tuple[int, int, int]],
    reconstructed: Sequence[np.ndarray],
    *,
    atol: float = 5.0e-7,
    rtol: float = 5.0e-6,
) -> dict[str, float | int]:
    """Cross-check MOKP reconstruction against the unambiguous packed R=0 image."""

    kp_index = kp.cells.index((0, 0, 0))
    output_index = output_cells.index((0, 0, 0))
    packed_zero = kp.total_density()[kp_index]
    mokp_zero = reconstructed[output_index]
    residual = mokp_zero - packed_zero
    max_abs = float(np.max(np.abs(residual))) if residual.size else 0.0
    scale = max(
        float(np.max(np.abs(mokp_zero))) if mokp_zero.size else 0.0,
        float(np.max(np.abs(packed_zero))) if packed_zero.size else 0.0,
        1.0e-300,
    )
    relative = max_abs / scale
    if not np.allclose(mokp_zero, packed_zero, atol=atol, rtol=rtol):
        raise BridgeError(
            "MOKP Fourier density does not reproduce the CP2K R=(0,0,0) restart density; "
            f"max residual={max_abs:.3e} (relative {relative:.3e}). "
            "Regenerate the CP2K input with KPOINTS SYMMETRY FALSE and FULL_GRID TRUE."
        )
    return {
        "reference_cell_kp_max_residual": max_abs,
        "reference_cell_kp_max_relative_residual": relative,
    }


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
    validation: dict[str, float | int | list[float]],
    invert_lattice_vectors: bool,
    pseudopotential_allowed: bool,
    reference_cif: Path | None,
) -> dict:
    return {
        "format": "cp2k-tonto-periodic-bridge",
        "format_version": 4,
        "bridge_version": BRIDGE_VERSION,
        "inputs": {
            "kp": str(kp_path),
            "mokp": str(mokp_path),
            "reference_cif": str(reference_cif) if reference_cif is not None else None,
        },
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
            "packed_nimages": len(kp.cells),
            "output_nimages": int(validation.get("output_images", len(kp.cells))),
            "fortran_record_marker_bytes": kp.fortran_format.marker_bytes,
            "fortran_endian": "little" if kp.fortran_format.endian == "<" else "big",
            "uses_pseudopotentials": any(atom.z_eff != atom.z_nuc for atom in mokp.atoms),
            "pseudopotential_allowed": pseudopotential_allowed,
        },
        "conversion": {
            "ao_order": "CP2K spherical m=-l..+l -> Molden/Tonto",
            "cp2k_realspace_storage": "physical P(R) reconstructed by Fourier transform of full-grid MOKP MOs",
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
    reference_cif: Path | None = None,
    atom_match_tolerance_bohr: float = 0.1,
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

    atom_alignment: dict[str, float | int | list[float]] = {}
    if reference_cif is not None:
        atom_alignment = align_mokp_origin_to_cif(
            mokp,
            reference_cif,
            tolerance_bohr=atom_match_tolerance_bohr,
        )

    output_cells, synthesized_inverse_cells = complete_translation_cells(kp.cells)
    physical_density, storage_validation = reconstruct_density_from_mokp(output_cells, mokp)
    reference_validation = validate_reference_cell_against_kp(kp, output_cells, physical_density)
    perm = kp.header.cp2k_to_molden_permutation()
    density = [matrix[np.ix_(perm, perm)] for matrix in physical_density]
    validation: dict[str, float | int | list[float]] = {
        "natom_match": 1,
        "nao_match": 1,
        "shell_order_match": 1,
        "packed_kp_images": len(kp.cells),
        "output_images": len(output_cells),
        "synthesized_inverse_cells": synthesized_inverse_cells,
    }
    validation.update(storage_validation)
    validation.update(reference_validation)
    validation.update(atom_alignment)
    if not skip_pair_check:
        validation.update(validate_density_translation_pairs(output_cells, density))

    xml_path.parent.mkdir(parents=True, exist_ok=True)
    basis_path.parent.mkdir(parents=True, exist_ok=True)
    write_tonto_periodic_xml(
        xml_path,
        mokp,
        output_cells,
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
        reference_cif=reference_cif,
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
        "--reference-cif",
        type=Path,
        help=(
            "CIF used to generate the CP2K geometry; validates the full-cell "
            "atom list and aligns an origin-equivalent global translation"
        ),
    )
    parser.add_argument(
        "--atom-match-tolerance-bohr",
        type=float,
        default=0.1,
        help="maximum periodic atom-matching distance after origin alignment (default: 0.1 bohr)",
    )
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
            reference_cif=args.reference_cif,
            atom_match_tolerance_bohr=args.atom_match_tolerance_bohr,
        )
    except (BridgeError, OSError, ValueError) as exc:
        parser.exit(2, f"cp2k_tonto_bridge: error: {exc}\n")
    print(json.dumps(manifest, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
