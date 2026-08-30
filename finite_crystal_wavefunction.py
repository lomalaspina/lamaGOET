#!/usr/bin/env python3
"""Build and run a finite all-electron crystal-cluster wavefunction calculation.

This is deliberately a *new finite calculation*, not a conversion of periodic
Bloch orbitals into a molecular WFN/WFX/NBO file.  A crystallographic CIF is
expanded around a selected atom.  Discrete molecular components are retained
whole; extended covalent networks are cut at a requested buffer radius and
their dangling bonds are hydrogen capped.  Tonto then performs a genuine
finite all-electron SCF and writes ``.47``, ``.wfn`` and ``.wfx`` files.

At least two buffer radii are accepted so users can test whether properties in
the active region are insensitive to the artificial boundary.  The exact
periodic wavefunction remains the accompanying TREXIO export.
"""

from __future__ import annotations

import argparse
from collections import deque
from dataclasses import asdict, dataclass
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import sys

from lamagoet_qt.crystal import CrystalStructure, DisplayAtom, infer_bonds
from periodic_wavefunction_export import ExportError, read_tonto_basis, resolve_basis_file


VERSION = "1.0.0"


class FiniteWavefunctionError(RuntimeError):
    """Raised when a finite cluster would be ambiguous or invalid."""


@dataclass(frozen=True)
class ClusterAtom:
    element: str
    x: float
    y: float
    z: float
    source_index: int
    translation: tuple[int, int, int]
    cap: bool = False

    @property
    def position(self) -> tuple[float, float, float]:
        return self.x, self.y, self.z


# CCDC/Tonto covalent radii for common crystal elements.  The fallback is
# conservative and causes an explicit warning in the manifest.
_COVALENT_RADII = {
    "H": 0.31, "B": 0.84, "C": 0.76, "N": 0.71, "O": 0.66,
    "F": 0.57, "Si": 1.11, "P": 1.07, "S": 1.05, "Cl": 1.02,
    "Br": 1.20, "I": 1.39, "Al": 1.21, "Ga": 1.22, "Ge": 1.20,
    "As": 1.19, "Se": 1.20,
}

_CAP_BOND_LENGTHS = {
    "B": 1.19, "C": 1.09, "N": 1.01, "O": 0.97, "Si": 1.48,
    "P": 1.42, "S": 1.34, "Al": 1.60, "Ga": 1.56, "Ge": 1.53,
    "As": 1.52, "Se": 1.46,
}

_ATOMIC_NUMBERS = {
    symbol: number
    for number, symbol in enumerate(
        (
            "", "H", "He", "Li", "Be", "B", "C", "N", "O", "F", "Ne",
            "Na", "Mg", "Al", "Si", "P", "S", "Cl", "Ar", "K", "Ca",
            "Sc", "Ti", "V", "Cr", "Mn", "Fe", "Co", "Ni", "Cu", "Zn",
            "Ga", "Ge", "As", "Se", "Br", "Kr", "Rb", "Sr", "Y", "Zr",
            "Nb", "Mo", "Tc", "Ru", "Rh", "Pd", "Ag", "Cd", "In", "Sn",
            "Sb", "Te", "I", "Xe", "Cs", "Ba", "La", "Ce", "Pr", "Nd",
            "Pm", "Sm", "Eu", "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb",
            "Lu", "Hf", "Ta", "W", "Re", "Os", "Ir", "Pt", "Au", "Hg",
            "Tl", "Pb", "Bi", "Po", "At", "Rn",
        )
    )
    if symbol
}


def _distance(left: tuple[float, float, float], right: tuple[float, float, float]) -> float:
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(left, right)))


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _translation_shell(structure: CrystalStructure, radius: float) -> int:
    lengths = [math.sqrt(sum(value * value for value in vector)) for vector in structure.cell.vectors]
    if min(lengths) <= 0.0:
        raise FiniteWavefunctionError("invalid zero-length unit-cell vector")
    return max(2, int(math.ceil((radius + 5.0) / min(lengths))) + 1)


def _unique_atoms(atoms: list[DisplayAtom]) -> list[DisplayAtom]:
    result: list[DisplayAtom] = []
    seen: set[tuple[str, float, float, float]] = set()
    for atom in atoms:
        key = (atom.element, *(round(value, 7) for value in atom.cartesian))
        if key not in seen:
            seen.add(key)
            result.append(atom)
    return result


def _periodic_candidates(structure: CrystalStructure, center: DisplayAtom, radius: float) -> list[DisplayAtom]:
    shell = _translation_shell(structure, radius)
    atoms = structure.supercell(shell)
    # Preserve a generous halo so complete components and severed bonds can be
    # detected without retaining the full generated supercell in memory.
    return _unique_atoms(
        [atom for atom in atoms if _distance(atom.cartesian, center.cartesian) <= radius + 4.0]
    )


def _components(atoms: list[DisplayAtom]) -> tuple[list[list[int]], list[list[int]]]:
    neighbours: list[list[int]] = [[] for _ in atoms]
    for left, right in infer_bonds(atoms):
        neighbours[left].append(right)
        neighbours[right].append(left)
    components: list[list[int]] = []
    remaining = set(range(len(atoms)))
    while remaining:
        seed = next(iter(remaining))
        component: list[int] = []
        queue = deque([seed])
        remaining.remove(seed)
        while queue:
            current = queue.popleft()
            component.append(current)
            for neighbour in neighbours[current]:
                if neighbour in remaining:
                    remaining.remove(neighbour)
                    queue.append(neighbour)
        components.append(component)
    return components, neighbours


def _is_network_component(
    component: list[int], atoms: list[DisplayAtom], center: DisplayAtom, radius: float
) -> bool:
    # A molecule has finite graph diameter.  A component that reaches the edge
    # of the deliberately oversized candidate halo is a periodic network.
    edge = radius + 3.0
    return any(_distance(atoms[index].cartesian, center.cartesian) >= edge for index in component)


def _center_component(
    components: list[list[int]], atoms: list[DisplayAtom], center: DisplayAtom
) -> list[int]:
    nearest = min(range(len(atoms)), key=lambda index: _distance(atoms[index].cartesian, center.cartesian))
    if _distance(atoms[nearest].cartesian, center.cartesian) > 1.0e-5:
        raise FiniteWavefunctionError("selected centre atom was not found in generated crystal images")
    return next(component for component in components if nearest in component)


def _cap_position(host: DisplayAtom, omitted: DisplayAtom) -> tuple[float, float, float]:
    direction = tuple(b - a for a, b in zip(host.cartesian, omitted.cartesian))
    length = math.sqrt(sum(value * value for value in direction))
    if length <= 1.0e-10:
        raise FiniteWavefunctionError("zero-length bond encountered while placing a hydrogen cap")
    cap_length = _CAP_BOND_LENGTHS.get(
        host.element, _COVALENT_RADII.get(host.element, 0.90) + _COVALENT_RADII["H"]
    )
    return tuple(a + cap_length * value / length for a, value in zip(host.cartesian, direction))


def build_cluster(
    structure: CrystalStructure,
    center_atom: int,
    active_radius: float,
    buffer_radius: float,
    cap_boundaries: bool,
) -> tuple[list[ClusterAtom], dict[str, object]]:
    unit_cell = structure.unit_cell()
    if not 1 <= center_atom <= len(unit_cell):
        raise FiniteWavefunctionError(
            f"centre atom {center_atom} is outside the 1..{len(unit_cell)} crystallographic-cell range"
        )
    if active_radius <= 0.0 or buffer_radius <= active_radius:
        raise FiniteWavefunctionError("each buffer radius must be larger than the active-region radius")
    center = unit_cell[center_atom - 1]
    candidates = _periodic_candidates(structure, center, buffer_radius)
    components, neighbours = _components(candidates)
    central_component = _center_component(components, candidates, center)
    network = _is_network_component(central_component, candidates, center, buffer_radius)

    selected: set[int] = set()
    if network:
        selected = {
            index
            for index, atom in enumerate(candidates)
            if _distance(atom.cartesian, center.cartesian) <= buffer_radius + 1.0e-8
        }
    else:
        # Include complete molecules/fragments whose nearest atom lies inside
        # the requested buffer, never a spherical slice through a molecule.
        for component in components:
            if min(
                _distance(candidates[index].cartesian, center.cartesian)
                for index in component
            ) <= buffer_radius + 1.0e-8:
                selected.update(component)

    result: list[ClusterAtom] = []
    for index in sorted(selected, key=lambda item: _distance(candidates[item].cartesian, center.cartesian)):
        atom = candidates[index]
        shifted = tuple(value - origin for value, origin in zip(atom.cartesian, center.cartesian))
        result.append(
            ClusterAtom(atom.element, *shifted, atom.source_index, atom.translation, False)
        )

    caps: list[ClusterAtom] = []
    if network and cap_boundaries:
        cap_seen: set[tuple[float, float, float]] = set()
        for index in selected:
            host = candidates[index]
            if host.element == "H":
                continue
            for neighbour in neighbours[index]:
                if neighbour in selected:
                    continue
                position = _cap_position(host, candidates[neighbour])
                shifted = tuple(value - origin for value, origin in zip(position, center.cartesian))
                key = tuple(round(value, 6) for value in shifted)
                if key not in cap_seen:
                    cap_seen.add(key)
                    caps.append(ClusterAtom("H", *shifted, host.source_index, host.translation, True))
        result.extend(caps)

    active_count = sum(
        1 for atom in result if not atom.cap and _distance(atom.position, (0.0, 0.0, 0.0)) <= active_radius
    )
    metadata: dict[str, object] = {
        "network": network,
        "selection_rule": (
            "spherical quantum buffer with hydrogen-capped severed covalent bonds"
            if network
            else "whole molecular components intersecting the buffer radius"
        ),
        "center_atom_1_based": center_atom,
        "center_label": center.label,
        "center_element": center.element,
        "active_radius_angstrom": active_radius,
        "buffer_radius_angstrom": buffer_radius,
        "real_atom_count": sum(not atom.cap for atom in result),
        "cap_atom_count": len(caps),
        "active_real_atom_count": active_count,
    }
    return result, metadata


def _method_block(method: str, multiplicity: int) -> tuple[str, list[str]]:
    value = method.strip().lower().replace(" ", "")
    aliases = {
        "hf": "uhf" if multiplicity != 1 else "rhf",
        "pbepbe": "pbe", "upbepbe": "upbe", "pbe1pbe": "b3lyp",
        "upbe1pbe": "ub3lyp", "rblyp": "blyp", "rb3lyp": "b3lyp",
        "rpbe": "pbe",
    }
    value = aliases.get(value, value)
    unrestricted = value.startswith("u") or multiplicity != 1
    base = value[1:] if value.startswith("u") else value
    if base == "rhf":
        base = "hf"
    if base == "uhf":
        base = "hf"
        unrestricted = True
    if base == "hf":
        return ("uhf" if unrestricted else "rhf"), []
    functionals = {
        "blyp": ("becke88", "lyp"),
        "pbe": ("pbex", "pbec"),
        "b3lyp": ("b3lypgx", "b3lypgc"),
    }
    if base not in functionals:
        raise FiniteWavefunctionError(
            f"finite Tonto SCF method {method!r} is unsupported; choose HF, BLYP, PBE or B3LYP"
        )
    exchange, correlation = functionals[base]
    return ("uks" if unrestricted else "rks"), [
        f"      dft_exchange_functional= {exchange}",
        f"      dft_correlation_functional= {correlation}",
    ]


def _write_xyz(path: Path, atoms: list[ClusterAtom], title: str) -> None:
    lines = [str(len(atoms)), title]
    lines.extend(
        f"{atom.element:<2s} {atom.x: .10f} {atom.y: .10f} {atom.z: .10f}"
        for atom in atoms
    )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _write_tonto_input(
    path: Path,
    name: str,
    atoms: list[ClusterAtom],
    basis_directory: Path,
    basis_name: str,
    method: str,
    charge: int,
    multiplicity: int,
    convergence: float,
) -> None:
    kind, functionals = _method_block(method, multiplicity)
    lines = [
        "{",
        f"   name= {name}",
        "   output_style_options= { real_precision= 8 }",
        f"   basis_directory= '{basis_directory}'",
        f"   basis_name= '{basis_name}'",
        f"   charge= {charge}",
        f"   multiplicity= {multiplicity}",
        "   atoms= {",
        "      keys= { label= { units= angstrom } pos= }",
        "      data= {",
    ]
    lines.extend(
        f"         {atom.element:<2s} {atom.x: .10f} {atom.y: .10f} {atom.z: .10f}"
        for atom in atoms
    )
    lines.extend(
        [
            "      }",
            "   }",
            "   put",
            "   scfdata= {",
            "      initial_density= promolecule",
            f"      kind= {kind}",
            *functionals,
            "      direct= on",
            f"      convergence= {convergence:.3e}",
            f"      diis= {{ convergence_tolerance= {convergence:.3e} }}",
            "      output= no",
            "      output_results= yes",
            "   }",
            "   scf",
            "   make_scf_density_matrix",
            "   assign_NOs_to_MOs",
            "   make_hirshfeld_inputs",
            "   make_fock_matrix",
            "   put_nbo_file_47",
            "   write_aim2000_wfn_file",
            "   write_full_wfx_file",
            "}",
        ]
    )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _parse_energy(stdout: Path) -> float | None:
    match = re.search(
        r"^Total energy \(E_e\+V_NN\)\s+E\s+\.{3,}\s+([-+0-9.EeDd]+)",
        stdout.read_text(encoding="utf-8", errors="replace"),
        re.MULTILINE,
    )
    return float(match.group(1).replace("D", "E").replace("d", "e")) if match else None


def _validate_exports(directory: Path, name: str) -> dict[str, object]:
    result: dict[str, object] = {}
    for suffix in ("47", "wfn", "wfx"):
        path = directory / f"{name}.{suffix}"
        if not path.is_file() or path.stat().st_size == 0:
            raise FiniteWavefunctionError(f"Tonto did not write a non-empty {path.name}")
        result[suffix] = {"file": path.name, "bytes": path.stat().st_size, "sha256": _sha256(path)}
    nbo = (directory / f"{name}.47").read_text(encoding="utf-8", errors="replace")
    if "$FOCK" not in nbo.upper():
        raise FiniteWavefunctionError("NBO .47 validation failed: the required $FOCK block is absent")
    wfx = (directory / f"{name}.wfx").read_text(encoding="utf-8", errors="replace")
    # The WFX dictionary uses this historical tag name even when a writer, as
    # Tonto's full writer does, records virtual orbitals with zero occupation.
    for tag in (
        "<Number of Occupied Molecular Orbitals>",
        "<Molecular Orbital Primitive Coefficients>",
    ):
        if tag not in wfx:
            raise FiniteWavefunctionError(f"WFX validation failed: missing {tag}")
    nmo_match = re.search(
        r"<Number of Occupied Molecular Orbitals>\s*(\d+)\s*</Number of Occupied Molecular Orbitals>",
        wfx,
        re.DOTALL,
    )
    nbas_match = re.search(r"\bNBAS\s*=\s*(\d+)", nbo, re.IGNORECASE)
    occupation_match = re.search(
        r"<Molecular Orbital Occupation Numbers>(.*?)</Molecular Orbital Occupation Numbers>",
        wfx,
        re.DOTALL,
    )
    if not nmo_match or not nbas_match or not occupation_match:
        raise FiniteWavefunctionError("could not cross-check the WFX orbital count against NBO NBAS")
    nmo = int(nmo_match.group(1))
    nbas = int(nbas_match.group(1))
    occupations = [
        float(value.replace("D", "E").replace("d", "e"))
        for value in occupation_match.group(1).split()
    ]
    if nmo != nbas or len(occupations) != nmo:
        raise FiniteWavefunctionError(
            f"full-orbital validation failed: WFX has {nmo} MOs/{len(occupations)} occupations, NBO has {nbas} basis functions"
        )
    result["orbital_space"] = {
        "molecular_orbitals": nmo,
        "occupied_orbitals": sum(abs(value) > 1.0e-10 for value in occupations),
        "virtual_orbitals": sum(abs(value) <= 1.0e-10 for value in occupations),
        "complete_ao_dimension": True,
    }
    wfn = (directory / f"{name}.wfn").read_text(encoding="utf-8", errors="replace")
    if "END DATA" not in wfn:
        raise FiniteWavefunctionError("WFN validation failed: missing END DATA")
    return result


def _parse_radii(value: str) -> list[float]:
    try:
        radii = sorted({float(item.strip()) for item in value.split(",") if item.strip()})
    except ValueError as exc:
        raise argparse.ArgumentTypeError("buffer radii must be comma-separated numbers") from exc
    if not radii or any(radius <= 0.0 for radius in radii):
        raise argparse.ArgumentTypeError("at least one positive buffer radius is required")
    return radii


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", choices=("cp2k", "crystal23"), required=True)
    parser.add_argument("--periodic-file", required=True, type=Path)
    parser.add_argument("--periodic-trexio", type=Path)
    parser.add_argument("--cif", required=True, type=Path)
    parser.add_argument("--basis-directory", required=True, type=Path)
    parser.add_argument("--basis-name", required=True)
    parser.add_argument("--method", required=True)
    parser.add_argument("--charge", type=int, default=0)
    parser.add_argument("--multiplicity", type=int, default=1)
    parser.add_argument("--center-atom", type=int, default=1)
    parser.add_argument("--active-radius", type=float, default=2.0)
    parser.add_argument("--buffer-radii", type=_parse_radii, default=_parse_radii("4.0,6.0"))
    parser.add_argument("--cap-boundaries", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--tonto", default="tonto")
    parser.add_argument("--convergence", type=float, default=1.0e-7)
    parser.add_argument("--output-directory", type=Path, required=True)
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument(
        "--allow-single-radius", action="store_true",
        help="allow a non-converged exploratory calculation with one buffer radius",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        if len(args.buffer_radii) < 2 and not args.allow_single_radius:
            raise FiniteWavefunctionError(
                "at least two buffer radii are required for a boundary-convergence series"
            )
        if not args.periodic_file.is_file():
            raise FiniteWavefunctionError(f"periodic provenance file not found: {args.periodic_file}")
        if not args.cif.is_file():
            raise FiniteWavefunctionError(f"final crystallographic CIF not found: {args.cif}")
        basis_file = resolve_basis_file(args.basis_directory, args.basis_name)
        structure = CrystalStructure.from_cif(args.cif)
        output = args.output_directory.resolve()
        output.mkdir(parents=True, exist_ok=True)
        manifest: dict[str, object] = {
            "format": "finite all-electron crystal-cluster wavefunction",
            "generator_version": VERSION,
            "scientific_scope": (
                "New finite Tonto SCF on a buffered crystal cluster. This is not a direct "
                "conversion of Bloch orbitals and is not the exact infinite periodic wavefunction."
            ),
            "source_program": args.source,
            "periodic_provenance": {
                "file": str(args.periodic_file.resolve()),
                "sha256": _sha256(args.periodic_file),
            },
            "periodic_trexio": (
                {"file": str(args.periodic_trexio.resolve()), "sha256": _sha256(args.periodic_trexio)}
                if args.periodic_trexio and args.periodic_trexio.is_file()
                else None
            ),
            "cif": {"file": str(args.cif.resolve()), "sha256": _sha256(args.cif)},
            "basis": {"file": str(basis_file.resolve()), "sha256": _sha256(basis_file)},
            "method": args.method,
            "charge": args.charge,
            "multiplicity": args.multiplicity,
            "results": [],
            "boundary_convergence_required": len(args.buffer_radii) >= 2,
            "warnings": [
                "Inspect active-region observables across buffer radii before using a finite file scientifically.",
                "Hydrogen caps alter the boundary Hamiltonian of extended covalent networks.",
                "No claim is made that diffraction amplitudes and model phases determine a unique interacting wavefunction.",
            ],
        }
        for radius in args.buffer_radii:
            atoms, cluster_metadata = build_cluster(
                structure, args.center_atom, args.active_radius, radius, args.cap_boundaries
            )
            elements = {atom.element for atom in atoms}
            read_tonto_basis(basis_file, elements)
            electron_count = sum(_ATOMIC_NUMBERS.get(atom.element, 0) for atom in atoms) - args.charge
            if electron_count <= 0 or (electron_count - (args.multiplicity - 1)) % 2:
                raise FiniteWavefunctionError(
                    f"buffer {radius:g} A gives {electron_count} electrons, incompatible with multiplicity {args.multiplicity}"
                )
            tag = f"buffer_{radius:g}A".replace(".", "p")
            run_directory = output / tag
            if run_directory.exists():
                raise FiniteWavefunctionError(f"refusing to overwrite existing run directory {run_directory}")
            run_directory.mkdir(parents=True)
            name = f"finite_{args.source}_{tag}"
            _write_xyz(run_directory / f"{name}.xyz", atoms, cluster_metadata["selection_rule"])
            _write_tonto_input(
                run_directory / "stdin", name, atoms, basis_file.parent, basis_file.name,
                args.method, args.charge, args.multiplicity, args.convergence,
            )
            result: dict[str, object] = {
                **cluster_metadata,
                "directory": tag,
                "job_name": name,
                "electron_count": electron_count,
                "prepared_only": args.prepare_only,
            }
            if not args.prepare_only:
                executable = shutil.which(args.tonto) if not Path(args.tonto).is_file() else args.tonto
                if not executable:
                    raise FiniteWavefunctionError(f"Tonto executable was not found: {args.tonto}")
                completed = subprocess.run([str(executable)], cwd=run_directory, check=False)
                stdout = run_directory / "stdout"
                if completed.returncode != 0 or not stdout.is_file():
                    raise FiniteWavefunctionError(
                        f"Tonto failed for buffer {radius:g} A with status {completed.returncode}"
                    )
                energy = _parse_energy(stdout)
                if energy is None:
                    raise FiniteWavefunctionError(
                        f"Tonto stdout for buffer {radius:g} A contains no final SCF energy"
                    )
                result["energy_hartree"] = energy
                result["exports"] = _validate_exports(run_directory, name)
                result["prepared_only"] = False
            manifest["results"].append(result)  # type: ignore[union-attr]
            (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        print(f"Prepared {len(args.buffer_radii)} finite cluster calculation(s) in {output}")
        if args.prepare_only:
            print("Preparation only: inspect each XYZ/stdin before running Tonto.")
        else:
            print("Validated .47, .wfn and .wfx files, including the NBO $FOCK block.")
        print(f"Manifest: {output / 'manifest.json'}")
        return 0
    except (FiniteWavefunctionError, ExportError, OSError, ValueError) as exc:
        print(f"finite_crystal_wavefunction: error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
