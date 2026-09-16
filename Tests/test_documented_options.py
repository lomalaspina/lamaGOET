#!/usr/bin/env python3
"""Require every canonical GUI/runner option to appear in the manual."""

from __future__ import annotations

from pathlib import Path
import re
import unittest

from lamagoet_qt.options_schema import OPTION_DEFAULTS


ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / "docs" / "manual" / "options-reference.md"


class DocumentedOptionsTest(unittest.TestCase):
    def test_every_canonical_option_is_documented(self) -> None:
        text = REFERENCE.read_text(encoding="utf-8")
        documented = set(re.findall(r"\|\s*`([A-Z][A-Z0-9_]*)`\s*\|", text))
        missing = sorted(set(OPTION_DEFAULTS) - documented)
        self.assertEqual(missing, [], f"Undocumented canonical options: {missing}")


if __name__ == "__main__":
    unittest.main()
