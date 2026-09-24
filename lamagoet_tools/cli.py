"""Unified command-line entry point for lamaGOET's Python support tools."""

from __future__ import annotations

import importlib
from pathlib import Path
import sys
from collections.abc import Callable, Sequence


_COMMANDS: dict[str, tuple[str, str]] = {
    "orca-basis": (
        "lamagoet_tools.orca_basis",
        "validate or convert an external basis to native ORCA input",
    ),
    "cif-to-cp2k": (
        "cif_to_cp2k",
        "expand a crystallographic CIF into a full-cell CP2K SUBSYS include",
    ),
    "cp2k-xml-bridge": (
        "cp2k_tonto_bridge",
        "run the retained legacy CP2K-to-Tonto XML conversion",
    ),
    "periodic-wavefunction": (
        "periodic_wavefunction_export",
        "export and validate a periodic TREXIO wavefunction",
    ),
    "finite-wavefunction": (
        "finite_crystal_wavefunction",
        "prepare or run finite all-electron crystal-cluster calculations",
    ),
}


def _usage(file: object = sys.stdout) -> None:
    print("usage: lamagoet-tools COMMAND [OPTIONS]", file=file)
    print("", file=file)
    print("commands:", file=file)
    width = max(len(name) for name in _COMMANDS)
    for name, (_, description) in _COMMANDS.items():
        print(f"  {name:<{width}}  {description}", file=file)
    print("", file=file)
    print("Run 'lamagoet-tools COMMAND --help' for command-specific options.", file=file)


def _load_main(module_name: str) -> Callable[[Sequence[str] | None], int]:
    repository = Path(__file__).resolve().parents[1]
    repository_text = str(repository)
    if repository_text not in sys.path:
        sys.path.insert(0, repository_text)
    module = importlib.import_module(module_name)
    main = getattr(module, "main", None)
    if not callable(main):
        raise RuntimeError(f"lamaGOET tool module {module_name!r} has no callable main()")
    return main


def main(argv: Sequence[str] | None = None) -> int:
    arguments = list(sys.argv[1:] if argv is None else argv)
    if not arguments or arguments[0] in {"-h", "--help", "help"}:
        _usage()
        return 0
    if arguments[0] in {"--version", "version"}:
        from . import __version__

        print(__version__)
        return 0

    command = arguments.pop(0)
    selected = _COMMANDS.get(command)
    if selected is None:
        print(f"lamagoet-tools: unknown command: {command}", file=sys.stderr)
        _usage(sys.stderr)
        return 2
    module_name, _ = selected
    return int(_load_main(module_name)(arguments))
