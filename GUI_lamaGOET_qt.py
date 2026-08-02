#!/usr/bin/env python3
"""Launch the cross-platform lamaGOET Qt preview."""

from __future__ import annotations

import argparse
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
        "job_options",
        nargs="?",
        default="job_options.txt",
        help="job_options file to load or create (default: ./job_options.txt)",
    )
    args = parser.parse_args()
    try:
        from lamagoet_qt.main_window import run
    except ImportError as exc:
        if exc.name and exc.name.startswith("PySide6"):
            print(
                "lamaGOET Qt requires PySide6.\n\n"
                "Create a Python environment, then install the Qt requirements:\n"
                "  python -m pip install -r requirements-qt.txt\n\n"
                "The existing GUI_lamaGOET_release.sh remains available.",
                file=sys.stderr,
            )
            return 2
        raise
    return run(Path(args.job_options), submission_mode=args.mode)


if __name__ == "__main__":
    raise SystemExit(main())
