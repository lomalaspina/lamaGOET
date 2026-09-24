"""Validate and normalize external all-electron basis blocks for ORCA.

Current lamaGOET writes native %basis/NewGTO input. Older releases used Basis
Set Exchange's misleading orca formatter, whose output is actually a GAMESS-US
$DATA container. This module safely converts that legacy representation.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import re
from collections.abc import Sequence


class OrcaBasisError(ValueError):
    """An external basis cannot be represented safely in ORCA."""


_ELEMENT_SYMBOLS = (
    "H He Li Be B C N O F Ne Na Mg Al Si P S Cl Ar K Ca Sc Ti V Cr Mn "
    "Fe Co Ni Cu Zn Ga Ge As Se Br Kr Rb Sr Y Zr Nb Mo Tc Ru Rh Pd Ag Cd "
    "In Sn Sb Te I Xe Cs Ba La Ce Pr Nd Pm Sm Eu Gd Tb Dy Ho Er Tm Yb Lu "
    "Hf Ta W Re Os Ir Pt Au Hg Tl Pb Bi Po At Rn Fr Ra Ac Th Pa U Np Pu Am "
    "Cm Bk Cf Es Fm Md No Lr Rf Db Sg Bh Hs Mt Ds Rg Cn Nh Fl Mc Lv Ts Og"
).split()

_ELEMENT_NAMES = (
    "hydrogen helium lithium beryllium boron carbon nitrogen oxygen fluorine "
    "neon sodium magnesium aluminium silicon phosphorus sulfur chlorine argon "
    "potassium calcium scandium titanium vanadium chromium manganese iron "
    "cobalt nickel copper zinc gallium germanium arsenic selenium bromine "
    "krypton rubidium strontium yttrium zirconium niobium molybdenum technetium "
    "ruthenium rhodium palladium silver cadmium indium tin antimony tellurium "
    "iodine xenon "
)
_ELEMENT_NAMES += (
    "caesium barium lanthanum cerium praseodymium neodymium promethium "
    "samarium europium gadolinium terbium dysprosium holmium erbium thulium "
    "ytterbium lutetium hafnium tantalum tungsten rhenium osmium iridium "
    "platinum gold mercury thallium lead bismuth polonium astatine radon "
)
_ELEMENT_NAMES += (
    "francium radium actinium thorium protactinium uranium neptunium plutonium "
    "americium curium berkelium californium einsteinium fermium mendelevium "
    "nobelium lawrencium rutherfordium dubnium seaborgium bohrium hassium "
)
_ELEMENT_NAMES += (
    "meitnerium darmstadtium roentgenium copernicium nihonium flerovium "
    "moscovium livermorium tennessine oganesson"
)

_NAME_TO_SYMBOL = {
    name: symbol for name, symbol in zip(_ELEMENT_NAMES.split(), _ELEMENT_SYMBOLS)
}
_NAME_TO_SYMBOL.update(
    {
        symbol.casefold(): symbol for symbol in _ELEMENT_SYMBOLS
    }
)
_NAME_TO_SYMBOL.update({"aluminum": "Al", "cesium": "Cs", "sulphur": "S"})

_SHELL_HEADER = re.compile(
    r"^(S|P|D|F|G|H|I|K|L|SP)\s+(\d+)(?:\s+.*)?$",
    flags=re.IGNORECASE,
)


def _element_symbol(header: str) -> str:
    fields = header.split()
    if len(fields) != 1:
        raise OrcaBasisError(
            "legacy $DATA element headers must contain only an element name"
        )
    try:
        return _NAME_TO_SYMBOL[fields[0].casefold()]
    except KeyError as exc:
        raise OrcaBasisError(
            f"unknown element header in legacy $DATA basis: {header!r}"
        ) from exc


def _first_content_line(lines: list[str]) -> str:
    for line in lines:
        stripped = line.strip()
        if stripped and not stripped.startswith(("#", "!")):
            return stripped
    raise OrcaBasisError("external ORCA basis file is empty")


def _validate_native_orca(text: str) -> str:
    lines = text.splitlines()
    if _first_content_line(lines).casefold() != "%basis":
        raise OrcaBasisError("native ORCA basis must start with %basis")
    if re.search(r"(?im)^\s*\$(?:data|end)\b", text):
        raise OrcaBasisError("native ORCA basis contains a GAMESS $DATA marker")
    if not re.search(r"(?im)^\s*NewGTO\s+[A-Za-z]{1,2}\s*$", text):
        raise OrcaBasisError("native ORCA basis contains no NewGTO element block")
    content = [
        line.strip()
        for line in lines
        if line.strip() and not line.lstrip().startswith(("#", "!"))
    ]
    if content[-1].casefold() != "end":
        raise OrcaBasisError("native ORCA %basis block has no final end")
    return text.rstrip() + "\n"


def _legacy_body(text: str) -> list[str]:
    lines = text.splitlines()
    markers = [
        index
        for index, line in enumerate(lines)
        if line.strip().casefold() in {"$data", "$end"}
    ]
    if len(markers) != 2:
        raise OrcaBasisError(
            "legacy ORCA basis must contain exactly one $DATA and one $END"
        )
    start, stop = markers
    if (
        lines[start].strip().casefold() != "$data"
        or lines[stop].strip().casefold() != "$end"
        or stop <= start
    ):
        raise OrcaBasisError("legacy $DATA/$END markers are out of order")
    outside = lines[:start] + lines[stop + 1 :]
    if any(
        line.strip() and not line.lstrip().startswith(("#", "!"))
        for line in outside
    ):
        raise OrcaBasisError("unexpected text outside the legacy $DATA block")
    return lines[start + 1 : stop]


def _primitive(fields: list[str], shell: str, element: str) -> tuple[str, ...]:
    expected = 4 if shell in {"L", "SP"} else 3
    if len(fields) != expected:
        raise OrcaBasisError(
            f"{element} {shell} primitive has {len(fields) - 2} coefficients; "
            f"expected {expected - 2}"
        )
    try:
        int(fields[0])
        for value in fields[1:]:
            float(value.replace("D", "E").replace("d", "e"))
    except ValueError as exc:
        raise OrcaBasisError(
            f"{element} {shell} contains a non-numeric primitive"
        ) from exc
    return tuple(fields[1:])


def _convert_legacy_gamess(text: str) -> str:
    body = _legacy_body(text)
    output = ["%basis"]
    seen: set[str] = set()
    index = 0
    while index < len(body):
        while index < len(body) and not body[index].strip():
            index += 1
        if index >= len(body):
            break
        symbol = _element_symbol(body[index].strip())
        if symbol in seen:
            raise OrcaBasisError(
                f"legacy $DATA basis contains duplicate element {symbol}"
            )
        seen.add(symbol)
        output.append(f"  NewGTO {symbol}")
        index += 1
        found_shell = False
        while index < len(body):
            line = body[index].strip()
            if not line:
                index += 1
                break
            match = _SHELL_HEADER.match(line)
            if match is None:
                # A non-shell line after at least one shell starts the next
                # element. It is parsed by the outer loop.
                if found_shell:
                    break
                raise OrcaBasisError(
                    f"expected a shell after legacy element {symbol}: {line!r}"
                )
            found_shell = True
            shell = match.group(1).upper()
            count = int(match.group(2))
            if count <= 0:
                raise OrcaBasisError(f"{symbol} {shell} has no primitives")
            index += 1
            primitives: list[tuple[str, ...]] = []
            while len(primitives) < count:
                if index >= len(body) or not body[index].strip():
                    raise OrcaBasisError(
                        f"{symbol} {shell} ended before {count} primitives"
                    )
                primitives.append(
                    _primitive(body[index].split(), shell, symbol)
                )
                index += 1
            if shell in {"L", "SP"}:
                for target, coefficient in (("S", 1), ("P", 2)):
                    output.append(f"    {target} {count}")
                    for number, values in enumerate(primitives, start=1):
                        output.append(
                            f"      {number} {values[0]} {values[coefficient]}"
                        )
            else:
                output.append(f"    {shell} {count}")
                for number, values in enumerate(primitives, start=1):
                    output.append(f"      {number} {values[0]} {values[1]}")
        if not found_shell:
            raise OrcaBasisError(f"legacy element {symbol} contains no shells")
        output.append("  end")
    if not seen:
        raise OrcaBasisError("legacy $DATA basis contains no elements")
    output.extend(("end", ""))
    return "\n".join(output)


def normalize_orca_basis_text(text: str) -> tuple[str, bool]:
    """Return native ORCA basis text and whether legacy input was converted."""

    first = _first_content_line(text.splitlines()).casefold()
    if first == "%basis":
        return _validate_native_orca(text), False
    if first == "$data":
        converted = _convert_legacy_gamess(text)
        return _validate_native_orca(converted), True
    raise OrcaBasisError(
        "external ORCA basis must be a native %basis block or legacy BSE $DATA"
    )


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="normalize a lamaGOET external basis as native ORCA input"
    )
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args(argv)
    try:
        normalized, converted = normalize_orca_basis_text(
            args.input.read_text(encoding="utf-8")
        )
        args.output.write_text(normalized, encoding="utf-8")
    except (OSError, OrcaBasisError) as exc:
        parser.exit(2, f"orca-basis: error: {exc}\n")
    if converted:
        print(
            "lamaGOET: converted legacy BSE $DATA basis to native ORCA %basis",
            file=__import__("sys").stderr,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
