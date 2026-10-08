#!/usr/bin/env python3
"""Regression tests for non-destructive SHELX HKL conversion."""

from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
RUNNERS = (ROOT / "lamaGOET.sh", ROOT / "RUN_lamaGOET_release.sh")
FUNCTIONS = (
    "_lamagoet_hkl_has_tonto_header",
    "_lamagoet_convert_shelx_hkl_records",
    "_lamagoet_prepare_tonto_hkl",
)


def function_definition(text: str, name: str) -> str:
    match = re.search(
        rf"(?ms)^{re.escape(name)}\(\)\s*\{{\n.*?^\}}[ \t]*$",
        text,
    )
    if not match:
        raise AssertionError(f"runner function {name} was not found")
    return match.group(0)


@unittest.skipUnless(shutil.which("bash"), "requires bash")
class HklConversionTest(unittest.TestCase):
    def _run_prepare(
        self, runner: Path, source: Path, *, on_f: bool = False
    ) -> tuple[subprocess.CompletedProcess[str], Path]:
        text = runner.read_text(encoding="utf-8")
        definitions = "\n\n".join(
            function_definition(text, name) for name in FUNCTIONS
        )
        target = "true" if on_f else "false"
        intensity = "false" if on_f else "true"
        command = (
            definitions
            + "\n"
            + f'HKL={shlex_quote(str(source))}\n'
            + 'JOBNAME="conversion_case"\n'
            + 'WRITEHEADER="true"\n'
            + f'ONF="{target}"\n'
            + f'ONF2="{intensity}"\n'
            + "_lamagoet_prepare_tonto_hkl\n"
            + 'printf "__RUNTIME__=%s\\n" "$HKL"\n'
        )
        result = subprocess.run(
            ["bash", "-c", command],
            cwd=source.parent,
            text=True,
            capture_output=True,
            check=True,
        )
        marker = next(
            line for line in result.stdout.splitlines()
            if line.startswith("__RUNTIME__=")
        )
        return result, Path(marker.split("=", 1)[1])

    def test_whitespace_records_are_parsed_without_modifying_source(self):
        original = (
            "   0   0   3 0.54424 0.65990   7\n"
            "1 -2 4 3298.25 268.230\n"
            "0 0 0 0 0\n"
        )
        for runner in RUNNERS:
            with self.subTest(runner=runner.name), tempfile.TemporaryDirectory() as tmp:
                source = Path(tmp) / "input reflections.hkl"
                source.write_text(original, encoding="ascii")
                _, runtime = self._run_prepare(runner, source)

                self.assertEqual(source.read_text(encoding="ascii"), original)
                self.assertNotEqual(runtime.resolve(), source.resolve())
                converted = runtime.read_text(encoding="ascii")
                self.assertIn("keys= { h= k= l= i_exp= i_sigma= }", converted)
                self.assertIn("0 0 3 0.54424 0.65990", converted)
                self.assertIn("1 -2 4 3298.25 268.230", converted)
                self.assertFalse((Path(tmp) / "conversion_case.your_input.hkl").exists())

    def test_touching_fixed_width_fields_use_shelx_fallback(self):
        original = (
            f"{0:4d}{0:4d}{3:4d}{-3298.25:8.2f}{268.23:8.2f}{7:4d}\n"
            f"{0:4d}{0:4d}{0:4d}{0.0:8.2f}{0.0:8.2f}{0:4d}\n"
        )
        for runner in RUNNERS:
            with self.subTest(runner=runner.name), tempfile.TemporaryDirectory() as tmp:
                source = Path(tmp) / "touching.hkl"
                source.write_text(original, encoding="ascii")
                _, runtime = self._run_prepare(runner, source, on_f=True)

                self.assertEqual(source.read_text(encoding="ascii"), original)
                converted = runtime.read_text(encoding="ascii")
                self.assertIn("keys= { h= k= l= f_exp= f_sigma= }", converted)
                self.assertIn("0 0 3 -3298.25 268.23", converted)

    def test_existing_tonto_header_is_not_reparsed_or_rewritten(self):
        original = (
            " reflection_data= {\n"
            "  keys= { h= k= l= i_exp= i_sigma= }\n"
            "   data= {\n"
            "not deliberately reparsed by this test\n"
            "   }\n  }\n REVERT\n"
        )
        for runner in RUNNERS:
            with self.subTest(runner=runner.name), tempfile.TemporaryDirectory() as tmp:
                source = Path(tmp) / "already_tonto.hkl"
                source.write_text(original, encoding="ascii")
                result, runtime = self._run_prepare(runner, source)

                self.assertEqual(runtime.resolve(), source.resolve())
                self.assertEqual(source.read_text(encoding="ascii"), original)
                self.assertIn("header already present", result.stdout)
                self.assertFalse((Path(tmp) / "conversion_case.tonto_runtime.hkl").exists())


def shlex_quote(value: str) -> str:
    """Quote a path for the small bash snippets used by these tests."""
    return "'" + value.replace("'", "'\"'\"'") + "'"


if __name__ == "__main__":
    unittest.main()
