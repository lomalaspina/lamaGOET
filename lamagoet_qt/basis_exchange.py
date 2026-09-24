"""Basis Set Exchange helpers for the optional Qt database selector."""

from __future__ import annotations

import json
import re
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
    # BSE's formatter named ``orca`` emits a GAMESS-style $DATA container,
    # which is not valid when appended to an ORCA input.  Render an actual
    # ORCA %basis/NewGTO block from BSE JSON instead.
    "Orca": "orca-native",
    "optorca": "orca-native",
    "Crystal14": "crystal",
    "Crystal23": "crystal",
    "CP2K": "cp2k",
    "OCC": "json",
    "Tonto": "tonto",
}

BASIS_EXCHANGE_OUTPUT_FILENAMES = {
    "Gaussian": "basis_gen.txt",
    "optgaussian": "basis_gen.txt",
    "Orca": "basis_gen.txt",
    "optorca": "basis_gen.txt",
    "Crystal14": "basis_gen.txt",
    "Crystal23": "basis_gen.txt",
    "CP2K": "basis_gen.txt",
    "OCC": "basis_gen.json",
    "Tonto": "basis_gen",
}

TONTO_BASIS_LABEL = "basis_gen"


def basis_exchange_output_filename(program: str) -> str:
    """Return the calculation-directory filename used for a BSE export."""

    try:
        return BASIS_EXCHANGE_OUTPUT_FILENAMES[program]
    except KeyError as exc:
        raise BasisExchangeError(
            f"Basis Set Exchange export is not supported for {program}."
        ) from exc


@lru_cache(maxsize=None)
def _metadata_by_display_name() -> dict[str, dict]:
    bse, _ = _bse()
    return {
        metadata["display_name"].casefold(): metadata
        for metadata in bse.get_metadata().values()
    }


def _is_explicit_dkh_basis(name: str) -> bool:
    """Return whether BSE metadata explicitly identifies a DKH/DK basis.

    This deliberately does not treat every all-electron relativistic basis as
    interchangeable.  In particular, X2C-only families are excluded.  The
    test is restricted to the BSE display name, family and description and
    requires an explicit Douglas--Kroll, DK or DKH marker.
    """

    metadata = _metadata_by_display_name().get(name.casefold())
    if metadata is None:
        return False
    fields = " ".join(
        str(metadata.get(field, ""))
        for field in ("display_name", "family", "description")
    )
    if re.search(r"douglas[ -]+kroll", fields, flags=re.IGNORECASE):
        return True
    return bool(
        re.search(
            r"(?<![A-Za-z0-9])DK(?:H)?[0-9]*(?![A-Za-z0-9])",
            fields,
            flags=re.IGNORECASE,
        )
    )


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


def _tonto_shell_letter(angular_momentum: int) -> str:
    """Return Tonto's one-letter shell label for angular momentum ``l``."""

    if not 0 <= angular_momentum <= 23:
        raise BasisExchangeError(
            "Tonto basis libraries support angular momenta l=0..23; "
            f"received l={angular_momentum}."
        )
    if angular_momentum <= 4:
        return "SPDFG"[angular_momentum]
    return chr(ord("G") + angular_momentum - 4)


def _render_tonto_element(data: Mapping, element: str) -> str:
    """Render one BSE element record as Tonto ``gamess-us`` library data.

    BSE may store combined SP shells and generally contracted shells.  Tonto's
    GAMESS-US library reader consumes one contraction vector per shell, so the
    renderer expands each vector explicitly instead of forwarding a combined
    ``L`` record whose second coefficient column Tonto would not read.
    """

    elements = data.get("elements", {})
    if len(elements) != 1:
        raise BasisExchangeError(
            f"Expected exactly one BSE element record for {element}."
        )
    record = next(iter(elements.values()))
    if record.get("ecp_potentials") or record.get("ecp_electrons"):
        raise BasisExchangeError(
            f"Tonto requires an all-electron basis for {element}."
        )
    shells = record.get("electron_shells", ())
    if not shells:
        raise BasisExchangeError(
            f"The selected BSE basis has no orbital shells for {element}."
        )

    lines: list[str] = []
    for shell in shells:
        function_type = str(shell.get("function_type", ""))
        if not function_type.startswith("gto"):
            raise BasisExchangeError(
                f"Tonto cannot render BSE shell type {function_type!r} for {element}."
            )
        angular_momenta = list(shell.get("angular_momentum", ()))
        exponents = list(shell.get("exponents", ()))
        coefficients = list(shell.get("coefficients", ()))
        if not angular_momenta or not exponents or not coefficients:
            raise BasisExchangeError(
                f"BSE returned an incomplete orbital shell for {element}."
            )
        if len(angular_momenta) == 1:
            contractions = [
                (int(angular_momenta[0]), coefficient)
                for coefficient in coefficients
            ]
        elif len(angular_momenta) == len(coefficients):
            contractions = [
                (int(angular), coefficient)
                for angular, coefficient in zip(angular_momenta, coefficients)
            ]
        else:
            raise BasisExchangeError(
                "Tonto cannot unambiguously expand the combined/general shell "
                f"returned by BSE for {element}."
            )

        for angular, coefficient in contractions:
            coefficient = list(coefficient)
            if len(coefficient) != len(exponents):
                raise BasisExchangeError(
                    f"BSE returned mismatched exponents and coefficients for {element}."
                )
            shell_letter = _tonto_shell_letter(angular)
            lines.append(f"{shell_letter} {len(exponents)}")
            for index, (exponent, value) in enumerate(
                zip(exponents, coefficient), start=1
            ):
                try:
                    float(str(exponent).replace("D", "E").replace("d", "e"))
                    float(str(value).replace("D", "E").replace("d", "e"))
                except ValueError as exc:
                    raise BasisExchangeError(
                        f"BSE returned a non-numeric primitive for {element}."
                    ) from exc
                lines.append(f"{index} {exponent} {value}")
    return "\n".join(lines)


def _expanded_contractions(
    shell: Mapping, element: str
) -> tuple[list[str], list[tuple[int, list[str]]]]:
    """Expand one validated BSE shell into explicit contraction vectors."""

    function_type = str(shell.get("function_type", ""))
    if not function_type.startswith("gto"):
        raise BasisExchangeError(
            f"Cannot render BSE shell type {function_type!r} for {element}."
        )
    angular_momenta = list(shell.get("angular_momentum", ()))
    exponents = list(shell.get("exponents", ()))
    coefficients = list(shell.get("coefficients", ()))
    if not angular_momenta or not exponents or not coefficients:
        raise BasisExchangeError(
            f"BSE returned an incomplete orbital shell for {element}."
        )
    if len(angular_momenta) == 1:
        contractions = [
            (int(angular_momenta[0]), list(coefficient))
            for coefficient in coefficients
        ]
    elif len(angular_momenta) == len(coefficients):
        contractions = [
            (int(angular), list(coefficient))
            for angular, coefficient in zip(angular_momenta, coefficients)
        ]
    else:
        raise BasisExchangeError(
            "Cannot unambiguously expand the combined/general shell "
            f"returned by BSE for {element}."
        )
    for _, coefficient in contractions:
        if len(coefficient) != len(exponents):
            raise BasisExchangeError(
                f"BSE returned mismatched exponents and coefficients for {element}."
            )
        for exponent, value in zip(exponents, coefficient):
            try:
                float(str(exponent).replace("D", "E").replace("d", "e"))
                float(str(value).replace("D", "E").replace("d", "e"))
            except ValueError as exc:
                raise BasisExchangeError(
                    f"BSE returned a non-numeric primitive for {element}."
                ) from exc
    return exponents, contractions


def _render_orca_element(data: Mapping, element: str) -> str:
    """Render one all-electron BSE record as an ORCA ``NewGTO`` block."""

    elements = data.get("elements", {})
    if len(elements) != 1:
        raise BasisExchangeError(
            f"Expected exactly one BSE element record for {element}."
        )
    record = next(iter(elements.values()))
    if record.get("ecp_potentials") or record.get("ecp_electrons"):
        raise BasisExchangeError(f"ORCA requires an all-electron basis for {element}.")
    shells = record.get("electron_shells", ())
    if not shells:
        raise BasisExchangeError(
            f"The selected BSE basis has no orbital shells for {element}."
        )

    lines = [f"NewGTO {element}"]
    for shell in shells:
        exponents, contractions = _expanded_contractions(shell, element)
        for angular, coefficients in contractions:
            lines.append(f"  {_tonto_shell_letter(angular)} {len(exponents)}")
            for index, (exponent, coefficient) in enumerate(
                zip(exponents, coefficients), start=1
            ):
                lines.append(f"    {index} {exponent} {coefficient}")
    lines.append("end")
    return "\n".join(lines)


def _single_basis_export(
    program: str,
    element: str,
    name: str,
    bse,
    lut,
) -> str:
    """Export and validate one element through the selected program path."""

    output_format = FORMAT_FOR_PROGRAM.get(program)
    if output_format is None:
        raise BasisExchangeError(
            f"Basis Set Exchange export is not supported for {program}."
        )
    try:
        if program in {"OCC", "Tonto", "Orca", "optorca"}:
            data = bse.get_basis(name, elements=[element])
            if program == "Tonto":
                return _render_tonto_element(data, element)
            if program in {"Orca", "optorca"}:
                return _render_orca_element(data, element)
            elements = data.get("elements", {})
            if len(elements) != 1:
                raise BasisExchangeError(
                    f"Expected exactly one BSE element record for {element}."
                )
            record = next(iter(elements.values()))
            if record.get("ecp_potentials") or record.get("ecp_electrons"):
                raise BasisExchangeError(
                    f"OCC requires an all-electron basis for {element}."
                )
            if not record.get("electron_shells"):
                raise BasisExchangeError(
                    f"The selected BSE basis has no orbital shells for {element}."
                )
            return json.dumps(data, sort_keys=True)

        piece = bse.get_basis(
            name,
            elements=[element],
            fmt=output_format,
            header=False,
        ).strip()
    except BasisExchangeError:
        raise
    except Exception as exc:
        raise BasisExchangeError(
            f"BSE could not export {name} for {element} as {output_format}: {exc}"
        ) from exc

    if not piece:
        raise BasisExchangeError(
            f"BSE returned an empty {output_format} basis for {element}."
        )
    if output_format == "crystal":
        piece = _populate_crystal_shell_charges(piece, element, lut)
    elif output_format == "gaussian94" and not piece.rstrip().endswith("****"):
        raise BasisExchangeError(
            "Basis Set Exchange returned an incomplete Gaussian94 basis block."
        )
    return piece


@lru_cache(maxsize=None)
def compatible_basis_names(
    element: str,
    program: str,
    require_dkh: bool = False,
) -> tuple[str, ...]:
    """Return bases that survive the selected program's actual exporter.

    The result is cached because validating CRYSTAL's shell/CHE constraints can
    require hundreds of BSE exports.  ``require_dkh`` is intended for the
    Gaussian Douglas--Kroll route and admits only families explicitly marked
    DK/DKH/Douglas--Kroll in BSE metadata; an all-electron basis alone is not
    considered sufficient evidence of DKH compatibility.
    """

    if program not in FORMAT_FOR_PROGRAM:
        raise BasisExchangeError(
            f"Basis Set Exchange export is not supported for {program}."
        )
    bse, lut = _bse()
    symbol = element.strip().capitalize()
    result: list[str] = []
    for name in all_electron_basis_names(symbol):
        if require_dkh and not _is_explicit_dkh_basis(name):
            continue
        try:
            _single_basis_export(program, symbol, name, bse, lut)
        except BasisExchangeError:
            continue
        result.append(name)
    return tuple(result)


def render_mixed_basis(
    program: str,
    selections: Mapping[str, str],
) -> tuple[str, str]:
    """Render one external basis file and return ``(text, CP2K map)``.

    For OCC, ``text`` is one MolSSI/BSE JSON document.  For Tonto it is a
    native basis-library file whose basis name is :data:`TONTO_BASIS_LABEL`.
    Other programs retain their established native BSE export formats.
    """

    bse, lut = _bse()
    output_format = FORMAT_FOR_PROGRAM.get(program)
    if not output_format:
        raise BasisExchangeError(
            "BSE export is supported for Gaussian, ORCA, Crystal23, CP2K, "
            "OCC and Tonto. ELMOdb does not accept a BSE export."
        )
    if not selections:
        raise BasisExchangeError("No element basis selections were provided.")

    ordered: list[tuple[str, str]] = []
    seen_symbols: set[str] = set()
    for element, name in sorted(selections.items()):
        symbol = element.strip().capitalize()
        if symbol in seen_symbols:
            raise BasisExchangeError(
                f"The basis selection contains {symbol} more than once."
            )
        seen_symbols.add(symbol)
        ordered.append((symbol, name))

    pieces: list[str] = []
    for element, name in ordered:
        if name not in all_electron_basis_names(element):
            raise BasisExchangeError(
                f"{name} is not an all-electron orbital basis for {element}."
            )
        pieces.append(_single_basis_export(program, element, name, bse, lut))

    if program == "OCC":
        elements: dict[str, dict] = {}
        function_types: set[str] = set()
        for piece in pieces:
            data = json.loads(piece)
            for atomic_number, record in data["elements"].items():
                if atomic_number in elements:
                    raise BasisExchangeError(
                        f"The OCC basis contains duplicate element Z={atomic_number}."
                    )
                elements[atomic_number] = record
            function_types.update(map(str, data.get("function_types", ())))
        document = {
            "molssi_bse_schema": {
                "schema_type": "complete",
                "schema_version": "0.1",
            },
            "name": "lamaGOET mixed all-electron basis",
            "description": "Program-specific BSE selections generated by lamaGOET",
            "role": "orbital",
            "function_types": sorted(function_types),
            "elements": elements,
        }
        text = json.dumps(document, indent=2, sort_keys=True) + "\n"
    elif program == "Tonto":
        lines = [
            "! Mixed all-electron basis generated by lamaGOET/Basis Set Exchange",
        ]
        lines.extend(f"! {element} = {name}" for element, name in ordered)
        lines.extend(("{", "  keys= { gamess-us= }", "  data= {"))
        for (element, _), piece in zip(ordered, pieces):
            lines.append(f"    {element}:{TONTO_BASIS_LABEL} {{")
            lines.extend(f"      {line}" for line in piece.splitlines())
            lines.append("    }")
        lines.extend(("  }", "}", ""))
        text = "\n".join(lines)
    elif output_format == "orca-native":
        lines = ["%basis"]
        for piece in pieces:
            lines.extend(f"  {line}" for line in piece.splitlines())
        lines.extend(("end", ""))
        text = "\n".join(lines)
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
        for piece in pieces:
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
        for element, name in ordered
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
