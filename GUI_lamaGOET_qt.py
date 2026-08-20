#!/usr/bin/env python3
"""Launch the cross-platform lamaGOET Qt interface."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import sys


def main() -> int:
    parser = argparse.ArgumentParser(description="lamaGOET Qt structure/job front end")
    parser.add_argument(
        "--mode",
        choices=("local", "cluster"),
        default="local",
        help=(
            "local runs lamaGOET.sh on this computer; cluster writes/submits "
            "lamaGOET.pbs (default: local)"
        ),
    )
    parser.add_argument(
        "--setup-only",
        action="store_true",
        help="create/update the private Qt environment, then exit",
    )
    parser.add_argument(
        "--check-install",
        action="store_true",
        help="create/update the environment and verify that Qt can start",
    )
    parser.add_argument(
        "job_options",
        nargs="?",
        default="job_options.txt",
        help="job_options file to load or create (default: ./job_options.txt)",
    )
    args = parser.parse_args()
    project_root = Path(__file__).resolve().parent
    try:
        from lamagoet_qt.bootstrap import BootstrapError, ensure_qt_environment

        python = ensure_qt_environment(
            project_root,
            Path(__file__).resolve(),
            sys.argv[1:],
        )
    except BootstrapError as exc:
        print(f"lamaGOET Qt setup failed:\n{exc}", file=sys.stderr)
        return 2
    if args.setup_only:
        print(f"lamaGOET Qt environment is ready: {python}")
        return 0
    if args.check_install:
        # Headless build machines have no graphical backend to initialize.
        # Real desktops and WSLg deliberately use their normal backend so a
        # missing XCB/Wayland library makes the installation check fail.
        if (
            sys.platform.startswith("linux")
            and not os.environ.get("DISPLAY")
            and not os.environ.get("WAYLAND_DISPLAY")
        ):
            os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
        try:
            import basis_set_exchange
            import numpy
            from PySide6.QtCore import qVersion
            from PySide6.QtGui import QIcon
            from PySide6.QtWidgets import QApplication

            app = QApplication.instance() or QApplication([])
            app.setApplicationName("lamaGOET")
            app.setDesktopFileName("lamagoet")
            icon = QIcon(str(project_root / "llama.png"))
            if icon.isNull():
                raise RuntimeError("llama.png is missing or unreadable")
            print(
                "lamaGOET Qt installation check passed: "
                f"Python {sys.version_info.major}.{sys.version_info.minor}, "
                f"Qt {qVersion()}, platform {app.platformName()}, "
                f"NumPy {numpy.__version__}, "
                f"Basis Set Exchange {basis_set_exchange.__version__}"
            )
            app.quit()
            return 0
        except (ImportError, OSError, RuntimeError) as exc:
            print(f"lamaGOET Qt installation check failed: {exc}", file=sys.stderr)
            return 2
    try:
        from lamagoet_qt.main_window import run
    except ImportError as exc:
        if exc.name and exc.name.startswith("PySide6"):
            print(
                "lamaGOET Qt could not import PySide6 after automatic setup.\n"
                "Run this launcher again with LAMAGOET_QT_REINSTALL=true, or "
                "review the preceding pip output.\n\n"
                "The existing GUI_lamaGOET_release.sh remains available.",
                file=sys.stderr,
            )
            return 2
        raise
    return run(Path(args.job_options), submission_mode=args.mode)


if __name__ == "__main__":
    raise SystemExit(main())
