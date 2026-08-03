"""Create and maintain lamaGOET's private Qt Python environment.

This module deliberately uses only the Python standard library so it can run
before PySide6 and the other GUI dependencies are installed.
"""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
from typing import Sequence


MINIMUM_PYTHON = (3, 10)
REQUIRED_MODULES = ("PySide6", "basis_set_exchange", "numpy")
MARKER_NAME = ".lamagoet-qt-environment.json"


class BootstrapError(RuntimeError):
    """Raised when the private Qt environment cannot be prepared."""


def _truthy(value: str | None) -> bool:
    return (value or "").strip().lower() in {"1", "true", "yes", "on"}


def environment_python(environment: Path, system_name: str | None = None) -> Path:
    """Return the interpreter path for a virtual environment."""

    name = system_name or platform.system()
    if name == "Windows":
        return environment / "Scripts" / "python.exe"
    return environment / "bin" / "python"


def _user_environment_root() -> Path:
    if platform.system() == "Windows":
        base = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local"))
    elif platform.system() == "Darwin":
        base = Path.home() / "Library" / "Application Support"
    else:
        base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share"))
    return base / "lamaGOET"


def select_environment(project_root: Path) -> Path:
    """Choose a writable, platform-compatible private environment path."""

    override = os.environ.get("LAMAGOET_QT_VENV")
    if override:
        return Path(override).expanduser().resolve()

    preferred = project_root / ".venv-qt"
    preferred_python = environment_python(preferred)
    if preferred_python.is_file() and os.access(preferred, os.W_OK):
        return preferred
    if not preferred.exists() and os.access(project_root, os.W_OK):
        return preferred

    # A checkout shared between Windows and WSL can already contain a virtual
    # environment for the other operating system. Keep both environments
    # instead of overwriting either one.
    tag = (
        f".venv-qt-{platform.system().lower()}-{platform.machine().lower()}-"
        f"py{sys.version_info.major}{sys.version_info.minor}"
    )
    compatible = project_root / tag
    if os.access(project_root, os.W_OK):
        return compatible
    return _user_environment_root() / tag


def _requirements_fingerprint(requirements: Path) -> dict[str, object]:
    digest = hashlib.sha256(requirements.read_bytes()).hexdigest()
    return {
        "schema": 1,
        "requirements_sha256": digest,
        "python": f"{sys.version_info.major}.{sys.version_info.minor}",
        "platform": platform.system(),
        "machine": platform.machine(),
    }


def _marker_matches(marker: Path, expected: dict[str, object]) -> bool:
    try:
        return json.loads(marker.read_text(encoding="utf-8")) == expected
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return False


def _modules_available(python: Path) -> bool:
    names = repr(REQUIRED_MODULES)
    check = (
        "import importlib.util,sys;"
        f"sys.exit(0 if all(importlib.util.find_spec(n) for n in {names}) else 1)"
    )
    try:
        result = subprocess.run(
            [str(python), "-c", check],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
    except OSError:
        return False
    return result.returncode == 0


def _venv_failure_help() -> str:
    if platform.system() == "Linux":
        return (
            "On Debian/Ubuntu/WSL, install the system venv component once with:\n"
            "  sudo apt-get install python3-venv"
        )
    return (
        "Install Python 3.10 or newer from https://www.python.org/downloads/ "
        "and include its venv/pip components."
    )


def _activated_environment(environment: Path, python: Path) -> dict[str, str]:
    variables = os.environ.copy()
    executable_directory = str(python.parent)
    path_items = variables.get("PATH", "").split(os.pathsep)
    if not path_items or path_items[0] != executable_directory:
        variables["PATH"] = os.pathsep.join(
            [executable_directory, *[item for item in path_items if item]]
        )
    variables["VIRTUAL_ENV"] = str(environment)
    variables.pop("PYTHONHOME", None)
    variables["LAMAGOET_QT_BOOTSTRAPPED"] = "1"
    return variables


def ensure_qt_environment(
    project_root: Path,
    script: Path,
    arguments: Sequence[str],
) -> Path:
    """Prepare the private environment and re-execute *script* inside it.

    The returned path is mainly useful for ``--setup-only``. Under ordinary
    startup this function replaces the current process when a different
    interpreter is required.
    """

    if _truthy(os.environ.get("LAMAGOET_QT_NO_BOOTSTRAP")):
        return Path(sys.executable)
    if sys.version_info < MINIMUM_PYTHON:
        raise BootstrapError(
            "lamaGOET Qt requires Python 3.10 or newer; "
            f"this interpreter is {platform.python_version()}."
        )

    requirements = project_root / "requirements-qt.txt"
    if not requirements.is_file():
        raise BootstrapError(f"Qt requirements file not found: {requirements}")

    environment = select_environment(project_root)
    python = environment_python(environment)
    marker = environment / MARKER_NAME
    fingerprint = _requirements_fingerprint(requirements)

    if not python.is_file():
        environment.parent.mkdir(parents=True, exist_ok=True)
        print(
            f"lamaGOET: creating the private Qt environment at {environment}",
            file=sys.stderr,
            flush=True,
        )
        try:
            subprocess.run(
                [sys.executable, "-m", "venv", str(environment)],
                check=True,
            )
        except (OSError, subprocess.CalledProcessError) as exc:
            raise BootstrapError(
                f"Could not create {environment}.\n{_venv_failure_help()}"
            ) from exc

    needs_install = (
        _truthy(os.environ.get("LAMAGOET_QT_REINSTALL"))
        or not _marker_matches(marker, fingerprint)
        or not _modules_available(python)
    )
    if needs_install:
        print(
            "lamaGOET: installing/updating Qt dependencies (one-time setup)...",
            file=sys.stderr,
            flush=True,
        )
        try:
            subprocess.run(
                [
                    str(python),
                    "-m",
                    "pip",
                    "install",
                    "--disable-pip-version-check",
                    "-r",
                    str(requirements),
                ],
                check=True,
            )
        except (OSError, subprocess.CalledProcessError) as exc:
            raise BootstrapError(
                "Could not install the Qt Python dependencies. Check the network "
                "connection and the pip error above, then start lamaGOET again."
            ) from exc
        marker.write_text(
            json.dumps(fingerprint, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )

    try:
        already_running = python.resolve() == Path(sys.executable).resolve()
    except OSError:
        already_running = False
    activated = _activated_environment(environment, python)
    if not already_running:
        os.execve(
            str(python),
            [str(python), str(script), *arguments],
            activated,
        )
    os.environ.clear()
    os.environ.update(activated)
    return python
