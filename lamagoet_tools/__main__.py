"""Allow ``python -m lamagoet_tools`` from a lamaGOET checkout."""

from __future__ import annotations

from .cli import main


if __name__ == "__main__":
    raise SystemExit(main())
