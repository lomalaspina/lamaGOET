"""Basis Set Exchange helpers for the optional Qt database selector."""

from __future__ import annotations

from functools import lru_cache
from typing import Mapping, Sequence


class BasisExchangeError(RuntimeError):
    """Raised when BSE is unavailable or cannot represent a selection."""


def _bse():
    try:
        import basis_set_exchange as bse
        from basis_set_exchange import lut
    except ImportError as exc:  # pragma: no cover - optional installation
        raise BasisExchangeError(
            "Basis Set Exchange is not installed. Run: "
            "python -m pip install -r requirements-qt.txt"
        ) from exc
    return bse, lut


@lru_cache(maxsize=None)
def all_electron_basis_names(element: str) -> tuple[str, ...]:
    """Return orbital GTO basis names that are all-electron for *element*."""

    bse, lut = _bse()
    symbol = element.strip().capitalize()
    try:
        atomic_number = str(lut.element_Z_from_sym(symbol))
    except Exception as exc:
        raise BasisExchangeError(f"Unknown chemical element: {element}") from exc

    result: list[str] = []
    for metadata in bse.get_metadata().values():
        latest = metadata["versions"][metadata["latest_version"]]
        function_types = metadata.get("function_types", ())
        if metadata.get("role") != "orbital":
            continue
        if not any(str(kind).startswith("gto") for kind in function_types):
            continue
        if atomic_number not in latest.get("elements", ()):
            continue
        name = metadata["display_name"]
        # Most entries cannot contain an ECP and need no expensive data load.
        # Mixed all-electron/ECP families are checked for this element only.
        if "scalar_ecp" in function_types:
            try:
                atom_record = bse.get_basis(name, elements=[symbol])["elements"][
                    atomic_number
                ]
            except Exception:
                continue
            if atom_record.get("ecp_potentials") or atom_record.get("ecp_electrons"):
                continue
        result.append(name)
    return tuple(sorted(set(result), key=str.casefold))


FORMAT_FOR_PROGRAM = {
    "Gaussian": "gaussian94",
    "optgaussian": "gaussian94",
    "Orca": "orca",
    "optorca": "orca",
    "Crystal14": "crystal",
    "CP2K": "cp2k",
}


# Neutral-atom subshells in Madelung filling order.  CRYSTAL's CHE field is
# not a basis-function coefficient: it is the formal population assigned to
# a shell for the initial atomic density.  Basis Set Exchange intentionally
# writes zero because it cannot know the molecular/crystal charge state.  The
# lamaGOET selector only offers all-electron bases, so a neutral-atom starting
# population is the safe automatic default and, critically, preserves charge
# neutrality for a neutral periodic cell.
_AUFBAU_SUBSHELLS = (
    (1, 0),
    (2, 0),
    (2, 1),
    (3, 0),
    (3, 1),
    (4, 0),
    (3, 2),
    (4, 1),
    (5, 0),
    (4, 2),
    (5, 1),
    (6, 0),
    (4, 3),
    (5, 2),
    (6, 1),
    (7, 0),
    (5, 3),
    (6, 2),
    (7, 1),
)

# Well-established neutral-ground-state promotions through Z=98, the largest
# conventional atomic number accepted by the CRYSTAL basis writer.  Each item
# is (source subshell, destination subshell, electron count).  These affect
# only the atomic SCF starting population; the total remains exactly Z.
_NEUTRAL_ATOM_PROMOTIONS = {
    24: (((4, 0), (3, 2), 1),),  # Cr
    29: (((4, 0), (3, 2), 1),),  # Cu
    41: (((5, 0), (4, 2), 1),),  # Nb
    42: (((5, 0), (4, 2), 1),),  # Mo
    44: (((5, 0), (4, 2), 1),),  # Ru
    45: (((5, 0), (4, 2), 1),),  # Rh
    46: (((5, 0), (4, 2), 2),),  # Pd
    47: (((5, 0), (4, 2), 1),),  # Ag
    57: (((4, 3), (5, 2), 1),),  # La
    58: (((4, 3), (5, 2), 1),),  # Ce
    64: (((4, 3), (5, 2), 1),),  # Gd
    78: (((6, 0), (5, 2), 1),),  # Pt
    79: (((6, 0), (5, 2), 1),),  # Au
    89: (((5, 3), (6, 2), 1),),  # Ac
    90: (((5, 3), (6, 2), 2),),  # Th
    91: (((5, 3), (6, 2), 1),),  # Pa
    92: (((5, 3), (6, 2), 1),),  # U
    93: (((5, 3), (6, 2), 1),),  # Np
    96: (((5, 3), (6, 2), 1),),  # Cm
}


def _neutral_atom_subshell_occupancies(
    atomic_number: int,
) -> dict[tuple[int, int], int]:
    """Return neutral-ground-state populations indexed by ``(n, l)``."""

    if not 1 <= atomic_number <= 98:
        raise BasisExchangeError(
            "Automatic CRYSTAL shell populations support elements H through Cf "
            f"(Z=1..98); received Z={atomic_number}."
        )
    remaining = atomic_number
    populations: dict[tuple[int, int], int] = {}
    for subshell in _AUFBAU_SUBSHELLS:
        if remaining == 0:
            break
        capacity = 2 * (2 * subshell[1] + 1)
        population = min(capacity, remaining)
        populations[subshell] = population
        remaining -= population
    if remaining:
        raise BasisExchangeError(
            f"No neutral-atom shell population is available for Z={atomic_number}."
        )
    for source, destination, count in _NEUTRAL_ATOM_PROMOTIONS.get(
        atomic_number, ()
    ):
        if populations.get(source, 0) < count:
            raise BasisExchangeError(
                f"Invalid neutral-atom population rule for Z={atomic_number}."
            )
        populations[source] -= count
        populations[destination] = populations.get(destination, 0) + count
    return populations


def _populate_crystal_shell_charges(
    piece: str,
    element: str,
    lut,
) -> str:
    """Replace BSE's zero CHE fields by neutral-atom shell populations.

    CRYSTAL shell records consume occupied subshells from compact to diffuse.
    A LAT=1 SP record consumes one s and one p subshell and receives their
    combined population.  Polarization/diffuse records left after the occupied
    subshells have been assigned correctly retain CHE=0.
    """

    lines = piece.rstrip().splitlines()
    if not lines or lines[-1].split() != ["99", "0"]:
        raise BasisExchangeError(
            "Basis Set Exchange returned an incomplete CRYSTAL basis block."
        )
    try:
        atomic_number = int(lut.element_Z_from_sym(element.strip().capitalize()))
        atom_header = lines[0].split()
        rendered_atomic_number = int(atom_header[0])
        shell_count = int(atom_header[1])
    except (IndexError, TypeError, ValueError) as exc:
        raise BasisExchangeError(
            f"Basis Set Exchange returned an invalid CRYSTAL header for {element}."
        ) from exc
    if rendered_atomic_number != atomic_number:
        raise BasisExchangeError(
            "Basis Set Exchange returned a CRYSTAL block for the wrong element: "
            f"expected Z={atomic_number}, received Z={rendered_atomic_number}."
        )

    populations = _neutral_atom_subshell_occupancies(atomic_number)
    queues: dict[int, list[int]] = {}
    for (principal, angular), population in sorted(populations.items()):
        if population:
            queues.setdefault(angular, []).append(population)
    consumed = {angular: 0 for angular in queues}

    output = [lines[0]]
    line_index = 1
    total_charge = 0
    for _ in range(shell_count):
        if line_index >= len(lines) - 1:
            raise BasisExchangeError(
                f"CRYSTAL basis block for {element} ended before all shells."
            )
        fields = lines[line_index].split()
        if len(fields) != 5:
            raise BasisExchangeError(
                f"Invalid CRYSTAL shell header for {element}: {lines[line_index]}"
            )
        try:
            ityb, lat, primitive_count = map(int, fields[:3])
        except ValueError as exc:
            raise BasisExchangeError(
                f"Invalid CRYSTAL shell header for {element}: {lines[line_index]}"
            ) from exc
        if ityb != 0 or lat not in {0, 1, 2, 3, 4, 5} or primitive_count < 1:
            raise BasisExchangeError(
                "Automatic CRYSTAL CHE assignment requires general all-electron "
                f"shells; unsupported header for {element}: {lines[line_index]}"
            )

        angular_momenta = (0, 1) if lat == 1 else ((0,) if lat == 0 else (lat - 1,))
        shell_charge = 0
        for angular in angular_momenta:
            position = consumed.get(angular, 0)
            values = queues.get(angular, [])
            if position < len(values):
                shell_charge += values[position]
            consumed[angular] = position + 1
        total_charge += shell_charge
        formatted_charge = (
            f"{float(shell_charge):.1f}" if shell_charge else fields[3]
        )
        output.append(
            f"{fields[0]} {fields[1]} {fields[2]} {formatted_charge} {fields[4]}"
        )

        primitive_end = line_index + 1 + primitive_count
        if primitive_end > len(lines) - 1:
            raise BasisExchangeError(
                f"CRYSTAL basis block for {element} has an incomplete contraction."
            )
        output.extend(lines[line_index + 1 : primitive_end])
        line_index = primitive_end

    if line_index != len(lines) - 1:
        raise BasisExchangeError(
            f"CRYSTAL basis block for {element} contains unexpected records."
        )
    unassigned = sum(
        sum(values[consumed.get(angular, 0) :])
        for angular, values in queues.items()
    )
    if unassigned or total_charge != atomic_number:
        raise BasisExchangeError(
            f"The selected CRYSTAL basis for {element} cannot represent all "
            f"{atomic_number} neutral-atom electrons in its shell records."
        )
    output.append("99 0")
    return "\n".join(output)


def render_mixed_basis(
    program: str,
    selections: Mapping[str, str],
) -> tuple[str, str]:
    """Render one external basis file and return ``(text, CP2K map)``."""

    bse, lut = _bse()
    output_format = FORMAT_FOR_PROGRAM.get(program)
    if not output_format:
        raise BasisExchangeError(
            "BSE export is supported for Gaussian, ORCA, Crystal23 and CP2K. "
            "Tonto/ELMOdb require Tonto-native library files, and OCC requires "
            "an OCC-native basis definition."
        )
    if not selections:
        raise BasisExchangeError("No element basis selections were provided.")

    pieces: list[str] = []
    for element, name in sorted(selections.items()):
        if name not in all_electron_basis_names(element):
            raise BasisExchangeError(
                f"{name} is not an all-electron orbital basis for {element}."
            )
        try:
            pieces.append(
                bse.get_basis(
                    name,
                    elements=[element],
                    fmt=output_format,
                    header=False,
                ).strip()
            )
        except Exception as exc:
            raise BasisExchangeError(
                f"BSE could not export {name} for {element} as {output_format}: {exc}"
            ) from exc

    if output_format == "orca":
        bodies = []
        for piece in pieces:
            lines = [
                line
                for line in piece.splitlines()
                if line.strip().upper() not in {"$DATA", "$END"}
            ]
            bodies.append("\n".join(lines).strip())
        text = "$DATA\n\n" + "\n\n".join(bodies) + "\n\n$END\n"
    elif output_format == "gaussian94":
        # In a Gaussian Gen basis, **** terminates each element/centre basis
        # block.  It is required between elements as well as after the last
        # one; do not collapse the per-element BSE terminators into one.
        if any(not piece.rstrip().endswith("****") for piece in pieces):
            raise BasisExchangeError(
                "Basis Set Exchange returned an incomplete Gaussian94 basis block."
            )
        # Gaussian 09 treats a blank line after **** as the end of the entire
        # general-basis input section.  The following element header must be
        # on the immediately following line.
        text = "\n".join(pieces) + "\n"
    elif output_format == "crystal":
        # BSE exports every requested element as a complete stand-alone
        # CRYSTAL basis input and therefore appends ``99 0`` to every piece.
        # In a mixed basis that record terminates the *entire* basis section,
        # so retaining it between elements makes CRYSTAL ignore the remaining
        # atom definitions.  Strip the per-element records and emit exactly
        # one terminator after the final element.
        bodies: list[str] = []
        for element, piece in zip(sorted(selections), pieces):
            piece = _populate_crystal_shell_charges(piece, element, lut)
            lines = piece.rstrip().splitlines()
            if not lines or lines[-1].split() != ["99", "0"]:
                raise BasisExchangeError(
                    "Basis Set Exchange returned an incomplete CRYSTAL basis block."
                )
            bodies.append("\n".join(lines[:-1]).rstrip())
        text = "\n".join(bodies) + "\n99 0\n"
    else:
        text = "\n\n".join(pieces) + "\n"
    cp2k_map = " ".join(
        f"{element.capitalize()}={name}"
        for element, name in sorted(selections.items())
    )
    return text, cp2k_map


def common_preferred_basis(
    choices: Sequence[str], preferred: Sequence[str]
) -> str:
    folded = {choice.casefold(): choice for choice in choices}
    for candidate in preferred:
        if candidate.casefold() in folded:
            return folded[candidate.casefold()]
    return choices[0] if choices else ""
