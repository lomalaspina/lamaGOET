"""Find Tonto and its basis sets without making the user type paths.

Tonto is normally run straight from its build tree: its README says to run
cmake and make, and never mentions `make install`.  So a user typically has
something like

    ~/tonto/release/tonto          the binary
    ~/tonto/basis_sets             the basis sets, one level up

If it *is* installed, CMake puts it somewhere quite different:

    /usr/local/bin/tonto
    /usr/local/share/tonto/basis_sets

lamaGOET's defaults matched neither: it looked for basis sets in
/usr/local/bin/basis_sets, which no Tonto has ever created.

Nothing here guesses silently.  Each function returns None when it finds
nothing, and the caller keeps whatever the user had.
"""

from __future__ import annotations

import os
import shutil
from pathlib import Path


#: Places a Tonto binary is likely to be, most specific first.
_TONTO_BINARY_HINTS = (
    "release/tonto",
    "release-*/tonto",
    "build/tonto",
    "build-*/tonto",
    "bin/tonto",
    "tonto",
)

#: Roots to search for a Tonto checkout or installation.
def _search_roots() -> list[Path]:
    roots: list[Path] = []
    env = os.environ.get("TONTO_DIR") or os.environ.get("TONTODIR")
    if env:
        roots.append(Path(env).expanduser())
    home = Path.home()
    roots += [
        home / "tonto",
        home / "Tonto",
        home / "src" / "tonto",
        home / "github" / "tonto",
        Path("/usr/local"),
        Path("/opt/homebrew"),
        Path("/opt/tonto"),
    ]
    return roots


def find_tonto_executable() -> Path | None:
    """Return a Tonto binary, or None.

    Anything already on PATH wins: if the user has arranged that, respect it.
    """

    on_path = shutil.which("tonto")
    if on_path:
        return Path(on_path)

    for root in _search_roots():
        if not root.is_dir():
            continue
        for hint in _TONTO_BINARY_HINTS:
            for candidate in sorted(root.glob(hint)):
                if candidate.is_file() and os.access(candidate, os.X_OK):
                    return candidate
    return None


def find_basis_sets(tonto_executable: str | Path | None = None) -> Path | None:
    """Return Tonto's basis-set directory, or None.

    Derived from the binary's location where possible, because the two are
    installed together and a mismatched pair is worse than none: Tonto will
    run and fail to find the basis it was asked for.
    """

    candidates: list[Path] = []

    if tonto_executable:
        binary = Path(tonto_executable).expanduser()
        # A bare name such as "tonto" tells us nothing about the layout.
        if binary.parent != Path("."):
            directory = binary.resolve().parent
            candidates += [
                directory / "basis_sets",                  # beside the binary
                directory.parent / "basis_sets",           # build tree, one up
                directory.parent / "share" / "tonto" / "basis_sets",  # installed
                directory.parent.parent / "basis_sets",    # nested build dir
            ]

    for root in _search_roots():
        candidates += [
            root / "basis_sets",
            root / "share" / "tonto" / "basis_sets",
        ]

    for candidate in candidates:
        if candidate.is_dir() and any(candidate.iterdir()):
            return candidate
    return None


def describe() -> str:
    """One-line summary, for logging and for the status bar."""

    tonto = find_tonto_executable()
    basis = find_basis_sets(tonto)
    if tonto is None and basis is None:
        return "Tonto was not found automatically; set it on the Settings tab."
    parts = []
    if tonto is not None:
        parts.append(f"Tonto {tonto}")
    if basis is not None:
        parts.append(f"basis sets {basis}")
    return "Found " + ", ".join(parts)
