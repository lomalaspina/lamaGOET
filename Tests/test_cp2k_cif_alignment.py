#!/usr/bin/env python3
"""Regression tests for CP2K MOKP/CIF atom-origin alignment."""

from __future__ import annotations

import dataclasses
from pathlib import Path
import sys

import numpy as np


REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO))

from cif_to_cp2k import read_expanded_structure  # noqa: E402
from cp2k_tonto_bridge import (  # noqa: E402
    AtomRecord,
    BOHR_PER_ANGSTROM,
    BridgeError,
    MOKPMetadata,
    align_mokp_origin_to_cif,
)


def mock_mokp(cif: Path, shift_fractional: np.ndarray) -> tuple[MOKPMetadata, np.ndarray]:
    cell_angstrom, expanded, _asymmetric_count, _operation_count = (
        read_expanded_structure(cif)
    )
    cell_bohr = cell_angstrom * BOHR_PER_ANGSTROM
    shift_bohr = shift_fractional @ cell_bohr
    atoms = [
        AtomRecord(
            atom_id=index,
            element=element,
            z_nuc=1,
            z_eff=1,
            position_bohr=tuple(
                float(value)
                for value in (fractional @ cell_bohr + shift_bohr)
            ),
            first_ao=index,
            last_ao=index,
        )
        for index, (element, fractional) in enumerate(expanded, start=1)
    ]
    metadata = MOKPMetadata(
        version="test",
        natom=len(atoms),
        nspins=1,
        nao=len(atoms),
        nkp=1,
        cell_bohr=cell_bohr,
        atoms=atoms,
        shells_by_atom=[],
        nmo=1,
        use_real_wfn=True,
        kpoints=np.zeros((1, 3)),
        weights=np.ones(1),
        density_by_kpoint=[],
    )
    reference_fractional = np.asarray(
        [fractional for _element, fractional in expanded], dtype=float
    )
    return metadata, reference_fractional


def assert_periodic_match(
    metadata: MOKPMetadata, reference_fractional: np.ndarray, tolerance: float = 1.0e-9
) -> None:
    source_cartesian = np.asarray(
        [atom.position_bohr for atom in metadata.atoms], dtype=float
    )
    source_fractional = source_cartesian @ np.linalg.inv(metadata.cell_bohr)
    difference = source_fractional - reference_fractional
    difference -= np.rint(difference)
    if float(np.max(np.abs(difference))) > tolerance:
        raise AssertionError("aligned CP2K atoms do not reproduce CIF positions")


def main() -> None:
    cif = REPO / "Tests" / "inputs" / "calc.cif"

    direct, reference = mock_mokp(cif, np.zeros(3))
    result = align_mokp_origin_to_cif(direct, cif)
    assert result["cif_origin_aligned"] == 0
    assert_periodic_match(direct, reference)

    imposed_shift = np.asarray([0.237, -0.181, 0.313])
    translated, reference = mock_mokp(cif, imposed_shift)
    result = align_mokp_origin_to_cif(translated, cif)
    assert result["cif_origin_aligned"] == 1
    recovered = np.asarray(result["cif_origin_shift_fractional"])
    periodic_residual = recovered + imposed_shift
    periodic_residual -= np.rint(periodic_residual)
    if float(np.max(np.abs(periodic_residual))) > 1.0e-9:
        raise AssertionError(
            f"wrong global origin correction: imposed={imposed_shift}, recovered={recovered}"
        )
    assert_periodic_match(translated, reference)

    inconsistent, _reference = mock_mokp(cif, np.zeros(3))
    first = inconsistent.atoms[0]
    inconsistent.atoms[0] = dataclasses.replace(
        first,
        position_bohr=(
            first.position_bohr[0] + 0.5,
            first.position_bohr[1],
            first.position_bohr[2],
        ),
    )
    try:
        align_mokp_origin_to_cif(inconsistent, cif)
    except BridgeError as exc:
        if "cannot be matched" not in str(exc):
            raise
    else:
        raise AssertionError("non-translational CP2K/CIF mismatch was not rejected")

    print("CP2K CIF/XML atom-alignment tests passed")


if __name__ == "__main__":
    main()
