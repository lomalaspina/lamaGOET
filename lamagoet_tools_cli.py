#!/usr/bin/env python3
"""Installed launcher for the unified :mod:`lamagoet_tools` command suite."""

from __future__ import annotations

import os
from pathlib import Path
import sys


_REPOSITORY = Path(__file__).resolve().parent
if str(_REPOSITORY) not in sys.path:
    sys.path.insert(0, str(_REPOSITORY))


def _restart_in_private_environment() -> None:
    """Use lamaGOET's dependency-complete interpreter when it is available.

    The installed ``lamagoet-tools`` command is a symlink to this file.  Its
    ``/usr/bin/env python3`` shebang is sufficient for ``--help`` but not for
    conversion commands that need NumPy or TREXIO.  ``install.sh`` already
    creates a private, cross-platform environment for exactly those
    dependencies, so enter it before importing a command module.
    """

    if os.environ.get("LAMAGOET_TOOLS_BOOTSTRAPPED") == "1":
        return
    requested = os.environ.get("LAMAGOET_TOOLS_PYTHON")
    if requested:
        python = Path(requested).expanduser()
    else:
        try:
            from lamagoet_qt.bootstrap import environment_python, select_environment

            python = environment_python(select_environment(_REPOSITORY))
        except (ImportError, OSError):
            return
    if not python.is_file():
        return
    try:
        if python.resolve() == Path(sys.executable).resolve():
            return
    except OSError:
        return
    environment = os.environ.copy()
    environment["LAMAGOET_TOOLS_BOOTSTRAPPED"] = "1"
    os.execve(
        str(python),
        [str(python), str(Path(__file__).resolve()), *sys.argv[1:]],
        environment,
    )


_restart_in_private_environment()

from lamagoet_tools.cli import main  # noqa: E402


if __name__ == "__main__":
    raise SystemExit(main())
