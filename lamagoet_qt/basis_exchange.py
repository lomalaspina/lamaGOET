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


def render_mixed_basis(
    program: str,
    selections: Mapping[str, str],
) -> tuple[str, str]:
    """Render one external basis file and return ``(text, CP2K map)``."""

    bse, _ = _bse()
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
