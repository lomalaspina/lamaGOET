from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path
import unittest

from lamagoet_tools.orca_basis import (
    OrcaBasisError,
    main,
    normalize_orca_basis_text,
)


class OrcaBasisNormalizationTests(unittest.TestCase):
    def test_native_newgto_basis_is_preserved(self):
        source = (
            "%basis\n"
            "  NewGTO C\n"
            "    S 1\n"
            "      1 2.0 1.0\n"
            "  end\n"
            "end\n"
        )
        normalized, converted = normalize_orca_basis_text(source)
        self.assertFalse(converted)
        self.assertEqual(normalized, source)

    def test_legacy_bse_gamess_basis_becomes_native_orca(self):
        source = (
            "$DATA\n\n"
            "HYDROGEN\n"
            "S 1\n"
            "1 3.0D+00 1.0\n\n"
            "CARBON\n"
            "L 1\n"
            "1 2.0 0.7 0.3\n\n"
            "$END\n"
        )
        normalized, converted = normalize_orca_basis_text(source)
        self.assertTrue(converted)
        self.assertTrue(normalized.startswith("%basis\n"))
        self.assertIn("NewGTO H", normalized)
        self.assertIn("NewGTO C", normalized)
        self.assertIn("    S 1\n      1 2.0 0.7", normalized)
        self.assertIn("    P 1\n      1 2.0 0.3", normalized)
        self.assertNotIn("$DATA", normalized)

    def test_ambiguous_legacy_contraction_is_rejected(self):
        source = "$DATA\nCARBON\nS 1\n1 2.0 0.7 0.3\n$END\n"
        with self.assertRaisesRegex(OrcaBasisError, "coefficients"):
            normalize_orca_basis_text(source)

    def test_cli_writes_separate_runtime_include(self):
        source = "$DATA\nOXYGEN\nS 1\n1 4.0 1.0\n$END\n"
        with tempfile.TemporaryDirectory() as directory:
            input_path = Path(directory) / "basis_gen.txt"
            output_path = Path(directory) / "job.orca-basis.inc"
            input_path.write_text(source, encoding="utf-8")
            self.assertEqual(main([str(input_path), str(output_path)]), 0)
            self.assertEqual(input_path.read_text(encoding="utf-8"), source)
            self.assertIn(
                "NewGTO O", output_path.read_text(encoding="utf-8")
            )

    @unittest.skipUnless(
        os.name == "posix" and shutil.which("bash"),
        "launcher integration requires bash",
    )
    def test_shell_helper_converts_legacy_file_and_exports_runtime_include(self):
        repository = Path(__file__).resolve().parents[1]
        source = "$DATA\nHYDROGEN\nS 1\n1 3.0 1.0\n$END\n"
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            input_path = work / "basis_gen.txt"
            output_path = work / "job.orca-basis.inc"
            input_path.write_text(source, encoding="utf-8")
            script = (
                'set -e\n'
                f'export LAMAGOET_DIR={shlex_quote(str(repository))}\n'
                f'source {shlex_quote(str(repository / "lamagoet_shell_env.sh"))}\n'
                f'_lamagoet_prepare_orca_external_basis '
                f'{shlex_quote(str(input_path))} {shlex_quote(str(output_path))}\n'
                'printf "%s\\n" "$ORCA_EXTERNAL_BASIS_FILE"\n'
            )
            result = subprocess.run(
                ["bash", "-c", script],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                result.stdout.strip().splitlines()[-1], str(output_path)
            )
            self.assertEqual(input_path.read_text(encoding="utf-8"), source)
            normalized = output_path.read_text(encoding="utf-8")
            self.assertIn("NewGTO H", normalized)
            self.assertNotIn("$DATA", normalized)


def shlex_quote(value: str) -> str:
    """Quote a path for the small bash integration fixture."""

    import shlex

    return shlex.quote(value)


if __name__ == "__main__":
    unittest.main()
